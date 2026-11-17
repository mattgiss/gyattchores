package com.gyattchores.app

import com.gyattchores.app.model.ChoreLog
import com.gyattchores.app.sync.FamilyKeys
import com.gyattchores.app.sync.HttpStatusException
import com.gyattchores.app.sync.JoinCode
import com.gyattchores.app.sync.LocalEntry
import com.gyattchores.app.sync.LogSync
import com.gyattchores.app.sync.MemorySessionStore
import com.gyattchores.app.sync.Relay
import com.gyattchores.app.sync.RelayHttp
import com.gyattchores.app.sync.StateSync
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import kotlinx.serialization.json.put
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.net.URI
import java.net.URLDecoder
import java.security.MessageDigest
import java.time.Instant
import java.util.UUID

/**
 * An in-memory relay with the same rules as supabase/doyourwork/001_relay.sql: anonymous sign-ups,
 * membership checks, one-time join tokens, and records only members can read or write.
 */
class FakeRelay : RelayHttp {
    data class Rec(var ciphertext: String, var clientUpdatedAt: Long)
    data class Token(val household: String, val expires: Long, var used: Boolean = false)
    val users = HashMap<String, String>()
    private val refresh = HashMap<String, String>()
    private val devices = HashMap<String, LinkedHashMap<String, String>>()
    private val tokens = HashMap<String, Token>()
    val records = sortedMapOf<String, Rec>()
    var expireNextToken = false

    private fun session(uid: String): Pair<Int, String> {
        val at = UUID.randomUUID().toString(); val rt = UUID.randomUUID().toString()
        users[at] = uid; refresh[rt] = uid
        return 200 to buildJsonObject { put("access_token", at); put("refresh_token", rt); put("expires_in", 3600); put("user", buildJsonObject { put("id", uid) }) }.toString()
    }

