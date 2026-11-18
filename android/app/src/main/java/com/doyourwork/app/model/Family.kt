package com.doyourwork.app.model

import com.doyourwork.app.engine.AdminCode
import com.doyourwork.app.sync.LocalEntry
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Who's in the family and what needs doing: the members (admins who don't do chores included),
 * each admin's code, the family's own chore list, and when each chore and person arrived.
 *
 * Kept on the device, and also as shared rows (see [FamilyState]) that go to the family's other
 * phones through the encrypted relay once this phone is linked to them.
 */
@Serializable
data class Family(
    val members: List<Player> = emptyList(),
    /** By player id. Only a salted hash of each code is kept. */
    val adminCodes: Map<String, AdminCode> = emptyMap(),
    /** The family's chore list; null until someone sets one, meaning the starter list. */
    val chores: List<Chore>? = null,
    /** Epoch millis each chore went on the list. Empty for a family carried over from before, which keeps counting from its history. */
    val choreAdded: Map<String, Long> = emptyMap(),
    /** Epoch millis each person joined. */
    val memberJoined: Map<String, Long> = emptyMap(),
    /** Ids are never reused, so a new player can't inherit a removed one's history. */
    val nextPlayerId: Int = 1,
    /** Ids of people removed, so sync doesn't add them back from old logs. */
    val removed: Set<String> = emptySet(),
) {
    /** A family exists once someone is in charge of it. */
    val isSetUp: Boolean get() = members.any { it.isAdmin }
    val players: List<Player> get() = members.filter { it.plays }
    val admins: List<Player> get() = members.filter { it.isAdmin }
}

/**
 * The family's lists as shared state rows (relay records; the old `family_state` table had the
 * same keys). Every value is a list of strings; the last writer wins per key. iOS reads and
 * writes exactly these keys.
 *
 * Kept from earlier versions, so Android 0.3.x and iOS 0.1.0 still understand them:
 *  - "players": "id:username" for each member who plays
 *  - "removed_players": ids
 *  - "display|<id>": one item, the display name (empty list: none)
 * Added with player characters (older versions leave it alone):
 *  - "character|<id>": one item, the id of the character they picked (empty list: none picked)
 * Added with setup and admin codes:
 *  - "staff": "id:username" for members who don't play
 *  - "admins": ids
 *  - "admin_code|<id>": one item, "salt:hash"
 *  - "chores": one JSON object per chore; missing or empty means the starter list
 *  - "chore_added", "member_joined": "id:epochMillis"
 *  - "next_player_id": one item
 * Dares ("dare|<from>|<day>") share the table but aren't part of the family.
 */
object FamilyState {
    const val PLAYERS = "players"
    const val STAFF = "staff"
    const val ADMINS = "admins"
    const val REMOVED = "removed_players"
    const val CHORES = "chores"
    const val CHORE_ADDED = "chore_added"
    const val MEMBER_JOINED = "member_joined"
    const val NEXT_ID = "next_player_id"
    const val DISPLAY = "display|"
    const val ADMIN_CODE = "admin_code|"
    const val CHARACTER = "character|"

    private val json = Json { ignoreUnknownKeys = true }

    /** True for keys this object owns; anything else (dares) is left alone. */
    fun owns(key: String) = key in setOf(PLAYERS, STAFF, ADMINS, REMOVED, CHORES, CHORE_ADDED, MEMBER_JOINED, NEXT_ID) ||
        key.startsWith(DISPLAY) || key.startsWith(ADMIN_CODE) || key.startsWith(CHARACTER)

    fun encode(f: Family): Map<String, List<String>> {
        val out = linkedMapOf<String, List<String>>()
        out[PLAYERS] = f.members.filter { it.plays }.map { "${it.id}:${it.name}" }
        out[STAFF] = f.members.filter { !it.plays }.map { "${it.id}:${it.name}" }
        out[ADMINS] = f.members.filter { it.isAdmin }.map { it.id }
        out[REMOVED] = f.removed.sorted()
        out[CHORES] = f.chores?.map { json.encodeToString(it) } ?: emptyList()
        out[CHORE_ADDED] = f.choreAdded.entries.sortedBy { it.key }.map { "${it.key}:${it.value}" }
        out[MEMBER_JOINED] = f.memberJoined.entries.sortedBy { it.key }.map { "${it.key}:${it.value}" }
        out[NEXT_ID] = listOf(f.nextPlayerId.toString())
        for (m in f.members) out[DISPLAY + m.id] = listOfNotNull(m.displayName)
        for (m in f.members) out[CHARACTER + m.id] = listOfNotNull(m.character)
        for ((id, code) in f.adminCodes) if (f.members.any { it.id == id && it.isAdmin }) out[ADMIN_CODE + id] = listOf(code.encode())
        return out
    }

