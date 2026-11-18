package com.gyattchores.app.sync

/**
 * Where a phone keeps its family keys and its relay sign-in between launches. On a phone that's
 * the Android Keystore (`data/KeystoreRelayVault`); tests and the in-memory test relay use [MemoryRelayVault].
 */
interface RelayVault {
    fun loadKeys(): FamilyKeys?
    fun saveKeys(keys: FamilyKeys)
    /** Forgets the keys and the sign-in: the family was deleted from the server, or this phone removed. */
    fun clear()
    val sessions: RelaySessionStore
}

class MemoryRelayVault : RelayVault {
    @Volatile private var keys: FamilyKeys? = null
    override fun loadKeys() = keys
    override fun saveKeys(keys: FamilyKeys) { this.keys = keys }
    override fun clear() { keys = null; sessions.clear() }
    override val sessions = MemorySessionStore()
}
