package com.gyattchores.app.engine

import java.text.BreakIterator

/**
 * A nickname a player can show in place of their username. Display only: the username and the id
 * behind it are what logs, sync and scoring use. Mirrors iOS's `DisplayName.clean`.
 */
object DisplayName {
    /** Longest display name, in characters as a person counts them (an emoji is one). */
    const val MAX_LENGTH = 24
    /** Accents stacked on one character beyond this are dropped, so "zalgo" text can't spill over. */
    private const val MAX_MARKS = 2
    private const val ZWJ = 0x200D

    private fun isVariationSelector(cp: Int) = cp in 0xFE00..0xFE0F

    /**
     * Tidies whatever was typed into something safe to show on one line: letters, symbols and
     * emoji are welcome; line breaks and runs of spaces become one space; invisible control and
     * text-direction characters are removed; stacked accents and length are capped.
     * Returns null when nothing visible is left, meaning "use the username".
     */
    /** Emoji skin tones, which belong to the emoji before them. */
    private fun isModifier(cp: Int) = cp in 0x1F3FB..0x1F3FF

    /**
     * The characters of [s] as a person counts them. The platform's breaker does most of it; joined
     * emoji, skin tones and emoji-style selectors are glued on here as well, since older breakers
     * (the JVM's among them) split them apart.
     */
    private fun clusters(s: String): List<String> {
        val it = BreakIterator.getCharacterInstance()
        it.setText(s)
        val out = ArrayList<String>()
        var start = it.first()
        var end = it.next()
        while (end != BreakIterator.DONE) {
            val c = s.substring(start, end)
            val first = c.codePointAt(0)
            val glue = out.isNotEmpty() && (out.last().codePointBefore(out.last().length) == ZWJ ||
                first == ZWJ || isModifier(first) || isVariationSelector(first))
            if (glue) out[out.size - 1] = out.last() + c else out += c
            start = end; end = it.next()
        }
        return out
    }

    fun clean(raw: String): String? {
        val out = StringBuilder()
        var count = 0
        var needsSpace = false
        for (cluster in clusters(raw)) {
            if (count >= MAX_LENGTH) break
            val cps = cluster.codePoints().toArray()
            if (cps.all { Character.isWhitespace(it) || Character.isSpaceChar(it) }) { needsSpace = count > 0; continue }
            val kept = ArrayList<Int>()
            var marks = 0
            for (cp in cps) {
                when (Character.getType(cp).toByte()) {
                    Character.CONTROL, Character.SURROGATE, Character.PRIVATE_USE, Character.UNASSIGNED,
                    Character.LINE_SEPARATOR, Character.PARAGRAPH_SEPARATOR -> {}
                    // Invisible formatting, including direction overrides. The joiner that builds emoji stays.
                    Character.FORMAT -> if (cp == ZWJ) kept += cp
                    Character.NON_SPACING_MARK, Character.ENCLOSING_MARK, Character.COMBINING_SPACING_MARK ->
                        if (isVariationSelector(cp)) kept += cp else { marks++; if (marks <= MAX_MARKS) kept += cp }
                    else -> kept += cp
                }
            }
            if (kept.none { it != ZWJ && !isVariationSelector(it) }) continue
            if (needsSpace && count + 1 < MAX_LENGTH) { out.append(' '); count++ }
            needsSpace = false
            kept.forEach { out.appendCodePoint(it) }
            count++
        }
        return out.toString().ifEmpty { null }
    }
}
