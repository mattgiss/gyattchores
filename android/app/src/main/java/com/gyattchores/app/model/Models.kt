package com.gyattchores.app.model

import kotlinx.serialization.Serializable

/**
 * Someone in the family. [name] is the username chores and points are kept under; [displayName]
 * is only ever shown. Admins approve chores and change players and chores; [plays] is false for
 * someone who only runs the scoreboard (say, a parent who doesn't do chores).
 */
@Serializable
data class Player(
    val id: String,
    val name: String,
    val displayName: String? = null,
    val isAdmin: Boolean = false,
    val plays: Boolean = true,
    /** The id of the character they picked for their scoreboard tile; null until they pick (see Characters.assign). */
    val character: String? = null,
) {
    /** What to show for this person: the display name if it holds anything visible, else the username. */
    val shownName: String get() = displayName?.let { com.gyattchores.app.engine.DisplayName.clean(it) } ?: name

    /** For the admin area, where the real username must stay visible: "display name (username)". */
    val adminLabel: String get() = if (shownName == name) name else "$shownName ($name)"
}

/** One chore in the pool (`native/chores.json`). `tiers` are minute costs that kick in at `tierDays` of neglect. */
@Serializable
data class Chore(
    val id: String,
    val name: String,
    val cat: String,
    val pts: Int,
    val tiers: List<Int>,
    val tierDays: List<Int>,
)

object Status {
    const val PENDING = "pending"
    const val APPROVED = "approved"
    const val REJECTED = "rejected"
}

/**
 * A chore log. Mirrors the web app's log and the Supabase `simple_logs` row.
 * [minutes] is local-only: rows pulled from sync have it null.
 */
@Serializable
data class ChoreLog(
    val id: String,
    val remoteId: String? = null,
    val playerId: String,
    val playerName: String,
    val choreId: String,
    val choreName: String,
    val points: Int,
    val minutes: Int? = null,
    val status: String,
    /** Epoch millis. */
    val timestamp: Long,
    /** Local-only: this chore matched a parent's hidden pick, so [points] is already doubled. */
    val parentPick: Boolean = false,
    /** Local-only: status was changed here and hasn't reached the server yet. */
    val statusDirty: Boolean = false,
)

/** A chore resolved for one player right now: its escalation tier and current minute cost. */
data class EnrichedChore(
    val chore: Chore,
    val neglectDays: Int,
    val currentMinutes: Int,
    /** 0 normal, 1 "!" neglected, 2 "!!" long overdue. */
    val escalLevel: Int,
) {
    val id get() = chore.id
    val name get() = chore.name
    val cat get() = chore.cat
    val pts get() = chore.pts
}

/** Today's card for one player. Lives only on the device that built it, like the web app. */
@Serializable
data class Card(
    /** Local date, ISO yyyy-MM-dd. */
    val date: String,
    val choreIds: List<String>,
    val minutes: List<Int>,
    val checked: List<Boolean>,
    /** Escalation level per chore when the card was built; empty on cards rebuilt from logs. */
    val escal: List<Int> = emptyList(),
    val submitted: Boolean = false,
)

/** A secret guess: [from] dares that [target] will do [choreId] on [day] (yyyy-MM-dd). */
data class Dare(val from: String, val target: String, val choreId: String, val day: String)

data class Rank(
    val level: Int,
    val version: String,
    val nextVersion: String,
    val into: Int,
    val need: Int,
    val pct: Int,
)
