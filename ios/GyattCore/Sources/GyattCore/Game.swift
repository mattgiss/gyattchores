import Foundation

/// Everything the app persists: the chore logs and the cards being worked on.
public struct GameState: Codable, Equatable, Sendable {
    /// Newest first.
    public var logs: [ChoreLog]
    /// Cards in progress, keyed by player and local day. A card only lives on
    /// the device that built it; other devices rebuild it from the logs.
    public var cards: [String: DailyCard]

    public init(logs: [ChoreLog] = [], cards: [String: DailyCard] = [:]) {
        self.logs = logs
        self.cards = cards
    }
}

/// The game as a value: state plus the moves that change it. No UI, no I/O —
/// the app wraps this in an observable store and saves after each move.
public struct Game: Sendable {
    public private(set) var state: GameState
    public let engine: Engine

    public init(state: GameState = GameState(), engine: Engine = Engine()) {
        self.engine = engine
        self.state = state
        self.state.logs = Self.newestFirst(state.logs)
    }

    public var logs: [ChoreLog] { state.logs }

    // MARK: - Reading

    /// The card this device is working on today, if it built one.
    public func localCard(for playerId: String, now: Date) -> DailyCard? {
        state.cards[cardKey(playerId, now)]
    }

    /// Today's card: the one built here, or else one rebuilt from today's logs.
    /// Nil means the player hasn't picked anything yet today.
    public func card(for playerId: String, now: Date) -> DailyCard? {
        localCard(for: playerId, now: now) ?? engine.cardFromLogs(playerId: playerId, logs: state.logs, now: now)
    }

    // MARK: - Moves

    /// Lock in the chores a player picked as today's card.
    public mutating func buildCard(for playerId: String, chores: [CardChore], now: Date) {
        guard !chores.isEmpty else { return }
        state.cards[cardKey(playerId, now)] = DailyCard(chores: chores)
    }

    /// Throw away an unsubmitted card so the player can pick again.
    public mutating func discardCard(for playerId: String, now: Date) {
        let key = cardKey(playerId, now)
        guard let card = state.cards[key], !card.submitted else { return }
        state.cards[key] = nil
    }

    /// Check a chore off (or back on) before the card is submitted.
    public mutating func toggleChore(at index: Int, for playerId: String, now: Date) {
        let key = cardKey(playerId, now)
        guard var card = state.cards[key], !card.submitted, card.checked.indices.contains(index) else { return }
        card.checked[index].toggle()
        state.cards[key] = card
    }

    /// Submit a fully checked-off card for approval. Returns false if there was
    /// nothing to submit.
    @discardableResult
    public mutating func submitCard(for player: Player, now: Date) -> Bool {
        let key = cardKey(player.id, now)
        guard var card = state.cards[key], !card.submitted, card.allChecked else { return false }
        append(engine.makeLogs(for: card.chores, player: player, now: now))
        card.submitted = true
        state.cards[key] = card
        return true
    }

    /// Bonus round: log extra chores straight to pending. A chore already logged
    /// today (card or bonus) is skipped — once a day is the rule.
    public mutating func logBonus(for player: Player, chores: [CardChore], now: Date) {
        guard let card = card(for: player.id, now: now) else { return }
        let logged = engine.todayState(playerId: player.id, logs: state.logs, card: card, now: now).loggedToday
        append(engine.makeLogs(for: chores.filter { !logged.contains($0.id) }, player: player, now: now))
    }

    /// The parent's verdict on a log.
    public mutating func setStatus(_ status: LogStatus, forLog id: String) {
        guard let index = state.logs.firstIndex(where: { $0.id == id }) else { return }
        state.logs[index].status = status
    }

    /// Drop cards from earlier days; their logs are the lasting record.
    public mutating func pruneCards(now: Date) {
        let suffix = "|" + dayKey(now)
        state.cards = state.cards.filter { $0.key.hasSuffix(suffix) }
    }

    // MARK: - Helpers

    private mutating func append(_ logs: [ChoreLog]) {
        guard !logs.isEmpty else { return }
        state.logs = Self.newestFirst(logs + state.logs)
    }

    private static func newestFirst(_ logs: [ChoreLog]) -> [ChoreLog] {
        logs.stableSorted { $0.timestamp > $1.timestamp }
    }

    private func cardKey(_ playerId: String, _ now: Date) -> String {
        playerId + "|" + dayKey(now)
    }

    func dayKey(_ date: Date) -> String {
        let parts = engine.calendar.dateComponents([.year, .month, .day], from: date)
        func pad(_ value: Int, _ width: Int) -> String {
            let text = String(value)
            return String(repeating: "0", count: max(0, width - text.count)) + text
        }
        return "\(pad(parts.year ?? 0, 4))-\(pad(parts.month ?? 0, 2))-\(pad(parts.day ?? 0, 2))"
    }
}

/// Saves and loads `GameState` as a JSON file.
public struct GameArchive: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public enum LoadResult: Equatable, Sendable {
        /// No save file yet — a fresh install.
        case empty
        case loaded(GameState)
        /// The save file couldn't be read. It was moved aside to `backup` rather
        /// than overwritten, so the data can still be recovered by hand.
        case unreadable(backup: URL?)
    }

    public func load() -> LoadResult {
        let manager = FileManager.default
        guard manager.fileExists(atPath: url.path) else { return .empty }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            return .loaded(try decoder.decode(GameState.self, from: Data(contentsOf: url)))
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = url.deletingPathExtension().appendingPathExtension("unreadable-\(stamp).json")
            do {
                try manager.moveItem(at: url, to: backup)
                return .unreadable(backup: backup)
            } catch {
                return .unreadable(backup: nil)
            }
        }
    }

    public func save(_ state: GameState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(state).write(to: url, options: .atomic)
    }
}
