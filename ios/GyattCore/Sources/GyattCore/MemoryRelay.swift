import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// An in-memory relay with the same rules as supabase/doyourwork/001_relay.sql: anonymous sign-ups,
/// membership checks, one-time join tokens, and records only members can read or write. GyattCore's
/// tests use it, and so do the app's UI tests (`-memoryRelay`), so neither ever reaches the real one.
public final class MemoryRelay: RelayHTTP, @unchecked Sendable {
    public init() {}
    /// Any address will do: nothing leaves the process.
    public static let config = RelayConfig(url: "https://relay.invalid", publishableKey: "memory")
    public struct Rec { var ciphertext: String, clientUpdatedAt: Int64 }
    private let lock = NSLock()
    var users: [String: String] = [:]          // access token → user id
    var refresh: [String: String] = [:]        // refresh token → user id
    var devices: [String: [String: String]] = [:]  // household → user id → joined_at
    var tokens: [String: (household: String, expires: Date, used: Bool)] = [:]  // token hash hex → …
    var records: [String: Rec] = [:]           // "household|kind|row" → record
    var expireNextToken = false
    var requests: [String] = []

    public func send(_ req: URLRequest) async throws -> (Data, Int) { lock.withLock { handle(req) } }

    private func json(_ o: Any, _ code: Int = 200) -> (Data, Int) { (try! JSONSerialization.data(withJSONObject: o, options: .fragmentsAllowed), code) }
    private func newSession(_ uid: String) -> (Data, Int) {
        let at = UUID().uuidString, rt = UUID().uuidString
        users[at] = uid; refresh[rt] = uid
        return json(["access_token": at, "refresh_token": rt, "expires_in": 3600, "user": ["id": uid]])
    }
    private func hexOf(_ bytea: String) -> Data {
        let s = bytea.dropFirst(2)
        return Data(stride(from: 0, to: s.count, by: 2).map { UInt8(s.dropFirst($0).prefix(2), radix: 16)! })
    }

    private func handle(_ req: URLRequest) -> (Data, Int) {
        let url = req.url!, comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let q = Dictionary((comps.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
        let body = req.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) }
        requests.append("\(req.httpMethod!) \(url.path)")
        guard req.value(forHTTPHeaderField: "apikey") != nil else { return json(["message": "no apikey"], 401) }

        if url.path == "/auth/v1/signup" { return newSession(UUID().uuidString.lowercased()) }
        if url.path == "/auth/v1/token" {
            guard let rt = (body as? [String: String])?["refresh_token"], let uid = refresh.removeValue(forKey: rt) else { return json(["message": "bad refresh"], 400) }
            return newSession(uid)
        }
        let token = req.value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(of: "Bearer ", with: "")
        guard let token, let uid = users[token] else { return json(["message": "JWT expired"], 401) }
        let member = { (h: String) in self.devices[h]?[uid] != nil }
        let eq = { (k: String) in q[k].map { String($0.dropFirst(3)) } }

        switch (req.httpMethod!, url.path) {
        case ("POST", "/rest/v1/rpc/create_household"):
            let h = (body as! [String: String])["p_household"]!
            guard devices[h] == nil else { return json(["message": "duplicate"], 409) }
            devices[h] = [uid: ISO8601DateFormatter().string(from: Date())]; return (Data(), 204)
        case ("POST", "/rest/v1/rpc/create_join_token"):
            let a = body as! [String: String], h = a["p_household"]!
            guard member(h) else { return json(["message": "not a member"], 403) }
            let exp = expireNextToken ? Date(timeIntervalSinceNow: -1) : Date(timeIntervalSinceNow: 600); expireNextToken = false
            tokens[String(a["p_token_hash"]!.dropFirst(2))] = (h, exp, false)
            return json(ISO8601DateFormatter().string(from: exp))
        case ("POST", "/rest/v1/rpc/join_household"):
            let a = body as! [String: String], h = a["p_household"]!
            let hash = SHA256.hash(data: hexOf(a["p_token"]!)).map { String(format: "%02x", $0) }.joined()
            guard let t = tokens[hash], t.household == h, !t.used, t.expires > Date() else { return json(false) }
            tokens[hash]!.used = true
            devices[h, default: [:]][uid] = devices[h]?[uid] ?? ISO8601DateFormatter().string(from: Date())
            return json(true)
        case ("POST", "/rest/v1/rpc/remove_device"):
            let a = body as! [String: String], h = a["p_household"]!
            guard member(h) else { return json(["message": "not a member"], 403) }
            devices[h]?[a["p_user"]!] = nil; return (Data(), 204)
        case ("POST", "/rest/v1/rpc/delete_household"):
            let h = (body as! [String: String])["p_household"]!
            guard member(h) else { return json(["message": "not a member"], 403) }
            devices[h] = nil; records = records.filter { !$0.key.hasPrefix(h + "|") }; return (Data(), 204)
        case ("GET", "/rest/v1/household_devices"):
            let h = eq("household_id")!
            guard member(h) else { return json([]) }
            return json(devices[h]!.map { ["user_id": $0.key, "joined_at": $0.value] })
        case ("POST", "/rest/v1/records"):
            for r in body as! [[String: Any]] {
                let h = r["household_id"] as! String
                guard member(h) else { return json(["message": "row-level security"], 403) }
                records["\(h)|\(r["kind"] as! String)|\(r["row_id"] as! String)"] = Rec(ciphertext: r["ciphertext"] as! String, clientUpdatedAt: (r["client_updated_at"] as! NSNumber).int64Value)
            }
            return (Data(), 201)
        case ("PATCH", "/rest/v1/records"):
            let key = "\(eq("household_id")!)|\(eq("kind")!)|\(eq("row_id")!)"
            guard member(eq("household_id")!), records[key] != nil else { return json([]) }
            let b = body as! [String: Any]
            records[key] = Rec(ciphertext: b["ciphertext"] as! String, clientUpdatedAt: (b["client_updated_at"] as! NSNumber).int64Value)
            return json([["row_id": eq("row_id")!]])
        case ("GET", "/rest/v1/records"):
            let h = eq("household_id")!, kind = eq("kind")!
            guard member(h) else { return json([]) }
            let rows = records.filter { $0.key.hasPrefix("\(h)|\(kind)|") }.sorted { $0.key < $1.key }
            let offset = Int(q["offset"] ?? "0")!, limit = Int(q["limit"] ?? "1000")!
            return json(rows.dropFirst(offset).prefix(limit).map { k, v in
                ["household_id": h, "kind": kind, "row_id": String(k.split(separator: "|", maxSplits: 2)[2]), "ciphertext": v.ciphertext, "client_updated_at": v.clientUpdatedAt] as [String: Any]
            })
        default:
            return json(["message": "not found"], 404)
        }
    }

    /// Lets a test tamper with what the server holds.
    public func withRecords(_ f: (inout [String: Rec]) -> Void) { lock.lock(); f(&records); lock.unlock() }
}
