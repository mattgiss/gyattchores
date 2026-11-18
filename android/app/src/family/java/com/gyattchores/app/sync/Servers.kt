package com.gyattchores.app.sync

/**
 * The servers the family edition talks to. Only this edition has this file's addresses; the
 * public one's `Servers` has none, so its APK carries no server address at all.
 * The keys are publishable by design: row-level security on each project decides access.
 */
object Servers {
    /** The encrypted relay: the DOYOURWORK Supabase project (supabase/doyourwork/001_relay.sql). */
    val RELAY: RelayConfig? = RelayConfig("https://omemognwvcnonnzjmcxm.supabase.co", "sb_publishable_prXq51_BMc8lnG4BY5vXmA_xJysoZxa")

    /** The family's old plain tables (`simple_logs`, `family_state`), until every phone has moved to the relay. */
    val OLD_TABLES: Pair<String, String>? = "https://ukshxdoqgwoxobjdclpx.supabase.co" to
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVrc2h4ZG9xZ3dveG9iamRjbHB4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3MjI2NDEsImV4cCI6MjA4MDI5ODY0MX0.UGNrsfG6goEA0PPWG4x7gxBueA7D5Oe9uWI-iCXIar0"
}
