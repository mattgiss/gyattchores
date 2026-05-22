import SwiftUI
import Combine

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isAdmin = false
    @Published var colorScheme: ColorScheme? = nil

    private let loginCode = "0413"
    private let adminCode = "7874"

    // Session timeout (30 minutes)
    private var sessionTimer: Timer?
    private let sessionTimeout: TimeInterval = 30 * 60

    init() {
        // Auto-detect dark mode based on time
        updateColorScheme()
    }

    func login(with code: String) -> Bool {
        if code == loginCode {
            isAuthenticated = true
            startSessionTimer()
            return true
        }
        return false
    }

    func verifyAdmin(code: String) -> Bool {
        if code == adminCode {
            isAdmin = true
            return true
        }
        return false
    }

    func logout() {
        isAuthenticated = false
        isAdmin = false
        sessionTimer?.invalidate()
        sessionTimer = nil
    }

    func toggleColorScheme() {
        if colorScheme == .dark {
            colorScheme = .light
        } else {
            colorScheme = .dark
        }
    }

    private func updateColorScheme() {
        let hour = Calendar.current.component(.hour, from: Date())
        // Dark mode: 6 PM to 6 AM
        colorScheme = (hour < 6 || hour >= 18) ? .dark : .light
    }

    private func startSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: sessionTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.logout()
            }
        }
    }

    func resetSessionTimer() {
        startSessionTimer()
    }
}
