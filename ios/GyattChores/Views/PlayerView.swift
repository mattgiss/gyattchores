import GyattCore
import SwiftUI

/// A player's day: pick a card if there isn't one yet, otherwise work through it.
struct PlayerView: View {
    let player: Player
    @EnvironmentObject private var store: GameStore
    @State private var showBonusPicker = false

    var body: some View {
        Group {
            if let card = store.card(for: player) {
                CardView(player: player, card: card) {
                    showBonusPicker = true
                }
            } else {
                ChorePickerView(player: player) { chores in
                    store.buildCard(for: player, chores: chores)
                }
            }
        }
        .navigationTitle(player.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBonusPicker) {
            NavigationStack {
                ChorePickerView(player: player, bonusExcluding: store.loggedToday(for: player)) { chores in
                    store.logBonus(for: player, chores: chores)
                    showBonusPicker = false
                }
                .navigationTitle("bonus round")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showBonusPicker = false }
                    }
                }
            }
            .environmentObject(store)
            .tint(Theme.accent)
        }
    }
}

/// Name, version, XP toward the next level, and the streak.
struct PlayerHeader: View {
    let player: Player
    @EnvironmentObject private var store: GameStore

    var body: some View {
        let stats = store.stats(for: player)

        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("player")
            Text(player.name.uppercased())
                .font(.mono(.title2, weight: .black))
                .tracking(3)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 6)
            Text(stats.rank.version)
                .font(.mono(.caption))
                .tracking(4)
                .foregroundStyle(Theme.accent)
                .padding(.top, 4)

            VStack(spacing: 5) {
                HStack {
                    Text("\(stats.rank.into) / \(stats.rank.need) XP")
                    Spacer()
                    Text("\(stats.rank.nextVersion) →")
                }
                .font(.mono(.caption2))
                .foregroundStyle(.secondary)

                ProgressView(value: Double(stats.rank.into), total: Double(stats.rank.need))
                    .tint(Theme.accent)
                    .animation(.easeOut(duration: 0.4), value: stats.rank.into)
            }
            .padding(.top, 14)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(stats.rank.into) of \(stats.rank.need) XP to \(stats.rank.nextVersion)")

            if stats.streak > 0 {
                Text("🔥 \(stats.streak)-day streak · \(String(format: "%.1f", stats.momentum))x momentum")
                    .font(.mono(.caption2))
                    .foregroundStyle(Theme.warning)
                    .padding(.top, 10)
            }

            VStack(spacing: 0) {
                Hairline()
                HStack(spacing: 0) {
                    StatCell(label: "xp", value: stats.xp.formatted())
                    Rectangle().fill(Theme.hairline).frame(width: 1)
                    StatCell(label: "streak", value: "\(stats.streak)")
                    Rectangle().fill(Theme.hairline).frame(width: 1)
                    StatCell(label: "version", value: stats.rank.version)
                }
                .fixedSize(horizontal: false, vertical: true)
                Hairline()
            }
            .padding(.top, 20)
        }
    }
}

private struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.mono(.body, weight: .bold))
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.mono(.caption2))
                .tracking(2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}
