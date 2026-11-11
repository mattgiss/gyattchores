import Foundation

public struct Player: Codable, Identifiable, Hashable {
    public var id: String
    public var name: String
    public init(id: String, name: String) { self.id = id; self.name = name }
}

/// One chore in the pool (`native/chores.json`). `tiers` are minute costs that kick in at `tierDays` of neglect.
public struct Chore: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let cat: String
    public let pts: Int
    public let tiers: [Int]
    public let tierDays: [Int]
}

public enum Status {
    public static let pending = "pending"
    public static let approved = "approved"
    public static let rejected = "rejected"
}

/// A chore log. Mirrors the web app's log and the Supabase `simple_logs` row.
public struct ChoreLog: Codable, Identifiable, Hashable {
    public var id: String
    public var remoteId: String?
    public var playerId: String
    public var playerName: String
    public var choreId: String
    public var choreName: String
    public var points: Int
    /// Local-only: nil on rows pulled from sync.
    public var minutes: Int?
    public var status: String
    public var timestamp: Date
    /// Local-only: this chore matched a parent's hidden pick, so `points` is already doubled.
    public var parentPick: Bool
    /// Local-only: status was changed here and hasn't reached the server yet.
    public var statusDirty: Bool

    public init(id: String = UUID().uuidString, remoteId: String? = nil, playerId: String, playerName: String,
                choreId: String, choreName: String, points: Int, minutes: Int?, status: String, timestamp: Date,
                parentPick: Bool = false, statusDirty: Bool = false) {
        self.id = id; self.remoteId = remoteId; self.playerId = playerId; self.playerName = playerName
        self.choreId = choreId; self.choreName = choreName; self.points = points; self.minutes = minutes
        self.status = status; self.timestamp = timestamp; self.parentPick = parentPick; self.statusDirty = statusDirty
    }
}

/// A chore resolved for one player right now: its escalation tier and current minute cost.
public struct EnrichedChore: Identifiable, Hashable {
    public let chore: Chore
    public let neglectDays: Int
    public let currentMinutes: Int
    /// 0 normal, 1 "!" neglected, 2 "!!" long overdue.
    public let escalLevel: Int
    public var id: String { chore.id }
    public var name: String { chore.name }
    public var cat: String { chore.cat }
    public var pts: Int { chore.pts }
}

/// Today's card for one player. Lives only on the device that built it, like the web app.
public struct Card: Codable, Hashable {
    /// Local date, ISO yyyy-MM-dd.
    public var date: String
    public var choreIds: [String]
    public var minutes: [Int]
    public var checked: [Bool]
    public var escal: [Int]
    public var submitted: Bool
    public init(date: String, choreIds: [String], minutes: [Int], checked: [Bool], escal: [Int] = [], submitted: Bool = false) {
        self.date = date; self.choreIds = choreIds; self.minutes = minutes; self.checked = checked; self.escal = escal; self.submitted = submitted
    }
}

/// A secret guess: `from` dares that `target` will do `choreId` on `day` (yyyy-MM-dd).
public struct Dare: Hashable, Sendable {
    public let from: String, target: String, choreId: String, day: String
    public init(from: String, target: String, choreId: String, day: String) { self.from = from; self.target = target; self.choreId = choreId; self.day = day }
}

public struct Rank: Hashable {
    public let level: Int
    public let version: String
    public let nextVersion: String
    public let into: Int
    public let need: Int
    public let pct: Int
}
