package com.gyattchores.app.sync

import kotlinx.serialization.Serializable

/**
 * A row of the shared `family_state` table: a named list that every phone keeps in step.
 * Used for each person's dares for a day ("dare|<fromId>|<yyyy-MM-dd>") and the player list.
 */
data class RemoteEntry(val key: String, val items: List<String>, val updatedAt: Long)

interface StateApi {
    fun upsert(entry: RemoteEntry)
    fun selectState(): List<RemoteEntry>
}

/** A local entry. [dirty] means it changed here and hasn't been pushed. [updatedAt] is epoch millis. */
@Serializable
data class LocalEntry(val items: List<String>, val updatedAt: Long = 0, val dirty: Boolean = false)

/** Last writer wins per key, by `updated_at`. */
object StateSync {
    fun run(api: StateApi, local: Map<String, LocalEntry>): Map<String, LocalEntry> {
        val work = local.toMutableMap()
        for ((key, e) in local) {
            if (!e.dirty) continue
            api.upsert(RemoteEntry(key, e.items, e.updatedAt))
            work[key] = e.copy(dirty = false)
        }
        for (r in api.selectState()) {
            val mine = work[r.key]
            if (mine == null || (!mine.dirty && r.updatedAt > mine.updatedAt)) work[r.key] = LocalEntry(r.items, r.updatedAt, false)
        }
        return work
    }

    /** Keeps entries edited locally while the pass was on the network. */
    fun reconcile(synced: Map<String, LocalEntry>, latest: Map<String, LocalEntry>): Map<String, LocalEntry> =
        synced + latest.filter { (k, v) -> v.dirty && synced[k]?.updatedAt != v.updatedAt }
}
