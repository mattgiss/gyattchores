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
    /// At the largest text sizes a row's name and numbers don't fit side by side: stack them.
    @Environment(\.dynamicTypeSize) private var typeSize
    #if FAMILY_SYNC
    var onDares: () -> Void = {}
    #endif

    var body: some View {
        // One list, like a Clear list: the title on the first band, then each player on the next,
        // red down to yellow, in this week's order. Few players? Their rows grow to fill the screen.
        let board = store.players.map { ($0, store.weekPoints($0.id)) }.sorted { $0.1 > $1.1 }
        let bands = board.count + 1
        GeometryReader { geo in
            let rowHeight: CGFloat = 64
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.top, geo.safeAreaInsets.top)
                        .background(Palette.heat.band(0, of: bands))

                    if store.players.isEmpty {
                        Text("Nobody's playing yet. An admin can add players in Admin.")
                            .foregroundStyle(Color.done).padding(20)
                    }
                    ForEach(Array(board.enumerated()), id: \.element.0.id) { i, row in
                        playerRow(row.0, place: i, points: row.1, band: i + 1, of: bands, height: rowHeight)
                    }

                    #if FAMILY_SYNC
                    FamilyHomeSection(onDares: onDares)
                    #endif

                    SectionLabel("The last \(Engine.logDays) days")
                    let days = Engine.recentDays(now: Date(), calendar: store.calendar)
                    ForEach(store.players) { p in
                        DailyLogRow(name: store.shownName(p), days: days,
                                    byDay: Engine.minutesByDay(playerId: p.id, logs: store.logs, pool: store.poolById, calendar: store.calendar))
                    }
                    .padding(.horizontal, 20)

                    Group {
                        #if !FAMILY_SYNC
                        Text("Everything here stays on this device. No accounts, nothing sent anywhere.")
                        #endif
                        // Which build a phone is running, as on Android: handy after a TestFlight update.
                        Text("Version \(AppInfo.version)")
                    }
                    .font(.app(.caption2)).foregroundStyle(Color.done).padding(.horizontal, 20).padding(.top, 8)
                }
                .padding(.bottom, 24)
            }
            .ignoresSafeArea(edges: .top)
            .scrollBounceBehavior(.basedOnSize)
            .noScrollEdgeShade()
        }
        .background(Color.appBackground)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("GyattChores").font(.app(fixedSize: 28, weight: .black)).lineLimit(1).minimumScaleFactor(0.5)
                Spacer(minLength: 8)
                // Approving chores and changing players or chores: behind an admin's code.
                // A look of your own, for this phone.
                Button { fb.tap(); ThemeStore.shared.picking = true } label: {
                    Text("Theme").font(.app(.callout)).fontWeight(.bold).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                Button { fb.tap(); onAdmin() } label: {
                    Text("Admin").font(.app(.callout)).fontWeight(.bold).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .padding(.leading, 12)
            }
            Text("\(Engine.dailyMinutes) minutes a day. That's it.").font(.app(.callout)).fontWeight(.semibold).opacity(0.85)
            Text(soundLine)
                .font(.app(.caption)).fontWeight(.semibold).opacity(0.7).padding(.vertical, 4).contentShape(Rectangle())
                .onTapGesture { fb.soundOn.toggle(); fb.tick(fb.soundOn) }
                .accessibilityHint("Toggles sound")
        }
        .foregroundStyle(Palette.heat.ink)
        .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 10)
    }

    /// A player's band: place and name on the left, this week's points and their version and
    /// streak on the right. The whole band is the button.
    private func playerRow(_ p: Player, place: Int, points: Int, band: Int, of bands: Int, height: CGFloat) -> some View {
        let isSelected = p.id == selectedId
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 12))
        return Button { fb.tap(); onPick(p) } label: {
            Band(index: band, count: bands, minHeight: height) {
                layout {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(place + 1)").font(.app(.callout)).fontWeight(.black).opacity(0.6)
                        // One line, shrinking a little before it cuts off: a wrapped, hyphenated
                        // name looks broken in the narrow left pane of the two-pane layout.
                        Text(store.shownName(p)).font(.app(.title3)).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
                        Text("\(points) pts").font(.app(.headline)).fontWeight(.black)
                        Text(store.streak(p.id) == 0 ? store.rank(p.id).version : "\(store.rank(p.id).version) · \(store.streak(p.id))-day streak").font(.app(.footnote)).fontWeight(.semibold).opacity(0.8)
                    }
                    .lineLimit(1)
                }
            }
            .overlay(alignment: .leading) { if isSelected { Rectangle().fill(Palette.heat.ink).frame(width: 6) } }
        }
        .buttonStyle(BandPress())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Pressing a band dims it a touch and settles it back: the whole row is the button.
