package com.doyourwork.app.engine

import com.doyourwork.app.model.Chore
import kotlin.math.floor

/**
 * Turns what someone typed or said about their household — "we need to do the dishes, take out
 * the trash and someone has to feed the dog for 5 minutes" — into a list of chores.
 *
 * Plain word-sorting on the device, a line-for-line port of iOS's `ChoreIntake` so both apps sort
 * the same text into the same chores. It won't get everything right and doesn't need to: the
 * result is shown as a list to tick, rename and re-time before anything is added.
 */
object ChoreIntake {
    const val MAX_NAME_LENGTH = 40
    const val MAX_CHORES_PER_PASS = 60
    /** A chore has to fit on a day's card. */
    val minuteRange = 1..Engine.DAILY_MINUTES

    data class Found(val name: String, val minutes: Int?)

    /** The chores found in [text], leaving out any already on the list (matched by name). */
    fun parse(text: String, existing: List<Chore> = emptyList()): List<Chore> {
        val names = existing.map { key(it.name) }.toMutableSet()
        val ids = existing.map { it.id }.toMutableSet()
        val out = ArrayList<Chore>()
        for (found in split(text)) {
            if (out.size >= MAX_CHORES_PER_PASS) break
            if (!names.add(key(found.name))) continue
            val chore = make(found.name, found.minutes ?: guessMinutes(found.name), ids)
            ids += chore.id
            out += chore
        }
        return out
    }

    /**
     * A chore from a name and how long it takes. Left undone, it grows to one and a half times and
     * then twice as long, like the starter chores do, but never past a day's card.
     */
    fun make(name: String, minutes: Int, takenIds: Set<String> = emptySet(), id: String? = null): Chore {
        val m = minutes.coerceIn(minuteRange.first, minuteRange.last)
        val cap = minuteRange.last
        val tiers = listOf(m, minOf(cap, (m * 3 + 1) / 2), minOf(cap, m * 2))
        val clean = tidyName(name) ?: "chore"
        return Chore(id ?: uniqueId(clean, takenIds), clean, category(clean),
            maxOf(5, floor(m * 2.5 + 0.5).toInt()), tiers, listOf(0, 3, 7))
    }

    /** A name as it will be stored: lower case, single spaces, not too long. Null if there's nothing to read. */
    fun tidyName(raw: String): String? {
        val words = raw.lowercase().split(Regex("\\s+")).filter { it.isNotEmpty() }
        var name = ""
        for (word in words) {
            val next = if (name.isEmpty()) word else "$name $word"
            if (next.length > MAX_NAME_LENGTH) break
            name = next
        }
        if (name.isEmpty() && words.isNotEmpty()) name = words.first().take(MAX_NAME_LENGTH)
        return if (name.any { it.isLetter() }) name else null
    }

    /** The pieces of [text] that read as chores, in order, with any time that was mentioned. */
    fun split(text: String): List<Found> {
        val out = ArrayList<Found>()
        val separators = setOf('\n', '\r', ',', ';', '.', '!', '?', '•', '·', '\t', ':')
        // Phones type a curly apostrophe; the word lists below use the plain one.
        val plain = text.lowercase().replace('’', '\'')
        for (piece in plain.split { it in separators }) {
            val words = piece.split(Regex("\\s+")).map(::trimmed).filter { it.isNotEmpty() }
            for (fragment in fragments(words)) {
                val w = fragment.toMutableList()
                val minutes = takeMinutes(w)
                stripEnds(w)
                val name = tidyName(w.joinToString(" ")) ?: continue
                val last = w.lastOrNull() ?: continue
                if (name.length < 3 || name in fillers || last in danglers) continue
                out += Found(name, minutes)
            }
        }
        return out
    }

    /** A first guess at how long a chore takes, from the words in its name. Five minutes if none ring a bell. */
    fun guessMinutes(name: String): Int {
        val n = key(name)
        return minuteGuesses.firstOrNull { n.contains(it.first) }?.second ?: 5
    }

    /** The part of the house a chore belongs to; picking a card tries to mix these. */
    fun category(name: String): String {
        val n = key(name)
        return categories.firstOrNull { (_, words) -> words.any { n.contains(it) } }?.first ?: "other"
    }

    // ─── Splitting ──────────────────────────────────────────────────────────

    private fun String.split(pred: (Char) -> Boolean): List<String> {
        val out = ArrayList<String>()
        val sb = StringBuilder()
        for (c in this) if (pred(c)) { if (sb.isNotEmpty()) { out += sb.toString(); sb.clear() } } else sb.append(c)
        if (sb.isNotEmpty()) out += sb.toString()
        return out
    }

    /** Words that start a new chore wherever they appear. */
    private val breakers = setOf("then", "also", "plus", "next")

