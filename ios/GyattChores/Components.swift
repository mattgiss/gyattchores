import SwiftUI
import GyattCore

/// The one main action on a screen: a full-width band of the screen's first colour, like the top
/// row of a Clear list. Dark grey when it can't be pressed yet.
struct TermButton: View {
    let label: String
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button(action: action) { Text(label) }
            .buttonStyle(TermButtonStyle(filled: true)).disabled(!enabled)
            .accessibilityIdentifier("main")
    }
}

/// A secondary action: a quiet dark band, so it never competes with the main one.
struct OutlineButton: View {
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) { Text(label) }.buttonStyle(TermButtonStyle(filled: false))
    }
}

/// The app's buttons: edge-to-edge bands, no outlines or rounded corners.
struct TermButtonStyle: ButtonStyle {
    let filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration, filled: filled)
    }

    private struct Face: View {
        let configuration: ButtonStyleConfiguration
        let filled: Bool
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.palette) private var palette

        var body: some View {
            let solid = filled && isEnabled
            configuration.label
                .font(.app(filled ? .headline : .callout))
                .fontWeight(filled ? .bold : .semibold)
                .lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(solid ? palette.ink : (isEnabled ? Color.appText : Color.done))
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, minHeight: filled ? 54 : 46)
                .background(solid ? palette.stops[0] : Color.surface)
                .contentShape(Rectangle())
                .opacity(configuration.isPressed ? 0.7 : 1)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.spring(duration: 0.25), value: configuration.isPressed)
        }
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        // Said plainly, as a heading in a sentence would be, not spaced-out capitals.
        Text(text.prefix(1).uppercased() + text.dropFirst()).font(.app(.subheadline)).fontWeight(.bold).foregroundStyle(Color.done)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 8)
    }
}

/// One chore row, as a band of colour. Picking: rows light up when picked. On a card: a row
/// ticked off drops to black and is struck through, as in Clear; after submit it shows the
/// admin's verdict.
struct ChoreRow: View {
    @Environment(\.palette) private var palette
    /// Not a parent's verdict: another player got this chore in first today.
    static let taken = "taken"
    let name: String
    let minutes: Int
    var escalLevel = 0
    let checked: Bool
    var status: String? = nil
    /// Where the row sits in its list, for its colour.
    var index = 0
    var count = 1
    /// The picker, where a picked row lights up (instead of a card, where a ticked row goes dark).
    var picking = false
    var onToggle: (() -> Void)? = nil

    var body: some View {
        let verdict: (String, Color)? = switch status {
        case Status.approved: ("approved", Theme.good)
        case Status.rejected: ("turned down", Theme.bad)
        case Status.pending: ("waiting", palette.ink.opacity(0.85))
        case ChoreRow.taken: ("taken", Color.done)
        default: nil
        }
        // Lit: on the gradient. Dark: done, taken, judged, or not picked yet.
        let lit = picking ? checked : (status == nil ? !checked : status == Status.pending)
        let struck = !picking && (status == nil ? checked : status == Status.approved || status == ChoreRow.taken)
        Band(index: index, count: count, done: !lit, minHeight: 50) {
            HStack(spacing: 12) {
                Text(name).strikethrough(struck).foregroundStyle(lit ? palette.ink : (picking || status == Status.rejected ? Color.appText : Color.done))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if escalLevel > 0 { Text(escalLevel == 1 ? "!" : "!!").fontWeight(.black).foregroundStyle(lit ? palette.ink : (escalLevel == 1 ? Theme.warn : Theme.bad)) }
                if let verdict { Text(verdict.0).font(.app(.footnote)).fontWeight(.semibold).foregroundStyle(verdict.1) }
                else { Text("\(minutes)m").font(.app(.callout)).foregroundStyle(lit ? palette.ink.opacity(0.85) : Color.done) }
            }
        }
        .onTapGesture { if status == nil { onToggle?() } }
        .animation(.easeOut(duration: 0.2), value: checked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(verdict.map { "\(name), \($0.0)" } ?? name)
        .accessibilityAddTraits(status == nil && onToggle != nil ? .isButton : [])
        .accessibilityValue(status == nil ? (checked ? "checked" : "not checked") : "")
    }
}

/// Version, XP bar and streak for one player.
/// Sits on the screen's top band, so everything is white.
struct StatsHeader: View {
    let rank: Rank
    let streak: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(rank.version).font(.app(fixedSize: 32, weight: .black))
                Spacer()
                Text(streak == 0 ? "No streak yet" : "\(streak)-day streak · \(String(format: "%.1f", Engine.momentumMult(streak)))x points")
                    .font(.app(.footnote)).fontWeight(.semibold)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.heat.ink.opacity(0.25))
                    Capsule().fill(Palette.heat.ink).frame(width: g.size.width * CGFloat(rank.pct) / 100)
                }
            }
            .frame(height: 6)
            .animation(.easeOut(duration: 0.7), value: rank.pct)
            Text("\(rank.into) of \(rank.need) xp to \(rank.nextVersion)").font(.app(.caption)).fontWeight(.semibold).opacity(0.75)
        }
        .foregroundStyle(Palette.heat.ink)
    }
}
