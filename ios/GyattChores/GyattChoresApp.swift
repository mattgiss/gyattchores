import SwiftUI

@main
struct GyattChoresApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var feedback = Feedback()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(feedback)
                .fontDesign(.monospaced)
                .tint(Theme.accent)
        }
    }
}

/// The one place the app points outside itself: the privacy policy on the website, opened in the
/// browser. The app itself never goes online.
enum Links {
    static let privacy = URL(string: "https://gyattchores.com/app-privacy.html")!
}

enum Theme {
    static let accent = Color(red: 0xF2 / 255, green: 0x38 / 255, blue: 0x61 / 255)
    static let warn = Color(red: 0xF5 / 255, green: 0xA6 / 255, blue: 0x23 / 255)
    static let bad = Color(red: 0xEF / 255, green: 0x44 / 255, blue: 0x44 / 255)
    static let good = Color(red: 0x16 / 255, green: 0xA3 / 255, blue: 0x4A / 255)
}
