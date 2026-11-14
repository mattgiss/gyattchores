package com.gyattchores.app

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import com.gyattchores.app.data.Store
import com.gyattchores.app.engine.Engine
import com.gyattchores.app.engine.PuzzlePack
import com.gyattchores.app.model.Card
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
    val store = Store(app)
    val zone: ZoneId get() = ZoneId.systemDefault()
    fun now() = System.currentTimeMillis()
    fun today(): LocalDate = Engine.dayOf(now(), zone)

    // ─── Card ───────────────────────────────────────────────────────────────

    fun pickable(playerId: String, logs: List<ChoreLog>): List<EnrichedChore> =
        Engine.pickableChores(store.pool, playerId, logs, now())

    fun cardFor(playerId: String, cards: Map<String, Card>, logs: List<ChoreLog>): Card? =
        cards["$playerId|${today()}"] ?: cardFromLogs(playerId, logs)

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

    /** One pending log per chore, with the minutes the card budgeted. */
    fun submit(player: Player, card: Card) {
        if (card.submitted || !card.checked.all { it }) return
        store.addLogs(card.choreIds.mapIndexed { i, id -> newLog(player, id, card.minutes[i]) })
        store.saveCard(player.id, card.copy(submitted = true))
        requestSync()
    }

    /** Bonus round: extra chores logged straight away, no minute cap, normal points. */
    fun logBonus(player: Player, chosen: List<EnrichedChore>) {
        store.addLogs(chosen.map { newLog(player, it.id, it.currentMinutes) })
        requestSync()
    }

    private fun newLog(player: Player, choreId: String, minutes: Int): ChoreLog {
        val c = store.poolById.getValue(choreId)
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

    fun submittedToday(playerId: String, logs: List<ChoreLog>): Boolean =
        logs.any { it.playerId == playerId && Engine.dayOf(it.timestamp, zone) == today() }

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
    private val api = Supabase()
    private val syncing = AtomicBoolean(false)
    private val syncAgain = AtomicBoolean(false)

    /** One pass at a time; a request that arrives mid-pass runs one follow-up pass instead of overlapping. */
    fun requestSync() {
        if (!syncing.compareAndSet(false, true)) { syncAgain.set(true); return }
        viewModelScope.launch(Dispatchers.IO) {
            syncStatus.value = "syncing"
            try {
                store.applySyncedLogs(LogSync.run(api, store.logs.value))
                store.adoptPlayersFromLogs()
                syncStatus.value = try {
                    store.applySyncedState(StateSync.run(api, store.state.value))
                    "synced"
                } catch (e: HttpStatusException) {
                    // The family_state table is optional until its SQL has been run: dares and
                    // player changes then stay on this phone.
                    if (e.code == 404) "synced · dares stay on this phone" else throw e
                }
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

    fun checkAdminCode(code: String) = Engine.fnv1a(code) == Engine.ADMIN_CODE_HASH

    fun addPlayer(name: String) {
        val n = name.trim().ifBlank { return }
        val players = store.players.value
        // Numeric string ids like the web app's "1", "2", so rows stay compatible with Supabase.
        val next = (players.mapNotNull { it.id.toIntOrNull() }.maxOrNull() ?: 0) + 1
        store.savePlayers(players + Player(next.toString(), n), now())
    }

    fun renamePlayer(player: Player, name: String) {
        val n = name.trim().ifBlank { return }
        store.savePlayers(store.players.value.map { if (it.id == player.id) it.copy(name = n) else it }, now())
    }

    /** Removes the player from the list. Their logs are kept so history and XP survive a re-add. */
    fun removePlayer(player: Player) {
        val players = store.players.value
        if (players.size <= 1) return
        store.markRemoved(player.id, now())
        store.savePlayers(players.filter { it.id != player.id }, now())
    }
}
