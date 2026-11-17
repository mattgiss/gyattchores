import XCTest
@testable import GyattCore

final class EngineTests: XCTestCase {
    // Shared fixtures live with the Android project so both ports are checked against the same data.
    static let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let pool: [Chore] = try! JSONDecoder().decode([Chore].self, from: Data(contentsOf: repo.appendingPathComponent("native/chores.json")))
    static let poolMap = Dictionary(uniqueKeysWithValues: pool.map { ($0.id, $0) })
    static var utc: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    func testPoolAndConstants() {
        XCTAssertEqual(Self.pool.count, 27)
        XCTAssertEqual(Engine.dailyMinutes, 25); XCTAssertEqual(Engine.fullDayMinutes, 20); XCTAssertEqual(Engine.logDays, 30)
    }

    func testEscalationTiers() {
        let toilet = Self.poolMap["scrub-toilet"]! // tiers 5,9,15 at 0,3,7 days
        XCTAssertEqual(Engine.enrich(toilet, days: 2).currentMinutes, 5)
        XCTAssertEqual(Engine.enrich(toilet, days: 3).currentMinutes, 9)
        XCTAssertEqual(Engine.enrich(toilet, days: Engine.never).escalLevel, 2)
        XCTAssertEqual(Engine.enrich(Self.poolMap["start-laundry"]!, days: 0).escalLevel, 2)
    }

    func testXpCurveAndVersions() {
        XCTAssertEqual(Engine.xpToNext(1), 60); XCTAssertEqual(Engine.xpToNext(2), 80)
        XCTAssertEqual(Engine.rank(xp: 59).level, 1); XCTAssertEqual(Engine.rank(xp: 60).level, 2); XCTAssertEqual(Engine.rank(xp: 140).level, 3)
        XCTAssertEqual(Engine.toVersion(1), "v1.0"); XCTAssertEqual(Engine.toVersion(10), "v1.9"); XCTAssertEqual(Engine.toVersion(11), "v2.0")
        XCTAssertEqual(Engine.momentumMult(50), 2.0, accuracy: 1e-9)
    }

    func testAdminHash() {
        XCTAssertEqual(Engine.fnv1a(""), 2166136261)
        XCTAssertEqual(Engine.fnv1a("a"), 0xE40C292C) // published FNV-1a 32-bit test vector
        XCTAssertNotEqual(Engine.fnv1a("wrong"), Engine.adminCodeHash)
        // The hash of the code retired in November 2026, which was published in plain text.
        XCTAssertNotEqual(Engine.adminCodeHash, 1305456521 as UInt32)
    }

    func log(_ chore: String, _ day: String, hour: Int = 12, status: String = Status.approved, player: String = "1") -> ChoreLog {
        let f = ISO8601DateFormatter()
        let c = Self.poolMap[chore]!
        return ChoreLog(playerId: player, playerName: "p", choreId: chore, choreName: c.name, points: c.pts, minutes: nil, status: status,
                        timestamp: f.date(from: "\(day)T\(String(format: "%02d", hour)):00:00Z")!)
    }

    func testDaresScoreForGuesserAndDoerAfterMidnight() {
        let cal = Self.utc
        let logs = [log("scrub-toilet", "2026-11-10", player: "2"), log("make-bed", "2026-11-10", status: Status.pending, player: "2")]
        let dares = [Dare(from: "1", target: "2", choreId: "scrub-toilet", day: "2026-11-10"),
                     Dare(from: "3", target: "2", choreId: "scrub-toilet", day: "2026-11-10"),
                     Dare(from: "1", target: "2", choreId: "make-bed", day: "2026-11-10")]
        XCTAssertEqual(Engine.dareXp(playerId: "1", dares: dares, logs: logs, today: "2026-11-10", calendar: cal), 0, "hidden and unscored the same day")
        XCTAssertEqual(Engine.dareXp(playerId: "1", dares: dares, logs: logs, today: "2026-11-11", calendar: cal), 10)
        XCTAssertEqual(Engine.dareXp(playerId: "3", dares: dares, logs: logs, today: "2026-11-11", calendar: cal), 10)
        XCTAssertEqual(Engine.dareXp(playerId: "2", dares: dares, logs: logs, today: "2026-11-11", calendar: cal), 10, "5 per person who dared it")
    }

