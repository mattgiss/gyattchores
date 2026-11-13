import XCTest
@testable import GyattCore

/// Rules the fixtures don't reach: picking against the budget, turning a card
/// into logs, and reading back the parent's verdict.
final class EngineBehaviorTests: XCTestCase {
    let player = ChoreCatalog.players[0]
    let other = ChoreCatalog.players[1]
    let now = Date(timeIntervalSince1970: 1_794_411_000)   // 2026-11-11T15:30:00Z

    var engine: Engine {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return Engine(calendar: calendar)
    }

    private func chore(_ id: String, minutes: Int, cat: String = "kitchen") -> CardChore {
        CardChore(id: id, name: id, cat: cat, pts: 10, neglectDays: 0, currentMinutes: minutes, escalLevel: 0)
    }

    // MARK: Picker

    func testEmptySelectionIsNotReady() {
        let pool = [chore("a", minutes: 10), chore("b", minutes: 10), chore("c", minutes: 10)]
        let summary = engine.pickerSummary(picked: [], pool: pool, bonus: false)
        XCTAssertEqual(summary.total, 0)
        XCTAssertEqual(summary.remaining, 25)
        XCTAssertTrue(summary.canAddMore)
        XCTAssertFalse(summary.isReady)
    }

    func testTwentyMinutesIsAFullDay() {
        let pool = [chore("a", minutes: 10), chore("b", minutes: 10), chore("c", minutes: 5)]
        let short = engine.pickerSummary(picked: ["a"], pool: pool, bonus: false)
        XCTAssertFalse(short.isFull)
        XCTAssertFalse(short.isReady, "10 minutes with room for more is not a full day")

        let full = engine.pickerSummary(picked: ["a", "b"], pool: pool, bonus: false)
        XCTAssertTrue(full.isFull)
        XCTAssertTrue(full.isReady)
        XCTAssertEqual(full.remaining, 5)
    }

    func testShortCardIsReadyWhenNothingElseFits() {
        let pool = [chore("a", minutes: 18), chore("b", minutes: 10)]
        let summary = engine.pickerSummary(picked: ["a"], pool: pool, bonus: false)
        XCTAssertFalse(summary.isFull)
        XCTAssertFalse(summary.canAddMore)
        XCTAssertTrue(summary.isReady, "nothing left fits in 7 minutes, so the card can be locked in")
        XCTAssertFalse(summary.canPick(pool[1]))
    }

    func testBonusRoundHasNoCap() {
        let pool = [chore("a", minutes: 20), chore("b", minutes: 20), chore("c", minutes: 20)]
        let summary = engine.pickerSummary(picked: ["a", "b"], pool: pool, bonus: true)
        XCTAssertEqual(summary.total, 40)
        XCTAssertNil(summary.remaining)
        XCTAssertTrue(summary.isReady)
        XCTAssertTrue(summary.canPick(pool[2]))
        XCTAssertFalse(engine.pickerSummary(picked: [], pool: pool, bonus: true).isReady)
    }

    func testFillNeverExceedsBudget() {
        let pool = engine.pickableChores(playerId: player.id, logs: [], now: now)
        let filled = Set(engine.suggestFill(picked: ["fold-laundry"], pool: pool))
        let total = pool.filter { filled.contains($0.id) }.reduce(0) { $0 + $1.currentMinutes }
        XCTAssertLessThanOrEqual(total, Engine.dailyMinutes)
        XCTAssertTrue(filled.contains("fold-laundry"))
        XCTAssertGreaterThan(filled.count, 1)
    }

    // MARK: Submitting

    func testMakeLogsRecordsPointsAndMinutes() {
        let chores = [chore("scrub-toilet", minutes: 9), chore("make-bed", minutes: 3)]
        let logs = engine.makeLogs(for: chores, player: player, now: now)
        XCTAssertEqual(logs.map(\.choreId), ["scrub-toilet", "make-bed"])
        XCTAssertEqual(logs.map(\.minutes), [9, 3])
        XCTAssertEqual(logs.map(\.points), [10, 10])
        XCTAssertTrue(logs.allSatisfy { $0.status == .pending && $0.playerId == player.id })
        XCTAssertEqual(Set(logs.map(\.id)).count, 2)
        XCTAssertLessThan(logs[0].timestamp, logs[1].timestamp, "submitted order survives sorting")
    }

    func testPendingLogsEarnNothingUntilApproved() {
        let pool = engine.pickableChores(playerId: player.id, logs: [], now: now)
        var logs = engine.makeLogs(for: Array(pool.prefix(3)), player: player, now: now)
        XCTAssertEqual(engine.xp(playerId: player.id, logs: logs), 0)
        XCTAssertEqual(engine.streak(playerId: player.id, logs: logs, now: now), 0)

        for index in logs.indices { logs[index].status = .approved }
        XCTAssertEqual(engine.xp(playerId: player.id, logs: logs), pool.prefix(3).reduce(0) { $0 + $1.pts })
        XCTAssertEqual(engine.streak(playerId: player.id, logs: logs, now: now), 1)
        XCTAssertEqual(engine.xp(playerId: other.id, logs: logs), 0, "another player's logs don't count")
    }

