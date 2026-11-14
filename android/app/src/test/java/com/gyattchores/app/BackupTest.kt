package com.gyattchores.app

import com.gyattchores.app.engine.AdminCode
import com.gyattchores.app.engine.Backup
import com.gyattchores.app.engine.BackupException
import com.gyattchores.app.engine.BackupFile
import com.gyattchores.app.engine.ChoreIntake
import com.gyattchores.app.model.ChoreLog
import com.gyattchores.app.model.Dare
import com.gyattchores.app.model.Family
import com.gyattchores.app.model.Player
import com.gyattchores.app.model.Status
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.ZoneId

/** Saving a backup and restoring it: on a phone of its own, and into a family that already exists. */
class BackupTest {
    private val zone = ZoneId.of("UTC")
    private val day = 86_400_000L
    private val now = 1_794_411_000_000L
    private val dishes = ChoreIntake.make("do the dishes", 10)
    private val trash = ChoreIntake.make("take out the trash", 4)
    private val code = AdminCode.make("2468", salt = "salt-1")!!

    private fun log(id: String, player: String, name: String, chore: String, at: Long, status: String = Status.APPROVED, remote: String? = null) =
        ChoreLog(id, remote, player, name, chore, chore, 10, 5, status, at)

    /** The phone the backup comes from: pat runs it, riley and sam play. */
    private val home = Family(
        members = listOf(Player("1", "pat", isAdmin = true, plays = false), Player("2", "riley", displayName = "Rex"), Player("3", "sam")),
        adminCodes = mapOf("1" to code),
        chores = listOf(dishes, trash),
        choreAdded = mapOf(dishes.id to now - 30 * day),
        memberJoined = mapOf("2" to now - 30 * day),
        nextPlayerId = 4,
    )
    private val homeLogs = listOf(
        log("a", "2", "riley", dishes.id, now - 2 * day, remote = "r-1"),
        log("b", "3", "sam", trash.id, now - day),
        log("c", "2", "riley", trash.id, now, Status.PENDING),
    )
    private fun backup() = Backup.make(home, home.chores!!, homeLogs, listOf(Dare("2", "3", trash.id, "2026-11-01")),
        mapOf("2" to 4), "android-public", "0.4.0", now)

    @Test fun aBackupRoundTripsThroughItsFile() {
        val b = backup()
        val back = Backup.decode(Backup.encode(b))
        assertEquals(b, back)
        assertEquals(BackupFile.TYPE, back.type)
        assertEquals(1, back.version)
        assertEquals(listOf(BackupFile.Code("1", "salt-1", code.hash)), back.adminCodes)
        assertEquals(2, back.players)
    }

    @Test fun theFileUsesTheAgreedNames() {
        val text = Backup.encode(backup())
        for (key in listOf("\"type\"", "\"version\"", "\"exportedAt\"", "\"source\"", "\"appVersion\"", "\"members\"", "\"adminCodes\"",
            "\"chores\"", "\"choreAdded\"", "\"memberJoined\"", "\"nextPlayerId\"", "\"logs\"", "\"dares\"", "\"puzzleLevels\"",
            "\"isAdmin\"", "\"plays\"", "\"displayName\"", "\"tierDays\"", "\"parentPick\"", "\"remoteId\"")) assertTrue(key, key in text)
        assertEquals("gyattchores-backup-2026-11-14.json", Backup.fileName(java.time.LocalDate.of(2026, 11, 14)))
    }

    @Test fun filesThatArentBackupsAreTurnedAway() {
        assertEquals("this file isn't a GyattChores backup", assertThrows(BackupException::class.java) { Backup.decode("not json") }.message)
        assertThrows(BackupException::class.java) { Backup.decode("""{"type":"something-else","members":[{"id":"1","name":"a","isAdmin":true}]}""") }
        val newer = assertThrows(BackupException::class.java) {
            Backup.decode("""{"type":"gyattchores-backup","version":2,"members":[{"id":"1","name":"a","isAdmin":true}]}""")
        }
        assertTrue(newer.message!!.contains("newer version"))
        // A backup with nobody in charge reads, but the public app won't put it in place of what it has.
        val noAdmin = Backup.decode("""{"type":"gyattchores-backup","version":1,"members":[{"id":"1","name":"a"}]}""")
        assertEquals("this backup has no admin, so it can't be restored here. nothing changed.", Backup.replaceProblem(noAdmin))
        assertNull(Backup.replaceProblem(backup()))
        // Keys a later version adds are ignored.
        val extra = Backup.encode(backup()).replaceFirst("{", """{"somethingNew":[1,2,3],""")
        assertEquals(backup().members, Backup.decode(extra).members)
    }

