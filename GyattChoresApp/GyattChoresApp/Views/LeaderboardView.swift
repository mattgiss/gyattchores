import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedTimeframe: Timeframe = .week

    enum Timeframe: String, CaseIterable {
        case week = "This Week"
        case month = "This Month"
        case allTime = "All Time"
    }

    var sortedPlayers: [Player] {
        dataManager.players.sorted { $0.weeklyPoints > $1.weeklyPoints }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Timeframe picker
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        ForEach(Timeframe.allCases, id: \.self) { timeframe in
                            Text(timeframe.rawValue).tag(timeframe)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Top 3 podium
                    if sortedPlayers.count >= 1 {
                        podiumView
                    }

                    // Full rankings
                    rankingsSection
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Leaderboard")
        }
    }

    // MARK: - Podium View

    private var podiumView: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // 2nd place
            if sortedPlayers.count >= 2 {
                PodiumCard(
                    player: sortedPlayers[1],
                    rank: 2,
                    height: 100
                )
            }

            // 1st place
            PodiumCard(
                player: sortedPlayers[0],
                rank: 1,
                height: 140,
                isGoat: true
            )

            // 3rd place
            if sortedPlayers.count >= 3 {
                PodiumCard(
                    player: sortedPlayers[2],
                    rank: 3,
                    height: 80
                )
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Rankings Section

    private var rankingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rankings")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(Array(sortedPlayers.enumerated()), id: \.element.id) { index, player in
                    RankingRow(
                        player: player,
                        rank: index + 1,
                        isLeader: index == 0
                    )

                    if index < sortedPlayers.count - 1 {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
}

// MARK: - Podium Card

struct PodiumCard: View {
    let player: Player
    let rank: Int
    let height: CGFloat
    var isGoat: Bool = false

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .secondary
        }
    }

    private var rankEmoji: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return ""
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Avatar with crown for GOAT
            ZStack {
                Text(player.avatarUrl)
                    .font(.system(size: rank == 1 ? 50 : 40))

                if isGoat {
                    Text("👑")
                        .font(.system(size: 24))
                        .offset(y: -35)
                }
            }

            Text(player.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)

            Text("\(player.weeklyPoints)")
                .font(.headline)
                .foregroundColor(.cyan)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .frame(height: height + 80)
        .background(
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [rankColor.opacity(0.3), rankColor.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: height)
            }
        )
        .overlay(alignment: .top) {
            Text(rankEmoji)
                .font(.title)
        }
    }
}

// MARK: - Ranking Row

struct RankingRow: View {
    let player: Player
    let rank: Int
    let isLeader: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Rank
            Text("\(rank)")
                .font(.headline)
                .foregroundColor(isLeader ? .cyan : .secondary)
                .frame(width: 30)

            // Avatar
            Text(player.avatarUrl)
                .font(.title2)

            // Name and stats
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(player.name)
                        .font(.body.weight(.medium))

                    if isLeader {
                        Text("LEADING")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.purple, .cyan],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }
                }

                Text("\(player.completedChores) chores completed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Points
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(player.weeklyPoints)")
                    .font(.headline)
                    .foregroundColor(.cyan)

                Text("pts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    LeaderboardView()
        .environmentObject(DataManager())
}
