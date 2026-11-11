import Foundation

/// A row of the shared `simple_logs` table.
public struct RemoteLog: Sendable {
    public let id: String, playerId: String, playerName: String, choreId: String, choreName: String
    public let points: Int, status: String, createdAt: Date
    public init(id: String, playerId: String, playerName: String, choreId: String, choreName: String, points: Int, status: String, createdAt: Date) {
        self.id = id; self.playerId = playerId; self.playerName = playerName; self.choreId = choreId
        self.choreName = choreName; self.points = points; self.status = status; self.createdAt = createdAt
    }
}

public protocol LogAPI: Sendable {
    /// Inserts a row and returns it as stored.
    func insert(_ log: ChoreLog) async throws -> RemoteLog
    /// Returns false if no row has that id (nothing was updated).
    func updateStatus(remoteId: String, status: String) async throws -> Bool
    func selectAll() async throws -> [RemoteLog]
}

/// One sync pass, following the web app's `sync()` step for step (and Android's `LogSync.kt`).
public enum LogSync {
    public static func run(api: LogAPI, local: [ChoreLog]) async throws -> [ChoreLog] {
        var work = local
        // 1. Push logs the server has never seen. Adopt the server's id and timestamp.
        for i in work.indices where work[i].remoteId == nil {
            let r = try await api.insert(work[i])
            work[i].remoteId = r.id; work[i].statusDirty = false; work[i].timestamp = r.createdAt
        }
        // 2. Push status changes. Stay dirty if no row was updated, so it retries.
        for i in work.indices {
            if let rid = work[i].remoteId, work[i].statusDirty, try await api.updateStatus(remoteId: rid, status: work[i].status) {
                work[i].statusDirty = false
            }
        }
        // 3. Pull.
        let rows = try await api.selectAll()
        var remoteIds = Set(rows.map(\.id))
        // 4. Self-heal: a dirty log whose remote row is gone is re-created.
        for i in work.indices {
            if work[i].statusDirty, let rid = work[i].remoteId, !remoteIds.contains(rid) {
                let r = try await api.insert(work[i])
                work[i].remoteId = r.id; work[i].statusDirty = false; work[i].timestamp = r.createdAt
                remoteIds.insert(r.id)
            }
        }
        // 5. Merge: the server's status wins unless we have an unpushed change; unknown rows are added.
        var indexByRemote: [String: Int] = [:]
        for (i, l) in work.enumerated() { if let rid = l.remoteId { indexByRemote[rid] = i } }
        for r in rows {
            if let i = indexByRemote[r.id] {
                if !work[i].statusDirty && work[i].status != r.status { work[i].status = r.status }
            } else {
                work.append(ChoreLog(id: "r_\(r.id)", remoteId: r.id, playerId: r.playerId, playerName: r.playerName, choreId: r.choreId,
                                     choreName: r.choreName, points: r.points, minutes: nil, status: r.status, timestamp: r.createdAt))
            }
        }
        return work
    }

    /// Folds in whatever changed locally while the pass was on the network.
    public static func reconcile(synced: [ChoreLog], latest: [ChoreLog]) -> [ChoreLog] {
        var out = synced
        var indexById: [String: Int] = [:]
        for (i, l) in out.enumerated() { indexById[l.id] = i }
        for l in latest {
            if let i = indexById[l.id] {
                if l.statusDirty && out[i].status != l.status { out[i].status = l.status; out[i].statusDirty = true }
            } else { out.append(l) }
        }
        return out.sorted { $0.timestamp > $1.timestamp }
    }
}

/// A row of the shared `family_state` table: a named list that every phone keeps in step.
/// Used for each person's dares for a day ("dare|<fromId>|<yyyy-MM-dd>") and the player list.
public struct RemoteEntry: Sendable {
    public let key: String, items: [String], updatedAt: Int64
    public init(key: String, items: [String], updatedAt: Int64) { self.key = key; self.items = items; self.updatedAt = updatedAt }
}

public protocol StateAPI: Sendable {
    func upsert(_ entry: RemoteEntry) async throws
    func selectState() async throws -> [RemoteEntry]
}

/// A local entry. `dirty` means it changed here and hasn't been pushed. `updatedAt` is epoch millis.
public struct LocalEntry: Codable, Hashable, Sendable {
    public var items: [String]
    public var updatedAt: Int64
    public var dirty: Bool
    public init(items: [String], updatedAt: Int64 = 0, dirty: Bool = false) { self.items = items; self.updatedAt = updatedAt; self.dirty = dirty }
}

/// Last writer wins per key, by `updated_at`.
public enum StateSync {
    public static func run(api: StateAPI, local: [String: LocalEntry]) async throws -> [String: LocalEntry] {
        var work = local
        for (key, e) in local where e.dirty {
            try await api.upsert(RemoteEntry(key: key, items: e.items, updatedAt: e.updatedAt))
            work[key]?.dirty = false
        }
        for r in try await api.selectState() {
            if let mine = work[r.key], mine.dirty || r.updatedAt <= mine.updatedAt { continue }
            work[r.key] = LocalEntry(items: r.items, updatedAt: r.updatedAt, dirty: false)
        }
        return work
    }

    /// Keeps entries edited locally while the pass was on the network.
    public static func reconcile(synced: [String: LocalEntry], latest: [String: LocalEntry]) -> [String: LocalEntry] {
        synced.merging(latest.filter { k, v in v.dirty && synced[k]?.updatedAt != v.updatedAt }) { _, new in new }
    }
}
