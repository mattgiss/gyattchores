import Foundation

// MARK: - Player

struct Player: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var avatar: String // Emoji

    static let samples: [Player] = [
        Player(id: UUID(), name: "bekindhearted", avatar: "🦁"),
        Player(id: UUID(), name: "titan", avatar: "🦖")
    ]
}

// MARK: - Chore

struct Chore: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var points: Int
    var icon: String // Emoji

    var dollarValue: Double {
        Double(points) / 250.0
    }

    static let all: [Chore] = [
        Chore(id: UUID(), name: "Pick up Poop", points: 500, icon: "💩"),
        Chore(id: UUID(), name: "Vacuum Living Room", points: 500, icon: "🧹"),
        Chore(id: UUID(), name: "Get Mail", points: 250, icon: "📬"),
        Chore(id: UUID(), name: "Take Out Trash", points: 375, icon: "🗑️"),
        Chore(id: UUID(), name: "Wash Dishes", points: 500, icon: "🍽️"),
        Chore(id: UUID(), name: "Load Dishwasher", points: 625, icon: "🫧"),
        Chore(id: UUID(), name: "Unload Dishwasher", points: 500, icon: "✨"),
        Chore(id: UUID(), name: "Clean Room", points: 750, icon: "🛏️"),
        Chore(id: UUID(), name: "Clean Bathroom", points: 750, icon: "🚿"),
        Chore(id: UUID(), name: "Water Plants", points: 250, icon: "🌱"),
        Chore(id: UUID(), name: "Feed Alfred", points: 250, icon: "🐕"),
        Chore(id: UUID(), name: "Feed Chevy", points: 250, icon: "🐱"),
        Chore(id: UUID(), name: "Sweep Floor", points: 375, icon: "🧹"),
        Chore(id: UUID(), name: "Wipe Counters", points: 375, icon: "🧽"),
        Chore(id: UUID(), name: "Fold Laundry", points: 500, icon: "👕"),
        Chore(id: UUID(), name: "Set Table", points: 250, icon: "🍴"),
        Chore(id: UUID(), name: "Clear Table", points: 250, icon: "🧹")
    ]
}

// MARK: - Chore Log Entry

struct ChoreLog: Identifiable, Codable {
    let id: UUID
    let playerId: UUID
    let choreId: UUID
    let choreName: String
    let choreIcon: String
    let points: Int
    let timestamp: Date
    var status: Status

    enum Status: String, Codable {
        case pending
        case approved
        case rejected
    }

    init(player: Player, chore: Chore) {
        self.id = UUID()
        self.playerId = player.id
        self.choreId = chore.id
        self.choreName = chore.name
        self.choreIcon = chore.icon
        self.points = chore.points
        self.timestamp = Date()
        self.status = .pending
    }
}
