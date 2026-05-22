import SwiftUI
import Combine

@MainActor
class DataManager: ObservableObject {
    @Published var players: [Player] = []
    @Published var chores: [Chore] = []
    @Published var pendingCompletions: [ChoreCompletion] = []
    @Published var isLoading = false
    @Published var error: Error?

    // GOAT tracking
    @Published var currentWeekLeader: Player?
    @Published var lastWeekGoat: Player?

    // Points conversion
    static let pointsPerDollar = 250

    private let supabase = SupabaseClient.shared

    // MARK: - Data Loading

    func loadAll() async {
        isLoading = true
        error = nil

        do {
            async let playersTask = supabase.fetchPlayers()
            async let choresTask = supabase.fetchChores()
            async let pendingTask = supabase.fetchPendingCompletions()

            let (fetchedPlayers, fetchedChores, fetchedPending) = try await (playersTask, choresTask, pendingTask)

            self.players = fetchedPlayers
            self.chores = fetchedChores
            self.pendingCompletions = fetchedPending

            // Calculate weekly stats
            await calculateWeeklyStats()

        } catch {
            self.error = error
        }

        isLoading = false
    }

    private func calculateWeeklyStats() async {
        let weekStart = getWeekStart()

        do {
            let totals = try await supabase.fetchWeeklyTotals(weekStart: weekStart)

            // Update player points
            for (playerId, total) in totals {
                if let index = players.firstIndex(where: { $0.id == playerId }) {
                    players[index].weeklyPoints = total
                }
            }

            // Find current week leader
            currentWeekLeader = players.max(by: { $0.weeklyPoints < $1.weeklyPoints })

        } catch {
            print("Error calculating weekly stats: \(error)")
        }
    }

    // MARK: - Chore Actions

    func claimChore(_ chore: Chore, for player: Player) async throws {
        let completion = try await supabase.claimChore(
            playerId: player.id,
            choreId: chore.id,
            value: chore.baseValue
        )
        pendingCompletions.insert(completion, at: 0)
    }

    func approveCompletion(_ completion: ChoreCompletion) async throws {
        try await supabase.approveCompletion(id: completion.id)
        pendingCompletions.removeAll { $0.id == completion.id }

        // Refresh stats
        await loadAll()
    }

    func rejectCompletion(_ completion: ChoreCompletion) async throws {
        try await supabase.rejectCompletion(id: completion.id)
        pendingCompletions.removeAll { $0.id == completion.id }
    }

    // MARK: - Helpers

    func getWeekStart() -> String {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday

        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysToMonday = (weekday == 1) ? -6 : (2 - weekday)

        let monday = calendar.date(byAdding: .day, value: daysToMonday, to: today)!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: monday)
    }

    func isChoreAvailable(_ chore: Chore, for player: Player) -> Bool {
        // Check cooldown
        let cooldownHours = chore.cooldownHours
        let cutoff = Date().addingTimeInterval(-Double(cooldownHours) * 3600)

        // For single-claim chores, check if ANY player has claimed it
        if chore.singleClaim {
            let recentClaims = pendingCompletions.filter { completion in
                completion.choreId == chore.id &&
                completion.completedAt > cutoff
            }
            return recentClaims.isEmpty
        }

        // For regular chores, check if THIS player has claimed it
        let playerClaims = pendingCompletions.filter { completion in
            completion.choreId == chore.id &&
            completion.playerId == player.id &&
            completion.completedAt > cutoff
        }
        return playerClaims.isEmpty
    }

    func formatPoints(_ points: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: points)) ?? "\(points)"
    }

    func pointsToDollars(_ points: Int) -> String {
        let dollars = Double(points) / Double(Self.pointsPerDollar)
        return String(format: "$%.2f", dollars)
    }
}
