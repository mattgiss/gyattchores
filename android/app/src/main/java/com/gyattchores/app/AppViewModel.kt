package com.gyattchores.app

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import com.gyattchores.app.data.Store
import com.gyattchores.app.engine.Engine
import com.gyattchores.app.engine.PuzzlePack
import com.gyattchores.app.engine.AdminCode
import com.gyattchores.app.engine.Backup
import com.gyattchores.app.engine.BackupFile
import com.gyattchores.app.engine.RestoreCounts
import com.gyattchores.app.engine.ChoreIntake
import com.gyattchores.app.engine.DisplayName
import com.gyattchores.app.model.Card
import com.gyattchores.app.model.Chore
import com.gyattchores.app.model.ChoreLog
import com.gyattchores.app.model.EnrichedChore
import com.gyattchores.app.model.Player
import com.gyattchores.app.model.Status
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import androidx.lifecycle.viewModelScope
import com.gyattchores.app.sync.HttpStatusException
import com.gyattchores.app.sync.LogSync
import com.gyattchores.app.sync.StateSync
import com.gyattchores.app.sync.LocalEntry
import com.gyattchores.app.model.Dare
import com.gyattchores.app.sync.Supabase
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch

/**
 * All app state lives here so it survives folding/unfolding (a configuration change).
 * Screens read the store's flows and call these actions.
 */
class AppViewModel(app: Application) : AndroidViewModel(app) {
    /** Family edition: shares the family and logs with the family's other phones. Public: nothing leaves the phone. */
    val familySync = BuildConfig.FAMILY_SYNC
    val store = Store(app, familySync)
    val zone: ZoneId get() = ZoneId.systemDefault()
    fun now() = System.currentTimeMillis()
    fun today(): LocalDate = Engine.dayOf(now(), zone)

    // ─── Card ───────────────────────────────────────────────────────────────

    fun pickable(playerId: String, logs: List<ChoreLog>): List<EnrichedChore> {
        val f = store.family.value
        val joined = f.memberJoined[playerId]
        val since = store.pool.mapNotNull { c -> listOfNotNull(f.choreAdded[c.id], joined).maxOrNull()?.let { c.id to it } }.toMap()
        return Engine.pickableChores(store.pool, playerId, logs, now(), since)
    }

    fun todaysLogs(playerId: String, logs: List<ChoreLog>): List<ChoreLog> =
        logs.filter { it.playerId == playerId && Engine.dayOf(it.timestamp, zone) == today() }

    /** Chores someone else has in today, as chore id → their name. One chore, one person, per day. */
    fun takenByOthers(playerId: String, logs: List<ChoreLog>): Map<String, String> {
        val shown = store.family.value.members.associate { it.name to it.shownName }
        return Engine.takenByOthersToday(playerId, logs.filter { Engine.dayOf(it.timestamp, zone) == today() })
            .mapValues { (_, name) -> shown[name] ?: name }
    }

    /** True when the player logged chores today and every one was rejected: they start over. */
    fun rejectedToday(playerId: String, logs: List<ChoreLog>): Boolean =
        todaysLogs(playerId, logs).isNotEmpty() && !submittedToday(playerId, logs)

    /**
     * Today's card, or null when the player picks one — including when everything they logged
     * today was rejected: a rejected day isn't a finished day, so they get the picker back
     * instead of a card of ✗s they can't change.
     */
    fun cardFor(playerId: String, cards: Map<String, Card>, logs: List<ChoreLog>): Card? {
        val startOver = rejectedToday(playerId, logs)
        cards["$playerId|${today()}"]?.let { return if (it.submitted && startOver) null else it }
        return if (startOver) null else cardFromLogs(playerId, logs)
    }

    /**
     * Rebuild today's submitted card from logs, for a device that didn't build it (like the web
     * app's cardFromLogs). Bonus-round chores are not part of this; they show separately.
     */
    private fun cardFromLogs(playerId: String, logs: List<ChoreLog>): Card? {
        val todays = logs.filter { it.playerId == playerId && Engine.dayOf(it.timestamp, zone) == today() }
            .sortedBy { it.timestamp }.distinctBy { it.choreId }
        if (todays.isEmpty()) return null
        return Card(today().toString(), todays.map { it.choreId }, todays.map { Engine.choreMinutes(it, store.poolById) },
            todays.map { true }, submitted = true)
    }

