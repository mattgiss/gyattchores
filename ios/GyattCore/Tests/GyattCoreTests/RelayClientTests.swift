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

/// The tests use the same in-memory relay the app's UI tests do.
typealias FakeRelay = MemoryRelay

extension RelayConfig {
    /// The real project, for `testRelayLive` only (the app keeps its own copy in RelayLink.swift).
    static let live = RelayConfig(url: "https://omemognwvcnonnzjmcxm.supabase.co", publishableKey: "sb_publishable_prXq51_BMc8lnG4BY5vXmA_xJysoZxa")
}

final class RelayClientTests: XCTestCase {
    func log(_ id: String, _ status: String = "pending", remoteId: String? = nil, dirty: Bool = false) -> ChoreLog {
        ChoreLog(id: id, remoteId: remoteId, playerId: "1", playerName: "kid", choreId: "make-bed", choreName: "make bed", points: 8, minutes: 5,
                 status: status, timestamp: Date(timeIntervalSince1970: 1_731_700_000.123), statusDirty: dirty)
    }

    /// Two phones in one family, sharing the fake relay.
    func family() async throws -> (FakeRelay, RelayClient, RelayClient) {
        let server = FakeRelay(), keys = FamilyKeys.generate()
        let a = RelayClient(keys: keys, config: MemoryRelay.config, sessions: MemorySessionStore(), http: server)
        try await a.createHousehold()
        let (code, _) = try await a.makeJoinCode()
        let scanned = try JoinCode(scanned: code.text)
        let b = RelayClient(keys: scanned.keys, config: MemoryRelay.config, sessions: MemorySessionStore(), http: server)
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

    /// The first "Add a phone" on a phone that synced with the old tables: its logs carry the old
    /// server's ids and its state is clean, yet all of it has to reach the new household.
    func testMovingAFamilyOverUploadsEverything() async throws {
        let (_, a, b) = try await family()
        let old = [log("l1", "approved", remoteId: "9f0c-old-uuid"), log("l2", "rejected", remoteId: "aa11-old", dirty: true)]
        let oldState = ["players": LocalEntry(items: ["1:kid"], updatedAt: 5, dirty: false)]
        let onA = try await LogSync.run(api: a, local: LogSync.forNewServer(old))
        XCTAssertEqual(onA.map(\.remoteId), ["l1", "l2"], "each log goes up under its own id")
        _ = try await StateSync.run(api: a, local: StateSync.forNewServer(oldState))

        let onB = try await LogSync.run(api: b, local: [])
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: onB.map { ($0.remoteId!, $0.status) }), ["l1": "approved", "l2": "rejected"])
        let stateB = try await StateSync.run(api: b, local: [:])
        XCTAssertEqual(stateB["players"], LocalEntry(items: ["1:kid"], updatedAt: 5, dirty: false), "state keeps its own date")
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
        let stranger = RelayClient(keys: a.keys, config: MemoryRelay.config, sessions: MemorySessionStore(), http: server)
        let pulled = try await stranger.selectAll()
        XCTAssertTrue(pulled.isEmpty)
        do { _ = try await stranger.insert(log("evil")); XCTFail("an outsider must not write") } catch RelayError.http(let code, _) { XCTAssertEqual(code, 403) }
        do { _ = try await stranger.makeJoinCode(); XCTFail("an outsider must not make codes") } catch RelayError.http(let code, _) { XCTAssertEqual(code, 403) }
    }

    func testJoinCodesWorkOnceAndExpire() async throws {
        let (server, a, _) = try await family()
        let (code, _) = try await a.makeJoinCode()
        let c = RelayClient(keys: code.keys, config: MemoryRelay.config, sessions: MemorySessionStore(), http: server)
        let d = RelayClient(keys: code.keys, config: MemoryRelay.config, sessions: MemorySessionStore(), http: server)
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
        let a = RelayClient(keys: .generate(), config: MemoryRelay.config, sessions: store, http: server, now: { clock.now })
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
        let a = RelayClient(keys: keys, config: .live, sessions: MemorySessionStore())
        try await a.createHousehold()
        do {
            let (code, expires) = try await a.makeJoinCode()
            XCTAssertGreaterThan(expires, Date().addingTimeInterval(500))
            let b = RelayClient(keys: try JoinCode(scanned: code.text).keys, config: .live, sessions: MemorySessionStore())
            let joined = try await b.join(code)
            XCTAssertTrue(joined)
            _ = try await LogSync.run(api: a, local: [log("live-1")])
            _ = try await StateSync.run(api: a, local: ["players": LocalEntry(items: ["1|kid"], updatedAt: 5, dirty: true)])
            let logs = try await LogSync.run(api: b, local: [])
            XCTAssertEqual(logs.map(\.remoteId), ["live-1"])
            let state = try await StateSync.run(api: b, local: [:])
            XCTAssertEqual(state["players"]?.items, ["1|kid"])
            let stranger = RelayClient(keys: keys, config: .live, sessions: MemorySessionStore())
            let seen = try await stranger.selectAll()
            XCTAssertTrue(seen.isEmpty)
        } catch { try? await a.deleteHousehold(); throw error }
        try await a.deleteHousehold()
    }
}
