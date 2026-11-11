import Foundation
import GyattCore

/// All app state and actions. Local-first: every change is written to disk at once and never waits
/// on the network. Mirrors Android's `Store` + `AppViewModel`.
@MainActor
final class AppStore: ObservableObject {
    let pool: [Chore]
    let poolById: [String: Chore]

    @Published private(set) var logs: [ChoreLog] { didSet { save("logs.json", logs) } }
    @Published private(set) var players: [Player] { didSet { save("players.json", players) } }
    /// Keyed "playerId|yyyy-MM-dd".
    @Published private(set) var cards: [String: Card] { didSet { save("cards.json", cards) } }
    /// Lists shared between the family's phones (`family_state`): each person's dares for a day under
    /// "dare|<fromId>|<yyyy-MM-dd>" as "targetId:choreId" items, and the player list.
    @Published private(set) var shared: [String: LocalEntry] { didSet { save("family_state.json", shared) } }
    /// Whose phone this is. Dares are made as this player.
    @Published private(set) var me: String? { didSet { UserDefaults.standard.set(me, forKey: "me") } }
    /// "syncing", "synced", "offline", or "synced · dares stay on this phone".
    @Published private(set) var syncStatus = "idle"

    private var removedPlayers: Set<String> { didSet { save("removed_players.json", removedPlayers) } }
    private let api = Supabase()
    private var syncing = false, syncAgain = false
    private static let dir: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    init() {
        let url = Bundle.main.url(forResource: "chores", withExtension: "json")!
        pool = try! JSONDecoder().decode([Chore].self, from: Data(contentsOf: url))
        poolById = Dictionary(uniqueKeysWithValues: pool.map { ($0.id, $0) })
        logs = Self.load("logs.json") ?? []
        players = Self.load("players.json") ?? [Player(id: "1", name: "bekindhearted"), Player(id: "2", name: "megadinolava")]
        cards = Self.load("cards.json") ?? [:]
        shared = Self.load("family_state.json") ?? [:]
        me = UserDefaults.standard.string(forKey: "me")
        removedPlayers = Self.load("removed_players.json") ?? []
    }

    // MARK: Time

    var calendar: Calendar { .current }
    var todayKey: String { Self.dayKey(Date(), calendar) }
    static func dayKey(_ date: Date, _ cal: Calendar) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    // MARK: Derived

    func pickable(_ playerId: String) -> [EnrichedChore] { Engine.pickableChores(pool: pool, playerId: playerId, logs: logs, now: Date()) }
    /// Chore XP plus XP from settled dares.
    func totalXp(_ playerId: String) -> Int {
        Engine.xp(playerId: playerId, logs: logs, calendar: calendar) + Engine.dareXp(playerId: playerId, dares: dares, logs: logs, today: todayKey, calendar: calendar)
    }
    func rank(_ playerId: String) -> Rank { Engine.rank(xp: totalXp(playerId)) }

    /// Every dare known to this phone, decoded from the shared state.
    var dares: [Dare] {
        shared.flatMap { key, e -> [Dare] in
            let parts = key.split(separator: "|").map(String.init)
            guard parts.count == 3, parts[0] == "dare" else { return [] }
            return e.items.compactMap { item in
                let t = item.split(separator: ":", maxSplits: 1).map(String.init)
                return t.count == 2 ? Dare(from: parts[1], target: t[0], choreId: t[1], day: parts[2]) : nil
            }
        }
    }
    func submittedToday(_ playerId: String) -> Bool { !todaysLogs(playerId).isEmpty }
    func streak(_ playerId: String) -> Int { Engine.streak(playerId: playerId, logs: logs, now: Date(), calendar: calendar) }
    func todaysLogs(_ playerId: String) -> [ChoreLog] { logs.filter { $0.playerId == playerId && calendar.isDateInToday($0.timestamp) } }

