import XCTest
@testable import GyattCore

/// Admin codes and the people in a family.
final class FamilyTests: XCTestCase {
    func testAnAdminCodeMatchesOnlyItself() throws {
        let code = try XCTUnwrap(AdminCode("2468"))
        XCTAssertTrue(code.matches("2468"))
        XCTAssertTrue(code.matches(" 2468\n"), "spaces around a code can't be seen when typing it")
        XCTAssertFalse(code.matches("2469"))
        XCTAssertFalse(code.matches(""))
        XCTAssertFalse(code.matches("24 68"))
    }

    func testACodeHasToBeLongEnough() {
        XCTAssertNil(AdminCode("123"))
        XCTAssertNil(AdminCode("   1  "))
        XCTAssertNotNil(AdminCode("1234"))
        XCTAssertFalse(AdminCode.isLongEnough("12 "))
        XCTAssertTrue(AdminCode.isLongEnough("open sesame"))
    }

    func testTheCodeItselfIsNotStored() throws {
        let code = try XCTUnwrap(AdminCode("7391-kiwi"))
        let saved = String(decoding: try JSONEncoder().encode(code), as: UTF8.self)
        XCTAssertFalse(saved.contains("7391"))
        XCTAssertFalse(saved.contains("kiwi"))
        XCTAssertTrue(try JSONDecoder().decode(AdminCode.self, from: Data(saved.utf8)).matches("7391-kiwi"))
    }

    func testTwoAdminsWithTheSameCodeAreStoredDifferently() throws {
        let a = try XCTUnwrap(AdminCode("2468")), b = try XCTUnwrap(AdminCode("2468"))
        XCTAssertNotEqual(a.salt, b.salt)
        XCTAssertTrue(a.matches("2468") && b.matches("2468"))
    }

    func testPlayersSavedByEarlierVersionsStillLoad() throws {
        let old = Data(#"[{"id":"1","name":"riley"},{"id":"2","name":"sam"}]"#.utf8)
        let players = try JSONDecoder().decode([Player].self, from: old)
        XCTAssertEqual(players.map(\.name), ["riley", "sam"])
        XCTAssertTrue(players.allSatisfy { $0.plays && !$0.isAdmin && $0.displayName == nil })
    }

    func testAPlayerRoundTrips() throws {
        let player = Player(id: "3", name: "jo", displayName: "✨ jo ✨", isAdmin: true, plays: false)
        let back = try JSONDecoder().decode(Player.self, from: JSONEncoder().encode(player))
        XCTAssertEqual(back, player)
        XCTAssertEqual(back.shownName, "✨ jo ✨")
        XCTAssertEqual(Player(id: "4", name: "sam", displayName: "   ").shownName, "sam", "a display name with nothing in it falls back to the username")
    }

    func testLogsSavedWithSyncFieldsStillLoad() throws {
        // What an earlier version wrote: extra fields from when logs were synced.
        let old = Data(#"[{"id":"a","remoteId":"77","playerId":"1","playerName":"riley","choreId":"make-bed","choreName":"make bed","points":8,"minutes":3,"status":"approved","timestamp":784111000,"parentPick":false,"statusDirty":true}]"#.utf8)
        let logs = try JSONDecoder().decode([ChoreLog].self, from: old)
        XCTAssertEqual(logs.first?.choreId, "make-bed")
        XCTAssertEqual(logs.first?.status, Status.approved)
    }

    func testANewChoreDoesNotStartOverdue() {
        let now = Date(timeIntervalSince1970: 1_794_411_000)
        func day(_ n: Double) -> Date { now.addingTimeInterval(-n * 86_400) }
        let pool = EngineTests.pool
        func dogPoop(_ since: [String: Date], _ logs: [ChoreLog] = []) -> EnrichedChore {
            Engine.pickableChores(pool: pool, playerId: "1", logs: logs, now: now, knownSince: since).first { $0.id == "dog-poop" }!
        }
        // Tiers 5, 10, 18 at 0, 1 and 3 days.
        XCTAssertEqual(dogPoop([:]).currentMinutes, 18, "with nothing known, never done still means long overdue")
        XCTAssertEqual(dogPoop(["dog-poop": now]).currentMinutes, 5, "added today: starts at its normal time")
        XCTAssertEqual(dogPoop(["dog-poop": now]).escalLevel, 0)
        XCTAssertEqual(dogPoop(["dog-poop": day(1.5)]).currentMinutes, 10, "left for a day, it grows")
        XCTAssertEqual(dogPoop(["dog-poop": day(40)]).currentMinutes, 18)
        XCTAssertEqual(dogPoop(["dog-poop": now.addingTimeInterval(3600)]).neglectDays, 0, "a clock set back can't make it negative")

        // Doing it still counts from when it was done, not from when it was added.
        let done = ChoreLog(playerId: "1", playerName: "p", choreId: "dog-poop", choreName: "pick up dog poop",
                            points: 15, minutes: 5, status: Status.approved, timestamp: day(0.5))
        XCTAssertEqual(dogPoop(["dog-poop": day(40)], [done]).currentMinutes, 5)

        // On day one the whole list is at its normal times, so a full card is easy to build.
        let fresh = Engine.pickableChores(pool: pool, playerId: "1", logs: [], now: now,
                                          knownSince: Dictionary(uniqueKeysWithValues: pool.map { ($0.id, now) }))
        XCTAssertTrue(fresh.allSatisfy { $0.currentMinutes == $0.chore.tiers[0] })
        XCTAssertEqual(fresh.map(\.currentMinutes), fresh.map(\.currentMinutes).sorted(), "all equally fresh: shortest first")
    }
}
