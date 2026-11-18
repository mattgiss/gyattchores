import Foundation
import Security
import DoYourWorkCore

extension RelayConfig {
    /// The DOYOURWORK relay: its own Supabase project, holding only sealed records.
    static let doyourwork = RelayConfig(url: "https://omemognwvcnonnzjmcxm.supabase.co",
                                        publishableKey: "sb_publishable_prXq51_BMc8lnG4BY5vXmA_xJysoZxa")
}

/// Where this phone keeps its place in the encrypted relay: the family's keys and its anonymous
/// sign-in. Both are in the Keychain, marked this-device-only so they never spread through iCloud
/// Keychain or into a backup another phone could restore (docs/design/encrypted-relay-join.md).
enum RelayVault {
    private static let service = "com.doyourwork.relay"
    /// Where the keys were kept before the app was renamed; moved over once (`migrate`).
    private static let legacyService = "com.gyattchores.relay"
    /// UI tests keep their own entries, so a test run never touches the real ones.
    private static func account(_ name: String) -> String { AppStore.uiTesting ? "ui-testing.\(name)" : name }

    /// The relay client for this phone, or nil if it hasn't added or joined a phone yet.
    static func client() -> RelayClient? {
        migrate()
        guard let raw = read("keys"), raw.count == 48, let keys = try? FamilyKeys(household: raw.prefix(16), familyKey: raw.suffix(32)) else { return nil }
        return client(keys)
    }

    static func client(_ keys: FamilyKeys) -> RelayClient {
        // UI tests never reach the real relay: they get one in memory, shared by everything in the app.
        AppStore.uiTesting ? RelayClient(keys: keys, config: MemoryRelay.config, sessions: KeychainSessionStore(), http: memory)
                           : RelayClient(keys: keys, config: .doyourwork, sessions: KeychainSessionStore())
    }

    static let memory = MemoryRelay()

    static func save(_ keys: FamilyKeys) { write("keys", keys.household + keys.familyKey) }

    static func clear() {
        delete("keys"); delete("session")
        // And any left under the old name, so they can't be moved back later.
        for name in ["keys", "session"] {
            var q = query(name); q[kSecAttrService as String] = legacyService
            SecItemDelete(q as CFDictionary)
        }
    }

    struct KeychainSessionStore: RelaySessionStore {
        func load() -> RelaySession? { read("session").flatMap { try? JSONDecoder().decode(RelaySession.self, from: $0) } }
        func save(_ session: RelaySession) { if let d = try? JSONEncoder().encode(session) { write("session", d) } }
    }

    // MARK: Keychain

    private static func query(_ name: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account(name)]
    }

    fileprivate static func read(_ name: String) -> Data? {
        var q = query(name)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        return SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess ? out as? Data : nil
    }

    fileprivate static func write(_ name: String, _ data: Data) {
        let q = query(name)
        let attrs: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        if SecItemUpdate(q as CFDictionary, attrs as CFDictionary) == errSecItemNotFound {
            SecItemAdd(q.merging(attrs) { _, new in new } as CFDictionary, nil)
        }
    }

    private static func delete(_ name: String) { SecItemDelete(query(name) as CFDictionary) }

    /// Moves the keys and sign-in saved under the old service name, the first time.
    private static func migrate() {
        for name in ["keys", "session"] where read(name) == nil {
            var q = query(name)
            q[kSecAttrService as String] = legacyService
            var copy = q
            copy[kSecReturnData as String] = true
            copy[kSecMatchLimit as String] = kSecMatchLimitOne
            var out: AnyObject?
            guard SecItemCopyMatching(copy as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { continue }
            write(name, data)
            if read(name) == data { SecItemDelete(q as CFDictionary) }
        }
    }
}

/// What came of scanning a code on the phone that's joining.
enum JoinOutcome: Equatable {
    case joined, notACode, usedOrExpired, offline

    var message: String? {
        switch self {
        case .joined: nil
        case .notACode: "That isn't a DOYOURWORK code."
        case .usedOrExpired: "That code has expired or was already used. Ask for a new one."
        case .offline: "Can't reach the server. Check the connection and try again."
        }
    }
}

