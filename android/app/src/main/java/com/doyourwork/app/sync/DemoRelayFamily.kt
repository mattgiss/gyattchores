package com.doyourwork.app.sync

import com.doyourwork.app.engine.AdminCode
import com.doyourwork.app.model.ChoreLog
import com.doyourwork.app.model.Family
import com.doyourwork.app.model.FamilyState
import com.doyourwork.app.model.Player
import com.doyourwork.app.model.Status

/**
 * Debug builds and tests only: another "first phone" on a [MemoryRelay], with a small family on
 * it, so joining can be tried end to end on one device (`--es scanResult seeded`). The family is
 * pat (admin, code 2468, doesn't play), riley and sam, with two chores logged by riley.
 */
object DemoRelayFamily {
    const val ADMIN_CODE = "2468"

    /** Uploads the family through the normal sync passes and returns a join code for it. */
    fun seed(server: MemoryRelay, now: Long = System.currentTimeMillis()): String {
        val first = Relay(FamilyKeys.generate(), MemorySessionStore(), MemoryRelay.CONFIG, http = server)
        first.createHousehold()
        val family = Family(
            members = listOf(Player("1", "pat", isAdmin = true, plays = false), Player("2", "riley"), Player("3", "sam")),
            adminCodes = mapOf("1" to AdminCode.make(ADMIN_CODE)!!),
            memberJoined = mapOf("1" to now, "2" to now, "3" to now),
            nextPlayerId = 4,
        )
        StateSync.run(first, FamilyState.encode(family).mapValues { LocalEntry(it.value, now, dirty = true) })
        LogSync.run(first, listOf(
            ChoreLog("demo-1", null, "2", "riley", "make-bed", "make bed", 8, 5, Status.APPROVED, now - 86_400_000),
            ChoreLog("demo-2", null, "2", "riley", "dishes", "dishes", 10, 10, Status.PENDING, now),
        ))
        return first.makeJoinCode().first.text
    }
}
