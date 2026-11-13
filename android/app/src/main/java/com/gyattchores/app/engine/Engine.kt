package com.gyattchores.app.engine

import com.gyattchores.app.model.Chore
import com.gyattchores.app.model.ChoreLog
import com.gyattchores.app.model.Dare
import com.gyattchores.app.model.EnrichedChore
import com.gyattchores.app.model.Rank
import com.gyattchores.app.model.Status
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlin.math.floor
import kotlin.math.roundToInt

/**
 * The game rules, ported one-to-one from the web app's `index.html`
 * (CARD ENGINE, XP / RANK / STREAK, DAILY MINUTES LOG). Pure functions:
 * pass `now` and `zone` so tests are deterministic.
 */
object Engine {
    const val DAILY_MINUTES = 25
    /** 20+ minutes picked counts as a full day. */
    const val FULL_DAY_MINUTES = DAILY_MINUTES - 5
    const val LOG_DAYS = 30
    const val NEVER = 999
    private const val DAY_MS = 86_400_000L

    // ─── Card engine ────────────────────────────────────────────────────────

    /** Whole days since this player's most recent approved log of this chore; [NEVER] if never. */
    fun neglectDays(choreId: String, playerId: String, logs: List<ChoreLog>, now: Long): Int {
        val last = logs.filter { it.playerId == playerId && it.choreId == choreId && it.status == Status.APPROVED }
            .maxOfOrNull { it.timestamp } ?: return NEVER
        return floor((now - last).toDouble() / DAY_MS).toInt()
    }

    fun enrich(chore: Chore, days: Int): EnrichedChore {
        var tier = 0
        for (i in chore.tierDays.indices.reversed()) if (days >= chore.tierDays[i]) { tier = i; break }
        return EnrichedChore(chore, days, chore.tiers[tier], tier)
    }

    /** The picker list: most neglected first, then shortest first. */
    fun pickableChores(pool: List<Chore>, playerId: String, logs: List<ChoreLog>, now: Long): List<EnrichedChore> =
        pool.map { enrich(it, neglectDays(it.id, playerId, logs, now)) }
            .sortedWith(compareByDescending<EnrichedChore> { it.neglectDays }.thenBy { it.currentMinutes })

    /**
     * Top a selection up to [cap] minutes: same category as something already picked first,
     * then most neglected, then longest. Returns picked ids followed by the added ones.
     */
    fun suggestFill(pickedIds: List<String>, pool: List<EnrichedChore>, cap: Int = DAILY_MINUTES): List<String> {
        val result = pickedIds.toMutableList()
        val picked = pool.filter { it.id in pickedIds }
        val cats = picked.map { it.cat }.toSet()
        var total = picked.sumOf { it.currentMinutes }
        val candidates = pool.filter { it.id !in pickedIds }.sortedWith(
            compareByDescending<EnrichedChore> { if (it.cat in cats) 1 else 0 }
                .thenByDescending { it.neglectDays }
                .thenByDescending { it.currentMinutes }
        )
        for (c in candidates) {
            if (total + c.currentMinutes <= cap) { result += c.id; total += c.currentMinutes }
        }
        return result
    }

    /**
     * Whether the picker's lock-in button is active. Normal card: at least one chore and either
     * 20+ minutes or nothing else fits. Bonus round: any selection.
     */
    fun cardReady(chosen: List<EnrichedChore>, pool: List<EnrichedChore>, bonus: Boolean): Boolean {
        if (chosen.isEmpty()) return false
        if (bonus) return true
        val total = chosen.sumOf { it.currentMinutes }
        val remaining = DAILY_MINUTES - total
        val ids = chosen.map { it.id }.toSet()
        val minUnpicked = pool.filter { it.id !in ids }.minOfOrNull { it.currentMinutes } ?: Int.MAX_VALUE
        val canAddMore = minUnpicked <= remaining
        return total >= FULL_DAY_MINUTES || !canAddMore
    }

