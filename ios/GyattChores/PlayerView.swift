import SwiftUI
import GyattCore

/// One player's day: pick a card, check it off, submit, then (optionally) a bonus round.
struct PlayerView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @Environment(\.dismiss) private var dismiss
    let player: Player
    @State private var bonusPicking = false

    var body: some View {
        let card = store.card(for: player.id)
        let todays = store.todaysLogs(player.id)
        let loggedToday = Set((card?.choreIds ?? []) + todays.map(\.choreId))
        VStack(spacing: 0) {
            HStack {
                Button("← back") { fb.tap(); if bonusPicking { bonusPicking = false } else { dismiss() } }
                Text(bonusPicking ? "\(player.name) · bonus round" : player.name).font(.headline).padding(.leading, 8)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.vertical, 12)

            if let card {
                if bonusPicking {
                    PickerView(pool: store.pickable(player.id).filter { !loggedToday.contains($0.id) }, bonus: true) { chosen in
                        store.logBonus(player, chosen); fb.submit(); bonusPicking = false
                    }
                } else {
                    CardRunView(player: player, card: card, todays: todays,
                                bonusLeft: store.pool.filter { !loggedToday.contains($0.id) }.count) { bonusPicking = true }
                }
            } else {
                PickerView(pool: store.pickable(player.id), bonus: false) { chosen in store.lockIn(player, chosen); fb.lockIn() }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct PickerView: View {
    @EnvironmentObject var fb: Feedback
    let pool: [EnrichedChore]
    let bonus: Bool
    let onConfirm: ([EnrichedChore]) -> Void
    @State private var picked: [String] = []
    @State private var suggested: Set<String> = []

    var body: some View {
        let chosen = pool.filter { picked.contains($0.id) }
        let total = chosen.reduce(0) { $0 + $1.currentMinutes }
        let remaining = bonus ? Int.max : Engine.dailyMinutes - total
        let ready = Engine.cardReady(chosen: chosen, pool: pool, bonus: bonus)
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    Text(bonus ? "log extra chores — no cap, all normal points" : "pick what you want — then fill to \(Engine.dailyMinutes) min")
                        .foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                    ForEach(pool) { c in
                        let isPicked = picked.contains(c.id)
                        ChoreRow(name: c.name + (suggested.contains(c.id) ? " ✨" : ""), minutes: c.currentMinutes, escalLevel: c.escalLevel, checked: isPicked) {
                            if isPicked { fb.tick(false); picked.removeAll { $0 == c.id }; suggested.remove(c.id) }
                            else if c.currentMinutes <= remaining { fb.tick(true); picked.append(c.id); suggested.remove(c.id) }
                            else { fb.error() }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(bonus ? "\(total)m" : "\(total) / \(Engine.dailyMinutes)m").bold()
                if !bonus {
                    ProgressView(value: min(1, Double(total) / Double(Engine.dailyMinutes))).animation(.easeOut(duration: 0.2), value: total)
                    OutlineButton(label: chosen.isEmpty ? "✨ suggest a \(Engine.dailyMinutes)-min card" : "✨ fill to \(Engine.dailyMinutes)m") {
                        fb.fill()
                        let next = Engine.suggestFill(pickedIds: picked, pool: pool)
                        suggested = suggested.intersection(next).union(next.filter { !picked.contains($0) })
                        picked = next
                    }
                }
                TermButton(label: ready ? (bonus ? "LOG \(chosen.count) CHORES" : "LOCK IN CARD")
                           : !chosen.isEmpty ? "ADD MORE TO REACH \(Engine.dailyMinutes)M" : bonus ? "PICK CHORES TO LOG" : "PICK OR SUGGEST CHORES",
                           enabled: ready) { onConfirm(chosen) }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        // Chime once when the card first becomes a full day.
        .onChange(of: ready) { _, now in if now && !bonus { fb.ready() } }
    }
}

private struct CardRunView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    let player: Player
    let card: Card
    let todays: [ChoreLog]
    let bonusLeft: Int
    let onBonus: () -> Void

    var body: some View {
        let rank = store.rank(player.id)
        // A parent's verdict wins over "pending" if a chore has more than one row today.
        let statusByChore = todays.reduce(into: [String: String]()) { m, l in
            if m[l.choreId] == nil || m[l.choreId] == Status.pending { m[l.choreId] = l.status }
        }
        var seen = Set(card.choreIds)
        let bonusLogs = todays.filter { seen.insert($0.choreId).inserted }
        let allChecked = card.checked.allSatisfy { $0 }

        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    StatsHeader(rank: rank, streak: store.streak(player.id))
                    SectionLabel("today's card · \(card.minutes.reduce(0, +))m")
                    ForEach(Array(card.choreIds.enumerated()), id: \.element) { i, id in
                        ChoreRow(name: store.poolById[id]?.name ?? id, minutes: card.minutes[i],
                                 escalLevel: i < card.escal.count ? card.escal[i] : 0, checked: card.checked[i],
                                 status: card.submitted ? (statusByChore[id] ?? Status.pending) : nil) {
                            fb.tick(!card.checked[i]); store.toggle(player, card, i)
                        }
                    }
                    if !bonusLogs.isEmpty {
                        SectionLabel("bonus round")
                        ForEach(bonusLogs) { l in
                            ChoreRow(name: l.choreName, minutes: Engine.choreMinutes(l, pool: store.poolById), checked: true, status: statusByChore[l.choreId])
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            VStack(alignment: .leading, spacing: 8) {
                if !card.submitted {
                    TermButton(label: allChecked ? "SUBMIT FOR APPROVAL" : "CHECK OFF EVERYTHING FIRST", enabled: allChecked) {
                        store.submit(player, card); fb.submit()
                    }
                    Button("change my picks") { fb.tap(); store.clearCard(player) }.foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    // Say what's actually left: every chore logged today is pending, approved or rejected.
                    let verdicts = (card.choreIds + bonusLogs.map(\.choreId)).map { statusByChore[$0] ?? Status.pending }
                    let waiting = verdicts.filter { $0 == Status.pending }.count
                    let rejected = verdicts.filter { $0 == Status.rejected }.count
                    if waiting == verdicts.count { Text("card submitted — waiting on a parent").foregroundStyle(.secondary) }
                    else if waiting > 0 { Text("\(waiting) of \(verdicts.count) still waiting on a parent").foregroundStyle(.secondary) }
                    else if rejected == 0 { Text("✓ all approved — nice work").foregroundStyle(Theme.good) }
                    else if rejected == verdicts.count { Text("✗ none approved today").foregroundStyle(Theme.bad) }
                    else { Text("done — \(verdicts.count - rejected) approved, \(rejected) rejected").foregroundStyle(.secondary) }
                    if bonusLeft > 0 { OutlineButton(label: "+ bonus round") { fb.tap(); onBonus() } }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        // Celebrate the first time this screen shows a new version (approval may have happened elsewhere).
        .task(id: rank.level) { if store.isNewLevel(player.id, rank.level) { fb.levelUp() } }
    }
}