    fun lockIn(player: Player, chosen: List<EnrichedChore>) {
        store.saveCard(player.id, Card(today().toString(), chosen.map { it.id }, chosen.map { it.currentMinutes }, chosen.map { false }, chosen.map { it.escalLevel }))
    }

    fun toggle(player: Player, card: Card, index: Int) {
        if (card.submitted) return
        store.saveCard(player.id, card.copy(checked = card.checked.mapIndexed { i, v -> if (i == index) !v else v }))
    }

    fun clearCard(player: Player) = store.clearCard(player.id, today().toString())

    /**
     * One pending log per chore, with the minutes the card budgeted. A chore someone else got in
     * while this card was being checked off is left out, and dropped from the card, so it's never
     * logged twice in a day.
     */
    fun submit(player: Player, card: Card) {
        if (card.submitted) return
        val lost = takenByOthers(player.id, store.logs.value)
        val keep = card.choreIds.indices.filter { card.choreIds[it] !in lost }
        if (keep.isEmpty() || !keep.all { card.checked[it] }) return
        store.addLogs(keep.mapNotNull { newLog(player, card.choreIds[it], card.minutes[it]) })
        store.saveCard(player.id, card.copy(choreIds = keep.map { card.choreIds[it] }, minutes = keep.map { card.minutes[it] },
            checked = keep.map { true }, escal = keep.map { card.escal.getOrElse(it) { 0 } }, submitted = true))
        requestSync()
    }

    /** Bonus round: extra chores logged straight away, no minute cap, normal points. */
    fun logBonus(player: Player, chosen: List<EnrichedChore>) {
        store.addLogs(chosen.mapNotNull { newLog(player, it.id, it.currentMinutes) })
        requestSync()
    }

    private fun newLog(player: Player, choreId: String, minutes: Int): ChoreLog? {
        val c = store.poolById[choreId] ?: return null
        return ChoreLog(UUID.randomUUID().toString(), null, player.id, player.name, c.id, c.name, c.pts, minutes, Status.PENDING, now())
    }

    // ─── Dares ──────────────────────────────────────────────────────────────

    /** Every dare known to this phone, decoded from the shared state. */
    fun dares(state: Map<String, LocalEntry>): List<Dare> = state.flatMap { (key, e) ->
        val parts = key.split('|')
        if (parts.size != 3 || parts[0] != "dare") emptyList()
        else e.items.map { Dare(parts[1], it.substringBefore(':'), it.substringAfter(':'), parts[2]) }
    }

    /** Chore XP plus XP from settled dares. Use this everywhere a level is shown. */
    fun totalXp(playerId: String, logs: List<ChoreLog>, state: Map<String, LocalEntry>): Int =
        Engine.xp(playerId, logs, zone) + Engine.dareXp(playerId, dares(state), logs, today(), zone)

    /**
     * True when the player has something in today that's awaiting a parent or approved. A day
     * where everything was rejected doesn't count as submitted.
     */
    fun submittedToday(playerId: String, logs: List<ChoreLog>): Boolean =
        Engine.standingToday(Engine.statusToday(todaysLogs(playerId, logs))).isNotEmpty()

    /** Adds or removes one of my dares for today. Returns why not, or null if it changed. */
    fun toggleDare(target: Player, choreId: String): String? {
        val me = store.me.value ?: return "set whose phone this is first"
        val key = "dare|$me|${today()}"
        val items = store.state.value[key]?.items.orEmpty()
        val item = "${target.id}:$choreId"
        val locked = submittedToday(target.id, store.logs.value)
        if (item in items) {
            if (locked) return "locked — they already submitted today"
            store.setState(key, items - item, now())
        } else {
            val mine = items.map { Dare(me, it.substringBefore(':'), it.substringAfter(':'), today().toString()) }
            Engine.dareBlocked(me, target.id, mine, locked)?.let { return it }
            store.setState(key, items + item, now())
        }
        requestSync()
        return null
    }

    fun setMe(player: Player) = store.setMe(player.id)

