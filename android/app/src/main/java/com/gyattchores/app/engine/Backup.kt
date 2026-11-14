package com.gyattchores.app.engine

import com.gyattchores.app.model.Chore
import com.gyattchores.app.model.ChoreLog
import com.gyattchores.app.model.Dare
import com.gyattchores.app.model.Family
import com.gyattchores.app.model.Player
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.ZoneId
import java.util.UUID

/**
 * A backup of a family's game: who's in it, their codes, the chore list and every chore logged.
 * One format for both apps, so a backup made on an iPhone restores on Android and back again.
 * JSON, saved as "gyattchores-backup-YYYY-MM-DD.json" (phones preview .json and pickers accept it
 * without a custom type). Times are epoch millis.
 */
@Serializable
data class BackupFile(
    val type: String = TYPE,
    val version: Int = VERSION,
    /** New for every export, so restoring the same file twice into a family can be spotted. */
    val id: String = UUID.randomUUID().toString(),
    val exportedAt: Long = 0,
    /** "ios-public", "ios-family", "android-public" or "android-family". */
    val source: String = "",
    val appVersion: String = "",
    val members: List<Player> = emptyList(),
    val adminCodes: List<Code> = emptyList(),
    val chores: List<Chore> = emptyList(),
    val choreAdded: Map<String, Long> = emptyMap(),
    val memberJoined: Map<String, Long> = emptyMap(),
    val nextPlayerId: Int = 1,
    val logs: List<Log> = emptyList(),
    val dares: List<BDare> = emptyList(),
    val puzzleLevels: Map<String, Int> = emptyMap(),
) {
    @Serializable data class Code(val id: String, val salt: String, val hash: Long)

    @Serializable
    data class Log(
        val id: String, val remoteId: String? = null, val playerId: String, val playerName: String,
        val choreId: String, val choreName: String, val points: Int, val minutes: Int? = null,
        val status: String, val timestamp: Long, val parentPick: Boolean = false,
    )

    @Serializable data class BDare(val from: String, val target: String, val choreId: String, val day: String)

    val players get() = members.count { it.plays }

    companion object {
        const val TYPE = "gyattchores-backup"
        const val VERSION = 1
        const val EXTENSION = "json"
        const val MIME = "application/json"
    }
}

/** Why a file couldn't be read as a backup; [message] is said to the person restoring it. */
class BackupException(message: String) : Exception(message)

/** What a restore brought in, for the "here's what came in" message. */
data class RestoreCounts(val players: Int, val chores: Int, val logs: Int) {
    fun describe() = "${n(players, "player")}, ${n(chores, "chore")}, ${n(logs, "chore")} logged"
    private fun n(k: Int, w: String) = "$k $w${if (k == 1) "" else "s"}"
}

object Backup {
    private val json = Json { ignoreUnknownKeys = true; explicitNulls = false; encodeDefaults = true }

    fun fileName(date: java.time.LocalDate) = "gyattchores-backup-$date.${BackupFile.EXTENSION}"

    fun encode(b: BackupFile): String = json.encodeToString(b)

    /** Reads a backup, or throws [BackupException] saying what's wrong with it. */
    fun decode(text: String): BackupFile {
        val b = try { json.decodeFromString<BackupFile>(text) } catch (e: Exception) {
            throw BackupException("this file isn't a GyattChores backup")
        }
        if (b.type != BackupFile.TYPE) throw BackupException("this file isn't a GyattChores backup")
        if (b.version > BackupFile.VERSION) throw BackupException("this backup is from a newer version of the app. update the app and try again")
        return b
    }

    /** Why the public app can't restore [b] in place of what it has, or null if it can. Same wording as iOS. */
    fun replaceProblem(b: BackupFile): String? =
        if (b.members.none { m -> m.isAdmin && b.adminCodes.any { it.id == m.id } })
            "this backup has no admin, so it can't be restored here. nothing changed." else null

    /** Everything this phone knows, as a backup. */
    fun make(family: Family, pool: List<Chore>, logs: List<ChoreLog>, dares: List<Dare>, puzzleLevels: Map<String, Int>,
             source: String, appVersion: String, now: Long) = BackupFile(
        exportedAt = now, source = source, appVersion = appVersion,
        members = family.members,
        adminCodes = family.adminCodes.filterKeys { id -> family.admins.any { it.id == id } }
            .map { (id, c) -> BackupFile.Code(id, c.salt, c.hash) },
        chores = pool, choreAdded = family.choreAdded, memberJoined = family.memberJoined,
        nextPlayerId = family.nextPlayerId,
        logs = logs.map { BackupFile.Log(it.id, it.remoteId, it.playerId, it.playerName, it.choreId, it.choreName,
            it.points, it.minutes, it.status, it.timestamp, it.parentPick) },
        dares = dares.map { BackupFile.BDare(it.from, it.target, it.choreId, it.day) },
        puzzleLevels = puzzleLevels,
    )

    /** The public app's restore: the backup replaces everything on the phone. Check [replaceProblem] first. */
    data class Replaced(val family: Family, val logs: List<ChoreLog>, val dares: List<Dare>, val puzzleLevels: Map<String, Int>, val counts: RestoreCounts)

