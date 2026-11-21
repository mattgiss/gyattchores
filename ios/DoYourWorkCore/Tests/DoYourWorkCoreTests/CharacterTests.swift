import XCTest
@testable import DoYourWorkCore

/// Who gets which character, how the tiles are laid out, and that every drawing can be read.
/// The same cases as Android's CharactersTest.
final class CharacterTests: XCTestCase {
    private func p(_ id: String, _ name: String, _ character: String? = nil) -> Player { Player(id: id, name: name, character: character) }

    func testEveryDrawingReadsInFullAndStaysInItsSquare() {
        XCTAssertEqual(Characters.all.count, 23)
        XCTAssertEqual(Set(Characters.all.map(\.id)).count, 23)
        for c in Characters.all {
            for l in c.layers {
                let steps = Characters.steps(l.path)
                guard case .move = steps.first else { return XCTFail("\(c.id) starts with a move") }
                XCTAssertEqual(steps.last, .close, "\(c.id) ends closed")
                XCTAssertEqual(steps.count, l.path.filter { "MLQCZ".contains($0) }.count, "\(c.id) reads every letter")
                let numbers = l.path.split(separator: " ").compactMap { Double($0) }
                XCTAssertTrue(numbers.allSatisfy { $0 >= 0 && $0 <= Characters.size }, "\(c.id) stays in the square")
            }
        }
    }

    func testAPathItCannotReadStopsWhereItWentWrong() {
        XCTAssertEqual(Characters.steps("M 1 2 L 3 4 A 5 5 0 0 1 9 9 Z"), [.move(1, 2), .line(3, 4)])
        XCTAssertEqual(Characters.steps("M 1 2 L 3"), [.move(1, 2)])
        XCTAssertEqual(Characters.steps(""), [])
    }

    func testAPickIsKeptAndEveryoneElseGetsTheirOwn() {
        let got = Characters.assign([p("1", "sockninja", "ninja"), p("2", "broomrider"), p("3", "dishwizard")])
        XCTAssertEqual(got["1"]?.id, "ninja")
        XCTAssertEqual(Set(got.values.map(\.id)).count, 3)
    }

    /// These are pinned so iOS and Android give the same character to the same username.
    func testTheCharacterGivenComesFromTheUsername() {
        let got = Characters.assign([p("1", "sockninja"), p("2", "broomrider"), p("3", "dishwizard"), p("4", "pat"), p("5", "Mia")])
        // A character named in the username is theirs to start with; the rest land where the username's hash says.
        XCTAssertEqual(["1", "2", "3", "4", "5"].map { got[$0]?.id }, ["ninja", "alien", "wizard", "octopus", "monster"])
        // The order the list arrives in makes no difference.
        XCTAssertEqual(got, Characters.assign([p("5", "Mia"), p("3", "dishwizard"), p("1", "sockninja"), p("4", "pat"), p("2", "broomrider")]))
        // Two with the same namesake: the lower id keeps it, the other is given one the usual way.
        let two = Characters.assign([p("2", "ninjakid"), p("1", "sockninja")])
        XCTAssertEqual(two["1"]?.id, "ninja")
        XCTAssertNotEqual(two["2"]?.id, "ninja")
    }

    func testSomeoneElsesPickBumpsTheGivenOneAlong() throws {
        let alone = try XCTUnwrap(Characters.assign([p("1", "pat")])["1"])
        let got = Characters.assign([p("1", "pat"), p("2", "broomrider", alone.id)])
        XCTAssertEqual(got["2"]?.id, alone.id)
        let i = try XCTUnwrap(Characters.given.firstIndex(of: alone))
        XCTAssertEqual(got["1"]?.id, Characters.given[(i + 1) % Characters.given.count].id)
    }

    func testACharacterThisVersionDoesNotKnowCountsAsNotPicked() {
        let got = Characters.assign([p("1", "sockninja", "dragon-from-the-future")])
        XCTAssertEqual(got["1"], Characters.assign([p("1", "sockninja")])["1"])
        XCTAssertNil(Characters.named("dragon-from-the-future"))
    }

    func testMorePlayersThanCharactersShareRatherThanGoWithout() {
        let got = Characters.assign((1...20).map { p("\($0)", "player\($0)") })
        XCTAssertEqual(got.count, 20)
        XCTAssertEqual(Set(got.values.map(\.id)).count, 16)
    }

    func testTilesFillTheirRowsEvenly() {
        XCTAssertEqual(Characters.tileRows(0, perRow: 3), [])
        XCTAssertEqual(Characters.tileRows(1, perRow: 3), [1])
        XCTAssertEqual(Characters.tileRows(3, perRow: 3), [3])
        XCTAssertEqual(Characters.tileRows(4, perRow: 3), [2, 2])
        XCTAssertEqual(Characters.tileRows(5, perRow: 3), [3, 2])
        XCTAssertEqual(Characters.tileRows(6, perRow: 3), [3, 3])
        XCTAssertEqual(Characters.tileRows(7, perRow: 3), [3, 2, 2])
        XCTAssertEqual(Characters.tileRows(6, perRow: 6), [6])
        XCTAssertEqual(Characters.tileRows(7, perRow: 6), [4, 3])
    }

    func testAPickTravelsThroughTheFamilysSharedRows() {
        let family = FamilyState.Family(members: [p("1", "sockninja", "owl"), p("2", "broomrider")])
        let rows = FamilyState.encode(family)
        XCTAssertEqual(rows["character|1"], ["owl"])
        XCTAssertEqual(rows["character|2"], [])
        XCTAssertEqual(FamilyState.decode(rows).members, family.members)
        // Rows from a phone that has never heard of characters simply have no pick in them.
        XCTAssertNil(FamilyState.decode(["players": ["1:sockninja"]]).members[0].character)
        // Someone taken off the list loses their pick everywhere.
        var gone = family; gone.members.removeFirst(); gone.removed = ["1"]
        XCTAssertEqual(FamilyState.encode(gone)["character|1"], [])
    }

    func testAPickSurvivesABackup() throws {
        let members = [Player(id: "1", name: "pat", isAdmin: true, plays: false), p("2", "sockninja", "owl"), p("3", "broomrider")]
        let json = try JSONEncoder().encode(members)
        XCTAssertEqual(try JSONDecoder().decode([Player].self, from: json), members)
        // A save from before there were characters still reads, with nobody having picked.
        let old = try JSONDecoder().decode([Player].self, from: Data(#"[{"id":"2","name":"sockninja"}]"#.utf8))
        XCTAssertNil(old[0].character)
    }

    /// Characters added after the first sixteen can be picked, but nobody is handed one, so an
    /// update never changes someone's character and older phones still agree.
    func testNewerCharactersArePickedNeverGiven() {
        XCTAssertEqual(Characters.given.map(\.id), Array(Characters.all.prefix(16)).map(\.id))
        let got = Characters.assign([Player(id: "1", name: "ottermom"), Player(id: "2", name: "kid", character: "dragon")])
        XCTAssertEqual(got["2"]?.id, "dragon")
        XCTAssertNotEqual(got["1"]?.id, "otter")
        XCTAssertTrue(Characters.given.contains { $0.id == got["1"]?.id })
    }
}
