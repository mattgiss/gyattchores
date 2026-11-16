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
    @State private var editingDisplayName = false
    @State private var displayNameDraft = ""

    var body: some View {
        let card = store.card(for: player.id)
        let todays = store.todaysLogs(player.id)
        let statusToday = Engine.statusToday(todays)
        // Used up for today: awaiting an admin, approved, or on the card and not yet submitted.
        // A rejected chore isn't — it can be done again.
        // One chore, one person, per day: what the other players have in today.
        let others = store.takenByOthers(player.id)
        let taken = Engine.standingToday(statusToday).union((card?.choreIds ?? []).filter { statusToday[$0] == nil }).union(others.keys)
        VStack(spacing: 0) {
            // The screen's first band: who this is, their version and streak, in white on red,
            // running up under the status bar.
            VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Leaving the bonus picker always needs a way back, even with no screen behind this one.
                if showsBack || bonusPicking {
                    Button("Back") { fb.tap(); if bonusPicking { bonusPicking = false } else { dismiss() } }
                        .font(.app(.callout)).fontWeight(.bold).frame(minWidth: 44, minHeight: 44, alignment: .leading).padding(.trailing, 8)
                }
                Text(bonusPicking ? "\(store.shownName(player)) · bonus" : store.shownName(player)).font(.app(.title3)).fontWeight(.black).lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 8)
                // Their own nickname, their own call: no admin needed, and it can't change the
                // username their points are kept under.
                if !bonusPicking {
                    Button("Rename") {
                        fb.tap()
                        displayNameDraft = player.displayName ?? ""
                        editingDisplayName = true
                    }
                    .font(.app(.callout)).fontWeight(.bold).frame(minHeight: 44)
                }
            }
            StatsHeader(rank: store.rank(player.id), streak: store.streak(player.id))
            }
            .foregroundStyle(Palette.heat.ink).tint(Palette.heat.ink)
            .padding(.horizontal, 16).padding(.bottom, 12)
            .background(Palette.heat.stops[0].ignoresSafeArea(edges: .top))

            if let card {
                if bonusPicking {
                    PickerView(pool: store.pickable(player.id).filter { !taken.contains($0.id) }, bonus: true) { chosen in
                        store.logBonus(player, chosen); fb.submit(); bonusPicking = false
                    }
                } else {
                    CardRunView(player: player, card: card, todays: todays, others: others,
                                bonusLeft: store.pool.filter { !taken.contains($0.id) }.count) { bonusPicking = true }
                }
            } else {
                PickerView(pool: store.pickable(player.id).filter { others[$0.id] == nil }, bonus: false,
                           notes: (store.rejectedToday(player.id) ? ["Today's earlier chores were turned down, so let's build a new card."] : [])
                               + (others.isEmpty ? [] : ["Someone else already has \(others.count == 1 ? "one" : "\(others.count)") of today's chores."])) { chosen in
                    store.lockIn(player, chosen); fb.lockIn()
                }
            }
        }
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Display name", isPresented: $editingDisplayName) {
            TextField("anything you like", text: $displayNameDraft)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Save") { store.setDisplayName(player.id, displayNameDraft) }
            Button("Use my username", role: .destructive) { store.setDisplayName(player.id, "") }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Shown in place of your username, \(player.name). Your chores and points stay exactly as they are. Up to \(DisplayName.maxLength) characters.")
        }
    }
}

