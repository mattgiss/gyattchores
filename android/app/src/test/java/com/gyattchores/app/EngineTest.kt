package com.gyattchores.app

import com.gyattchores.app.engine.Engine
import com.gyattchores.app.model.Chore
import com.gyattchores.app.model.ChoreLog
import com.gyattchores.app.model.Dare
import com.gyattchores.app.model.Status
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate
import java.time.ZoneId

class EngineTest {
    private val json = Json { ignoreUnknownKeys = true }
    private val pool: List<Chore> = json.decodeFromString(File("src/main/assets/chores.json").readText())
    private val poolMap = pool.associateBy { it.id }
    private val zone = ZoneId.of("UTC")
    private val day = 86_400_000L

    private fun log(choreId: String, ts: Long, status: String = Status.APPROVED, player: String = "1", minutes: Int? = null): ChoreLog {
        val c = poolMap.getValue(choreId)
        return ChoreLog("x$ts$choreId", null, player, "p$player", choreId, c.name, c.pts, minutes, status, ts)
    }

    @Test fun poolHas27Chores() = assertEquals(27, pool.size)

    @Test fun constants() {
        assertEquals(25, Engine.DAILY_MINUTES)
        assertEquals(20, Engine.FULL_DAY_MINUTES)
        assertEquals(30, Engine.LOG_DAYS)
    }

    @Test fun escalationTiers() {
        val toilet = poolMap.getValue("scrub-toilet") // tiers 5,9,15 at 0,3,7 days
        assertEquals(5 to 0, Engine.enrich(toilet, 0).let { it.currentMinutes to it.escalLevel })
        assertEquals(5 to 0, Engine.enrich(toilet, 2).let { it.currentMinutes to it.escalLevel })
        assertEquals(9 to 1, Engine.enrich(toilet, 3).let { it.currentMinutes to it.escalLevel })
        assertEquals(15 to 2, Engine.enrich(toilet, 7).let { it.currentMinutes to it.escalLevel })
        assertEquals(15 to 2, Engine.enrich(toilet, Engine.NEVER).let { it.currentMinutes to it.escalLevel })
        // All tierDays 0: always the top tier, as in the web app.
        assertEquals(2, Engine.enrich(poolMap.getValue("start-laundry"), 0).escalLevel)
    }

    @Test fun neglectOnlyCountsApproved() {
        val now = 1_000 * day
        val logs = listOf(log("make-bed", now - 3 * day), log("make-bed", now - day, Status.PENDING))
        assertEquals(3, Engine.neglectDays("make-bed", "1", logs, now))
        assertEquals(Engine.NEVER, Engine.neglectDays("make-bed", "2", logs, now))
    }

    @Test fun xpCurve() {
        assertEquals(60, Engine.xpToNext(1)); assertEquals(80, Engine.xpToNext(2))
        assertEquals(1, Engine.rank(59).level); assertEquals(2, Engine.rank(60).level)
        assertEquals(3, Engine.rank(140).level)
        assertEquals("v1.0", Engine.toVersion(1)); assertEquals("v1.9", Engine.toVersion(10)); assertEquals("v2.0", Engine.toVersion(11))
        assertEquals(1.0, Engine.momentumMult(0), 1e-9); assertEquals(2.0, Engine.momentumMult(10), 1e-9); assertEquals(2.0, Engine.momentumMult(50), 1e-9)
    }

    /**
     * Deliberate difference from the web app: its getXP treats days as consecutive only when their
     * midnights are exactly 24h apart, so a streak's multiplier resets across a DST change. Here
     * consecutive calendar days always continue the run.
     */
    @Test fun xpStreakSurvivesDstChange() {
        val denver = ZoneId.of("America/Denver") // DST ended 2026-11-01
        fun noon(d: LocalDate) = d.atTime(12, 0).atZone(denver).toInstant().toEpochMilli()
        val oct31 = noon(LocalDate.of(2026, 10, 31))
        val nov1 = noon(LocalDate.of(2026, 11, 1))
        val logs = listOf(log("make-bed", oct31), log("make-bed", nov1))
        assertEquals(8 + 9, Engine.xp("1", logs, denver)) // day 2 of the run earns 1.1x: round(8.8) = 9
    }

    @Test fun xpDedupesSameChoreSameDay() {
        val t = LocalDate.of(2026, 11, 10).atTime(12, 0).atZone(zone).toInstant().toEpochMilli()
        val logs = listOf(log("make-bed", t), log("make-bed", t + 60_000))
        assertEquals(8, Engine.xp("1", logs, zone))
    }

    @Test fun daresScoreForGuesserAndDoerAfterMidnight() {
        val d10 = LocalDate.of(2026, 11, 10)
        val noon = d10.atTime(12, 0).atZone(zone).toInstant().toEpochMilli()
        val logs = listOf(log("scrub-toilet", noon, player = "2"), log("make-bed", noon, Status.PENDING, player = "2"))
        val dares = listOf(
            Dare("1", "2", "scrub-toilet", "2026-11-10"), // lands
            Dare("3", "2", "scrub-toilet", "2026-11-10"), // lands (second guesser)
            Dare("1", "2", "make-bed", "2026-11-10"),     // not approved, so it doesn't land
        )
        // Same day: hidden and unscored.
        assertEquals(0, Engine.dareXp("1", dares, logs, d10, zone))
        // Next day: guessers get 10 each, the doer gets 5 per person who dared it.
        val d11 = d10.plusDays(1)
        assertEquals(10, Engine.dareXp("1", dares, logs, d11, zone))
        assertEquals(10, Engine.dareXp("3", dares, logs, d11, zone))
        assertEquals(10, Engine.dareXp("2", dares, logs, d11, zone))
    }

