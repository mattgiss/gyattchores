import SwiftUI
import DoYourWorkCore

/// The scoreboard: this week's standings, who's playing, and the 30-day "25 minutes a day" log.
/// Where a tap leads (a pushed screen on a phone, the right-hand pane on an iPad) is `RootView`'s call.
struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    /// The player whose day is open beside this list, highlighted in the two-pane layout.
    var selectedId: String? = nil
    let onPick: (Player) -> Void
    let onAdmin: () -> Void
    var onDares: () -> Void = {}

    var body: some View {
        // The title on the first band, then the players as small tiles, each a step down the heat
        // gradient in this week's order, with the character they picked.
        let board = store.players.map { ($0, store.weekPoints($0.id)) }.sorted { $0.1 > $1.1 }
        let bands = board.count + 1
        let characters = store.characters
        GeometryReader { geo in
            // Three tiles across on a phone; more where there's room, so an iPad's tiles stay small too.
            let perRow = min(6, max(3, Int(geo.size.width / 124)))
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.top, geo.safeAreaInsets.top)
                        .background(Palette.heat.band(0, of: bands))

                    if store.players.isEmpty {
                        Text("Nobody's playing yet. An admin can add players in Admin.")
                            .foregroundStyle(Color.done).padding(20)
                    }
                    ForEach(tileRows(board.count, perRow: perRow), id: \.lowerBound) { row in
                        HStack(spacing: 0) {
                            ForEach(Array(row), id: \.self) { i in
                                playerTile(board[i].0, place: i, points: board[i].1, band: i + 1, of: bands, character: characters[board[i].0.id])
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    // Dares need each phone to be someone's: only a family on more than one phone has them.
                    if store.isLinked { FamilyHomeSection(onDares: onDares) }

                    SectionLabel("The last \(Engine.logDays) days")
                    let days = Engine.recentDays(now: Date(), calendar: store.calendar)
                    ForEach(store.players) { p in
                        DailyLogRow(name: store.shownName(p), days: days,
                                    byDay: Engine.minutesByDay(playerId: p.id, logs: store.logs, pool: store.poolById, calendar: store.calendar))
                    }
                    .padding(.horizontal, 20)

                    Group {
                        if !store.isLinked { Text("Everything here stays on this device. No accounts, nothing sent anywhere.") }
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
                Text("DOYOURWORK").font(.app(fixedSize: 28, weight: .black)).lineLimit(1).minimumScaleFactor(0.5)
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

    /// Which places share each row of tiles: `Characters.tileRows` says how many, this says which.
    private func tileRows(_ count: Int, perRow: Int) -> [Range<Int>] {
        var start = 0
        return Characters.tileRows(count, perRow: perRow).map { size in
            defer { start += size }
            return start..<(start + size)
        }
    }

    /// One player on the scoreboard: their place, their character, their name, this week's points,
    /// and their version with their streak beside it. Small on purpose, so a whole household fits
    /// above the fold. The whole tile is the button.
    private func playerTile(_ p: Player, place: Int, points: Int, band: Int, of bands: Int, character: PlayerCharacter?) -> some View {
        let isSelected = p.id == selectedId
        let ink = Palette.heat.ink
        let version = store.rank(p.id).version
        let streak = store.streak(p.id)
        return Button { fb.tap(); onPick(p) } label: {
            VStack(spacing: 1) {
                if let character { CharacterIcon(character: character, size: 46) }
                // One line, shrinking before it cuts off, in a fixed height so every tile matches.
                Text(store.shownName(p)).font(.app(.subheadline)).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.6)
                    .frame(height: 26)
                Text("\(points) pts").font(.app(.subheadline)).fontWeight(.black).lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 1) {
                    Text(streak == 0 ? version : "\(version) · \(streak)").font(.app(.caption)).fontWeight(.semibold).lineLimit(1)
                    if streak > 0 { StreakFlame(size: 12) }
                }
                .opacity(0.85)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(streak == 0 ? version : "\(version), \(streak)-day streak")
            }
            .foregroundStyle(ink)
            // Three across leaves no room for the largest text sizes; the player's own screen has them in full.
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .padding(.top, 12).padding(.bottom, 10).padding(.horizontal, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.heat.band(band, of: bands))
            .overlay(alignment: .topLeading) {
                Text("\(place + 1)").font(.app(fixedSize: 14, weight: .black)).foregroundStyle(ink.opacity(0.6)).padding(.leading, 8).padding(.top, 6)
            }
            .overlay { if isSelected { Rectangle().strokeBorder(ink, lineWidth: 3) } }
            .contentShape(Rectangle())
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
        guard store.isLinked else { return sound }
        return sound + " · " + store.syncStatus.prefix(1).uppercased() + store.syncStatus.dropFirst()
    }
}

/// The app's version and build, e.g. "1.0 (202611141817)".
enum AppInfo {
    static var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let v = info["CFBundleShortVersionString"] as? String ?? "?"
        let b = info["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}

/// A linked phone: whose phone this is, the dares button, and yesterday's dares revealed.
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
