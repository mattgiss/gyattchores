import Foundation

enum CompletionStatus: String, Codable, CaseIterable {
    case pending
    case approved
    case rejected
}

struct ChoreCompletion: Identifiable, Codable, Hashable {
    let id: UUID
    let playerId: UUID
    let choreId: UUID
    var completedDate: Date
    var completedAt: Date
    var valueAwarded: Int
    var status: CompletionStatus

    // Joined data (not from database directly)
    var playerName: String?
    var choreName: String?
    var choreIcon: String?

    enum CodingKeys: String, CodingKey {
        case id
        case playerId = "player_id"
        case choreId = "chore_id"
        case completedDate = "completed_date"
        case completedAt = "completed_at"
        case valueAwarded = "value_awarded"
        case status
    }

    init(
        id: UUID = UUID(),
        playerId: UUID,
        choreId: UUID,
        completedDate: Date = Date(),
        completedAt: Date = Date(),
        valueAwarded: Int,
        status: CompletionStatus = .pending,
        playerName: String? = nil,
        choreName: String? = nil,
        choreIcon: String? = nil
    ) {
        self.id = id
        self.playerId = playerId
        self.choreId = choreId
        self.completedDate = completedDate
        self.completedAt = completedAt
        self.valueAwarded = valueAwarded
        self.status = status
        self.playerName = playerName
        self.choreName = choreName
        self.choreIcon = choreIcon
    }
}
