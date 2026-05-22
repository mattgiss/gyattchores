import SwiftUI

@main
struct GyattChoresWatchApp: App {
    @StateObject private var store = WatchChoreStore()

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(store)
        }
    }
}
