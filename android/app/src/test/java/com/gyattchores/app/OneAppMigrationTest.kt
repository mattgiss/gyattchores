package com.gyattchores.app

import com.gyattchores.app.engine.AdminCode
import com.gyattchores.app.model.Chore
import com.gyattchores.app.model.Family
import com.gyattchores.app.model.FamilyState
import com.gyattchores.app.model.Player
import com.gyattchores.app.sync.FamilyKeys
import com.gyattchores.app.sync.JoinCode
import com.gyattchores.app.sync.LocalEntry
import com.gyattchores.app.sync.MemoryRelay
import com.gyattchores.app.sync.MemoryRelayVault
import com.gyattchores.app.sync.Relay
import com.gyattchores.app.sync.StateSync
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The first launch of the one-app version on a phone that ran the old on-device ("public")
 * edition. That edition kept the family in family.json only; its shared file (family_state.json)
 * held nothing but dares, or, at worst, family rows left over from something older. The app runs
 * [FamilyState.reseed] at every unlinked launch and before the first "Add a phone"
 * (Store.shareFamilyFromDevice / prepareForNewServer).
 */
class OneAppMigrationTest {
    private val now = 1_800_000_000_000L
    private val code = AdminCode.make("2468")!!
    private val family = Family(
        // Players first, then members who don't play: the order the shared rows keep them in.
        members = listOf(Player("2", "riley", displayName = "Riles"), Player("3", "sam"), Player("1", "pat", isAdmin = true, plays = false)),
        adminCodes = mapOf("1" to code),
        chores = listOf(Chore("make-bed", "make bed", "bedroom", 8, listOf(3, 5, 6), listOf(0, 3, 7))),
        choreAdded = mapOf("make-bed" to 1_700_000_000_000L),
        memberJoined = mapOf("1" to 1_700_000_000_000L, "2" to 1_700_000_000_000L, "3" to 1_700_000_000_000L),
        nextPlayerId = 4,
        removed = setOf("9"),
    )
    /** What a public install had in its shared file: only dares, from a backup it restored or an older build. */
    private val dares = mapOf(
        "dare|2|2026-11-16" to LocalEntry(listOf("3:make-bed"), 500),
        "dare|3|2026-11-15" to LocalEntry(emptyList(), 400),
    )

    private fun decoded(state: Map<String, LocalEntry>) =
        FamilyState.decode(state.filterKeys(FamilyState::owns).mapValues { it.value.items }, Family())

    @Test fun aPublicInstallGetsSharedStateFromItsFamily() {
        val seeded = FamilyState.reseed(dares, family, now)
        // The shared rows now describe exactly the family this phone has.
        assertEquals(family, decoded(seeded))
        // Its dares are untouched, and nothing else was invented.
        for ((k, e) in dares) assertSame(e, seeded[k])
        assertEquals(FamilyState.encode(family).keys + dares.keys, seeded.keys)
        // The new rows go out on the first pass after "Add a phone".
        assertTrue(seeded.filterKeys(FamilyState::owns).values.all { it.dirty && it.updatedAt == now })
    }

    @Test fun aStaleSharedFileNeverOverwritesThePlayers() {
        val stale = dares + mapOf(
            FamilyState.PLAYERS to LocalEntry(listOf("7:ghost", "2:old-riley"), 99_999_999_999_999),
            FamilyState.ADMINS to LocalEntry(listOf("7"), 99_999_999_999_999),
            "${FamilyState.DISPLAY}7" to LocalEntry(listOf("Ghosty"), 5),
            "${FamilyState.ADMIN_CODE}7" to LocalEntry(listOf("salt:1"), 5),
        )
        val seeded = FamilyState.reseed(stale, family, now)
        assertEquals(family, decoded(seeded))
        // A family row nobody here has any more is emptied, so it can't come back from the file.
        assertEquals(LocalEntry(emptyList(), now, dirty = true), seeded["${FamilyState.DISPLAY}7"])
        assertEquals(LocalEntry(emptyList(), now, dirty = true), seeded["${FamilyState.ADMIN_CODE}7"])
    }

    @Test fun aFamilyInstallWhoseRowsAgreeIsLeftAlone() {
        // A family-edition install: the rows came from sync and family.json was decoded from them.
        val synced = FamilyState.encode(family).mapValues { LocalEntry(it.value, 123) } + dares +
            ("restored_backups" to LocalEntry(listOf("b1"), 7))
        val again = FamilyState.reseed(synced, family, now)
        assertEquals(synced, again)
        assertFalse(again.values.any { it.dirty })
    }

    @Test fun runningItTwiceChangesNothingMore() {
        val once = FamilyState.reseed(dares, family, now)
        assertEquals(once, FamilyState.reseed(once, family, now + 1000))
    }

    @Test fun addingAPhoneAfterwardsSendsTheWholeFamilyAndItsDares() {
        val server = MemoryRelay()
        val stale = dares + (FamilyState.PLAYERS to LocalEntry(listOf("7:ghost"), 99_999_999_999_999))
        // Store.prepareForNewServer: reseed, then everything goes out.
        val sent = StateSync.forNewServer(FamilyState.reseed(stale, family, now))
        val a = Relay(FamilyKeys.generate(), MemoryRelayVault().sessions, MemoryRelay.CONFIG, http = server)
        a.createHousehold()
        StateSync.run(a, sent)

        val joinCode = JoinCode.parse(a.makeJoinCode().first.text)
        val b = Relay(joinCode.keys, MemoryRelayVault().sessions, MemoryRelay.CONFIG, http = server)
        assertTrue(b.join(joinCode))
        val onB = StateSync.run(b, emptyMap())
        assertEquals(family, decoded(onB))
        assertEquals(listOf("3:make-bed"), onB["dare|2|2026-11-16"]?.items)
        // And the phone that added it, decoding what came back, still has its own players.
        assertEquals(family.members, decoded(StateSync.run(a, sent.mapValues { it.value.copy(dirty = false) })).members)
    }
}
