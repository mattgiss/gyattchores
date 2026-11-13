import Foundation
import GyattCore

/// All app state and actions. Everything lives in this app's own storage on this device and is
/// written to disk the moment it changes. There is no account, no server and no network code:
/// nothing a family enters ever leaves the phone or tablet it was entered on.
@MainActor
final class AppStore: ObservableObject {
    /// What's kept beside the players, chores and logs.
    struct Settings: Codable {
        /// False until the first-run setup has been finished.
        var setUp = false
        /// Each admin's code, by player id. Only a salted hash of a code is kept.
        var adminCodes: [String: AdminCode] = [:]
        /// Off unless an admin turns it on: Face ID belongs to whoever owns the device, which on a
        /// player's own tablet is the player.
        var biometricUnlock = false
        /// Ids are never reused, so a new player can't inherit a removed one's history.
        var nextPlayerId = 1        /// When each chore went on the list and when each person joined, on this device. A chore
        /// can't be overdue for longer than the player has had it. Empty for a family carried over
        /// from an earlier version, where chores keep counting from their history.
        var choreAdded: [String: Date] = [:]
        var memberJoined: [String: Date] = [:]
    }

    /// The starter chores that ship with the app.
    let starterChores: [Chore]

    @Published private(set) var settings: Settings { didSet { save("settings.json", settings) } }
    /// Everyone in the family, admins who don't do chores included.
    @Published private(set) var members: [Player] { didSet { save("players.json", members) } }
    /// The family's own chore list.
    @Published private(set) var pool: [Chore] { didSet { save("chores.json", pool); poolById = Self.index(pool) } }
    private(set) var poolById: [String: Chore]
    @Published private(set) var logs: [ChoreLog] { didSet { save("logs.json", logs) } }
    /// Keyed "playerId|yyyy-MM-dd".
    @Published private(set) var cards: [String: Card] { didSet { save("cards.json", cards) } }
    /// Dares made in an earlier version of the app. Nothing adds to them now; they're read so the
    /// points they earned aren't lost.
    private var dares: [Dare]

    /// The people on the scoreboard.
    var players: [Player] { members.filter(\.plays) }
    var admins: [Player] { members.filter(\.isAdmin) }
    var isSetUp: Bool { settings.setUp }

    /// Debug builds only: `-uiTesting` is how the UI tests launch the app. It gives them their own
    /// data folder, so a test run can never touch a real scoreboard. With it, `-resetData` starts
    /// from a fresh install, `-demoFamily` from a family that's already set up, and `-demoData`
    /// from that family with a made-up month of chores.
    #if DEBUG
    private static let launchArguments = ProcessInfo.processInfo.arguments
    #else
    private static let launchArguments: [String] = []
    #endif
    private static let uiTesting = launchArguments.contains("-uiTesting")
    /// On top of `-uiTesting`: the made-up family in the App Store pictures (`testAppStoreScreenshots`)
    /// has three players with names fit for a store page, and logs its chores before 9:41.
    private static let screenshots = uiTesting && launchArguments.contains("-screenshots")
    /// The admin code of the made-up family the UI tests use.
    static let demoAdminCode = "2468"

