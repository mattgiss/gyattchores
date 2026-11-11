import XCTest
@testable import GyattCore

final class SyncTests: XCTestCase {
    /// An in-memory stand-in for the `simple_logs` table.
    final class FakeLogs: LogAPI, @unchecked Sendable {
        var rows: [String: RemoteLog] = [:]
        var next = 1
        var dropUpdates = false
        func insert(_ log: ChoreLog) async throws -> RemoteLog {
            let r = RemoteLog(id: "srv\(next)", playerId: log.playerId, playerName: log.playerName, choreId: log.choreId, choreName: log.choreName,
                              points: log.points, status: log.status, createdAt: Date(timeIntervalSince1970: 5000))
            next += 1; rows[r.id] = r; return r
        }
        func updateStatus(remoteId: String, status: String) async throws -> Bool {
            guard !dropUpdates, let r = rows[remoteId] else { return false }
            rows[remoteId] = RemoteLog(id: r.id, playerId: r.playerId, playerName: r.playerName, choreId: r.choreId, choreName: r.choreName, points: r.points, status: status, createdAt: r.createdAt)
            return true
        }
        func selectAll() async throws -> [RemoteLog] { Array(rows.values) }
    }

    func local(_ id: String, _ status: String = "pending", remoteId: String? = nil, dirty: Bool = false) -> ChoreLog {
        ChoreLog(id: id, remoteId: remoteId, playerId: "1", playerName: "kid", choreId: "make-bed", choreName: "make bed", points: 8, minutes: 5,
                 status: status, timestamp: Date(timeIntervalSince1970: 1000), statusDirty: dirty)
    }
    func remote(_ id: String, _ status: String) -> RemoteLog {
        RemoteLog(id: id, playerId: "1", playerName: "kid", choreId: "make-bed", choreName: "make bed", points: 8, status: status, createdAt: Date(timeIntervalSince1970: 1000))
    }

    func testPushesNewLogsOnce() async throws {
        let api = FakeLogs()
        let first = try await LogSync.run(api: api, local: [local("a")])
        XCTAssertEqual(first.first?.remoteId, "srv1"); XCTAssertEqual(first.first?.minutes, 5)
        _ = try await LogSync.run(api: api, local: first)
        XCTAssertEqual(api.rows.count, 1, "a second pass must not insert again")
    }

    func testApprovalsFlowBothWays() async throws {
        let api = FakeLogs(); api.rows["x"] = remote("x", "pending")
        let pushed = try await LogSync.run(api: api, local: [local("a", "approved", remoteId: "x", dirty: true)])
        XCTAssertEqual(api.rows["x"]?.status, "approved"); XCTAssertEqual(pushed.first?.statusDirty, false)
        let pulled = try await LogSync.run(api: api, local: [local("b", "pending", remoteId: "x")])
        XCTAssertEqual(pulled.first?.status, "approved")
    }

    func testUnpushedLocalChangeBeatsRemote() async throws {
        let api = FakeLogs(); api.rows["x"] = remote("x", "pending"); api.dropUpdates = true
        let out = try await LogSync.run(api: api, local: [local("a", "rejected", remoteId: "x", dirty: true)])
        XCTAssertEqual(out.first?.status, "rejected"); XCTAssertEqual(out.first?.statusDirty, true)
    }

    func testPullsUnknownRowsAndReconciles() async throws {
        let api = FakeLogs(); api.rows["x"] = remote("x", "approved")
        let out = try await LogSync.run(api: api, local: [])
        XCTAssertEqual(out.first?.id, "r_x"); XCTAssertNil(out.first?.minutes)
        let merged = LogSync.reconcile(synced: [local("a", "pending", remoteId: "x")], latest: [local("a", "approved", remoteId: "x", dirty: true), local("b")])
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged.first { $0.id == "a" }?.status, "approved")
    }

    func testParsesPostgresTimestamps() {
        let d = Supabase.parseTime("2026-09-13T17:33:15.501793+00:00")
        XCTAssertEqual(d.timeIntervalSince1970, 1789320795.501, accuracy: 0.001)
        XCTAssertEqual(Supabase.parseTime("2026-09-13T17:33:15+00:00").timeIntervalSince1970, 1789320795, accuracy: 0.001)
    }

    final class FakeState: StateAPI, @unchecked Sendable {
        var rows: [String: RemoteEntry] = [:]
        func upsert(_ entry: RemoteEntry) async throws { rows[entry.key] = entry }
        func selectState() async throws -> [RemoteEntry] { Array(rows.values) }
    }

    func testStatePushesThenNewerRemoteWins() async throws {
        let api = FakeState(), key = "dare|1|2026-11-10"
        let mine = try await StateSync.run(api: api, local: [key: LocalEntry(items: ["2:make-bed"], updatedAt: 100, dirty: true)])
        XCTAssertEqual(api.rows[key]?.items, ["2:make-bed"]); XCTAssertEqual(mine[key]?.dirty, false)
        api.rows[key] = RemoteEntry(key: key, items: ["2:scrub-toilet"], updatedAt: 200)
        api.rows["players"] = RemoteEntry(key: "players", items: ["1:kid", "3:dad"], updatedAt: 150)
        let pulled = try await StateSync.run(api: api, local: mine)
        XCTAssertEqual(pulled[key]?.items, ["2:scrub-toilet"]); XCTAssertEqual(pulled["players"]?.items, ["1:kid", "3:dad"])
    }

    func testOlderRemoteDoesNotOverwrite() async throws {
        let api = FakeState(); api.rows["players"] = RemoteEntry(key: "players", items: ["1:old"], updatedAt: 50)
        let out = try await StateSync.run(api: api, local: ["players": LocalEntry(items: ["1:new"], updatedAt: 100)])
        XCTAssertEqual(out["players"]?.items, ["1:new"])
    }
}
