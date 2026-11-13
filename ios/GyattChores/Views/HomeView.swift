import GyattCore
import SwiftUI

/// Player select, plus the 25-minute daily log.
struct HomeView: View {
    @EnvironmentObject private var store: GameStore
    @State private var titleTaps = 0
    @State private var lastTitleTap = Date.distantPast
    @State private var showAdmin = false

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                title

                VStack(spacing: 8) {
                    ForEach(store.players) { player in
                        NavigationLink(value: player) {
                            PlayerButtonLabel(player: player, stats: store.stats(for: player))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("player-\(player.id)")
                    }
                }

                DailyLogView()
            }
            .frame(maxWidth: Theme.contentWidth)
            .padding(.horizontal, 28)
            .padding(.vertical, 48)
            .frame(maxWidth: .infinity)
        }
        .navigationDestination(for: Player.self) { player in
            PlayerView(player: player)
        }
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showAdmin) {
            AdminView()
                .environmentObject(store)
        }
    }

    /// Tapping the title five times opens the parent controls — deliberately
    /// unmarked, like the web app.
    private var title: some View {
        VStack(spacing: 6) {
            Text("GYATTCHORES")
                .font(.mono(.title2, weight: .black))
                .tracking(6)
                .foregroundStyle(Theme.accent)
            Text("select player")
                .font(.mono(.caption2))
                .tracking(4)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: tapTitle)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityAction(named: "Open parent controls") { showAdmin = true }
        .accessibilityIdentifier("title")
    }

    private func tapTitle() {
        let tap = Date()
        titleTaps = tap.timeIntervalSince(lastTitleTap) < 2 ? titleTaps + 1 : 1
        lastTitleTap = tap
        if titleTaps >= 5 {
            titleTaps = 0
            showAdmin = true
        }
    }
}

private struct PlayerButtonLabel: View {
    let player: Player
    let stats: PlayerStats

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("> " + player.name)
                .font(.mono(.callout, weight: .bold))
                .tracking(3)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 8)
            if stats.streak > 0 {
                Text("🔥\(stats.streak)")
                    .font(.mono(.caption))
                    .foregroundStyle(Theme.warning)
            }
            Text(stats.rank.version)
                .font(.mono(.caption, weight: .bold))
                .foregroundStyle(Theme.accent)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .overlay(Rectangle().strokeBorder(Theme.hairline, lineWidth: 1))
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var text = "\(player.name), \(stats.rank.version)"
        if stats.streak > 0 { text += ", \(stats.streak) day streak" }
        return text
    }
}
