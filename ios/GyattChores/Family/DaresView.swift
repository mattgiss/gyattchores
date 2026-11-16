#if FAMILY_SYNC
import SwiftUI
import GyattCore

/// Make today's secret dares: guess which chores someone else will do. Optional, up to three a day.
/// Only your own dares show here; everyone's are revealed on the home screen after midnight.
struct DaresView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @Environment(\.dismiss) private var dismiss
    /// Set when this is shown in a pane, not presented over the app: closes the pane.
    var onBack: (() -> Void)? = nil
    @State private var targetId: String?
    @State private var note: String?

    var body: some View {
        let me = store.me ?? ""
        let others = store.players.filter { $0.id != me }
        let target = others.first { $0.id == targetId } ?? others.first
        let mine = store.dares.filter { $0.from == me && $0.day == store.todayKey }
        let names = Dictionary(uniqueKeysWithValues: store.players.map { ($0.id, store.shownName($0)) })
        VStack(spacing: 0) {
            // Dares are in Clear's plum theme: a secret, after-dark corner of the app.
            HStack(spacing: 12) {
                Button("Back") { fb.tap(); if let onBack { onBack() } else { dismiss() } }
                    .font(.app(.callout)).fontWeight(.bold).frame(minWidth: 44, minHeight: 44, alignment: .leading)
                Text("Dares").font(.app(fixedSize: 24, weight: .black))
                Spacer()
            }
            .foregroundStyle(Palette.plum.ink).tint(Palette.plum.ink)
            .padding(.horizontal, 16).padding(.bottom, 10)
            .background(Palette.plum.stops[0].ignoresSafeArea(edges: .top))
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Text("Guess what someone will do today. If they do it and it's approved, you get \(Engine.dareGuesserPoints) points and they get \(Engine.dareDoerPoints). Nobody sees the dares until tomorrow.")
                        .font(.app(.callout)).foregroundStyle(Color.done).padding(.top, 14)
                    Text(mine.isEmpty ? "You haven't made any dares today." : mine.count == Engine.maxDaresPerDay ? "You've made all \(mine.count) of today's dares."
                         : "You've made \(mine.count) of your \(Engine.maxDaresPerDay) dares today.").bold().padding(.top, 10)
                    ForEach(mine, id: \.self) { d in
                        Text("You dared \(names[d.target] ?? d.target) to \(store.poolById[d.choreId]?.name ?? d.choreId).").font(.app(.callout))
                            .foregroundStyle(Palette.plum.ink).padding(.top, 2)
                    }
                    // A locked target already has its own standing line below; don't say it twice.
                    let locked = target.map { store.submittedToday($0.id) } ?? false
                    if let note, !locked { Text(note).font(.app(.footnote)).foregroundStyle(Theme.bad).padding(.top, 6) }

                    if let target {
                        SectionLabel("Who are you daring?")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(others) { p in
                                    Button(store.shownName(p)) { fb.tap(); targetId = p.id; note = nil }
                                        .font(.app(.callout)).fontWeight(.bold)
                                        .foregroundStyle(p.id == target.id ? Palette.plum.ink : Color.appText)
                                        .padding(.horizontal, 18).frame(minHeight: 44)
                                        .background(p.id == target.id ? Palette.plum.stops[0] : Color.surface, in: Capsule())
                                }
                            }
                        }
                        if store.submittedToday(target.id) {
                            Text("\(store.shownName(target)) already sent today's card, so it's too late to dare them.").font(.app(.footnote)).foregroundStyle(Theme.warn).padding(.top, 8)
                        }
                        // The same list the target sees, most overdue first: the likeliest chores are on top.
                        let pool = store.pickable(target.id)
                        ForEach(Array(pool.enumerated()), id: \.element.id) { i, c in
                            let on = mine.contains { $0.target == target.id && $0.choreId == c.id }
                            ChoreRow(name: c.name, minutes: c.currentMinutes, escalLevel: c.escalLevel, checked: on,
                                     index: i, count: pool.count, picking: true) {
                                let why = store.toggleDare(target, c.id)
                                note = why
                                if why != nil { fb.error() } else if on { fb.tick(false) } else { fb.dare() }
                            }
                            .padding(.horizontal, -20)
                        }
                    } else {
                        Text("Once there's someone else playing, you can dare them.").foregroundStyle(.secondary).padding(.vertical, 24)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.appBackground)
        .environment(\.palette, .plum)
    }
}
#endif
