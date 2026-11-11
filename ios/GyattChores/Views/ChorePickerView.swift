import GyattCore
import SwiftUI

/// Build today's card: pick what you want, then fill the rest of the 25
/// minutes with suggestions. In the bonus round (after the card is in) there's
/// no cap — anything not already logged today can be added.
struct ChorePickerView: View {
    let player: Player
    /// Non-nil switches to the bonus round; these chores are already logged today.
    var bonusExcluding: Set<String>?
    let onConfirm: ([CardChore]) -> Void

    @EnvironmentObject private var store: GameStore
    @State private var picked: [String] = []
    @State private var suggested: Set<String> = []

    private var isBonus: Bool { bonusExcluding != nil }

    private var pool: [CardChore] {
        let excluded = bonusExcluding ?? []
        return store.pickableChores(for: player).filter { !excluded.contains($0.id) }
    }

    var body: some View {
        let pool = self.pool
        let summary = store.engine.pickerSummary(picked: Set(picked), pool: pool, bonus: isBonus)
        let chosenCount = pool.filter { picked.contains($0.id) }.count

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(summary: summary, chosenCount: chosenCount)

                ForEach(pool) { chore in
                    row(for: chore, summary: summary)
                }

                if pool.contains(where: { $0.escalLevel > 0 }) {
                    Text("! = neglected   !! = long overdue")
                        .font(.mono(.caption2))
                        .foregroundStyle(.secondary)
                        .padding(.top, 16)
                }
            }
            .frame(maxWidth: Theme.contentWidth)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actions(pool: pool, summary: summary, chosenCount: chosenCount)
        }
        .sensoryFeedback(.selection, trigger: picked)
    }

    private func header(summary: PickerSummary, chosenCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(isBonus ? "bonus round" : "build today's card")
            Text(isBonus
                 ? "log extra chores — no cap, all normal points"
                 : "pick what you want — then fill to \(Engine.dailyMinutes) min")
                .font(.mono(.footnote))
                .padding(.top, 6)

            HStack(alignment: .firstTextBaseline) {
                Text("\(chosenCount) picked")
                    .font(.mono(.caption2))
                    .tracking(2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(isBonus ? "\(summary.total)m" : "\(summary.total) / \(Engine.dailyMinutes)m")
                    .font(.mono(.footnote, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.top, 18)

            if !isBonus {
                ProgressView(value: Double(min(summary.total, Engine.dailyMinutes)), total: Double(Engine.dailyMinutes))
                    .tint(Theme.accent)
                    .padding(.top, 5)
                    .animation(.easeOut(duration: 0.2), value: summary.total)
                    .accessibilityLabel("\(summary.total) of \(Engine.dailyMinutes) minutes picked")
            }
        }
        .padding(.bottom, 12)
    }

    private func row(for chore: CardChore, summary: PickerSummary) -> some View {
        let isOn = picked.contains(chore.id)
        let tooBig = !isOn && !summary.canPick(chore)

        return Button {
            toggle(chore, summary: summary)
        } label: {
            ChoreRow(
                name: chore.name,
                isOn: isOn,
                note: suggested.contains(chore.id) ? "suggested" : nil,
                trailing: .minutes(chore.currentMinutes, escalLevel: chore.escalLevel)
            )
        }
        .buttonStyle(.plain)
        .disabled(tooBig)
        .opacity(tooBig ? 0.35 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(chore.name), \(chore.currentMinutes) minutes\(ChoreRow.spokenEscalation(chore.escalLevel))")
        .accessibilityValue(isOn ? "picked" : (tooBig ? "doesn't fit in today's \(Engine.dailyMinutes) minutes" : "not picked"))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("chore-\(chore.id)")
    }

    private func actions(pool: [CardChore], summary: PickerSummary, chosenCount: Int) -> some View {
        VStack(spacing: 8) {
            if summary.canAddMore {
                Button(chosenCount > 0 ? "✨ FILL TO \(Engine.dailyMinutes)M" : "✨ SUGGEST A \(Engine.dailyMinutes)-MIN CARD") {
                    fill(pool: pool)
                }
                .buttonStyle(TerminalButtonStyle(kind: .outline))
                .accessibilityIdentifier("fill")
            }

            Button(confirmTitle(summary: summary, chosenCount: chosenCount)) {
                onConfirm(pool.filter { picked.contains($0.id) })
            }
            .buttonStyle(TerminalButtonStyle(kind: .filled))
            .disabled(!summary.isReady)
            .accessibilityIdentifier("confirm")
        }
        .frame(maxWidth: Theme.contentWidth)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) { Hairline() }
    }

    private func confirmTitle(summary: PickerSummary, chosenCount: Int) -> String {
        if summary.isReady {
            let noun = chosenCount == 1 ? "CHORE" : "CHORES"
            return isBonus
                ? "LOG \(chosenCount) BONUS \(noun) · \(summary.total)M"
                : "LOCK IN \(chosenCount) \(noun) · \(summary.total)M"
        }
        if chosenCount > 0 { return "ADD MORE TO REACH \(Engine.dailyMinutes)M" }
        return isBonus ? "PICK CHORES TO LOG" : "PICK OR SUGGEST CHORES"
    }

    private func toggle(_ chore: CardChore, summary: PickerSummary) {
        if let index = picked.firstIndex(of: chore.id) {
            picked.remove(at: index)
        } else if summary.canPick(chore) {
            picked.append(chore.id)
        } else {
            return
        }
        suggested.remove(chore.id)   // touching a chore by hand makes it yours, not a suggestion
    }

    private func fill(pool: [CardChore]) {
        let poolIds = Set(pool.map(\.id))
        let current = picked.filter { poolIds.contains($0) }
        let next = store.engine.suggestFill(picked: current, pool: pool)
        let added = Set(next).subtracting(current)
        picked = next
        suggested = suggested.intersection(next).union(added)
    }
}
