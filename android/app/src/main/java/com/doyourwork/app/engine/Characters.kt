package com.doyourwork.app.engine

import com.doyourwork.app.model.Player

/**
 * One of the little characters a player can have on their scoreboard tile. It's a stack of layers
 * on a [Characters.SIZE] square, painted in order: the dark body, then the light details (eyes,
 * teeth, a headband), with the odd body layer on top for a pupil.
 */
data class PlayerCharacter(val id: String, val name: String, val layers: List<Layer>) {
    data class Layer(val detail: Boolean, val path: String)
}

/** The characters, who gets which, and how the scoreboard lays its tiles out. The same on iOS. */
object Characters {
    const val SIZE = 40f

    /** The drawings themselves are in [CharacterArt], written out from `tools/characters`. */
    val all: List<PlayerCharacter> get() = CharacterArt.ALL

    /**
     * The characters handed out to someone who hasn't picked: the first sixteen, the ones every
     * version has. Characters added later can be picked but aren't handed out, so nobody's
     * character changes when the app updates, and phones on different versions still agree.
     */
    const val GIVEN_COUNT = 16
    val given: List<PlayerCharacter> get() = all.take(GIVEN_COUNT)

    /** The character with this id; null for none, or one this version doesn't know. */
    fun named(id: String?): PlayerCharacter? = id?.let { i -> all.firstOrNull { it.id == i } }

    /**
     * Who has which character. Someone who picked one has it. Everyone else is given one from
     * their username, so it's the same on every phone: a character named in it if there is one
     * ("sockninja" starts as the ninja), else one the username's hash lands on, or the next free one.
     * Only the [given] characters are handed out this way, and only once there are more players
     * than those do two share.
     */
    fun assign(players: List<Player>): Map<String, PlayerCharacter> {
        val out = HashMap<String, PlayerCharacter>()
        val taken = HashSet<String>()
        for (p in players) named(p.character)?.let { out[p.id] = it; taken += it.id }
        // In id order, so two phones holding the list in a different order still agree.
        for (p in players.sortedWith(compareBy({ it.id.toIntOrNull() ?: Int.MAX_VALUE }, { it.id }))) {
            if (p.id in out) continue
            // "sockninja" gets the ninja if it's free. Otherwise the username picks a place to start looking.
            val pool = given
            val namesake = pool.firstOrNull { it.id in p.name.lowercase() && it.id !in taken }
            val start = (Engine.fnv1a(p.name) % pool.size).toInt()
            val pick = namesake ?: (0 until pool.size).map { pool[(start + it) % pool.size] }.firstOrNull { it.id !in taken } ?: pool[start]
            out[p.id] = pick; taken += pick.id
        }
        return out
    }

    /**
     * How many tiles go on each row of the scoreboard: as few rows as [perRow] allows, filled as
     * evenly as they can be, so four players are two and two rather than three and one.
     */
    fun tileRows(count: Int, perRow: Int): List<Int> {
        if (count <= 0 || perRow <= 0) return emptyList()
        val rows = (count + perRow - 1) / perRow
        return List(rows) { count / rows + if (it < count % rows) 1 else 0 }
    }

    /** One step of a drawing. Coordinates are in the [SIZE] square. */
    sealed interface Step {
        data class Move(val x: Float, val y: Float) : Step
        data class Line(val x: Float, val y: Float) : Step
        data class Quad(val cx: Float, val cy: Float, val x: Float, val y: Float) : Step
        data class Cubic(val c1x: Float, val c1y: Float, val c2x: Float, val c2y: Float, val x: Float, val y: Float) : Step
        data object Close : Step
    }

    /**
     * Reads a layer's path. The drawings only ever use absolute M, L, Q, C and Z with spaces
     * between everything, so this is all the reading there is; anything else stops the drawing there.
     */
    fun steps(path: String): List<Step> {
        val out = ArrayList<Step>()
        val t = path.split(' ').filter { it.isNotEmpty() }
        var i = 0
        fun take(n: Int): List<Float>? = if (i + n > t.size) null else t.subList(i, i + n).map { it.toFloatOrNull() ?: return null }.also { i += n }
        while (i < t.size) {
            when (t[i++]) {
                "M" -> take(2)?.let { out += Step.Move(it[0], it[1]) } ?: return out
                "L" -> take(2)?.let { out += Step.Line(it[0], it[1]) } ?: return out
                "Q" -> take(4)?.let { out += Step.Quad(it[0], it[1], it[2], it[3]) } ?: return out
                "C" -> take(6)?.let { out += Step.Cubic(it[0], it[1], it[2], it[3], it[4], it[5]) } ?: return out
                "Z" -> out += Step.Close
                else -> return out
            }
        }
        return out
    }
}