    // ─── XP / rank / streak ─────────────────────────────────────────────────

    fun momentumMult(streak: Int): Double = 1 + minOf(streak, 10) * 0.1

    fun xpToNext(level: Int): Int = 60 + (level - 1) * 20

    fun toVersion(level: Int): String = "v${(level - 1) / 10 + 1}.${(level - 1) % 10}"

    fun dayOf(timestamp: Long, zone: ZoneId): LocalDate = Instant.ofEpochMilli(timestamp).atZone(zone).toLocalDate()

    /**
     * Approved logs for a player, one per chore per local day. A chore can only be done once a day,
     * so extra rows are sync duplicates and must not double-count XP or minutes.
     */
    fun approvedOncePerDay(playerId: String, logs: List<ChoreLog>, zone: ZoneId): List<Pair<LocalDate, ChoreLog>> {
        val seen = HashSet<Pair<LocalDate, String>>()
        val out = ArrayList<Pair<LocalDate, ChoreLog>>()
        // The web app sorts logs newest first before this; keep the same "first seen wins".
        for (l in logs.sortedByDescending { it.timestamp }) {
            if (l.playerId != playerId || l.status != Status.APPROVED) continue
            val day = dayOf(l.timestamp, zone)
            if (seen.add(day to l.choreId)) out += day to l
        }
        return out
    }

    /** Lifetime XP: approved points per day, each day scaled by its running-streak multiplier. Only grows. */
    fun xp(playerId: String, logs: List<ChoreLog>, zone: ZoneId): Int {
        val byDay = sortedMapOf<LocalDate, Int>()
        for ((day, log) in approvedOncePerDay(playerId, logs, zone)) byDay[day] = (byDay[day] ?: 0) + log.points
        var xp = 0
        var run = 0
        var prev: LocalDate? = null
        for ((day, pts) in byDay) {
            run = if (prev != null && prev.plusDays(1) == day) run + 1 else 1
            xp += (pts * momentumMult(run - 1)).roundHalfUp()
            prev = day
        }
        return xp
    }

    fun rank(xp: Int): Rank {
        var level = 1
        var into = xp
        while (into >= xpToNext(level)) { into -= xpToNext(level); level++ }
        val need = xpToNext(level)
        return Rank(level, toVersion(level), toVersion(level + 1), into, need, (into.toDouble() / need * 100).roundHalfUp())
    }

    /** Consecutive days, counting back from today, with at least one approved log. 0 if none today. */
    fun streak(playerId: String, logs: List<ChoreLog>, now: Long, zone: ZoneId): Int {
        val days = logs.filter { it.playerId == playerId && it.status == Status.APPROVED }
            .map { dayOf(it.timestamp, zone) }.toSet()
        var d = dayOf(now, zone)
        var n = 0
        while (n < 365 && d in days) { n++; d = d.minusDays(1) }
        return n
    }

    // ─── Dares ──────────────────────────────────────────────────────────────

    const val MAX_DARES_PER_DAY = 3
    /** What the guesser earns for a dare that lands. */
    const val DARE_GUESSER_POINTS = 10
    /** What the doer earns per person who dared the chore they did. */
    const val DARE_DOER_POINTS = 5

    /** A dare lands when its target has an approved log of that chore on that day. */
    fun dareLanded(d: Dare, logs: List<ChoreLog>, zone: ZoneId): Boolean = logs.any {
        it.playerId == d.target && it.choreId == d.choreId && it.status == Status.APPROVED && dayOf(it.timestamp, zone).toString() == d.day
    }

    /** Dares settle at midnight: only days before [today] are revealed and scored. */
    fun settled(d: Dare, today: LocalDate): Boolean = d.day < today.toString()

