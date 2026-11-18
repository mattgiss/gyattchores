import Foundation

/// A backup of a family's scoreboard: a JSON file the family keeps (Files, iCloud Drive, AirDrop…)
/// and can restore on a new phone, or bring into the family build later. The Android app reads and
/// writes the same format, so a backup made on either restores on the other.
///
/// Times are epoch milliseconds. Readers ignore keys they don't know and refuse a newer `version`.
public struct Backup: Codable, Equatable {
    public static let typeName = "doyourwork-backup"
    /// What backups were marked before the app was renamed. They still restore.
    public static let legacyTypeNames: Set<String> = ["gyattchores-backup"]
    public static let currentVersion = 1
    public static let fileExtension = "json"

    public struct Member: Codable, Equatable {
        public var id: String, name: String, displayName: String?, isAdmin: Bool, plays: Bool
        /// The character they picked, if they did. Absent from backups made before there were characters.
        public var character: String?
    }
    public struct Code: Codable, Equatable { public var id: String, salt: String, hash: UInt32 }
    public struct Log: Codable, Equatable {
        public var id: String, remoteId: String?, playerId: String, playerName: String, choreId: String, choreName: String
        public var points: Int, minutes: Int?, status: String, timestamp: Int64, parentPick: Bool
    }
    public struct DareRow: Codable, Equatable { public var from: String, target: String, choreId: String, day: String }

    public var type: String
    public var version: Int
    /// New for every export: lets a family build refuse to restore the same file twice.
    public var id: String
    public var exportedAt: Int64
    /// "ios-public", "ios-family", "android-public" or "android-family".
    public var source: String
    public var appVersion: String
    public var members: [Member]
    public var adminCodes: [Code]
    public var chores: [Chore]
    public var choreAdded: [String: Int64]
    public var memberJoined: [String: Int64]
    public var nextPlayerId: Int
    public var logs: [Log]
    public var dares: [DareRow]
    public var puzzleLevels: [String: Int]

    public enum ReadError: Error, Equatable {
        case notABackup
        case newerVersion
        public var message: String {
            switch self {
            case .notABackup: "that file isn't a DOYOURWORK backup."
            case .newerVersion: "this backup is from a newer version of the app. update the app, then try again."
            }
        }
    }

    // MARK: Making one

    public init(members: [Player], codes: [String: AdminCode], chores: [Chore], choreAdded: [String: Date], memberJoined: [String: Date],
                nextPlayerId: Int, logs: [ChoreLog], dares: [Dare], puzzleLevels: [String: Int], source: String, appVersion: String,
                now: Date = Date(), id: String = UUID().uuidString) {
        type = Self.typeName; version = Self.currentVersion; self.id = id
        exportedAt = Self.ms(now); self.source = source; self.appVersion = appVersion
        self.members = members.map { Member(id: $0.id, name: $0.name, displayName: $0.displayName, isAdmin: $0.isAdmin, plays: $0.plays, character: $0.character) }
        adminCodes = codes.keys.sorted().map { Code(id: $0, salt: codes[$0]!.salt, hash: codes[$0]!.hash) }
        self.chores = chores
        self.choreAdded = choreAdded.mapValues(Self.ms)
        self.memberJoined = memberJoined.mapValues(Self.ms)
        self.nextPlayerId = nextPlayerId
        self.logs = logs.map { Log(id: $0.id, remoteId: $0.remoteId, playerId: $0.playerId, playerName: $0.playerName, choreId: $0.choreId,
                                   choreName: $0.choreName, points: $0.points, minutes: $0.minutes, status: $0.status,
                                   timestamp: Self.ms($0.timestamp), parentPick: $0.parentPick) }
        self.dares = dares.map { DareRow(from: $0.from, target: $0.target, choreId: $0.choreId, day: $0.day) }
        self.puzzleLevels = puzzleLevels
    }

