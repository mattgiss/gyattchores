import Foundation
import SwiftUI

// MARK: - Color Theme

struct AppTheme {
    // Primary gradient - vibrant purple to electric blue
    static let primaryGradient = LinearGradient(
        colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Accent - Electric lime for points/success
    static let accent = Color(hex: "00d4aa")
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "00d4aa"), Color(hex: "7eed56")],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Player colors - Bold, distinct, memorable
    static let playerColors: [PlayerTheme] = [
        PlayerTheme(
            name: "Flame",
            primary: Color(hex: "ff6b6b"),
            secondary: Color(hex: "ee5a24"),
            gradient: LinearGradient(colors: [Color(hex: "ff6b6b"), Color(hex: "ee5a24")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        PlayerTheme(
            name: "Ocean",
            primary: Color(hex: "4facfe"),
            secondary: Color(hex: "00f2fe"),
            gradient: LinearGradient(colors: [Color(hex: "4facfe"), Color(hex: "00f2fe")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        PlayerTheme(
            name: "Sunset",
            primary: Color(hex: "fa709a"),
            secondary: Color(hex: "fee140"),
            gradient: LinearGradient(colors: [Color(hex: "fa709a"), Color(hex: "fee140")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ),
        PlayerTheme(
            name: "Aurora",
            primary: Color(hex: "a8edea"),
            secondary: Color(hex: "fed6e3"),
            gradient: LinearGradient(colors: [Color(hex: "a8edea"), Color(hex: "fed6e3")], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    ]

    // Background
    static let backgroundDark = Color(hex: "0f0f23")
    static let backgroundCard = Color(hex: "1a1a2e")
    static let backgroundCardLight = Color(hex: "25253d")
}

struct PlayerTheme {
    let name: String
    let primary: Color
    let secondary: Color
    let gradient: LinearGradient
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Player

struct Player: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var avatar: String // Emoji
    var themeIndex: Int // Index into AppTheme.playerColors

    var theme: PlayerTheme {
        AppTheme.playerColors[themeIndex % AppTheme.playerColors.count]
    }

    static let samples: [Player] = [
        Player(id: UUID(), name: "BeKindHearted", avatar: "🦁", themeIndex: 0),
        Player(id: UUID(), name: "MegoDinoLava", avatar: "🦖", themeIndex: 1)
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

    // Tier for visual treatment
    var tier: ChoreTier {
        switch points {
        case 0..<300: return .bronze
        case 300..<500: return .silver
        case 500..<700: return .gold
        default: return .diamond
        }
    }

    enum ChoreTier {
        case bronze, silver, gold, diamond

        var color: Color {
            switch self {
            case .bronze: return Color(hex: "cd7f32")
            case .silver: return Color(hex: "c0c0c0")
            case .gold: return Color(hex: "ffd700")
            case .diamond: return Color(hex: "b9f2ff")
            }
        }
    }

    static let all: [Chore] = [
        Chore(id: UUID(), name: "Pick up Poop", points: 500, icon: "💩"),
        Chore(id: UUID(), name: "Vacuum", points: 500, icon: "🧹"),
        Chore(id: UUID(), name: "Get Mail", points: 250, icon: "📬"),
        Chore(id: UUID(), name: "Trash", points: 375, icon: "🗑️"),
        Chore(id: UUID(), name: "Wash Dishes", points: 500, icon: "🍽️"),
        Chore(id: UUID(), name: "Load Dishwasher", points: 625, icon: "🫧"),
        Chore(id: UUID(), name: "Unload Dishwasher", points: 500, icon: "✨"),
        Chore(id: UUID(), name: "Clean Room", points: 750, icon: "🛏️"),
        Chore(id: UUID(), name: "Clean Bathroom", points: 750, icon: "🚿"),
        Chore(id: UUID(), name: "Water Plants", points: 250, icon: "🌱"),
        Chore(id: UUID(), name: "Feed Alfred", points: 250, icon: "🐕"),
        Chore(id: UUID(), name: "Feed Chevy", points: 250, icon: "🐱"),
        Chore(id: UUID(), name: "Sweep", points: 375, icon: "🧹"),
        Chore(id: UUID(), name: "Wipe Counters", points: 375, icon: "🧽"),
        Chore(id: UUID(), name: "Fold Laundry", points: 500, icon: "👕"),
        Chore(id: UUID(), name: "Set Table", points: 250, icon: "🍴"),
        Chore(id: UUID(), name: "Clear Table", points: 250, icon: "🧺")
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
