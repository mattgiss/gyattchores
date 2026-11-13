import SwiftUI

@main
struct GyattChoresApp: App {
    @StateObject private var store = GameStore.forLaunch()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.accent)
        }
        .onChange(of: scenePhase) { _, phase in
            // Coming back to the app may be coming back on a new day.
            if phase == .active { store.refreshClock() }
        }
    }
}
