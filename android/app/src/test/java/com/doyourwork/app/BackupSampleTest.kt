package com.doyourwork.app

import com.doyourwork.app.engine.AdminCode
import com.doyourwork.app.engine.Backup
import com.doyourwork.app.engine.BackupFile
import com.doyourwork.app.engine.ChoreIntake
import com.doyourwork.app.engine.Engine
import com.doyourwork.app.model.Chore
import com.doyourwork.app.model.ChoreLog
import com.doyourwork.app.model.Dare
import com.doyourwork.app.model.Family
import com.doyourwork.app.model.Player
import com.doyourwork.app.model.Status
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.ZoneId

/**
 * A backup written by Android's own encoder, for the iOS app to restore (the other half of the
 * cross-platform check; `backup-ios.json` is the first). Written to
 * `build/backup-samples/android-family-backup.json` on every run, and checked against the copy
 * kept in test resources so the format can't drift unnoticed. That copy predates the rename and
 * keeps the old type, so it also stands in for every Android backup made before it.
 *
 * The family: mom is a playing admin (code 1357); kai has a display name; lena plays. Besides
 * five starter chores there's "feed the fish", whose id is the starter list's "make-bed", so a
 * merge into a family on the starter list has to give it a fresh id.
 */
class BackupSampleTest {
    private val zone = ZoneId.of("America/Denver")
    /** Sat 14 Nov 2026, 12:00 in Denver. */
    private val now = 1_794_682_800_000L
    private val day = 86_400_000L
    private val starter: List<Chore> = Json { ignoreUnknownKeys = true }.decodeFromString(File("src/main/assets/chores.json").readText())

    private fun sample(): String {
        val pick = listOf("load-dishwasher", "wipe-counters", "sweep-kitchen", "scrub-toilet", "empty-kitchen-trash")
            .map { id -> starter.single { it.id == id } }
        val fish = ChoreIntake.make("feed the fish", 3, id = "make-bed")
        val chores = pick + fish
        val family = Family(
            members = listOf(
                Player("1", "mom", isAdmin = true, plays = true),
                Player("2", "kai", displayName = "Kai 🦖"),
                Player("3", "lena"),
            ),
            adminCodes = mapOf("1" to AdminCode.make("1357", salt = "A0D1F2E3-0000-4000-8000-ANDROIDSAMPLE")!!),
            chores = chores,
            choreAdded = chores.associate { it.id to now - 20 * day },
            memberJoined = mapOf("1" to now - 20 * day, "2" to now - 20 * day, "3" to now - 20 * day),
            nextPlayerId = 4,
        )
        val logs = ArrayList<ChoreLog>()
        var n = 0
        fun log(player: Player, chore: Chore, daysAgo: Int, status: String = Status.APPROVED, minute: Int = 0) {
            logs += ChoreLog("android-log-${n++}", null, player.id, player.name, chore.id, chore.name, chore.pts, chore.tiers[0],
                status, now - daysAgo * day - 3 * 3_600_000L + minute * 60_000L)
        }
        val (mom, kai, lena) = family.members
        // kai: a full day (26 minutes) on each of the last six days, plus today's still waiting on an admin.
        for (d in 1..6) {
            log(kai, pick[0], d); log(kai, pick[2], d, minute = 1); log(kai, pick[3], d, minute = 2)
            log(kai, pick[1], d, minute = 3); log(kai, pick[4], d, minute = 4); log(kai, fish, d, minute = 5)
        }
        log(kai, fish, 0, Status.PENDING); log(kai, pick[0], 0, Status.PENDING, 1)
        // lena: hit and miss, with one rejected chore.
        for (d in listOf(2, 4, 9)) { log(lena, pick[4], d); log(lena, fish, d, minute = 1) }
        log(lena, pick[1], 3, Status.REJECTED)
        // mom plays too.
        log(mom, pick[2], 1); log(mom, pick[3], 1, minute = 1)
        val b = Backup.make(family, chores, logs, listOf(Dare("2", "3", fish.id, "2026-11-12")), mapOf("2" to 3),
            "android-family", "0.4.0", now).copy(id = "android-sample-0001")
        return Backup.encode(b)
    }

    @Test fun writesTheAndroidSampleAndItMatchesTheKeptCopy() {
        val text = sample()
        File("build/backup-samples").mkdirs()
        File("build/backup-samples/android-family-backup.json").writeText(text)
        // The kept copy was written before the rename, so it says the old type; apart from that
        // one value the format must not have moved.
        val kept = File("src/test/resources/backup-android.json").readText()
        assertTrue(kept.startsWith("""{"type":"${BackupFile.LEGACY_TYPE}","""))
        assertTrue(text.startsWith("""{"type":"${BackupFile.TYPE}","""))
        assertEquals(kept.replaceFirst(BackupFile.LEGACY_TYPE, BackupFile.TYPE), text)
    }

    @Test fun theKeptPreRenameCopyStillRestores() {
        val old = Backup.decode(File("src/test/resources/backup-android.json").readText())
        assertEquals(BackupFile.LEGACY_TYPE, old.type)
        assertEquals(Backup.replace(Backup.decode(sample())).family, Backup.replace(old).family)
    }

    @Test fun theSampleScoresAsDescribed() {
        val r = Backup.replace(Backup.decode(sample()))
        val today = Engine.dayOf(now, zone)
        val days = Engine.recentDays(now, zone)
        val pool = r.family.chores!!.associateBy { it.id }
        fun week(id: String) = Engine.weekPoints(id, r.logs, r.dares, today, zone)
        fun hits(id: String) = Engine.minutesByDay(id, r.logs, pool, zone).let { m -> days.count { (m[it] ?: 0) >= Engine.DAILY_MINUTES } }
        val got = listOf("1", "2", "3").associateWith { "week ${week(it)}, daily ${hits(it)}/${days.size}" }
        println("android sample: $got")
        assertEquals(mapOf("1" to "week 35, daily 0/30", "2" to "week 400, daily 6/30", "3" to "week 41, daily 0/30"), got)
        assertTrue(r.family.adminCodes.getValue("1").matches("1357"))
        assertEquals("Kai 🦖", r.family.members[1].shownName)
        assertEquals(47, r.logs.size)
        // kai dared lena would feed the fish on the 12th, and she did: +10 for kai, +5 for lena.
        assertEquals(1, r.dares.size)
        assertEquals(mapOf("2" to 390, "3" to 36), listOf("2", "3").associateWith { Engine.weekPoints(it, r.logs, emptyList(), today, zone) })
    }
}
