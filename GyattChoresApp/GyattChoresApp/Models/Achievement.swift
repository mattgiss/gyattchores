import Foundation

enum AchievementType: String, Codable, CaseIterable {
    case totalChores = "total_chores"
    case totalPoints = "total_points"
    case goatWins = "goat_wins"
    case streakDays = "streak_days"
    case special
}

struct Achievement: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var icon: String
    var requirementType: AchievementType
    var requirementValue: Int
    var pointsReward: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case icon
        case requirementType = "requirement_type"
        case requirementValue = "requirement_value"
        case pointsReward = "points_reward"
    }

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        icon: String,
        requirementType: AchievementType,
        requirementValue: Int,
        pointsReward: Int = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.requirementType = requirementType
        self.requirementValue = requirementValue
        self.pointsReward = pointsReward
    }
}

struct PlayerAchievement: Identifiable, Codable, Hashable {
    let id: UUID
    let playerId: UUID
    let achievementId: UUID
    let earnedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case playerId = "player_id"
        case achievementId = "achievement_id"
        case earnedAt = "earned_at"
    }
}

// Sample achievements
extension Achievement {
    static let samples: [Achievement] = [
        // Chore milestones
        Achievement(name: "First Steps", description: "Complete your first chore", icon: "👶", requirementType: .totalChores, requirementValue: 1),
        Achievement(name: "Getting Started", description: "Complete 10 chores", icon: "🚀", requirementType: .totalChores, requirementValue: 10),
        Achievement(name: "Chore Champion", description: "Complete 50 chores", icon: "🏆", requirementType: .totalChores, requirementValue: 50),
        Achievement(name: "Hundred Club", description: "Complete 100 chores", icon: "💯", requirementType: .totalChores, requirementValue: 100),
        Achievement(name: "Chore Master", description: "Complete 250 chores", icon: "👑", requirementType: .totalChores, requirementValue: 250),
        Achievement(name: "Chore Legend", description: "Complete 500 chores", icon: "🌟", requirementType: .totalChores, requirementValue: 500),

        // Point milestones
        Achievement(name: "Point Starter", description: "Earn 1,000 points", icon: "💰", requirementType: .totalPoints, requirementValue: 1000),
        Achievement(name: "Point Collector", description: "Earn 5,000 points", icon: "💎", requirementType: .totalPoints, requirementValue: 5000),
        Achievement(name: "Point Master", description: "Earn 10,000 points", icon: "🏅", requirementType: .totalPoints, requirementValue: 10000),
        Achievement(name: "Point Legend", description: "Earn 25,000 points", icon: "🎖️", requirementType: .totalPoints, requirementValue: 25000),

        // Streak achievements
        Achievement(name: "Daily Dedication", description: "3-day streak", icon: "🔥", requirementType: .streakDays, requirementValue: 3),
        Achievement(name: "Weekly Warrior", description: "7-day streak", icon: "⚡", requirementType: .streakDays, requirementValue: 7),
        Achievement(name: "Unstoppable", description: "14-day streak", icon: "💪", requirementType: .streakDays, requirementValue: 14),
        Achievement(name: "Legendary", description: "30-day streak", icon: "🌈", requirementType: .streakDays, requirementValue: 30)
    ]
}
