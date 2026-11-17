import Foundation

/// Someone in the family. `name` is the username chores and points are kept under.
public struct Player: Codable, Identifiable, Hashable {
    public var id: String
    public var name: String
    /// A nickname shown in place of the username. Only ever shown, never used to keep score.
    public var displayName: String?
    /// Admins approve chores and change players and chores. Each has their own code.
    public var isAdmin: Bool
    /// False for someone who only runs the scoreboard (say, a parent who doesn't do chores).
    public var plays: Bool
    /// The id of the character they picked for their scoreboard tile; nil until they pick (see `Characters.assign`).
    public var character: String?

    public init(id: String, name: String, displayName: String? = nil, isAdmin: Bool = false, plays: Bool = true, character: String? = nil) {
        self.id = id; self.name = name; self.displayName = displayName; self.isAdmin = isAdmin; self.plays = plays; self.character = character
    }

    // Older saves hold only an id and a name.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        isAdmin = try c.decodeIfPresent(Bool.self, forKey: .isAdmin) ?? false
        plays = try c.decodeIfPresent(Bool.self, forKey: .plays) ?? true
        character = try c.decodeIfPresent(String.self, forKey: .character)
    }

    /// What to show for this person: the display name if it holds anything visible, else the username.
    public var shownName: String { displayName.flatMap(DisplayName.clean) ?? name }
}

/// One chore on the family's list. `tiers` are minute costs that kick in at `tierDays` of neglect.
/// The starter list is `native/chores.json`; a family's own chores are made by `ChoreIntake`.
public struct Chore: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let cat: String
    public let pts: Int
    public let tiers: [Int]
    public let tierDays: [Int]
    public init(id: String, name: String, cat: String, pts: Int, tiers: [Int], tierDays: [Int]) {
        self.id = id; self.name = name; self.cat = cat; self.pts = pts; self.tiers = tiers; self.tierDays = tierDays
    }
}

public enum Status {
    public static let pending = "pending"
    public static let approved = "approved"
    public static let rejected = "rejected"
}

/// One chore done by one player. In the public app it never leaves the device; the family build
/// also keeps it in step with the family's shared `simple_logs` table.
public struct ChoreLog: Codable, Identifiable, Hashable {
    public var id: String
    /// Family build: the row's id on the server, once it's been pushed. Nil in the public app.
    public var remoteId: String?
    public var playerId: String
    public var playerName: String
    public var choreId: String
    public var choreName: String
    public var points: Int
    /// Nil on logs saved by early versions, and on rows pulled from sync, which don't record it.
    public var minutes: Int?
    public var status: String
    public var timestamp: Date
    /// This chore matched a parent's hidden pick, so `points` is already doubled.
    public var parentPick: Bool
    /// Family build: the status was changed here and hasn't reached the server yet.
    public var statusDirty: Bool

    public init(id: String = UUID().uuidString, remoteId: String? = nil, playerId: String, playerName: String,
                choreId: String, choreName: String, points: Int, minutes: Int?, status: String, timestamp: Date,
                parentPick: Bool = false, statusDirty: Bool = false) {
        self.id = id; self.remoteId = remoteId; self.playerId = playerId; self.playerName = playerName
        self.choreId = choreId; self.choreName = choreName; self.points = points; self.minutes = minutes
        self.status = status; self.timestamp = timestamp; self.parentPick = parentPick; self.statusDirty = statusDirty
    }

    // Saves from the on-device app have no sync fields.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        remoteId = try c.decodeIfPresent(String.self, forKey: .remoteId)
        playerId = try c.decode(String.self, forKey: .playerId)
        playerName = try c.decode(String.self, forKey: .playerName)
        choreId = try c.decode(String.self, forKey: .choreId)
        choreName = try c.decode(String.self, forKey: .choreName)
        points = try c.decode(Int.self, forKey: .points)
        minutes = try c.decodeIfPresent(Int.self, forKey: .minutes)
        status = try c.decode(String.self, forKey: .status)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        parentPick = try c.decodeIfPresent(Bool.self, forKey: .parentPick) ?? false
        statusDirty = try c.decodeIfPresent(Bool.self, forKey: .statusDirty) ?? false
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

/// Today's card for one player.
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
