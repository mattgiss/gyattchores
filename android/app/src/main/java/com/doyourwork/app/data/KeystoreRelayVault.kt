package com.doyourwork.app.data

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import com.doyourwork.app.sync.FamilyKeys
import com.doyourwork.app.sync.RelaySession
import com.doyourwork.app.sync.RelaySessionStore
import com.doyourwork.app.sync.RelayVault
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * The family keys and relay sign-in, kept in the "relay" preferences file encrypted under an AES
 * key that lives in the Android Keystore and never leaves it. The app isn't backed up
 * (`allowBackup="false"`), so the keys stay on this phone.
 */
class KeystoreRelayVault(context: Context) : RelayVault {
    private val prefs = context.getSharedPreferences("relay", Context.MODE_PRIVATE)
    private val json = Json { ignoreUnknownKeys = true }

    override fun loadKeys(): FamilyKeys? = read(KEYS)?.takeIf { it.size == 48 }?.let { FamilyKeys(it.copyOfRange(0, 16), it.copyOfRange(16, 48)) }

    override fun saveKeys(keys: FamilyKeys) = write(KEYS, keys.household + keys.familyKey)

    override fun clear() { prefs.edit().remove(KEYS).remove(SESSION).commit() }

    override val sessions = object : RelaySessionStore {
        override fun load(): RelaySession? = read(SESSION)?.let { runCatching { json.decodeFromString<RelaySession>(String(it, Charsets.UTF_8)) }.getOrNull() }
        override fun save(session: RelaySession) = write(SESSION, json.encodeToString(session).toByteArray(Charsets.UTF_8))
    }

    private fun key(): SecretKey {
        val ks = KeyStore.getInstance(STORE).apply { load(null) }
        (ks.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, STORE).apply {
            init(KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256).build())
        }.generateKey()
    }

    @Synchronized private fun write(name: String, plain: ByteArray) {
        val c = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key()) }
        // The Keystore picks the 12-byte nonce; it's kept in front of the ciphertext.
        prefs.edit().putString(name, Base64.encodeToString(c.iv + c.doFinal(plain), Base64.NO_WRAP)).commit()
    }

    @Synchronized private fun read(name: String): ByteArray? = runCatching {
        val raw = Base64.decode(prefs.getString(name, null) ?: return null, Base64.NO_WRAP)
        Cipher.getInstance("AES/GCM/NoPadding").run {
            init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, raw, 0, 12))
            doFinal(raw, 12, raw.size - 12)
        }
    }.getOrNull()

    private companion object {
        const val STORE = "AndroidKeyStore"
        const val ALIAS = "relay"
        const val KEYS = "keys"
        const val SESSION = "session"
    }
}
