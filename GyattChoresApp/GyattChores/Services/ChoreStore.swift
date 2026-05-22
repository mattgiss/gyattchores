import SwiftUI
import Combine

@MainActor
class ChoreStore: ObservableObject {
    // MARK: - Published State

    @Published var players: [Player] = Player.samples
    @Published var chores: [Chore] = Chore.all
    @Published var logs: [ChoreLog] = []
    @Published var selectedPlayer: Player?
    @Published var isAdmin = false

    // MARK: - Computed

    var pendingLogs: [ChoreLog] {
        logs.filter { $0.status == .pending }
    }

    func weeklyPoints(for player: Player) -> Int {
        let weekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        return logs
            .filter { $0.playerId == player.id && $0.status == .approved && $0.timestamp >= weekStart }
            .reduce(0) { $0 + $1.points }
    }

    func todayPoints(for player: Player) -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        return logs
            .filter { $0.playerId == player.id && $0.status == .approved && $0.timestamp >= today }
            .reduce(0) { $0 + $1.points }
    }

    var leader: Player? {
        players.max { weeklyPoints(for: $0) < weeklyPoints(for: $1) }
    }

    // MARK: - Actions

    func logChore(_ chore: Chore, for player: Player) {
        let log = ChoreLog(player: player, chore: chore)
        logs.insert(log, at: 0)
        save()

        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func approve(_ log: ChoreLog) {
        if let index = logs.firstIndex(where: { $0.id == log.id }) {
            logs[index].status = .approved
            save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    func reject(_ log: ChoreLog) {
        if let index = logs.firstIndex(where: { $0.id == log.id }) {
            logs[index].status = .rejected
            save()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    func approveAll() {
        for i in logs.indices where logs[i].status == .pending {
            logs[i].status = .approved
        }
        save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Persistence

    private let saveKey = "gyattchores_logs"

    init() {
        load()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([ChoreLog].self, from: data) {
            logs = decoded
        }
    }

    // MARK: - Shortcuts Support

    func logChoreByName(_ choreName: String, playerName: String) -> Bool {
        guard let chore = chores.first(where: { $0.name.lowercased().contains(choreName.lowercased()) }),
              let player = players.first(where: { $0.name.lowercased().contains(playerName.lowercased()) }) else {
            return false
        }
        logChore(chore, for: player)
        return true
    }
}
