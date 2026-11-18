package com.doyourwork.app.engine

import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * An admin's code, kept as a salted hash so the code itself is never written down. Same scheme as
 * iOS's `AdminCode`: fnv1a(salt + code), so a code set on one platform opens the other.
 *
 * The hash is small on purpose: a code is a few digits, so any hash of it could be tried
 * exhaustively. What keeps it from a curious player is that it lives in app storage. The salt
 * only keeps two admins with the same code from having matching entries.
 */
@Serializable
data class AdminCode(val salt: String, val hash: Long) {
    fun matches(code: String): Boolean = Engine.fnv1a(salt + tidy(code)) == hash

    /** "salt:hash", as kept in the family's shared state. */
    fun encode(): String = "$salt:$hash"

    companion object {
        const val MIN_LENGTH = 4

        /** Null if the code is too short. Spaces around it are ignored, since they're invisible when typed. */
        fun make(code: String, salt: String = UUID.randomUUID().toString().uppercase()): AdminCode? {
            val t = tidy(code)
            if (t.length < MIN_LENGTH) return null
            return AdminCode(salt, Engine.fnv1a(salt + t))
        }

        fun isLongEnough(code: String) = tidy(code).length >= MIN_LENGTH

        fun decode(s: String): AdminCode? {
            val i = s.lastIndexOf(':')
            if (i <= 0) return null
            return s.substring(i + 1).toLongOrNull()?.let { AdminCode(s.substring(0, i), it) }
        }

        private fun tidy(code: String) = code.trim()
    }
}
