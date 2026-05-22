import SwiftUI

@main
struct GyattChoresApp: App {
    @StateObject private var store = ChoreStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
