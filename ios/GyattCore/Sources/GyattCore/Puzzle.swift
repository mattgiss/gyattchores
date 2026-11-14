import Foundation

/// The puzzle a player unlocks by submitting today's card ("CLEAR THE GRID").
///
/// The board holds pink and black blocks, and walls on later levels. Tap one block, then a block of
/// the other colour in the same row or column with nothing between them, and both disappear. Clear
/// the board to level up. Blocks stand in each other's way and most can pair with more than one
/// partner, so the order decides whether the board can be cleared.
///
/// The levels come from `native/puzzles.json` (made by `native/tools/puzzles.mjs`); the Android
/// engine follows the same rules, and both are tested against the same fixtures.
public struct PuzzleBoard: Equatable, Sendable {
    public enum Cell: Character, Sendable {
        case empty = ".", pink = "P", ink = "K", wall = "#"
        public var isBlock: Bool { self == .pink || self == .ink }
    }

    public let width: Int
    public let height: Int
    public private(set) var cells: [Cell]

    /// `cells` row by row: P pink, K black, # wall, . empty.
    public init(width: Int, height: Int, cells: String) {
        self.width = width
        self.height = height
        self.cells = cells.map { Cell(rawValue: $0) ?? .empty }
        precondition(self.cells.count == width * height, "puzzle level has the wrong number of cells")
    }

    public var blocksLeft: Int { cells.filter(\.isBlock).count }
    public var cleared: Bool { blocksLeft == 0 }
    /// Blocks remain but no two can be matched: the level has to be restarted.
    public var stuck: Bool { !cleared && !hasMove }

    public func row(_ i: Int) -> Int { i / width }
    public func column(_ i: Int) -> Int { i % width }

    /// True when the blocks at `a` and `b` can be matched now.
    public func canMatch(_ a: Int, _ b: Int) -> Bool {
        guard a != b, cells.indices.contains(a), cells.indices.contains(b),
              cells[a].isBlock, cells[b].isBlock, cells[a] != cells[b] else { return false }
        let step: Int
        if row(a) == row(b) { step = b > a ? 1 : -1 }
        else if column(a) == column(b) { step = b > a ? width : -width }
        else { return false }
        var i = a + step
        while i != b {
            if cells[i] != .empty { return false }
            i += step
        }
        return true
    }

    /// The blocks the block at `a` can be matched with now.
    public func targets(from a: Int) -> [Int] { cells.indices.filter { canMatch(a, $0) } }

    /// Every legal match once, as (smaller index, larger index), in index order.
    public var moves: [(Int, Int)] {
        var out: [(Int, Int)] = []
        for a in cells.indices where cells[a].isBlock {
            for b in (a + 1)..<cells.count where canMatch(a, b) { out.append((a, b)) }
        }
        return out
    }

    public var hasMove: Bool {
        for a in cells.indices where cells[a].isBlock {
            for b in (a + 1)..<cells.count where canMatch(a, b) { return true }
        }
        return false
    }

    /// Removes both blocks if they can be matched. Returns whether it did.
    @discardableResult
    public mutating func match(_ a: Int, _ b: Int) -> Bool {
        guard canMatch(a, b) else { return false }
        cells[a] = .empty
        cells[b] = .empty
        return true
    }
}

/// The level pack. Levels after the last one replay the harder half of the pack, so the level
/// number keeps climbing.
public struct PuzzlePack: Decodable, Sendable {
    public struct Level: Decodable, Sendable {
        public let w: Int
        public let h: Int
        public let cells: String
    }

    public let version: Int
    public let levels: [Level]

    public init(json: Data) throws { self = try JSONDecoder().decode(PuzzlePack.self, from: json) }

    /// Which entry of the pack plays as level `number` (1-based).
    public func index(for number: Int) -> Int {
        let n = max(1, number)
        if n <= levels.count { return n - 1 }
        let half = levels.count / 2
        return half + (n - levels.count - 1) % (levels.count - half)
    }

    public func board(_ number: Int) -> PuzzleBoard {
        let l = levels[index(for: number)]
        return PuzzleBoard(width: l.w, height: l.h, cells: l.cells)
    }
}
