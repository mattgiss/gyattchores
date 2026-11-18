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

/** The real relay, for the RELAY_LIVE=1 test only. The app keeps its copy in the family edition's `Servers`. */
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

    /** Against the real DOYOURWORK relay, only when asked: `RELAY_LIVE=1 ./gradlew testPublicDebugUnitTest --tests '*RelayTest*'`. */
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
}

