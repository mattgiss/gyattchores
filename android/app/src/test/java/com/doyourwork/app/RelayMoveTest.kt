package com.doyourwork.app

import com.doyourwork.app.engine.AdminCode
import com.doyourwork.app.model.ChoreLog
import com.doyourwork.app.model.Family
import com.doyourwork.app.model.FamilyState
import com.doyourwork.app.model.Player
import com.doyourwork.app.sync.DemoRelayFamily
import com.doyourwork.app.sync.FamilyKeys
import com.doyourwork.app.sync.JoinCode
import com.doyourwork.app.sync.LocalEntry
import com.doyourwork.app.sync.LogSync
import com.doyourwork.app.sync.MemoryRelay
import com.doyourwork.app.sync.MemoryRelayVault
import com.doyourwork.app.sync.Relay
import com.doyourwork.app.sync.StateSync
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Moving a family from the old tables to the encrypted relay, and joining it from another phone. */
class RelayMoveTest {
    private fun log(id: String, remoteId: String?, status: String, dirty: Boolean = false) =
        ChoreLog(id, remoteId, "2", "riley", "make-bed", "make bed", 8, 5, status, 1_731_700_000_000L, statusDirty = dirty)

    @Test fun forNewServerSendsEveryLogAgainUnderItsOwnId() {
        val moved = LogSync.forNewServer(listOf(log("r_abc", "abc", "approved"), log("l2", null, "pending", dirty = true)))
        assertTrue(moved.all { it.remoteId == null && !it.statusDirty })
        assertEquals(listOf("approved", "pending"), moved.map { it.status })
    }

    @Test fun forNewServerMarksEveryEntryDirtyAndKeepsItsDate() {
        val moved = StateSync.forNewServer(mapOf("players" to LocalEntry(listOf("2:riley"), 42, dirty = false)))
        assertEquals(LocalEntry(listOf("2:riley"), 42, dirty = true), moved["players"])
    }

    @Test fun aMovedFamilyReachesThePhoneThatJoins() {
        val server = MemoryRelay()
        val family = Family(members = listOf(Player("1", "pat", isAdmin = true, plays = false), Player("2", "riley")),
            adminCodes = mapOf("1" to AdminCode.make("2468")!!), nextPlayerId = 3)
        // Phone A, as the old tables left it: logs with their old row ids, nothing waiting to go out.
        val logsOnA = listOf(log("r_abc", "abc", "approved"), log("r_def", "def", "pending"))
        val stateOnA = FamilyState.encode(family).mapValues { LocalEntry(it.value, 100) } + ("dare|2|2026-11-17" to LocalEntry(listOf("3:dishes"), 101))

        val a = Relay(FamilyKeys.generate(), MemoryRelayVault().sessions, MemoryRelay.CONFIG, http = server)
        a.createHousehold()
        val syncedA = LogSync.run(a, LogSync.forNewServer(logsOnA))
        StateSync.run(a, StateSync.forNewServer(stateOnA))
        assertEquals(listOf("r_abc", "r_def"), syncedA.map { it.remoteId })

        val code = JoinCode.parse(a.makeJoinCode().first.text)
        val b = Relay(code.keys, MemoryRelayVault().sessions, MemoryRelay.CONFIG, http = server)
        assertTrue(b.join(code))
        val logsOnB = LogSync.run(b, emptyList())
        val stateOnB = StateSync.run(b, emptyMap())
        assertEquals(setOf("approved", "pending"), logsOnB.map { it.status }.toSet())
        val decoded = FamilyState.decode(stateOnB.filterKeys(FamilyState::owns).mapValues { it.value.items }, Family())
        assertEquals(setOf("pat", "riley"), decoded.members.map { it.name }.toSet())
        assertTrue(decoded.adminCodes["1"]!!.matches("2468"))
        assertEquals(listOf("3:dishes"), stateOnB["dare|2|2026-11-17"]?.items)
    }

    @Test fun theSeededFamilyCanBeJoined() {
        val server = MemoryRelay()
        val code = JoinCode.parse(DemoRelayFamily.seed(server))
        val b = Relay(code.keys, MemoryRelayVault().sessions, MemoryRelay.CONFIG, http = server)
        assertTrue(b.join(code))
        assertFalse("a code works once", Relay(code.keys, MemoryRelayVault().sessions, MemoryRelay.CONFIG, http = server).join(code))
        assertEquals(2, LogSync.run(b, emptyList()).size)
        val state = StateSync.run(b, emptyMap())
        val f = FamilyState.decode(state.mapValues { it.value.items }, Family())
        assertEquals(setOf("pat", "riley", "sam"), f.members.map { it.name }.toSet())
        assertTrue(f.isSetUp)
    }

    @Test fun aPhoneCanTellItWasRemovedOrTheFamilyDeleted() {
        val server = MemoryRelay()
        val a = Relay(FamilyKeys.generate(), MemoryRelayVault().sessions, MemoryRelay.CONFIG, http = server)
        a.createHousehold()
        val code = JoinCode.parse(a.makeJoinCode().first.text)
        val b = Relay(code.keys, MemoryRelayVault().sessions, MemoryRelay.CONFIG, http = server)
        assertTrue(b.join(code))
        assertTrue(b.isMember())
        a.removeDevice(b.userId())
        assertFalse("a removed phone can tell", b.isMember())
        assertTrue(a.isMember())
        a.deleteHousehold()
        assertFalse("nobody is in a deleted family", a.isMember())
        val stranger = Relay(code.keys, MemoryRelayVault().sessions, MemoryRelay.CONFIG, http = server)
        assertFalse(stranger.isMember())
    }

    @Test fun clearingTheVaultForgetsKeysAndSignIn() {
        val v = MemoryRelayVault()
        val r = Relay(FamilyKeys.generate(), v.sessions, MemoryRelay.CONFIG, http = MemoryRelay())
        v.saveKeys(r.keys); r.createHousehold()
        assertTrue(v.sessions.load() != null)
        v.clear()
        assertNull(v.loadKeys())
        assertNull(v.sessions.load())
    }

    @Test fun theVaultKeepsKeysAndSession() {
        val v = MemoryRelayVault()
        assertNull(v.loadKeys())
        val k = FamilyKeys.generate(); v.saveKeys(k)
        assertEquals(k, v.loadKeys())
    }
}