    private static let dir: URL = {
        var d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        if uiTesting {
            d = d.appendingPathComponent("ui-testing", isDirectory: true)
            if launchArguments.contains("-resetData") { try? FileManager.default.removeItem(at: d) }
        }
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    init() {
        let url = Bundle.main.url(forResource: "chores", withExtension: "json")!
        starterChores = try! JSONDecoder().decode([Chore].self, from: Data(contentsOf: url))

        var members: [Player] = Self.load("players.json") ?? []
        let logs: [ChoreLog] = Self.load("logs.json") ?? []
        var settings: Settings = Self.load("settings.json") ?? Settings()
        // Saved by a version that shared its lists between phones: display names and dares were in there.
        let legacy: [String: LegacyEntry] = Self.load("family_state.json") ?? [:]
        if !settings.setUp {
            for i in members.indices where members[i].displayName == nil {
                members[i].displayName = legacy["display|\(members[i].id)"]?.items.first.flatMap(DisplayName.clean)
            }
            let removed: [String] = Self.load("removed_players.json") ?? []
            let used = (members.map(\.id) + logs.map(\.playerId) + removed).compactMap(Int.init)
            settings.nextPlayerId = max(settings.nextPlayerId, (used.max() ?? 0) + 1)
        }
        dares = legacy.flatMap { key, entry -> [Dare] in
            let parts = key.split(separator: "|").map(String.init)
            guard parts.count == 3, parts[0] == "dare" else { return [] }
            return entry.items.compactMap { item in
                let t = item.split(separator: ":", maxSplits: 1).map(String.init)
                return t.count == 2 ? Dare(from: parts[1], target: t[0], choreId: t[1], day: parts[2]) : nil
            }
        }
        let pool: [Chore] = Self.load("chores.json") ?? starterChores
        self.settings = settings
        self.members = members
        self.pool = pool
        self.poolById = Self.index(pool)
        self.logs = logs
        self.cards = Self.load("cards.json") ?? [:]
        #if DEBUG
        if Self.uiTesting, !settings.setUp, Self.launchArguments.contains("-demoFamily") || Self.launchArguments.contains("-demoData") {
            finishSetup(adminName: "pat", adminPlays: false, code: Self.demoAdminCode, biometricUnlock: false,
                        playerNames: Self.screenshots ? ["sockninja", "dishwizard", "broomrider"] : ["riley", "sam"], chores: starterChores)
            if Self.launchArguments.contains("-demoData") {
                // `-demoRejectedDay`: the second player's chores for today were all rejected, not left waiting.
                let rejectedDay = Self.launchArguments.contains("-demoRejectedDay")
                self.logs = Self.demoLogs(pool: pool, players: players, todayStatus: rejectedDay ? Status.rejected : Status.pending)
                save("logs.json", self.logs)
            }
        }
        #endif
    }

    private struct LegacyEntry: Decodable { let items: [String] }
    private static func index(_ chores: [Chore]) -> [String: Chore] {
        Dictionary(chores.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: Setup

    /// Names already in the family when setup starts: a save from an earlier version of the app.
    var existingPlayerNames: [String] { members.map(\.name) }

    /// Finishes the first-run setup: who's in charge, who's playing and what needs doing.
    func finishSetup(adminName: String, adminPlays: Bool, code: String, biometricUnlock: Bool, playerNames: [String], chores: [Chore]) {
        guard !settings.setUp, let adminCode = AdminCode(code), let admin = Self.tidy(adminName) else { return }
        var next = settings
        var list = members
        let now = Date()
        func find(_ name: String) -> Int? { list.firstIndex { $0.name.lowercased() == name.lowercased() } }
        for name in playerNames.compactMap(Self.tidy) where find(name) == nil {
            next.memberJoined[String(next.nextPlayerId)] = now
            list.append(Player(id: String(next.nextPlayerId), name: name)); next.nextPlayerId += 1
        }
        // Someone who was already playing keeps playing when they turn out to be the admin too.
        if let i = find(admin) {
            list[i].isAdmin = true
            next.adminCodes[list[i].id] = adminCode
        } else {
            let id = String(next.nextPlayerId); next.nextPlayerId += 1
            list.insert(Player(id: id, name: admin, isAdmin: true, plays: adminPlays), at: 0)
            next.adminCodes[id] = adminCode
            next.memberJoined[id] = now
        }
        next.biometricUnlock = biometricUnlock
        next.setUp = true
        let list2 = chores.isEmpty ? starterChores : chores
        // A family with history keeps counting from it; a new one starts with nothing overdue.
        if logs.isEmpty { for chore in list2 { next.choreAdded[chore.id] = now } }
        members = list
        pool = list2
        settings = next
    }

    private static func tidy(_ name: String) -> String? {
        let n = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return n.isEmpty ? nil : String(n.prefix(DisplayName.maxLength))
    }

    /// Wipes the scoreboard: players, chores, history and codes. The app goes back to its first-run setup.
    func eraseEverything() {
        for name in ["players.json", "logs.json", "cards.json", "chores.json", "settings.json", "family_state.json", "removed_players.json"] {
            try? FileManager.default.removeItem(at: Self.dir.appendingPathComponent(name))
        }
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("seen_level_") { defaults.removeObject(forKey: key) }
        cards = [:]; logs = []; members = []; pool = starterChores; dares = []
        settings = Settings()
    }

    // MARK: Time

    var calendar: Calendar { .current }
    var todayKey: String { Self.dayKey(Date(), calendar) }
    static func dayKey(_ date: Date, _ cal: Calendar) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    // MARK: Derived

    func pickable(_ playerId: String) -> [EnrichedChore] {
        let joined = settings.memberJoined[playerId]
        var since: [String: Date] = [:]
        for chore in pool { since[chore.id] = [settings.choreAdded[chore.id], joined].compactMap { $0 }.max() }
        return Engine.pickableChores(pool: pool, playerId: playerId, logs: logs, now: Date(), knownSince: since)
    }
    /// Chore XP plus XP from settled dares.
    func totalXp(_ playerId: String) -> Int {
        Engine.xp(playerId: playerId, logs: logs, calendar: calendar) + Engine.dareXp(playerId: playerId, dares: dares, logs: logs, today: todayKey, calendar: calendar)
    }
    func rank(_ playerId: String) -> Rank { Engine.rank(xp: totalXp(playerId)) }

    /// Points this week, for the leaderboard.
    func weekPoints(_ playerId: String) -> Int {
        Engine.weekPoints(playerId: playerId, logs: logs, dares: dares, now: Date(), calendar: calendar)
    }
    /// A chore's name, even after it's been taken off the list: recent logs remember it.
    func choreName(_ choreId: String) -> String {
        poolById[choreId]?.name ?? logs.last { $0.choreId == choreId }?.choreName ?? choreId
    }
    /// True when the player has something in today that's awaiting an admin or approved. A day where
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

    /// Today's card, or one rebuilt from today's logs if the card itself is gone. Nil means the
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
        logs += keep.compactMap { newLog(player, card.choreIds[$0], card.minutes[$0]) }
        let c = Card(date: card.date, choreIds: keep.map { card.choreIds[$0] }, minutes: keep.map { card.minutes[$0] },
                     checked: keep.map { _ in true }, escal: keep.map { $0 < card.escal.count ? card.escal[$0] : 0 }, submitted: true)
        cards["\(player.id)|\(c.date)"] = c
    }

    /// Bonus round: extra chores logged straight away, no minute cap.
    func logBonus(_ player: Player, _ chosen: [EnrichedChore]) {
        logs += chosen.compactMap { newLog(player, $0.id, $0.currentMinutes) }
    }

    private func newLog(_ player: Player, _ choreId: String, _ minutes: Int) -> ChoreLog? {
        guard let c = poolById[choreId] else { return nil }
        return ChoreLog(playerId: player.id, playerName: player.name, choreId: c.id, choreName: c.name,
                        points: c.pts, minutes: minutes, status: Status.pending, timestamp: Date())
    }

    // MARK: Admin: unlocking

    /// True if `code` is any admin's code.
    func checkAdminCode(_ code: String) -> Bool {
        admins.contains { settings.adminCodes[$0.id]?.matches(code) == true }
    }

    func setBiometricUnlock(_ on: Bool) { settings.biometricUnlock = on }

    // MARK: Admin: approvals

    func setStatus(_ log: ChoreLog, _ status: String) {
        guard let i = logs.firstIndex(where: { $0.id == log.id }) else { return }
        logs[i].status = status
    }

    /// Approves a log. Returns true if that took the player up a level.
    func approve(_ log: ChoreLog) -> Bool {
        let before = rank(log.playerId).level
        setStatus(log, Status.approved)
        return rank(log.playerId).level > before
    }

    // MARK: Admin: players

    /// What an admin can change about a person. `newCode` is only read when `isAdmin` is on:
    /// empty keeps the code they have.
    struct MemberDraft {
        var name = ""
        var displayName = ""
        var plays = true
        var isAdmin = false
        var newCode = ""
    }

    func draft(for member: Player) -> MemberDraft {
        MemberDraft(name: member.name, displayName: member.displayName ?? "", plays: member.plays, isAdmin: member.isAdmin)
    }

    /// Why this change can't be saved, or nil if it can. `id` is nil for someone new.
    func problem(with draft: MemberDraft, for id: String?) -> String? {
        guard let name = Self.tidy(draft.name) else { return "they need a name" }
        if members.contains(where: { $0.id != id && $0.name.lowercased() == name.lowercased() }) { return "someone already has that name" }
        if draft.isAdmin {
            let hasCode = id.map { settings.adminCodes[$0] != nil } ?? false
            if draft.newCode.isEmpty ? !hasCode : !AdminCode.isLongEnough(draft.newCode) {
                return "an admin needs a code of \(AdminCode.minLength) or more characters"
            }
        } else if let id, admins.map(\.id) == [id] {
            return "someone has to stay an admin"
        }
        if !draft.plays, !draft.isAdmin { return "they need to do chores, be an admin, or both" }
        return nil
    }

    /// Adds someone (`id` nil) or changes them. Returns false, changing nothing, if `problem` has an objection.
    @discardableResult
    func saveMember(_ draft: MemberDraft, id: String?) -> Bool {
        guard problem(with: draft, for: id) == nil, let name = Self.tidy(draft.name) else { return false }
        var next = settings
        var member: Player
        if let id, let current = members.first(where: { $0.id == id }) { member = current } else {
            member = Player(id: String(next.nextPlayerId), name: name); next.nextPlayerId += 1
            next.memberJoined[member.id] = Date()
        }
        member.name = name
        member.displayName = DisplayName.clean(draft.displayName)
        member.plays = draft.plays
        member.isAdmin = draft.isAdmin
        if !draft.isAdmin { next.adminCodes[member.id] = nil }
        else if let code = AdminCode(draft.newCode) { next.adminCodes[member.id] = code }
        if let i = members.firstIndex(where: { $0.id == member.id }) { members[i] = member } else { members.append(member) }
        settings = next
        return true
    }

    func canRemove(_ member: Player) -> Bool { !(member.isAdmin && admins.count == 1) }

    /// Removes someone and everything kept about them: their chores, points and code.
    func removeMember(_ member: Player) {
        guard canRemove(member) else { return }
        members.removeAll { $0.id == member.id }
        logs.removeAll { $0.playerId == member.id }
        cards = cards.filter { !$0.key.hasPrefix("\(member.id)|") }
        settings.adminCodes[member.id] = nil
        settings.memberJoined[member.id] = nil
        UserDefaults.standard.removeObject(forKey: "seen_level_\(member.id)")
    }

    // MARK: Display names

    /// A player's nickname is their own call: no admin needed, and it can't change the username
    /// their points are kept under. Empty (or nothing visible) clears it.
    func setDisplayName(_ playerId: String, _ raw: String) {
        guard let i = members.firstIndex(where: { $0.id == playerId }) else { return }
        members[i].displayName = DisplayName.clean(raw)
    }

    /// What to show for a player: their display name, or their username if they haven't set one.
    func shownName(_ player: Player) -> String { player.shownName }

    /// For the admin area, where the real username must stay visible: "display name (username)".
    func adminLabel(_ player: Player) -> String {
        player.shownName == player.name ? player.name : "\(player.shownName) (\(player.name))"
    }

    // MARK: Admin: chores

    /// Adds chores to the list, skipping any whose name is already on it. Returns how many went in.
    @discardableResult
    func addChores(_ chores: [Chore]) -> Int {
        var names = Set(pool.map { $0.name.lowercased() }), ids = Set(pool.map(\.id))
        var fresh: [Chore] = []
        for chore in chores where names.insert(chore.name.lowercased()).inserted {
            let c = ids.contains(chore.id) ? ChoreIntake.make(name: chore.name, minutes: chore.tiers.first ?? 5, takenIds: ids) : chore
            ids.insert(c.id)
            fresh.append(c)
        }
        if !fresh.isEmpty {
            let now = Date()
            for chore in fresh { settings.choreAdded[chore.id] = now }
            pool += fresh
        }
        return fresh.count
    }

    /// Renames or re-times a chore. Its id, and so its history, stays the same.
    func updateChore(_ chore: Chore, name: String, minutes: Int) {
        guard let i = pool.firstIndex(where: { $0.id == chore.id }), let clean = ChoreIntake.tidyName(name) else { return }
        pool[i] = ChoreIntake.make(name: clean, minutes: minutes, id: chore.id)
    }

    /// Takes a chore off the list. Chores already logged keep their points; a card someone is
    /// still checking off loses it and they pick again.
    func removeChore(_ chore: Chore) {
        guard pool.count > 1 else { return }
        pool.removeAll { $0.id == chore.id }
        settings.choreAdded[chore.id] = nil
        cards = cards.filter { $0.value.submitted || !$0.value.choreIds.contains(chore.id) }
    }

    /// True the first time a player's screen shows a level higher than the last one it showed.
    func isNewLevel(_ playerId: String, _ level: Int) -> Bool {
        let key = "seen_level_\(playerId)"
        let last = UserDefaults.standard.object(forKey: key) as? Int ?? 1
        if level != last { UserDefaults.standard.set(level, forKey: key) }
        return level > last
    }

    // MARK: Demo data

    #if DEBUG
    /// A made-up month for `-uiTesting -demoData`: the first player clears the card most days, the
    /// second is hit and miss and has today's chores still waiting on an admin. With `-screenshots`
    /// there's a third, with a good month behind them and today's chores not picked yet.
    private static func demoLogs(pool: [Chore], players: [Player], todayStatus: String) -> [ChoreLog] {
        let now = Date(), cal = Calendar.current
        var out: [ChoreLog] = []
        for daysAgo in 0..<Engine.logDays {
            guard var day = cal.date(byAdding: .day, value: -daysAgo, to: now) else { continue }
            // In the pictures the clock reads 9:41 am whenever they're taken, so chores are logged before that.
            if screenshots, let morning = cal.date(bySettingHour: 7, minute: 48, second: 0, of: day) { day = morning }
            for (index, player) in players.prefix(screenshots ? 3 : 2).enumerated() {
                let steady = index == 0
                let dayOff = index == 2 ? daysAgo == 0 || daysAgo % 7 == 5 : steady ? daysAgo % 9 == 4 : daysAgo % 3 == 1
                if dayOff { continue }
                let goal = steady || index == 2 || daysAgo % 4 != 0 ? Engine.dailyMinutes : 14 // some short days
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
