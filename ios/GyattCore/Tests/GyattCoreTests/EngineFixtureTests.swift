import XCTest
@testable import GyattCore

/// Replays scenarios whose answers were produced by the web app's own engine
/// (see tools/native/generate-engine-fixtures.mjs). If one of these fails, the
/// Swift port and index.html disagree about a game rule.
final class EngineFixtureTests: XCTestCase {
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
                     points: points, minutes: minutes,
                     timestamp: Date(timeIntervalSince1970: timestamp / 1000),
                     status: LogStatus(rawValue: status)!)
        }
    }
    struct Expected: Decodable {
        let playerId: String
        let xp: Int
        let streak: Int
        let minutesByDay: [Int]
        let pickable: [Pickable]
        let fills: [Fill]
        let cardFromLogs: [CardEntry]?
    }
    struct Pickable: Decodable, Equatable { let id: String, neglectDays: Int, currentMinutes: Int, escalLevel: Int }
    struct Fill: Decodable { let picked: [String]; let result: [String] }
    struct CardEntry: Decodable, Equatable { let id: String, currentMinutes: Int, pts: Int }

    // MARK: Setup

    static let fixtures: Fixtures = {
        let url = Bundle.module.url(forResource: "engine-fixtures", withExtension: "json", subdirectory: "Fixtures")!
        return try! JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url))
    }()

    var fixtures: Fixtures { Self.fixtures }
    var now: Date { Date(timeIntervalSince1970: fixtures.now / 1000) }
    var engine: Engine {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return Engine(calendar: calendar)
    }

    // MARK: Constants and catalog

    func testConstantsMatchWebApp() {
        XCTAssertEqual(Engine.dailyMinutes, fixtures.dailyMinutes)
        XCTAssertEqual(Engine.logDays, fixtures.logDays)
        XCTAssertEqual(AdminGate.codeHash, fixtures.adminCodeHash)
    }

    func testCatalogMatchesWebApp() {
        XCTAssertEqual(ChoreCatalog.players, fixtures.players)
        XCTAssertEqual(ChoreCatalog.pool, fixtures.chorePool)
    }

    func testAdminHash() {
        for vector in fixtures.hashVectors {
            XCTAssertEqual(AdminGate.hash(vector.input), vector.hash, "hash(\(vector.input.debugDescription))")
        }
    }

    func testVersionsAndLevelCosts() {
        for vector in fixtures.versions {
            XCTAssertEqual(Engine.version(level: vector.level), vector.version)
            XCTAssertEqual(Engine.xpToNext(level: vector.level), vector.xpToNext)
        }
    }

    func testMomentum() {
        for vector in fixtures.momentum {
            XCTAssertEqual(Engine.momentumMult(streak: vector.streak), vector.mult, "streak \(vector.streak)")
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

    func testScenariosExist() {
        XCTAssertGreaterThanOrEqual(fixtures.scenarios.count, 10)
        XCTAssertGreaterThan(fixtures.scenarios.reduce(0) { $0 + $1.logs.count }, 500)
    }

    func testXP() {
        forEachPlayer { scenario, logs, expected, label in
            XCTAssertEqual(engine.xp(playerId: expected.playerId, logs: logs), expected.xp, label)
        }
    }

    func testStreak() {
        forEachPlayer { scenario, logs, expected, label in
            XCTAssertEqual(engine.streak(playerId: expected.playerId, logs: logs, now: now), expected.streak, label)
        }
    }

    func testDailyLogMinutes() {
        forEachPlayer { scenario, logs, expected, label in
            let row = engine.dailyLog(playerId: expected.playerId, logs: logs, now: now)
            XCTAssertEqual(row.days.map(\.minutes), expected.minutesByDay, label)
            XCTAssertEqual(row.hits, expected.minutesByDay.filter { $0 >= 25 }.count, label)
        }
    }

    func testPickableChores() {
        forEachPlayer { scenario, logs, expected, label in
            let pool = engine.pickableChores(playerId: expected.playerId, logs: logs, now: now)
            let got = pool.map { Pickable(id: $0.id, neglectDays: $0.neglectDays, currentMinutes: $0.currentMinutes, escalLevel: $0.escalLevel) }
            XCTAssertEqual(got, expected.pickable, label)
        }
    }

    func testSuggestFill() {
        forEachPlayer { scenario, logs, expected, label in
            let pool = engine.pickableChores(playerId: expected.playerId, logs: logs, now: now)
            for fill in expected.fills {
                XCTAssertEqual(engine.suggestFill(picked: fill.picked, pool: pool), fill.result, "\(label) picked \(fill.picked)")
            }
        }
    }

    func testCardFromLogs() {
        forEachPlayer { scenario, logs, expected, label in
            let card = engine.cardFromLogs(playerId: expected.playerId, logs: logs, now: now)
            let got = card?.chores.map { CardEntry(id: $0.id, currentMinutes: $0.currentMinutes, pts: $0.pts) }
            XCTAssertEqual(got, expected.cardFromLogs, label)
            if let card {
                XCTAssertTrue(card.submitted, label)
                XCTAssertTrue(card.allChecked, label)
            }
        }
    }

    private func forEachPlayer(_ body: (Scenario, [ChoreLog], Expected, String) -> Void) {
        for scenario in fixtures.scenarios {
            let logs = scenario.logs.map(\.log)
            for expected in scenario.players {
                body(scenario, logs, expected, "[\(scenario.name)] player \(expected.playerId)")
            }
        }
    }
}
