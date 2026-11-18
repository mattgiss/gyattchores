package com.gyattchores.app.data

import android.content.Context
import com.gyattchores.app.model.Card
import com.gyattchores.app.model.Chore
import com.gyattchores.app.model.ChoreLog
import com.gyattchores.app.model.Family
import com.gyattchores.app.model.FamilyState
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
 * Local-first storage: logs, the family and today's cards as small JSON files in app storage.
 * Every write lands on disk immediately; nothing waits on the network.
 *
 * Every change to the family is also written to the shared state. Once this phone is linked to
 * the family's other phones, sync pushes it, and a sync pass that brings changes from another
 * phone is adopted here. Unlinked, the shared state just stays on the phone, ready for the first
 * "Add a phone".
 */
class Store(context: Context) {
    private val dir = context.filesDir
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    /** The starter chores that ship with the app. */
    val starterChores: List<Chore> = json.decodeFromString(context.assets.open("chores.json").bufferedReader().readText())

    private val _logs = MutableStateFlow(read("logs.json") ?: emptyList<ChoreLog>())
    val logs: StateFlow<List<ChoreLog>> = _logs.asStateFlow()

    private val _family = MutableStateFlow(read("family.json") ?: migrate())
    val family: StateFlow<Family> = _family.asStateFlow()

    /** The family's chore list. */
    val pool: List<Chore> get() = _family.value.chores ?: starterChores
    val poolById: Map<String, Chore> get() = pool.associateBy { it.id }

    /** Keyed "playerId|yyyy-MM-dd". */
    private val _cards = MutableStateFlow(read("cards.json") ?: emptyMap<String, Card>())
    val cards: StateFlow<Map<String, Card>> = _cards.asStateFlow()

    /**
     * Lists shared between the family's phones: the family itself
     * ([FamilyState]) and each person's dares for a day under "dare|<fromId>|<yyyy-MM-dd>".
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

    /** A save from before families had admins: the players (and who was removed) carry over. */
    private fun migrate(): Family {
        val players: List<Player> = read("players.json") ?: emptyList()
        val removed: Set<String> = read("removed_players.json") ?: emptySet()
        val used = (players.map { it.id } + removed + _logs.value.map { it.playerId }).mapNotNull { it.toIntOrNull() }
        return Family(members = players, removed = removed, nextPlayerId = (used.maxOrNull() ?: 0) + 1)
    }

    /** Replaces the family; the rows that changed go out on the next sync. */
    @Synchronized fun setFamily(next: Family, now: Long) {
        val before = _family.value
        _family.value = next
        write("family.json", next)
        for ((k, v) in FamilyState.changes(before, next)) setState(k, v, now)
        // Someone removed takes their history with them, on this phone at least.
        if (next.removed != before.removed) dropRemoved()
    }

    private fun dropRemoved() {
        val gone = _family.value.removed
        if (_logs.value.any { it.playerId in gone }) { _logs.value = _logs.value.filter { it.playerId !in gone }; write("logs.json", _logs.value) }
        if (_cards.value.keys.any { it.substringBefore('|') in gone }) {
            _cards.value = _cards.value.filterKeys { it.substringBefore('|') !in gone }; write("cards.json", _cards.value)
        }
    }

    /** Applies a finished sync pass, keeping anything that changed locally while it ran. */
    @Synchronized fun applySyncedLogs(synced: List<ChoreLog>) {
        val gone = _family.value.removed
        _logs.value = LogSync.reconcile(synced, _logs.value).filter { it.playerId !in gone }
        write("logs.json", _logs.value)
    }

    @Synchronized fun applySyncedState(synced: Map<String, LocalEntry>) {
        _state.value = StateSync.reconcile(synced, _state.value)
        write("family_state.json", _state.value)
        // Another phone may have changed the family: adopt what the shared rows now say.
        val rows = _state.value.filterKeys(FamilyState::owns).mapValues { it.value.items }
        val next = FamilyState.decode(rows, _family.value)
        if (next != _family.value) {
            val removedChanged = next.removed != _family.value.removed
            _family.value = next
            write("family.json", next)
            if (removedChanged) dropRemoved()
            // A chore taken off the list on another phone leaves any card here still being checked off.
            val ids = pool.map { it.id }.toSet()
            val stale = _cards.value.filterValues { c -> !c.submitted && c.choreIds.any { it !in ids } }
            if (stale.isNotEmpty()) { _cards.value = _cards.value - stale.keys; write("cards.json", _cards.value) }
        }
    }

    /** Adds players that appear in synced logs but aren't known here (e.g. added in the web app). */
    @Synchronized fun adoptPlayersFromLogs(now: Long) {
        val f = _family.value
        val known = f.members.map { it.id }.toSet() + f.removed
        val fresh = _logs.value.sortedByDescending { it.timestamp }.filter { it.playerId !in known }
            .distinctBy { it.playerId }.map { Player(it.playerId, it.playerName) }
        if (fresh.isEmpty()) return
        val next = maxOf(f.nextPlayerId, (fresh.mapNotNull { it.id.toIntOrNull() }.maxOrNull() ?: 0) + 1)
        setFamily(f.copy(members = f.members + fresh.sortedBy { it.id }, nextPlayerId = next), now)
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

    /** Drops cards still being checked off that include a chore taken off the list. */
    @Synchronized fun dropCardsWith(choreId: String) {
        _cards.value = _cards.value.filterValues { it.submitted || choreId !in it.choreIds }
        write("cards.json", _cards.value)
    }

    /**
     * For a phone that isn't linked, whose family.json is the truth: the shared family rows are
     * made to match it (see [FamilyState.reseed]). Run at every unlinked launch, which is how an
     * install of the old on-device edition gets its shared state, and before the first "Add a
     * phone". Does nothing when they already match.
     */
    @Synchronized fun shareFamilyFromDevice(now: Long) {
        val next = FamilyState.reseed(_state.value, _family.value, now)
        if (next != _state.value) { _state.value = next; write("family_state.json", next) }
    }

    /**
     * The first "Add a phone": the relay has nothing yet, so every log and every shared list goes
     * out on the next pass. The family rows are rebuilt from this phone's family first, so the
     * whole family travels as this phone has it, and nothing stale in the shared file can win.
     */
    @Synchronized fun prepareForNewServer(now: Long) {
        _logs.value = LogSync.forNewServer(_logs.value)
        write("logs.json", _logs.value)
        _state.value = StateSync.forNewServer(FamilyState.reseed(_state.value, _family.value, now))
        write("family_state.json", _state.value)
    }

    /**
     * Joining a family with a code: what this phone had came from elsewhere, and the family it
     * joins has it already, so it starts empty and loads the family. Whose phone it is stays.
     */
    @Synchronized fun clearForJoin() {
        for (n in listOf("logs.json", "cards.json", "family.json", "family_state.json", "players.json", "removed_players.json")) File(dir, n).delete()
        _logs.value = emptyList(); _cards.value = emptyMap(); _state.value = emptyMap()
        _family.value = Family()
    }

    /**
     * Deletes everything this phone keeps. Unlinked, it goes back to its first-run setup; linked,
     * it fetches the family again on the next sync.
     */
    @Synchronized fun eraseAll() {
        for (n in listOf("logs.json", "cards.json", "family.json", "family_state.json", "me.json", "players.json", "removed_players.json")) {
            File(dir, n).delete()
        }
        _logs.value = emptyList(); _cards.value = emptyMap(); _state.value = emptyMap(); _me.value = null
        _family.value = Family()
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
}