    @Test fun aMinimalBackupFromAnotherAppStillReads() {
        // Only what's required, optional fields left out, as another app might write it.
        val b = Backup.decode("""{"type":"gyattchores-backup","version":1,"id":"x","exportedAt":1,"source":"ios-public",
            "members":[{"id":"1","name":"pat","isAdmin":true,"plays":false},{"id":"2","name":"riley","isAdmin":false,"plays":true}],
            "adminCodes":[{"id":"1","salt":"s","hash":4294967295}],
            "chores":[{"id":"dishes","name":"dishes","cat":"kitchen","pts":25,"tiers":[10,15,20],"tierDays":[0,3,7]}],
            "logs":[{"id":"l","playerId":"2","playerName":"riley","choreId":"dishes","choreName":"dishes","points":25,"status":"approved","timestamp":5}]}""")
        assertEquals(4294967295L, b.adminCodes[0].hash)
        assertNull(b.logs[0].minutes)
        assertFalse(b.logs[0].parentPick)
        assertEquals(emptyMap<String, Int>(), b.puzzleLevels)
    }

    @Test fun restoringOnAPhoneOfItsOwnReplacesEverything() {
        val r = Backup.replace(backup())
        assertEquals(home.members, r.family.members)
        assertTrue(r.family.adminCodes["1"]!!.matches("2468"))
        assertEquals(home.chores, r.family.chores)
        assertEquals(homeLogs.map { it.copy(remoteId = null) }, r.logs)
        assertEquals(mapOf("2" to 4), r.puzzleLevels)
        assertEquals(listOf(Dare("2", "3", trash.id, "2026-11-01")), r.dares)
        assertEquals(4, r.family.nextPlayerId)
        assertEquals("2 players, 2 chores, 3 chores logged", r.counts.describe())
    }

    /** The family it's merged into: jo is the admin; riley is already here under another id, with one chore in common. */
    private val family = Family(
        members = listOf(Player("10", "jo", isAdmin = true), Player("11", "RILEY")),
        adminCodes = mapOf("10" to AdminCode.make("9999", salt = "salt-2")!!),
        chores = listOf(ChoreIntake.make("Do The Dishes", 12).copy(id = "kitchen-dishes"), ChoreIntake.make("feed the cat", 3).copy(id = trash.id)),
        nextPlayerId = 12,
    )
    private val familyLogs = listOf(log("f1", "11", "RILEY", "kitchen-dishes", now - 2 * day + 3_600_000))

    @Test fun mergingMatchesPeopleByUsernameAndKeepsTheFamilysAdmins() {
        val m = Backup.merge(family, family.chores!!, familyLogs, emptyMap(), backup(), zone, now)
        val byName = m.family.members.associateBy { it.name.lowercase() }
        assertEquals("11", byName.getValue("riley").id)          // matched, not duplicated
        assertEquals("RILEY", byName.getValue("riley").name)     // the family's spelling stays
        assertEquals("12", byName.getValue("pat").id)            // new people get fresh ids
        assertEquals("13", byName.getValue("sam").id)
        assertEquals(14, m.family.nextPlayerId)
        assertFalse("the family already has an admin, so pat comes in as a player", byName.getValue("pat").isAdmin)
        assertTrue(byName.getValue("pat").plays)
        assertEquals(setOf("10"), m.family.adminCodes.keys)
        assertTrue(m.family.adminCodes.getValue("10").matches("9999"))
    }

    @Test fun mergingMapsChoresByNameThenId() {
        val m = Backup.merge(family, family.chores!!, familyLogs, emptyMap(), backup(), zone, now)
        val chores = m.family.chores!!
        // "do the dishes" is already on the list as kitchen-dishes; "take out the trash" has an id the family uses for something else.
        assertEquals(3, chores.size)
        val trashHere = chores.single { it.name == "take out the trash" }
        assertTrue(trashHere.id != trash.id)
        assertEquals(1, m.counts.chores)
        val sams = m.newLogs.single { it.playerId == "13" }
        assertEquals(trashHere.id, sams.choreId)
    }

    @Test fun mergingSkipsWhatTheFamilyAlreadyHas() {
        val m = Backup.merge(family, family.chores!!, familyLogs, emptyMap(), backup(), zone, now)
        // riley's dishes two days ago is already in the family's history (same person, chore and day).
        assertEquals(2, m.newLogs.size)
        assertTrue(m.newLogs.none { it.playerId == "11" && it.choreId == "kitchen-dishes" })
        val pending = m.newLogs.single { it.playerId == "11" }
        assertEquals(Status.PENDING, pending.status)            // a log waiting on an admin still waits
        assertEquals(now, pending.timestamp)                     // and keeps its own date
        assertTrue(m.newLogs.all { it.remoteId == null })        // so sync pushes them
        // A log the server already has is never added twice, wherever it came from.
        val withRemote = familyLogs + log("x", "11", "RILEY", "z", 0, remote = "r-1")
        assertTrue(Backup.merge(family, family.chores!!, withRemote, emptyMap(), backup(), zone, now).newLogs.none { it.timestamp == now - 2 * day })
    }

    @Test fun aFamilyWithNoAdminTakesTheBackupsAdmins() {
        // What the family looked like before admins existed: players from 0.3.x, nobody in charge.
        val old = Family(members = listOf(Player("1", "bekindhearted"), Player("2", "riley")), nextPlayerId = 3)
        val m = Backup.merge(old, emptyList(), emptyList(), emptyMap(), backup(), zone, now)
        val pat = m.family.members.single { it.name == "pat" }
        assertTrue(pat.isAdmin)
        assertFalse(pat.plays)
        assertTrue(m.family.adminCodes.getValue(pat.id).matches("2468"))
        assertTrue(m.family.isSetUp)
        assertEquals("2", m.family.members.single { it.name == "riley" }.id)
    }

