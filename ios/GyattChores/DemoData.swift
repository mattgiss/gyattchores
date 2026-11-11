#if DEBUG
import Foundation
import GyattCore

/// A month of made-up history for the `-demoData` launch argument: one player
/// who clears the card most days, one who's hit and miss. Debug builds only.
enum DemoData {
    static func state(now: Date, engine: Engine = Engine()) -> GameState {
        let players = ChoreCatalog.players
        var logs: [ChoreLog] = []

        for daysAgo in 0..<Engine.logDays {
            guard let day = engine.calendar.date(byAdding: .day, value: -daysAgo, to: now) else { continue }
            for (index, player) in players.enumerated() {
                let steady = index == 0
                if steady ? daysAgo % 9 == 4 : daysAgo % 3 == 1 { continue }   // a day off
                let goal = steady || daysAgo % 4 != 0 ? Engine.dailyMinutes : 14   // some short days

                var minutes = 0
                var slot = daysAgo * 5 + index * 11
                var used = Set<String>()
                while minutes < goal, used.count < engine.pool.count {
                    let chore = engine.pool[slot % engine.pool.count]
                    slot += 1
                    guard used.insert(chore.id).inserted else { continue }
                    logs.append(ChoreLog(
                        playerId: player.id, playerName: player.name,
                        choreId: chore.id, choreName: chore.name,
                        points: chore.pts, minutes: chore.tiers[0],
                        timestamp: day.addingTimeInterval(Double(-used.count)),
                        // Today's chores for the second player are still waiting on a parent.
                        status: daysAgo == 0 && !steady ? .pending : .approved
                    ))
                    minutes += chore.tiers[0]
                }
            }
        }
        return GameState(logs: logs)
    }
}
#endif
