package com.gyattchores.app.sync

import com.gyattchores.app.model.ChoreLog
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.time.OffsetDateTime

/**
 * Where a relay lives. The real one (the DOYOURWORK Supabase project) is in the family edition's
 * `Servers`, so the public edition carries no server address at all.
 */
data class RelayConfig(val url: String, val publishableKey: String)

/** This device's anonymous sign-in. No email or password: just a random user id the server made. */
@Serializable
data class RelaySession(val accessToken: String, val refreshToken: String, /** Epoch seconds. */ val expiresAt: Long, val userId: String)

/** Keeps the session between launches. */
interface RelaySessionStore {
    fun load(): RelaySession?
    fun save(session: RelaySession)
}

class MemorySessionStore(@Volatile private var session: RelaySession? = null) : RelaySessionStore {
    override fun load() = session
    override fun save(session: RelaySession) { this.session = session }
}

/** The network, so tests can put an in-memory relay behind the client. Returns the status and body. */
fun interface RelayHttp {
    fun send(method: String, url: String, headers: Map<String, String>, body: String?): Pair<Int, String>
}

object UrlConnectionHttp : RelayHttp {
    override fun send(method: String, url: String, headers: Map<String, String>, body: String?): Pair<Int, String> {
        val c = URL(url).openConnection() as HttpURLConnection
        try {
            c.requestMethod = method
            c.connectTimeout = 15_000; c.readTimeout = 20_000
            headers.forEach { (k, v) -> c.setRequestProperty(k, v) }
            if (body != null) { c.doOutput = true; c.outputStream.use { it.write(body.toByteArray()) } }
            val code = c.responseCode
            val text = (if (code in 200..299) c.inputStream else c.errorStream)?.bufferedReader()?.use { it.readText() }.orEmpty()
            return code to text
        } finally { c.disconnect() }
    }
}

/** A phone that joined the household, as the server lists it. */
data class RelayDevice(val userId: String, /** Epoch millis. */ val joinedAt: Long)

/**
 * The relay transport (docs/design/encrypted-relay-join.md): the same [LogApi] and [StateApi] the old
 * plain tables offered, so [LogSync] and [StateSync] keep their rules, but every record is sealed with
 * the family key before it leaves the phone. GyattCore's `RelayClient.swift` is the same.
 */
