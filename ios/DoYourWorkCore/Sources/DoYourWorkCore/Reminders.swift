import Foundation

/// The app's two daily notifications, decided the same way on iPhone and Android.
///
/// - Morning, at 7: a random motivational line, to get people to open the app and pick their chores.
/// - Evening, at a time an admin can change (5 p.m. unless they do): "Did you do your work today?",
///   only if someone this phone looks after hasn't picked their chores yet.
///
/// A personal phone (one whose owner plays) looks after its owner. A shared phone, the wall tablet or
/// an admin who doesn't play looks after everyone who plays.
public enum Reminders {
    public static let morningHour = 7
    public static let defaultEveningHour = 17
    /// The evening times an admin can choose from, as hours of the day.
    public static let eveningHours = 12...21

    /// The morning lines, one picked at random each day. Kept identical to native/reminders.json
    /// (and so to Android's list) by the tests.
    public static let lines: [String] = [
        "25 minutes. That's it.",
        "Small jobs, done daily, add up.",
        "Well begun is half done.",
        "Your future self says thanks.",
        "Pick early, play sooner.",
        "Someone might dare you today.",
        "Champions show up on ordinary days.",
        "Points don't earn themselves.",
        "Do it now, then forget about it.",
        "A tidy house is a team sport.",
        "Get ahead while everyone's still asleep.",
        "Today's a good day for a streak.",
        "Little by little, a little becomes a lot.",
        "Done is better than perfect.",
        "The hardest part is picking. So pick.",
        "Your streak is waiting.",
        "Do your work. Then play.",
        "Many hands make light work.",
        "Beat yesterday's you.",
        "The game unlocks when the work is done.",
        "First one to pick sets the pace.",
        "A calm morning beats a late scramble.",
        "Ready, set, chores.",
        "Earn your hour of play.",
        "Show up. That's the whole trick.",
        "Tiny effort, big points.",
        "Nobody ever regretted an empty sink.",
        "Make today count. It's only 25 minutes.",
        "The scoreboard is open.",
        "Good habits start with one pick.",
    ]

    public static let morningBody = "Pick today's chores."
    public static let eveningTitle = "Did you do your work today?"
    public static let eveningGeneric = "Pick your chores before the day's done."

    /// Whose chores this phone reminds about: its owner if they play, otherwise everyone who plays.
    public static func watched(playerIds: [String], me: String?) -> [String] {
        if let me, playerIds.contains(me) { return [me] }
        return playerIds
    }

    /// True once a player has picked today: a card for today that still stands, or chores logged
    /// today that weren't all rejected. Matches when the app stops showing them the picker.
    public static func hasPicked(card: Card?, todaysLogs: [ChoreLog]) -> Bool {
        let rejected = !todaysLogs.isEmpty && Engine.standingToday(Engine.statusToday(todaysLogs)).isEmpty
        if let card { return !(card.submitted && rejected) }
        return !todaysLogs.isEmpty && !rejected
    }

    /// The evening message's body. A personal phone gets the general line; a shared one names who
    /// still has to pick, when that's known.
    public static func eveningBody(stillToPick names: [String], personal: Bool) -> String {
        if personal || names.isEmpty { return eveningGeneric }
        return "Still to pick: \(list(names))."
    }

    static func list(_ names: [String]) -> String {
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + names.last!
    }
}
