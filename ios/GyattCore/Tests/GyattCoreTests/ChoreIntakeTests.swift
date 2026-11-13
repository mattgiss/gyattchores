import XCTest
@testable import GyattCore

/// Sorting what someone typed or said into a list of chores.
final class ChoreIntakeTests: XCTestCase {
    private func names(_ text: String) -> [String] { ChoreIntake.split(text).map(\.name) }

    func testACommaListBecomesOneChoreEach() {
        XCTAssertEqual(names("Dishes, take out the trash, vacuum the living room"),
                       ["dishes", "take out the trash", "vacuum the living room"])
    }

    func testLinesBulletsAndNumbers() {
        XCTAssertEqual(names("1. Make bed\n2) feed the cat\n- water plants\n• Sweep porch"),
                       ["make bed", "feed the cat", "water plants", "sweep porch"])
    }

    func testSpokenSentences() {
        XCTAssertEqual(
            names("We need to do the dishes and take out the trash. Someone has to feed the dog every morning, and the kids need to pick up their toys and books. That’s it."),
            ["do the dishes", "take out the trash", "feed the dog", "pick up their toys and books"])
    }

    func testAndOnlySplitsBeforeANewChore() {
        XCTAssertEqual(names("fold and put away laundry"), ["fold and put away laundry"])
        XCTAssertEqual(names("sweep and mop the kitchen"), ["sweep and mop the kitchen"])
        XCTAssertEqual(names("wash and dry the dishes and take out trash"), ["wash and dry the dishes", "take out trash"])
    }

    func testSpeechWithNoPunctuationIsCutAtEachNewVerb() {
        XCTAssertEqual(names("do the dishes take out the trash vacuum the living room feed the dog"),
                       ["do the dishes", "take out the trash", "vacuum the living room", "feed the dog"])
    }

    func testAVerbInsideAChoreDoesNotCutIt() {
        XCTAssertEqual(names("put away clean clothes"), ["put away clean clothes"])
        XCTAssertEqual(names("start a load of laundry"), ["start a load of laundry"])
        XCTAssertEqual(names("we need to do the dishes then also put away clean clothes"), ["do the dishes", "put away clean clothes"])
    }

    func testTimesAreReadAndRemoved() {
        let found = ChoreIntake.split("mow the lawn for 20 minutes, dust shelves (5 min), scrub tub takes about ten minutes, walk dog half an hour, wipe table 3m, tidy desk")
        XCTAssertEqual(found.map(\.name), ["mow the lawn", "dust shelves", "scrub tub", "walk dog", "wipe table", "tidy desk"])
        XCTAssertEqual(found.map(\.minutes), [20, 5, 10, 25, 3, nil], "half an hour is capped at a day's card")
    }

    func testThingsThatAreNotChoresAreLeftOut() {
        XCTAssertEqual(names("Okay. Here are our chores: dishes, um, 42, !!!, and so on."), ["dishes"])
        XCTAssertEqual(names(""), [])
        XCTAssertEqual(names("   \n , . "), [])
    }

    func testParseMakesChoresThatFitTheGame() {
        let chores = ChoreIntake.parse("mow the lawn, Make Bed, take out trash/recycling for 4 minutes, clean bathroom")
        XCTAssertEqual(chores.map(\.name), ["mow the lawn", "make bed", "take out trash/recycling", "clean bathroom"])
        XCTAssertEqual(chores.map(\.id), ["mow-the-lawn", "make-bed", "take-out-trash-recycling", "clean-bathroom"])
        XCTAssertEqual(chores.map { $0.tiers[0] }, [25, 3, 4, 12])
        XCTAssertEqual(chores.map(\.cat), ["outdoor", "room", "outdoor", "bathroom"])
        for chore in chores {
            XCTAssertEqual(chore.tiers.count, 3)
            XCTAssertEqual(chore.tierDays, [0, 3, 7])
            XCTAssertEqual(chore.tiers, chore.tiers.sorted(), "left undone, a chore never gets shorter")
            XCTAssertLessThanOrEqual(chore.tiers.max()!, Engine.dailyMinutes, "it always fits on a card")
            XCTAssertGreaterThanOrEqual(chore.pts, 5)
        }
        // Playable straight away: the picker and the card filler accept them.
        let pool = Engine.pickableChores(pool: chores, playerId: "1", logs: [], now: Date())
        XCTAssertEqual(pool.count, chores.count)
        XCTAssertFalse(Engine.suggestFill(pickedIds: [], pool: pool).isEmpty)
    }

    func testRepeatsAndChoresAlreadyOnTheListAreSkipped() {
        let existing = EngineTests.pool
        let chores = ChoreIntake.parse("Make bed, make  BED, feed the fish, feed the fish, water plants", existing: existing)
        XCTAssertEqual(chores.map(\.name), ["feed the fish"])
        XCTAssertFalse(existing.map(\.id).contains(chores[0].id))
    }

    func testIdsStayUnique() {
        let first = ChoreIntake.make(name: "Feed the cat!", minutes: 3)
        XCTAssertEqual(first.id, "feed-the-cat")
        XCTAssertEqual(ChoreIntake.make(name: "feed the cat?", minutes: 3, takenIds: [first.id]).id, "feed-the-cat-2")
        XCTAssertEqual(ChoreIntake.make(name: "feed the cat", minutes: 3, takenIds: [first.id, "feed-the-cat-2"]).id, "feed-the-cat-3")
        // A name with no plain letters still gets an id.
        XCTAssertEqual(ChoreIntake.make(name: "ゴミ出し", minutes: 3).id, "chore")
        XCTAssertEqual(ChoreIntake.make(name: "ゴミ出し", minutes: 3).name, "ゴミ出し")
    }

    func testMinutesAndNamesAreKeptInBounds() {
        XCTAssertEqual(ChoreIntake.make(name: "x", minutes: 0).tiers, [1, 2, 2])
        XCTAssertEqual(ChoreIntake.make(name: "x", minutes: 500).tiers, [25, 25, 25])
        XCTAssertEqual(ChoreIntake.make(name: "x", minutes: 10).tiers, [10, 15, 20])
        XCTAssertEqual(ChoreIntake.make(name: "x", minutes: 10).pts, 25)
        let long = ChoreIntake.tidyName(String(repeating: "scrub the very large kitchen floor ", count: 5))!
        XCTAssertLessThanOrEqual(long.count, ChoreIntake.maxNameLength)
        XCTAssertEqual(long, "scrub the very large kitchen floor scrub")
        XCTAssertNil(ChoreIntake.tidyName("  12 !! "))
        XCTAssertEqual(ChoreIntake.parse(String(repeating: "wash a thing, ", count: 3) + (1...200).map { "chore number \($0) thing" }.joined(separator: ", ")).count,
                       ChoreIntake.maxChoresPerPass)
    }
}
