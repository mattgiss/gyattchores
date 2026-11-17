import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
@testable import GyattCore

/// An in-memory relay with the same rules as supabase/doyourwork/001_relay.sql: anonymous sign-ups,
/// membership checks, one-time join tokens, and records only members can read or write.
final class FakeRelay: RelayHTTP, @unchecked Sendable {
    struct Rec { var ciphertext: String, clientUpdatedAt: Int64 }
    private let lock = NSLock()
    var users: [String: String] = [:]          // access token → user id
    var refresh: [String: String] = [:]        // refresh token → user id
    var devices: [String: [String: String]] = [:]  // household → user id → joined_at
    var tokens: [String: (household: String, expires: Date, used: Bool)] = [:]  // token hash hex → …
    var records: [String: Rec] = [:]           // "household|kind|row" → record
    var expireNextToken = false
    var requests: [String] = []

    func send(_ req: URLRequest) async throws -> (Data, Int) { lock.lock(); defer { lock.unlock() }; return handle(req) }

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
    func withRecords(_ f: (inout [String: Rec]) -> Void) { lock.lock(); f(&records); lock.unlock() }
}

final class RelayClientTests: XCTestCase {
    func log(_ id: String, _ status: String = "pending", remoteId: String? = nil, dirty: Bool = false) -> ChoreLog {
        ChoreLog(id: id, remoteId: remoteId, playerId: "1", playerName: "kid", choreId: "make-bed", choreName: "make bed", points: 8, minutes: 5,
                 status: status, timestamp: Date(timeIntervalSince1970: 1_731_700_000.123), statusDirty: dirty)
    }

    /// Two phones in one family, sharing the fake relay.
    func family() async throws -> (FakeRelay, RelayClient, RelayClient) {
        let server = FakeRelay(), keys = FamilyKeys.generate()
        let a = RelayClient(keys: keys, sessions: MemorySessionStore(), http: server)
        try await a.createHousehold()
        let (code, _) = try await a.makeJoinCode()
        let scanned = try JoinCode(scanned: code.text)
        let b = RelayClient(keys: scanned.keys, sessions: MemorySessionStore(), http: server)
        let joined = try await b.join(scanned)
        XCTAssertTrue(joined)
        return (server, a, b)
    }

    func testLogsTravelBetweenPhonesThroughLogSync() async throws {
        let (server, a, b) = try await family()
        let onA = try await LogSync.run(api: a, local: [log("l1")])
        XCTAssertEqual(onA.first?.remoteId, "l1")
        XCTAssertEqual(onA.first?.timestamp, log("l1").timestamp, "a log keeps its own date")

        var onB = try await LogSync.run(api: b, local: [])
        XCTAssertEqual(onB.count, 1)
        XCTAssertEqual(onB[0].minutes, 5, "relay records carry minutes")
        XCTAssertEqual(onB[0].timestamp.timeIntervalSince1970, 1_731_700_000.123, accuracy: 0.001)

        // B approves; A picks it up.
        onB[0].status = "approved"; onB[0].statusDirty = true
        let afterB = try await LogSync.run(api: b, local: onB)
        XCTAssertFalse(afterB[0].statusDirty)
        let again = try await LogSync.run(api: a, local: onA)
        XCTAssertEqual(again.first?.status, "approved")

        // What the server holds says nothing about the family.
        for (_, r) in server.records { XCTAssertFalse(r.ciphertext.contains("kid")); XCTAssertNil(Data(base64Encoded: r.ciphertext).flatMap { String(data: $0, encoding: .utf8) }) }
    }

    func testStateTravelsWithHiddenKeys() async throws {
        let (server, a, b) = try await family()
        let local = ["players": LocalEntry(items: ["1|kid"], updatedAt: 10, dirty: true), "dare|1|2026-11-17": LocalEntry(items: ["x"], updatedAt: 11, dirty: true)]
        _ = try await StateSync.run(api: a, local: local)
        let onB = try await StateSync.run(api: b, local: [:])
        XCTAssertEqual(onB["players"]?.items, ["1|kid"])
        XCTAssertEqual(onB["dare|1|2026-11-17"]?.updatedAt, 11)
        XCTAssertFalse(server.records.keys.contains { $0.contains("players") || $0.contains("dare") }, "state keys are hashed on the server")
    }

    func testOutsidersGetNothing() async throws {
        let (server, a, _) = try await family()
        _ = try await LogSync.run(api: a, local: [log("l1")])
        // Someone with the family's keys but no device row (an old photo of the code) can't read.
        let stranger = RelayClient(keys: a.keys, sessions: MemorySessionStore(), http: server)
        let pulled = try await stranger.selectAll()
        XCTAssertTrue(pulled.isEmpty)
        do { _ = try await stranger.insert(log("evil")); XCTFail("an outsider must not write") } catch RelayError.http(let code, _) { XCTAssertEqual(code, 403) }
        do { _ = try await stranger.makeJoinCode(); XCTFail("an outsider must not make codes") } catch RelayError.http(let code, _) { XCTAssertEqual(code, 403) }
    }

