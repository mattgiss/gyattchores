package com.gyattchores.app.data

import android.content.Context
import com.gyattchores.app.model.Card
import com.gyattchores.app.model.Chore
import com.gyattchores.app.model.ChoreLog
import com.gyattchores.app.model.Player
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

    /** A parent's hidden picks for a kid on a day. Keyed "playerId|yyyy-MM-dd" -> chore ids. */
    private val _picks = MutableStateFlow(read("parent_picks.json") ?: emptyMap<String, List<String>>())
    val picks: StateFlow<Map<String, List<String>>> = _picks.asStateFlow()

    @Synchronized fun setPicks(playerId: String, date: String, choreIds: List<String>) {
        val kept = _picks.value.filterKeys { it.substringAfter('|') >= date }
        _picks.value = if (choreIds.isEmpty()) kept - "$playerId|$date" else kept + ("$playerId|$date" to choreIds)
        write("parent_picks.json", _picks.value)
    }

    @Synchronized fun addLogs(new: List<ChoreLog>) {
        _logs.value = _logs.value + new
        write("logs.json", _logs.value)
    }

    @Synchronized fun setStatus(logId: String, status: String) {
        _logs.value = _logs.value.map { if (it.id == logId) it.copy(status = status) else it }
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