    // ─── Sync ───────────────────────────────────────────────────────────────

    /** "syncing", "synced", "offline", or "synced · dares stay on this phone". */
    val syncStatus = MutableStateFlow("idle")
    /**
     * Who to sync with. Release builds: the family's Supabase. Debug builds: only a test server
     * given at launch (`--es syncURL http://<host>:8789`, kept until another is given; an empty
     * value clears it), and with none they stay offline — a test build can never reach real data.
     */
    private fun syncApi(): Supabase? =
        if (BuildConfig.REAL_SYNC) realApi
        else prefs.getString(KEY_SYNC_URL, null)?.takeIf { it.isNotBlank() }?.let { url ->
            if (testApi?.first != url) testApi = url to Supabase(baseUrl = url.trimEnd('/'))
            testApi!!.second
        }
    private val realApi by lazy { Supabase() }
    private var testApi: Pair<String, Supabase>? = null

    /** Debug builds only: the test server to sync with (see [syncApi]). */
    fun setTestSyncUrl(url: String) {
        if (BuildConfig.REAL_SYNC) return
        prefs.edit().putString(KEY_SYNC_URL, url.trim()).apply()
    }
    private val syncing = AtomicBoolean(false)
    private val syncAgain = AtomicBoolean(false)

    /** One pass at a time; a request that arrives mid-pass runs one follow-up pass instead of overlapping. */
    fun requestSync() {
        if (!familySync) return
        if (!syncing.compareAndSet(false, true)) { syncAgain.set(true); return }
        val api = syncApi()
        if (api == null) { syncStatus.value = "offline"; syncing.set(false); return }
        viewModelScope.launch(Dispatchers.IO) {
            syncStatus.value = "syncing"
            try {
                store.applySyncedLogs(LogSync.run(api, store.logs.value))
                syncStatus.value = try {
                    store.applySyncedState(StateSync.run(api, store.state.value))
                    "synced"
                } catch (e: HttpStatusException) {
                    // The family_state table is optional until its SQL has been run: dares and
                    // family changes then stay on this phone.
                    if (e.code == 404) "synced · dares stay on this phone" else throw e
                }
                // After the family rows, so someone removed on another phone isn't added back from old logs.
                store.adoptPlayersFromLogs(now())
                if (!prefs.getBoolean(KEY_SYNCED, false)) { prefs.edit().putBoolean(KEY_SYNCED, true).apply(); syncedOnce.value = true }
            } catch (e: Exception) {
                syncStatus.value = "offline"
            } finally {
                syncing.set(false)
                if (syncAgain.compareAndSet(true, false)) requestSync()
            }
        }
    }

    // ─── Admin ──────────────────────────────────────────────────────────────

    fun setStatus(log: ChoreLog, status: String) { store.setStatus(log.id, status); requestSync() }

    private fun level(playerId: String) = Engine.rank(totalXp(playerId, store.logs.value, store.state.value)).level

    /** Approves a log. Returns true if that approval took the player up a level. */
    fun approve(log: ChoreLog): Boolean {
        val before = level(log.playerId)
        store.setStatus(log.id, Status.APPROVED)
        requestSync()
        return level(log.playerId) > before
    }

    /** Approves several logs at once. Returns true if any of it took someone up a level. */
    fun approveAll(logs: List<ChoreLog>): Boolean {
        val before = logs.map { it.playerId }.distinct().associateWith { level(it) }
        for (l in logs) store.setStatus(l.id, Status.APPROVED)
        requestSync()
        return before.any { (id, lvl) -> level(id) > lvl }
    }

    private val seen = app.getSharedPreferences("seen_levels", android.content.Context.MODE_PRIVATE)

    /** True the first time a player's screen shows a level higher than the last one it showed. */
    fun isNewLevel(playerId: String, level: Int): Boolean {
        val last = seen.getInt(playerId, 1)
        if (level != last) seen.edit().putInt(playerId, level).apply()
        return level > last
    }

    // ─── Puzzle ─────────────────────────────────────────────────────────────

    val puzzlePack: PuzzlePack by lazy { PuzzlePack.parse(app.assets.open("puzzles.json").bufferedReader().readText()) }
    private val puzzleProgress = app.getSharedPreferences("puzzle", android.content.Context.MODE_PRIVATE)

