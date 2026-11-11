import Combine
import Foundation
import GyattCore

/// What a player's header shows.
struct PlayerStats {
    let xp: Int
    let rank: Rank
    let streak: Int
    let momentum: Double
}

/// The app's single source of truth: wraps the `Game` value from GyattCore,
/// publishes changes to SwiftUI, and saves to disk after every move.
///
/// Used from the main thread only.
final class GameStore: ObservableObject {
    @Published private(set) var game: Game
    /// The moment the UI is rendering for. Refreshed on every move and whenever
    /// the app comes forward, so "today" rolls over without a relaunch.
    @Published private(set) var now: Date
    /// Set when saving or loading went wrong; the root view shows it as an alert.
    @Published var saveProblem: String?

    let players = ChoreCatalog.players
    private let archive: GameArchive

    init(archive: GameArchive = GameStore.defaultArchive, now: Date = Date()) {
        self.archive = archive
        self.now = now

        var game = Game()
        var problem: String?
        switch archive.load() {
        case .empty:
            break
        case .loaded(let state):
            game = Game(state: state)
        case .unreadable(let backup):
            if let backup {
                problem = "The saved chore data couldn't be read, so the app started fresh. The old file was kept as \(backup.lastPathComponent)."
            } else {
                problem = "The saved chore data couldn't be read, so the app started fresh."
            }
        }
        game.pruneCards(now: now)
        self.game = game
        self.saveProblem = problem
    }

    static var defaultArchive: GameArchive {
        let manager = FileManager.default
        let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? manager.temporaryDirectory
        return GameArchive(url: base
            .appendingPathComponent("GyattChores", isDirectory: true)
            .appendingPathComponent("game.json"))
    }

    /// The store the app launches with. Debug builds understand two launch
    /// arguments, used by the UI tests and handy when developing:
    ///   -resetData   start from an empty save file
    ///   -demoData    a month of made-up history, kept apart from real data
    static func forLaunch() -> GameStore {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-demoData") {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("gyattchores-demo.json")
            let archive = GameArchive(url: url)
            try? archive.save(DemoData.state(now: Date()))
            return GameStore(archive: archive)
        }
        if arguments.contains("-resetData") {
            try? FileManager.default.removeItem(at: defaultArchive.url)
        }
        #endif
        return GameStore()
    }

    // MARK: - Reading

    var engine: Engine { game.engine }
    var logs: [ChoreLog] { game.logs }
    var hasApprovedLogs: Bool { logs.contains { $0.status == .approved } }
    var pendingCount: Int { logs.filter { $0.status == .pending }.count }

    func stats(for player: Player) -> PlayerStats {
        let xp = engine.xp(playerId: player.id, logs: logs)
        let streak = engine.streak(playerId: player.id, logs: logs, now: now)
        return PlayerStats(xp: xp, rank: Engine.rank(xp: xp), streak: streak, momentum: Engine.momentumMult(streak: streak))
    }

    func dailyLog(for player: Player) -> DailyLogRow {
        engine.dailyLog(playerId: player.id, logs: logs, now: now)
    }

    /// Today's card, whether built on this device or rebuilt from the logs.
    func card(for player: Player) -> DailyCard? {
        game.card(for: player.id, now: now)
    }

    func pickableChores(for player: Player) -> [CardChore] {
        engine.pickableChores(playerId: player.id, logs: logs, now: now)
    }

    func todayState(for player: Player, card: DailyCard) -> TodayState {
        engine.todayState(playerId: player.id, logs: logs, card: card, now: now)
    }

    /// Chores this player has already logged today, on the card or as a bonus.
    func loggedToday(for player: Player) -> Set<String> {
        guard let card = card(for: player) else { return [] }
        return todayState(for: player, card: card).loggedToday
    }

    // MARK: - Moves

    func refreshClock() {
        now = Date()
        game.pruneCards(now: now)
    }

    func buildCard(for player: Player, chores: [CardChore]) {
        move { $0.buildCard(for: player.id, chores: chores, now: $1) }
    }

    func discardCard(for player: Player) {
        move { $0.discardCard(for: player.id, now: $1) }
    }

    func toggleChore(at index: Int, for player: Player) {
        move { $0.toggleChore(at: index, for: player.id, now: $1) }
    }

    func submitCard(for player: Player) {
        move { game, moment in _ = game.submitCard(for: player, now: moment) }
    }

    func logBonus(for player: Player, chores: [CardChore]) {
        move { $0.logBonus(for: player, chores: chores, now: $1) }
    }

    func setStatus(_ status: LogStatus, for log: ChoreLog) {
        move { game, _ in game.setStatus(status, forLog: log.id) }
    }

    private func move(_ change: (inout Game, Date) -> Void) {
        let moment = Date()
        var next = game
        change(&next, moment)
        now = moment
        game = next
        do {
            try archive.save(next.state)
        } catch {
            saveProblem = "Couldn't save your chores: \(error.localizedDescription)"
        }
    }
}