    @Synchronized
    override fun send(method: String, url: String, headers: Map<String, String>, body: String?): Pair<Int, String> {
        val uri = URI(url)
        val q = uri.rawQuery.orEmpty().split("&").filter { it.isNotEmpty() }.associate { it.substringBefore("=") to URLDecoder.decode(it.substringAfter("="), "UTF-8") }
        val eq = { k: String -> q[k]?.removePrefix("eq.") }
        val b = body?.let { Json.parseToJsonElement(it) }
        if (headers["apikey"] == null) return 401 to "{}"
        if (uri.path == "/auth/v1/signup") return session(UUID.randomUUID().toString())
        if (uri.path == "/auth/v1/token") {
            val uid = refresh.remove(b!!.jsonObject["refresh_token"]!!.jsonPrimitive.content) ?: return 400 to "{}"
            return session(uid)
        }
        val uid = users[headers["Authorization"]?.removePrefix("Bearer ")] ?: return 401 to """{"message":"JWT expired"}"""
        val member = { h: String -> devices[h]?.containsKey(uid) == true }
        val arg = { k: String -> b!!.jsonObject[k]!!.jsonPrimitive.content }

        return when (method to uri.path) {
            "POST" to "/rest/v1/rpc/create_household" -> {
                val h = arg("p_household"); if (devices.containsKey(h)) 409 to "{}" else { devices[h] = linkedMapOf(uid to Instant.now().toString()); 204 to "" }
            }
            "POST" to "/rest/v1/rpc/create_join_token" -> {
                val h = arg("p_household"); if (!member(h)) return 403 to "{}"
                val exp = if (expireNextToken) System.currentTimeMillis() - 1000 else System.currentTimeMillis() + 600_000; expireNextToken = false
                tokens[arg("p_token_hash").removePrefix("\\x")] = Token(h, exp)
                200 to JsonPrimitive(Instant.ofEpochMilli(exp).toString()).toString()
            }
            "POST" to "/rest/v1/rpc/join_household" -> {
                val h = arg("p_household"); val tok = arg("p_token").removePrefix("\\x")
                val raw = ByteArray(tok.length / 2) { tok.substring(it * 2, it * 2 + 2).toInt(16).toByte() }
                val hash = MessageDigest.getInstance("SHA-256").digest(raw).joinToString("") { "%02x".format(it) }
                val t = tokens[hash]
                if (t == null || t.household != h || t.used || t.expires < System.currentTimeMillis()) 200 to "false"
                else { t.used = true; devices.getOrPut(h) { linkedMapOf() }.putIfAbsent(uid, Instant.now().toString()); 200 to "true" }
            }
            "POST" to "/rest/v1/rpc/remove_device" -> { val h = arg("p_household"); if (!member(h)) 403 to "{}" else { devices[h]!!.remove(arg("p_user")); 204 to "" } }
            "POST" to "/rest/v1/rpc/delete_household" -> {
                val h = arg("p_household"); if (!member(h)) 403 to "{}" else { devices.remove(h); records.keys.removeIf { it.startsWith("$h|") }; 204 to "" }
            }
            "GET" to "/rest/v1/household_devices" -> {
                val h = eq("household_id")!!; if (!member(h)) 200 to "[]"
                else 200 to buildJsonArray { devices[h]!!.forEach { (u, at) -> add(buildJsonObject { put("user_id", u); put("joined_at", at) }) } }.toString()
            }
            "POST" to "/rest/v1/records" -> {
                for (r in b!!.jsonArray) {
                    val o = r.jsonObject; val h = o["household_id"]!!.jsonPrimitive.content
                    if (!member(h)) return 403 to """{"message":"row-level security"}"""
                    records["$h|${o["kind"]!!.jsonPrimitive.content}|${o["row_id"]!!.jsonPrimitive.content}"] =
                        Rec(o["ciphertext"]!!.jsonPrimitive.content, o["client_updated_at"]!!.jsonPrimitive.long)
                }
                201 to ""
            }
            "PATCH" to "/rest/v1/records" -> {
                val key = "${eq("household_id")}|${eq("kind")}|${eq("row_id")}"
                val rec = records[key]
                if (!member(eq("household_id")!!) || rec == null) 200 to "[]"
                else { rec.ciphertext = arg("ciphertext"); rec.clientUpdatedAt = b!!.jsonObject["client_updated_at"]!!.jsonPrimitive.long; 200 to """[{"row_id":"x"}]""" }
            }
            "GET" to "/rest/v1/records" -> {
                val h = eq("household_id")!!; val kind = eq("kind")!!
                if (!member(h)) return 200 to "[]"
                val rows = records.filterKeys { it.startsWith("$h|$kind|") }.entries.drop(q["offset"]!!.toInt()).take(q["limit"]!!.toInt())
                200 to JsonArray(rows.map { (k, v) -> buildJsonObject {
                    put("household_id", h); put("kind", kind); put("row_id", k.split("|", limit = 3)[2]); put("ciphertext", v.ciphertext); put("client_updated_at", v.clientUpdatedAt)
                } }).toString()
            }
            else -> 404 to "{}"
        }
    }
}

class RelayTest {
    private fun log(id: String, status: String = "pending") =
        ChoreLog(id, null, "1", "kid", "make-bed", "make bed", 8, 5, status, 1_731_700_000_123L)

    private fun family(): Triple<FakeRelay, Relay, Relay> {
        val server = FakeRelay()
        val a = Relay(FamilyKeys.generate(), MemorySessionStore(), http = server)
        a.createHousehold()
        val scanned = JoinCode.parse(a.makeJoinCode().first.text)
        val b = Relay(scanned.keys, MemorySessionStore(), http = server)
        assertTrue(b.join(scanned))
        return Triple(server, a, b)
    }

    @Test fun logsTravelBetweenPhonesThroughLogSync() {
        val (server, a, b) = family()
        val onA = LogSync.run(a, listOf(log("l1")))
        assertEquals("l1", onA.single().remoteId)
        assertEquals("a log keeps its own date", 1_731_700_000_123L, onA.single().timestamp)

        val onB = LogSync.run(b, emptyList())
        assertEquals(5, onB.single().minutes)
        assertEquals(1_731_700_000_123L, onB.single().timestamp)

        val afterB = LogSync.run(b, listOf(onB.single().copy(status = "approved", statusDirty = true)))
        assertFalse(afterB.single().statusDirty)
        assertEquals("approved", LogSync.run(a, onA).single().status)

        for (r in server.records.values) assertFalse(r.ciphertext.contains("kid"))
    }

