import Foundation
import DoYourWorkCore

/// Sync between the family's phones, through the encrypted relay, once this phone is linked
/// (`RelayLink.swift`). The same passes as the Android app.
///
/// - Chore logs: the server's status wins unless a change made here hasn't reached it yet.
/// - Players, display names, admin codes, the chore list and dares are keyed as `FamilyState`
///   describes; the last phone to change a key wins.
///
/// Every change is saved here first and never waits on the network. Under `-uiTesting` the relay is
/// an in-memory one, so a test run can't reach the real server.
extension AppStore {
    /// One pass at a time; a request that arrives mid-pass runs one follow-up pass instead of overlapping.
    func requestSync() {
        // Not linked: everything stays on this phone.
        guard let onRelay = relay else { syncStatus = "local"; return }
        if syncing { syncAgain = true; return }
        syncing = true
        syncStatus = "syncing"
        let logSnapshot = logs, stateSnapshot = shared
        let started = transport
        Task {
            do {
                // Removed from the family, or the family was deleted: reads would just come back
                // empty, so ask before syncing anything.
                if try await !onRelay.isMember() {
                    if started == transport { leaveRelay(); notice = "This phone is no longer in the family's sync. Everything on it stays here." }
                    syncing = false
                    if syncAgain { syncAgain = false; requestSync() }
                    return
                }
                let synced = try await LogSync.run(api: onRelay, local: logSnapshot)
                // This phone joined another family or left mid-pass: what came back doesn't belong here now.
                guard started == transport else { throw CancellationError() }
                // Taken off the list: their rows stay on the server but not on this device.
                logs = LogSync.reconcile(synced: synced, latest: logs).filter { !removedIds.contains($0.playerId) }
                let st = try await StateSync.run(api: onRelay, local: stateSnapshot)
                guard started == transport else { throw CancellationError() }
                shared = StateSync.reconcile(synced: st, latest: shared)
                applyShared()
                logs.removeAll { removedIds.contains($0.playerId) }
                adoptPlayersFromLogs()
                hasSynced = true
                syncStatus = "synced"
            } catch is CancellationError {
                syncAgain = true
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
        if let chores = family.chores, chores != pool {
            pool = chores
            // A chore taken off the list on another phone: a card still being checked off loses it
            // and its player picks again, rather than having it vanish when they submit.
            let ids = Set(chores.map(\.id))
            cards = cards.filter { $0.value.submitted || $0.value.choreIds.allSatisfy(ids.contains) }
        }
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

    // MARK: Backups

    /// Ids of backups already restored into this family, on any device.
    var restoredBackupIds: Set<String> { Set(shared[FamilyState.restoredBackups]?.items ?? []) }

    func markRestored(_ backupId: String) {
        let items = (shared[FamilyState.restoredBackups]?.items ?? []) + [backupId]
        shared[FamilyState.restoredBackups] = LocalEntry(items: items, updatedAt: Int64(Date().timeIntervalSince1970 * 1000), dirty: true)
    }

    // MARK: Dares

    func setMe(_ player: Player) { me = player.id }

    /// Adds or removes one of my dares for today. Returns why not, or nil if it changed.
    func toggleDare(_ target: Player, _ choreId: String) -> String? {
        guard let me else { return "Set whose phone this is first." }
        let key = FamilyState.dareKey(from: me, day: todayKey), item = "\(target.id):\(choreId)"
        var items = shared[key]?.items ?? []
        let locked = submittedToday(target.id)
        if let i = items.firstIndex(of: item) {
            if locked { return "Locked. They already sent today's card in." }
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
