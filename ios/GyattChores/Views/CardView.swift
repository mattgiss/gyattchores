import GyattCore
import SwiftUI

/// Today's card: check each chore off, submit for approval, then watch the
/// parent's verdicts come in. After submitting, the bonus round opens up.
struct CardView: View {
    let player: Player
    let card: DailyCard
    let onBonus: () -> Void

    @EnvironmentObject private var store: GameStore

    var body: some View {
        let today = store.todayState(for: player, card: card)

        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                PlayerHeader(player: player)
                cardSection(today: today)
                if !today.bonus.isEmpty {
                    bonusSection(today: today)
                }
            }
            .frame(maxWidth: Theme.contentWidth)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer(today: today)
        }
        .sensoryFeedback(.selection, trigger: card.doneCount)
        .sensoryFeedback(.success, trigger: card.submitted)
    }

    // MARK: Sections

    private func cardSection(today: TodayState) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Eyebrow("today's card")
                if !card.submitted {
                    Button("↻ re-pick") {
                        store.discardCard(for: player)
                    }
                    .font(.mono(.caption2))
                    .accessibilityLabel("Re-pick today's chores")
                }
                Spacer()
                Text("\(card.doneCount)/\(card.chores.count) · \(card.totalMinutes)m")
                    .font(.mono(.caption2))
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(card.chores.enumerated()), id: \.element.id) { index, chore in
                cardRow(index: index, chore: chore, status: status(of: chore, today: today))
            }
        }
    }

    @ViewBuilder
    private func cardRow(index: Int, chore: CardChore, status: LogStatus?) -> some View {
        let isChecked = card.checked.indices.contains(index) && card.checked[index]

        if let status {
            // A verdict (or "awaiting") is in — the row is read-only.
            ChoreRow(name: chore.name, isOn: isChecked, strikeWhenOn: true, trailing: .status(status))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(chore.name), \(ChoreRow.spoken(status))")
        } else {
            Button {
                store.toggleChore(at: index, for: player)
            } label: {
                ChoreRow(name: chore.name, isOn: isChecked, strikeWhenOn: true,
                         trailing: .minutes(chore.currentMinutes, escalLevel: chore.escalLevel))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(chore.name), \(chore.currentMinutes) minutes")
            .accessibilityValue(isChecked ? "done" : "not done")
            .accessibilityAddTraits(isChecked ? [.isButton, .isSelected] : .isButton)
            .accessibilityIdentifier("chore-\(chore.id)")
        }
    }

    private func bonusSection(today: TodayState) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow("bonus round")
                Spacer()
                Text("\(today.bonus.count) · \(today.bonus.reduce(0) { $0 + $1.currentMinutes })m")
                    .font(.mono(.caption2))
                    .foregroundStyle(.secondary)
            }

            ForEach(today.bonus) { chore in
                let status = today.statusByChore[chore.id] ?? .pending
                ChoreRow(name: chore.name, isOn: true, strikeWhenOn: true, trailing: .status(status))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(chore.name), \(ChoreRow.spoken(status))")
                    .accessibilityIdentifier("bonus-\(chore.id)")
            }
        }
    }

    // MARK: Footer

    private func footer(today: TodayState) -> some View {
        VStack(spacing: 10) {
            if card.submitted {
                let outcome = verdict(today: today)
                Text(outcome.label)
                    .font(.mono(.footnote))
                    .tracking(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(outcome.color)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .overlay(Rectangle().strokeBorder(outcome.color, lineWidth: 1))
                    .accessibilityIdentifier("verdict")

                if today.bonusLeft > 0 {
                    Button("➕ BONUS ROUND — LOG MORE", action: onBonus)
                        .buttonStyle(TerminalButtonStyle(kind: .outline))
                        .accessibilityIdentifier("bonus")
                }
            } else {
                Button(card.allChecked ? "SUBMIT CARD" : "CHECK OFF ALL \(card.chores.count) CHORES") {
                    store.submitCard(for: player)
                }
                .buttonStyle(TerminalButtonStyle(kind: .filled))
                .disabled(!card.allChecked)
                .accessibilityIdentifier("submit")
            }
        }
        .frame(maxWidth: Theme.contentWidth)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) { Hairline() }
    }

    // MARK: Derived

    /// On a submitted card, a chore with no log yet is still awaiting approval.
    private func status(of chore: CardChore, today: TodayState) -> LogStatus? {
        today.statusByChore[chore.id] ?? (card.submitted ? .pending : nil)
    }

    /// Reflect what the parent has actually done, not just "submitted".
    private func verdict(today: TodayState) -> (label: String, color: Color) {
        let statuses = card.chores.map { status(of: $0, today: today) }
        let total = card.chores.count
        let approved = statuses.filter { $0 == .approved }.count
        let rejected = statuses.filter { $0 == .rejected }.count

        if rejected > 0 {
            return ("\(rejected) REJECTED · \(approved)/\(total) APPROVED", Theme.danger)
        }
        if approved == total {
            let cardPoints = card.chores.reduce(0) { $0 + $1.pts }
            let bonusPoints = today.bonus
                .filter { today.statusByChore[$0.id] == .approved }
                .reduce(0) { $0 + $1.pts }
            return ("ALL APPROVED ✓ · +\(cardPoints + bonusPoints) PTS", Theme.success)
        }
        if approved > 0 {
            return ("\(approved)/\(total) APPROVED · REST AWAITING", Theme.accent)
        }
        return ("SUBMITTED — AWAITING APPROVAL", Theme.accent)
    }
}
