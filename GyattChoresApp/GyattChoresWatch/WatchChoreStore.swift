import SwiftUI

// Simplified store for watchOS
@MainActor
class WatchChoreStore: ObservableObject {
    @Published var players: [WatchPlayer] = [
        WatchPlayer(id: "1", name: "bekindhearted", avatar: "🦁"),
        WatchPlayer(id: "2", name: "titan", avatar: "🦖")
    ]

    @Published var chores: [WatchChore] = [
        WatchChore(id: "1", name: "Poop", icon: "💩", points: 500),
        WatchChore(id: "2", name: "Vacuum", icon: "🧹", points: 500),
        WatchChore(id: "3", name: "Mail", icon: "📬", points: 250),
        WatchChore(id: "4", name: "Trash", icon: "🗑️", points: 375),
        WatchChore(id: "5", name: "Dishes", icon: "🍽️", points: 500),
        WatchChore(id: "6", name: "Feed Alfred", icon: "🐕", points: 250),
        WatchChore(id: "7", name: "Feed Chevy", icon: "🐱", points: 250),
        WatchChore(id: "8", name: "Clean Room", icon: "🛏️", points: 750)
    ]

    @Published var selectedPlayer: WatchPlayer?
    @Published var recentLogs: [WatchLog] = []

    func logChore(_ chore: WatchChore, for player: WatchPlayer) {
        let log = WatchLog(
            playerName: player.name,
            choreName: chore.name,
            choreIcon: chore.icon,
            points: chore.points
        )
        recentLogs.insert(log, at: 0)

        // Keep only last 10 logs
        if recentLogs.count > 10 {
            recentLogs = Array(recentLogs.prefix(10))
        }

        // Haptic
        WKInterfaceDevice.current().play(.success)
    }
}

struct WatchPlayer: Identifiable, Hashable {
    let id: String
    let name: String
    let avatar: String
}

struct WatchChore: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let points: Int
}

struct WatchLog: Identifiable {
    let id = UUID()
    let playerName: String
    let choreName: String
    let choreIcon: String
    let points: Int
    let timestamp = Date()
}

import WatchKit