    /**
     * Rows that differ between two families, ready to write. A key [before] had and [after]
     * doesn't (a removed person's display name or code) is written as an empty list, so the
     * removal reaches the other phones too.
     */
    fun changes(before: Family, after: Family): Map<String, List<String>> {
        val a = encode(before); val b = encode(after)
        val out = linkedMapOf<String, List<String>>()
        for ((k, v) in b) if (a[k] != v) out[k] = v
        for (k in a.keys - b.keys) if (a[k]!!.isNotEmpty()) out[k] = emptyList()
        return out
    }

    /**
     * The shared rows made to say exactly what [family] says, for a phone whose own family is the
     * truth: one that isn't linked to any other phone. Every family row that differs (or is
     * missing) is rewritten from [family], stamped [now] and marked to go out; a family row
     * [family] has no use for (a stale display name, say) is emptied. Dares and every other key
     * are left as they are, and rows that already agree aren't touched, so it's safe to run on
     * every launch.
     *
     * This is how an install of the old on-device-only edition, which kept its family in
     * family.json only (and its dares in the shared file), gets shared state the first time it
     * runs the one-app version, and how a stale shared file can never overwrite its players when
     * it later adds a phone.
     */
    fun reseed(state: Map<String, LocalEntry>, family: Family, now: Long): Map<String, LocalEntry> {
        val want = encode(family)
        val out = LinkedHashMap(state)
        for ((k, items) in want) if (state[k]?.items != items) out[k] = LocalEntry(items, now, dirty = true)
        for ((k, e) in state) if (owns(k) && k !in want && e.items.isNotEmpty()) out[k] = LocalEntry(emptyList(), now, dirty = true)
        return out
    }

    /** The family as the shared rows describe it. Anything the rows don't cover comes from [base]. */
    fun decode(state: Map<String, List<String>>, base: Family): Family {
        fun pairs(items: List<String>) = items.mapNotNull { s ->
            val i = s.indexOf(':'); if (i <= 0) null else s.substring(0, i) to s.substring(i + 1)
        }
        val baseById = base.members.associateBy { it.id }
        val admins = state[ADMINS]?.toSet()
        val members = if (state[PLAYERS] != null || state[STAFF] != null) {
            val listed = pairs(state[PLAYERS].orEmpty()).map { it to true } + pairs(state[STAFF].orEmpty()).map { it to false }
            listed.distinctBy { it.first.first }.map { (p, plays) ->
                val (id, name) = p
                val was = baseById[id]
                Player(id, name, was?.displayName, admins?.contains(id) ?: was?.isAdmin ?: false, plays, was?.character)
            }
        } else base.members.map { m -> admins?.let { m.copy(isAdmin = m.id in it) } ?: m }
        val withNames = members.map { m ->
            state[DISPLAY + m.id]?.let { m.copy(displayName = it.firstOrNull()?.ifBlank { null }) } ?: m
        }.map { m ->
            state[CHARACTER + m.id]?.let { m.copy(character = it.firstOrNull()?.ifBlank { null }) } ?: m
        }
        val codes = base.adminCodes.toMutableMap()
        for (m in withNames) state[ADMIN_CODE + m.id]?.let { items ->
            val c = items.firstOrNull()?.let(AdminCode::decode)
            if (c != null) codes[m.id] = c else codes.remove(m.id)
        }
        val chores = state[CHORES]?.let { items ->
            if (items.isEmpty()) null else items.mapNotNull { runCatching { json.decodeFromString<Chore>(it) }.getOrNull() }.ifEmpty { null }
        } ?: base.chores.takeIf { state[CHORES] == null }
        fun times(key: String, fallback: Map<String, Long>) =
            state[key]?.let { pairs(it).mapNotNull { (k, v) -> v.toLongOrNull()?.let { k to it } }.toMap() } ?: fallback
        val next = maxOf(base.nextPlayerId, state[NEXT_ID]?.firstOrNull()?.toIntOrNull() ?: 0,
            (withNames.mapNotNull { it.id.toIntOrNull() }.maxOrNull() ?: 0) + 1)
        return Family(
            members = withNames,
            adminCodes = codes.filterKeys { id -> withNames.any { it.id == id && it.isAdmin } },
            chores = chores,
            choreAdded = times(CHORE_ADDED, base.choreAdded),
            memberJoined = times(MEMBER_JOINED, base.memberJoined),
            nextPlayerId = next,
            removed = state[REMOVED]?.toSet() ?: base.removed,
        )
    }
}