    /// Today's card, or one rebuilt from today's logs when another device built it.
    func card(for playerId: String) -> Card? {
        if let c = cards["\(playerId)|\(todayKey)"] { return c }
        var seen = Set<String>()
        let todays = todaysLogs(playerId).sorted { $0.timestamp < $1.timestamp }.filter { seen.insert($0.choreId).inserted }
        guard !todays.isEmpty else { return nil }
        return Card(date: todayKey, choreIds: todays.map(\.choreId), minutes: todays.map { Engine.choreMinutes($0, pool: poolById) },
                    checked: todays.map { _ in true }, submitted: true)
    }

    // MARK: Card actions

    func lockIn(_ player: Player, _ chosen: [EnrichedChore]) {
        let c = Card(date: todayKey, choreIds: chosen.map(\.id), minutes: chosen.map(\.currentMinutes), checked: chosen.map { _ in false }, escal: chosen.map(\.escalLevel))
        cards = cards.filter { $0.value.date >= c.date }.merging(["\(player.id)|\(c.date)": c]) { _, new in new }
    }

    func toggle(_ player: Player, _ card: Card, _ index: Int) {
        guard !card.submitted else { return }
        var c = card; c.checked[index].toggle()
        cards["\(player.id)|\(c.date)"] = c
    }

    func clearCard(_ player: Player) { cards["\(player.id)|\(todayKey)"] = nil }

    /// Writes one pending log per chore.
    func submit(_ player: Player, _ card: Card) {
        guard !card.submitted, card.checked.allSatisfy({ $0 }) else { return }
        logs += zip(card.choreIds, card.minutes).map { newLog(player, $0, $1) }
        var c = card; c.submitted = true
        cards["\(player.id)|\(c.date)"] = c
        requestSync()
    }

    /// Bonus round: extra chores logged straight away, no minute cap.
    func logBonus(_ player: Player, _ chosen: [EnrichedChore]) {
        logs += chosen.map { newLog(player, $0.id, $0.currentMinutes) }
        requestSync()
    }

    private func newLog(_ player: Player, _ choreId: String, _ minutes: Int) -> ChoreLog {
        let c = poolById[choreId]!
        return ChoreLog(playerId: player.id, playerName: player.name, choreId: c.id, choreName: c.name,
                        points: c.pts, minutes: minutes, status: Status.pending, timestamp: Date())
    }

    // MARK: Dares

    func setMe(_ player: Player) { me = player.id }

    private func setShared(_ key: String, _ items: [String]) {
        // An emptied list is kept (not removed) so "cleared" also reaches other devices.
        shared[key] = LocalEntry(items: items, updatedAt: Int64(Date().timeIntervalSince1970 * 1000), dirty: true)
    }

    /// Adds or removes one of my dares for today. Returns why not, or nil if it changed.
    func toggleDare(_ target: Player, _ choreId: String) -> String? {
        guard let me else { return "set whose phone this is first" }
        let key = "dare|\(me)|\(todayKey)", item = "\(target.id):\(choreId)"
        var items = shared[key]?.items ?? []
        let locked = submittedToday(target.id)
        if let i = items.firstIndex(of: item) {
            if locked { return "locked — they already submitted today" }
            items.remove(at: i)
        } else {
            let mine = dares.filter { $0.from == me && $0.day == todayKey }
            if let why = Engine.dareBlocked(from: me, target: target.id, mineToday: mine, targetSubmitted: locked) { return why }
            items.append(item)
        }
        setShared(key, items)
        requestSync()
        return nil
    }

    /// True the first time a day's dare results are shown on this phone.
    func firstReveal(_ day: String) -> Bool {
        if UserDefaults.standard.string(forKey: "reveal") == day { return false }
        UserDefaults.standard.set(day, forKey: "reveal")
        return true
    }

    // MARK: Parent actions

    func checkAdminCode(_ code: String) -> Bool { Engine.fnv1a(code) == Engine.adminCodeHash }

    func setStatus(_ log: ChoreLog, _ status: String) {
        guard let i = logs.firstIndex(where: { $0.id == log.id }) else { return }
        logs[i].status = status; logs[i].statusDirty = true
        requestSync()
    }

    /// Approves a log. Returns true if that took the player up a level.
    func approve(_ log: ChoreLog) -> Bool {
        let before = rank(log.playerId).level
        setStatus(log, Status.approved)
        return rank(log.playerId).level > before
    }

