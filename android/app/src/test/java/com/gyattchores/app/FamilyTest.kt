package com.gyattchores.app

import com.gyattchores.app.engine.AdminCode
import com.gyattchores.app.engine.ChoreIntake
import com.gyattchores.app.engine.DisplayName
import com.gyattchores.app.engine.Engine
import com.gyattchores.app.model.Chore
import com.gyattchores.app.model.ChoreLog
import com.gyattchores.app.model.Family
import com.gyattchores.app.model.FamilyState
import com.gyattchores.app.model.Player
import com.gyattchores.app.model.Status
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Setup, admin codes, display names, the family's own chores and the shared family rows.
 * The chore-intake and display-name cases are the iOS ones (GyattCoreTests), so both apps agree.
 */
class FamilyTest {
    private val pool: List<Chore> = Json { ignoreUnknownKeys = true }.decodeFromString(File("src/main/assets/chores.json").readText())
    private fun names(text: String) = ChoreIntake.split(text).map { it.name }

    // ─── Admin codes ────────────────────────────────────────────────────────

    @Test fun anAdminCodeMatchesOnlyItself() {
        val code = AdminCode.make("2468")!!
        assertTrue(code.matches("2468"))
        assertTrue(code.matches(" 2468 "))
        assertFalse(code.matches("2469"))
        assertFalse(code.matches(""))
    }

    @Test fun aCodeHasToBeLongEnough() {
        assertNull(AdminCode.make("123"))
        assertNull(AdminCode.make("   1  "))
        assertNotNull(AdminCode.make("1234"))
        assertFalse(AdminCode.isLongEnough("12 "))
        assertTrue(AdminCode.isLongEnough("open sesame"))
    }

    @Test fun twoAdminsWithTheSameCodeAreStoredDifferently() {
        val a = AdminCode.make("2468")!!; val b = AdminCode.make("2468")!!
        assertNotEquals(a.hash, b.hash)
    }

    @Test fun aCodeMadeOnIosOpensAndroid() {
        // Same scheme as iOS: fnv1a over UTF-16 of salt + code, as an unsigned 32-bit number.
        val salt = "6F1C2A4E-0000-4000-8000-000000000001"
        val ios = AdminCode(salt, Engine.fnv1a(salt + "2468"))
        assertTrue(AdminCode.decode(ios.encode())!!.matches("2468"))
        assertTrue(ios.hash in 0..0xFFFFFFFFL)
    }

    // ─── Display names ──────────────────────────────────────────────────────

    @Test fun displayNamesKeepWhatPeopleType() {
        for (n in listOf("Rex", "dino king", "Zoë", "李小龙", "Ольга")) assertEquals(n, DisplayName.clean(n))
        assertEquals("🦖 Rex 👑", DisplayName.clean("🦖 Rex 👑"))
        assertEquals("👨‍👩‍👧", DisplayName.clean("👨‍👩‍👧"))
        assertEquals("👍🏽 ❤️", DisplayName.clean("👍🏽 ❤️"))
        assertEquals("café naïve", DisplayName.clean("café naïve"))
    }

    @Test fun displayNamesAreTidied() {
        assertEquals("Dino King", DisplayName.clean("  Dino \t  King \n"))
        assertEquals("line one line two three", DisplayName.clean("line one\nline two\r\nthree"))
        assertEquals("evil", DisplayName.clean("‮evil‬"))
        assertEquals("abcd", DisplayName.clean("a\u0000b\u0007c​d"))
        for (empty in listOf("", "   ", "\n\t", "​‍", "‮")) assertNull(DisplayName.clean(empty))
        assertEquals(DisplayName.MAX_LENGTH, DisplayName.clean("a".repeat(60))!!.length)
        assertFalse(DisplayName.clean("ab ".repeat(30))!!.endsWith(" "))
        // Zalgo: at most two marks stay on each letter.
        val zalgo = DisplayName.clean("a" + "́".repeat(10) + "b" + "̀".repeat(10))!!
        assertEquals(2 + 2 * 2, zalgo.length)
    }

