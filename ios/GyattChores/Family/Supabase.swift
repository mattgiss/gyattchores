#if FAMILY_SYNC
import Foundation
import GyattCore

/// Family build only (`FAMILY_SYNC`): the app has no network code at all.
/// The same Supabase project and publishable (anon) key the web app ships in `index.html`.
/// The key is by design; access is governed by the tables' row-level-security policies.
enum SyncConfig {
    /// Debug builds under `-uiTesting` only: `-syncURL http://127.0.0.1:8789` points sync at a test
    /// server instead of the family's, so sync can be tested end to end without touching real data.
    static var testURL: String? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-uiTesting"), let i = args.firstIndex(of: "-syncURL"), i + 1 < args.count else { return nil }
        return args[i + 1]
        #else
        return nil
        #endif
    }

    static let url = "https://ukshxdoqgwoxobjdclpx.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVrc2h4ZG9xZ3dveG9iamRjbHB4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3MjI2NDEsImV4cCI6MjA4MDI5ODY0MX0.UGNrsfG6goEA0PPWG4x7gxBueA7D5Oe9uWI-iCXIar0"
}

enum SupabaseError: Error { case http(Int) }

/// Minimal PostgREST client over URLSession.
struct Supabase: LogAPI, StateAPI {
    let baseURL: String, key: String
    init(baseURL: String = SyncConfig.testURL ?? SyncConfig.url, key: String = SyncConfig.anonKey) { self.baseURL = baseURL; self.key = key }

    private struct LogRow: Codable {
        var id: String?
        var player_id: String, player_name: String, chore_id: String, chore_name: String
        var chore_icon: String? = ""
        var points: Int = 0
        var status: String
        var created_at: String?
        var remote: RemoteLog {
            RemoteLog(id: id ?? "", playerId: player_id, playerName: player_name, choreId: chore_id, choreName: chore_name,
                      points: points, status: status, createdAt: PostgresTime.parse(created_at))
        }
    }
    private struct StateRow: Codable { var key: String, items: [String], updated_at: String }

    func insert(_ log: ChoreLog) async throws -> RemoteLog {
        // Every log keeps the date it was made on this device: one made offline, or brought in from
        // a backup, mustn't land on the day it happened to reach the server. Android does the same.
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let createdAt: String? = iso.string(from: log.timestamp)
        let row = LogRow(id: nil, player_id: log.playerId, player_name: log.playerName, chore_id: log.choreId, chore_name: log.choreName, points: log.points, status: log.status, created_at: createdAt)
        let out: [LogRow] = try await call("POST", "simple_logs", body: row)
        guard let first = out.first else { throw SupabaseError.http(0) }
        return first.remote
    }

    func updateStatus(_ log: ChoreLog) async throws -> Bool {
        guard let remoteId = log.remoteId else { return false }
        let out: [LogRow] = try await call("PATCH", "simple_logs?id=eq.\(remoteId)", body: ["status": log.status])
        return !out.isEmpty
    }

    func selectAll() async throws -> [RemoteLog] {
        // PostgREST caps a response at 1000 rows, so page through.
        var all: [RemoteLog] = []
        while true {
            let page: [LogRow] = try await call("GET", "simple_logs?select=*&order=created_at.desc,id.asc&limit=1000&offset=\(all.count)", body: nil as String?)
            all += page.map(\.remote)
            if page.count < 1000 { return all }
        }
    }

    func upsert(_ entry: RemoteEntry) async throws {
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let row = StateRow(key: entry.key, items: entry.items, updated_at: iso.string(from: Date(timeIntervalSince1970: Double(entry.updatedAt) / 1000)))
        _ = try await raw("POST", "family_state?on_conflict=key", body: [row], prefer: "resolution=merge-duplicates,return=minimal")
    }

    func selectState() async throws -> [RemoteEntry] {
        let rows: [StateRow] = try await call("GET", "family_state?select=*", body: nil as String?)
        return rows.map { RemoteEntry(key: $0.key, items: $0.items, updatedAt: Int64(PostgresTime.parse($0.updated_at).timeIntervalSince1970 * 1000)) }
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
}
#endif
