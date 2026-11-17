package com.gyattchores.app

import com.gyattchores.app.engine.Phrase
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

/** The same cases as iOS's PhraseTests, so both apps say the same thing. */
class PhraseTest {
    private val today = LocalDate.of(2026, 11, 14)

    @Test fun choresReadAsThingsSomeoneDid() {
        val cases = mapOf(
            "empty kids bathroom trash" to "emptied the kids bathroom trash",
            "sweep kitchen floor" to "swept the kitchen floor",
            "wipe kitchen counters" to "wiped the kitchen counters",
            "load dishwasher" to "loaded the dishwasher",
            "feed the fish" to "fed the fish",
            "take out the trash" to "took out the trash",
            "fold and put away laundry" to "folded and put away laundry",
            "start a load of laundry" to "started a load of laundry",
            "scrub toilet" to "scrubbed the toilet",
            "tidy room" to "tidied the room",
            "make bed" to "made the bed",
            "mop" to "mopped",
            "dishes" to "did dishes",
            "Vacuum stairs" to "Vacuumed the stairs",
        )
        for ((chore, said) in cases) assertEquals(chore, said, Phrase.did(chore))
    }

    @Test fun aWholeSentence() {
        assertEquals("Sam emptied the kids bathroom trash today.", Phrase.sentence("Sam", "empty kids bathroom trash", today, today))
        assertEquals("Sam emptied the kids bathroom trash today.", Phrase.sentence("sam", "empty kids bathroom trash", today, today))
        assertEquals("Kai fed the fish yesterday.", Phrase.sentence("Kai", "feed the fish", today.minusDays(1), today))
        assertEquals("Lena swept the kitchen floor on Thursday.", Phrase.sentence("Lena", "sweep kitchen floor", LocalDate.of(2026, 11, 12), today))
        assertEquals("Lena swept the kitchen floor on Nov 2.", Phrase.sentence("Lena", "sweep kitchen floor", LocalDate.of(2026, 11, 2), today))
    }

    @Test fun counts() {
        assertEquals("1 minute", Phrase.count(1, "minute"))
        assertEquals("25 minutes", Phrase.count(25, "minute"))
    }
}
