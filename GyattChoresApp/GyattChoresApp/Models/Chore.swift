import Foundation

struct Chore: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var description: String?
    var baseValue: Int
    var maxPerDay: Int
    var icon: String
    var isActive: Bool
    var cooldownHours: Int
    var singleClaim: Bool
    var assignedPlayerId: UUID?
    var isFromBid: Bool
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case baseValue = "base_value"
        case maxPerDay = "max_per_day"
        case icon
        case isActive = "is_active"
        case cooldownHours = "cooldown_hours"
        case singleClaim = "single_claim"
        case assignedPlayerId = "assigned_player_id"
        case isFromBid = "is_from_bid"
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        baseValue: Int,
        maxPerDay: Int = 1,
        icon: String,
        isActive: Bool = true,
        cooldownHours: Int = 24,
        singleClaim: Bool = false,
        assignedPlayerId: UUID? = nil,
        isFromBid: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.baseValue = baseValue
        self.maxPerDay = maxPerDay
        self.icon = icon
        self.isActive = isActive
        self.cooldownHours = cooldownHours
        self.singleClaim = singleClaim
        self.assignedPlayerId = assignedPlayerId
        self.isFromBid = isFromBid
        self.createdAt = createdAt
    }

    // Dollar value (250 pts = $1)
    var dollarValue: Double {
        Double(baseValue) / 250.0
    }
}

// Extension for sample data
extension Chore {
    static let samples: [Chore] = [
        Chore(name: "Pick up Poop", baseValue: 500, icon: "💩"),
        Chore(name: "Vacuum Living Room", baseValue: 500, icon: "🧹"),
        Chore(name: "Get Mail", baseValue: 250, icon: "📬"),
        Chore(name: "Take Out Trash", baseValue: 375, icon: "🗑️"),
        Chore(name: "Wash Dishes", baseValue: 500, icon: "🍽️"),
        Chore(name: "Load Dishwasher", baseValue: 625, icon: "🫧"),
        Chore(name: "Unload Dishwasher", baseValue: 500, icon: "✨"),
        Chore(name: "Clean Room", baseValue: 750, icon: "🛏️"),
        Chore(name: "Clean Bathroom", baseValue: 750, icon: "🚿"),
        Chore(name: "Water Plants", baseValue: 250, icon: "🌱"),
        Chore(name: "Feed Alfred", baseValue: 250, cooldownHours: 8, singleClaim: true, icon: "🐕"),
        Chore(name: "Feed Chevy", baseValue: 250, cooldownHours: 8, singleClaim: true, icon: "🐱"),
        Chore(name: "Sweep Floor", baseValue: 375, icon: "🧹"),
        Chore(name: "Wipe Counters", baseValue: 375, icon: "🧽"),
        Chore(name: "Take Out Recycling", baseValue: 250, icon: "♻️"),
        Chore(name: "Fold Laundry", baseValue: 500, icon: "👕"),
        Chore(name: "Set Table", baseValue: 250, icon: "🍴"),
        Chore(name: "Clear Table", baseValue: 250, icon: "🧹")
    ]
}
