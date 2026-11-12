import XCTest
@testable import GyattCore

/// What a player's day looks like after a parent has had their say: a rejected chore isn't used
/// up, and a day where everything was rejected isn't a finished day.
final class TodayTests: XCTestCase {
    private let noon = Date(timeIntervalSince1970: 1_794_398_400)   // 2026-11-11T12:00:00Z

    private func log(_ chore: String, _ status: String, minutesAfterNoon: Double = 0) -> ChoreLog {
        ChoreLog(playerId: "2", playerName: "megadinolava", choreId: chore, choreName: chore, points: 10, minutes: 5,
                 status: status, timestamp: noon.addingTimeInterval(minutesAfterNoon * 60))
    }

    func testNothingLoggedMeansNothingStanding() {
        XCTAssertTrue(Engine.statusToday([]).isEmpty)
        XCTAssertTrue(Engine.standingToday([:]).isEmpty)
    }

    func testEachStatusReadsAsItself() {
        let status = Engine.statusToday([log("a", Status.pending), log("b", Status.approved), log("c", Status.rejected)])
        XCTAssertEqual(status, ["a": Status.pending, "b": Status.approved, "c": Status.rejected])
        XCTAssertEqual(Engine.standingToday(status), ["a", "b"], "the rejected chore can be done again")
    }

    /// The reported bug: someone submitted cards under a player's name, a parent rejected them all,
    /// and the player was left unable to pick anything. Nothing is standing, so they start over.
    func testADayWhereEverythingWasRejectedHasNothingStanding() {
        let todays = ["make-bed", "dog-poop", "scrub-toilet", "water-plants"].map { log($0, Status.rejected) }
        let status = Engine.statusToday(todays)
        XCTAssertEqual(Set(status.values), [Status.rejected])
        XCTAssertTrue(Engine.standingToday(status).isEmpty)
    }

    func testAChoreRedoneAfterARejectionIsAwaitingAgain() {
        var todays = [log("make-bed", Status.rejected), log("dog-poop", Status.rejected)]
        todays.append(log("make-bed", Status.pending, minutesAfterNoon: 30))
        var status = Engine.statusToday(todays)
        XCTAssertEqual(status["make-bed"], Status.pending)
        XCTAssertEqual(status["dog-poop"], Status.rejected)
        XCTAssertEqual(Engine.standingToday(status), ["make-bed"])

        // …and in whatever order the rows happen to arrive.
        status = Engine.statusToday(todays.reversed())
        XCTAssertEqual(status["make-bed"], Status.pending)

        // Rejected a second time: free again.
        todays[2].status = Status.rejected
        XCTAssertTrue(Engine.standingToday(Engine.statusToday(todays)).isEmpty)
    }

    func testApprovedAlwaysWins() {
        // An approval stands even if a stray later row for the same chore says otherwise.
        let todays = [log("make-bed", Status.approved), log("make-bed", Status.rejected, minutesAfterNoon: 5),
                      log("make-bed", Status.pending, minutesAfterNoon: 10)]
        XCTAssertEqual(Engine.statusToday(todays)["make-bed"], Status.approved)
        XCTAssertEqual(Engine.statusToday(todays.reversed())["make-bed"], Status.approved)
    }

    func testAVerdictBeatsItsOwnSyncDuplicate() {
        // The same submission can exist as two rows with the same time; the parent's verdict on one
        // mustn't be hidden by the untouched twin.
        let twins = [log("make-bed", Status.pending), log("make-bed", Status.rejected)]
        XCTAssertEqual(Engine.statusToday(twins)["make-bed"], Status.rejected)
        XCTAssertEqual(Engine.statusToday(twins.reversed())["make-bed"], Status.rejected)
    }
}
