import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        NavigationStack {
            HomeView()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            // Midnight passed (or the clock changed) while the app was open.
            store.refreshClock()
        }
        .alert("Heads up", isPresented: saveProblemBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.saveProblem ?? "")
        }
    }

    private var saveProblemBinding: Binding<Bool> {
        Binding(
            get: { store.saveProblem != nil },
            set: { isShown in
                if !isShown { store.saveProblem = nil }
            }
        )
    }
}
