import XCTest
@testable import GyattCore

/// Named cases whose answers came from the web app's own engine
/// (`node native/tools/scenarios.mjs` → native/fixtures/engine-scenarios.json).
/// Where `testMatchesWebAppGolden` checks one big random history, these aim at
/// single rules — sync duplicates, midnight boundaries, the minutes fallbacks,
/// escalation tiers — so a failure names the rule that drifted.
final class ScenarioTests: XCTestCase {
    // MARK: Fixture shape

    struct Fixtures: Decodable {
        let now: Double
        let dailyMinutes: Int
        let logDays: Int
        let adminCodeHash: UInt32
        let players: [Player]
        let chorePool: [Chore]
        let hashVectors: [HashVector]
        let versions: [VersionVector]
        let momentum: [MomentumVector]
        let ranks: [RankVector]
        let scenarios: [Scenario]
    }
    struct HashVector: Decodable { let input: String; let hash: UInt32 }
    struct VersionVector: Decodable { let level: Int; let version: String; let xpToNext: Int }
    struct MomentumVector: Decodable { let streak: Int; let mult: Double }
    struct RankVector: Decodable {
        let xp: Int, level: Int, version: String, nextVersion: String, into: Int, need: Int, pct: Int
    }
    struct Scenario: Decodable {
        let name: String
        let logs: [FixtureLog]
        let players: [Expected]
    }
    struct FixtureLog: Decodable {
        let id: String, playerId: String, playerName: String, choreId: String, choreName: String
        let points: Int
        let minutes: Int?
        let timestamp: Double
        let status: String

        var log: ChoreLog {
            ChoreLog(id: id, playerId: playerId, playerName: playerName, choreId: choreId, choreName: choreName,
                     points: points, minutes: minutes, status: status,
                     timestamp: Date(timeIntervalSince1970: timestamp / 1000))
        }
    }
    struct Expected: Decodable {
        let playerId: String
        let xp: Int
        let streak: Int
        /// One entry per day of the 30-day log, oldest first.
        let minutesByDay: [Int]
        let pickable: [Pickable]
        let fills: [Fill]
    }
    struct Pickable: Decodable, Equatable { let id: String, neglectDays: Int, currentMinutes: Int, escalLevel: Int }
    struct Fill: Decodable { let picked: [String]; let result: [String] }

    // MARK: Setup

