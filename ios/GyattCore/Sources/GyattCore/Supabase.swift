import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking   // URLSession lives here on Linux, where CI runs these tests
#endif

/// The same Supabase project and publishable (anon) key the web app ships in `index.html`.
/// The key is public by design; access is governed by the tables' row-level-security policies.
public enum SyncConfig {
    public static let url = "https://ukshxdoqgwoxobjdclpx.supabase.co"
    public static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVrc2h4ZG9xZ3dveG9iamRjbHB4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3MjI2NDEsImV4cCI6MjA4MDI5ODY0MX0.UGNrsfG6goEA0PPWG4x7gxBueA7D5Oe9uWI-iCXIar0"
}

public enum SupabaseError: Error { case http(Int) }

/// Minimal PostgREST client over URLSession.
public struct Supabase: LogAPI, StateAPI {
    let baseURL: String, key: String
    public init(baseURL: String = SyncConfig.url, key: String = SyncConfig.anonKey) { self.baseURL = baseURL; self.key = key }

    private struct LogRow: Codable {
        var id: String?
        var player_id: String, player_name: String, chore_id: String, chore_name: String
        var chore_icon: String? = ""
        var points: Int = 0
        var status: String
        var created_at: String?
        var remote: RemoteLog {
            RemoteLog(id: id ?? "", playerId: player_id, playerName: player_name, choreId: chore_id, choreName: chore_name,
                      points: points, status: status, createdAt: Supabase.parseTime(created_at))
        }
    }
    private struct StateRow: Codable { var key: String, items: [String], updated_at: String }

    public func insert(_ log: ChoreLog) async throws -> RemoteLog {
        let row = LogRow(id: nil, player_id: log.playerId, player_name: log.playerName, chore_id: log.choreId, chore_name: log.choreName, points: log.points, status: log.status, created_at: nil)
        let out: [LogRow] = try await call("POST", "simple_logs", body: row)
        guard let first = out.first else { throw SupabaseError.http(0) }
        return first.remote
    }

    public func updateStatus(remoteId: String, status: String) async throws -> Bool {
        let out: [LogRow] = try await call("PATCH", "simple_logs?id=eq.\(remoteId)", body: ["status": status])
        return !out.isEmpty
    }

    public func selectAll() async throws -> [RemoteLog] {
        // PostgREST caps a response at 1000 rows, so page through.
        var all: [RemoteLog] = []
        while true {
            let page: [LogRow] = try await call("GET", "simple_logs?select=*&order=created_at.desc,id.asc&limit=1000&offset=\(all.count)", body: nil as String?)
            all += page.map(\.remote)
            if page.count < 1000 { return all }
        }
    }

    public func upsert(_ entry: RemoteEntry) async throws {
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let row = StateRow(key: entry.key, items: entry.items, updated_at: iso.string(from: Date(timeIntervalSince1970: Double(entry.updatedAt) / 1000)))
        _ = try await raw("POST", "family_state?on_conflict=key", body: [row], prefer: "resolution=merge-duplicates,return=minimal")
    }

    public func selectState() async throws -> [RemoteEntry] {
        let rows: [StateRow] = try await call("GET", "family_state?select=*", body: nil as String?)
        return rows.map { RemoteEntry(key: $0.key, items: $0.items, updatedAt: Int64(Supabase.parseTime($0.updated_at).timeIntervalSince1970 * 1000)) }
    }

    private func call<B: Encodable, R: Decodable>(_ method: String, _ path: String, body: B?) async throws -> R {
        let data = try await raw(method, path, body: body, prefer: "return=representation")
        return try JSONDecoder().decode(R.self, from: data.isEmpty ? Data("[]".utf8) : data)
    }

    private func raw<B: Encodable>(_ method: String, _ path: String, body: B?, prefer: String) async throws -> Data {
        var req = URLRequest(url: URL(string: "\(baseURL)/rest/v1/\(path)")!, timeoutInterval: 20)
        req.httpMethod = method
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(prefer, forHTTPHeaderField: "Prefer")
            req.httpBody = try JSONEncoder().encode(body)
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(code) else { throw SupabaseError.http(code) }
        return data
    }

    /// Postgres timestamps carry microseconds ("…15.501793+00:00"); trim to milliseconds before parsing.
    static func parseTime(_ s: String?) -> Date {
        guard var s else { return Date() }
        if let dot = s.firstIndex(of: ".") {
            let after = s[s.index(after: dot)...]
            let digits = after.prefix { $0.isNumber }
            let rest = after.dropFirst(digits.count)
            s = s[..<dot] + "." + digits.prefix(3).padding(toLength: 3, withPad: "0", startingAt: 0) + rest
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = f.date(from: s) { return d }
        }
        return ISO8601DateFormatter().date(from: s) ?? Date()
    }
}
