import CoreText
import SwiftUI

/// The app's one typeface: Schibsted Grotesk (SIL Open Font License, see native/fonts-OFL.txt),
/// bundled in the same four weights as the Android app so both look alike. Sized like the system
/// text styles and scaling with Dynamic Type.
enum AppFont {
    static let family = "Schibsted Grotesk"

    /// Registers the bundled faces. Called once at launch; the Info.plist is generated, so they
    /// aren't listed there.
    static func register() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        CTFontManagerRegisterFontURLs(urls.filter { $0.lastPathComponent.hasPrefix("SchibstedGrotesk-") } as CFArray, .process, true, nil)
    }

    /// The system's default (Large) point sizes and weights for each text style.
    static func base(_ style: Font.TextStyle) -> (CGFloat, Font.Weight) {
        switch style {
        case .largeTitle: (34, .regular)
        case .title: (28, .regular)
        case .title2: (22, .regular)
        case .title3: (20, .regular)
        case .headline: (17, .semibold)
        case .subheadline: (15, .regular)
        case .callout: (16, .regular)
        case .footnote: (13, .regular)
        case .caption: (12, .regular)
        case .caption2: (11, .regular)
        default: (17, .regular)
        }
    }
}

extension Font {
    /// Schibsted Grotesk at the size of a system text style, growing and shrinking with Dynamic Type.
    static func app(_ style: Font.TextStyle) -> Font {
        let (size, weight) = AppFont.base(style)
        return .custom(AppFont.family, size: size, relativeTo: style).weight(weight)
    }

    /// Schibsted Grotesk at a fixed size, for the few big numbers that don't scale.
    static func app(fixedSize size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(AppFont.family, fixedSize: size).weight(weight)
    }
}
