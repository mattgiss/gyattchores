package com.gyattchores.app.sync

/** The public edition talks to no server, so it has no addresses (the family edition's `Servers` does). */
object Servers {
    val RELAY: RelayConfig? = null
    val OLD_TABLES: Pair<String, String>? = null
}
