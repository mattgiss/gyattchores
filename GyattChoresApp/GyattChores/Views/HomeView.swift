import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: ChoreStore
    @State private var showSuccess = false
    @State private var lastLoggedChore: Chore?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Player Selector - Always visible at top
                playerSelector

                // Quick Stats
                if let player = store.selectedPlayer {
                    statsBar(for: player)
                }

                // Chore Grid - Main action area
                choreGrid
            }
            .padding()
        }
        .navigationTitle("GyattChores")
        .overlay {
            if showSuccess, let chore = lastLoggedChore {
                successOverlay(chore: chore)
            }
        }
    }

    // MARK: - Player Selector

    private var playerSelector: some View {
        HStack(spacing: 16) {
            ForEach(store.players) { player in
                PlayerButton(
                    player: player,
                    isSelected: store.selectedPlayer?.id == player.id,
                    isLeader: store.leader?.id == player.id,
                    points: store.weeklyPoints(for: player)
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        store.selectedPlayer = player
                    }
                }
            }
        }
    }

    // MARK: - Stats Bar

    private func statsBar(for player: Player) -> some View {
        let todayPts = store.todayPoints(for: player)
        let lastMonthTodayPts = store.lastMonthTodayPoints(for: player)
        let weekPts = store.weeklyPoints(for: player)
        let lastMonthWeekPts = store.lastMonthWeeklyPoints(for: player)

        return HStack(spacing: 20) {
            StatPill(
                label: "Today",
                value: "\(todayPts)",
                icon: "sun.max.fill",
                color: .orange,
                trend: (todayPts > 0 || lastMonthTodayPts > 0) ? todayPts - lastMonthTodayPts : nil
            )
            StatPill(
                label: "This Week",
                value: "\(weekPts)",
                icon: "calendar",
                color: .cyan,
                trend: (weekPts > 0 || lastMonthWeekPts > 0) ? weekPts - lastMonthWeekPts : nil
            )
        }
    }

    // MARK: - Chore Grid

    private var choreGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            ForEach(store.chores) { chore in
                ChoreButton(chore: chore, isEnabled: store.selectedPlayer != nil) {
                    logChore(chore)
                }
            }
        }
    }

    // MARK: - Log Chore

    private func logChore(_ chore: Chore) {
        guard let player = store.selectedPlayer else { return }

        store.logChore(chore, for: player)
        lastLoggedChore = chore

        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            showSuccess = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showSuccess = false
            }
        }
    }

    // MARK: - Success Overlay

    private func successOverlay(chore: Chore) -> some View {
        VStack(spacing: 16) {
            Text(chore.icon)
                .font(.system(size: 60))

            Text("Logged!")
                .font(.title2.bold())

            Text("+\(chore.points) pts")
                .font(.headline)
                .foregroundStyle(.cyan)
        }
        .frame(width: 200, height: 200)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Player Button

struct PlayerButton: View {
    let player: Player
    let isSelected: Bool
    let isLeader: Bool
    let points: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Text(player.avatar)
                        .font(.system(size: 48))

                    if isLeader && points > 0 {
                        Text("👑")
                            .font(.system(size: 20))
                            .offset(x: 24, y: -24)
                    }
                }

                Text(player.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Text("\(points) pts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.cyan.opacity(0.15) : Color(.secondarySystemGroupedBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? Color.cyan : Color.clear, lineWidth: 3)
                    }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    var trend: Int? = nil

    private var trendArrow: String {
        guard let delta = trend else { return "" }
        return delta > 0 ? "↑" : delta < 0 ? "↓" : "→"
    }

    private var trendColor: Color {
        guard let delta = trend else { return .secondary }
        return delta > 0 ? .green : delta < 0 ? .red : .secondary
    }

    private var trendLabel: String {
        guard let delta = trend else { return "" }
        return delta > 0 ? "+\(delta)" : "\(delta)"
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if trend != nil {
                VStack(spacing: 0) {
                    Text(trendArrow)
                        .font(.caption.bold())
                        .foregroundStyle(trendColor)
                    Text(trendLabel)
                        .font(.caption2)
                        .foregroundStyle(trendColor)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Chore Button

struct ChoreButton: View {
    let chore: Chore
    let isEnabled: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Text(chore.icon)
                    .font(.system(size: 36))

                Text(chore.name)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 40)

                Text("\(chore.points) pts")
                    .font(.caption.bold())
                    .foregroundStyle(.cyan)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            }
            .opacity(isEnabled ? 1.0 : 0.5)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(ChoreStore())
    }
}
