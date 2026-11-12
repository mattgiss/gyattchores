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
        let names = Dictionary(uniqueKeysWithValues: store.players.map { ($0.id, $0.name) })
        VStack(spacing: 0) {
            HStack {
                Button("← back") { fb.tap(); if let onBack { onBack() } else { dismiss() } }
                Text("DARES").font(.headline).foregroundStyle(Theme.accent).padding(.leading, 8)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Text("guess what someone will do today. if they do it and it's approved, you get +\(Engine.dareGuesserPoints) and they get +\(Engine.dareDoerPoints). nobody sees dares until tomorrow.")
                        .font(.callout).foregroundStyle(.secondary)
                    Text("\(mine.count) of \(Engine.maxDaresPerDay) used today").bold().padding(.top, 10)
                    ForEach(mine, id: \.self) { d in
                        Text("· \(names[d.target] ?? d.target): \(store.poolById[d.choreId]?.name ?? d.choreId)").font(.callout).padding(.top, 2)
                    }
                    // A locked target already has its own standing line below; don't say it twice.
                    let locked = target.map { store.submittedToday($0.id) } ?? false
                    if let note, !locked { Text(note).font(.footnote).foregroundStyle(Theme.bad).padding(.top, 6) }

                    if let target {
                        SectionLabel("who are you daring?")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(others) { p in
                                    if p.id == target.id { Button(p.name) {}.buttonStyle(.borderedProminent) }
                                    else { Button(p.name) { fb.tap(); targetId = p.id; note = nil }.buttonStyle(.bordered) }
                                }
                            }
                        }
                        if store.submittedToday(target.id) {
                            Text("locked — \(target.name) already submitted today").font(.footnote).foregroundStyle(Theme.warn).padding(.top, 8)
                        }
                        // The same list the target sees, most overdue first: the likeliest chores are on top.
                        ForEach(store.pickable(target.id)) { c in
                            let on = mine.contains { $0.target == target.id && $0.choreId == c.id }
                            ChoreRow(name: c.name, minutes: c.currentMinutes, escalLevel: c.escalLevel, checked: on) {
                                let why = store.toggleDare(target, c.id)
                                note = why
                                if why != nil { fb.error() } else if on { fb.tick(false) } else { fb.dare() }
                            }
                        }
                    } else {
                        Text("add another player to dare them.").foregroundStyle(.secondary).padding(.vertical, 24)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}
