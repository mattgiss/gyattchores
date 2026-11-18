package com.doyourwork.app.engine

import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Plain-English sentences about chores, so the app talks like a person: "Sam emptied the kids
 * bathroom trash today." Chore names are written as instructions ("empty kids bathroom trash"),
 * so the first word is put in the past tense. The same rules as iOS's Phrase.swift.
 */
object Phrase {
    private val irregular = mapOf(
        "bring" to "brought", "buy" to "bought", "do" to "did", "feed" to "fed", "get" to "got", "give" to "gave",
        "go" to "went", "hang" to "hung", "lay" to "laid", "leave" to "left", "make" to "made", "put" to "put",
        "read" to "read", "ride" to "rode", "run" to "ran", "set" to "set", "shut" to "shut", "sweep" to "swept",
        "take" to "took", "throw" to "threw", "write" to "wrote", "sit" to "sat", "spin" to "spun", "hide" to "hid",
        "beat" to "beat", "sell" to "sold", "tell" to "told", "find" to "found", "hold" to "held", "keep" to "kept",
        "cut" to "cut", "shake" to "shook", "wring" to "wrung", "split" to "split", "spread" to "spread",
    )
    /** Short verbs that double their last letter: scrub → scrubbed. */
    private val doubles = setOf("scrub", "mop", "wrap", "chop", "prep", "drop", "plan", "stir", "pat", "rub", "tap", "trim", "stop", "dip", "plug", "pop", "tug", "hug", "jog")

    /** "empty" → "emptied", "sweep" → "swept", "wipe" → "wiped", "scrub" → "scrubbed". */
    fun past(verb: String): String {
        val v = verb.lowercase(Locale.ROOT)
        irregular[v]?.let { return keepCase(verb, it) }
        val out = when {
            v in doubles -> v + v.last() + "ed"
            v.endsWith("e") -> v + "d"
            v.length > 1 && v.endsWith("y") && v[v.length - 2] !in "aeiou" -> v.dropLast(1) + "ied"
            else -> v + "ed"
        }
        return keepCase(verb, out)
    }

    private fun keepCase(original: String, word: String) =
        if (original.firstOrNull()?.isUpperCase() == true) word.replaceFirstChar { it.uppercase() } else word

    /** Words that start a chore name but aren't something you do ("trash out", "dishes"). */
    private val notVerbs = setOf("the", "a", "an", "my", "your", "all", "dishes", "laundry", "trash", "bed", "room", "homework")

    /** Words after which "the" would read wrong: "feed the fish" yes, "empty the kids trash" yes, "take out the trash" no. */
    private val noArticleAfter = setOf("out", "up", "down", "off", "away", "in", "on", "over", "around", "the", "a", "an", "my", "your", "his", "her", "their", "our", "all", "some", "every", "and", "or", "with", "to", "for", "at", "from", "into", "of")

    /**
     * What someone did, as the second half of a sentence: "emptied the kids bathroom trash". A name
     * that doesn't start with a verb is said as it is: "did dishes".
     */
    fun did(chore: String): String {
        val words = chore.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }
        if (words.isEmpty()) return "did a chore"
        val first = words[0]
        if (first.lowercase(Locale.ROOT) in notVerbs || !first.all { it.isLetter() || it == '\'' }) return "did ${chore.trim()}"
        val rest = words.drop(1)
        val article = rest.isNotEmpty() && rest[0].lowercase(Locale.ROOT) !in noArticleAfter && !rest[0][0].isDigit()
        return (listOf(past(first)) + (if (article) listOf("the") else emptyList()) + rest).joinToString(" ")
    }

    /** "today", "yesterday", or "on Thursday" within the week, else "on Nov 12". */
    fun whenDone(day: LocalDate, today: LocalDate): String = when (day) {
        today -> "today"
        today.minusDays(1) -> "yesterday"
        else -> if (day.isAfter(today.minusDays(7))) "on " + day.format(DateTimeFormatter.ofPattern("EEEE", Locale.US))
        else "on " + day.format(DateTimeFormatter.ofPattern("MMM d", Locale.US))
    }

    /** "Sam emptied the kids bathroom trash today." */
    fun sentence(name: String, chore: String, day: LocalDate, today: LocalDate) =
        "${name.replaceFirstChar { it.uppercase() }} ${did(chore)} ${whenDone(day, today)}."

    /** "1 chore", "3 chores"; "1 minute", "25 minutes". */
    fun count(n: Int, word: String) = "$n $word${if (n == 1) "" else "s"}"
}
