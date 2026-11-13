import XCTest
@testable import GyattCore

/// The puzzle engine against `native/puzzles.json` and the fixtures made with it by
/// `native/tools/puzzles.mjs`. The Android engine replays the same fixtures, so the two agree.
final class PuzzleTests: XCTestCase {
    struct Fixtures: Decodable {
        struct Step: Decodable { let legal: Int; let move: [Int] }
        struct Trace: Decodable { let steps: [Step]; let cleared: Bool }
        struct Level: Decodable { let level: Int; let solution: [[Int]]; let trace: Trace }
        let levels: [Level]
    }

    static let pack = try! PuzzlePack(json: Data(contentsOf: EngineTests.repo.appendingPathComponent("native/puzzles.json")))
    static let fixtures = try! JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: EngineTests.repo.appendingPathComponent("native/fixtures/puzzle-scenarios.json")))

    func testPackShape() {
        XCTAssertEqual(Self.pack.version, 1)
        XCTAssertEqual(Self.pack.levels.count, 200)
        XCTAssertEqual(Self.fixtures.levels.count, Self.pack.levels.count)
        for (i, l) in Self.pack.levels.enumerated() {
            XCTAssertEqual(l.cells.count, l.w * l.h, "level \(i + 1)")
            let b = Self.pack.board(i + 1)
            XCTAssertEqual(b.cells.filter { $0 == .pink }.count, b.cells.filter { $0 == .ink }.count, "level \(i + 1) has unmatched colours")
            XCTAssertFalse(b.cleared)
        }
    }

    /// Every level can be cleared: its stored solution plays through to an empty board.
    func testEverySolutionClears() {
        for f in Self.fixtures.levels {
            var b = Self.pack.board(f.level)
            for m in f.solution {
                XCTAssertTrue(b.match(m[0], m[1]), "level \(f.level): \(m) should be legal")
            }
            XCTAssertTrue(b.cleared, "level \(f.level) not cleared by its solution")
            XCTAssertFalse(b.stuck)
        }
    }

    /// Random play from the web generator: the same legal moves at every step, in the same order,
    /// and the same ending (cleared or stuck).
    func testRandomPlayMatchesGenerator() {
        for f in Self.fixtures.levels {
            var b = Self.pack.board(f.level)
            for (n, step) in f.trace.steps.enumerated() {
                let legal = b.moves
                XCTAssertEqual(legal.count, step.legal, "level \(f.level) step \(n)")
                XCTAssertTrue(legal.contains { $0 == (step.move[0], step.move[1]) }, "level \(f.level) step \(n)")
                XCTAssertTrue(b.match(step.move[0], step.move[1]))
            }
            XCTAssertFalse(b.hasMove, "level \(f.level): trace ended with moves left")
            XCTAssertEqual(b.cleared, f.trace.cleared, "level \(f.level)")
            XCTAssertEqual(b.stuck, !f.trace.cleared, "level \(f.level)")
        }
    }

    func testRules() {
        // P K
        // . #
        // K P
        var b = PuzzleBoard(width: 2, height: 3, cells: "PK.#KP")
        XCTAssertTrue(b.canMatch(0, 1))          // side by side
        XCTAssertTrue(b.canMatch(0, 4))          // same column, empty cell between
        XCTAssertFalse(b.canMatch(1, 5))         // wall between
        XCTAssertFalse(b.canMatch(0, 5))         // diagonal
        XCTAssertFalse(b.canMatch(0, 0))
        XCTAssertFalse(b.canMatch(0, 2))         // empty cell
        XCTAssertFalse(b.canMatch(1, 3))         // wall
        XCTAssertEqual(b.targets(from: 0), [1, 4])
        XCTAssertFalse(b.match(1, 5))
        XCTAssertEqual(b.blocksLeft, 4)
        XCTAssertTrue(b.match(4, 0))             // either order
        XCTAssertEqual(b.blocksLeft, 2)
        XCTAssertFalse(b.canMatch(1, 5))
        XCTAssertTrue(b.stuck)
        // Same colour never matches.
        let same = PuzzleBoard(width: 2, height: 1, cells: "PP")
        XCTAssertFalse(same.canMatch(0, 1))
        XCTAssertTrue(same.stuck)
        // Something in the way, until it's cleared.
        var line = PuzzleBoard(width: 4, height: 1, cells: "PKPK")
        XCTAssertFalse(line.canMatch(0, 3))
        XCTAssertTrue(line.match(1, 2))
        XCTAssertTrue(line.canMatch(0, 3))
    }

    func testLevelsPastTheEndReplayTheHardHalf() {
        let p = Self.pack
        XCTAssertEqual(p.index(for: 0), 0)
        XCTAssertEqual(p.index(for: 1), 0)
        XCTAssertEqual(p.index(for: 200), 199)
        XCTAssertEqual(p.index(for: 201), 100)
        XCTAssertEqual(p.index(for: 300), 199)
        XCTAssertEqual(p.index(for: 301), 100)
    }
}