    /** Words a chore tends to start with. */
    private val verbs = setOf(
        "take", "wash", "vacuum", "feed", "fold", "wipe", "sweep", "mop", "make", "empty", "unload", "load",
        "walk", "pick", "put", "tidy", "dust", "scrub", "do", "set", "clear", "sort", "mow", "rake", "change",
        "organize", "brush", "cook", "bring", "hang", "rinse", "dry", "clean", "water", "start", "switch",
        "collect", "fill", "check", "get", "pack", "shovel", "weed", "hoover", "refill", "replace", "straighten",
    )

    /** A verb straight after one of these is part of the same chore, so it never starts a new one. */
    private val glue = setOf(
        "a", "an", "the", "of", "to", "and", "or", "up", "out", "away", "my", "your", "our", "their", "his", "her",
        "in", "on", "off", "for", "with", "all", "some", "any", "down", "back", "&",
    )

    /** Below this many words a fragment is taken as one chore; above it, probably several run together. */
    private const val RUN_ON_LENGTH = 7

    private fun fragments(words: List<String>): List<List<String>> {
        val out = ArrayList<List<String>>()
        var current = ArrayList<String>()
        fun cut() { if (current.isNotEmpty()) { out += current; current = ArrayList() } }
        val runOn = words.size >= RUN_ON_LENGTH
        for ((i, word) in words.withIndex()) {
            if (word in breakers) { cut(); continue }
            val nextIsVerb = i + 1 < words.size && words[i + 1] in verbs
            if (word == "and" && nextIsVerb && current.size >= 2) { cut(); continue }
            if (runOn && word in verbs && current.size >= 2 && current.last() !in glue) cut()
            current += word
        }
        cut()
        return out
    }

    // ─── Minutes ────────────────────────────────────────────────────────────

    private val numberWords = mapOf(
        "one" to 1, "two" to 2, "three" to 3, "four" to 4, "five" to 5, "six" to 6, "seven" to 7, "eight" to 8,
        "nine" to 9, "ten" to 10, "twelve" to 12, "fifteen" to 15, "twenty" to 20, "thirty" to 30, "a" to 1, "an" to 1,
    )
    private val minuteUnits = setOf("min", "mins", "minute", "minutes")
    private val hourUnits = setOf("hour", "hours", "hr", "hrs")
    private val timeLeadIns = setOf("for", "takes", "take", "about", "around", "roughly", "is", "it", "that", "which", "like", "each")

    /** Finds "10 minutes", "ten min", "10m", "half an hour" in [words], removes it, and returns the minutes. */
    private fun takeMinutes(words: MutableList<String>): Int? {
        var lo = -1; var hi = -1; var minutes = 0
        for ((i, word) in words.withIndex()) {
            val unit = listOf("minutes", "minute", "mins", "min", "m").firstOrNull { word.endsWith(it) }
            if (unit != null) {
                val head = word.dropLast(unit.length)
                val n = head.toIntOrNull()
                if (n != null && head.isNotEmpty()) { lo = i; hi = i + 1; minutes = n; break }
            }
            if (i + 1 >= words.size) continue
            val n = word.toIntOrNull() ?: numberWords[word] ?: continue
            if (words[i + 1] in minuteUnits) { lo = i; hi = i + 2; minutes = n; break }
            if (words[i + 1] in hourUnits) {
                val half = i > 0 && words[i - 1] == "half"
                lo = if (half) i - 1 else i; hi = i + 2; minutes = if (half) 30 else n * 60; break
            }
        }
        if (lo < 0) return null
        while (lo > 0 && words[lo - 1] in timeLeadIns) lo--
        repeat(hi - lo) { words.removeAt(lo) }
        return minutes.coerceIn(minuteRange.first, minuteRange.last)
    }

    // ─── Trimming ───────────────────────────────────────────────────────────

    private fun phrases(vararg p: String) = p.map { it.split(" ") }.sortedByDescending { it.size }

    /** Ways people lead into a chore when talking: dropped from the front, repeatedly. */
    private val leadIns = phrases(
        "the kids need to", "the kids have to", "the kids should", "kids need to", "kids have to",
        "someone needs to", "someone has to", "somebody needs to", "somebody has to", "someone should",
        "we need to", "we have to", "we got to", "we gotta", "we should", "we also", "we always", "we usually",
        "you need to", "you have to", "i need to", "i have to", "they need to", "they have to",
        "there is", "there's", "need to", "needs to", "have to", "has to", "got to", "gotta", "should",
        "please", "and", "also", "then", "or", "um", "uh", "oh", "okay", "ok", "so", "well", "like",
        "first", "second", "third", "finally", "lastly", "to", "we", "i", "-", "*",
    )

