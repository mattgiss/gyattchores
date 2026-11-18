package com.gyattchores.app

import com.gyattchores.app.model.ChoreLog
import com.gyattchores.app.sync.FamilyKeys
import com.gyattchores.app.sync.HttpStatusException
import com.gyattchores.app.sync.JoinCode
import com.gyattchores.app.sync.LocalEntry
import com.gyattchores.app.sync.MemoryRelay
import com.gyattchores.app.sync.LogSync
import com.gyattchores.app.sync.MemorySessionStore
import com.gyattchores.app.sync.Relay
import com.gyattchores.app.sync.RelayConfig
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
 * The desktop JVM's HttpURLConnection refuses PATCH (Android's accepts it), so the live tests speak
 * HTTP/1.1 over a TLS socket themselves.
 */
private object SocketHttp : RelayHttp {
    override fun send(method: String, url: String, headers: Map<String, String>, body: String?): Pair<Int, String> {
        val u = URI(url)
        val bytes = body?.toByteArray() ?: ByteArray(0)
        (javax.net.ssl.SSLSocketFactory.getDefault().createSocket(u.host, 443) as javax.net.ssl.SSLSocket).use { sock ->
            sock.soTimeout = 20_000
            val head = buildString {
                append("$method ${u.rawPath}${u.rawQuery?.let { "?$it" } ?: ""} HTTP/1.1\r\nHost: ${u.host}\r\nConnection: close\r\n")
                headers.forEach { (k, v) -> append("$k: $v\r\n") }
                append("Content-Length: ${bytes.size}\r\n\r\n")
            }
            sock.outputStream.apply { write(head.toByteArray()); write(bytes); flush() }
            val raw = sock.inputStream.readBytes()
            val split = String(raw, Charsets.ISO_8859_1).indexOf("\r\n\r\n")
            val lines = String(raw, 0, split, Charsets.ISO_8859_1).split("\r\n")
            val code = lines[0].split(" ")[1].toInt()
            var rest = raw.copyOfRange(split + 4, raw.size)
            if (lines.any { it.lowercase().replace(" ", "") == "transfer-encoding:chunked" }) {
                val out = java.io.ByteArrayOutputStream(); var i = 0
                while (true) {
                    val eol = (i until rest.size - 1).first { rest[it] == '\r'.code.toByte() && rest[it + 1] == '\n'.code.toByte() }
                    val n = String(rest, i, eol - i, Charsets.ISO_8859_1).substringBefore(';').trim().toInt(16)
                    if (n == 0) break
                    out.write(rest, eol + 2, n); i = eol + 2 + n + 2
                }
                rest = out.toByteArray()
            }
            return code to String(rest, Charsets.UTF_8)
        }
    }
}

/** The real relay, for the RELAY_LIVE=1 tests only. The app keeps its copy in `Servers`. */
private val LIVE = RelayConfig("https://omemognwvcnonnzjmcxm.supabase.co", "sb_publishable_prXq51_BMc8lnG4BY5vXmA_xJysoZxa")

class RelayTest {
    private fun log(id: String, status: String = "pending") =
        ChoreLog(id, null, "1", "kid", "make-bed", "make bed", 8, 5, status, 1_731_700_000_123L)

    private fun family(): Triple<MemoryRelay, Relay, Relay> {
        val server = MemoryRelay()
        val a = Relay(FamilyKeys.generate(), MemorySessionStore(), MemoryRelay.CONFIG, http = server)
        a.createHousehold()
        val scanned = JoinCode.parse(a.makeJoinCode().first.text)
        val b = Relay(scanned.keys, MemorySessionStore(), MemoryRelay.CONFIG, http = server)
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
        val stranger = Relay(a.keys, MemorySessionStore(), MemoryRelay.CONFIG, http = server)
        assertTrue(stranger.selectAll().isEmpty())
        try { stranger.insert(log("evil")); fail() } catch (e: HttpStatusException) { assertEquals(403, e.code) }
        try { stranger.makeJoinCode(); fail() } catch (e: HttpStatusException) { assertEquals(403, e.code) }
    }