struct BandPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension HomeView {
    private var soundLine: String {
        let sound = fb.soundOn ? "Sound on" : "Sound off"
        #if FAMILY_SYNC
        return sound + " · " + store.syncStatus.prefix(1).uppercased() + store.syncStatus.dropFirst()
        #else
        return sound
        #endif
    }
}

/// The app's version and build, e.g. "1.0 (202611141817)", and which kind of build it is.
enum AppInfo {
    static var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let v = info["CFBundleShortVersionString"] as? String ?? "?"
        let b = info["CFBundleVersion"] as? String ?? "?"
        #if FAMILY_SYNC
        return "\(v) (\(b)) · family"
        #else
        return "\(v) (\(b))"
        #endif
    }
}

#if FAMILY_SYNC
/// Family build: whose phone this is, the dares button, and yesterday's dares revealed.
private struct FamilyHomeSection: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    let onDares: () -> Void

    var body: some View {
        let names = Dictionary(store.members.map { ($0.id, store.shownName($0)) }, uniquingKeysWith: { a, _ in a })
        let dares = store.dares
        // Whose phone is this? Asked once; changing it later needs an admin.
        if let me = store.me, names[me] != nil {
            let used = dares.filter { $0.from == me && $0.day == store.todayKey }.count
            // Optional, so it's an outline: the players below are the main thing here.
            TermButton(label: "Make a dare · \(Engine.maxDaresPerDay - used) left today") { fb.tap(); onDares() }
                .environment(\.palette, .plum)
            Text("This is \(names[me] ?? "")'s phone.").lineLimit(1).font(.app(.caption2)).foregroundStyle(Color.done).padding(.horizontal, 20).padding(.top, 8)
        } else if !store.players.isEmpty {
            SectionLabel("Whose phone is this?")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.players) { p in
                        Button(store.shownName(p)) { fb.tap(); store.setMe(p) }
                            .font(.app(.callout)).fontWeight(.bold).foregroundStyle(Color.appText)
                            .padding(.horizontal, 18).frame(minHeight: 44).background(Color.surface, in: Capsule())
                    }
                }
                .padding(.horizontal, 20)
            }
        }

        // Yesterday's dares, revealed after midnight.
        let yesterday = Engine.dayKey(store.calendar.date(byAdding: .day, value: -1, to: Date())!, calendar: store.calendar)
        let revealed = dares.filter { $0.day == yesterday }
        if !revealed.isEmpty {
            SectionLabel("Yesterday's dares")
            let myPoints = store.me.map { id in revealed.reduce(0) { $0 + Engine.darePoints(playerId: id, $1, logs: store.logs, calendar: store.calendar) } } ?? 0
            if myPoints > 0 {
                Text("You earned \(myPoints) points from dares.").bold().foregroundStyle(Palette.plum.ink).padding(.horizontal, 20).padding(.bottom, 6)
                    .task { if store.firstReveal(yesterday) { fb.dareLanded() } }
            }
            ForEach(revealed, id: \.self) { d in
                let landed = Engine.dareLanded(d, logs: store.logs, calendar: store.calendar)
                HStack {
                    Text("\(names[d.from] ?? d.from) dared \(names[d.target] ?? d.target) to \(store.choreName(d.choreId)).").font(.app(.callout))
                    Spacer()
                    Text(landed ? "Done, +\(Engine.dareGuesserPoints)" : "Didn't happen").foregroundStyle(landed ? Theme.good : Color.done)
                }
                .padding(.horizontal, 20).padding(.vertical, 3)
            }
        }
    }
}
#endif

private struct DailyLogRow: View {
    let name: String
    let days: [Date]
    let byDay: [Date: Int]

    var body: some View {
        let hits = days.filter { (byDay[$0] ?? 0) >= Engine.dailyMinutes }.count
        VStack(spacing: 6) {
            HStack {
                Text(name).font(.app(.callout)).lineLimit(1)
                Spacer()
                Text("\(hits)/\(days.count) · \(Int((Double(hits) * 100 / Double(days.count)).rounded()))%").font(.app(.footnote)).fontWeight(.semibold).foregroundStyle(Color.done)
            }
            HStack(spacing: 2) {
                ForEach(days, id: \.self) { d in
                    let mins = byDay[d] ?? 0
                    let a = Engine.cellAlpha(mins)
                    Rectangle()
                        // A full day is Clear red; part of one runs back up the gradient towards yellow.
                        .fill(a == 0 ? Color.surface : Palette.heat.band(Int(((1 - a) * 5).rounded()), of: 6))
                        .overlay { if d == days.last { Rectangle().stroke(Color.appText.opacity(mins >= Engine.dailyMinutes ? 0.9 : 0.35), lineWidth: 1) } }
                        .aspectRatio(0.6, contentMode: .fit)
                        .accessibilityLabel("\(d.formatted(date: .abbreviated, time: .omitted)), \(mins) minutes")
                }
            }
        }
        .padding(.bottom, 14)
    }
}