    func testDareRulesAndWeekPoints() {
        let cal = Self.utc
        let three = (0..<3).map { Dare(from: "1", target: "2", choreId: "c\($0)", day: "2026-11-10") }
        XCTAssertNil(Engine.dareBlocked(from: "1", target: "2", mineToday: [], targetSubmitted: false))
        XCTAssertNotNil(Engine.dareBlocked(from: "1", target: "1", mineToday: [], targetSubmitted: false))
        XCTAssertNotNil(Engine.dareBlocked(from: "1", target: "2", mineToday: [], targetSubmitted: true))
        XCTAssertNotNil(Engine.dareBlocked(from: "1", target: "2", mineToday: three, targetSubmitted: false))
        // 2026-11-10 is a Tuesday. Sunday's chore is last week; Monday 8 + Tuesday 20 + doer bonus 5 for Monday's settled dare.
        let logs = [log("make-bed", "2026-11-08"), log("make-bed", "2026-11-09"), log("scrub-toilet", "2026-11-10")]
        let dares = [Dare(from: "2", target: "1", choreId: "make-bed", day: "2026-11-09"), Dare(from: "2", target: "1", choreId: "scrub-toilet", day: "2026-11-10")]
        let now = ISO8601DateFormatter().date(from: "2026-11-10T18:00:00Z")!
        XCTAssertEqual(Engine.dayKey(Engine.weekStart(now, calendar: cal), calendar: cal), "2026-11-09")
        XCTAssertEqual(Engine.weekPoints(playerId: "1", logs: logs, dares: dares, now: now, calendar: cal), 33)
        XCTAssertEqual(Engine.weekPoints(playerId: "2", logs: logs, dares: dares, now: now, calendar: cal), 10)
    }

    /// Same inputs as the web app's own functions (run in Node), same outputs. Shares golden.json with Android.
    func testMatchesWebAppGolden() throws {
        let url = Self.repo.appendingPathComponent("android/app/src/test/resources/golden.json")
        let g = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        let now = Date(timeIntervalSince1970: (g["now"] as! Double) / 1000)
        let logs = (g["logs"] as! [[String: Any]]).map { o in
            ChoreLog(id: o["id"] as! String, playerId: o["playerId"] as! String, playerName: o["playerName"] as! String,
                     choreId: o["choreId"] as! String, choreName: o["choreName"] as! String, points: o["points"] as! Int,
                     minutes: o["minutes"] as? Int, status: o["status"] as! String,
                     timestamp: Date(timeIntervalSince1970: (o["timestamp"] as! Double) / 1000))
        }
        let cal = Self.utc
        let fmt = DateFormatter(); fmt.calendar = cal; fmt.timeZone = cal.timeZone; fmt.dateFormat = "yyyy-MM-dd"
        for (pid, any) in g["players"] as! [String: [String: Any]] {
            let xp = Engine.xp(playerId: pid, logs: logs, calendar: cal)
            XCTAssertEqual(xp, any["xp"] as! Int, "xp \(pid)")
            let r = any["rank"] as! [String: Any], rank = Engine.rank(xp: xp)
            XCTAssertEqual(rank.level, r["level"] as! Int); XCTAssertEqual(rank.version, r["version"] as! String); XCTAssertEqual(rank.pct, r["pct"] as! Int)
            XCTAssertEqual(Engine.streak(playerId: pid, logs: logs, now: now, calendar: cal), any["streak"] as! Int, "streak \(pid)")

            let pick = Engine.pickableChores(pool: Self.pool, playerId: pid, logs: logs, now: now)
            let expected = (any["pickable"] as! [[Any]]).map { "\($0[0])|\($0[1])|\($0[2])|\($0[3])" }
            XCTAssertEqual(pick.map { "\($0.id)|\($0.neglectDays)|\($0.currentMinutes)|\($0.escalLevel)" }, expected, "pickable \(pid)")
            XCTAssertEqual(Engine.suggestFill(pickedIds: [], pool: pick), any["fillEmpty"] as! [String], "fillEmpty \(pid)")
            XCTAssertEqual(Engine.suggestFill(pickedIds: ["wipe-counters"], pool: pick), any["fillKitchen"] as! [String], "fillKitchen \(pid)")

            let mins = Dictionary(uniqueKeysWithValues: Engine.minutesByDay(playerId: pid, logs: logs, pool: Self.poolMap, calendar: cal).map { (fmt.string(from: $0.key), $0.value) })
            XCTAssertEqual(mins, any["minutes"] as! [String: Int], "minutes \(pid)")
        }
    }
}