    /** The puzzle level a player plays next (1 until they clear one). Kept on this phone. */
    fun puzzleLevel(playerId: String): Int = puzzleProgress.getInt(playerId, 1)

    /** A player cleared [level]: the next one is unlocked. Replaying an old level changes nothing. */
    fun puzzleCleared(playerId: String, level: Int) {
        if (level >= puzzleLevel(playerId)) puzzleProgress.edit().putInt(playerId, level + 1).apply()
    }

    /** True the first time yesterday's dare results are shown on this phone. */
    fun firstReveal(day: String): Boolean {
        if (seen.getString("reveal", null) == day) return false
        seen.edit().putString("reveal", day).apply()
        return true
    }

    // ─── Setup ──────────────────────────────────────────────────────────────

    private val prefs = app.getSharedPreferences("device", android.content.Context.MODE_PRIVATE)

    /**
     * Family edition: true once this phone has finished one sync. Until then it can't tell a new
     * family from one it hasn't fetched yet, so it waits rather than offering setup and starting
     * a second family.
     */
    val syncedOnce = MutableStateFlow(!familySync || prefs.getBoolean(KEY_SYNCED, false))

    /** Off unless an admin turns it on: a fingerprint belongs to whoever owns the phone, which on a player's own phone is the player. */
    val biometricUnlock = MutableStateFlow(prefs.getBoolean(KEY_BIOMETRIC, false))

    fun setBiometricUnlock(on: Boolean) { prefs.edit().putBoolean(KEY_BIOMETRIC, on).apply(); biometricUnlock.value = on }

    /** Finishes the first-run setup: who's in charge, who's playing and what needs doing. */
    fun finishSetup(adminName: String, adminPlays: Boolean, code: String, bio: Boolean, playerNames: List<String>, chores: List<Chore>) {
        val f = store.family.value
        if (f.isSetUp) return
        val adminCode = AdminCode.make(code) ?: return
        val admin = tidy(adminName) ?: return
        val t = now()
        val list = f.members.toMutableList()
        var next = f.nextPlayerId
        val joined = f.memberJoined.toMutableMap()
        fun find(n: String) = list.indexOfFirst { it.name.equals(n, ignoreCase = true) }
        for (n in playerNames.mapNotNull(::tidy)) if (find(n) < 0) {
            joined[next.toString()] = t; list += Player(next.toString(), n); next++
        }
        val codes = f.adminCodes.toMutableMap()
        // Someone who was already playing keeps playing when they turn out to be the admin too.
        val i = find(admin)
        if (i >= 0) { list[i] = list[i].copy(isAdmin = true); codes[list[i].id] = adminCode }
        else {
            val id = next.toString(); next++
            list.add(0, Player(id, admin, isAdmin = true, plays = adminPlays)); codes[id] = adminCode; joined[id] = t
        }
        val pool = chores.ifEmpty { store.starterChores }
        // A family with history keeps counting from it; a new one starts with nothing overdue.
        val added = if (store.logs.value.isEmpty()) pool.associate { it.id to t } else f.choreAdded
        setBiometricUnlock(bio)
        store.setFamily(f.copy(members = list, adminCodes = codes, chores = pool.takeIf { it != store.starterChores } ?: f.chores,
            choreAdded = added, memberJoined = joined, nextPlayerId = next), t)
        requestSync()
    }

    /** Wipes this phone. Public: back to first-run setup. Family: the family is fetched again. */
    fun eraseEverything() {
        store.eraseAll()
        seen.edit().clear().apply()
        puzzleProgress.edit().clear().apply()
        prefs.edit().clear().apply()
        biometricUnlock.value = false
        syncedOnce.value = !familySync
        requestSync()
    }

    // ─── Admin: unlocking ───────────────────────────────────────────────────

    /** True if [code] is any admin's code. */
    fun checkAdminCode(code: String): Boolean {
        val f = store.family.value
        return f.admins.any { f.adminCodes[it.id]?.matches(code) == true }
    }

    // ─── Admin: people ──────────────────────────────────────────────────────

