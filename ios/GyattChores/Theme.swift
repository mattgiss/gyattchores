import SwiftUI

/// The GyattChores look: monospaced type, one hot-pink accent, hairline rules.
/// Surfaces and text use system colors so light and dark mode both work.
enum Theme {
    static let accent = Color(red: 242 / 255, green: 56 / 255, blue: 97 / 255)     // #F23861
    static let warning = Color(red: 245 / 255, green: 166 / 255, blue: 35 / 255)   // #F5A623
    static let danger = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255)     // #EF4444
    static let success = Color(red: 22 / 255, green: 163 / 255, blue: 74 / 255)    // #16A34A
    static let hairline = Color(uiColor: .separator)
    static let emptyCell = Color(uiColor: .systemGray5)

    /// Content never grows wider than this, so it stays readable on big screens.
    static let contentWidth: CGFloat = 520
}

extension Font {
    /// A monospaced font that follows Dynamic Type.
    static func mono(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .monospaced, weight: weight)
    }
}

/// The small, widely tracked label above a section.
struct Eyebrow: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.mono(.caption2))
            .tracking(3)
            .foregroundStyle(.secondary)
    }
}

/// A 1-point horizontal rule.
struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
    }
}

/// Square, bordered, all-caps monospaced buttons.
struct TerminalButtonStyle: ButtonStyle {
    enum Kind {
        case filled, outline
    }

    var kind: Kind = .outline
    var color: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, kind: kind, color: color)
    }

    private struct StyledLabel: View {
        let configuration: ButtonStyleConfiguration
        let kind: Kind
        let color: Color
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.mono(.footnote, weight: .heavy))
                .tracking(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 12)
                .foregroundStyle(foreground)
                .background(background)
                .overlay(Rectangle().strokeBorder(border, lineWidth: 1))
                .contentShape(Rectangle())
                .opacity(configuration.isPressed ? 0.6 : 1)
        }

        private var foreground: Color {
            guard isEnabled else { return Color.secondary }
            return kind == .filled ? Color.white : color
        }

        private var background: Color {
            isEnabled && kind == .filled ? color : Color.clear
        }

        private var border: Color {
            isEnabled ? color : Theme.hairline
        }
    }
}