private struct PickerView: View {
    @EnvironmentObject var fb: Feedback
    let pool: [EnrichedChore]
    let bonus: Bool
    /// Shown above the list when there's something the player should know before picking.
    var notes: [String] = []
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
                    Text(bonus ? "Did a bit extra today? Pick what you did. Every chore still earns its points." : "Pick what you'd like to do today, then fill it up to \(Engine.dailyMinutes) minutes.")
                        .font(.app(.callout)).foregroundStyle(Color.done).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.vertical, 14)
                    ForEach(notes, id: \.self) { note in
                        Text(note).font(.app(.footnote)).foregroundStyle(Theme.warn).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.bottom, 10)
                    }
                    ForEach(Array(pool.enumerated()), id: \.element.id) { i, c in
                        let isPicked = picked.contains(c.id)
                        ChoreRow(name: c.name, minutes: c.currentMinutes, escalLevel: c.escalLevel, checked: isPicked,
                                 index: i, count: pool.count, picking: true) {
                            if isPicked { fb.tick(false); picked.removeAll { $0 == c.id }; suggested.remove(c.id) }
                            else if c.currentMinutes <= remaining { fb.tick(true); picked.append(c.id); suggested.remove(c.id) }
                            else { fb.error() }
                        }
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(bonus ? Phrase.count(total, "minute") : "\(total) of \(Engine.dailyMinutes) minutes").font(.app(.title3)).fontWeight(.black)
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.vertical, 10)
                if !bonus {
                    // How full the card is, as a strip of the gradient across the screen.
                    GeometryReader { g in
                        Rectangle().fill(LinearGradient(colors: Palette.heat.stops, startPoint: .leading, endPoint: .trailing))
                            .frame(width: g.size.width * min(1, CGFloat(total) / CGFloat(Engine.dailyMinutes)))
                    }
                    .frame(height: 4).background(Color.surface)
                    .animation(.easeOut(duration: 0.2), value: total)
                    OutlineButton(label: chosen.isEmpty ? "Suggest a \(Engine.dailyMinutes)-minute card" : "Fill it up to \(Engine.dailyMinutes) minutes") {
                        fb.fill()
                        let next = Engine.suggestFill(pickedIds: picked, pool: pool)
                        suggested = suggested.intersection(next).union(next.filter { !picked.contains($0) })
                        picked = next
                    }
                }
                TermButton(label: ready ? (bonus ? "Log \(chosen.count == 1 ? "this chore" : "these \(chosen.count) chores")" : "Lock in my card")
                           : !chosen.isEmpty ? "Add a few more to reach \(Engine.dailyMinutes) minutes" : bonus ? "Pick the chores you did" : "Pick some chores, or let me suggest some",
                           enabled: ready) { onConfirm(chosen) }
            }
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
    /// Chores another player has in today: chore id → their name.
    let others: [String: String]
    let bonusLeft: Int
    let onBonus: () -> Void
    @State private var puzzleOpen = false

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
        // On a card that isn't submitted yet, a chore someone else got in first stays visible, marked
        // taken, and is left out when the card is submitted.
        let lost = card.submitted ? [] : card.choreIds.filter { others[$0] != nil }
        let keep = card.choreIds.indices.filter { !lost.contains(card.choreIds[$0]) }
        let allChecked = !keep.isEmpty && keep.allSatisfy { card.checked[$0] }

        // One gradient down the whole day: the card, then the bonus round, then anything rejected.
        let rows = card.choreIds.count + bonusLogs.count + (card.submitted ? rejectedExtras.count : 0)
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    SectionLabel("Today's card · \(Phrase.count(card.minutes.reduce(0, +), "minute"))")
                    ForEach(Array(card.choreIds.enumerated()), id: \.element) { i, id in
                        ChoreRow(name: store.choreName(id), minutes: card.minutes[i],
                                 escalLevel: i < card.escal.count ? card.escal[i] : 0, checked: card.checked[i],
                                 status: card.submitted ? (statusByChore[id] ?? Status.pending) : (lost.contains(id) ? ChoreRow.taken : nil),
                                 index: i, count: rows) {
                            fb.tick(!card.checked[i]); store.toggle(player, card, i)
                        }
                    }
                    if !bonusLogs.isEmpty {
                        SectionLabel("Bonus round")
                        ForEach(Array(bonusLogs.enumerated()), id: \.element.id) { i, l in
                            ChoreRow(name: l.choreName, minutes: Engine.choreMinutes(l, pool: store.poolById), checked: true, status: statusByChore[l.choreId],
                                     index: card.choreIds.count + i, count: rows)
                        }
                    }
                    // Kept off a card that's still being checked off, where it would only be in the way.
                    if card.submitted && !rejectedExtras.isEmpty {
                        SectionLabel("Turned down today")
                        ForEach(rejectedExtras) { l in
                            ChoreRow(name: l.choreName, minutes: Engine.choreMinutes(l, pool: store.poolById), checked: true, status: Status.rejected)
                        }
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(alignment: .leading, spacing: 0) {
                if !card.submitted {
                    if !lost.isEmpty {
                        Text("Someone else got to the ones marked taken first, so they won't be sent.").font(.app(.footnote)).foregroundStyle(Color.done).padding(.horizontal, 20).padding(.bottom, 8)
                    }
                    TermButton(label: allChecked ? "Send it off for approval" : keep.isEmpty ? "Everything's been taken today. Change your picks" : "Check everything off first",
                               enabled: allChecked) {
                        store.submit(player, card); fb.submit()
                    }
                    HStack {
                        Text("The puzzle opens once you send your card.").font(.app(.footnote)).foregroundStyle(Color.done)
                        Spacer()
                        Button("Change my picks") { fb.tap(); store.clearCard(player) }.font(.app(.footnote)).fontWeight(.bold).foregroundStyle(Color.appText).frame(minHeight: 44)
                    }
                    .padding(.horizontal, 20)
                } else {
                    // Say what's actually left: every chore logged today is pending, approved or rejected.
                    let verdicts = (card.choreIds + extras.map(\.choreId)).map { statusByChore[$0] ?? Status.pending }
                    let waiting = verdicts.filter { $0 == Status.pending }.count
                    let rejected = verdicts.filter { $0 == Status.rejected }.count
                    Group {
                        if waiting == verdicts.count { Text("Sent! Now it's waiting for an admin to look at it.").foregroundStyle(Color.done) }
                        else if waiting > 0 { Text("\(waiting) of \(verdicts.count) are still waiting for an admin.").foregroundStyle(Color.done) }
                        else if rejected == 0 { Text("Everything's approved. Nice work!").foregroundStyle(Theme.good) }
                        else if rejected == verdicts.count { Text("None of today's chores were approved.").foregroundStyle(Theme.bad) }
                        else { Text("\(verdicts.count - rejected) approved and \(rejected) turned down.").foregroundStyle(Color.done) }
                        if rejected > 0 {
                            Text("You can redo the turned-down ones in a bonus round.").font(.app(.footnote)).foregroundStyle(Color.done)
                        }
                    }
                    .font(.app(.callout)).fontWeight(.semibold).padding(.horizontal, 20).padding(.vertical, 10)
                    let minutesLeft = store.puzzleMinutesLeft(player.id)
                    if minutesLeft > 0 {
                        let level = store.puzzleLevel(player.id)
                        let play = { fb.unlock(); puzzleOpen = true }
                        // On a narrow phone (an iPhone 16e) the minutes left matter more than the puzzle's name.
                        ViewThatFits(in: .horizontal) {
                            TermButton(label: "Play level \(level) · \(Phrase.count(minutesLeft, "minute")) left today", action: play)
                            TermButton(label: "Play level \(level) · \(minutesLeft) min left", action: play)
                        }
                    } else {
                        Text("That's your hour of puzzles for today. See you tomorrow!").foregroundStyle(Color.done).padding(.horizontal, 20).padding(.vertical, 18)
                    }
                    if bonusLeft > 0 { OutlineButton(label: "Do a bonus round") { fb.tap(); onBonus() } }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Celebrate the first time this screen shows a new version (approval may have happened elsewhere).
        .task(id: rank.level) { if store.isNewLevel(player.id, rank.level) { fb.levelUp() } }
        .fullScreenCover(isPresented: $puzzleOpen, onDismiss: { store.puzzleTimeShown() }) {
            PuzzleView(player: player).environmentObject(store).environmentObject(fb).font(.app(.body)).tint(Theme.accent)
        }
    }
}
