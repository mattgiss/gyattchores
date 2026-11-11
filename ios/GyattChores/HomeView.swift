import SwiftUI
import GyattCore

/// Player select + the 30-day "25 minutes a day" log. Tapping the title 5x opens the parent gate.
struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @State private var path: [Player] = []
    @State private var adminOpen = false
    @State private var daresOpen = false
    @State private var taps = 0
    @State private var lastTap = Date.distantPast

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("GYATTCHORES").font(.title).bold().kerning(4).foregroundStyle(Theme.accent)
                        .padding(.vertical, 8).contentShape(Rectangle())
                        .onTapGesture {
                            fb.tap()
                            let now = Date()
                            taps = now.timeIntervalSince(lastTap) < 2 ? taps + 1 : 1
                            lastTap = now
                            if taps >= 5 { taps = 0; adminOpen = true }
                        }
                    Text("\(Engine.dailyMinutes) minutes a day. that's it.").foregroundStyle(.secondary)
                    Text((fb.soundOn ? "♪ sound: on" : "♪ sound: off") + "   ⇅ \(store.syncStatus)")
                        .font(.caption).foregroundStyle(.secondary).padding(.vertical, 10).contentShape(Rectangle())
                        .onTapGesture { fb.soundOn.toggle(); fb.tick(fb.soundOn) }
                        .accessibilityHint("Toggles sound")

                    // Whose phone is this? Asked once; changing it later needs the parent unlock.
                    let names = Dictionary(uniqueKeysWithValues: store.players.map { ($0.id, $0.name) })
                    let dares = store.dares
                    if let me = store.me, names[me] != nil {
                        let used = dares.filter { $0.from == me && $0.day == store.todayKey }.count
                        TermButton(label: "DARES · \(Engine.maxDaresPerDay - used) LEFT TODAY") { fb.tap(); daresOpen = true }.padding(.top, 4)
                        Text("this phone: \(names[me] ?? "")").font(.caption2).foregroundStyle(.secondary).padding(.top, 4)
                    } else {
                        SectionLabel("whose phone is this?")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) { ForEach(store.players) { p in Button(p.name) { fb.tap(); store.setMe(p) }.buttonStyle(.bordered) } }
                        }
                    }

                    // Yesterday's dares, revealed after midnight.
                    let yesterday = Engine.dayKey(store.calendar.date(byAdding: .day, value: -1, to: Date())!, calendar: store.calendar)
                    let revealed = dares.filter { $0.day == yesterday }
                    if !revealed.isEmpty {
                        SectionLabel("yesterday's dares · revealed")
                        let myPoints = store.me.map { id in revealed.reduce(0) { $0 + Engine.darePoints(playerId: id, $1, logs: store.logs, calendar: store.calendar) } } ?? 0
                        if myPoints > 0 {
                            Text("★ you earned +\(myPoints) from dares").bold().foregroundStyle(Theme.accent).padding(.bottom, 6)
                                .task { if store.firstReveal(yesterday) { fb.dareLanded() } }
                        }
                        ForEach(revealed, id: \.self) { d in
                            let landed = Engine.dareLanded(d, logs: store.logs, calendar: store.calendar)
                            HStack {
                                Text("\(names[d.from] ?? d.from) → \(names[d.target] ?? d.target): \(store.poolById[d.choreId]?.name ?? d.choreId)").font(.callout)
                                Spacer()
                                Text(landed ? "✓ +\(Engine.dareGuesserPoints)" : "✗").foregroundStyle(landed ? Theme.good : .secondary)
                            }
                            .padding(.vertical, 3)
                        }
                    }

                    SectionLabel("this week")
                    let board = store.players.map { ($0, Engine.weekPoints(playerId: $0.id, logs: store.logs, dares: dares, now: Date(), calendar: store.calendar)) }
                        .sorted { $0.1 > $1.1 }
                    ForEach(Array(board.enumerated()), id: \.element.0.id) { i, row in
                        HStack {
                            Text("\(i + 1). ").foregroundStyle(i == 0 && row.1 > 0 ? Theme.accent : .secondary)
                            Text(row.0.name).fontWeight(i == 0 && row.1 > 0 ? .bold : .regular)
                            Spacer()
                            Text("\(row.1) pts").foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    SectionLabel("who's playing")
                    ForEach(store.players) { p in
                        Button { fb.tap(); path.append(p) } label: {
                            HStack {
                                Text("> ").foregroundStyle(Theme.accent)
                                Text(p.name).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(store.rank(p.id).version) · 🔥\(store.streak(p.id))").foregroundStyle(.secondary)
                            }
                            .frame(minHeight: 64).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }

                    SectionLabel("daily log · last \(Engine.logDays) days")
                    let days = Engine.recentDays(now: Date(), calendar: store.calendar)
                    ForEach(store.players) { p in
                        DailyLogRow(player: p, days: days,
                                    byDay: Engine.minutesByDay(playerId: p.id, logs: store.logs, pool: store.poolById, calendar: store.calendar))
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
            }
            .navigationDestination(for: Player.self) { PlayerView(player: $0) }
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $daresOpen) {
            DaresView().environmentObject(store).environmentObject(fb).fontDesign(.monospaced).tint(Theme.accent)
        }
        .fullScreenCover(isPresented: $adminOpen) {
            AdminView().environmentObject(store).environmentObject(fb).fontDesign(.monospaced).tint(Theme.accent)
        }
    }
}

private struct DailyLogRow: View {
    let player: Player
    let days: [Date]
    let byDay: [Date: Int]

    var body: some View {
        let hits = days.filter { (byDay[$0] ?? 0) >= Engine.dailyMinutes }.count
        VStack(spacing: 6) {
            HStack {
                Text(player.name).font(.callout)
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
