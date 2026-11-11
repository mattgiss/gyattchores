package com.gyattchores.app

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import com.gyattchores.app.data.Store
import com.gyattchores.app.engine.Engine
import com.gyattchores.app.model.Card
import com.gyattchores.app.model.ChoreLog
import com.gyattchores.app.model.EnrichedChore
import com.gyattchores.app.model.Player
import com.gyattchores.app.model.Status
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID

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
    /** Returns how many chores matched the parent's hidden picks. */
    fun submit(player: Player, card: Card): Int {
        if (card.submitted || !card.checked.all { it }) return 0
        val new = card.choreIds.mapIndexed { i, id -> newLog(player, id, card.minutes[i]) }
        store.addLogs(new)
        store.saveCard(player.id, card.copy(submitted = true))
        return new.count { it.parentPick }
    }

    /** Bonus round: extra chores logged straight away, no minute cap, normal points. */
    fun logBonus(player: Player, chosen: List<EnrichedChore>): Int {
        val new = chosen.map { newLog(player, it.id, it.currentMinutes) }
        store.addLogs(new)
        return new.count { it.parentPick }
    }

    private fun newLog(player: Player, choreId: String, minutes: Int): ChoreLog {
        val c = store.poolById.getValue(choreId)
        // The parent's picks stay hidden until now: a match is logged at double points.
        val matched = choreId in parentPicks(player.id)
        return ChoreLog(UUID.randomUUID().toString(), null, player.id, player.name, c.id, c.name,
            Engine.pointsFor(c, matched), minutes, Status.PENDING, now(), parentPick = matched)
    }

    // ─── Parent picks ───────────────────────────────────────────────────────

    fun parentPicks(playerId: String): List<String> = store.picks.value["$playerId|${today()}"].orEmpty()

    fun setParentPicks(player: Player, choreIds: List<String>) = store.setPicks(player.id, today().toString(), choreIds)

    // ─── Admin ──────────────────────────────────────────────────────────────

    fun setStatus(log: ChoreLog, status: String) = store.setStatus(log.id, status)

    private fun level(playerId: String) = Engine.rank(Engine.xp(playerId, store.logs.value, zone)).level

    /** Approves a log. Returns true if that approval took the player up a level. */
    fun approve(log: ChoreLog): Boolean {
        val before = level(log.playerId)
        store.setStatus(log.id, Status.APPROVED)
        return level(log.playerId) > before
    }

    private val seen = app.getSharedPreferences("seen_levels", android.content.Context.MODE_PRIVATE)

    /** True the first time a player's screen shows a level higher than the last one it showed. */
    fun isNewLevel(playerId: String, level: Int): Boolean {
        val last = seen.getInt(playerId, 1)
        if (level != last) seen.edit().putInt(playerId, level).apply()
        return level > last
    }

    fun checkAdminCode(code: String) = Engine.fnv1a(code) == Engine.ADMIN_CODE_HASH

    fun addPlayer(name: String) {
        val n = name.trim().ifBlank { return }
        val players = store.players.value
        // Numeric string ids like the web app's "1", "2", so rows stay compatible with Supabase.
        val next = (players.mapNotNull { it.id.toIntOrNull() }.maxOrNull() ?: 0) + 1
        store.savePlayers(players + Player(next.toString(), n))
    }

    fun renamePlayer(player: Player, name: String) {
        val n = name.trim().ifBlank { return }
        store.savePlayers(store.players.value.map { if (it.id == player.id) it.copy(name = n) else it })
    }

    /** Removes the player from the list. Their logs are kept so history and XP survive a re-add. */
    fun removePlayer(player: Player) {
        val players = store.players.value
        if (players.size <= 1) return
        store.savePlayers(players.filter { it.id != player.id })
    }
}
