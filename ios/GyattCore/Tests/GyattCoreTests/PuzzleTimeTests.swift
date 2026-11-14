import XCTest
@testable import GyattCore

final class PuzzleTimeTests: XCTestCase {
    private var cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/Denver")!; return c }()
    private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func testAnHourADay() {
        XCTAssertEqual(PuzzleTime.minutesPerDay, 60)
        let now = at(2026, 11, 14, 15)
        XCTAssertEqual(PuzzleTime.minutesLeft(nil, now: now, calendar: cal), 60)
        let r = PuzzleTime.adding(37 * 60 + 10, to: nil, now: now, calendar: cal)
        XCTAssertEqual(r.day, "2026-11-14")
        XCTAssertEqual(PuzzleTime.minutesLeft(r, now: now, calendar: cal), 23, "22m50s left shows as 23")
        let done = PuzzleTime.adding(9999, to: r, now: now, calendar: cal)
        XCTAssertEqual(done.seconds, 3600, "never more than the hour")
        XCTAssertEqual(PuzzleTime.secondsLeft(done, now: now, calendar: cal), 0)
        XCTAssertEqual(PuzzleTime.minutesLeft(done, now: now, calendar: cal), 0)
        XCTAssertEqual(PuzzleTime.minutesLeft(PuzzleTime(day: "2026-11-14", seconds: 3599), now: now, calendar: cal), 1)
    }

    func testStartsOverAtLocalMidnight() {
        let r = PuzzleTime.adding(3600, to: nil, now: at(2026, 11, 14, 23, 59), calendar: cal)
        XCTAssertEqual(PuzzleTime.minutesLeft(r, now: at(2026, 11, 14, 23, 59), calendar: cal), 0)
        XCTAssertEqual(PuzzleTime.minutesLeft(r, now: at(2026, 11, 15, 0, 1), calendar: cal), 60)
        let next = PuzzleTime.adding(60, to: r, now: at(2026, 11, 15, 0, 1), calendar: cal)
        XCTAssertEqual(next, PuzzleTime(day: "2026-11-15", seconds: 60), "yesterday's time is dropped")
    }

    func testStoredRoundTrip() {
        let r = PuzzleTime(day: "2026-11-14", seconds: 125.5)
        XCTAssertEqual(PuzzleTime(stored: r.stored), r)
        XCTAssertNil(PuzzleTime(stored: nil))
        XCTAssertNil(PuzzleTime(stored: "junk"))
        XCTAssertEqual(PuzzleTime(stored: "2026-11-14|-5")?.seconds, 0)
    }
}
