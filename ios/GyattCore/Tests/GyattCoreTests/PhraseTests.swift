import XCTest
@testable import GyattCore

/// The same cases as Android's PhraseTest, so both apps say the same thing.
final class PhraseTests: XCTestCase {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/Denver")!; return c }
    private func day(_ d: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: 12))! }

    func testChoresReadAsThingsSomeoneDid() {
        let cases = [
            "empty kids bathroom trash": "emptied the kids bathroom trash",
            "sweep kitchen floor": "swept the kitchen floor",
            "wipe kitchen counters": "wiped the kitchen counters",
            "load dishwasher": "loaded the dishwasher",
            "feed the fish": "fed the fish",
            "take out the trash": "took out the trash",
            "fold and put away laundry": "folded and put away laundry",
            "start a load of laundry": "started a load of laundry",
            "scrub toilet": "scrubbed the toilet",
            "tidy room": "tidied the room",
            "make bed": "made the bed",
            "mop": "mopped",
            "dishes": "did dishes",
            "Vacuum stairs": "Vacuumed the stairs",
        ]
        for (chore, said) in cases { XCTAssertEqual(Phrase.did(chore), said, chore) }
    }

    func testAWholeSentence() {
        XCTAssertEqual(Phrase.sentence("Sam", "empty kids bathroom trash", on: day(14), today: day(14), calendar: cal), "Sam emptied the kids bathroom trash today.")
        XCTAssertEqual(Phrase.sentence("sam", "empty kids bathroom trash", on: day(14), today: day(14), calendar: cal), "Sam emptied the kids bathroom trash today.")
        XCTAssertEqual(Phrase.sentence("Kai", "feed the fish", on: day(13), today: day(14), calendar: cal), "Kai fed the fish yesterday.")
        XCTAssertEqual(Phrase.sentence("Lena", "sweep kitchen floor", on: day(12), today: day(14), calendar: cal), "Lena swept the kitchen floor on Thursday.")
        XCTAssertEqual(Phrase.sentence("Lena", "sweep kitchen floor", on: day(2), today: day(14), calendar: cal), "Lena swept the kitchen floor on Nov 2.")
    }

    func testCounts() {
        XCTAssertEqual(Phrase.count(1, "minute"), "1 minute")
        XCTAssertEqual(Phrase.count(25, "minute"), "25 minutes")
    }
}