    func testApprovalResetsEscalation() {
        let before = engine.pickableChores(playerId: player.id, logs: [], now: now).first { $0.id == "dog-poop" }!
        XCTAssertEqual(before.escalLevel, 2)
        XCTAssertEqual(before.currentMinutes, 18)

        let log = ChoreLog(playerId: player.id, playerName: player.name, choreId: "dog-poop", choreName: "pick up dog poop",
                           points: 15, minutes: 18, timestamp: now.addingTimeInterval(-3600), status: .approved)
        let after = engine.pickableChores(playerId: player.id, logs: [log], now: now).first { $0.id == "dog-poop" }!
        XCTAssertEqual(after.neglectDays, 0)
        XCTAssertEqual(after.escalLevel, 0)
        XCTAssertEqual(after.currentMinutes, 5)
    }

    // MARK: Today

    func testTodayStateSplitsCardFromBonusAndPrefersVerdicts() {
        let card = DailyCard(chores: [chore("scrub-toilet", minutes: 5), chore("make-bed", minutes: 3)],
                             checked: [true, true], submitted: true)
        func log(_ choreId: String, _ status: LogStatus, secondsAgo: Double, player: Player? = nil) -> ChoreLog {
            let p = player ?? self.player
            return ChoreLog(playerId: p.id, playerName: p.name, choreId: choreId, choreName: choreId,
                            points: 10, minutes: 5, timestamp: now.addingTimeInterval(-secondsAgo), status: status)
        }
        let logs = [
            log("scrub-toilet", .pending, secondsAgo: 10),
            log("scrub-toilet", .approved, secondsAgo: 20),      // duplicate row: the verdict wins
            log("make-bed", .rejected, secondsAgo: 30),
            log("dog-poop", .pending, secondsAgo: 40),           // not on the card: bonus round
            log("water-plants", .approved, secondsAgo: 86_400 * 2),   // another day
            log("wipe-mirrors", .approved, secondsAgo: 50, player: other),
        ]
        let state = engine.todayState(playerId: player.id, logs: logs, card: card, now: now)
        XCTAssertEqual(state.statusByChore["scrub-toilet"], .approved)
        XCTAssertEqual(state.statusByChore["make-bed"], .rejected)
        XCTAssertEqual(state.statusByChore["dog-poop"], .pending)
        XCTAssertNil(state.statusByChore["water-plants"])
        XCTAssertNil(state.statusByChore["wipe-mirrors"])
        XCTAssertEqual(state.bonus.map(\.id), ["dog-poop"])
        XCTAssertEqual(state.loggedToday, ["scrub-toilet", "make-bed", "dog-poop"])
        XCTAssertEqual(state.bonusLeft, ChoreCatalog.pool.count - 3)
    }

    func testDayBoundaryFollowsTheCalendarTimeZone() {
        // 2026-11-11T02:00:00Z is still Nov 10 in Los Angeles.
        let stamp = Date(timeIntervalSince1970: 1_794_362_400)
        let log = ChoreLog(playerId: player.id, playerName: player.name, choreId: "make-bed", choreName: "make bed",
                           points: 8, minutes: 3, timestamp: stamp, status: .approved)

        var la = Calendar(identifier: .gregorian)
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let laEngine = Engine(calendar: la)
        let utcEngine = engine

        XCTAssertNotNil(utcEngine.cardFromLogs(playerId: player.id, logs: [log], now: now))
        XCTAssertNil(laEngine.cardFromLogs(playerId: player.id, logs: [log], now: now),
                     "in LA that log belongs to yesterday")
        XCTAssertEqual(utcEngine.streak(playerId: player.id, logs: [log], now: now), 1)
        XCTAssertEqual(laEngine.streak(playerId: player.id, logs: [log], now: now), 0)
    }

    func testDailyCardBookkeeping() {
        var card = DailyCard(chores: [chore("a", minutes: 10), chore("b", minutes: 12)])
        XCTAssertEqual(card.checked, [false, false])
        XCTAssertEqual(card.totalMinutes, 22)
        XCTAssertFalse(card.allChecked)
        card.checked[0] = true
        XCTAssertEqual(card.doneCount, 1)
        card.checked[1] = true
        XCTAssertTrue(card.allChecked)

        let data = try! JSONEncoder().encode(card)
        XCTAssertEqual(try! JSONDecoder().decode(DailyCard.self, from: data), card)
    }

    func testDayMinutesShading() {
        XCTAssertFalse(DayMinutes(date: now, minutes: 24).isHit)
        XCTAssertTrue(DayMinutes(date: now, minutes: 25).isHit)
        XCTAssertEqual(DayMinutes(date: now, minutes: 40).fraction, 1)
        XCTAssertEqual(DayMinutes(date: now, minutes: 0).fraction, 0)
    }
}
