package com.gyattchores.app.sync

import java.nio.ByteBuffer
import java.security.GeneralSecurityException
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Base64
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.Mac
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * The encrypted relay's keys and record format (docs/design/encrypted-relay-join.md). GyattCore's
 * `RelayCrypto.swift` is the same, and both are checked against native/fixtures/relay-crypto.json,
 * written by native/tools/relay-crypto.mjs, which also spells out the format.
 *
 * The family key never leaves the family's phones: it travels from screen to camera in the join
 * code. The server only ever sees sealed records, hashed state keys and a hash of the join token.
 */
class FamilyKeys(household: ByteArray, familyKey: ByteArray) {
    class Failure(message: String) : Exception(message)

    /** 16 bytes, made on the first phone. Also the household's id on the server (as a UUID). */
    val household: ByteArray = household.copyOf()
    /** 32 bytes. Never sent to the server. */
    val familyKey: ByteArray = familyKey.copyOf()

    init { if (household.size != 16 || familyKey.size != 32) throw Failure("bad key length") }

    internal val encKey: ByteArray by lazy { RelayCrypto.hkdf(this.familyKey, this.household, "dyw1 enc") }
    internal val rowKey: ByteArray by lazy { RelayCrypto.hkdf(this.familyKey, this.household, "dyw1 row") }

    /** The household id as the server stores it. */
    val householdUUID: UUID get() = ByteBuffer.wrap(household).let { UUID(it.long, it.long) }

    private fun aad(kind: String, rowId: String): ByteArray =
        household + kind.toByteArray(Charsets.UTF_8) + byteArrayOf(0) + rowId.toByteArray(Charsets.UTF_8)

    /**
     * Encrypts one record for the server: base64 of version 1, nonce, ciphertext and tag. The kind
     * and row id are bound in, so the server can't move a record to another row, kind or family.
     */
    fun seal(plaintext: ByteArray, kind: String, rowId: String): String = seal(plaintext, kind, rowId, RelayCrypto.random(12))

    internal fun seal(plaintext: ByteArray, kind: String, rowId: String, nonce: ByteArray): String {
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.ENCRYPT_MODE, SecretKeySpec(encKey, "AES"), GCMParameterSpec(128, nonce))
        c.updateAAD(aad(kind, rowId))
        return Base64.getEncoder().encodeToString(byteArrayOf(1) + nonce + c.doFinal(plaintext))
    }

    /** Opens a record sealed by any of the family's phones. Throws if it was altered, moved, or sealed under another family's key. */
    fun open(sealed: String, kind: String, rowId: String): ByteArray {
        val raw = try { Base64.getDecoder().decode(sealed) } catch (e: IllegalArgumentException) { throw Failure("cannot open") }
        if (raw.size < 1 + 12 + 16 || raw[0] != 1.toByte()) throw Failure("cannot open")
        return try {
            val c = Cipher.getInstance("AES/GCM/NoPadding")
            c.init(Cipher.DECRYPT_MODE, SecretKeySpec(encKey, "AES"), GCMParameterSpec(128, raw, 1, 12))
            c.updateAAD(aad(kind, rowId))
            c.doFinal(raw, 13, raw.size - 13)
        } catch (e: GeneralSecurityException) { throw Failure("cannot open") }
    }

    /** The server's row id for a piece of shared state, so names like "dare|3|2026-11-16" don't show. */
    fun stateRowId(key: String): String = RelayCrypto.b64url(RelayCrypto.hmac(rowKey, key.toByteArray(Charsets.UTF_8)))

    override fun equals(other: Any?) = other is FamilyKeys && household.contentEquals(other.household) && familyKey.contentEquals(other.familyKey)
    override fun hashCode() = household.contentHashCode()

    companion object {
        /** A new family's keys, from the system's secure random source. */
        fun generate() = FamilyKeys(RelayCrypto.random(16), RelayCrypto.random(32))
    }
}

/** What the "Add a phone" QR code carries: the family's keys and a one-time join token. */
class JoinCode(val keys: FamilyKeys, token: ByteArray) {
    /** 32 random bytes. The server keeps only its SHA-256, for 10 minutes. */
    val token: ByteArray = token.copyOf()

    init { if (token.size != 32) throw FamilyKeys.Failure("bad token length") }

    /** The text to draw as a QR code. */
    val text: String get() = PREFIX + RelayCrypto.b64url(keys.household + keys.familyKey + token)

    /** What the first phone sends the server when it shows this code. */
    val tokenHash: ByteArray get() = MessageDigest.getInstance("SHA-256").digest(token)

    override fun equals(other: Any?) = other is JoinCode && keys == other.keys && token.contentEquals(other.token)
    override fun hashCode() = keys.hashCode()

    companion object {
        const val PREFIX = "dyw1:"

        /** A fresh code for this family. */
        fun make(keys: FamilyKeys) = JoinCode(keys, RelayCrypto.random(32))

        /** Reads a scanned code. Throws on anything that isn't a DOYOURWORK join code. */
        fun parse(scanned: String): JoinCode {
            val s = scanned.trim()
            if (!s.startsWith(PREFIX)) throw FamilyKeys.Failure("not a join code")
            val body = s.removePrefix(PREFIX)
            if (!body.all { it in 'A'..'Z' || it in 'a'..'z' || it in '0'..'9' || it == '-' || it == '_' }) throw FamilyKeys.Failure("not a join code")
            val raw = try { Base64.getUrlDecoder().decode(body) } catch (e: IllegalArgumentException) { throw FamilyKeys.Failure("not a join code") }
            if (raw.size != 80) throw FamilyKeys.Failure("not a join code")
            return JoinCode(FamilyKeys(raw.copyOfRange(0, 16), raw.copyOfRange(16, 48)), raw.copyOfRange(48, 80))
        }
    }
}

object RelayCrypto {
    private val rng = SecureRandom()

    fun random(n: Int): ByteArray = ByteArray(n).also { rng.nextBytes(it) }

    fun b64url(b: ByteArray): String = Base64.getUrlEncoder().withoutPadding().encodeToString(b)

    internal fun hmac(key: ByteArray, data: ByteArray): ByteArray =
        Mac.getInstance("HmacSHA256").run { init(SecretKeySpec(key, "HmacSHA256")); doFinal(data) }

    /** HKDF-SHA256 (RFC 5869) for one 32-byte output block, which is all the relay needs. */
    internal fun hkdf(ikm: ByteArray, salt: ByteArray, info: String): ByteArray {
        val prk = hmac(salt, ikm)
        return hmac(prk, info.toByteArray(Charsets.UTF_8) + byteArrayOf(1))
    }
}
