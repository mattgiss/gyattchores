import XCTest
@testable import GyattCore

/// A display name can be anything a kid thinks is funny, as long as it shows on one line and
/// can't wreck the screen around it.
final class DisplayNameTests: XCTestCase {
    func testOrdinaryAndSillyNamesAreKeptAsTyped() {
        for name in ["Dino King", "xX_D1no_K1ng_Xx", "~*<( o_o )>*~", "a:b|c,d;e", "\"quotes\" & 'more'", "¯\\_(ツ)_/¯", "恐竜キング", "ملك"] {
            XCTAssertEqual(DisplayName.clean(name), name)
        }
    }

    func testEmojiAreKeptWhole() {
        XCTAssertEqual(DisplayName.clean("🦖 Rex 👑"), "🦖 Rex 👑")
        XCTAssertEqual(DisplayName.clean("👨‍👩‍👧"), "👨‍👩‍👧", "joined emoji stay one picture")
        XCTAssertEqual(DisplayName.clean("👍🏽 ❤️"), "👍🏽 ❤️", "skin tones and emoji-style hearts survive")
        XCTAssertEqual(DisplayName.clean("👨‍👩‍👧")?.count, 1)
    }

    func testSpacesAndLineBreaksCollapse() {
        XCTAssertEqual(DisplayName.clean("  Dino \t  King \n"), "Dino King")
        XCTAssertEqual(DisplayName.clean("line one\nline two\r\nthree"), "line one line two three")
    }

    func testNothingVisibleMeansNoDisplayName() {
        for empty in ["", "   ", "\n\t", "\u{200B}\u{200D}\u{FEFF}", "\u{202E}"] {
            XCTAssertNil(DisplayName.clean(empty), "\(empty.unicodeScalars.map { String($0.value, radix: 16) })")
        }
    }

    func testInvisibleAndDirectionFlippingCharactersAreRemoved() {
        XCTAssertEqual(DisplayName.clean("\u{202E}evil\u{202C}"), "evil", "no right-to-left override")
        XCTAssertEqual(DisplayName.clean("a\u{0000}b\u{0007}c\u{200B}d"), "abcd")
    }

    func testStackedAccentsAreCapped() {
        let zalgo = "Z" + String(repeating: "\u{0301}\u{0336}\u{035B}", count: 15) + "a" + String(repeating: "\u{0489}", count: 9)
        let cleaned = DisplayName.clean(zalgo)!
        XCTAssertEqual(cleaned.count, 2)
        XCTAssertEqual(cleaned.unicodeScalars.count, 2 + 2 * DisplayName.maxMarksPerCharacter)
        XCTAssertEqual(DisplayName.clean("café naïve"), "café naïve", "ordinary accents are untouched")
        XCTAssertEqual(DisplayName.clean("cafe\u{0301}"), "cafe\u{0301}")
    }

    func testLengthIsCappedInCharactersAPersonWouldCount() {
        XCTAssertEqual(DisplayName.clean(String(repeating: "a", count: 60))?.count, DisplayName.maxLength)
        XCTAssertEqual(DisplayName.clean(String(repeating: "🦖", count: 60))?.count, DisplayName.maxLength)
        XCTAssertEqual(DisplayName.clean(String(repeating: "ab ", count: 30))?.count, DisplayName.maxLength)
        XCTAssertFalse(DisplayName.clean(String(repeating: "ab ", count: 30))!.hasSuffix(" "))
    }

    func testCleaningTwiceChangesNothing() {
        for name in ["  Dino \n King ", "🦖 Rex 👑", "Z\u{0301}\u{0301}\u{0301}\u{0301}", String(repeating: "x y ", count: 20)] {
            let once = DisplayName.clean(name)
            XCTAssertEqual(once.flatMap(DisplayName.clean), once)
        }
    }
}