    @Test fun aPlayerWithoutADisplayNameShowsTheirUsername() {
        assertEquals("riley", Player("1", "riley").shownName)
        assertEquals("Rex", Player("1", "riley", displayName = "Rex").shownName)
        assertEquals("riley", Player("1", "riley", displayName = "​").shownName)
        assertEquals("Rex (riley)", Player("1", "riley", displayName = "Rex").adminLabel)
    }

    @Test fun playersSavedByEarlierVersionsStillLoad() {
        val p = Json { ignoreUnknownKeys = true }.decodeFromString<Player>("""{"id":"1","name":"bekindhearted"}""")
        assertEquals(Player("1", "bekindhearted", null, isAdmin = false, plays = true), p)
    }

    // ─── Chore intake (the iOS cases) ───────────────────────────────────────

    @Test fun aCommaListBecomesOneChoreEach() =
        assertEquals(listOf("dishes", "take out the trash", "vacuum the living room"), names("Dishes, take out the trash, vacuum the living room"))

    @Test fun linesBulletsAndNumbers() =
        assertEquals(listOf("make bed", "feed the cat", "water plants", "sweep porch"), names("1. Make bed\n2) feed the cat\n- water plants\n• Sweep porch"))

    @Test fun spokenSentences() = assertEquals(
        listOf("do the dishes", "take out the trash", "feed the dog", "pick up their toys and books"),
        names("We need to do the dishes and take out the trash. Someone has to feed the dog every morning, and the kids need to pick up their toys and books. That’s it."))

    @Test fun andOnlySplitsBeforeANewChore() {
        assertEquals(listOf("fold and put away laundry"), names("fold and put away laundry"))
        assertEquals(listOf("sweep and mop the kitchen"), names("sweep and mop the kitchen"))
        assertEquals(listOf("wash and dry the dishes", "take out trash"), names("wash and dry the dishes and take out trash"))
    }

    @Test fun speechWithNoPunctuationIsCutAtEachNewVerb() = assertEquals(
        listOf("do the dishes", "take out the trash", "vacuum the living room", "feed the dog"),
        names("do the dishes take out the trash vacuum the living room feed the dog"))

    @Test fun aVerbInsideAChoreDoesNotCutIt() {
        assertEquals(listOf("put away clean clothes"), names("put away clean clothes"))
        assertEquals(listOf("start a load of laundry"), names("start a load of laundry"))
        assertEquals(listOf("do the dishes", "put away clean clothes"), names("we need to do the dishes then also put away clean clothes"))
    }

    @Test fun timesAreReadAndRemoved() {
        val found = ChoreIntake.split("mow the lawn for 20 minutes, dust shelves (5 min), scrub tub takes about ten minutes, walk dog half an hour, wipe table 3m, tidy desk")
        assertEquals(listOf("mow the lawn", "dust shelves", "scrub tub", "walk dog", "wipe table", "tidy desk"), found.map { it.name })
        assertEquals(listOf(20, 5, 10, 25, 3, null), found.map { it.minutes })
    }

    @Test fun thingsThatAreNotChoresAreLeftOut() {
        assertEquals(listOf("dishes"), names("Okay. Here are our chores: dishes, um, 42, !!!, and so on."))
        assertEquals(emptyList<String>(), names(""))
        assertEquals(emptyList<String>(), names("   \n , . "))
    }

