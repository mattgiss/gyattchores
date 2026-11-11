package com.gyattchores.app.data

import android.content.Context
import com.gyattchores.app.model.Card
import com.gyattchores.app.model.Chore
import com.gyattchores.app.model.ChoreLog
import com.gyattchores.app.model.Player
import com.gyattchores.app.sync.LocalPick
import com.gyattchores.app.sync.LogSync
import com.gyattchores.app.sync.PickSync
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File

/**
 * Local-first storage: logs, players and today's cards as small JSON files in app storage.
 * Every write lands on disk immediately; nothing waits on the network. (Supabase sync, M5,
 * will push/pull `logs` on top of this.)
 */
class Store(context: Context) {
    private val dir = context.filesDir
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    val pool: List<Chore> = json.decodeFromString(context.assets.open("chores.json").bufferedReader().readText())
    val poolById: Map<String, Chore> = pool.associateBy { it.id }

    private val _logs = MutableStateFlow(read("logs.json") ?: emptyList<ChoreLog>())
    val logs: StateFlow<List<ChoreLog>> = _logs.asStateFlow()

    private val _players = MutableStateFlow(read("players.json") ?: DEFAULT_PLAYERS)
    val players: StateFlow<List<Player>> = _players.asStateFlow()

    /** Keyed "playerId|yyyy-MM-dd". */
    private val _cards = MutableStateFlow(read("cards.json") ?: emptyMap<String, Card>())
    val cards: StateFlow<Map<String, Card>> = _cards.asStateFlow()

    /** Parents' hidden picks with their sync state. Keyed "playerId|yyyy-MM-dd". */
    private val _pickEntries = MutableStateFlow(read("parent_picks_v2.json") ?: emptyMap<String, LocalPick>())
    val pickEntries: StateFlow<Map<String, LocalPick>> = _pickEntries.asStateFlow()

    @Synchronized fun setPicks(playerId: String, date: String, choreIds: List<String>, now: Long) {
        // An emptied list is kept (not removed) so "cleared" also reaches other devices.
        val kept = _pickEntries.value.filterKeys { it.substringAfter('|') >= date }
        _pickEntries.value = kept + ("$playerId|$date" to LocalPick(choreIds, now, dirty = true))
        write("parent_picks_v2.json", _pickEntries.value)
    }

    /** Applies a finished sync pass, keeping anything that changed locally while it ran. */
    @Synchronized fun applySyncedLogs(synced: List<ChoreLog>) {
        _logs.value = LogSync.reconcile(synced, _logs.value)
        write("logs.json", _logs.value)
    }

    @Synchronized fun applySyncedPicks(synced: Map<String, LocalPick>) {
        _pickEntries.value = PickSync.reconcile(synced, _pickEntries.value)
        write("parent_picks_v2.json", _pickEntries.value)
    }

    /** Players removed on this device, so sync doesn't add them straight back from old logs. */
    private var removedPlayers: Set<String> = read("removed_players.json") ?: emptySet()

    @Synchronized fun markRemoved(playerId: String) {
        removedPlayers = removedPlayers + playerId
        write("removed_players.json", removedPlayers)
    }

    /** Adds players that appear in synced logs but aren't known here (e.g. added on another phone). */
    @Synchronized fun adoptPlayersFromLogs() {
        val known = _players.value.map { it.id }.toSet() + removedPlayers
        val fresh = _logs.value.sortedByDescending { it.timestamp }.filter { it.playerId !in known }
            .distinctBy { it.playerId }.map { Player(it.playerId, it.playerName) }
        if (fresh.isNotEmpty()) savePlayers(_players.value + fresh.sortedBy { it.id })
    }

    @Synchronized fun addLogs(new: List<ChoreLog>) {
        _logs.value = _logs.value + new
        write("logs.json", _logs.value)
    }

    @Synchronized fun setStatus(logId: String, status: String) {
        _logs.value = _logs.value.map { if (it.id == logId) it.copy(status = status, statusDirty = true) else it }
        write("logs.json", _logs.value)
    }

    @Synchronized fun saveCard(playerId: String, card: Card) {
        // Keep only today's-or-newer cards so the file doesn't grow forever.
        _cards.value = (_cards.value + ("$playerId|${card.date}" to card)).filterValues { it.date >= card.date }
        write("cards.json", _cards.value)
    }

    @Synchronized fun clearCard(playerId: String, date: String) {
        _cards.value = _cards.value - "$playerId|$date"
        write("cards.json", _cards.value)
    }

    @Synchronized fun savePlayers(players: List<Player>) {
        _players.value = players
        write("players.json", players)
    }

    private inline fun <reified T> read(name: String): T? = runCatching {
        File(dir, name).takeIf { it.exists() }?.readText()?.let { json.decodeFromString<T>(it) }
    }.getOrNull()

    private inline fun <reified T> write(name: String, value: T) {
        // Write to a temp file then rename, so a crash mid-write can't corrupt the data.
        val tmp = File(dir, "$name.tmp")
        tmp.writeText(json.encodeToString(value))
        tmp.renameTo(File(dir, name))
    }

    companion object {
        val DEFAULT_PLAYERS = listOf(Player("1", "bekindhearted"), Player("2", "megadinolava"))
    }
}