    /** How-often words at the end say nothing about what the chore is. */
    private val trailers = phrases(
        "every single day", "every day", "every morning", "every night", "every evening", "every week",
        "each day", "each morning", "each night", "each week", "once a day", "once a week", "twice a week",
        "daily", "weekly", "too", "as well", "and", "or", "then", "also", "to", "etc",
    )

    /** Things said around a list that aren't chores. */
    private val fillers = setOf(
        "that's it", "that's all", "thats it", "thats all", "that is it", "that is all", "and so on", "so on",
        "stuff like that", "things like that", "you know", "let's see", "lets see", "i think", "the end", "done",
        "first", "second", "third", "finally", "lastly", "okay", "yeah", "yes", "and", "the", "well", "then", "also",
        "like", "stuff", "things", "etc", "hmm",
    )

    /** A fragment ending in one of these was introducing the list ("here are our chores:"), not on it. */
    private val danglers = setOf("chores", "are", "is", "include", "includes", "list")

    private fun stripEnds(words: MutableList<String>) {
        var changed = true
        while (changed) {
            changed = false
            while (words.isNotEmpty() && words.first().toIntOrNull() != null) { words.removeAt(0); changed = true }
            while (words.isNotEmpty() && words.last().toIntOrNull() != null) { words.removeAt(words.size - 1); changed = true }
            leadIns.firstOrNull { words.size > it.size && words.subList(0, it.size) == it }?.let { lead ->
                repeat(lead.size) { words.removeAt(0) }; changed = true
            }
            trailers.firstOrNull { words.size > it.size && words.subList(words.size - it.size, words.size) == it }?.let { t ->
                repeat(t.size) { words.removeAt(words.size - 1) }; changed = true
            }
        }
    }

    /** A word without the punctuation stuck to its ends: "(dishes)" → "dishes". Inner marks stay. */
    private fun trimmed(word: String): String {
        var s = 0; var e = word.length
        while (s < e && !word[s].isLetterOrDigit()) s++
        while (e > s && !word[e - 1].isLetterOrDigit()) e--
        return word.substring(s, e)
    }

    // ─── Guesses ────────────────────────────────────────────────────────────

    /** Checked in order, so the more telling word comes first ("mow" before "yard"). */
    private val minuteGuesses = listOf(
        "mow" to 25, "shovel" to 20, "rake" to 20, "weed" to 15, "cook" to 20, "dinner" to 15, "deep clean" to 20,
        "bathroom" to 12, "shower" to 10, "bathtub" to 10, "toilet" to 5, "vacuum" to 10, "hoover" to 10, "mop" to 10,
        "sweep" to 6, "fold" to 10, "laundry" to 5, "dishwasher" to 5, "dishes" to 10, "trash" to 4, "garbage" to 4,
        "recycling" to 4, "bins" to 4, "make bed" to 3, "make my bed" to 3, "make the bed" to 3, "walk" to 15,
        "litter" to 5, "feed" to 3, "water" to 4, "dust" to 8, "wipe" to 4, "windows" to 10, "fridge" to 10,
        "garage" to 20, "car" to 15, "bedroom" to 10, "room" to 10, "toys" to 5, "tidy" to 5, "pick up" to 5,
    )

    private val categories = listOf(
        "kitchen" to listOf("dish", "kitchen", "counter", "stove", "microwave", "cook", "dinner", "fridge", "oven", "pantry", "lunch"),
        "bathroom" to listOf("bath", "toilet", "shower", "mirror", "sink"),
        "laundry" to listOf("laundry", "clothes", "fold", "washer", "dryer", "towel", "sheets"),
        "floors" to listOf("vacuum", "hoover", "sweep", "mop", "floor", "rug", "carpet", "stairs"),
        "outdoor" to listOf("trash", "garbage", "recycling", "bins", "yard", "mow", "garden", "plants", "dog", "walk", "rake",
            "snow", "shovel", "car", "garage", "weed", "mail", "porch", "patio", "lawn"),
        "room" to listOf("bed", "room", "toys", "desk", "closet", "backpack", "books"),
    )

    // ─── Ids ────────────────────────────────────────────────────────────────

    private fun key(name: String) = name.lowercase().split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ")

    /** "take out the trash" → "take-out-the-trash", with a number on the end if that's taken. */
    private fun uniqueId(name: String, taken: Set<String>): String {
        val slug = name.map { if (it.code < 128 && it.isLetterOrDigit()) it else '-' }.joinToString("")
        val root = slug.split('-').filter { it.isNotEmpty() }.joinToString("-").ifEmpty { "chore" }
        if (root !in taken) return root
        var n = 2
        while ("$root-$n" in taken) n++
        return "$root-$n"
    }
}
