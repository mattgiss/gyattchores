import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedPlayer: Player?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with weather and theme toggle
                    headerSection

                    // Player selection
                    playerSelectionSection

                    // Available chores
                    if let player = selectedPlayer {
                        availableChoresSection(for: player)
                    }

                    // Pending approvals preview
                    if !dataManager.pendingCompletions.isEmpty {
                        pendingPreviewSection
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("GyattChores")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { authManager.toggleColorScheme() }) {
                        Image(systemName: authManager.colorScheme == .dark ? "sun.max.fill" : "moon.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { authManager.logout() }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .refreshable {
                await dataManager.loadAll()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 16) {
            // Date and greeting
            VStack(alignment: .leading, spacing: 4) {
                Text(Date(), format: .dateTime.weekday(.wide).month().day())
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(greeting)
                    .font(.title2.bold())
            }

            Spacer()

            // Quick stats
            if let player = selectedPlayer {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(dataManager.formatPoints(player.weeklyPoints))")
                        .font(.title.bold())
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("This Week")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good Morning!"
        } else if hour < 17 {
            return "Good Afternoon!"
        } else {
            return "Good Evening!"
        }
    }

    // MARK: - Player Selection

    private var playerSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Who's doing chores?")
                .font(.headline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach(dataManager.players) { player in
                    PlayerButton(
                        player: player,
                        isSelected: selectedPlayer?.id == player.id,
                        isLeader: dataManager.currentWeekLeader?.id == player.id
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPlayer = player
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
        }
    }

    // MARK: - Available Chores

    private func availableChoresSection(for player: Player) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Available Chores")
                    .font(.headline)

                Spacer()

                Text("\(availableChores(for: player).count) available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(availableChores(for: player)) { chore in
                    ChoreCard(chore: chore) {
                        Task {
                            try? await dataManager.claimChore(chore, for: player)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                }
            }
        }
    }

    private func availableChores(for player: Player) -> [Chore] {
        dataManager.chores.filter { dataManager.isChoreAvailable($0, for: player) }
    }

    // MARK: - Pending Preview

    private var pendingPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pending Approval")
                    .font(.headline)

                Spacer()

                Text("\(dataManager.pendingCompletions.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .clipShape(Capsule())
            }

            ForEach(dataManager.pendingCompletions.prefix(3)) { completion in
                PendingCompletionRow(completion: completion)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Player Button

struct PlayerButton: View {
    let player: Player
    let isSelected: Bool
    let isLeader: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Text(player.avatarUrl)
                        .font(.system(size: 40))

                    if isLeader {
                        Text("👑")
                            .font(.system(size: 16))
                            .offset(x: 20, y: -20)
                    }
                }

                Text(player.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.cyan.opacity(0.15) : Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.cyan : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chore Card

struct ChoreCard: View {
    let chore: Chore
    let onClaim: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onClaim) {
            VStack(spacing: 12) {
                Text(chore.icon)
                    .font(.system(size: 36))

                VStack(spacing: 4) {
                    Text(chore.name)
                        .font(.subheadline.weight(.medium))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text("\(chore.baseValue) pts")
                        .font(.caption)
                        .foregroundColor(.cyan)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Pending Completion Row

struct PendingCompletionRow: View {
    let completion: ChoreCompletion

    var body: some View {
        HStack(spacing: 12) {
            Text(completion.choreIcon ?? "❓")
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(completion.choreName ?? "Unknown")
                    .font(.subheadline.weight(.medium))

                Text(completion.playerName ?? "Unknown")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(completion.valueAwarded) pts")
                .font(.caption)
                .foregroundColor(.orange)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    DashboardView()
        .environmentObject(AuthManager())
        .environmentObject(DataManager())
}