    /** What an admin can change about a person. [newCode] is only read when [isAdmin]: empty keeps the code they have. */
    data class MemberDraft(val name: String = "", val displayName: String = "", val plays: Boolean = true,
                           val isAdmin: Boolean = false, val newCode: String = "")

    fun draft(m: Player) = MemberDraft(m.name, m.displayName ?: "", m.plays, m.isAdmin)

    /** Why this change can't be saved, or null if it can. [id] is null for someone new. */
    fun problem(d: MemberDraft, id: String?): String? {
        val f = store.family.value
        val name = tidy(d.name) ?: return "they need a name"
        if (f.members.any { it.id != id && it.name.equals(name, ignoreCase = true) }) return "someone already has that name"
        if (d.isAdmin) {
            val hasCode = id?.let { f.adminCodes[it] != null } ?: false
            if (if (d.newCode.isEmpty()) !hasCode else !AdminCode.isLongEnough(d.newCode))
                return "an admin needs a code of ${AdminCode.MIN_LENGTH} or more characters"
        } else if (id != null && f.admins.map { it.id } == listOf(id)) return "someone has to stay an admin"
        if (!d.plays && !d.isAdmin) return "they need to do chores, be an admin, or both"
        return null
    }

    /** Adds someone ([id] null) or changes them. Returns false, changing nothing, if [problem] objects. */
    fun saveMember(d: MemberDraft, id: String?): Boolean {
        if (problem(d, id) != null) return false
        val name = tidy(d.name) ?: return false
        val f = store.family.value
        var next = f.nextPlayerId
        val joined = f.memberJoined.toMutableMap()
        val current = id?.let { i -> f.members.firstOrNull { it.id == i } }
        val base = current ?: Player(next.toString(), name).also { joined[it.id] = now(); next++ }
        val m = base.copy(name = name, displayName = DisplayName.clean(d.displayName), plays = d.plays, isAdmin = d.isAdmin)
        val codes = f.adminCodes.toMutableMap()
        if (!d.isAdmin) codes.remove(m.id) else AdminCode.make(d.newCode)?.let { codes[m.id] = it }
        val members = if (current != null) f.members.map { if (it.id == m.id) m else it } else f.members + m
        store.setFamily(f.copy(members = members, adminCodes = codes, memberJoined = joined, nextPlayerId = next), now())
        requestSync()
        return true
    }

    fun canRemove(m: Player): Boolean = !(m.isAdmin && store.family.value.admins.size == 1)

    /** Removes someone and everything kept about them: their chores, points and code. */
    fun removeMember(m: Player) {
        if (!canRemove(m)) return
        val f = store.family.value
        store.setFamily(f.copy(members = f.members.filter { it.id != m.id }, adminCodes = f.adminCodes - m.id,
            memberJoined = f.memberJoined - m.id, removed = f.removed + m.id), now())
        seen.edit().remove(m.id).apply()
        puzzleProgress.edit().remove(m.id).apply()
        requestSync()
    }

    /**
     * A player's nickname is their own call: no admin needed, and it can't change the username
     * their points are kept under. Empty (or nothing visible) clears it.
     */
    fun setDisplayName(playerId: String, raw: String) {
        val f = store.family.value
        store.setFamily(f.copy(members = f.members.map { if (it.id == playerId) it.copy(displayName = DisplayName.clean(raw)) else it }), now())
        requestSync()
    }

    // ─── Admin: chores ──────────────────────────────────────────────────────

    /** Adds chores to the list, skipping any whose name is already on it. Returns how many went in. */
    fun addChores(chores: List<Chore>): Int {
        val f = store.family.value
        val pool = store.pool
        val names = pool.map { it.name.lowercase() }.toMutableSet()
        val ids = pool.map { it.id }.toMutableSet()
        val fresh = ArrayList<Chore>()
        for (c in chores) {
            if (!names.add(c.name.lowercase())) continue
            val chore = if (c.id in ids) ChoreIntake.make(c.name, c.tiers.firstOrNull() ?: 5, ids) else c
            ids += chore.id; fresh += chore
        }
        if (fresh.isNotEmpty()) {
            val t = now()
            store.setFamily(f.copy(chores = pool + fresh, choreAdded = f.choreAdded + fresh.associate { it.id to t }), t)
            requestSync()
        }
        return fresh.size
    }

