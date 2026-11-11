package com.gyattchores.app.sync

import com.gyattchores.app.model.ChoreLog

/** A row of the shared `simple_logs` table. */
data class RemoteLog(
    val id: String,
    val playerId: String,
    val playerName: String,
    val choreId: String,
    val choreName: String,
    val points: Int,
    val status: String,
    /** Epoch millis. */
    val createdAt: Long,
)

interface LogApi {
    /** Inserts a row and returns it as stored. */
    fun insert(log: ChoreLog): RemoteLog
    /** Returns false if no row has that id (nothing was updated). */
    fun updateStatus(remoteId: String, status: String): Boolean
    fun selectAll(): List<RemoteLog>
}

/**
 * One sync pass, following the web app's `sync()` step for step so the two clients agree:
 * push new logs, push approve/reject changes, pull everything, and merge.
 */
object LogSync {

    /** Returns the merged list. [local] is the snapshot the pass started from. */
    fun run(api: LogApi, local: List<ChoreLog>): List<ChoreLog> {
        val work = local.toMutableList()

        // 1. Push logs the server has never seen. Adopt the server's id and timestamp.
        for (i in work.indices) {
            val l = work[i]
            if (l.remoteId == null) {
                val r = api.insert(l)
                work[i] = l.copy(remoteId = r.id, statusDirty = false, timestamp = r.createdAt)
            }
        }
        // 2. Push status changes. Stay dirty if no row was updated, so it retries rather than vanishing.
        for (i in work.indices) {
            val l = work[i]
            if (l.remoteId != null && l.statusDirty && api.updateStatus(l.remoteId, l.status)) {
                work[i] = l.copy(statusDirty = false)
            }
        }
        // 3. Pull.
        val rows = api.selectAll()
        val remoteIds = rows.mapTo(HashSet()) { it.id }
        // 4. Self-heal: a dirty log whose remote row is gone (table reset) is re-created.
        for (i in work.indices) {
            val l = work[i]
            if (l.statusDirty && l.remoteId != null && l.remoteId !in remoteIds) {
                val r = api.insert(l)
                work[i] = l.copy(remoteId = r.id, statusDirty = false, timestamp = r.createdAt)
                remoteIds += r.id
            }
        }
        // 5. Merge: the server's status wins unless we have an unpushed change; unknown rows are added.
        val indexByRemote = HashMap<String, Int>()
        work.forEachIndexed { i, l -> l.remoteId?.let { indexByRemote[it] = i } }
        for (r in rows) {
            val i = indexByRemote[r.id]
            if (i == null) {
                work += ChoreLog("r_${r.id}", r.id, r.playerId, r.playerName, r.choreId, r.choreName, r.points, null, r.status, r.createdAt)
            } else if (!work[i].statusDirty && work[i].status != r.status) {
                work[i] = work[i].copy(status = r.status)
            }
        }
        return work
    }

    /**
     * Folds in whatever changed locally while the pass was on the network: logs added meanwhile are
     * kept, and a status changed meanwhile wins and stays dirty for the next pass.
     */
    fun reconcile(synced: List<ChoreLog>, latest: List<ChoreLog>): List<ChoreLog> {
        val out = synced.toMutableList()
        val indexById = HashMap<String, Int>()
        out.forEachIndexed { i, l -> indexById[l.id] = i }
        for (l in latest) {
            val i = indexById[l.id]
            if (i == null) out += l
            else if (l.statusDirty && out[i].status != l.status) out[i] = out[i].copy(status = l.status, statusDirty = true)
        }
        return out.sortedByDescending { it.timestamp }
    }
}
