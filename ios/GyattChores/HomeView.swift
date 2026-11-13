import SwiftUI
import GyattCore

/// The scoreboard: this week's standings, who's playing, and the 30-day "25 minutes a day" log.
/// Where a tap leads (a pushed screen on a phone, the right-hand pane on an iPad) is `RootView`'s call.
struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    /// The player whose day is open beside this list, highlighted in the two-pane layout.
    var selectedId: String? = nil
    let onPick: (Player) -> Void
    let onAdmin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The title stays put; everything else scrolls beneath it, so nothing slides up
            // under the status bar or the Dynamic Island.
            HStack(alignment: .firstTextBaseline) {
                Text("GYATTCHORES").font(.title).bold().kerning(4).foregroundStyle(Theme.accent)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 8)
                // Approving chores and changing players or chores: behind an admin's code.
                Button { fb.tap(); onAdmin() } label: {
                    Text("admin").font(.footnote).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 20).padding(.top, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(Engine.dailyMinutes) minutes a day. that's it.").foregroundStyle(.secondary)
                    Text(fb.soundOn ? "♪ sound: on" : "♪ sound: off")
                        .font(.caption).foregroundStyle(.secondary).padding(.vertical, 10).contentShape(Rectangle())
                        .onTapGesture { fb.soundOn.toggle(); fb.tick(fb.soundOn) }
                        .accessibilityHint("Toggles sound")

                    if store.players.isEmpty {
                        Text("nobody's playing yet. an admin can add players in the admin area.")
                            .foregroundStyle(.secondary).padding(.vertical, 24)
                    }

                    SectionLabel("this week")
                    let board = store.players.map { ($0, store.weekPoints($0.id)) }
                        .sorted { $0.1 > $1.1 }
                    ForEach(Array(board.enumerated()), id: \.element.0.id) { i, row in
                        HStack {
                            Text("\(i + 1). ").foregroundStyle(i == 0 && row.1 > 0 ? Theme.accent : .secondary)
                            Text(store.shownName(row.0)).fontWeight(i == 0 && row.1 > 0 ? .bold : .regular).lineLimit(1).minimumScaleFactor(0.75)
                            Spacer()
                            Text("\(row.1) pts").foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    SectionLabel("who's playing")
                    ForEach(store.players) { p in
                        let isSelected = p.id == selectedId
                        Button { fb.tap(); onPick(p) } label: {
                            HStack {
                                Text("> ").foregroundStyle(Theme.accent)
                                // One line, shrinking a little before it cuts off: a wrapped, hyphenated
                                // name looks broken in the narrow left pane of the two-pane layout.
                                Text(store.shownName(p)).font(.headline).lineLimit(1).minimumScaleFactor(0.75)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(store.rank(p.id).version) · 🔥\(store.streak(p.id))").foregroundStyle(.secondary)
                            }
                            .frame(minHeight: 64).contentShape(Rectangle())
                            .padding(.horizontal, 10)
                            .background(isSelected ? Theme.accent.opacity(0.12) : Color.clear)
                            .padding(.horizontal, -10)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        Divider()
                    }

                    SectionLabel("daily log · last \(Engine.logDays) days")
                    let days = Engine.recentDays(now: Date(), calendar: store.calendar)
                    ForEach(store.players) { p in
                        DailyLogRow(name: store.shownName(p), days: days,
                                    byDay: Engine.minutesByDay(playerId: p.id, logs: store.logs, pool: store.poolById, calendar: store.calendar))
                    }

                    Text("everything here stays on this device. no accounts, nothing sent anywhere.")
                        .font(.caption2).foregroundStyle(.secondary).padding(.top, 8)
                }
                .padding(.horizontal, 20).padding(.bottom, 16)
            }
            // Only scroll (and bounce) when there's more than fits.
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

private struct DailyLogRow: View {
    let name: String
    let days: [Date]
    let byDay: [Date: Int]

    var body: some View {
        let hits = days.filter { (byDay[$0] ?? 0) >= Engine.dailyMinutes }.count
        VStack(spacing: 6) {
            HStack {
                Text(name).font(.callout).lineLimit(1)
                Spacer()
                Text("\(hits)/\(days.count) · \(Int((Double(hits) * 100 / Double(days.count)).rounded()))%").font(.footnote).foregroundStyle(.secondary)
            }
            HStack(spacing: 2) {
                ForEach(days, id: \.self) { d in
                    let mins = byDay[d] ?? 0
                    let a = Engine.cellAlpha(mins)
                    Rectangle()
                        .fill(a == 0 ? Color(.systemGray5) : Theme.accent.opacity(a))
                        .overlay { if d == days.last { Rectangle().stroke(mins >= Engine.dailyMinutes ? Theme.accent : Color(.systemGray2), lineWidth: 1) } }
                        .aspectRatio(0.6, contentMode: .fit)
                        .accessibilityLabel("\(d.formatted(date: .abbreviated, time: .omitted)), \(mins) minutes")
                }
            }
        }
        .padding(.bottom, 14)
    }
}