    func testJoinCodesWorkOnceAndExpire() async throws {
        let (server, a, _) = try await family()
        let (code, _) = try await a.makeJoinCode()
        let c = RelayClient(keys: code.keys, sessions: MemorySessionStore(), http: server)
        let d = RelayClient(keys: code.keys, sessions: MemorySessionStore(), http: server)
        let cJoined = try await c.join(code), dJoined = try await d.join(code)
        XCTAssertTrue(cJoined); XCTAssertFalse(dJoined, "a code works once")
        let wrong = try JoinCode(keys: code.keys, token: Data(repeating: 7, count: 32))
        let wrongJoined = try await d.join(wrong)
        XCTAssertFalse(wrongJoined)
        server.expireNextToken = true
        let (old, _) = try await a.makeJoinCode()
        let oldJoined = try await d.join(old)
        XCTAssertFalse(oldJoined, "an expired code is refused")
    }

    func testTamperedRecordsAreSkippedNotFatal() async throws {
        let (server, a, b) = try await family()
        _ = try await LogSync.run(api: a, local: [log("l1"), log("l2")])
        server.withRecords { recs in
            let k1 = recs.keys.first { $0.hasSuffix("|log|l1") }!, k2 = recs.keys.first { $0.hasSuffix("|log|l2") }!
            recs[k1]!.ciphertext = recs[k2]!.ciphertext  // the server swaps a record into another row
        }
        let pulled = try await b.selectAll()
        XCTAssertEqual(pulled.map(\.id), ["l2"])
        let unreadable = await b.unreadable
        XCTAssertEqual(unreadable, 1)
    }

    func testRemovedPhoneStopsGettingUpdatesAndDeleteClearsAll() async throws {
        let (_, a, b) = try await family()
        let bId = try await b.userId()
        var devices = try await a.devices()
        XCTAssertEqual(devices.count, 2)
        try await a.removeDevice(userId: bId)
        devices = try await a.devices()
        XCTAssertEqual(devices.count, 1)
        _ = try await LogSync.run(api: a, local: [log("l1")])
        let onB = try await b.selectAll()
        XCTAssertTrue(onB.isEmpty, "a removed phone sees nothing new")
        try await a.deleteHousehold()
        let gone = try await a.selectAll()
        XCTAssertTrue(gone.isEmpty)
    }

    func testRefreshesAnExpiredSessionAndKeepsTheSameDevice() async throws {
        let server = FakeRelay(), store = MemorySessionStore()
        let clock = Clock()
        let a = RelayClient(keys: .generate(), sessions: store, http: server, now: { clock.now })
        try await a.createHousehold()
        let first = store.load()!
        clock.now = clock.now.addingTimeInterval(4000)  // past expiry
        _ = try await a.selectAll()
        let second = store.load()!
        XCTAssertNotEqual(first.accessToken, second.accessToken)
        XCTAssertEqual(first.userId, second.userId)
        // A token the server dropped early is refreshed on the 401 and the call retried.
        server.users[second.accessToken] = nil
        _ = try await a.selectAll()
        XCTAssertEqual(store.load()!.userId, first.userId)
    }

    final class Clock: @unchecked Sendable { var now = Date(timeIntervalSince1970: 1_800_000_000) }

    /// Against the real DOYOURWORK relay, only when asked: `RELAY_LIVE=1 swift test --filter RelayLive`.
    /// Makes a throwaway household and deletes it again. The anonymous users it signs up stay behind
    /// in Authentication → Users.
    func testRelayLive() async throws {
        guard ProcessInfo.processInfo.environment["RELAY_LIVE"] == "1" else { throw XCTSkip("set RELAY_LIVE=1 to run against the real relay") }
        let keys = FamilyKeys.generate()
        let a = RelayClient(keys: keys, sessions: MemorySessionStore())
        try await a.createHousehold()
        do {
            let (code, expires) = try await a.makeJoinCode()
            XCTAssertGreaterThan(expires, Date().addingTimeInterval(500))
            let b = RelayClient(keys: try JoinCode(scanned: code.text).keys, sessions: MemorySessionStore())
            let joined = try await b.join(code)
            XCTAssertTrue(joined)
            _ = try await LogSync.run(api: a, local: [log("live-1")])
            _ = try await StateSync.run(api: a, local: ["players": LocalEntry(items: ["1|kid"], updatedAt: 5, dirty: true)])
            let logs = try await LogSync.run(api: b, local: [])
            XCTAssertEqual(logs.map(\.remoteId), ["live-1"])
            let state = try await StateSync.run(api: b, local: [:])
            XCTAssertEqual(state["players"]?.items, ["1|kid"])
            let stranger = RelayClient(keys: keys, sessions: MemorySessionStore())
            let seen = try await stranger.selectAll()
            XCTAssertTrue(seen.isEmpty)
        } catch { try? await a.deleteHousehold(); throw error }
        try await a.deleteHousehold()
    }
}
