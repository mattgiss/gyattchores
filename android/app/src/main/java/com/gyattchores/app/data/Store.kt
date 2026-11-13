package com.gyattchores.app.data

import android.content.Context
import com.gyattchores.app.model.Card
import com.gyattchores.app.model.Chore
import com.gyattchores.app.model.ChoreLog
import com.gyattchores.app.model.Player
import com.gyattchores.app.sync.LocalEntry
import com.gyattchores.app.sync.LogSync
import com.gyattchores.app.sync.StateSync
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

    /**
     * Lists shared between the family's phones (see `family_state`): each person's dares for a day
     * under "dare|<fromId>|<yyyy-MM-dd>" as "targetId:choreId" items, and the player list.
     */
    private val _state = MutableStateFlow(read("family_state.json") ?: emptyMap<String, LocalEntry>())
    val state: StateFlow<Map<String, LocalEntry>> = _state.asStateFlow()

    @Synchronized fun setState(key: String, items: List<String>, now: Long) {
        // An emptied list is kept (not removed) so "cleared" also reaches other devices.
        _state.value = _state.value + (key to LocalEntry(items, now, dirty = true))
        write("family_state.json", _state.value)
    }

    /** Whose phone this is. Dares are made as this player. */
    private val _me = MutableStateFlow(read<String>("me.json"))
    val me: StateFlow<String?> = _me.asStateFlow()

    @Synchronized fun setMe(playerId: String) { _me.value = playerId; write("me.json", playerId) }

    /** Applies a finished sync pass, keeping anything that changed locally while it ran. */
    @Synchronized fun applySyncedLogs(synced: List<ChoreLog>) {
        _logs.value = LogSync.reconcile(synced, _logs.value)
        write("logs.json", _logs.value)
    }

    @Synchronized fun applySyncedState(synced: Map<String, LocalEntry>) {
        _state.value = StateSync.reconcile(synced, _state.value)
        write("family_state.json", _state.value)
        // The player list and removals travel in the shared state; adopt them when another phone changed them.
        _state.value[KEY_PLAYERS]?.takeIf { !it.dirty && it.items.isNotEmpty() }?.let { e ->
            val list = e.items.map { Player(it.substringBefore(':'), it.substringAfter(':')) }
            if (list != _players.value) { _players.value = list; write("players.json", list) }
        }
        _state.value[KEY_REMOVED]?.takeIf { !it.dirty }?.let { e ->
            if (e.items.toSet() != removedPlayers) { removedPlayers = e.items.toSet(); write("removed_players.json", removedPlayers) }
        }
    }

    /** Players removed on this device, so sync doesn't add them straight back from old logs. */
    private var removedPlayers: Set<String> = read("removed_players.json") ?: emptySet()

    @Synchronized fun markRemoved(playerId: String, now: Long) {
        removedPlayers = removedPlayers + playerId
        write("removed_players.json", removedPlayers)
        setState(KEY_REMOVED, removedPlayers.sorted(), now)
    }

    /** Adds players that appear in synced logs but aren't known here (e.g. added on another phone). */
    @Synchronized fun adoptPlayersFromLogs() {
        val known = _players.value.map { it.id }.toSet() + removedPlayers
        val fresh = _logs.value.sortedByDescending { it.timestamp }.filter { it.playerId !in known }
            .distinctBy { it.playerId }.map { Player(it.playerId, it.playerName) }
        if (fresh.isNotEmpty()) savePlayers(_players.value + fresh.sortedBy { it.id }, System.currentTimeMillis())
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

    @Synchronized fun savePlayers(players: List<Player>, now: Long) {
        _players.value = players
        write("players.json", players)
        setState(KEY_PLAYERS, players.map { "${it.id}:${it.name}" }, now)
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
        const val KEY_PLAYERS = "players"
        const val KEY_REMOVED = "removed_players"
        val DEFAULT_PLAYERS = listOf(Player("1", "bekindhearted"), Player("2", "megadinolava"))
    }
}