    static let fixtures: Fixtures = {
        let url = EngineTests.repo.appendingPathComponent("native/fixtures/engine-scenarios.json")
        return try! JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url))
    }()

    var fixtures: Fixtures { Self.fixtures }
    var now: Date { Date(timeIntervalSince1970: fixtures.now / 1000) }
    let cal = EngineTests.utc

    private func forEachPlayer(_ body: ([ChoreLog], Expected, String) -> Void) {
        for scenario in fixtures.scenarios {
            let logs = scenario.logs.map(\.log)
            for expected in scenario.players {
                body(logs, expected, "[\(scenario.name)] player \(expected.playerId)")
            }
        }
    }

    // MARK: Constants and catalog

    func testFixturesAreSubstantial() {
        XCTAssertGreaterThanOrEqual(fixtures.scenarios.count, 10)
        XCTAssertGreaterThan(fixtures.scenarios.reduce(0) { $0 + $1.logs.count }, 500)
    }

    func testConstantsMatchWebApp() {
        XCTAssertEqual(Engine.dailyMinutes, fixtures.dailyMinutes)
        XCTAssertEqual(Engine.logDays, fixtures.logDays)
        XCTAssertEqual(Engine.adminCodeHash, fixtures.adminCodeHash)
    }

    func testChorePoolMatchesWebApp() {
        XCTAssertEqual(EngineTests.pool, fixtures.chorePool, "native/chores.json has drifted from CHORE_POOL in index.html")
    }

    func testAdminHashVectors() {
        for vector in fixtures.hashVectors {
            XCTAssertEqual(Engine.fnv1a(vector.input), vector.hash, "hash(\(vector.input.debugDescription))")
        }
    }

    func testVersionsLevelCostsAndMomentum() {
        for vector in fixtures.versions {
            XCTAssertEqual(Engine.toVersion(vector.level), vector.version)
            XCTAssertEqual(Engine.xpToNext(vector.level), vector.xpToNext)
        }
        for vector in fixtures.momentum {
            XCTAssertEqual(Engine.momentumMult(vector.streak), vector.mult, "streak \(vector.streak)")
        }
    }

    func testRanks() {
        for vector in fixtures.ranks {
            let rank = Engine.rank(xp: vector.xp)
            XCTAssertEqual(rank.level, vector.level, "xp \(vector.xp)")
            XCTAssertEqual(rank.version, vector.version, "xp \(vector.xp)")
            XCTAssertEqual(rank.nextVersion, vector.nextVersion, "xp \(vector.xp)")
            XCTAssertEqual(rank.into, vector.into, "xp \(vector.xp)")
            XCTAssertEqual(rank.need, vector.need, "xp \(vector.xp)")
            XCTAssertEqual(rank.pct, vector.pct, "xp \(vector.xp)")
        }
    }

    // MARK: Scenarios

    func testXP() {
        forEachPlayer { logs, expected, label in
            XCTAssertEqual(Engine.xp(playerId: expected.playerId, logs: logs, calendar: cal), expected.xp, label)
        }
    }

    func testStreak() {
        forEachPlayer { logs, expected, label in
            XCTAssertEqual(Engine.streak(playerId: expected.playerId, logs: logs, now: now, calendar: cal), expected.streak, label)
        }
    }

    func testDailyLogMinutes() {
        let days = Engine.recentDays(now: now, calendar: cal)
        XCTAssertEqual(days.count, fixtures.logDays)
        forEachPlayer { logs, expected, label in
            let byDay = Engine.minutesByDay(playerId: expected.playerId, logs: logs, pool: EngineTests.poolMap, calendar: cal)
            XCTAssertEqual(days.map { byDay[$0] ?? 0 }, expected.minutesByDay, label)
        }
    }

    func testPickableChores() {
        forEachPlayer { logs, expected, label in
            let pool = Engine.pickableChores(pool: EngineTests.pool, playerId: expected.playerId, logs: logs, now: now)
            let got = pool.map { Pickable(id: $0.id, neglectDays: $0.neglectDays, currentMinutes: $0.currentMinutes, escalLevel: $0.escalLevel) }
            XCTAssertEqual(got, expected.pickable, label)
        }
    }

    func testSuggestFill() {
        forEachPlayer { logs, expected, label in
            let pool = Engine.pickableChores(pool: EngineTests.pool, playerId: expected.playerId, logs: logs, now: now)
            for fill in expected.fills {
                XCTAssertEqual(Engine.suggestFill(pickedIds: fill.picked, pool: pool), fill.result, "\(label) picked \(fill.picked)")
            }
        }
    }

    // MARK: Rules the fixtures don't reach

    private func chore(_ id: String, minutes: Int) -> EnrichedChore {
        EnrichedChore(chore: Chore(id: id, name: id, cat: "kitchen", pts: 10, tiers: [minutes], tierDays: [0]),
                      neglectDays: 0, currentMinutes: minutes, escalLevel: 0)
    }

    func testCardReadyAgainstTheBudget() {
        let a = chore("a", minutes: 10), b = chore("b", minutes: 10), c = chore("c", minutes: 5)
        XCTAssertFalse(Engine.cardReady(chosen: [], pool: [a, b, c], bonus: false), "nothing picked")
        XCTAssertFalse(Engine.cardReady(chosen: [a], pool: [a, b, c], bonus: false), "10 minutes with room for more")
        XCTAssertTrue(Engine.cardReady(chosen: [a, b], pool: [a, b, c], bonus: false), "20 minutes is a full day")

        let long = chore("long", minutes: 18)
        XCTAssertTrue(Engine.cardReady(chosen: [long], pool: [long, a], bonus: false), "nothing left fits in 7 minutes")
    }

    func testBonusRoundHasNoCap() {
        let a = chore("a", minutes: 20), b = chore("b", minutes: 20), c = chore("c", minutes: 20)
        XCTAssertTrue(Engine.cardReady(chosen: [a, b], pool: [a, b, c], bonus: true))
        XCTAssertFalse(Engine.cardReady(chosen: [], pool: [a, b, c], bonus: true))
    }

    func testFillNeverExceedsTheBudget() {
        let pool = Engine.pickableChores(pool: EngineTests.pool, playerId: "1", logs: [], now: now)
        let filled = Set(Engine.suggestFill(pickedIds: ["fold-laundry"], pool: pool))
        XCTAssertTrue(filled.contains("fold-laundry"))
        XCTAssertGreaterThan(filled.count, 1)
        XCTAssertLessThanOrEqual(pool.filter { filled.contains($0.id) }.reduce(0) { $0 + $1.currentMinutes }, Engine.dailyMinutes)
    }

    func testApprovalResetsEscalation() {
        func dogPoop(_ logs: [ChoreLog]) -> EnrichedChore {
            Engine.pickableChores(pool: EngineTests.pool, playerId: "1", logs: logs, now: now).first { $0.id == "dog-poop" }!
        }
        XCTAssertEqual(dogPoop([]).currentMinutes, 18, "never done: long overdue")
        XCTAssertEqual(dogPoop([]).escalLevel, 2)

        var log = ChoreLog(playerId: "1", playerName: "p", choreId: "dog-poop", choreName: "pick up dog poop",
                           points: 15, minutes: 18, status: Status.pending, timestamp: now.addingTimeInterval(-3600))
        XCTAssertEqual(dogPoop([log]).currentMinutes, 18, "a pending log doesn't reset anything")
        log.status = Status.approved
        XCTAssertEqual(dogPoop([log]).currentMinutes, 5)
        XCTAssertEqual(dogPoop([log]).escalLevel, 0)
    }

    func testDayBoundaryFollowsTheCalendarTimeZone() {
        // 2026-11-11T02:00:00Z is still Nov 10 in Los Angeles.
        let stamp = Date(timeIntervalSince1970: 1_794_362_400)
        let log = ChoreLog(playerId: "1", playerName: "p", choreId: "make-bed", choreName: "make bed",
                           points: 8, minutes: 3, status: Status.approved, timestamp: stamp)
        var la = Calendar(identifier: .gregorian)
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        XCTAssertEqual(Engine.dayKey(stamp, calendar: cal), "2026-11-11")
        XCTAssertEqual(Engine.dayKey(stamp, calendar: la), "2026-11-10")
        XCTAssertEqual(Engine.streak(playerId: "1", logs: [log], now: now, calendar: cal), 1)
        XCTAssertEqual(Engine.streak(playerId: "1", logs: [log], now: now, calendar: la), 0, "in LA that log belongs to yesterday")
    }
}
