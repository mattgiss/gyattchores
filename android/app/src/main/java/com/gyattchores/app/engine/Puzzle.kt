package com.gyattchores.app.engine

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * The puzzle a player unlocks by submitting today's card ("CLEAR THE GRID").
 *
 * The board holds pink and black blocks, and walls on later levels. Tap one block, then a block of
 * the other colour in the same row or column with nothing between them, and both disappear. Clear
 * the board to level up. Blocks stand in each other's way and most can pair with more than one
 * partner, so the order decides whether the board can be cleared.
 *
 * The levels come from `native/puzzles.json` (made by `native/tools/puzzles.mjs`, copied into this
 * app's assets). The iOS engine follows the same rules; both are tested against the same fixtures.
 */
class PuzzleBoard private constructor(val width: Int, val height: Int, private val cells: CharArray) {
    /** [cells] row by row: P pink, K black, # wall, . empty. */
    constructor(width: Int, height: Int, cells: String) : this(width, height, cells.toCharArray()) {
        require(cells.length == width * height) { "puzzle level has the wrong number of cells" }
    }

    val size get() = cells.size
    /** The cells as a string, the same form a level is stored in. */
    val cellString get() = String(cells)
    operator fun get(i: Int): Char = cells[i]
    fun isBlock(i: Int) = cells[i] == PINK || cells[i] == INK
    fun row(i: Int) = i / width
    fun column(i: Int) = i % width

    val blocksLeft get() = cells.indices.count { isBlock(it) }
    val cleared get() = blocksLeft == 0
    /** Blocks remain but no two can be matched: the level has to be restarted. */
    val stuck get() = !cleared && !hasMove

    /** True when the blocks at [a] and [b] can be matched now. */
    fun canMatch(a: Int, b: Int): Boolean {
        if (a == b || a !in cells.indices || b !in cells.indices) return false
        if (!isBlock(a) || !isBlock(b) || cells[a] == cells[b]) return false
        val step = when {
            row(a) == row(b) -> if (b > a) 1 else -1
            column(a) == column(b) -> if (b > a) width else -width
            else -> return false
        }
        var i = a + step
        while (i != b) {
            if (cells[i] != EMPTY) return false
            i += step
        }
        return true
    }

    /** The blocks the block at [a] can be matched with now. */
    fun targets(a: Int): List<Int> = cells.indices.filter { canMatch(a, it) }

    /** Every legal match once, as (smaller index, larger index), in index order. */
    val moves: List<Pair<Int, Int>>
        get() = buildList {
            for (a in cells.indices) if (isBlock(a)) for (b in a + 1 until cells.size) if (canMatch(a, b)) add(a to b)
        }

    val hasMove: Boolean
        get() {
            for (a in cells.indices) if (isBlock(a)) for (b in a + 1 until cells.size) if (canMatch(a, b)) return true
            return false
        }

    /** A copy with both blocks removed, or null if they can't be matched. */
    fun match(a: Int, b: Int): PuzzleBoard? {
        if (!canMatch(a, b)) return null
        val next = cells.copyOf()
        next[a] = EMPTY; next[b] = EMPTY
        return PuzzleBoard(width, height, next)
    }

    override fun equals(other: Any?) = other is PuzzleBoard && other.width == width && other.cells.contentEquals(cells)
    override fun hashCode() = cells.contentHashCode() * 31 + width

    companion object {
        const val EMPTY = '.'
        const val PINK = 'P'
        const val INK = 'K'
        const val WALL = '#'
    }
}

/** The level pack. Levels after the last one replay the harder half, so the level number keeps climbing. */
@Serializable
data class PuzzlePack(val version: Int, val levels: List<Level>) {
    @Serializable
    data class Level(val w: Int, val h: Int, val cells: String)

    /** Which entry of the pack plays as level [number] (1-based). */
    fun index(number: Int): Int {
        val n = maxOf(1, number)
        if (n <= levels.size) return n - 1
        val half = levels.size / 2
        return half + (n - levels.size - 1) % (levels.size - half)
    }

    fun board(number: Int): PuzzleBoard = levels[index(number)].let { PuzzleBoard(it.w, it.h, it.cells) }

    companion object {
        private val json = Json { ignoreUnknownKeys = true }
        fun parse(text: String): PuzzlePack = json.decodeFromString(serializer(), text)
    }
}
