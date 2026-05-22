import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedPlayer: Player?
    @State private var showAchievements = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Player selector
                    playerSelector

                    if let player = selectedPlayer {
                        // Stats overview
                        statsOverview(for: player)

                        // Weekly breakdown
                        weeklyBreakdown(for: player)

                        // Achievements button
                        achievementsButton

                        // Payout info
                        payoutSection(for: player)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .sheet(isPresented: $showAchievements) {
                if let player = selectedPlayer {
                    AchievementsSheet(player: player)
                }
            }
        }
    }

    // MARK: - Player Selector

    private var playerSelector: some View {
        HStack(spacing: 16) {
            ForEach(dataManager.players) { player in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedPlayer = player
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(player.avatarUrl)
                            .font(.system(size: 44))

                        Text(player.name)
                            .font(.caption.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedPlayer?.id == player.id ?
                                  Color.cyan.opacity(0.15) :
                                  Color(.secondarySystemGroupedBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(selectedPlayer?.id == player.id ? Color.cyan : Color.clear, lineWidth: 2)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Stats Overview

    private func statsOverview(for player: Player) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ProfileStatCard(
                title: "This Week",
                value: "\(player.weeklyPoints)",
                icon: "star.fill",
                color: .cyan
            )

            ProfileStatCard(
                title: "Best Week",
                value: "\(player.bestWeekTotal)",
                icon: "trophy.fill",
                color: .yellow
            )

            ProfileStatCard(
                title: "Total Chores",
                value: "\(player.completedChores)",
                icon: "checkmark.circle.fill",
                color: .green
            )
        }
    }

    // MARK: - Weekly Breakdown

    private func weeklyBreakdown(for player: Player) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 Days")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { dayOffset in
                    let day = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
                    let dayName = day.formatted(.dateTime.weekday(.narrow))

                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(dayOffset == 0 ? Color.cyan : Color.cyan.opacity(0.3))
                            .frame(height: CGFloat.random(in: 20...60)) // Placeholder

                        Text(dayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 80)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Achievements Button

    private var achievementsButton: some View {
        Button {
            showAchievements = true
        } label: {
            HStack {
                Image(systemName: "medal.fill")
                    .foregroundColor(.yellow)

                Text("View Achievements")
                    .fontWeight(.medium)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Payout Section

    private func payoutSection(for player: Player) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Earnings")
                .font(.headline)

            VStack(spacing: 16) {
                HStack {
                    Text("This Period")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(dataManager.pointsToDollars(player.weeklyPoints))
                        .font(.title3.bold())
                        .foregroundColor(.green)
                }

                Divider()

                // Tiered payout explanation
                VStack(alignment: .leading, spacing: 8) {
                    Text("Payout Tiers")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)

                    PayoutTierRow(range: "0 - 4,999", rate: "$0.004/pt")
                    PayoutTierRow(range: "5,000 - 9,999", rate: "$0.005/pt")
                    PayoutTierRow(range: "10,000 - 14,999", rate: "$0.006/pt")
                    PayoutTierRow(range: "15,000+", rate: "$0.007/pt")
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }
}

struct ProfileStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3.bold())

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

struct PayoutTierRow: View {
    let range: String
    let rate: String

    var body: some View {
        HStack {
            Text(range)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(rate)
                .font(.caption.weight(.medium))
        }
    }
}

struct AchievementsSheet: View {
    let player: Player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(Achievement.samples) { achievement in
                        AchievementCard(achievement: achievement, isEarned: false)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    let isEarned: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(achievement.icon)
                .font(.system(size: 36))
                .opacity(isEarned ? 1.0 : 0.3)

            Text(achievement.name)
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isEarned ?
                      Color.yellow.opacity(0.15) :
                      Color(.secondarySystemGroupedBackground))
        )
        .opacity(isEarned ? 1.0 : 0.6)
    }
}

#Preview {
    ProfileView()
        .environmentObject(DataManager())
}
