package com.gyattchores.app

import com.gyattchores.app.engine.PuzzleBoard
import com.gyattchores.app.engine.PuzzlePack
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * The puzzle engine against the level pack in this app's assets and the fixtures made with it by
 * `native/tools/puzzles.mjs`. The iOS engine replays the same fixtures, so the two agree.
 */
class PuzzleTest {
    private val pack = PuzzlePack.parse(File("src/main/assets/puzzles.json").readText())
    private val fixtures = Json.parseToJsonElement(File("../../native/fixtures/puzzle-scenarios.json").readText())
        .jsonObject["levels"]!!.jsonArray.map { it.jsonObject }

    private fun pair(e: kotlinx.serialization.json.JsonElement) = e.jsonArray.let { it[0].jsonPrimitive.int to it[1].jsonPrimitive.int }

    @Test fun assetsMatchTheSharedPack() {
        assertEquals(File("../../native/puzzles.json").readText(), File("src/main/assets/puzzles.json").readText())
    }

    @Test fun packShape() {
        assertEquals(1, pack.version)
        assertEquals(200, pack.levels.size)
        assertEquals(pack.levels.size, fixtures.size)
        pack.levels.forEachIndexed { i, l ->
            assertEquals("level ${i + 1}", l.w * l.h, l.cells.length)
            assertEquals("level ${i + 1} has unmatched colours", l.cells.count { it == 'P' }, l.cells.count { it == 'K' })
            assertFalse(pack.board(i + 1).cleared)
        }
    }

    /** Every level can be cleared: its stored solution plays through to an empty board. */
    @Test fun everySolutionClears() {
        for (f in fixtures) {
            val level = f["level"]!!.jsonPrimitive.int
            var b = pack.board(level)
            for (m in f["solution"]!!.jsonArray) {
                val (a, c) = pair(m)
                b = b.match(a, c) ?: error("level $level: $a,$c should be legal")
            }
            assertTrue("level $level not cleared by its solution", b.cleared)
            assertFalse(b.stuck)
        }
    }

    /** Random play from the generator: the same legal moves at every step, in the same order, and the same ending. */
    @Test fun randomPlayMatchesGenerator() {
        for (f in fixtures) {
            val level = f["level"]!!.jsonPrimitive.int
            val trace = f["trace"]!!.jsonObject
            var b = pack.board(level)
            trace["steps"]!!.jsonArray.forEachIndexed { n, s ->
                val step = s.jsonObject
                val move = pair(step["move"]!!)
                assertEquals("level $level step $n", step["legal"]!!.jsonPrimitive.int, b.moves.size)
                assertTrue("level $level step $n", move in b.moves)
                b = b.match(move.first, move.second)!!
            }
            val cleared = trace["cleared"]!!.jsonPrimitive.boolean
            assertFalse("level $level: trace ended with moves left", b.hasMove)
            assertEquals("level $level", cleared, b.cleared)
            assertEquals("level $level", !cleared, b.stuck)
        }
    }

    @Test fun rules() {
        // P K
        // . #
        // K P
        val b = PuzzleBoard(2, 3, "PK.#KP")
        assertTrue(b.canMatch(0, 1))      // side by side
        assertTrue(b.canMatch(0, 4))      // same column, empty cell between
        assertFalse(b.canMatch(1, 5))     // wall between
        assertFalse(b.canMatch(0, 5))     // diagonal
        assertFalse(b.canMatch(0, 0))
        assertFalse(b.canMatch(0, 2))     // empty cell
        assertFalse(b.canMatch(1, 3))     // wall
        assertEquals(listOf(1, 4), b.targets(0))
        assertNull(b.match(1, 5))
        val after = b.match(4, 0)         // either order
        assertNotNull(after)
        assertEquals(2, after!!.blocksLeft)
        assertEquals(4, b.blocksLeft)     // the original is unchanged
        assertTrue(after.stuck)
        // Same colour never matches.
        assertTrue(PuzzleBoard(2, 1, "PP").stuck)
        // Something in the way, until it's cleared.
        val line = PuzzleBoard(4, 1, "PKPK")
        assertFalse(line.canMatch(0, 3))
        assertTrue(line.match(1, 2)!!.canMatch(0, 3))
    }

    @Test fun levelsPastTheEndReplayTheHardHalf() {
        assertEquals(0, pack.index(0))
        assertEquals(0, pack.index(1))
        assertEquals(199, pack.index(200))
        assertEquals(100, pack.index(201))
        assertEquals(199, pack.index(300))
        assertEquals(100, pack.index(301))
    }
}
