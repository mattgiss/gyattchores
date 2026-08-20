import AppIntents
import SwiftUI

// MARK: - Log Chore Intent

struct LogChoreIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Chore"
    static var description = IntentDescription("Log a completed chore for a player")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Chore")
    var choreName: String

    @Parameter(title: "Player")
    var playerName: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = ChoreStore()

        guard let chore = store.chores.first(where: { $0.name.lowercased().contains(choreName.lowercased()) }) else {
            return .result(dialog: "Couldn't find chore '\(choreName)'")
        }

        guard let player = store.players.first(where: { $0.name.lowercased().contains(playerName.lowercased()) }) else {
            return .result(dialog: "Couldn't find player '\(playerName)'")
        }

        store.logChore(chore, for: player)

        return .result(dialog: "Logged \(chore.name) for \(player.name)! +\(chore.points) pts")
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$choreName) for \(\.$playerName)")
    }
}

// MARK: - Quick Log Intents (Pre-configured shortcuts)

struct LogPoopIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Pick Up Poop"
    static var description = IntentDescription("Quick log poop pickup")

    @Parameter(title: "Player")
    var playerName: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = ChoreStore()

        guard let chore = store.chores.first(where: { $0.name == "Pick up Poop" }),
              let player = store.players.first(where: { $0.name.lowercased().contains(playerName.lowercased()) }) else {
            return .result(dialog: "Couldn't log chore")
        }

        store.logChore(chore, for: player)
        return .result(dialog: "Poop picked up! +500 pts for \(player.name)")
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Log poop pickup for \(\.$playerName)")
    }
}

struct LogFeedDogIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Feed Alfred"
    static var description = IntentDescription("Quick log dog feeding")

    @Parameter(title: "Player")
    var playerName: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = ChoreStore()

        guard let chore = store.chores.first(where: { $0.name == "Feed Alfred" }),
              let player = store.players.first(where: { $0.name.lowercased().contains(playerName.lowercased()) }) else {
            return .result(dialog: "Couldn't log chore")
        }

        store.logChore(chore, for: player)
        return .result(dialog: "Alfred fed! +250 pts for \(player.name)")
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Log feeding Alfred for \(\.$playerName)")
    }
}

struct LogFeedCatIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Feed Chevy"
    static var description = IntentDescription("Quick log cat feeding")

    @Parameter(title: "Player")
    var playerName: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = ChoreStore()

        guard let chore = store.chores.first(where: { $0.name == "Feed Chevy" }),
              let player = store.players.first(where: { $0.name.lowercased().contains(playerName.lowercased()) }) else {
            return .result(dialog: "Couldn't log chore")
        }

        store.logChore(chore, for: player)
        return .result(dialog: "Chevy fed! +250 pts for \(player.name)")
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Log feeding Chevy for \(\.$playerName)")
    }
}

// MARK: - App Shortcuts Provider

struct GyattChoresShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogChoreIntent(),
            phrases: [
                "Log a chore in \(.applicationName)"
            ],
            shortTitle: "Log Chore",
            systemImageName: "checkmark.circle"
        )

        AppShortcut(
            intent: LogPoopIntent(),
            phrases: [
                "Log poop pickup in \(.applicationName)"
            ],
            shortTitle: "Log Poop",
            systemImageName: "leaf"
        )

        AppShortcut(
            intent: LogFeedDogIntent(),
            phrases: [
                "Feed the dog in \(.applicationName)"
            ],
            shortTitle: "Feed Dog",
            systemImageName: "dog"
        )

        AppShortcut(
            intent: LogFeedCatIntent(),
            phrases: [
                "Feed the cat in \(.applicationName)"
            ],
            shortTitle: "Feed Cat",
            systemImageName: "cat"
        )
    }
}