    @Test fun joinCodesWorkOnceAndExpire() {
        val (server, a, _) = family()
        val code = a.makeJoinCode().first
        val c = Relay(code.keys, MemorySessionStore(), MemoryRelay.CONFIG, http = server)
        val d = Relay(code.keys, MemorySessionStore(), MemoryRelay.CONFIG, http = server)
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
        val server = MemoryRelay(); val store = MemorySessionStore()
        var clock = 1_800_000_000_000L
        val a = Relay(FamilyKeys.generate(), store, MemoryRelay.CONFIG, http = server, now = { clock })
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

    /** Against the real DOYOURWORK relay, only when asked: `RELAY_LIVE=1 ./gradlew testPlayDebugUnitTest --tests '*RelayTest*'`. */
    @Test fun relayLive() {
        assumeTrue("set RELAY_LIVE=1 to run against the real relay", System.getenv("RELAY_LIVE") == "1")
        val keys = FamilyKeys.generate()
        val a = Relay(keys, MemorySessionStore(), LIVE)
        a.createHousehold()
        try {
            val (code, expires) = a.makeJoinCode()
            assertTrue(expires > System.currentTimeMillis() + 500_000)
            val b = Relay(JoinCode.parse(code.text).keys, MemorySessionStore(), LIVE)
            assertTrue(b.join(code))
            LogSync.run(a, listOf(log("live-1")))
            StateSync.run(a, mapOf("players" to LocalEntry(listOf("1|kid"), 5, true)))
            assertEquals(listOf("live-1"), LogSync.run(b, emptyList()).map { it.remoteId })
            assertEquals(listOf("1|kid"), StateSync.run(b, emptyMap())["players"]?.items)
            assertTrue(Relay(keys, MemorySessionStore(), LIVE).selectAll().isEmpty())
        } finally { a.deleteHousehold() }
    }
    /**
     * An iPhone and an Android phone in one family, on the real relay. Runs beside the iOS test
     * `testInteropWithAndroid`, handing join codes over through a folder:
     * `INTEROP_DIR=<dir> RELAY_LIVE=1 ./gradlew testPlayDebugUnitTest --tests '*RelayTest.interopWithIos'`.
     * The iPhone makes a family and this phone joins it; then this phone makes one and the iPhone joins.
     */
    @Test fun interopWithIos() {
        val dir = System.getenv("INTEROP_DIR")
        assumeTrue("set INTEROP_DIR to run beside the iOS test", dir != null)
        fun waitFor(name: String): String {
            val f = java.io.File(dir, name)
            repeat(600) { if (f.exists()) return f.readText(); Thread.sleep(500) }
            fail("the iPhone never wrote $name"); error("")
        }
        fun done(name: String, text: String = "ok") { java.io.File(dir, "$name.tmp").apply { writeText(text); renameTo(java.io.File(dir, name)) } }

        // 1. The iPhone's family.
        val code = JoinCode.parse(waitFor("ios-code"))
        val b = Relay(code.keys, MemorySessionStore(), LIVE, http = SocketHttp)
        assertTrue("joins the iPhone's family", b.join(code))
        val pulled = LogSync.run(b, emptyList())
        val fromIos = pulled.single { it.remoteId == "ios-1" }
        assertEquals("make bed", fromIos.choreName)
        assertEquals(1_731_700_000_123L, fromIos.timestamp)
        assertEquals(listOf("1|from-ios"), StateSync.run(b, emptyMap())["players"]?.items)
        LogSync.run(b, pulled.map { if (it.remoteId == "ios-1") it.copy(status = "approved", statusDirty = true) else it } + log("android-1"))
        StateSync.run(b, mapOf("chores" to LocalEntry(listOf("make-bed|from-android"), 6, true)))
        done("android-joined")

        // 2. This phone's family.
        val a = Relay(FamilyKeys.generate(), MemorySessionStore(), LIVE, http = SocketHttp)
        a.createHousehold()
        try {
            LogSync.run(a, listOf(log("android-2")))
            StateSync.run(a, mapOf("players" to LocalEntry(listOf("1|from-android"), 7, true)))
            done("android-code", a.makeJoinCode().first.text)
            waitFor("ios-joined")
            val back = LogSync.run(a, emptyList()).associate { it.remoteId to it.status }
            assertEquals(mapOf("android-2" to "approved", "ios-2" to "pending"), back)
            assertEquals(listOf("make-bed|from-ios"), StateSync.run(a, emptyMap())["chores"]?.items)
            assertEquals(2, a.devices().size)
        } finally { a.deleteHousehold() }
        done("android-finished")
    }
}
