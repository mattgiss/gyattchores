import UIKit
import CoreHaptics

@MainActor
class HapticManager {
    static let shared = HapticManager()

    private var engine: CHHapticEngine?

    private init() {
        prepareHaptics()
    }

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            engine = try CHHapticEngine()
            try engine?.start()

            engine?.resetHandler = { [weak self] in
                do {
                    try self?.engine?.start()
                } catch {
                    print("Failed to restart haptic engine: \(error)")
                }
            }
        } catch {
            print("Haptic engine creation error: \(error)")
        }
    }

    // MARK: - Player Selection (Soft click)

    func playerSelected() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.prepare()
        impact.impactOccurred(intensity: 0.6)
    }

    // MARK: - Chore Button Press (Anticipation)

    func chorePressed() {
        let impact = UIImpactFeedbackGenerator(style: .soft)
        impact.prepare()
        impact.impactOccurred(intensity: 0.4)
    }

    // MARK: - Chore Logged Success (Satisfying reward pattern)

    func choreLogged(points: Int) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = engine else {
            // Fallback to basic haptics
            let notification = UINotificationFeedbackGenerator()
            notification.prepare()
            notification.notificationOccurred(.success)
            return
        }

        // Create a satisfying "cha-ching" pattern based on points
        var events: [CHHapticEvent] = []

        // Initial impact - stronger for more points
        let initialIntensity = min(1.0, 0.5 + (Float(points) / 1500.0))
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: initialIntensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ],
            relativeTime: 0
        ))

        // Rising confirmation bumps
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ],
            relativeTime: 0.08
        ))

        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
            ],
            relativeTime: 0.15
        ))

        // Final satisfying thud
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ],
            relativeTime: 0.25
        ))

        // Bonus celebration taps for high-point chores
        if points >= 500 {
            for i in 0..<3 {
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: 0.35 + Double(i) * 0.05
                ))
            }
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic pattern: \(error)")
        }
    }

    // MARK: - Approve (Confirmation)

    func approved() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = engine else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }

        var events: [CHHapticEvent] = []

        // Double-tap confirmation
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ],
            relativeTime: 0
        ))

        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ],
            relativeTime: 0.1
        ))

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error)")
        }
    }

    // MARK: - Reject (Negative feedback)

    func rejected() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = engine else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }

        var events: [CHHapticEvent] = []

        // Buzzy error pattern
        for i in 0..<3 {
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ],
                relativeTime: Double(i) * 0.08,
                duration: 0.05
            ))
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error)")
        }
    }

    // MARK: - Approve All (Big celebration)

    func approvedAll(count: Int) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = engine else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }

        var events: [CHHapticEvent] = []

        // Cascading celebration
        for i in 0..<min(count, 5) {
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4 + Float(i) * 0.15),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                ],
                relativeTime: Double(i) * 0.08
            ))
        }

        // Final big impact
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ],
            relativeTime: Double(min(count, 5)) * 0.08 + 0.1
        ))

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error)")
        }
    }

    // MARK: - Tab Switch

    func tabSwitch() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.prepare()
        impact.impactOccurred(intensity: 0.5)
    }

    // MARK: - Scroll Snap

    func scrollSnap() {
        let selection = UISelectionFeedbackGenerator()
        selection.prepare()
        selection.selectionChanged()
    }
}
