import SwiftUI

@main
struct DOYOURWORKApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var feedback = Feedback()
    @ObservedObject private var themes = ThemeStore.shared

    init() { AppFont.register() }

    var body: some Scene {
        WindowGroup {
            RootView()
                // A new theme redraws everything: colours are read from it as each screen draws.
                .id(themes.current.id)
                .foregroundStyle(Color.appText)
                .background(Color.appBackground.ignoresSafeArea())
                .alert("DOYOURWORK", isPresented: Binding(get: { store.notice != nil }, set: { if !$0 { store.notice = nil } })) {
                    Button("OK", role: .cancel) { store.notice = nil }
                } message: { Text(store.notice ?? "") }
                .environmentObject(store)
                .environmentObject(feedback)
                .font(.app(.body))
                .tint(Theme.accent)
                // Dark only, like Clear: the colour is in the rows, not the background.
                .preferredColorScheme(.dark)
                // The picker sits above the redraw, so it stays open while you try themes.
                .sheet(isPresented: $themes.picking) { ThemePicker().font(.app(.body)) }
        }
    }
}

/// The one place the app points outside itself: the privacy policy on the website, opened in the
/// browser. The app itself never goes online.
enum Links {
    static let privacy = URL(string: "https://doyourwork.today/app-privacy.html")!
}

/// Colours for text and small marks on black, taken from the palette (see Palette.swift).
enum Theme {
    /// Links and highlights: the heat map's orange-red, bright enough to read on black.
    static var accent: Color { ThemeStore.shared.current.isClear ? .hex(0xE8572A) : ThemeStore.shared.current.main }
    static let warn = Color.hex(0xEDB82A)
    static let bad = Color.hex(0xFF4D3D)
    static let good = Color.hex(0x6BC276)
    /// The puzzle's two colours of block: Clear red and Clear blue, both bright on black.
    static var blockA: Color { ThemeStore.shared.current.isClear ? .hex(0xD90015) : ThemeStore.shared.current.main }
    static var blockB: Color { ThemeStore.shared.current.isClear ? .hex(0x45AAC0) : .mix(ThemeStore.shared.current.sub, ThemeStore.shared.current.text, 0.35) }
}
