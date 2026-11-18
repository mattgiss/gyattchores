import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Where the relay lives. The app passes in the DOYOURWORK project's address (supabase/doyourwork/
/// 001_relay.sql); it isn't kept here, because the App Store build links DoYourWorkCore too and must not
/// contain a server address. The publishable key is public by design; the SQL's row-level security
/// decides access.
public struct RelayConfig: Sendable, Equatable {
    public let url: String, publishableKey: String
    public init(url: String, publishableKey: String) { self.url = url; self.publishableKey = publishableKey }
}

/// This device's anonymous sign-in. No email or password: just a random user id the server made.
public struct RelaySession: Codable, Sendable, Equatable {
    public var accessToken: String, refreshToken: String
    /// Seconds since 1970.
    public var expiresAt: Int64
    public var userId: String
    public init(accessToken: String, refreshToken: String, expiresAt: Int64, userId: String) {
        self.accessToken = accessToken; self.refreshToken = refreshToken; self.expiresAt = expiresAt; self.userId = userId
    }
}

/// Keeps the session between launches (the app uses the Keychain).
public protocol RelaySessionStore: Sendable {
    func load() -> RelaySession?
    func save(_ session: RelaySession)
}

public final class MemorySessionStore: RelaySessionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var session: RelaySession?
    public init(_ session: RelaySession? = nil) { self.session = session }
    public func load() -> RelaySession? { lock.lock(); defer { lock.unlock() }; return session }
    public func save(_ session: RelaySession) { lock.lock(); self.session = session; lock.unlock() }
}

/// The network, so tests can put an in-memory relay behind the client.
public protocol RelayHTTP: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, Int)
}

public struct URLSessionHTTP: RelayHTTP {
    public init() {}
    public func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, resp) = try await URLSession.shared.data(for: request)
        return (data, (resp as? HTTPURLResponse)?.statusCode ?? 0)
    }
}

public enum RelayError: Error, Equatable {
    case http(Int, String)
    case badResponse
}

/// A phone that joined the household, as the server lists it.
public struct RelayDevice: Sendable, Equatable {
    public let userId: String, joinedAt: Date
}

