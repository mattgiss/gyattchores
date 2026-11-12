import SwiftUI
import GyattCore

/// Player select + the 30-day "25 minutes a day" log. Tapping the title 5x opens the parent gate.
/// Where a tap leads (a pushed screen on a phone, the right-hand pane on an iPad) is `RootView`'s call.
struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    /// The player whose day is open beside this list, highlighted in the two-pane layout.
    var selectedId: String? = nil
    let onPick: (Player) -> Void
    let onAdmin: () -> Void
    let onDares: () -> Void
    @State private var taps = 0
    @State private var lastTap = Date.distantPast
    @State private var editingDisplayName = false
    @State private var displayNameDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The title stays put; everything else scrolls beneath it, so nothing slides up
            // under the status bar or the Dynamic Island.
            Text("GYATTCHORES").font(.title).bold().kerning(4).foregroundStyle(Theme.accent)
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.vertical, 8).contentShape(Rectangle())
                .onTapGesture {
                    fb.tap()
                    let now = Date()
                    taps = now.timeIntervalSince(lastTap) < 2 ? taps + 1 : 1
                    lastTap = now
                    if taps >= 5 { taps = 0; onAdmin() }
                }
                .padding(.horizontal, 20).padding(.top, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(Engine.dailyMinutes) minutes a day. that's it.").foregroundStyle(.secondary)
                    Text((fb.soundOn ? "♪ sound: on" : "♪ sound: off") + "   ⇅ \(store.syncStatus)")
                        .font(.caption).foregroundStyle(.secondary).padding(.vertical, 10).contentShape(Rectangle())
                        .onTapGesture { fb.soundOn.toggle(); fb.tick(fb.soundOn) }
                        .accessibilityHint("Toggles sound")

                    // Whose phone is this? Asked once; changing it later needs the parent unlock.
                    let names = Dictionary(uniqueKeysWithValues: store.players.map { ($0.id, store.shownName($0)) })
                    let dares = store.dares
                    if let me = store.me, names[me] != nil {
                        let used = dares.filter { $0.from == me && $0.day == store.todayKey }.count
                        // Optional, so it's an outline: the players below are the main thing here.
                        OutlineButton(label: "> DARES · \(Engine.maxDaresPerDay - used) LEFT TODAY") { fb.tap(); onDares() }.padding(.top, 4)
                        HStack {
                            Text("this phone: \(names[me] ?? "")").lineLimit(1).foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            // Their own nickname, their own call: no parent unlock needed, and it can't
                            // change the username underneath.
                            Button("✎ display name") {
                                fb.tap()
                                displayNameDraft = store.displayName(me) ?? ""
                                editingDisplayName = true
                            }
                            .frame(minHeight: 36)
                        }
                        .font(.caption2).padding(.top, 4)
                    } else {
                        SectionLabel("whose phone is this?")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) { ForEach(store.players) { p in Button(store.shownName(p)) { fb.tap(); store.setMe(p) }.buttonStyle(.bordered) } }
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
                }
                .padding(.horizontal, 20).padding(.bottom, 16)
            }
            // Only scroll (and bounce) when there's more than fits.
            .scrollBounceBehavior(.basedOnSize)
        }
        .alert("Display name", isPresented: $editingDisplayName) {
            TextField("anything you like", text: $displayNameDraft)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Save") { if let me = store.me { store.setDisplayName(me, displayNameDraft) } }
            Button("Use my username", role: .destructive) { if let me = store.me { store.setDisplayName(me, "") } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Shown in the app in place of your username. Your username, chores and points stay exactly as they are. Up to \(DisplayName.maxLength) characters.")
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
