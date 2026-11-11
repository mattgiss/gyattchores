package com.gyattchores.app.model

import kotlinx.serialization.Serializable

@Serializable
data class Player(val id: String, val name: String)

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

data class Rank(
    val level: Int,
    val version: String,
    val nextVersion: String,
    val into: Int,
    val need: Int,
    val pct: Int,
)
