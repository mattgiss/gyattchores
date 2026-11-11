import Foundation

public struct Player: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// A chore in the pool. `tiers` are minute costs and `tierDays` the neglect-day
/// thresholds at which each tier kicks in — the longer a chore goes undone, the
/// more minutes it costs.
public struct Chore: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    public let cat: String
    public let pts: Int
    public let tiers: [Int]
    public let tierDays: [Int]

    public init(id: String, name: String, cat: String, pts: Int, tiers: [Int], tierDays: [Int]) {
        self.id = id
        self.name = name
        self.cat = cat
        self.pts = pts
        self.tiers = tiers
        self.tierDays = tierDays
    }
}

public enum LogStatus: String, Codable, Sendable, CaseIterable {
    case pending, approved, rejected
}

/// One submitted chore. Field names mirror the web app's log records, and the
/// synced subset mirrors the Supabase `simple_logs` table.
public struct ChoreLog: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    /// Row id on the sync backend once this log has been pushed; nil while local-only.
    public var remoteId: String?
    public var playerId: String
    public var playerName: String
    public var choreId: String
    public var choreName: String
    /// XP points (the chore's `pts`).
    public var points: Int
    /// Minutes the chore was budgeted at when logged, escalation included.
    /// Nil on rows that came from a backend without this column.
    public var minutes: Int?
    public var timestamp: Date
    public var status: LogStatus

    public init(
        id: String = UUID().uuidString,
        remoteId: String? = nil,
        playerId: String,
        playerName: String,
        choreId: String,
        choreName: String,
        points: Int,
        minutes: Int? = nil,
        timestamp: Date,
        status: LogStatus = .pending
    ) {
        self.id = id
        self.remoteId = remoteId
        self.playerId = playerId
        self.playerName = playerName
        self.choreId = choreId
        self.choreName = choreName
        self.points = points
        self.minutes = minutes
        self.timestamp = timestamp
        self.status = status
    }
}

/// A chore resolved for one player at one moment: how neglected it is and what
/// it currently costs.
public struct CardChore: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    public let cat: String
    public let pts: Int
    public let neglectDays: Int
    public let currentMinutes: Int
    /// 0 normal · 1 neglected ("!") · 2 long overdue ("!!").
    public let escalLevel: Int

    public init(id: String, name: String, cat: String, pts: Int, neglectDays: Int, currentMinutes: Int, escalLevel: Int) {
        self.id = id
        self.name = name
        self.cat = cat
        self.pts = pts
        self.neglectDays = neglectDays
        self.currentMinutes = currentMinutes
        self.escalLevel = escalLevel
    }
}

/// A player's card for one day: the chores they picked and how far along they are.
public struct DailyCard: Hashable, Codable, Sendable {
    public var chores: [CardChore]
    public var checked: [Bool]
    public var submitted: Bool

    public init(chores: [CardChore], checked: [Bool]? = nil, submitted: Bool = false) {
        self.chores = chores
        self.checked = checked ?? chores.map { _ in false }
        self.submitted = submitted
    }

    public var totalMinutes: Int { chores.reduce(0) { $0 + $1.currentMinutes } }
    public var doneCount: Int { checked.filter { $0 }.count }
    public var allChecked: Bool { checked.allSatisfy { $0 } }
}

/// Lifetime XP resolved into a level, shown as a version number.
public struct Rank: Hashable, Sendable {
    public let level: Int
    public let version: String
    public let nextVersion: String
    /// XP earned inside the current level.
    public let into: Int
    /// XP the current level takes in total.
    public let need: Int
    public let pct: Int
}

/// One day of the home-screen log.
public struct DayMinutes: Identifiable, Hashable, Sendable {
    public let date: Date
    public let minutes: Int
    public var id: Date { date }
    public var isHit: Bool { minutes >= Engine.dailyMinutes }
    /// 0…1 progress toward the daily goal.
    public var fraction: Double { min(Double(minutes) / Double(Engine.dailyMinutes), 1) }
}

public struct DailyLogRow: Sendable {
    public let days: [DayMinutes]
    public let hits: Int
    public let pct: Int
}

/// What a player's day looks like beyond the card itself: the parent's verdict
/// per chore, and anything logged in the bonus round.
public struct TodayState: Sendable {
    public let statusByChore: [String: LogStatus]
    public let bonus: [CardChore]
    public let loggedToday: Set<String>
    public let bonusLeft: Int
}

public struct PickerSummary: Hashable, Sendable {
    public let total: Int
    /// Minutes left in the budget; nil when uncapped (bonus round).
    public let remaining: Int?
    public let canAddMore: Bool
    public let isFull: Bool
    public let isReady: Bool

    public func canPick(_ chore: CardChore) -> Bool {
        guard let remaining else { return true }
        return chore.currentMinutes <= remaining
    }
}