    @Test fun parseMakesChoresThatFitTheGame() {
        val chores = ChoreIntake.parse("mow the lawn, Make Bed, take out trash/recycling for 4 minutes, clean bathroom")
        assertEquals(listOf("mow the lawn", "make bed", "take out trash/recycling", "clean bathroom"), chores.map { it.name })
        assertEquals(listOf("mow-the-lawn", "make-bed", "take-out-trash-recycling", "clean-bathroom"), chores.map { it.id })
        assertEquals(listOf(25, 3, 4, 12), chores.map { it.tiers[0] })
        assertEquals(listOf("outdoor", "room", "outdoor", "bathroom"), chores.map { it.cat })
        for (c in chores) {
            assertEquals(listOf(0, 3, 7), c.tierDays)
            assertEquals(c.tiers.sorted(), c.tiers)
            assertTrue(c.tiers.max() <= Engine.DAILY_MINUTES)
            assertTrue(c.pts >= 5)
        }
        val picker = Engine.pickableChores(chores, "1", emptyList(), System.currentTimeMillis())
        assertEquals(chores.size, picker.size)
        assertTrue(Engine.suggestFill(emptyList(), picker).isNotEmpty())
    }

    @Test fun repeatsAndChoresAlreadyOnTheListAreSkipped() {
        val chores = ChoreIntake.parse("Make bed, make  BED, feed the fish, feed the fish, water plants", pool)
        assertEquals(listOf("feed the fish"), chores.map { it.name })
        assertFalse(chores[0].id in pool.map { it.id })
    }

    @Test fun idsStayUnique() {
        val first = ChoreIntake.make("Feed the cat!", 3)
        assertEquals("feed-the-cat", first.id)
        assertEquals("feed-the-cat-2", ChoreIntake.make("feed the cat?", 3, setOf(first.id)).id)
        assertEquals("feed-the-cat-3", ChoreIntake.make("feed the cat", 3, setOf(first.id, "feed-the-cat-2")).id)
        assertEquals("chore", ChoreIntake.make("ゴミ出し", 3).id)
        assertEquals("ゴミ出し", ChoreIntake.make("ゴミ出し", 3).name)
    }

    @Test fun minutesAndNamesAreKeptInBounds() {
        assertEquals(listOf(1, 2, 2), ChoreIntake.make("x", 0).tiers)
        assertEquals(listOf(25, 25, 25), ChoreIntake.make("x", 500).tiers)
        assertEquals(listOf(10, 15, 20), ChoreIntake.make("x", 10).tiers)
        assertEquals(25, ChoreIntake.make("x", 10).pts)
        assertEquals("scrub the very large kitchen floor scrub", ChoreIntake.tidyName("scrub the very large kitchen floor ".repeat(5)))
        assertNull(ChoreIntake.tidyName("  12 !! "))
        val many = "wash a thing, ".repeat(3) + (1..200).joinToString(", ") { "chore number $it thing" }
        assertEquals(ChoreIntake.MAX_CHORES_PER_PASS, ChoreIntake.parse(many).size)
    }

    // ─── Nothing starts overdue (the iOS case) ──────────────────────────────

    @Test fun aNewChoreDoesNotStartOverdue() {
        val now = 1_794_411_000_000L
        fun day(n: Double) = now - (n * 86_400_000).toLong()
        fun dogPoop(since: Map<String, Long>, logs: List<ChoreLog> = emptyList()) =
            Engine.pickableChores(pool, "1", logs, now, since).first { it.id == "dog-poop" }
        assertEquals(18, dogPoop(emptyMap()).currentMinutes)
        assertEquals(5, dogPoop(mapOf("dog-poop" to now)).currentMinutes)
        assertEquals(10, dogPoop(mapOf("dog-poop" to day(1.5))).currentMinutes)
        assertEquals(18, dogPoop(mapOf("dog-poop" to day(40.0))).currentMinutes)
        assertEquals(0, dogPoop(mapOf("dog-poop" to now + 3_600_000)).neglectDays)
        val done = ChoreLog("x", null, "1", "p", "dog-poop", "pick up dog poop", 15, 5, Status.APPROVED, day(0.5))
        assertEquals(5, dogPoop(mapOf("dog-poop" to day(40.0)), listOf(done)).currentMinutes)
    }

