import Foundation

/// How a family is written into the shared `family_state` table, for the family build of the app.
/// Each key holds a list of strings; the last device to write a key wins. The Android family flavor
/// writes the same keys the same way, so a change on any phone shows up on all of them.
///
/// | key | items |
/// |---|---|
/// | `players` | `"id:username"` for each member who plays |
/// | `staff` | `"id:username"` for members who don't play (admins only) |
/// | `removed_players` | ids taken off the list (their history stays on the server) |
/// | `display\|<id>` | the display name, or nothing once cleared |
/// | `admins` | ids |
/// | `admin_code\|<id>` | `"salt:hash"`, hash = decimal fnv1a(salt + trimmed code), as `AdminCode` |
/// | `chores` | one chore per item, as JSON with the fields of `native/chores.json`; none = the starter list |
/// | `chore_added` | `"choreId:millis"` |
/// | `member_joined` | `"id:millis"` |
/// | `next_player_id` | the next free id, as one item. Ids are never reused. |
/// | `dare\|<fromId>\|<yyyy-MM-dd>` | `"targetId:choreId"` |
/// | `restored_backups` | ids of backups restored into the family (see `Backup`) |
///
/// `players`, `removed_players`, `display|…` and `dare|…` are what the first synced versions
/// (Android 0.3.x, iOS 0.1.0) already read and write, so they keep working beside this one.
/// A family is set up once `admins` has anyone in it.
public enum FamilyState {
    public static let players = "players"
    public static let staff = "staff"
    public static let removed = "removed_players"
    public static let admins = "admins"
    public static let chores = "chores"
    public static let choreAdded = "chore_added"
    public static let memberJoined = "member_joined"
    public static let nextPlayerId = "next_player_id"
    /// Ids of backups already restored into the family, so the same file can't be added twice.
    public static let restoredBackups = "restored_backups"
    public static func displayKey(_ id: String) -> String { "display|\(id)" }
    public static func adminCodeKey(_ id: String) -> String { "admin_code|\(id)" }
    public static func dareKey(from: String, day: String) -> String { "dare|\(from)|\(day)" }

    /// The family as the shared state describes it.
    public struct Family: Equatable {
        public var members: [Player]
        /// Nil when no device has written a chore list: use the starter list.
        public var chores: [Chore]?
        public var codes: [String: AdminCode]
        public var removed: Set<String>
        public var choreAdded: [String: Date]
        public var memberJoined: [String: Date]
        /// Nil when no device has written one yet.
        public var nextPlayerId: Int?
        public init(members: [Player], chores: [Chore]? = nil, codes: [String: AdminCode] = [:], removed: Set<String> = [],
                    choreAdded: [String: Date] = [:], memberJoined: [String: Date] = [:], nextPlayerId: Int? = nil) {
            self.members = members; self.chores = chores; self.codes = codes; self.removed = removed
            self.choreAdded = choreAdded; self.memberJoined = memberJoined; self.nextPlayerId = nextPlayerId
        }
        /// Set up once somebody is an admin.
        public var isSetUp: Bool { members.contains(where: \.isAdmin) }
    }

    public static func decode(_ state: [String: [String]]) -> Family {
        let removedIds = Set(state[removed] ?? [])
        let adminIds = Set(state[admins] ?? [])
        var codes: [String: AdminCode] = [:]
        for id in adminIds {
            guard let item = state[adminCodeKey(id)]?.first else { continue }
            let t = item.split(separator: ":", maxSplits: 1).map(String.init)
            if t.count == 2, let hash = UInt32(t[1]) { codes[id] = AdminCode(salt: t[0], hash: hash) }
        }
        var seen = Set<String>()
        func people(_ key: String, plays: Bool) -> [Player] {
            (state[key] ?? []).compactMap { item in
                let t = item.split(separator: ":", maxSplits: 1).map(String.init)
                guard t.count == 2, !removedIds.contains(t[0]), seen.insert(t[0]).inserted else { return nil }
                return Player(id: t[0], name: t[1], displayName: state[displayKey(t[0])]?.first.flatMap(DisplayName.clean),
                              isAdmin: adminIds.contains(t[0]), plays: plays)
            }
        }
        let members = people(players, plays: true) + people(staff, plays: false)
        let decoder = JSONDecoder()
        let list = (state[chores] ?? []).compactMap { try? decoder.decode(Chore.self, from: Data($0.utf8)) }
        return Family(members: members, chores: list.isEmpty ? nil : list, codes: codes, removed: removedIds,
                      choreAdded: dates(state[choreAdded]), memberJoined: dates(state[memberJoined]),
                      nextPlayerId: state[nextPlayerId]?.first.flatMap { Int($0) })
    }

    /// The entries that describe `family`. Display names and codes are written for every member,
    /// as `[]` when there isn't one, so clearing either reaches the other devices too.
    public static func encode(_ family: Family) -> [String: [String]] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        func ids(_ s: Set<String>) -> [String] { s.sorted { (Int($0) ?? 0, $0) < (Int($1) ?? 0, $1) } }
        var out: [String: [String]] = [
            players: family.members.filter(\.plays).map { "\($0.id):\($0.name)" },
            staff: family.members.filter { !$0.plays }.map { "\($0.id):\($0.name)" },
            removed: ids(family.removed),
            admins: family.members.filter(\.isAdmin).map(\.id),
            choreAdded: millis(family.choreAdded),
            memberJoined: millis(family.memberJoined),
        ]
        if let list = family.chores {
            out[chores] = list.compactMap { (try? encoder.encode($0)).flatMap { String(data: $0, encoding: .utf8) } }
        }
        if let next = family.nextPlayerId { out[nextPlayerId] = [String(next)] }
        for m in family.members {
            out[displayKey(m.id)] = m.displayName.flatMap(DisplayName.clean).map { [$0] } ?? []
            out[adminCodeKey(m.id)] = m.isAdmin ? family.codes[m.id].map { ["\($0.salt):\($0.hash)"] } ?? [] : []
        }
        // Someone taken off the list loses their display name and code everywhere.
        for id in family.removed { out[displayKey(id)] = []; out[adminCodeKey(id)] = [] }
        return out
    }

    /// Every dare in the shared state.
    public static func dares(_ state: [String: [String]]) -> [Dare] {
        state.flatMap { key, items -> [Dare] in
            let parts = key.split(separator: "|").map(String.init)
            guard parts.count == 3, parts[0] == "dare" else { return [] }
            return items.compactMap { item in
                let t = item.split(separator: ":", maxSplits: 1).map(String.init)
                return t.count == 2 ? Dare(from: parts[1], target: t[0], choreId: t[1], day: parts[2]) : nil
            }
        }
    }

    /// The next free player id: never one in use, removed, with history on the server, or below
    /// what any device has recorded as next.
    public static func nextFreeId(_ family: Family, logs: [ChoreLog]) -> Int {
        let used = (family.members.map(\.id) + family.removed + logs.map(\.playerId)).compactMap(Int.init)
        return max((used.max() ?? 0) + 1, family.nextPlayerId ?? 1)
    }

    private static func dates(_ items: [String]?) -> [String: Date] {
        var out: [String: Date] = [:]
        for item in items ?? [] {
            guard let i = item.lastIndex(of: ":"), let ms = Int64(item[item.index(after: i)...]) else { continue }
            out[String(item[..<i])] = Date(timeIntervalSince1970: Double(ms) / 1000)
        }
        return out
    }

    private static func millis(_ dates: [String: Date]) -> [String] {
        dates.keys.sorted().map { "\($0):\(Int64((dates[$0]!.timeIntervalSince1970 * 1000).rounded()))" }
    }
}
