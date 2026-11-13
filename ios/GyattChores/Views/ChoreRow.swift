import GyattCore
import SwiftUI

/// One chore line: a `[+]` / `[ ]` box, the name, and on the right either what
/// it costs or what the parent decided.
struct ChoreRow: View {
    enum Trailing {
        case minutes(Int, escalLevel: Int)
        case status(LogStatus)
    }

    let name: String
    let isOn: Bool
    /// Checked-off chores on a card are struck through; picked chores in the
    /// picker are highlighted instead.
    var strikeWhenOn = false
    var note: String?
    let trailing: Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(isOn ? "[+]" : "[ ]")
                    .font(.mono(.callout))
                    .foregroundStyle(isOn ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.tertiary))

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.mono(.callout))
                        .strikethrough(isOn && strikeWhenOn)
                        .foregroundStyle(nameStyle)
                        .multilineTextAlignment(.leading)
                    if let note {
                        Text(note)
                            .font(.mono(.caption2))
                            .tracking(1)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                trailingText
                    .font(.mono(.footnote))
            }
            .padding(.vertical, 14)
            Hairline()
        }
        .contentShape(Rectangle())
    }

    private var nameStyle: AnyShapeStyle {
        guard isOn else { return AnyShapeStyle(.primary) }
        return strikeWhenOn ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Theme.accent)
    }

    @ViewBuilder
    private var trailingText: some View {
        switch trailing {
        case .minutes(let minutes, let escalLevel):
            Text(Self.minutesText(minutes, escalLevel: escalLevel))
                .foregroundStyle(Self.escalationStyle(escalLevel))
        case .status(let status):
            Text(Self.statusText(status))
                .foregroundStyle(Self.statusColor(status))
        }
    }

    static func minutesText(_ minutes: Int, escalLevel: Int) -> String {
        let marks = ["", "! ", "!! "]
        return (marks.indices.contains(escalLevel) ? marks[escalLevel] : "") + "\(minutes)m"
    }

    static func escalationStyle(_ level: Int) -> AnyShapeStyle {
        switch level {
        case 1: return AnyShapeStyle(Theme.warning)
        case 2: return AnyShapeStyle(Theme.danger)
        default: return AnyShapeStyle(.tertiary)
        }
    }

    static func statusText(_ status: LogStatus) -> String {
        switch status {
        case .approved: return "✓ approved"
        case .rejected: return "✗ rejected"
        case .pending: return "· awaiting"
        }
    }

    static func statusColor(_ status: LogStatus) -> Color {
        switch status {
        case .approved: return Theme.success
        case .rejected: return Theme.danger
        case .pending: return Theme.warning
        }
    }

    static func spoken(_ status: LogStatus) -> String {
        switch status {
        case .approved: return "approved"
        case .rejected: return "rejected"
        case .pending: return "awaiting approval"
        }
    }

    static func spokenEscalation(_ level: Int) -> String {
        switch level {
        case 1: return ", neglected"
        case 2: return ", long overdue"
        default: return ""
        }
    }
}