    /** Renames or re-times a chore. Its id, and so its history, stays the same. */
    fun updateChore(chore: Chore, name: String, minutes: Int) {
        val clean = ChoreIntake.tidyName(name) ?: return
        val f = store.family.value
        store.setFamily(f.copy(chores = store.pool.map { if (it.id == chore.id) ChoreIntake.make(clean, minutes, id = chore.id) else it }), now())
        requestSync()
    }

    /** Takes a chore off the list. Points already earned are kept; a card still being checked off loses it. */
    fun removeChore(chore: Chore) {
        val pool = store.pool
        if (pool.size <= 1) return
        val f = store.family.value
        store.setFamily(f.copy(chores = pool.filter { it.id != chore.id }, choreAdded = f.choreAdded - chore.id), now())
        store.dropCardsWith(chore.id)
        requestSync()
    }

    // ─── Backup ─────────────────────────────────────────────────────────────

    private val appVersion: String by lazy {
        runCatching { getApplication<Application>().packageManager.getPackageInfo(getApplication<Application>().packageName, 0).versionName }
            .getOrNull() ?: "?"
    }

    /** Everything this phone knows about the game, as the text of a backup file. */
    fun exportBackup(): String {
        val f = store.family.value
        val levels = f.members.associate { it.id to puzzleLevel(it.id) }.filterValues { it > 1 }
        return Backup.encode(Backup.make(f, store.pool, store.logs.value, dares(store.state.value), levels,
            if (familySync) "android-family" else "android-public", appVersion, now()))
    }

    fun backupFileName() = Backup.fileName(today())

    /** A one-off message for whichever screen is showing (say, what a restore brought in). */
    val notice = MutableStateFlow<String?>(null)

    /** True when this exact backup has already been merged into the family. */
    fun alreadyRestored(b: BackupFile) = familySync && b.id in store.state.value[KEY_RESTORED]?.items.orEmpty()

    /**
     * Restores a backup. Public: it replaces everything on this phone. Family: it's merged into
     * the family (see [Backup.merge]) and goes out to the other phones on the next sync.
     */
    fun restore(b: BackupFile): RestoreCounts {
        val t = now()
        if (!familySync) {
            val r = Backup.replace(b)
            store.eraseAll()
            seen.edit().clear().apply()
            puzzleProgress.edit().clear().apply { r.puzzleLevels.forEach { (id, l) -> putInt(id, l) } }.apply()
            store.setFamily(r.family, t)
            store.addLogs(r.logs)
            // Kept where dares always live ("dare|<from>|<day>"), so their points count as on iOS.
            for ((key, ds) in r.dares.groupBy { "dare|${it.from}|${it.day}" }) store.setState(key, ds.map { "${it.target}:${it.choreId}" }, t)
            return r.counts
        }
        if (alreadyRestored(b)) return RestoreCounts(0, 0, 0)
        val m = Backup.merge(store.family.value, store.pool, store.logs.value,
            store.family.value.members.associate { it.id to puzzleLevel(it.id) }, b, zone, t)
        store.setFamily(m.family, t)
        store.addLogs(m.newLogs)
        m.puzzleLevels.forEach { (id, l) -> if (l > puzzleLevel(id)) puzzleProgress.edit().putInt(id, l).apply() }
        store.setState(KEY_RESTORED, store.state.value[KEY_RESTORED]?.items.orEmpty() + b.id, t)
        requestSync()
        return m.counts
    }

    /** A chore's name, even after it's been taken off the list: recent logs remember it. */
    fun choreName(choreId: String): String =
        store.poolById[choreId]?.name ?: store.logs.value.lastOrNull { it.choreId == choreId }?.choreName ?: choreId

    private fun tidy(name: String): String? =
        name.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ").takeIf { it.isNotEmpty() }?.take(DisplayName.MAX_LENGTH)

    private companion object {
        const val KEY_SYNCED = "synced_once"
        const val KEY_BIOMETRIC = "biometric_unlock"
        const val KEY_SYNC_URL = "test_sync_url"
        /** Shared: ids of backups already merged into the family, so a repeat does nothing. */
        const val KEY_RESTORED = "restored_backups"
    }
}
