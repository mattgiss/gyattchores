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
    @Published private(set) var me: String? { didSet { UserDefaults.standard.set(me, forKey: Self.meKey) } }
    /// "syncing", "synced", "offline", or "synced · dares stay on this phone".
    @Published private(set) var syncStatus = "idle"

    private var removedPlayers: Set<String> { didSet { save("removed_players.json", removedPlayers) } }
    private let api = Supabase()
    private var syncing = false, syncAgain = false
    /// Debug builds only: `-uiTesting` is how the UI tests launch the app. It gives them their own
    /// data folder and turns sync off, so a test run can never read or write the family's real
    /// chores. With it, `-resetData` starts from nothing and `-demoData` from a made-up month.
    #if DEBUG
    private static let launchArguments = ProcessInfo.processInfo.arguments
    #else
    private static let launchArguments: [String] = []
    #endif
    private static let uiTesting = launchArguments.contains("-uiTesting")
    /// "Whose phone is this" is kept apart for UI tests too, so they can't change the real answer.
    private static let meKey = uiTesting ? "ui-testing.me" : "me"

    private static let dir: URL = {
        var d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        if uiTesting {
            d = d.appendingPathComponent("ui-testing", isDirectory: true)
            if launchArguments.contains("-resetData") {
                try? FileManager.default.removeItem(at: d)
                UserDefaults.standard.removeObject(forKey: meKey)
                for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix(puzzleKey) {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }
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
        me = UserDefaults.standard.string(forKey: Self.meKey)
        removedPlayers = Self.load("removed_players.json") ?? []
        #if DEBUG
        if Self.uiTesting, Self.launchArguments.contains("-demoData") {
            // `-demoRejectedDay`: the second player's chores for today were all rejected, not left waiting.
            let rejectedDay = Self.launchArguments.contains("-demoRejectedDay")
            logs = Self.demoLogs(pool: pool, players: players, todayStatus: rejectedDay ? Status.rejected : Status.pending)
        }
        #endif
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
    /// True when the player has something in today that's awaiting a parent or approved. A day where
    /// everything was rejected doesn't count as submitted.
    func submittedToday(_ playerId: String) -> Bool { !Engine.standingToday(Engine.statusToday(todaysLogs(playerId))).isEmpty }
    /// Chores someone else has in today, as chore id → their name. One chore, one person, per day.
    func takenByOthers(_ playerId: String) -> [String: String] {
        Engine.takenByOthersToday(playerId: playerId, todays: logs.filter { calendar.isDateInToday($0.timestamp) })
    }
    /// True when the player logged chores today and every one was rejected: they start over.
    func rejectedToday(_ playerId: String) -> Bool { !todaysLogs(playerId).isEmpty && !submittedToday(playerId) }
    func streak(_ playerId: String) -> Int { Engine.streak(playerId: playerId, logs: logs, now: Date(), calendar: calendar) }
    func todaysLogs(_ playerId: String) -> [ChoreLog] { logs.filter { $0.playerId == playerId && calendar.isDateInToday($0.timestamp) } }

    /// Today's card, or one rebuilt from today's logs when another device built it. Nil means the
    /// player picks a card — including when everything they logged today was rejected: a rejected
    /// day isn't a finished day, so they get a fresh picker instead of a card of ✗s they can't change.
    func card(for playerId: String) -> Card? {
        let startOver = rejectedToday(playerId)
        if let c = cards["\(playerId)|\(todayKey)"] { return c.submitted && startOver ? nil : c }
        if startOver { return nil }
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

    /// Writes one pending log per chore. A chore someone else got in while this card was still being
    /// checked off is left out, and dropped from the card, so it's never logged twice in a day.
    func submit(_ player: Player, _ card: Card) {
        guard !card.submitted else { return }
        let lost = takenByOthers(player.id)
        let keep = card.choreIds.indices.filter { lost[card.choreIds[$0]] == nil }
        guard !keep.isEmpty, keep.allSatisfy({ card.checked[$0] }) else { return }
        logs += keep.map { newLog(player, card.choreIds[$0], card.minutes[$0]) }
        let c = Card(date: card.date, choreIds: keep.map { card.choreIds[$0] }, minutes: keep.map { card.minutes[$0] },
                     checked: keep.map { _ in true }, escal: keep.map { $0 < card.escal.count ? card.escal[$0] : 0 }, submitted: true)
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

    // MARK: Display names

    /// A player's display name, if they've set one. It is only ever shown: the username and id are
    /// what chore logs, sync and scoring use, so a display name can't damage them. Kept per player
    /// under "display|<id>" in the shared state, so it follows them to the family's other phones.
    func displayName(_ playerId: String) -> String? {
        // Cleaned on the way out as well as in, in case another device stored something odd.
        shared[Self.displayKey(playerId)]?.items.first.flatMap(DisplayName.clean)
    }

    /// What to show for a player: their display name, or their username if they haven't set one.
    func shownName(_ player: Player) -> String { displayName(player.id) ?? player.name }

    /// For the parent area, where the real username must stay visible: "display name (username)".
    func parentLabel(_ player: Player) -> String { displayName(player.id).map { "\($0) (\(player.name))" } ?? player.name }

    /// Sets a player's display name; empty (or nothing visible) clears it, back to the username.
    func setDisplayName(_ playerId: String, _ raw: String) {
        let cleaned = DisplayName.clean(raw)
        guard cleaned != displayName(playerId) else { return }
        setShared(Self.displayKey(playerId), cleaned.map { [$0] } ?? [])
        requestSync()
    }

    private static func displayKey(_ playerId: String) -> String { "display|\(playerId)" }

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

    // MARK: Puzzle

    /// The levels for the puzzle unlocked by a submitted card (`native/puzzles.json`).
    let puzzlePack: PuzzlePack = {
        let url = Bundle.main.url(forResource: "puzzles", withExtension: "json")!
        return try! PuzzlePack(json: Data(contentsOf: url))
    }()
    /// Puzzle progress is kept apart for UI tests too.
    private static let puzzleKey = uiTesting ? "ui-testing.puzzle_level_" : "puzzle_level_"

    /// The puzzle level a player plays next (1 until they clear one). Kept on this phone.
    func puzzleLevel(_ playerId: String) -> Int { max(1, UserDefaults.standard.integer(forKey: Self.puzzleKey + playerId)) }

    /// A player cleared `level`: the next one is unlocked. Replaying an old level changes nothing.
    func puzzleCleared(_ playerId: String, _ level: Int) {
        guard level >= puzzleLevel(playerId) else { return }
        objectWillChange.send()
        UserDefaults.standard.set(level + 1, forKey: Self.puzzleKey + playerId)
    }

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
        if Self.uiTesting { syncStatus = "off (ui testing)"; return }
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

    // MARK: Demo data

    #if DEBUG
    /// A made-up month for `-uiTesting -demoData`: the first player clears the card most days, the
    /// second is hit and miss and has today's chores still waiting on a parent.
    private static func demoLogs(pool: [Chore], players: [Player], todayStatus: String) -> [ChoreLog] {
        let now = Date(), cal = Calendar.current
        var out: [ChoreLog] = []
        for daysAgo in 0..<Engine.logDays {
            guard let day = cal.date(byAdding: .day, value: -daysAgo, to: now) else { continue }
            for (index, player) in players.prefix(2).enumerated() {
                let steady = index == 0
                if steady ? daysAgo % 9 == 4 : daysAgo % 3 == 1 { continue } // a day off
                let goal = steady || daysAgo % 4 != 0 ? Engine.dailyMinutes : 14 // some short days
                var minutes = 0, slot = daysAgo * 5 + index * 11
                var used = Set<String>()
                while minutes < goal, used.count < pool.count {
                    let c = pool[slot % pool.count]
                    slot += 1
                    guard used.insert(c.id).inserted else { continue }
                    out.append(ChoreLog(playerId: player.id, playerName: player.name, choreId: c.id, choreName: c.name,
                                        points: c.pts, minutes: c.tiers[0],
                                        status: daysAgo == 0 && !steady ? todayStatus : Status.approved,
                                        timestamp: day.addingTimeInterval(Double(-used.count))))
                    minutes += c.tiers[0]
                }
            }
        }
        return out
    }
    #endif

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
