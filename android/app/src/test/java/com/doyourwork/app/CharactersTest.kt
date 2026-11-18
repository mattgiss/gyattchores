package com.doyourwork.app

import com.doyourwork.app.engine.Characters
import com.doyourwork.app.model.Family
import com.doyourwork.app.model.FamilyState
import com.doyourwork.app.model.Player
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Who gets which character, how the tiles are laid out, and that every drawing can be read. The same cases as iOS's CharacterTests. */
class CharactersTest {
    private fun p(id: String, name: String, character: String? = null) = Player(id, name, character = character)

    @Test fun everyDrawingReadsInFullAndStaysInItsSquare() {
        assertEquals(16, Characters.all.size)
        assertEquals(16, Characters.all.map { it.id }.toSet().size)
        for (c in Characters.all) for (l in c.layers) {
            val steps = Characters.steps(l.path)
            assertTrue("${c.id} starts with a move", steps.first() is Characters.Step.Move)
            assertEquals("${c.id} ends closed", Characters.Step.Close, steps.last())
            assertEquals("${c.id} reads every letter", l.path.count { it in "MLQCZ" }, steps.size)
            val numbers = l.path.split(' ').mapNotNull { it.toFloatOrNull() }
            assertTrue("${c.id} stays in the square", numbers.all { it in 0f..Characters.SIZE })
        }
    }

    @Test fun aPathItCannotReadStopsWhereItWentWrong() {
        assertEquals(listOf(Characters.Step.Move(1f, 2f), Characters.Step.Line(3f, 4f)), Characters.steps("M 1 2 L 3 4 A 5 5 0 0 1 9 9 Z"))
        assertEquals(listOf(Characters.Step.Move(1f, 2f)), Characters.steps("M 1 2 L 3"))
        assertEquals(emptyList<Characters.Step>(), Characters.steps(""))
    }

    @Test fun aPickIsKeptAndEveryoneElseGetsTheirOwn() {
        val got = Characters.assign(listOf(p("1", "sockninja", "ninja"), p("2", "broomrider"), p("3", "dishwizard")))
        assertEquals("ninja", got["1"]?.id)
        assertEquals(3, got.values.map { it.id }.toSet().size)
    }

    /** These three are pinned so iOS and Android give the same character to the same username. */
    @Test fun theCharacterGivenComesFromTheUsername() {
        val got = Characters.assign(listOf(p("1", "sockninja"), p("2", "broomrider"), p("3", "dishwizard"), p("4", "pat"), p("5", "Mia")))
        // A character named in the username is theirs to start with; the rest land where the username's hash says.
        assertEquals(listOf("ninja", "alien", "wizard", "octopus", "monster"), listOf("1", "2", "3", "4", "5").map { got[it]?.id })
        // The order the list arrives in makes no difference.
        assertEquals(got, Characters.assign(listOf(p("5", "Mia"), p("3", "dishwizard"), p("1", "sockninja"), p("4", "pat"), p("2", "broomrider"))))
        // Two with the same namesake: the lower id keeps it, the other is given one the usual way.
        val two = Characters.assign(listOf(p("2", "ninjakid"), p("1", "sockninja")))
        assertEquals("ninja", two["1"]?.id)
        assertTrue(two["2"]?.id != "ninja")
    }

    @Test fun someoneElsesPickBumpsTheGivenOneAlong() {
        val alone = Characters.assign(listOf(p("1", "pat")))["1"]!!
        val got = Characters.assign(listOf(p("1", "pat"), p("2", "broomrider", alone.id)))
        assertEquals(alone.id, got["2"]?.id)
        val next = Characters.all[(Characters.all.indexOf(alone) + 1) % Characters.all.size]
        assertEquals(next.id, got["1"]?.id)
    }

    @Test fun aCharacterThisVersionDoesNotKnowCountsAsNotPicked() {
        val got = Characters.assign(listOf(p("1", "sockninja", "dragon-from-the-future")))
        assertEquals(Characters.assign(listOf(p("1", "sockninja")))["1"], got["1"])
        assertNull(Characters.named("dragon-from-the-future"))
    }

    @Test fun moreplayersThanCharactersShareRatherThanGoWithout() {
        val many = (1..20).map { p("$it", "player$it") }
        val got = Characters.assign(many)
        assertEquals(20, got.size)
        assertEquals(16, got.values.map { it.id }.toSet().size)
    }

    @Test fun tilesFillTheirRowsEvenly() {
        assertEquals(emptyList<Int>(), Characters.tileRows(0, 3))
        assertEquals(listOf(1), Characters.tileRows(1, 3))
        assertEquals(listOf(3), Characters.tileRows(3, 3))
        assertEquals(listOf(2, 2), Characters.tileRows(4, 3))
        assertEquals(listOf(3, 2), Characters.tileRows(5, 3))
        assertEquals(listOf(3, 3), Characters.tileRows(6, 3))
        assertEquals(listOf(3, 2, 2), Characters.tileRows(7, 3))
        assertEquals(listOf(6), Characters.tileRows(6, 6))
        assertEquals(listOf(4, 3), Characters.tileRows(7, 6))
    }

    @Test fun aPickTravelsThroughTheFamilysSharedRows() {
        val family = Family(members = listOf(p("1", "sockninja", "owl"), p("2", "broomrider")))
        val rows = FamilyState.encode(family)
        assertEquals(listOf("owl"), rows["character|1"])
        assertEquals(emptyList<String>(), rows["character|2"])
        assertEquals(family.members, FamilyState.decode(rows, Family()).members)
        // Only the pick is written when that's all that changed.
        val picked = family.copy(members = listOf(p("1", "sockninja", "owl"), p("2", "broomrider", "frog")))
        assertEquals(mapOf("character|2" to listOf("frog")), FamilyState.changes(family, picked))
        // Rows from a phone that has never heard of characters leave a pick already here alone.
        val old = mapOf("players" to listOf("1:sockninja", "2:broomrider"))
        assertEquals("owl", FamilyState.decode(old, family).members[0].character)
        assertTrue(FamilyState.owns("character|1"))
    }
}
