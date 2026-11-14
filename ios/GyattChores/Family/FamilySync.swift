#if FAMILY_SYNC
import Foundation
import GyattCore

/// The family build's sync: the same passes as the Android app's family flavor (and the web app).
///
/// - Chore logs go to `simple_logs`; the server's status wins unless a change made here hasn't
///   reached it yet.
/// - Players, display names, admin codes, the chore list and dares go to `family_state`, keyed as
///   `FamilyState` describes; the last device to change a key wins.
///
/// Every change is saved here first and never waits on the network. Under `-uiTesting` sync is off,
/// so a test run can't read or write the family's real chores.
extension AppStore {
    /// One pass at a time; a request that arrives mid-pass runs one follow-up pass instead of overlapping.
    func requestSync() {
        if Self.uiTesting { syncStatus = "off (ui testing)"; return }
        if syncing { syncAgain = true; return }
        syncing = true
        syncStatus = "syncing"
        let logSnapshot = logs, stateSnapshot = shared
        Task {
            do {
                let synced = try await LogSync.run(api: api, local: logSnapshot)
                // Taken off the list: their rows stay on the server but not on this device.
                logs = LogSync.reconcile(synced: synced, latest: logs).filter { !removedIds.contains($0.playerId) }
                let st = try await StateSync.run(api: api, local: stateSnapshot)
                shared = StateSync.reconcile(synced: st, latest: shared)
                applyShared()
                logs.removeAll { removedIds.contains($0.playerId) }
                adoptPlayersFromLogs()
                hasSynced = true
                syncStatus = "synced"
            } catch {
                syncStatus = "offline"
            }
            syncing = false
            if syncAgain { syncAgain = false; requestSync() }
        }
    }

    /// Players, chores or codes changed here: write them to the shared state and send them.
    func familyChanged() {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let theirChores = FamilyState.decode(shared.mapValues(\.items)).chores ?? starterChores
        for (key, items) in FamilyState.encode(currentFamily) where (shared[key]?.items ?? []) != items {
            // Android writes the same chores as differently ordered JSON: only a real change counts.
            if key == FamilyState.chores, theirChores == pool { continue }
            // An emptied list is kept (not removed) so "cleared" also reaches other devices.
            shared[key] = LocalEntry(items: items, updatedAt: now, dirty: true)
        }
        requestSync()
    }

    /// The family as this device has it now.
    private var currentFamily: FamilyState.Family {
        FamilyState.Family(members: members, chores: pool, codes: settings.adminCodes, removed: removedIds,
                           choreAdded: settings.choreAdded, memberJoined: settings.memberJoined,
                           nextPlayerId: max(settings.nextPlayerId, familyNextId))
    }

    /// A chore was logged or its status changed: send it.
    func logsChanged() { requestSync() }

    /// Takes in what other devices changed. Keys with changes of our own still waiting to go out
    /// hold our version in `shared`, so a pass never undoes something done on this device.
    func applyShared() {
        let family = FamilyState.decode(shared.mapValues(\.items))
        removedIds = family.removed
        // A family synced only by older apps has no "players" key yet; keep the list we have then.
        if shared[FamilyState.players] != nil || shared[FamilyState.staff] != nil, family.members != members {
            members = family.members
        }
        if let chores = family.chores, chores != pool { pool = chores }
        var next = settings
        next.adminCodes = family.codes
        next.choreAdded.merge(family.choreAdded) { _, theirs in theirs }
        next.memberJoined.merge(family.memberJoined) { _, theirs in theirs }
        next.nextPlayerId = max(next.nextPlayerId, family.nextPlayerId ?? 1)
        if next.adminCodes != settings.adminCodes || next.choreAdded != settings.choreAdded
            || next.memberJoined != settings.memberJoined || next.nextPlayerId != settings.nextPlayerId {
            settings = next
        }
    }

    /// Adds players who have logs on the server but aren't on the list here (an older device added
    /// them), so their chores show up. Players taken off the list stay off.
    private func adoptPlayersFromLogs() {
        var known = Set(members.map(\.id)).union(removedIds)
        var fresh: [Player] = []
        for l in logs.sorted(by: { $0.timestamp > $1.timestamp }) where known.insert(l.playerId).inserted {
            fresh.append(Player(id: l.playerId, name: l.playerName))
        }
        guard !fresh.isEmpty else { return }
        members += fresh.sorted { (Int($0.id) ?? 0) < (Int($1.id) ?? 0) }
        familyChanged()
    }

    /// The next player id no one has used, here or on any other device.
    var familyNextId: Int {
        FamilyState.nextFreeId(.init(members: members, removed: removedIds), logs: logs)
    }

    // MARK: Dares

    func setMe(_ player: Player) { me = player.id }

    /// Adds or removes one of my dares for today. Returns why not, or nil if it changed.
    func toggleDare(_ target: Player, _ choreId: String) -> String? {
        guard let me else { return "set whose phone this is first" }
        let key = FamilyState.dareKey(from: me, day: todayKey), item = "\(target.id):\(choreId)"
        var items = shared[key]?.items ?? []
        let locked = submittedToday(target.id)
        if let i = items.firstIndex(of: item) {
            if locked { return "locked — they already submitted today" }
            items.remove(at: i)
        } else {
            let mine = dares.filter { $0.from == me && $0.day == todayKey }
            if let why = Engine.dareBlocked(from: me, target: target.id, mineToday: mine, targetSubmitted: locked) { return why }
            items.append(item)
        }
        shared[key] = LocalEntry(items: items, updatedAt: Int64(Date().timeIntervalSince1970 * 1000), dirty: true)
        requestSync()
        return nil
    }

    /// True the first time a day's dare results are shown on this phone.
    func firstReveal(_ day: String) -> Bool {
        let key = Self.uiTesting ? "ui-testing.reveal" : "reveal"
        if UserDefaults.standard.string(forKey: key) == day { return false }
        UserDefaults.standard.set(day, forKey: key)
        return true
    }
}
#endif
