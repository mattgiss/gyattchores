package com.gyattchores.app

import com.gyattchores.app.model.ChoreLog
import com.gyattchores.app.sync.LocalPick
import com.gyattchores.app.sync.LogApi
import com.gyattchores.app.sync.LogSync
import com.gyattchores.app.sync.PickSync
import com.gyattchores.app.sync.PicksApi
import com.gyattchores.app.sync.RemoteLog
import com.gyattchores.app.sync.RemotePick
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SyncTest {
    /** An in-memory stand-in for the `simple_logs` table. */
    private class FakeLogs : LogApi {
        val rows = LinkedHashMap<String, RemoteLog>()
        var next = 1
        override fun insert(log: ChoreLog): RemoteLog {
            val r = RemoteLog("srv${next++}", log.playerId, log.playerName, log.choreId, log.choreName, log.points, log.status, 5_000L + next)
            rows[r.id] = r; return r
        }
        override fun updateStatus(remoteId: String, status: String): Boolean {
            val r = rows[remoteId] ?: return false
            rows[remoteId] = r.copy(status = status); return true
        }
        override fun selectAll() = rows.values.toList()
    }

    private fun local(id: String, status: String = "pending", remoteId: String? = null, dirty: Boolean = false, minutes: Int? = 5) =
        ChoreLog(id, remoteId, "1", "kid", "make-bed", "make bed", 8, minutes, status, 1_000L, statusDirty = dirty)

    @Test fun pushesNewLogsOnceAndKeepsLocalFields() {
        val api = FakeLogs()
        val first = LogSync.run(api, listOf(local("a")))
        assertEquals(1, api.rows.size)
        assertEquals("srv1", first.single().remoteId)
        assertEquals(5, first.single().minutes) // local-only field survives
        val second = LogSync.run(api, first)
        assertEquals("a second pass must not insert again", 1, api.rows.size)
        assertEquals(1, second.size)
    }

    @Test fun pullsRowsFromOtherDevices() {
        val api = FakeLogs()
        api.rows["x"] = RemoteLog("x", "2", "other", "scrub-toilet", "scrub toilet", 20, "approved", 9_000L)
        val out = LogSync.run(api, emptyList())
        assertEquals("r_x", out.single().id)
        assertNull(out.single().minutes)
        assertEquals("approved", out.single().status)
    }

    @Test fun pushesApprovalAndClearsDirty() {
        val api = FakeLogs()
        api.rows["x"] = RemoteLog("x", "1", "kid", "make-bed", "make bed", 8, "pending", 1_000L)
        val out = LogSync.run(api, listOf(local("a", "approved", remoteId = "x", dirty = true)))
        assertEquals("approved", api.rows.getValue("x").status)
        assertFalse(out.single().statusDirty)
    }

    @Test fun remoteApprovalReachesTheKidsPhone() {
        val api = FakeLogs()
        api.rows["x"] = RemoteLog("x", "1", "kid", "make-bed", "make bed", 8, "approved", 1_000L)
        val out = LogSync.run(api, listOf(local("a", "pending", remoteId = "x")))
        assertEquals("approved", out.single().status)
    }

    @Test fun unpushedLocalChangeBeatsRemoteStatus() {
        val api = object : LogApi by FakeLogs() {
            override fun updateStatus(remoteId: String, status: String) = false // server dropped it
            override fun selectAll() = listOf(RemoteLog("x", "1", "kid", "make-bed", "make bed", 8, "pending", 1_000L))
        }
        val out = LogSync.run(api, listOf(local("a", "rejected", remoteId = "x", dirty = true)))
        assertEquals("rejected", out.single().status)
        assertTrue(out.single().statusDirty)
    }

    @Test fun recreatesRowWhenServerLostIt() {
        val api = FakeLogs() // empty table: "x" no longer exists
        val out = LogSync.run(api, listOf(local("a", "approved", remoteId = "x", dirty = true)))
        assertEquals("approved", api.rows.values.single().status)
        assertEquals(api.rows.keys.single(), out.single().remoteId)
        assertFalse(out.single().statusDirty)
    }

    @Test fun reconcileKeepsWorkDoneDuringThePass() {
        val synced = listOf(local("a", "pending", remoteId = "x"))
        val latest = listOf(local("a", "approved", remoteId = "x", dirty = true), local("b"))
        val out = LogSync.reconcile(synced, latest)
        assertEquals(2, out.size)
        val a = out.first { it.id == "a" }
        assertEquals("approved", a.status); assertTrue(a.statusDirty)
    }

    private class FakePicks : PicksApi {
        val rows = HashMap<String, RemotePick>()
        override fun upsertPick(pick: RemotePick) { rows["${pick.playerId}|${pick.day}"] = pick }
        override fun selectPicks(fromDay: String) = rows.values.filter { it.day >= fromDay }
    }

    @Test fun picksPushThenPullNewerWins() {
        val api = FakePicks()
        val day = "2026-11-10"
        val mine = PickSync.run(api, mapOf("1|$day" to LocalPick(listOf("make-bed"), 100, dirty = true)), day)
        assertEquals(listOf("make-bed"), api.rows.getValue("1|$day").choreIds)
        assertFalse(mine.getValue("1|$day").dirty)
        // Another phone changes it later; and has a pick for a kid we have none for.
        api.rows["1|$day"] = RemotePick("1", day, listOf("scrub-toilet"), 200)
        api.rows["2|$day"] = RemotePick("2", day, listOf("dog-poop"), 150)
        val pulled = PickSync.run(api, mine, day)
        assertEquals(listOf("scrub-toilet"), pulled.getValue("1|$day").choreIds)
        assertEquals(listOf("dog-poop"), pulled.getValue("2|$day").choreIds)
    }

    @Test fun clearedPicksSyncAsEmpty() {
        val api = FakePicks()
        val day = "2026-11-10"
        PickSync.run(api, mapOf("1|$day" to LocalPick(emptyList(), 300, dirty = true)), day)
        assertTrue(api.rows.getValue("1|$day").choreIds.isEmpty())
    }
}
