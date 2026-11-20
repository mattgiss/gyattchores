import XCTest
@testable import DoYourWorkCore

final class ReminderTests: XCTestCase {
    func testLinesMatchTheSharedList() throws {
        let url = EngineTests.repo.appendingPathComponent("native/reminders.json")
        let shared = try JSONDecoder().decode([String].self, from: Data(contentsOf: url))
        XCTAssertEqual(Reminders.lines, shared, "Android reads the same list: change native/reminders.json and both apps")
    }

    func testAPersonalPhoneWatchesItsOwnerOnly() {
        XCTAssertEqual(Reminders.watched(playerIds: ["1", "2", "3"], me: "2"), ["2"])
        XCTAssertEqual(Reminders.watched(playerIds: ["1", "2"], me: nil), ["1", "2"], "a shared phone watches everyone")
        XCTAssertEqual(Reminders.watched(playerIds: ["1", "2"], me: "9"), ["1", "2"], "an admin who doesn't play watches everyone")
    }

    private func log(_ status: String) -> ChoreLog {
        ChoreLog(playerId: "1", playerName: "p", choreId: "make-bed", choreName: "make bed", points: 8, minutes: 3, status: status, timestamp: Date())
    }

    func testPickedMeansACardOrChoresThatStand() {
        let card = Card(date: "2026-11-19", choreIds: ["make-bed"], minutes: [3], checked: [false])
        XCTAssertFalse(Reminders.hasPicked(card: nil, todaysLogs: []))
        XCTAssertTrue(Reminders.hasPicked(card: card, todaysLogs: []), "picked but not done yet still counts")
        XCTAssertTrue(Reminders.hasPicked(card: nil, todaysLogs: [log(Status.pending)]), "picked on another phone")
        XCTAssertFalse(Reminders.hasPicked(card: nil, todaysLogs: [log(Status.rejected)]), "all rejected: pick again")
        var sent = card; sent.submitted = true
        XCTAssertFalse(Reminders.hasPicked(card: sent, todaysLogs: [log(Status.rejected)]))
    }

    func testEveningBody() {
        XCTAssertEqual(Reminders.eveningBody(stillToPick: ["Ada"], personal: true), Reminders.eveningGeneric)
        XCTAssertEqual(Reminders.eveningBody(stillToPick: [], personal: false), Reminders.eveningGeneric)
        XCTAssertEqual(Reminders.eveningBody(stillToPick: ["Ada"], personal: false), "Still to pick: Ada.")
        XCTAssertEqual(Reminders.eveningBody(stillToPick: ["Ada", "Bo", "Cy"], personal: false), "Still to pick: Ada, Bo and Cy.")
    }
}
