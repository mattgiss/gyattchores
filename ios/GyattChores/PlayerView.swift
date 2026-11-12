import SwiftUI
import GyattCore

/// One player's day: pick a card, check it off, submit, then (optionally) a bonus round.
struct PlayerView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @Environment(\.dismiss) private var dismiss
    let player: Player
    /// False when this is the right-hand pane beside the home list: there's nothing to go back to.
    var showsBack = true
    @State private var bonusPicking = false

    var body: some View {
        let card = store.card(for: player.id)
        let todays = store.todaysLogs(player.id)
        let statusToday = Engine.statusToday(todays)
        // Used up for today: awaiting a parent, approved, or on the card and not yet submitted.
        // A rejected chore isn't — it can be done again.
        let taken = Engine.standingToday(statusToday).union((card?.choreIds ?? []).filter { statusToday[$0] == nil })
        VStack(spacing: 0) {
            HStack {
                // Leaving the bonus picker always needs a way back, even with no screen behind this one.
                if showsBack || bonusPicking {
                    Button("← back") { fb.tap(); if bonusPicking { bonusPicking = false } else { dismiss() } }
                        .padding(.trailing, 8)
                }
                Text(bonusPicking ? "\(player.name) · bonus round" : player.name).font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.vertical, 12)

            if let card {
                if bonusPicking {
                    PickerView(pool: store.pickable(player.id).filter { !taken.contains($0.id) }, bonus: true) { chosen in
                        store.logBonus(player, chosen); fb.submit(); bonusPicking = false
                    }
                } else {
                    CardRunView(player: player, card: card, todays: todays,
                                bonusLeft: store.pool.filter { !taken.contains($0.id) }.count) { bonusPicking = true }
                }
            } else {
                PickerView(pool: store.pickable(player.id), bonus: false,
                           note: store.rejectedToday(player.id) ? "today's earlier chores were rejected — build a new card" : nil) { chosen in
                    store.lockIn(player, chosen); fb.lockIn()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct PickerView: View {
    @EnvironmentObject var fb: Feedback
    let pool: [EnrichedChore]
    let bonus: Bool
    /// Shown above the list when there's something the player should know before picking.
    var note: String? = nil
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
                    if let note {
                        Text(note).font(.footnote).foregroundStyle(Theme.warn).frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 8)
                    }
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
            .scrollBounceBehavior(.basedOnSize)
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
        // Approved wins; otherwise the latest log for a chore decides, so one redone after a rejection is awaiting again.
        let statusByChore = Engine.statusToday(todays)
        // Chores logged today that aren't on the card: bonus-round ones still standing, and ones a
        // parent rejected (from the bonus round, or from an earlier card that was rejected outright).
        var seen = Set(card.choreIds)
        let extras = todays.filter { seen.insert($0.choreId).inserted }
        let bonusLogs = extras.filter { statusByChore[$0.choreId] != Status.rejected }
        let rejectedExtras = extras.filter { statusByChore[$0.choreId] == Status.rejected }
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
                    // Kept off a card that's still being checked off, where it would only be in the way.
                    if card.submitted && !rejectedExtras.isEmpty {
                        SectionLabel("rejected today")
                        ForEach(rejectedExtras) { l in
                            ChoreRow(name: l.choreName, minutes: Engine.choreMinutes(l, pool: store.poolById), checked: true, status: Status.rejected)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(alignment: .leading, spacing: 8) {
                if !card.submitted {
                    TermButton(label: allChecked ? "SUBMIT FOR APPROVAL" : "CHECK OFF EVERYTHING FIRST", enabled: allChecked) {
                        store.submit(player, card); fb.submit()
                    }
                    Button("change my picks") { fb.tap(); store.clearCard(player) }.foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    // Say what's actually left: every chore logged today is pending, approved or rejected.
                    let verdicts = (card.choreIds + extras.map(\.choreId)).map { statusByChore[$0] ?? Status.pending }
                    let waiting = verdicts.filter { $0 == Status.pending }.count
                    let rejected = verdicts.filter { $0 == Status.rejected }.count
                    if waiting == verdicts.count { Text("card submitted — waiting on a parent").foregroundStyle(.secondary) }
                    else if waiting > 0 { Text("\(waiting) of \(verdicts.count) still waiting on a parent").foregroundStyle(.secondary) }
                    else if rejected == 0 { Text("✓ all approved — nice work").foregroundStyle(Theme.good) }
                    else if rejected == verdicts.count { Text("✗ none approved today").foregroundStyle(Theme.bad) }
                    else { Text("done — \(verdicts.count - rejected) approved, \(rejected) rejected").foregroundStyle(.secondary) }
                    if rejected > 0 {
                        Text("rejected chores can be done again from the bonus round").font(.footnote).foregroundStyle(.secondary)
                    }
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
