package com.gyattchores.app

import com.gyattchores.app.engine.Engine
import com.gyattchores.app.model.ChoreLog
import com.gyattchores.app.model.Status
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * What a player's day looks like after a parent has had their say: a rejected chore isn't used
 * up, a day where everything was rejected isn't a finished day, and one chore is one person's
 * per day. The same rules, and the same cases, as the iOS app's TodayTests.
 */
class TodayTest {
    private val noon = 1_794_398_400_000L   // 2026-11-11T12:00:00Z

    private fun log(chore: String, status: String, minutesAfterNoon: Int = 0, player: String = "2") =
        ChoreLog("$player-$chore-$status-$minutesAfterNoon", null, player, "player $player", chore, chore, 10, 5, status, noon + minutesAfterNoon * 60_000L)

    private fun standing(logs: List<ChoreLog>) = Engine.standingToday(Engine.statusToday(logs))

    @Test fun nothingLoggedMeansNothingStanding() {
        assertTrue(Engine.statusToday(emptyList()).isEmpty())
        assertTrue(Engine.standingToday(emptyMap()).isEmpty())
    }

    @Test fun eachStatusReadsAsItself() {
        val status = Engine.statusToday(listOf(log("a", Status.PENDING), log("b", Status.APPROVED), log("c", Status.REJECTED)))
        assertEquals(mapOf("a" to Status.PENDING, "b" to Status.APPROVED, "c" to Status.REJECTED), status)
        assertEquals("the rejected chore can be done again", setOf("a", "b"), Engine.standingToday(status))
    }

    /** The reported bug: every chore under a player's name was rejected and they couldn't pick anything. */
    @Test fun aDayWhereEverythingWasRejectedHasNothingStanding() {
        val todays = listOf("make-bed", "dog-poop", "scrub-toilet", "water-plants").map { log(it, Status.REJECTED) }
        assertEquals(setOf(Status.REJECTED), Engine.statusToday(todays).values.toSet())
        assertTrue(standing(todays).isEmpty())
    }

    @Test fun aChoreRedoneAfterARejectionIsAwaitingAgain() {
        val todays = listOf(log("make-bed", Status.REJECTED), log("dog-poop", Status.REJECTED), log("make-bed", Status.PENDING, 30))
        val status = Engine.statusToday(todays)
        assertEquals(Status.PENDING, status["make-bed"])
        assertEquals(Status.REJECTED, status["dog-poop"])
        assertEquals(setOf("make-bed"), Engine.standingToday(status))
        // …in whatever order the rows happen to arrive.
        assertEquals(Status.PENDING, Engine.statusToday(todays.reversed())["make-bed"])
        // Rejected a second time: free again.
        assertTrue(standing(todays.dropLast(1) + log("make-bed", Status.REJECTED, 30)).isEmpty())
    }

    @Test fun approvedAlwaysWins() {
        val todays = listOf(log("make-bed", Status.APPROVED), log("make-bed", Status.REJECTED, 5), log("make-bed", Status.PENDING, 10))
        assertEquals(Status.APPROVED, Engine.statusToday(todays)["make-bed"])
        assertEquals(Status.APPROVED, Engine.statusToday(todays.reversed())["make-bed"])
    }

    @Test fun aSyncDuplicateTakesTheVerdictOverPending() {
        // The same chore twice at the same moment, one row not yet updated.
        val todays = listOf(log("make-bed", Status.PENDING), log("make-bed", Status.REJECTED))
        assertEquals(Status.REJECTED, Engine.statusToday(todays)["make-bed"])
        assertEquals(Status.REJECTED, Engine.statusToday(todays.reversed())["make-bed"])
    }

    // One chore, one person, per day

    @Test fun aChoreSomeoneElseHasInIsTaken() {
        val todays = listOf(log("make-bed", Status.PENDING, player = "1"), log("dog-poop", Status.APPROVED, player = "1"),
            log("scrub-toilet", Status.REJECTED, player = "1"), log("water-plants", Status.PENDING, player = "2"))
        assertEquals("a rejected chore is free for anyone; your own chores aren't taken from you",
            mapOf("make-bed" to "player 1", "dog-poop" to "player 1"), Engine.takenByOthersToday("2", todays))
        assertEquals(mapOf("water-plants" to "player 2"), Engine.takenByOthersToday("1", todays))
        assertTrue(Engine.takenByOthersToday("3", emptyList()).isEmpty())
    }

    @Test fun aChoreFreedByARejectionCanBeTakenBySomeoneElse() {
        val todays = listOf(log("make-bed", Status.REJECTED, player = "1"), log("make-bed", Status.PENDING, 20, player = "2"))
        assertEquals(mapOf("make-bed" to "player 2"), Engine.takenByOthersToday("1", todays))
        assertTrue(Engine.takenByOthersToday("2", todays).isEmpty())
    }

    @Test fun whenTwoPeopleHoldTheSameChoreTheAnswerIsStable() {
        // Possible when two phones submit before they sync: whoever is asked third sees one name, always the same one.
        val todays = listOf(log("make-bed", Status.PENDING, player = "2"), log("make-bed", Status.PENDING, player = "1"))
        assertEquals(mapOf("make-bed" to "player 1"), Engine.takenByOthersToday("3", todays))
        assertEquals(mapOf("make-bed" to "player 1"), Engine.takenByOthersToday("3", todays.reversed()))
    }
}
