import XCTest
@testable import DoYourWorkCore

final class FamilyStateTests: XCTestCase {
    let chore = Chore(id: "make-bed", name: "make bed", cat: "bedroom", pts: 8, tiers: [5, 8], tierDays: [0, 4])
    let t = Date(timeIntervalSince1970: 1_794_000_000.123)

    func testRoundTrip() {
        let code = AdminCode("2468", salt: "s1")!
        let family = FamilyState.Family(
            members: [Player(id: "2", name: "kid", displayName: "Kiddo"),
                      Player(id: "1", name: "mom", isAdmin: true, plays: false)],
            chores: [chore], codes: ["1": code], removed: ["3"],
            choreAdded: ["make-bed": t], memberJoined: ["2": t], nextPlayerId: 4)
        let state = FamilyState.encode(family)
        XCTAssertEqual(state["players"], ["2:kid"])
        XCTAssertEqual(state["staff"], ["1:mom"])
        XCTAssertEqual(state["admins"], ["1"])
        XCTAssertEqual(state["admin_code|1"], ["s1:\(code.hash)"])
        XCTAssertEqual(state["admin_code|2"], [])
        XCTAssertEqual(state["removed_players"], ["3"])
        XCTAssertEqual(state["display|2"], ["Kiddo"])
        XCTAssertEqual(state["display|3"], [])
        XCTAssertEqual(state["chore_added"], ["make-bed:1794000000123"])
        XCTAssertEqual(state["member_joined"], ["2:1794000000123"])
        XCTAssertEqual(state["next_player_id"], ["4"])
        let back = FamilyState.decode(state)
        XCTAssertEqual(back.members, family.members)
        XCTAssertEqual(back.chores, family.chores)
        XCTAssertEqual(back.codes, family.codes)
        XCTAssertEqual(back.nextPlayerId, 4)
        XCTAssertEqual(back.choreAdded["make-bed"]!.timeIntervalSince1970, t.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertTrue(back.isSetUp)
        XCTAssertTrue(back.codes["1"]!.matches(" 2468 "))
    }

    /// What the first synced versions wrote: players and display names only. Not set up yet, so
    /// the family build runs setup, which merges into these players by username.
    func testOldFamilyState() {
        let f = FamilyState.decode(["players": ["1:bekindhearted", "2:megadinolava", "3:gone"],
                                    "removed_players": ["3"], "display|2": ["Dino"]])
        XCTAssertEqual(f.members.map(\.name), ["bekindhearted", "megadinolava"])
        XCTAssertEqual(f.members[1].shownName, "Dino")
        XCTAssertTrue(f.members.allSatisfy { $0.plays && !$0.isAdmin })
        XCTAssertFalse(f.isSetUp)
        XCTAssertNil(f.chores)
        XCTAssertNil(f.nextPlayerId)
    }

    func testBadItemsAreSkipped() {
        let f = FamilyState.decode(["players": ["nocolon", "1:a", "1:dupe"], "admins": ["1"], "admin_code|1": ["nohash"],
                                    "chores": ["{oops"], "next_player_id": ["x"], "chore_added": ["bad", "a:1"]])
        XCTAssertEqual(f.members.map(\.name), ["a"])
        XCTAssertTrue(f.members[0].isAdmin)
        XCTAssertTrue(f.codes.isEmpty)
        XCTAssertNil(f.chores)
        XCTAssertNil(f.nextPlayerId)
        XCTAssertEqual(f.choreAdded.count, 1)
    }

    func testChoreJSONMatchesStarterFormat() {
        let item = FamilyState.encode(.init(members: [], chores: [chore]))["chores"]![0]
        XCTAssertEqual(item, #"{"cat":"bedroom","id":"make-bed","name":"make bed","pts":8,"tierDays":[0,4],"tiers":[5,8]}"#)
    }

    func testDares() {
        let d = FamilyState.dares(["dare|1|2026-11-14": ["2:make-bed"], "players": ["1:a"]])
        XCTAssertEqual(d, [Dare(from: "1", target: "2", choreId: "make-bed", day: "2026-11-14")])
    }

    func testNextFreeIdNeverReuses() {
        let log = ChoreLog(playerId: "7", playerName: "old", choreId: "x", choreName: "x", points: 1, minutes: nil, status: "approved", timestamp: Date())
        let f = FamilyState.Family(members: [Player(id: "2", name: "a")], removed: ["5"])
        XCTAssertEqual(FamilyState.nextFreeId(f, logs: [log]), 8)
        XCTAssertEqual(FamilyState.nextFreeId(.init(members: [], nextPlayerId: 12), logs: [log]), 12)
    }
}
