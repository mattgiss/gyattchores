package com.doyourwork.app

import com.doyourwork.app.engine.Reminders
import com.doyourwork.app.model.Card
import com.doyourwork.app.model.ChoreLog
import com.doyourwork.app.model.Status
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** The same cases as the iOS core's ReminderTests, so both apps notify alike. */
class ReminderTest {
    @Test fun linesMatchTheSharedList() {
        val shared: List<String> = Json.decodeFromString(File("../../native/reminders.json").readText())
        assertEquals("iOS reads the same list: change native/reminders.json and both apps", shared, Reminders.lines)
    }

    @Test fun aPersonalPhoneWatchesItsOwnerOnly() {
        assertEquals(listOf("2"), Reminders.watched(listOf("1", "2", "3"), "2"))
        assertEquals(listOf("1", "2"), Reminders.watched(listOf("1", "2"), null))
        assertEquals(listOf("1", "2"), Reminders.watched(listOf("1", "2"), "9"))
    }

    private fun log(status: String) = ChoreLog("l", playerId = "1", playerName = "p", choreId = "make-bed", choreName = "make bed",
        points = 8, minutes = 3, status = status, timestamp = System.currentTimeMillis())

    @Test fun pickedMeansACardOrChoresThatStand() {
        val card = Card("2026-11-19", listOf("make-bed"), listOf(3), listOf(false))
        assertFalse(Reminders.hasPicked(null, emptyList()))
        assertTrue(Reminders.hasPicked(card, emptyList()))
        assertTrue(Reminders.hasPicked(null, listOf(log(Status.PENDING))))
        assertFalse(Reminders.hasPicked(null, listOf(log(Status.REJECTED))))
        assertFalse(Reminders.hasPicked(card.copy(submitted = true), listOf(log(Status.REJECTED))))
    }

    @Test fun eveningBody() {
        assertEquals(Reminders.EVENING_GENERIC, Reminders.eveningBody(listOf("Ada"), personal = true))
        assertEquals(Reminders.EVENING_GENERIC, Reminders.eveningBody(emptyList(), personal = false))
        assertEquals("Still to pick: Ada.", Reminders.eveningBody(listOf("Ada"), personal = false))
        assertEquals("Still to pick: Ada, Bo and Cy.", Reminders.eveningBody(listOf("Ada", "Bo", "Cy"), personal = false))
    }
}
