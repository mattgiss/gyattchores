package com.doyourwork.app.sync

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import kotlinx.serialization.json.put
import java.net.URI
import java.net.URLDecoder
import java.security.MessageDigest
import java.time.Instant
import java.util.UUID

/**
 * An in-memory relay with the same rules as supabase/doyourwork/001_relay.sql: anonymous sign-ups,
 * membership checks, one-time join tokens, and records only members can read or write.
 *
 * The unit tests run [Relay] against it, and debug builds can sync with it (`--ez memoryRelay true`),
 * so the join flow can be tried without the real server. It lives only as long as the app process.
 */
class MemoryRelay : RelayHttp {
    companion object {
        /** Where [Relay] thinks it's talking to. Never resolves: nothing leaves the process. */
        val CONFIG = RelayConfig("https://relay.invalid", "memory-relay")
    }

    data class Rec(var ciphertext: String, var clientUpdatedAt: Long)
    data class Token(val household: String, val expires: Long, var used: Boolean = false)
    val users = HashMap<String, String>()
    private val refresh = HashMap<String, String>()
    private val devices = HashMap<String, LinkedHashMap<String, String>>()
    private val tokens = HashMap<String, Token>()
    val records = sortedMapOf<String, Rec>()
    var expireNextToken = false

    private fun session(uid: String): Pair<Int, String> {
        val at = UUID.randomUUID().toString(); val rt = UUID.randomUUID().toString()
        users[at] = uid; refresh[rt] = uid
        return 200 to buildJsonObject { put("access_token", at); put("refresh_token", rt); put("expires_in", 3600); put("user", buildJsonObject { put("id", uid) }) }.toString()
    }

    @Synchronized
    override fun send(method: String, url: String, headers: Map<String, String>, body: String?): Pair<Int, String> {
        val uri = URI(url)
        val q = uri.rawQuery.orEmpty().split("&").filter { it.isNotEmpty() }.associate { it.substringBefore("=") to URLDecoder.decode(it.substringAfter("="), "UTF-8") }
        val eq = { k: String -> q[k]?.removePrefix("eq.") }
        val b = body?.let { Json.parseToJsonElement(it) }
        if (headers["apikey"] == null) return 401 to "{}"
        if (uri.path == "/auth/v1/signup") return session(UUID.randomUUID().toString())
        if (uri.path == "/auth/v1/token") {
            val uid = refresh.remove(b!!.jsonObject["refresh_token"]!!.jsonPrimitive.content) ?: return 400 to "{}"
            return session(uid)
        }
        val uid = users[headers["Authorization"]?.removePrefix("Bearer ")] ?: return 401 to """{"message":"JWT expired"}"""
        val member = { h: String -> devices[h]?.containsKey(uid) == true }
        val arg = { k: String -> b!!.jsonObject[k]!!.jsonPrimitive.content }

        return when (method to uri.path) {
            "POST" to "/rest/v1/rpc/create_household" -> {
                val h = arg("p_household"); if (devices.containsKey(h)) 409 to "{}" else { devices[h] = linkedMapOf(uid to Instant.now().toString()); 204 to "" }
            }
            "POST" to "/rest/v1/rpc/is_member" -> 200 to member(arg("h")).toString()
            "POST" to "/rest/v1/rpc/create_join_token" -> {
                val h = arg("p_household"); if (!member(h)) return 403 to "{}"
                val exp = if (expireNextToken) System.currentTimeMillis() - 1000 else System.currentTimeMillis() + 600_000; expireNextToken = false
                tokens[arg("p_token_hash").removePrefix("\\x")] = Token(h, exp)
                200 to JsonPrimitive(Instant.ofEpochMilli(exp).toString()).toString()
            }
            "POST" to "/rest/v1/rpc/join_household" -> {
                val h = arg("p_household"); val tok = arg("p_token").removePrefix("\\x")
                val raw = ByteArray(tok.length / 2) { tok.substring(it * 2, it * 2 + 2).toInt(16).toByte() }
                val hash = MessageDigest.getInstance("SHA-256").digest(raw).joinToString("") { "%02x".format(it) }
                val t = tokens[hash]
                if (t == null || t.household != h || t.used || t.expires < System.currentTimeMillis()) 200 to "false"
                else { t.used = true; devices.getOrPut(h) { linkedMapOf() }.putIfAbsent(uid, Instant.now().toString()); 200 to "true" }
            }
            "POST" to "/rest/v1/rpc/remove_device" -> { val h = arg("p_household"); if (!member(h)) 403 to "{}" else { devices[h]!!.remove(arg("p_user")); 204 to "" } }
            "POST" to "/rest/v1/rpc/delete_household" -> {
                val h = arg("p_household"); if (!member(h)) 403 to "{}" else { devices.remove(h); records.keys.removeIf { it.startsWith("$h|") }; 204 to "" }
            }
            "GET" to "/rest/v1/household_devices" -> {
                val h = eq("household_id")!!; if (!member(h)) 200 to "[]"
                else 200 to buildJsonArray { devices[h]!!.forEach { (u, at) -> add(buildJsonObject { put("user_id", u); put("joined_at", at) }) } }.toString()
            }
            "POST" to "/rest/v1/records" -> {
                for (r in b!!.jsonArray) {
                    val o = r.jsonObject; val h = o["household_id"]!!.jsonPrimitive.content
                    if (!member(h)) return 403 to """{"message":"row-level security"}"""
                    records["$h|${o["kind"]!!.jsonPrimitive.content}|${o["row_id"]!!.jsonPrimitive.content}"] =
                        Rec(o["ciphertext"]!!.jsonPrimitive.content, o["client_updated_at"]!!.jsonPrimitive.long)
                }
                201 to ""
            }
            "PATCH" to "/rest/v1/records" -> {
                val key = "${eq("household_id")}|${eq("kind")}|${eq("row_id")}"
                val rec = records[key]
                if (!member(eq("household_id")!!) || rec == null) 200 to "[]"
                else { rec.ciphertext = arg("ciphertext"); rec.clientUpdatedAt = b!!.jsonObject["client_updated_at"]!!.jsonPrimitive.long; 200 to """[{"row_id":"x"}]""" }
            }
            "GET" to "/rest/v1/records" -> {
                val h = eq("household_id")!!; val kind = eq("kind")!!
                if (!member(h)) return 200 to "[]"
                val rows = records.filterKeys { it.startsWith("$h|$kind|") }.entries.drop(q["offset"]!!.toInt()).take(q["limit"]!!.toInt())
                200 to JsonArray(rows.map { (k, v) -> buildJsonObject {
                    put("household_id", h); put("kind", kind); put("row_id", k.split("|", limit = 3)[2]); put("ciphertext", v.ciphertext); put("client_updated_at", v.clientUpdatedAt)
                } }).toString()
            }
            else -> 404 to "{}"
        }
    }
}