    fun replace(b: BackupFile): Replaced {
        val ids = (b.members.map { it.id } + b.logs.map { it.playerId }).mapNotNull { it.toIntOrNull() }
        val family = Family(
            members = b.members,
            adminCodes = b.adminCodes.filter { c -> b.members.any { it.id == c.id && it.isAdmin } }
                .associate { it.id to AdminCode(it.salt, it.hash) },
            chores = b.chores.ifEmpty { null },
            choreAdded = b.choreAdded, memberJoined = b.memberJoined,
            nextPlayerId = maxOf(b.nextPlayerId, (ids.maxOrNull() ?: 0) + 1),
        )
        val logs = b.logs.map { ChoreLog(it.id, null, it.playerId, it.playerName, it.choreId, it.choreName,
            it.points, it.minutes, it.status, it.timestamp, it.parentPick) }
        // Dares come along: the public app makes none, but the points the settled ones earned still count.
        val dares = b.dares.map { Dare(it.from, it.target, it.choreId, it.day) }
        return Replaced(family, logs, dares, b.puzzleLevels, RestoreCounts(b.players, b.chores.size, logs.size))
    }

    /** A family restore: what to add to the family and its logs. */
    data class Merged(val family: Family, val newLogs: List<ChoreLog>, val puzzleLevels: Map<String, Int>, val counts: RestoreCounts)

    /**
     * Merges a backup into a family that may already have players and history. Members are
     * matched by username; chores by name, then id; logs are skipped when the family already has
     * them (same server row, or the same person doing the same chore on the same day). The
     * family's admins and codes are never changed — unless it has none yet, when the backup's
     * admins come in with their codes. Dares aren't merged. Puzzle levels take the higher of the two.
     */
    fun merge(family: Family, pool: List<Chore>, logs: List<ChoreLog>, puzzleLevels: Map<String, Int>,
              b: BackupFile, zone: ZoneId, now: Long): Merged {
        val adoptAdmins = !family.isSetUp
        val members = family.members.toMutableList()
        val codes = family.adminCodes.toMutableMap()
        val joined = family.memberJoined.toMutableMap()
        var next = family.nextPlayerId
        val backupCodes = b.adminCodes.associateBy { it.id }
        val playerMap = HashMap<String, String>()
        var playersAdded = 0
        for (m in b.members) {
            val i = members.indexOfFirst { it.name.equals(m.name, ignoreCase = true) }
            val bringAdmin = adoptAdmins && m.isAdmin && backupCodes[m.id] != null
            val id: String
            if (i >= 0) {
                id = members[i].id
                if (bringAdmin) members[i] = members[i].copy(isAdmin = true)
            } else {
                id = (next++).toString()
                // Someone coming in without being an admin has to play, or they'd have no part in the game.
                members += Player(id, m.name, m.displayName, isAdmin = bringAdmin, plays = m.plays || !bringAdmin)
                joined[id] = b.memberJoined[m.id] ?: now
                if (m.plays || !bringAdmin) playersAdded++
            }
            if (bringAdmin) backupCodes[m.id]?.let { codes[id] = AdminCode(it.salt, it.hash) }
            playerMap[m.id] = id
        }
        // Logs from someone no longer in the backup's member list still need a home.
        for (l in b.logs) if (l.playerId !in playerMap) {
            val i = members.indexOfFirst { it.name.equals(l.playerName, ignoreCase = true) }
            playerMap[l.playerId] = if (i >= 0) members[i].id else {
                val id = (next++).toString()
                members += Player(id, l.playerName); joined[id] = now; playersAdded++
                id
            }
        }

        val chores = pool.toMutableList()
        val added = family.choreAdded.toMutableMap()
        val choreMap = HashMap<String, String>()
        var choresAdded = 0
        for (c in b.chores) {
            val same = chores.firstOrNull { it.name.equals(c.name, ignoreCase = true) }
            if (same != null) { choreMap[c.id] = same.id; continue }
            val ids = chores.map { it.id }.toSet()
            val chore = if (c.id in ids) c.copy(id = ChoreIntake.make(c.name, c.tiers.firstOrNull() ?: 5, ids).id) else c
            chores += chore; choreMap[c.id] = chore.id; choresAdded++
            added[chore.id] = b.choreAdded[c.id] ?: now
        }

        val names = members.associate { it.id to it.name }
        val haveRemote = logs.mapNotNull { it.remoteId }.toHashSet()
        val haveDay = logs.map { Triple(it.playerId, it.choreId, Engine.dayOf(it.timestamp, zone)) }.toHashSet()
        val newLogs = ArrayList<ChoreLog>()
        for (l in b.logs) {
            if (l.remoteId != null && l.remoteId in haveRemote) continue
            val pid = playerMap.getValue(l.playerId)
            val cid = choreMap[l.choreId] ?: l.choreId
            if (!haveDay.add(Triple(pid, cid, Engine.dayOf(l.timestamp, zone)))) continue
            newLogs += ChoreLog(UUID.randomUUID().toString(), null, pid, names.getValue(pid), cid, l.choreName,
                l.points, l.minutes, l.status, l.timestamp, l.parentPick)
        }

        val levels = puzzleLevels.toMutableMap()
        for ((id, lvl) in b.puzzleLevels) playerMap[id]?.let { levels[it] = maxOf(levels[it] ?: 1, lvl) }

        val merged = family.copy(
            members = members, adminCodes = codes, memberJoined = joined,
            chores = if (choresAdded > 0) chores else family.chores,
            choreAdded = added, nextPlayerId = next,
        )
        return Merged(merged, newLogs, levels, RestoreCounts(playersAdded, choresAdded, newLogs.size))
    }
}
