import SwiftUI
import GyattCore

/// "> LABEL" — the one main action on a screen. Filled when it can be pressed, a grey outline when it can't.
struct TermButton: View {
    let label: String
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button(action: action) { Text("> \(label)") }
            .buttonStyle(TermButtonStyle(filled: true)).disabled(!enabled)
    }
}

/// A secondary action: a thin outline and nothing more, so it never competes with the main one.
struct OutlineButton: View {
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) { Text(label) }.buttonStyle(TermButtonStyle(filled: false))
    }
}

/// The app's buttons: full width but only as tall as a comfortable tap target, with a squared-off
/// outline. Sized by hand because the system's bordered styles add their own padding on top.
struct TermButtonStyle: ButtonStyle {
    let filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration, filled: filled)
    }

    private struct Face: View {
        let configuration: ButtonStyleConfiguration
        let filled: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let solid = filled && isEnabled
            let shape = RoundedRectangle(cornerRadius: 8)
            configuration.label
                .font(filled ? .subheadline : .footnote)
                .fontWeight(filled ? .bold : .regular)
                .kerning(filled ? 1 : 0)
                .lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(solid ? Color.white : (isEnabled ? Theme.accent : Color.secondary))
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: filled ? 44 : 40)
                .background(solid ? Theme.accent : Color.clear, in: shape)
                .overlay(shape.strokeBorder(isEnabled ? Theme.accent.opacity(filled ? 1 : 0.55) : Color(.separator), lineWidth: 1))
                .contentShape(Rectangle())
                .opacity(configuration.isPressed ? 0.6 : 1)
        }
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased()).font(.caption2).kerning(3).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 20).padding(.bottom, 8)
    }
}

/// One chore row. Before submit it's a checkbox ([+]/[ ]); after submit it shows the parent's verdict.
struct ChoreRow: View {
    let name: String
    let minutes: Int
    var escalLevel = 0
    let checked: Bool
    var status: String? = nil
    var onToggle: (() -> Void)? = nil

    var body: some View {
        let verdict: (String, Color)? = switch status {
        case Status.approved: ("✓ approved", Theme.good)
        case Status.rejected: ("✗ rejected", Theme.bad)
        case Status.pending: ("· awaiting", Theme.warn)
        default: nil
        }
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(checked ? "[+]" : "[ ]").foregroundStyle(checked ? Theme.accent : .secondary)
                Text(name).frame(maxWidth: .infinity, alignment: .leading)
                if escalLevel > 0 { Text(escalLevel == 1 ? "!" : "!!").bold().foregroundStyle(escalLevel == 1 ? Theme.warn : Theme.bad) }
                if let verdict { Text(verdict.0).font(.footnote).foregroundStyle(verdict.1) }
                else { Text("\(minutes)m").foregroundStyle(.secondary) }
            }
            .frame(minHeight: 52).contentShape(Rectangle())
            .onTapGesture { if status == nil { onToggle?() } }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(verdict.map { "\(name), \($0.0)" } ?? name)
            .accessibilityAddTraits(status == nil && onToggle != nil ? .isButton : [])
            .accessibilityValue(status == nil ? (checked ? "checked" : "not checked") : "")
            Divider()
        }
    }
}

/// Version, XP bar and streak for one player.
struct StatsHeader: View {
    let rank: Rank
    let streak: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(rank.version).font(.title).bold().foregroundStyle(Theme.accent)
                Text(" → \(rank.nextVersion)").foregroundStyle(.secondary)
                Spacer()
                Text("🔥 \(streak) · \(String(format: "%.1f", Engine.momentumMult(streak)))x").font(.callout)
            }
            ProgressView(value: Double(rank.pct) / 100).animation(.easeOut(duration: 0.7), value: rank.pct)
            Text("\(rank.into) / \(rank.need) xp").font(.caption).foregroundStyle(.secondary)
        }
    }
}