    func addPlayer(_ name: String) {
        let n = name.trimmingCharacters(in: .whitespaces); guard !n.isEmpty else { return }
        // Numeric string ids like the web app's "1", "2", so rows stay compatible.
        let next = (players.compactMap { Int($0.id) }.max() ?? 0) + 1
        players.append(Player(id: String(next), name: n))
        pushPlayers()
    }

    func renamePlayer(_ player: Player, _ name: String) {
        let n = name.trimmingCharacters(in: .whitespaces); guard !n.isEmpty, let i = players.firstIndex(of: player) else { return }
        players[i].name = n
        pushPlayers()
    }

    /// Removes the player from the list. Their logs are kept so history survives a re-add.
    func removePlayer(_ player: Player) {
        guard players.count > 1 else { return }
        removedPlayers.insert(player.id)
        players.removeAll { $0.id == player.id }
        setShared(Self.keyRemoved, removedPlayers.sorted())
        pushPlayers()
    }

    private static let keyPlayers = "players", keyRemoved = "removed_players"
    private func pushPlayers() { setShared(Self.keyPlayers, players.map { "\($0.id):\($0.name)" }); requestSync() }

    /// True the first time a player's screen shows a level higher than the last one it showed.
    func isNewLevel(_ playerId: String, _ level: Int) -> Bool {
        let key = "seen_level_\(playerId)"
        let last = UserDefaults.standard.object(forKey: key) as? Int ?? 1
        if level != last { UserDefaults.standard.set(level, forKey: key) }
        return level > last
    }

    // MARK: Sync

    /// One pass at a time; a request that arrives mid-pass runs one follow-up pass instead of overlapping.
    func requestSync() {
        if syncing { syncAgain = true; return }
        syncing = true
        syncStatus = "syncing"
        let logSnapshot = logs, stateSnapshot = shared
        Task {
            do {
                let synced = try await LogSync.run(api: api, local: logSnapshot)
                logs = LogSync.reconcile(synced: synced, latest: logs)
                adoptPlayersFromLogs()
                do {
                    let st = try await StateSync.run(api: api, local: stateSnapshot)
                    shared = StateSync.reconcile(synced: st, latest: shared)
                    adoptSharedPlayers()
                    syncStatus = "synced"
                } catch SupabaseError.http(let code) where code == 404 {
                    // The family_state table is optional until its SQL has been run:
                    // dares and player changes then stay on this phone.
                    syncStatus = "synced · dares stay on this phone"
                }
            } catch {
                syncStatus = "offline"
            }
            syncing = false
            if syncAgain { syncAgain = false; requestSync() }
        }
    }

    /// The player list and removals travel in the shared state; adopt them when another phone changed them.
    private func adoptSharedPlayers() {
        if let e = shared[Self.keyPlayers], !e.dirty, !e.items.isEmpty {
            let list = e.items.compactMap { item -> Player? in
                let t = item.split(separator: ":", maxSplits: 1).map(String.init)
                return t.count == 2 ? Player(id: t[0], name: t[1]) : nil
            }
            if list != players { players = list }
        }
        if let e = shared[Self.keyRemoved], !e.dirty, Set(e.items) != removedPlayers { removedPlayers = Set(e.items) }
    }

    /// Adds players that appear in synced logs but aren't known here (e.g. added on another phone).
    private func adoptPlayersFromLogs() {
        var known = Set(players.map(\.id)).union(removedPlayers)
        var fresh: [Player] = []
        for l in logs.sorted(by: { $0.timestamp > $1.timestamp }) where known.insert(l.playerId).inserted {
            fresh.append(Player(id: l.playerId, name: l.playerName))
        }
        if !fresh.isEmpty { players += fresh.sorted { $0.id < $1.id }; setShared(Self.keyPlayers, players.map { "\($0.id):\($0.name)" }) }
    }

    // MARK: Disk

    private static func load<T: Decodable>(_ name: String) -> T? {
        guard let data = try? Data(contentsOf: dir.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ name: String, _ value: T) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: Self.dir.appendingPathComponent(name), options: .atomic)
    }
}