    @Test fun stateTravelsWithHiddenKeys() {
        val (server, a, b) = family()
        StateSync.run(a, mapOf("players" to LocalEntry(listOf("1|kid"), 10, true), "dare|1|2026-11-17" to LocalEntry(listOf("x"), 11, true)))
        val onB = StateSync.run(b, emptyMap())
        assertEquals(listOf("1|kid"), onB["players"]?.items)
        assertEquals(11L, onB["dare|1|2026-11-17"]?.updatedAt)
        assertFalse(server.records.keys.any { "players" in it || "dare" in it })
    }

    @Test fun outsidersGetNothing() {
        val (server, a, _) = family()
        LogSync.run(a, listOf(log("l1")))
        val stranger = Relay(a.keys, MemorySessionStore(), http = server)
        assertTrue(stranger.selectAll().isEmpty())
        try { stranger.insert(log("evil")); fail() } catch (e: HttpStatusException) { assertEquals(403, e.code) }
        try { stranger.makeJoinCode(); fail() } catch (e: HttpStatusException) { assertEquals(403, e.code) }
    }

    @Test fun joinCodesWorkOnceAndExpire() {
        val (server, a, _) = family()
        val code = a.makeJoinCode().first
        val c = Relay(code.keys, MemorySessionStore(), http = server)
        val d = Relay(code.keys, MemorySessionStore(), http = server)
        assertTrue(c.join(code)); assertFalse("a code works once", d.join(code))
        assertFalse(d.join(JoinCode(code.keys, ByteArray(32) { 7 })))
        server.expireNextToken = true
        assertFalse("an expired code is refused", d.join(a.makeJoinCode().first))
    }

    @Test fun tamperedRecordsAreSkippedNotFatal() {
        val (server, a, b) = family()
        LogSync.run(a, listOf(log("l1"), log("l2")))
        val k1 = server.records.keys.first { it.endsWith("|log|l1") }; val k2 = server.records.keys.first { it.endsWith("|log|l2") }
        server.records[k1]!!.ciphertext = server.records[k2]!!.ciphertext
        assertEquals(listOf("l2"), b.selectAll().map { it.id })
        assertEquals(1, b.unreadable)
    }

    @Test fun removedPhoneStopsGettingUpdatesAndDeleteClearsAll() {
        val (_, a, b) = family()
        assertEquals(2, a.devices().size)
        a.removeDevice(b.userId())
        assertEquals(1, a.devices().size)
        LogSync.run(a, listOf(log("l1")))
        assertTrue(b.selectAll().isEmpty())
        a.deleteHousehold()
        assertTrue(a.selectAll().isEmpty())
    }

    @Test fun refreshesAnExpiredSessionAndKeepsTheSameDevice() {
        val server = FakeRelay(); val store = MemorySessionStore()
        var clock = 1_800_000_000_000L
        val a = Relay(FamilyKeys.generate(), store, http = server, now = { clock })
        a.createHousehold()
        val first = store.load()!!
        clock += 4_000_000
        a.selectAll()
        val second = store.load()!!
        assertNotEquals(first.accessToken, second.accessToken)
        assertEquals(first.userId, second.userId)
        server.users.remove(second.accessToken)
        a.selectAll()
        assertEquals(first.userId, store.load()!!.userId)
    }

    /** Against the real DOYOURWORK relay, only when asked: `RELAY_LIVE=1 ./gradlew testPublicDebugUnitTest --tests '*RelayTest*'`. */
    @Test fun relayLive() {
        assumeTrue("set RELAY_LIVE=1 to run against the real relay", System.getenv("RELAY_LIVE") == "1")
        val keys = FamilyKeys.generate()
        val a = Relay(keys, MemorySessionStore())
        a.createHousehold()
        try {
            val (code, expires) = a.makeJoinCode()
            assertTrue(expires > System.currentTimeMillis() + 500_000)
            val b = Relay(JoinCode.parse(code.text).keys, MemorySessionStore())
            assertTrue(b.join(code))
            LogSync.run(a, listOf(log("live-1")))
            StateSync.run(a, mapOf("players" to LocalEntry(listOf("1|kid"), 5, true)))
            assertEquals(listOf("live-1"), LogSync.run(b, emptyList()).map { it.remoteId })
            assertEquals(listOf("1|kid"), StateSync.run(b, emptyMap())["players"]?.items)
            assertTrue(Relay(keys, MemorySessionStore()).selectAll().isEmpty())
        } finally { a.deleteHousehold() }
    }
}

