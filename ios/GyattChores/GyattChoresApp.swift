import SwiftUI

@main
struct GyattChoresApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var feedback = Feedback()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .environmentObject(feedback)
                .fontDesign(.monospaced)
                .tint(Theme.accent)
                // Sync on open and every 10 seconds while the app is on screen.
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    while !Task.isCancelled {
                        store.requestSync()
                        try? await Task.sleep(for: .seconds(10))
                    }
                }
        }
    }
}

enum Theme {
    static let accent = Color(red: 0xF2 / 255, green: 0x38 / 255, blue: 0x61 / 255)
    static let warn = Color(red: 0xF5 / 255, green: 0xA6 / 255, blue: 0x23 / 255)
    static let bad = Color(red: 0xEF / 255, green: 0x44 / 255, blue: 0x44 / 255)
    static let good = Color(red: 0x16 / 255, green: 0xA3 / 255, blue: 0x4A / 255)
}