    /** Points a player earned from one dare, as guesser and/or doer. 0 unless it landed. */
    fun darePoints(playerId: String, d: Dare, logs: List<ChoreLog>, zone: ZoneId): Int =
        if (!dareLanded(d, logs, zone)) 0
        else (if (d.from == playerId) DARE_GUESSER_POINTS else 0) + (if (d.target == playerId) DARE_DOER_POINTS else 0)

    /** Lifetime XP from settled dares. Flat points on top of chore XP (no streak multiplier). */
    fun dareXp(playerId: String, dares: List<Dare>, logs: List<ChoreLog>, today: LocalDate, zone: ZoneId): Int =
        dares.filter { settled(it, today) && (it.from == playerId || it.target == playerId) }.sumOf { darePoints(playerId, it, logs, zone) }

    /**
     * Why [from] can't add this dare, or null if they can. [mineToday] is every dare [from] has
     * made today; [targetSubmitted] is whether the target already submitted today.
     */
    fun dareBlocked(from: String, target: String, mineToday: List<Dare>, targetSubmitted: Boolean): String? = when {
        from == target -> "you can't dare yourself"
        targetSubmitted -> "locked — they already submitted today"
        mineToday.size >= MAX_DARES_PER_DAY -> "that's all $MAX_DARES_PER_DAY dares for today"
        else -> null
    }

    /** Monday of the week containing [today]. */
    fun weekStart(today: LocalDate): LocalDate = today.minusDays((today.dayOfWeek.value - 1).toLong())

    /** This week's leaderboard score: approved chore points since Monday plus settled dare points. */
    fun weekPoints(playerId: String, logs: List<ChoreLog>, dares: List<Dare>, today: LocalDate, zone: ZoneId): Int {
        val start = weekStart(today)
        val chores = approvedOncePerDay(playerId, logs, zone).filter { it.first >= start }.sumOf { it.second.points }
        val fromDares = dares.filter { settled(it, today) && it.day >= start.toString() }.sumOf { darePoints(playerId, it, logs, zone) }
        return chores + fromDares
    }

    // ─── Daily minutes log ──────────────────────────────────────────────────

    /** Minutes a log contributed: its recorded minutes, else the chore's base tier, else its points. */
    fun choreMinutes(log: ChoreLog, pool: Map<String, Chore>): Int =
        log.minutes ?: pool[log.choreId]?.tiers?.firstOrNull() ?: log.points

    fun minutesByDay(playerId: String, logs: List<ChoreLog>, pool: Map<String, Chore>, zone: ZoneId): Map<LocalDate, Int> {
        val byDay = HashMap<LocalDate, Int>()
        for ((day, log) in approvedOncePerDay(playerId, logs, zone)) byDay[day] = (byDay[day] ?: 0) + choreMinutes(log, pool)
        return byDay
    }

    /** The last [LOG_DAYS] local days, oldest first, today last. */
    fun recentDays(now: Long, zone: ZoneId): List<LocalDate> {
        val today = dayOf(now, zone)
        return (LOG_DAYS - 1 downTo 0).map { today.minusDays(it.toLong()) }
    }

    /** Opacity of a daily-log cell: 0 for none, faded for partial, 1 for a full 25-minute day. */
    fun cellAlpha(mins: Int): Float = when {
        mins <= 0 -> 0f
        mins >= DAILY_MINUTES -> 1f
        else -> 0.30f + (mins.toFloat() / DAILY_MINUTES) * 0.70f
    }

    // ─── Admin gate ─────────────────────────────────────────────────────────

    const val ADMIN_CODE_HASH = 3856382990L

    /** 32-bit FNV-1a over UTF-16 code units, matching the web app's `hashCode`. */
    fun fnv1a(s: String): Long {
        var h = 2166136261L
        for (ch in s) {
            h = h xor ch.code.toLong()
            h = (h * 16777619L) and 0xFFFFFFFFL
        }
        return h
    }

    /** JavaScript's Math.round: halves round up (towards +infinity). */
    private fun Double.roundHalfUp(): Int = floor(this + 0.5).toInt()
}
