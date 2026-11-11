package com.gyattchores.app.sync

/** A parent's hidden picks for one kid on one day (`parent_picks` table). */
data class RemotePick(val playerId: String, val day: String, val choreIds: List<String>, val updatedAt: Long)

interface PicksApi {
    fun upsertPick(pick: RemotePick)
    fun selectPicks(fromDay: String): List<RemotePick>
}

/** A local pick entry. [dirty] means it changed here and hasn't been pushed. */
@kotlinx.serialization.Serializable
data class LocalPick(val choreIds: List<String>, val updatedAt: Long = 0, val dirty: Boolean = false)

/** Last writer wins, by `updated_at`. Keys are "playerId|yyyy-MM-dd". */
object PickSync {
    fun run(api: PicksApi, local: Map<String, LocalPick>, today: String): Map<String, LocalPick> {
        val work = local.toMutableMap()
        for ((key, p) in local) {
            if (!p.dirty) continue
            api.upsertPick(RemotePick(key.substringBefore('|'), key.substringAfter('|'), p.choreIds, p.updatedAt))
            work[key] = p.copy(dirty = false)
        }
        for (r in api.selectPicks(today)) {
            val key = "${r.playerId}|${r.day}"
            val mine = work[key]
            if (mine == null || (!mine.dirty && r.updatedAt > mine.updatedAt)) work[key] = LocalPick(r.choreIds, r.updatedAt, false)
        }
        return work
    }

    /** Keeps picks edited locally while the pass was on the network. */
    fun reconcile(synced: Map<String, LocalPick>, latest: Map<String, LocalPick>): Map<String, LocalPick> =
        synced + latest.filter { (k, v) -> v.dirty && synced[k]?.updatedAt != v.updatedAt }
}