/// The relay transport (docs/design/encrypted-relay-join.md): the same `LogAPI` and `StateAPI` the
/// old plain tables offered, so `LogSync` and `StateSync` keep their rules, but every record is
/// sealed with the family key before it leaves the phone. Android's `Relay.kt` is the same.
public actor RelayClient: LogAPI, StateAPI {
    public nonisolated let keys: FamilyKeys
    private let config: RelayConfig
    private let sessions: RelaySessionStore
    private let http: RelayHTTP
    private let now: @Sendable () -> Date
    /// Records the last pull skipped because they wouldn't open. Zero unless something is wrong.
    public private(set) var unreadable = 0

    public init(keys: FamilyKeys, config: RelayConfig, sessions: RelaySessionStore,
                http: RelayHTTP = URLSessionHTTP(), now: @escaping @Sendable () -> Date = { Date() }) {
        self.keys = keys; self.config = config; self.sessions = sessions; self.http = http; self.now = now
    }

    private var household: String { keys.householdUUID.uuidString.lowercased() }

    // MARK: Household

    /// This device's anonymous user id, signing in first if it hasn't yet.
    public func userId() async throws -> String { try await session().userId }

    /// The first "Add a phone": puts the household on the server with this device in it.
    public func createHousehold() async throws {
        _ = try await rpc("create_household", ["p_household": household])
    }

    /// A one-time code for another phone to scan, good for 10 minutes. Only members can make one.
    public func makeJoinCode() async throws -> (code: JoinCode, expires: Date) {
        let code = JoinCode.make(for: keys)
        let out = try await rpc("create_join_token", ["p_household": household, "p_token_hash": Self.bytea(code.tokenHash)])
        guard let s = try JSONSerialization.jsonObject(with: out, options: .fragmentsAllowed) as? String else { throw RelayError.badResponse }
        return (code, PostgresTime.parse(s))
    }

    /// The scanning phone joins with the code it read. False if the code was wrong, used or expired.
    public func join(_ code: JoinCode) async throws -> Bool {
        let out = try await rpc("join_household", ["p_household": household, "p_token": Self.bytea(code.token)])
        guard let ok = try JSONSerialization.jsonObject(with: out, options: .fragmentsAllowed) as? Bool else { throw RelayError.badResponse }
        return ok
    }

    public func devices() async throws -> [RelayDevice] {
        struct Row: Decodable { let user_id: String, joined_at: String }
        let rows = try JSONDecoder().decode([Row].self, from: try await rest("GET", "household_devices?household_id=eq.\(household)&select=user_id,joined_at&order=joined_at.asc"))
        return rows.map { RelayDevice(userId: $0.user_id, joinedAt: PostgresTime.parse($0.joined_at)) }
    }

    /// Admin → Phones → Remove. That phone can't fetch anything new afterwards.
    public func removeDevice(userId: String) async throws {
        _ = try await rpc("remove_device", ["p_household": household, "p_user": userId])
    }

    /// False once this phone was removed, or the family was deleted from the server. Reads then
    /// come back empty rather than failing, so a sync pass asks this first.
    public func isMember() async throws -> Bool {
        let out = try await rpc("is_member", ["h": household])
        guard let ok = try JSONSerialization.jsonObject(with: out, options: .fragmentsAllowed) as? Bool else { throw RelayError.badResponse }
        return ok
    }

    /// Admin → "Delete this family from the server": the household and every record go.
    public func deleteHousehold() async throws {
        _ = try await rpc("delete_household", ["p_household": household])
    }

    // MARK: LogAPI

    struct LogPayload: Codable {
        let id: String, playerId: String, playerName: String, choreId: String, choreName: String
        let points: Int, minutes: Int?, status: String
        /// Milliseconds since 1970.
        let timestamp: Int64
    }

    private func sealLog(_ log: ChoreLog, rowId: String) throws -> Record {
        let ms = Int64((log.timestamp.timeIntervalSince1970 * 1000).rounded())
        let p = LogPayload(id: rowId, playerId: log.playerId, playerName: log.playerName, choreId: log.choreId, choreName: log.choreName,
                           points: log.points, minutes: log.minutes, status: log.status, timestamp: ms)
        return Record(household_id: household, kind: "log", row_id: rowId,
                      ciphertext: try keys.seal(JSONEncoder().encode(p), kind: "log", rowId: rowId), client_updated_at: Int64(now().timeIntervalSince1970 * 1000))
    }

    /// A log keeps its own id as its row id, and its own date.
    public func insert(_ log: ChoreLog) async throws -> RemoteLog {
        let rowId = log.remoteId ?? log.id
        _ = try await rest("POST", "records?on_conflict=household_id,kind,row_id", body: [try sealLog(log, rowId: rowId)],
                           prefer: "resolution=merge-duplicates,return=minimal")
        return RemoteLog(id: rowId, playerId: log.playerId, playerName: log.playerName, choreId: log.choreId, choreName: log.choreName,
                         points: log.points, status: log.status, createdAt: log.timestamp, minutes: log.minutes)
    }

    public func updateStatus(_ log: ChoreLog) async throws -> Bool {
        guard let rowId = log.remoteId else { return false }
        let r = try sealLog(log, rowId: rowId)
        let out = try await rest("PATCH", "records?household_id=eq.\(household)&kind=eq.log&row_id=eq.\(Self.query(rowId))",
                                 body: ["ciphertext": .string(r.ciphertext), "client_updated_at": .int(r.client_updated_at)] as [String: JSONValue],
                                 prefer: "return=representation")
        return !((try JSONSerialization.jsonObject(with: out) as? [Any]) ?? []).isEmpty
    }

    public func selectAll() async throws -> [RemoteLog] {
        var bad = 0
        let logs: [RemoteLog] = try await pull(kind: "log").compactMap { r in
            guard let data = try? keys.open(r.ciphertext, kind: "log", rowId: r.row_id),
                  let p = try? JSONDecoder().decode(LogPayload.self, from: data), p.id == r.row_id else { bad += 1; return nil }
            return RemoteLog(id: r.row_id, playerId: p.playerId, playerName: p.playerName, choreId: p.choreId, choreName: p.choreName,
                             points: p.points, status: p.status, createdAt: Date(timeIntervalSince1970: Double(p.timestamp) / 1000), minutes: p.minutes)
        }
        unreadable = bad
        return logs
    }

    // MARK: StateAPI

    struct StatePayload: Codable { let key: String, items: [String], updatedAt: Int64 }

    public func upsert(_ entry: RemoteEntry) async throws {
        let rowId = keys.stateRowId(entry.key)
        let sealed = try keys.seal(JSONEncoder().encode(StatePayload(key: entry.key, items: entry.items, updatedAt: entry.updatedAt)), kind: "state", rowId: rowId)
        _ = try await rest("POST", "records?on_conflict=household_id,kind,row_id",
                           body: [Record(household_id: household, kind: "state", row_id: rowId, ciphertext: sealed, client_updated_at: entry.updatedAt)],
                           prefer: "resolution=merge-duplicates,return=minimal")
    }

    public func selectState() async throws -> [RemoteEntry] {
        var bad = 0
        let entries: [RemoteEntry] = try await pull(kind: "state").compactMap { r in
            guard let data = try? keys.open(r.ciphertext, kind: "state", rowId: r.row_id),
                  let p = try? JSONDecoder().decode(StatePayload.self, from: data), keys.stateRowId(p.key) == r.row_id else { bad += 1; return nil }
            return RemoteEntry(key: p.key, items: p.items, updatedAt: p.updatedAt)
        }
        unreadable += bad
        return entries
    }

    // MARK: Wire

    struct Record: Codable {
        let household_id: String, kind: String, row_id: String, ciphertext: String, client_updated_at: Int64
    }

    private func pull(kind: String) async throws -> [Record] {
        // PostgREST caps a response at 1000 rows, so page through.
        var all: [Record] = []
        while true {
            let page = try JSONDecoder().decode([Record].self, from: try await rest("GET",
                "records?household_id=eq.\(household)&kind=eq.\(kind)&select=household_id,kind,row_id,ciphertext,client_updated_at&order=row_id.asc&limit=1000&offset=\(all.count)"))
            all += page
            if page.count < 1000 { return all }
        }
    }

    private func rpc(_ name: String, _ args: [String: String]) async throws -> Data {
        try await rest("POST", "rpc/\(name)", body: args, prefer: "return=representation")
    }

    private func rest<B: Encodable>(_ method: String, _ path: String, body: B?, prefer: String) async throws -> Data {
        try await authed(method, "/rest/v1/\(path)", body: body.map { try JSONEncoder().encode($0) }, prefer: prefer)
    }

    private func rest(_ method: String, _ path: String) async throws -> Data {
        try await authed(method, "/rest/v1/\(path)", body: nil, prefer: nil)
    }

    /// Signs in if needed, and on a 401 refreshes the session once and tries again.
    private func authed(_ method: String, _ path: String, body: Data?, prefer: String?) async throws -> Data {
        var s = try await session()
        for attempt in 0..<2 {
            let (data, code) = try await send(method, path, body: body, token: s.accessToken, prefer: prefer)
            if (200...299).contains(code) { return data }
            if code == 401 && attempt == 0 { s = try await refresh(s); continue }
            throw RelayError.http(code, String(decoding: data.prefix(300), as: UTF8.self))
        }
        throw RelayError.badResponse
    }

    private func send(_ method: String, _ path: String, body: Data?, token: String?, prefer: String?) async throws -> (Data, Int) {
        guard let url = URL(string: config.url + path) else { throw RelayError.badResponse }
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.httpMethod = method
        req.setValue(config.publishableKey, forHTTPHeaderField: "apikey")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
            req.httpBody = body
        }
        return try await http.send(req)
    }

    // MARK: Session

    private struct AuthResponse: Decodable {
        struct User: Decodable { let id: String }
        let access_token: String, refresh_token: String, expires_in: Int64, user: User
    }

    private func session() async throws -> RelaySession {
        guard let s = sessions.load() else { return try await signUp() }
        if s.expiresAt - 60 <= Int64(now().timeIntervalSince1970) { return try await refresh(s) }
        return s
    }

    private func signUp() async throws -> RelaySession {
        try await auth("/auth/v1/signup", body: Data("{}".utf8))
    }

    private func refresh(_ s: RelaySession) async throws -> RelaySession {
        try await auth("/auth/v1/token?grant_type=refresh_token", body: try JSONEncoder().encode(["refresh_token": s.refreshToken]))
    }

    private func auth(_ path: String, body: Data) async throws -> RelaySession {
        let (data, code) = try await send("POST", path, body: body, token: nil, prefer: nil)
        guard (200...299).contains(code) else { throw RelayError.http(code, String(decoding: data.prefix(300), as: UTF8.self)) }
        let r = try JSONDecoder().decode(AuthResponse.self, from: data)
        let s = RelaySession(accessToken: r.access_token, refreshToken: r.refresh_token,
                             expiresAt: Int64(now().timeIntervalSince1970) + r.expires_in, userId: r.user.id)
        sessions.save(s)
        return s
    }

    // MARK: Helpers

    static func bytea(_ d: Data) -> String { "\\x" + d.map { String(format: "%02x", $0) }.joined() }

    static func query(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-_.~"))) ?? s
    }
}

/// Just enough JSON for a PATCH body with mixed value types.
enum JSONValue: Encodable {
    case string(String), int(Int64)
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .string(let s): try c.encode(s); case .int(let i): try c.encode(i) }
    }
}