    public func data() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try e.encode(self)
    }

    /// "doyourwork-backup-2026-11-14.json".
    public static func fileName(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        "doyourwork-backup-\(Engine.dayKey(date, calendar: calendar)).\(fileExtension)"
    }

    // MARK: Reading one

    public static func read(_ data: Data) throws -> Backup {
        struct Header: Decodable { let type: String?; let version: Int? }
        guard let header = try? JSONDecoder().decode(Header.self, from: data), let type = header.type, type == typeName || legacyTypeNames.contains(type), let v = header.version, v >= 1
        else { throw ReadError.notABackup }
        guard v <= currentVersion else { throw ReadError.newerVersion }
        guard let backup = try? JSONDecoder().decode(Backup.self, from: data) else { throw ReadError.notABackup }
        return backup
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decode(String.self, forKey: .type)
        version = try c.decode(Int.self, forKey: .version)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        exportedAt = try c.decodeIfPresent(Int64.self, forKey: .exportedAt) ?? 0
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? "unknown"
        appVersion = try c.decodeIfPresent(String.self, forKey: .appVersion) ?? ""
        members = try c.decodeIfPresent([Member].self, forKey: .members) ?? []
        adminCodes = try c.decodeIfPresent([Code].self, forKey: .adminCodes) ?? []
        chores = try c.decodeIfPresent([Chore].self, forKey: .chores) ?? []
        choreAdded = try c.decodeIfPresent([String: Int64].self, forKey: .choreAdded) ?? [:]
        memberJoined = try c.decodeIfPresent([String: Int64].self, forKey: .memberJoined) ?? [:]
        nextPlayerId = try c.decodeIfPresent(Int.self, forKey: .nextPlayerId) ?? 1
        logs = try c.decodeIfPresent([Log].self, forKey: .logs) ?? []
        dares = try c.decodeIfPresent([DareRow].self, forKey: .dares) ?? []
        puzzleLevels = try c.decodeIfPresent([String: Int].self, forKey: .puzzleLevels) ?? [:]
    }

    // MARK: What's in it

    public var players: [Player] {
        members.map { Player(id: $0.id, name: $0.name, displayName: $0.displayName.flatMap(DisplayName.clean), isAdmin: $0.isAdmin, plays: $0.plays, character: $0.character) }
    }
    public var codes: [String: AdminCode] {
        Dictionary(adminCodes.map { ($0.id, AdminCode(salt: $0.salt, hash: $0.hash)) }, uniquingKeysWith: { a, _ in a })
    }
    public var choreLogs: [ChoreLog] {
        logs.map { ChoreLog(id: $0.id, remoteId: $0.remoteId, playerId: $0.playerId, playerName: $0.playerName, choreId: $0.choreId,
                            choreName: $0.choreName, points: $0.points, minutes: $0.minutes, status: $0.status,
                            timestamp: Self.date($0.timestamp), parentPick: $0.parentPick) }
    }
    public var gameDares: [Dare] { dares.map { Dare(from: $0.from, target: $0.target, choreId: $0.choreId, day: $0.day) } }
    public var choreAddedDates: [String: Date] { choreAdded.mapValues(Self.date) }
    public var memberJoinedDates: [String: Date] { memberJoined.mapValues(Self.date) }
    public var exportedDate: Date { Self.date(exportedAt) }
    /// Usable as a whole scoreboard: somebody can unlock the admin area.
    public var hasAdmin: Bool { members.contains { $0.isAdmin && codes[$0.id] != nil } }

    /// "3 players, 12 chores, 214 chores logged"
    public var summary: String {
        let people = members.filter(\.plays).count
        return "\(people) player\(people == 1 ? "" : "s"), \(chores.count) chore\(chores.count == 1 ? "" : "s"), \(logs.count) logged"
    }

    // MARK: Merging into an existing family

    /// What restoring a backup into a family that's already set up would add. The family's own
    /// admins and codes never change; people are matched by username, chores by id or name, and a
    /// log is left out when the family already has it (same server row) or when that person already
    /// has that chore on that day (one chore, one person, per day).
    public struct MergePlan: Equatable {
        public var newMembers: [Player]
        /// Backup player id → family player id.
        public var idMap: [String: String]
        /// Backup chore id → family chore id (a chore matched by name, or given a fresh id).
        public var choreMap: [String: String]
        public var newChores: [Chore]
        public var newLogs: [ChoreLog]
        public var skippedLogs: Int
        public var memberJoined: [String: Date]
        public var choreAdded: [String: Date]
        public var isEmpty: Bool { newMembers.isEmpty && newChores.isEmpty && newLogs.isEmpty }
        /// "2 players, 3 chores and 120 logged chores added"
        public var summary: String {
            if isEmpty { return "nothing new: everything in this backup is already here." }
            var parts: [String] = []
            if !newMembers.isEmpty { parts.append("\(newMembers.count) \(newMembers.count == 1 ? "person" : "people")") }
            if !newChores.isEmpty { parts.append("\(newChores.count) chore\(newChores.count == 1 ? "" : "s")") }
            if !newLogs.isEmpty { parts.append("\(newLogs.count) logged chore\(newLogs.count == 1 ? "" : "s")") }
            return parts.joined(separator: ", ") + " added" + (skippedLogs > 0 ? " (\(skippedLogs) already here)" : "")
        }
    }

    public func mergePlan(members family: [Player], chores pool: [Chore], logs existing: [ChoreLog], nextId: Int, calendar: Calendar) -> MergePlan {
        var idMap: [String: String] = [:]
        var newMembers: [Player] = []
        var joined: [String: Date] = [:]
        var next = nextId
        var taken = Set(family.map { $0.name.lowercased() })
        for m in members {
            if let match = family.first(where: { $0.name.lowercased() == m.name.lowercased() }) {
                idMap[m.id] = match.id
            } else if taken.insert(m.name.lowercased()).inserted {
                let id = String(next); next += 1
                idMap[m.id] = id
                // Restored people come in as players or helpers, never admins: the family keeps its own.
                newMembers.append(Player(id: id, name: m.name, displayName: m.displayName.flatMap(DisplayName.clean), isAdmin: false, plays: m.plays || m.isAdmin, character: m.character))
                joined[id] = memberJoined[m.id].map(Self.date)
            } else if let earlier = newMembers.first(where: { $0.name.lowercased() == m.name.lowercased() }) {
                idMap[m.id] = earlier.id
            }
        }
        // Chores are matched by name first: the family's chore of that name keeps its id. A new one
        // whose id is already used by a different chore gets a fresh id. Logs follow the mapping.
        var choreIds = Set(pool.map(\.id))
        var byName = Dictionary(pool.map { ($0.name.lowercased(), $0.id) }, uniquingKeysWith: { a, _ in a })
        var choreMap: [String: String] = [:]
        var newChores: [Chore] = [], added: [String: Date] = [:]
        for c in chores {
            if let existing = byName[c.name.lowercased()] { choreMap[c.id] = existing; continue }
            var chore = c
            if choreIds.contains(c.id) {
                let fresh = ChoreIntake.make(name: c.name, minutes: c.tiers.first ?? 5, takenIds: choreIds)
                chore = Chore(id: fresh.id, name: c.name, cat: c.cat, pts: c.pts, tiers: c.tiers, tierDays: c.tierDays)
            }
            choreIds.insert(chore.id); byName[chore.name.lowercased()] = chore.id
            choreMap[c.id] = chore.id
            newChores.append(chore)
            added[chore.id] = choreAdded[c.id].map(Self.date)
        }
        let remote = Set(existing.compactMap(\.remoteId))
        func dayKey(_ playerId: String, _ choreId: String, _ t: Date) -> String { "\(playerId)|\(choreId)|\(Engine.dayKey(t, calendar: calendar))" }
        var seen = Set(existing.map { dayKey($0.playerId, $0.choreId, $0.timestamp) })
        let names = Dictionary((family + newMembers).map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        var newLogs: [ChoreLog] = [], skipped = 0
        for l in choreLogs {
            guard let pid = idMap[l.playerId] else { skipped += 1; continue }
            if let r = l.remoteId, remote.contains(r) { skipped += 1; continue }
            let cid = choreMap[l.choreId] ?? l.choreId
            guard seen.insert(dayKey(pid, cid, l.timestamp)).inserted else { skipped += 1; continue }
            // A new row for the family: it goes to the server on the next sync, keeping its date.
            newLogs.append(ChoreLog(playerId: pid, playerName: names[pid] ?? l.playerName, choreId: cid, choreName: l.choreName,
                                    points: l.points, minutes: l.minutes, status: l.status, timestamp: l.timestamp, parentPick: l.parentPick))
        }
        return MergePlan(newMembers: newMembers, idMap: idMap, choreMap: choreMap, newChores: newChores, newLogs: newLogs, skippedLogs: skipped,
                         memberJoined: joined.compactMapValues { $0 }, choreAdded: added.compactMapValues { $0 })
    }

    static func ms(_ d: Date) -> Int64 { Int64((d.timeIntervalSince1970 * 1000).rounded()) }
    static func date(_ ms: Int64) -> Date { Date(timeIntervalSince1970: Double(ms) / 1000) }
}
