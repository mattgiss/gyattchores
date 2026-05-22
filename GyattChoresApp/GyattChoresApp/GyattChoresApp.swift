import SwiftUI

@main
struct GyattChoresApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var dataManager = DataManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(dataManager)
                .preferredColorScheme(authManager.colorScheme)
        }
    }
}