extension AppStore {
    var isLinked: Bool { relay != nil }

    /// Admin → "Add a phone". The first time, this phone puts the family on the relay: a new
    /// household and family key, and everything here goes up encrypted. Then, and every time
    /// after, a one-time code for the other phone to scan, good for 10 minutes.
    func addPhone() async throws -> (code: JoinCode, expires: Date) {
        if relay == nil {
            let keys = FamilyKeys.generate(), client = RelayVault.client(keys)
            try await client.createHousehold()
            RelayVault.save(keys)
            switchTransport(to: client)
            logs = LogSync.forNewServer(logs)
            shared = StateSync.forNewServer(shared)
            requestSync()
        }
        return try await relay!.makeJoinCode()
    }

    /// This phone scanned a code. On success it takes the family from the relay: what it had is
    /// dropped, and it loads afresh. Whose phone it is stays.
    func joinFamily(scanned text: String) async -> JoinOutcome {
        guard let code = try? JoinCode(scanned: text) else { return .notACode }
        let client = RelayVault.client(code.keys)
        do {
            guard try await client.join(code) else { return .usedOrExpired }
        } catch { return .offline }
        RelayVault.save(code.keys)
        switchTransport(to: client)
        logs = []; shared = [:]; cards = [:]; removedIds = []
        members = []
        // Set up or not is now the joined family's: it is once its admin arrives.
        settings.setUp = false
        hasSynced = false
        requestSync()
        return .joined
    }

    /// The family's phones, oldest first, and which one is this.
    func phones() async throws -> (mine: String, all: [RelayDevice]) {
        guard let relay else { return ("", []) }
        return (try await relay.userId(), try await relay.devices())
    }

    func removePhone(_ userId: String) async throws { try await relay?.removeDevice(userId: userId) }

    /// Admin → "Delete this family from the server": the household and everything sent go, for
    /// every phone. The family stays on this phone, which is no longer linked.
    func deleteFromServer() async throws {
        guard let relay else { return }
        try await relay.deleteHousehold()
        leaveRelay()
    }

    /// Forgets the relay (its keys and sign-in) and keeps everything else on this phone.
    func leaveRelay() {
        RelayVault.clear()
        relay = nil
        transport += 1
        syncStatus = "local"
    }

    private func switchTransport(to client: RelayClient) {
        relay = client
        transport += 1
        objectWillChange.send()
    }

    #if DEBUG
    /// UI tests (`-scanResult seeded`): another phone in the in-memory relay, with a small family on
    /// it, shows a code. Returns that code, as if this phone's camera had read it.
    func seededJoinCode() async -> String {
        // Its own sign-in: it's a different phone from this one.
        let first = RelayClient(keys: FamilyKeys.generate(), config: MemoryRelay.config, sessions: MemorySessionStore(), http: RelayVault.memory)
        // `-seededDeletes`: a few seconds after this phone joins, the other phone deletes the
        // family from the server, so a test sees this one find out on its next pass.
        if Self.launchArguments.contains("-seededDeletes") {
            Task { try? await Task.sleep(for: .seconds(4)); try? await first.deleteHousehold() }
        }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let family = FamilyState.Family(
            members: [Player(id: "1", name: "pat", isAdmin: true, plays: false), Player(id: "2", name: "jules"), Player(id: "3", name: "kai")],
            chores: starterChores, codes: ["1": AdminCode(Self.demoAdminCode)!], nextPlayerId: 4)
        let state = FamilyState.encode(family).mapValues { LocalEntry(items: $0, updatedAt: now, dirty: true) }
        let log = ChoreLog(id: "seed1", playerId: "2", playerName: "jules", choreId: starterChores[0].id, choreName: starterChores[0].name,
                           points: starterChores[0].pts, minutes: 5, status: Status.approved, timestamp: Date())
        do {
            try await first.createHousehold()
            _ = try await StateSync.run(api: first, local: state)
            _ = try await LogSync.run(api: first, local: [log])
            return try await first.makeJoinCode().code.text
        } catch { return "" }
    }
    #endif
}
