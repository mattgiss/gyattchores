package com.gyattchores.app

import com.gyattchores.app.sync.FamilyKeys
import com.gyattchores.app.sync.JoinCode
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.fail
import org.junit.Test
import java.io.File
import java.util.Base64

/**
 * The relay's bytes must match native/fixtures/relay-crypto.json exactly, as GyattCore's must, so an
 * Android phone and an iPhone can open each other's records.
 */
class RelayCryptoTest {
    @Serializable data class Seal(val kind: String, val rowId: String, val nonce: String, val plaintext: String, val sealed: String)
    @Serializable data class Row(val key: String, val rowId: String)
    @Serializable data class Join(val token: String, val code: String, val tokenHash: String)
    @Serializable data class Vectors(
        val familyKey: String, val household: String, val encKey: String, val rowKey: String,
        val seal: List<Seal>, val stateRowIds: List<Row>, val joinCode: Join,
    )

    private val v: Vectors = Json { ignoreUnknownKeys = true }.decodeFromString(File("../../native/fixtures/relay-crypto.json").readText())
    private val keys = FamilyKeys(hex(v.household), hex(v.familyKey))

    private fun hex(s: String) = ByteArray(s.length / 2) { s.substring(it * 2, it * 2 + 2).toInt(16).toByte() }
    private fun hexString(b: ByteArray) = b.joinToString("") { "%02x".format(it) }
    private fun assertFails(what: String, block: () -> Unit) {
        try { block(); fail("should have failed: $what") } catch (e: FamilyKeys.Failure) {}
    }

    @Test fun subkeysMatch() {
        assertEquals(v.encKey, hexString(keys.encKey))
        assertEquals(v.rowKey, hexString(keys.rowKey))
    }

    @Test fun sealsTheSameBytesAndOpensThem() {
        for (c in v.seal) {
            assertEquals(c.rowId, c.sealed, keys.seal(c.plaintext.toByteArray(), c.kind, c.rowId, hex(c.nonce)))
            assertEquals(c.plaintext, String(keys.open(c.sealed, c.kind, c.rowId), Charsets.UTF_8))
        }
    }

    @Test fun refusesMovedOrAlteredRecords() {
        val c = v.seal[0]
        assertFails("another kind") { keys.open(c.sealed, "state", c.rowId) }
        assertFails("another row") { keys.open(c.sealed, c.kind, c.rowId + "x") }
        val raw = Base64.getDecoder().decode(c.sealed).also { it[it.size - 1] = (it[it.size - 1].toInt() xor 1).toByte() }
        assertFails("a flipped bit") { keys.open(Base64.getEncoder().encodeToString(raw), c.kind, c.rowId) }
        assertFails("another family") { FamilyKeys.generate().open(c.sealed, c.kind, c.rowId) }
        assertFails("not base64") { keys.open("not base64!", c.kind, c.rowId) }
        assertFails("too short") { keys.open("AQ==", c.kind, c.rowId) }
    }

    @Test fun freshNoncesEachTime() {
        val a = keys.seal("x".toByteArray(), "log", "r")
        assertNotEquals(a, keys.seal("x".toByteArray(), "log", "r"))
        assertArrayEquals("x".toByteArray(), keys.open(a, "log", "r"))
    }

    @Test fun stateRowIds() {
        for (r in v.stateRowIds) assertEquals(r.key, r.rowId, keys.stateRowId(r.key))
    }

    @Test fun joinCode() {
        val code = JoinCode(keys, hex(v.joinCode.token))
        assertEquals(v.joinCode.code, code.text)
        assertEquals(v.joinCode.tokenHash, hexString(code.tokenHash))
        assertEquals(code, JoinCode.parse(" ${v.joinCode.code}\n"))
        for (bad in listOf("", "dyw1:", "dyw2:" + v.joinCode.code.drop(5), v.joinCode.code.dropLast(1), v.joinCode.code + "AA",
                "https://example.com", v.joinCode.code.replace("o", "+"))) {
            assertFails(bad) { JoinCode.parse(bad) }
        }
        val fresh = JoinCode.make(FamilyKeys.generate())
        assertEquals(fresh, JoinCode.parse(fresh.text))
    }

    /** The log in the fixture is the JSON both apps put inside a sealed record; each must read it. */
    @Test fun readsTheSharedLogPayload() {
        val json = Json { ignoreUnknownKeys = true }
        val p = json.decodeFromString<com.gyattchores.app.sync.Relay.LogPayload>(v.seal[0].plaintext)
        assertEquals(v.seal[0].rowId, p.id); assertEquals(5, p.minutes); assertEquals(1_731_700_000_000L, p.timestamp)
        val noMinutes = json.decodeFromString<com.gyattchores.app.sync.Relay.LogPayload>(
            """{"id":"a","playerId":"1","playerName":"k","choreId":"c","choreName":"c","points":1,"status":"pending","timestamp":1,"later":"ignored"}""")
        assertEquals(null, noMinutes.minutes)
    }

    @Test fun householdUuid() {
        assertEquals("a1b2c3d4-e5f6-0718-293a-4b5c6d7e8f90", keys.householdUUID.toString())
    }
}
