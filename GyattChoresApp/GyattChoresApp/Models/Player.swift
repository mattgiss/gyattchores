import Foundation

struct Player: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var avatarUrl: String
    var bestWeekTotal: Int
    var createdAt: Date

    // Computed properties for display
    var weeklyPoints: Int = 0
    var completedChores: Int = 0

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case avatarUrl = "avatar_url"
        case bestWeekTotal = "best_week_total"
        case createdAt = "created_at"
    }

    init(id: UUID = UUID(), name: String, avatarUrl: String, bestWeekTotal: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.avatarUrl = avatarUrl
        self.bestWeekTotal = bestWeekTotal
        self.createdAt = createdAt
    }
}

// Extension for sample data
extension Player {
    static let samples: [Player] = [
        Player(name: "BeKindHearted", avatarUrl: "🦁", bestWeekTotal: 5250),
        Player(name: "MegoDinoLava", avatarUrl: "🦖", bestWeekTotal: 4875)
    ]
}
