package com.gyattchores.app.sync

import com.gyattchores.app.model.ChoreLog
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.time.Instant
import java.time.OffsetDateTime

/**
 * The same Supabase project and publishable (anon) key the web app ships in `index.html`.
 * The key is public by design; access is governed by the table's row-level-security policies.
 */
object SyncConfig {
    const val URL = "https://ukshxdoqgwoxobjdclpx.supabase.co"
    const val ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVrc2h4ZG9xZ3dveG9iamRjbHB4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3MjI2NDEsImV4cCI6MjA4MDI5ODY0MX0.UGNrsfG6goEA0PPWG4x7gxBueA7D5Oe9uWI-iCXIar0"
}

class HttpStatusException(val code: Int, body: String) : IOException("HTTP $code: ${body.take(200)}")

/** Minimal PostgREST client over HttpURLConnection. */
class Supabase(private val baseUrl: String = SyncConfig.URL, private val key: String = SyncConfig.ANON_KEY) : LogApi, StateApi {
    private val json = Json { ignoreUnknownKeys = true; explicitNulls = false }

    @Serializable
    private data class LogRow(
        val id: String? = null,
        @SerialName("player_id") val playerId: String,
        @SerialName("player_name") val playerName: String,
        @SerialName("chore_id") val choreId: String,
        @SerialName("chore_name") val choreName: String,
        @SerialName("chore_icon") val choreIcon: String? = "",
        val points: Int = 0,
        val status: String,
        @SerialName("created_at") val createdAt: String? = null,
    ) {
        fun toRemote() = RemoteLog(id!!, playerId, playerName, choreId, choreName, points, status, parseTime(createdAt))
    }

    @Serializable private data class StatusPatch(val status: String)

    @Serializable
    private data class StateRow(
        val key: String,
        val items: List<String>,
        @SerialName("updated_at") val updatedAt: String,
    )

    override fun insert(log: ChoreLog): RemoteLog {
        val body = json.encodeToString(LogRow(null, log.playerId, log.playerName, log.choreId, log.choreName, "", log.points, log.status))
        return json.decodeFromString<List<LogRow>>(call("POST", "simple_logs", body)).first().toRemote()
    }

    override fun updateStatus(remoteId: String, status: String): Boolean {
        val out = call("PATCH", "simple_logs?id=eq.${enc(remoteId)}", json.encodeToString(StatusPatch(status)))
        return json.decodeFromString<List<LogRow>>(out).isNotEmpty()
    }

    override fun selectAll(): List<RemoteLog> {
        // PostgREST caps a response at 1000 rows, so page through.
        val all = ArrayList<RemoteLog>()
        while (true) {
            val page = json.decodeFromString<List<LogRow>>(
                call("GET", "simple_logs?select=*&order=created_at.desc,id.asc&limit=$PAGE&offset=${all.size}", null))
            all += page.map { it.toRemote() }
            if (page.size < PAGE) return all
        }
    }

    override fun upsert(entry: RemoteEntry) {
        val body = json.encodeToString(listOf(StateRow(entry.key, entry.items, Instant.ofEpochMilli(entry.updatedAt).toString())))
        call("POST", "family_state?on_conflict=key", body, prefer = "resolution=merge-duplicates,return=minimal")
    }

    override fun selectState(): List<RemoteEntry> =
        json.decodeFromString<List<StateRow>>(call("GET", "family_state?select=*", null))
            .map { RemoteEntry(it.key, it.items, parseTime(it.updatedAt)) }

    private fun call(method: String, path: String, body: String?, prefer: String = "return=representation"): String {
        val c = URL("$baseUrl/rest/v1/$path").openConnection() as HttpURLConnection
        try {
            c.requestMethod = method
            c.connectTimeout = 15_000; c.readTimeout = 20_000
            c.setRequestProperty("apikey", key)
            c.setRequestProperty("Authorization", "Bearer $key")
            c.setRequestProperty("Accept", "application/json")
            if (body != null) {
                c.setRequestProperty("Content-Type", "application/json")
                c.setRequestProperty("Prefer", prefer)
                c.doOutput = true
                c.outputStream.use { it.write(body.toByteArray()) }
            }
            val code = c.responseCode
            val text = (if (code in 200..299) c.inputStream else c.errorStream)?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (code !in 200..299) throw HttpStatusException(code, text)
            return text.ifBlank { "[]" }
        } finally { c.disconnect() }
    }

    private companion object {
        const val PAGE = 1000
        fun enc(s: String): String = URLEncoder.encode(s, "UTF-8")
        fun parseTime(s: String?): Long = s?.let { OffsetDateTime.parse(it).toInstant().toEpochMilli() } ?: System.currentTimeMillis()
    }
}
