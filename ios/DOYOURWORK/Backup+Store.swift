import Foundation
import DoYourWorkCore

/// Saving and restoring a backup of the scoreboard (`DoYourWorkCore.Backup`).
///
/// - Public app: restoring replaces everything on this device with the backup.
/// - Family build: restoring adds the backup to the family. People are matched by username, chores
///   by id or name, and logs the family already has are left out. A family that has no admin yet
///   also takes its admins and codes from the backup. The same backup can't be restored twice.
extension AppStore {
    static var backupSource: String {
        "ios"
    }

    func makeBackup(now: Date = Date()) -> Backup {
        var levels: [String: Int] = [:]
        for m in members { let l = puzzleLevel(m.id); if l > 1 { levels[m.id] = l } }
        return Backup(members: members, codes: settings.adminCodes, chores: pool, choreAdded: settings.choreAdded,
                      memberJoined: settings.memberJoined, nextPlayerId: settings.nextPlayerId, logs: logs, dares: dares,
                      puzzleLevels: levels, source: Self.backupSource, appVersion: AppInfo.version, now: now)
    }

    /// What restoring `backup` here would do, in words, for the confirmation before it happens.
    func restorePreview(_ backup: Backup) -> String {
        let when = backup.exportedDate.formatted(date: .abbreviated, time: .shortened)
        guard isLinked else {
            guard backup.hasAdmin else { return "Saved \(when): \(backup.summary). It has no admin, so it can't be restored here." }
            return "Saved \(when): \(backup.summary). " + (isSetUp ? "Everything on this device now is replaced by it." : "It becomes this device's scoreboard.")
        }
        if restoredBackupIds.contains(backup.id) { return "This backup (saved \(when)) was already restored. Restoring it again adds nothing." }
        let plan = backup.mergePlan(members: members, chores: pool, logs: logs, nextId: familyNextId, calendar: calendar)
        return "Saved \(when): \(backup.summary).\n\nAdding it to the family: \(plan.isEmpty ? plan.summary : plan.summary + ".")" + (isSetUp ? "" : " Its admins and their codes become the family's.")
    }

    /// Restores a backup. Returns what happened, for the message afterwards.
    @discardableResult
    func restore(_ backup: Backup) -> String {
        // Linked, it joins what the family's phones share; on its own, the phone becomes the backup.
        isLinked ? restoreIntoFamily(backup) : restoreReplacing(backup)
    }

    private func setPuzzleLevels(_ levels: [String: Int], idMap: [String: String]) {
        for (id, level) in levels {
            guard let target = idMap[id] else { continue }
            if level > puzzleLevel(target) { puzzleCleared(target, level - 1) }
        }
    }


    private func restoreReplacing(_ b: Backup) -> String {
        // Nobody could unlock the admin area afterwards. Android refuses these too.
        guard b.hasAdmin else { return "This backup has no admin, so it can't be restored here. Nothing changed." }
        eraseEverything()
        var next = Settings()
        next.adminCodes = b.codes.filter { id, _ in b.members.contains { $0.id == id && $0.isAdmin } }
        next.choreAdded = b.choreAddedDates
        next.memberJoined = b.memberJoinedDates
        let used = (b.members.map(\.id) + b.logs.map(\.playerId)).compactMap(Int.init)
        next.nextPlayerId = max(b.nextPlayerId, (used.max() ?? 0) + 1)
        next.setUp = true
        pool = b.chores.isEmpty ? starterChores : b.chores
        members = b.players
        logs = b.choreLogs.map { var l = $0; l.remoteId = nil; l.statusDirty = false; return l }
        // Its dares keep the points they earned.
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        var dares: [String: [String]] = [:]
        for d in b.gameDares { dares[FamilyState.dareKey(from: d.from, day: d.day), default: []].append("\(d.target):\(d.choreId)") }
        shared = dares.mapValues { LocalEntry(items: $0, updatedAt: now, dirty: true) }
        settings = next
        familyChanged()
        setPuzzleLevels(b.puzzleLevels, idMap: Dictionary(b.members.map { ($0.id, $0.id) }, uniquingKeysWith: { a, _ in a }))
        return "Restored: \(b.summary)."
    }

    private func restoreIntoFamily(_ b: Backup) -> String {
        guard !restoredBackupIds.contains(b.id) else { return "This backup was already restored. Nothing changed." }
        let plan = b.mergePlan(members: members, chores: pool, logs: logs, nextId: familyNextId, calendar: calendar)
        var list = members + plan.newMembers
        var next = settings
        // A family with no admin yet takes the backup's admins and codes.
        if !isSetUp {
            for m in b.members where m.isAdmin {
                guard let id = plan.idMap[m.id], let code = b.codes[m.id], let i = list.firstIndex(where: { $0.id == id }) else { continue }
                list[i].isAdmin = true
                // Someone new takes the backup's say on whether they play; someone already in the
                // family keeps playing as they were.
                if plan.newMembers.contains(where: { $0.id == id }) { list[i].plays = m.plays }
                next.adminCodes[id] = code
            }
        }
        next.memberJoined.merge(plan.memberJoined) { mine, _ in mine }
        next.choreAdded.merge(plan.choreAdded) { mine, _ in mine }
        next.nextPlayerId = max(next.nextPlayerId, (list.compactMap { Int($0.id) }.max() ?? 0) + 1)
        members = list
        pool += plan.newChores
        logs += plan.newLogs
        settings = next
        setPuzzleLevels(b.puzzleLevels, idMap: plan.idMap)
        markRestored(b.id)
        familyChanged()
        return plan.isEmpty ? "Nothing new. Everything in this backup is already here." : "Restored: \(plan.summary)."
    }
}