class Relay(
    val keys: FamilyKeys,
    private val sessions: RelaySessionStore,
    private val config: RelayConfig,
    private val http: RelayHttp = UrlConnectionHttp,
    private val now: () -> Long = System::currentTimeMillis,
) : LogApi, StateApi {
    private val json = Json { ignoreUnknownKeys = true; explicitNulls = false }
    private val household = keys.householdUUID.toString()
    private val lock = Any()

    /** Records the last pull skipped because they wouldn't open. Zero unless something is wrong. */
    @Volatile var unreadable = 0
        private set

    // ─── Household ──────────────────────────────────────────────────────────

    /** This device's anonymous user id, signing in first if it hasn't yet. */
    fun userId(): String = session().userId

    /** The first "Add a phone": puts the household on the server with this device in it. */
    fun createHousehold() { rpc("create_household", mapOf("p_household" to household)) }

    /** A one-time code for another phone to scan, good for 10 minutes. Returns the code and its expiry (epoch millis). */
    fun makeJoinCode(): Pair<JoinCode, Long> {
        val code = JoinCode.make(keys)
        val out = rpc("create_join_token", mapOf("p_household" to household, "p_token_hash" to bytea(code.tokenHash)))
        val expires = json.parseToJsonElement(out).jsonPrimitive.contentOrNull ?: throw HttpStatusException(0, "bad response")
        return code to parseTime(expires)
    }

    /** The scanning phone joins with the code it read. False if the code was wrong, used or expired. */
    fun join(code: JoinCode): Boolean {
        val out = rpc("join_household", mapOf("p_household" to household, "p_token" to bytea(code.token)))
        return json.parseToJsonElement(out).jsonPrimitive.booleanOrNull ?: throw HttpStatusException(0, "bad response")
    }

    @Serializable private data class DeviceRow(@SerialName("user_id") val userId: String, @SerialName("joined_at") val joinedAt: String)

    fun devices(): List<RelayDevice> =
        json.decodeFromString<List<DeviceRow>>(rest("GET", "household_devices?household_id=eq.$household&select=user_id,joined_at&order=joined_at.asc"))
            .map { RelayDevice(it.userId, parseTime(it.joinedAt)) }

    /** Admin → Phones → Remove. That phone can't fetch anything new afterwards. */
    fun removeDevice(userId: String) { rpc("remove_device", mapOf("p_household" to household, "p_user" to userId)) }

    /** Admin → "Delete this family from the server": the household and every record go. */
    fun deleteHousehold() { rpc("delete_household", mapOf("p_household" to household)) }

    // ─── LogApi ─────────────────────────────────────────────────────────────

    @Serializable
    internal data class LogPayload(
        val id: String, val playerId: String, val playerName: String, val choreId: String, val choreName: String,
        val points: Int, val minutes: Int? = null, val status: String, /** Epoch millis. */ val timestamp: Long,
    )

    @Serializable
    private data class Record(
        @SerialName("household_id") val household: String, val kind: String, @SerialName("row_id") val rowId: String,
        val ciphertext: String, @SerialName("client_updated_at") val clientUpdatedAt: Long,
    )

    private fun sealLog(log: ChoreLog, rowId: String): Record {
        val p = LogPayload(rowId, log.playerId, log.playerName, log.choreId, log.choreName, log.points, log.minutes, log.status, log.timestamp)
        return Record(household, "log", rowId, keys.seal(json.encodeToString(p).toByteArray(), "log", rowId), now())
    }

    /** A log keeps its own id as its row id, and its own date. */
    override fun insert(log: ChoreLog): RemoteLog {
        val rowId = log.remoteId ?: log.id
        rest("POST", "records?on_conflict=household_id,kind,row_id", json.encodeToString(listOf(sealLog(log, rowId))), "resolution=merge-duplicates,return=minimal")
        return RemoteLog(rowId, log.playerId, log.playerName, log.choreId, log.choreName, log.points, log.status, log.timestamp, log.minutes)
    }

    override fun updateStatus(log: ChoreLog): Boolean {
        val rowId = log.remoteId ?: return false
        val r = sealLog(log, rowId)
        val body = buildJsonObject { put("ciphertext", r.ciphertext); put("client_updated_at", r.clientUpdatedAt) }.toString()
        val out = rest("PATCH", "records?household_id=eq.$household&kind=eq.log&row_id=eq.${enc(rowId)}", body, "return=representation")
        return json.parseToJsonElement(out).jsonArray.isNotEmpty()
    }

    override fun selectAll(): List<RemoteLog> {
        var bad = 0
        val logs = pull("log").mapNotNull { r ->
            val p = try { json.decodeFromString<LogPayload>(String(keys.open(r.ciphertext, "log", r.rowId), Charsets.UTF_8)) } catch (e: Exception) { null }
            if (p == null || p.id != r.rowId) { bad++; null }
            else RemoteLog(r.rowId, p.playerId, p.playerName, p.choreId, p.choreName, p.points, p.status, p.timestamp, p.minutes)
        }
        unreadable = bad
        return logs
    }

    // ─── StateApi ───────────────────────────────────────────────────────────

    @Serializable internal data class StatePayload(val key: String, val items: List<String>, val updatedAt: Long)

    override fun upsert(entry: RemoteEntry) {
        val rowId = keys.stateRowId(entry.key)
        val sealed = keys.seal(json.encodeToString(StatePayload(entry.key, entry.items, entry.updatedAt)).toByteArray(), "state", rowId)
        rest("POST", "records?on_conflict=household_id,kind,row_id", json.encodeToString(listOf(Record(household, "state", rowId, sealed, entry.updatedAt))),
            "resolution=merge-duplicates,return=minimal")
    }

    override fun selectState(): List<RemoteEntry> {
        var bad = 0
        val entries = pull("state").mapNotNull { r ->
            val p = try { json.decodeFromString<StatePayload>(String(keys.open(r.ciphertext, "state", r.rowId), Charsets.UTF_8)) } catch (e: Exception) { null }
            if (p == null || keys.stateRowId(p.key) != r.rowId) { bad++; null } else RemoteEntry(p.key, p.items, p.updatedAt)
        }
        unreadable += bad
        return entries
    }

    // ─── Wire ───────────────────────────────────────────────────────────────

    private fun pull(kind: String): List<Record> {
        // PostgREST caps a response at 1000 rows, so page through.
        val all = ArrayList<Record>()
        while (true) {
            val page = json.decodeFromString<List<Record>>(rest("GET",
                "records?household_id=eq.$household&kind=eq.$kind&select=household_id,kind,row_id,ciphertext,client_updated_at&order=row_id.asc&limit=$PAGE&offset=${all.size}"))
            all += page
            if (page.size < PAGE) return all
        }
    }

    private fun rpc(name: String, args: Map<String, String>): String =
        rest("POST", "rpc/$name", json.encodeToString(args), "return=representation")

    /** Signs in if needed, and on a 401 refreshes the session once and tries again. */
    private fun rest(method: String, path: String, body: String? = null, prefer: String? = null): String {
        var s = session()
        repeat(2) { attempt ->
            val (code, text) = send(method, "/rest/v1/$path", body, s.accessToken, prefer)
            if (code in 200..299) return text.ifBlank { "[]" }
            if (code == 401 && attempt == 0) s = refresh(s) else throw HttpStatusException(code, text)
        }
        throw HttpStatusException(0, "unreachable")
    }

    private fun send(method: String, path: String, body: String?, token: String?, prefer: String?): Pair<Int, String> {
        val h = linkedMapOf("apikey" to config.publishableKey, "Accept" to "application/json")
        if (token != null) h["Authorization"] = "Bearer $token"
        if (body != null) { h["Content-Type"] = "application/json"; if (prefer != null) h["Prefer"] = prefer }
        return http.send(method, config.url + path, h, body)
    }

    // ─── Session ────────────────────────────────────────────────────────────

    @Serializable private data class AuthUser(val id: String)
    @Serializable private data class AuthResponse(
        @SerialName("access_token") val accessToken: String, @SerialName("refresh_token") val refreshToken: String,
        @SerialName("expires_in") val expiresIn: Long, val user: AuthUser,
    )

    private fun session(): RelaySession = synchronized(lock) {
        val s = sessions.load() ?: return signUp()
        if (s.expiresAt - 60 <= now() / 1000) refresh(s) else s
    }

    private fun signUp() = auth("/auth/v1/signup", "{}")

    private fun refresh(s: RelaySession) = synchronized(lock) {
        // Another call may have refreshed already while this one waited.
        val current = sessions.load()
        if (current != null && current.accessToken != s.accessToken && current.expiresAt - 60 > now() / 1000) current
        else auth("/auth/v1/token?grant_type=refresh_token", json.encodeToString(mapOf("refresh_token" to s.refreshToken)))
    }

    private fun auth(path: String, body: String): RelaySession {
        val (code, text) = send("POST", path, body, null, null)
        if (code !in 200..299) throw HttpStatusException(code, text)
        val r = json.decodeFromString<AuthResponse>(text)
        return RelaySession(r.accessToken, r.refreshToken, now() / 1000 + r.expiresIn, r.user.id).also { sessions.save(it) }
    }

    private companion object {
        const val PAGE = 1000
        fun enc(s: String): String = URLEncoder.encode(s, "UTF-8")
        fun bytea(b: ByteArray) = "\\x" + b.joinToString("") { "%02x".format(it) }
        fun parseTime(s: String): Long = OffsetDateTime.parse(s).toInstant().toEpochMilli()
    }
}