    @Test fun dareRules() {
        val three = List(3) { Dare("1", "2", "c$it", "2026-11-10") }
        assertEquals(null, Engine.dareBlocked("1", "2", emptyList(), targetSubmitted = false))
        assertTrue(Engine.dareBlocked("1", "1", emptyList(), false)!!.contains("yourself"))
        assertTrue(Engine.dareBlocked("1", "2", emptyList(), true)!!.contains("locked"))
        assertTrue(Engine.dareBlocked("1", "2", three, false)!!.contains("3"))
    }

    @Test fun weekPointsCountsChoresSinceMondayAndSettledDares() {
        val tue = LocalDate.of(2026, 11, 10) // a Tuesday
        assertEquals(LocalDate.of(2026, 11, 9), Engine.weekStart(tue))
        fun noon(d: LocalDate) = d.atTime(12, 0).atZone(zone).toInstant().toEpochMilli()
        val logs = listOf(log("make-bed", noon(tue.minusDays(2))), log("make-bed", noon(tue.minusDays(1))), log("scrub-toilet", noon(tue)))
        val dares = listOf(Dare("2", "1", "make-bed", "2026-11-09"), Dare("2", "1", "scrub-toilet", "2026-11-10"))
        // Sunday's chore is last week. Monday 8 + Tuesday 20 + doer bonus for Monday's settled dare 5.
        assertEquals(33, Engine.weekPoints("1", logs, dares, tue, zone))
        assertEquals(10, Engine.weekPoints("2", logs, dares, tue, zone))
    }

    @Test fun adminHash() {
        assertEquals(2166136261L, Engine.fnv1a(""))
        assertEquals(0xE40C292CL, Engine.fnv1a("a")) // published FNV-1a 32-bit test vector
        assertFalse(Engine.fnv1a("wrong") == Engine.ADMIN_CODE_HASH)
    }

    @Test fun cellAlpha() {
        assertEquals(0f, Engine.cellAlpha(0)); assertEquals(1f, Engine.cellAlpha(25)); assertEquals(1f, Engine.cellAlpha(40))
        assertEquals(0.30f + 0.70f * 10 / 25, Engine.cellAlpha(10), 1e-6f)
    }

    @Test fun readyRules() {
        val fresh = Engine.pickableChores(pool, "1", emptyList(), 0) // all NEVER: top tiers
        assertFalse(Engine.cardReady(emptyList(), fresh, bonus = false))
        assertTrue(Engine.cardReady(listOf(fresh.first()), fresh, bonus = true))
        val fill = Engine.suggestFill(emptyList(), fresh)
        val chosen = fresh.filter { it.id in fill }
        assertTrue(chosen.sumOf { it.currentMinutes } <= 25)
        assertTrue(Engine.cardReady(chosen, fresh, bonus = false))
    }

    /** Same inputs as the web app's own functions (run in Node), same outputs. */
    @Test fun matchesWebAppGolden() {
        val g = json.parseToJsonElement(File("src/test/resources/golden.json").readText()).jsonObject
        val now = g.getValue("now").jsonPrimitive.long
        val logs = g.getValue("logs").jsonArray.map { e ->
            val o = e.jsonObject
            ChoreLog(
                id = o.getValue("id").jsonPrimitive.content,
                playerId = o.getValue("playerId").jsonPrimitive.content,
                playerName = o.getValue("playerName").jsonPrimitive.content,
                choreId = o.getValue("choreId").jsonPrimitive.content,
                choreName = o.getValue("choreName").jsonPrimitive.content,
                points = o.getValue("points").jsonPrimitive.int,
                minutes = o["minutes"]?.jsonPrimitive?.int,
                status = o.getValue("status").jsonPrimitive.content,
                timestamp = o.getValue("timestamp").jsonPrimitive.long,
            )
        }
        for ((pid, pe) in g.getValue("players").jsonObject) {
            val p = pe.jsonObject
            val xp = Engine.xp(pid, logs, zone)
            assertEquals("xp $pid", p.getValue("xp").jsonPrimitive.int, xp)
            val r = p.getValue("rank").jsonObject
            val rank = Engine.rank(xp)
            assertEquals(r.getValue("level").jsonPrimitive.int, rank.level)
            assertEquals(r.getValue("version").jsonPrimitive.content, rank.version)
            assertEquals(r.getValue("pct").jsonPrimitive.int, rank.pct)
            assertEquals("streak $pid", p.getValue("streak").jsonPrimitive.int, Engine.streak(pid, logs, now, zone))

            val pick = Engine.pickableChores(pool, pid, logs, now)
            val expectedPick = p.getValue("pickable").jsonArray.map { a ->
                a.jsonArray.let { listOf(it[0].jsonPrimitive.content, it[1].jsonPrimitive.content, it[2].jsonPrimitive.content, it[3].jsonPrimitive.content) }
            }
            assertEquals("pickable $pid", expectedPick, pick.map { listOf(it.id, "${it.neglectDays}", "${it.currentMinutes}", "${it.escalLevel}") })

            fun ids(k: String) = p.getValue(k).jsonArray.map { it.jsonPrimitive.content }
            assertEquals("fillEmpty $pid", ids("fillEmpty"), Engine.suggestFill(emptyList(), pick))
            assertEquals("fillKitchen $pid", ids("fillKitchen"), Engine.suggestFill(listOf("wipe-counters"), pick))

            val mins = Engine.minutesByDay(pid, logs, poolMap, zone).mapKeys { it.key.toString() }
            val expectedMins = p.getValue("minutes").jsonObject.mapValues { it.value.jsonPrimitive.int }
            assertEquals("minutes $pid", expectedMins, mins)
        }
    }
}