    @Test fun someoneRemovedFromTheFamilyComesBackAsSomeoneNew() {
        val f = family.copy(removed = setOf("3"))
        val m = Backup.merge(f, f.chores!!, familyLogs, emptyMap(), backup(), zone, now)
        val sam = m.family.members.single { it.name == "sam" }
        assertFalse(sam.id == "3")
        assertTrue(m.newLogs.any { it.playerId == sam.id })
    }

    @Test fun aMergeSaysWhatWasNewAndWhatWasAlreadyHere() {
        val m = Backup.merge(family, family.chores!!, familyLogs, emptyMap(), backup(), zone, now)
        // riley was here; pat and sam are new. dishes matched by name; trash came in under a fresh id.
        assertEquals("2 players added (1 already here), 1 chore added (1 already here), 2 chores logged", m.counts.describe())
        val again = Backup.merge(m.family, m.family.chores!!, familyLogs + m.newLogs, emptyMap(), backup(), zone, now)
        assertEquals("no new players (2 already here), no new chores (2 already here), 0 chores logged", again.counts.describe())
    }

    @Test fun puzzleLevelsKeepTheHigherOfTheTwo() {
        val m = Backup.merge(family, family.chores!!, familyLogs, mapOf("11" to 2), backup(), zone, now)
        assertEquals(4, m.puzzleLevels["11"])
        val m2 = Backup.merge(family, family.chores!!, familyLogs, mapOf("11" to 9), backup(), zone, now)
        assertEquals(9, m2.puzzleLevels["11"])
    }

    @Test fun mergingTheSameBackupTwiceAddsNothingTheSecondTime() {
        val m = Backup.merge(family, family.chores!!, familyLogs, emptyMap(), backup(), zone, now)
        val again = Backup.merge(m.family, m.family.chores!!, familyLogs + m.newLogs, emptyMap(), backup(), zone, now)
        assertEquals(0, again.newLogs.size)
        assertEquals(0, again.counts.players)
        assertEquals(0, again.counts.chores)
        assertEquals(m.family.members, again.family.members)
    }

    // ─── A real backup made by the iOS app ──────────────────────────────────

    private val ios by lazy { Backup.decode(java.io.File("src/test/resources/backup-ios.json").readText()) }
    /** The iOS simulator that made it keeps Mountain time. */
    private val denver = ZoneId.of("America/Denver")

    @Test fun aBackupFromTheIosAppRestoresHere() {
        assertEquals("ios-public", ios.source)
        val r = Backup.replace(ios)
        assertEquals(listOf("pat", "riley", "sam"), r.family.members.map { it.name })
        val pat = r.family.members.single { it.name == "pat" }
        assertTrue(pat.isAdmin); assertFalse(pat.plays)
        assertTrue("pat's iOS code opens the Android app", r.family.adminCodes.getValue(pat.id).matches("2468"))
        assertEquals(27, r.family.chores!!.size)
        assertEquals(292, r.logs.size)
        assertEquals(286, r.logs.count { it.status == Status.APPROVED })
        assertEquals(6, r.logs.count { it.status == Status.PENDING })
        assertEquals("2 players, 27 chores, 292 chores logged", r.counts.describe())

        // The numbers the iOS app showed when it was saved.
        val today = com.gyattchores.app.engine.Engine.dayOf(ios.exportedAt, denver)
        fun id(n: String) = r.family.members.single { it.name == n }.id
        val e = com.gyattchores.app.engine.Engine
        assertEquals(384, e.weekPoints(id("riley"), r.logs, emptyList(), today, denver))
        assertEquals(232, e.weekPoints(id("sam"), r.logs, emptyList(), today, denver))
        val days = e.recentDays(ios.exportedAt, denver)
        fun hits(n: String) = e.minutesByDay(id(n), r.logs, r.family.chores!!.associateBy { it.id }, denver).let { m ->
            days.count { (m[it] ?: 0) >= e.DAILY_MINUTES } }
        assertEquals(27, hits("riley"))
        assertEquals(15, hits("sam"))
    }

    @Test fun anIosBackupMergesIntoAnAndroidFamilyAndSavesBackTheSame() {
        val m = Backup.merge(family, family.chores!!, familyLogs, emptyMap(), ios, denver, ios.exportedAt)
        assertEquals("11", m.family.members.single { it.name.equals("riley", true) }.id)
        assertTrue(m.newLogs.size in 280..292)
        // An Android backup of the restored phone reads back to the same game.
        val r = Backup.replace(ios)
        val again = Backup.decode(Backup.encode(Backup.make(r.family, r.family.chores!!, r.logs, emptyList(), r.puzzleLevels,
            "android-public", "0.4.0", ios.exportedAt)))
        assertEquals(ios.members, again.members)
        assertEquals(ios.chores, again.chores)
        assertEquals(ios.logs.map { it.copy(remoteId = null) }, again.logs)
    }
}