    // ─── The family's shared rows ───────────────────────────────────────────

    private val family = Family(
        members = listOf(
            Player("3", "pat", isAdmin = true, plays = false),
            Player("1", "riley", displayName = "Rex 🦖"),
            Player("2", "sam", isAdmin = true),
        ),
        adminCodes = mapOf("3" to AdminCode("s1", 1L), "2" to AdminCode("s2", 2L)),
        chores = listOf(ChoreIntake.make("feed the fish", 3)),
        choreAdded = mapOf("feed-the-fish" to 100L),
        memberJoined = mapOf("1" to 10L, "2" to 20L, "3" to 30L),
        nextPlayerId = 4,
        removed = setOf("9"),
    )

    @Test fun aFamilyRoundTripsThroughTheSharedRows() {
        val rows = FamilyState.encode(family)
        assertEquals(listOf("1:riley", "2:sam"), rows["players"])
        assertEquals(listOf("3:pat"), rows["staff"])
        assertEquals(listOf("3", "2"), rows["admins"])
        assertEquals(listOf("Rex 🦖"), rows["display|1"])
        assertEquals(listOf("s1:1"), rows["admin_code|3"])
        val back = FamilyState.decode(rows, Family())
        assertEquals(family.members.sortedBy { it.id }, back.members.sortedBy { it.id })
        assertEquals(family.adminCodes, back.adminCodes)
        assertEquals(family.chores, back.chores)
        assertEquals(family.choreAdded, back.choreAdded)
        assertEquals(family.memberJoined, back.memberJoined)
        assertEquals(4, back.nextPlayerId)
        assertEquals(setOf("9"), back.removed)
        assertTrue(back.isSetUp)
    }

    @Test fun rowsFromAnOlderPhoneStillDescribeTheFamily() {
        // What Android 0.3.x and iOS 0.1.0 wrote: players and display names, no admins.
        val old = mapOf("players" to listOf("1:bekindhearted", "2:megadinolava"), "display|2" to listOf("Mega"), "removed_players" to listOf("5"))
        val f = FamilyState.decode(old, Family())
        assertEquals(listOf("bekindhearted", "megadinolava"), f.members.map { it.name })
        assertEquals("Mega", f.members[1].shownName)
        assertFalse(f.isSetUp)
        assertNull(f.chores)
        assertEquals(3, f.nextPlayerId)
    }

    @Test fun onlyWhatChangedIsWrittenAndRemovalsAreWrittenAsEmpty() {
        val renamed = family.copy(members = family.members.map { if (it.id == "1") it.copy(displayName = null) else it })
        assertEquals(mapOf("display|1" to emptyList<String>()), FamilyState.changes(family, renamed))
        val without = family.copy(members = family.members.filter { it.id != "2" }, adminCodes = family.adminCodes - "2", removed = family.removed + "2")
        val c = FamilyState.changes(family, without)
        assertEquals(listOf("1:riley"), c["players"])
        assertEquals(listOf("3"), c["admins"])
        assertEquals(emptyList<String>(), c["admin_code|2"])
        assertEquals(listOf("2", "9"), c["removed_players"])
    }

    @Test fun anEmptiedCodeOrDisplayNameIsCleared() {
        val rows = FamilyState.encode(family).toMutableMap()
        rows["display|1"] = emptyList()
        val f = FamilyState.decode(rows, family)
        assertEquals("riley", f.members.first { it.id == "1" }.shownName)
        // Someone who stops being an admin loses their code.
        rows["admins"] = listOf("3")
        assertFalse("2" in FamilyState.decode(rows, family).adminCodes)
    }

    @Test fun idsAreNeverReused() {
        val f = FamilyState.decode(mapOf("players" to listOf("7:x"), "next_player_id" to listOf("3")), Family(nextPlayerId = 5))
        assertEquals(8, f.nextPlayerId)
    }
}
