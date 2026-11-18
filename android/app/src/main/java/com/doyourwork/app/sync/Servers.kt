package com.doyourwork.app.sync

/**
 * The server every build talks to, and only once this phone is linked to a family (Admin →
 * Phones). The key is publishable by design: row-level security on the project decides access,
 * and everything sent is encrypted on the phone first.
 */
object Servers {
    /** The encrypted relay: the DOYOURWORK Supabase project (supabase/doyourwork/001_relay.sql). */
    val RELAY = RelayConfig("https://omemognwvcnonnzjmcxm.supabase.co", "sb_publishable_prXq51_BMc8lnG4BY5vXmA_xJysoZxa")
}
