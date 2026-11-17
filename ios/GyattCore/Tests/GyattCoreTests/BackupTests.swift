import XCTest
@testable import GyattCore

final class BackupTests: XCTestCase {
    var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/Chicago")!; return c }
    let bed = Chore(id: "make-bed", name: "make bed", cat: "bedroom", pts: 8, tiers: [5, 8], tierDays: [0, 4])
    let dishes = Chore(id: "dishes", name: "do dishes", cat: "kitchen", pts: 10, tiers: [10], tierDays: [0])
    let day1 = Date(timeIntervalSince1970: 1_794_000_000)

    func log(_ pid: String, _ name: String, _ chore: Chore, _ t: Date, remote: String? = nil, status: String = Status.approved) -> ChoreLog {
        ChoreLog(remoteId: remote, playerId: pid, playerName: name, choreId: chore.id, choreName: chore.name, points: chore.pts,
                 minutes: chore.tiers[0], status: status, timestamp: t)
    }

    func sample() -> Backup {
        Backup(members: [Player(id: "1", name: "pat", isAdmin: true, plays: false), Player(id: "2", name: "riley", displayName: "Ri")],
               codes: ["1": AdminCode("2468", salt: "s")!], chores: [bed, dishes],
               choreAdded: ["make-bed": day1], memberJoined: ["2": day1], nextPlayerId: 3,
               logs: [log("2", "riley", bed, day1), log("2", "riley", dishes, day1, remote: "srv9", status: Status.pending)],
               dares: [Dare(from: "2", target: "1", choreId: "dishes", day: "2026-11-12")], puzzleLevels: ["2": 4],
               source: "ios-public", appVersion: "1.0 (1)", now: day1, id: "B1")
    }

    func testRoundTrip() throws {
        let b = sample()
        let back = try Backup.read(b.data())
        XCTAssertEqual(back, b)
        XCTAssertEqual(back.players.map(\.name), ["pat", "riley"])
        XCTAssertTrue(back.codes["1"]!.matches("2468"))
        XCTAssertEqual(back.choreLogs[1].remoteId, "srv9")
        XCTAssertEqual(back.choreLogs[0].timestamp, day1)
        XCTAssertEqual(back.gameDares.first?.choreId, "dishes")
        XCTAssertTrue(back.hasAdmin)
        XCTAssertEqual(back.summary, "1 player, 2 chores, 2 logged")
    }

    func testRefusesOtherFilesAndNewerVersions() {
        XCTAssertThrowsError(try Backup.read(Data("not json".utf8))) { XCTAssertEqual($0 as? Backup.ReadError, .notABackup) }
        XCTAssertThrowsError(try Backup.read(Data(#"{"type":"something-else","version":1}"#.utf8))) { XCTAssertEqual($0 as? Backup.ReadError, .notABackup) }
        XCTAssertThrowsError(try Backup.read(Data(#"{"type":"gyattchores-backup","version":2}"#.utf8))) { XCTAssertEqual($0 as? Backup.ReadError, .newerVersion) }
    }

    /// What another app (or a later version) might write: unknown keys, missing optional lists.
    func testToleratesUnknownAndMissingKeys() throws {
        let json = #"{"type":"gyattchores-backup","version":1,"members":[{"id":"7","name":"sam","isAdmin":false,"plays":true}],"somethingNew":[1,2]}"#
        let b = try Backup.read(Data(json.utf8))
        XCTAssertEqual(b.players.map(\.name), ["sam"])
        XCTAssertTrue(b.logs.isEmpty)
        XCTAssertFalse(b.hasAdmin)
    }

    func testMergeMatchesByUsernameAndSkipsDuplicates() {
        let family = [Player(id: "10", name: "Mom", isAdmin: true, plays: false), Player(id: "11", name: "RILEY")]
        let existing = [log("11", "RILEY", bed, day1.addingTimeInterval(3600))] // same person, chore and day
        let plan = sample().mergePlan(members: family, chores: [bed], logs: existing, nextId: 12, calendar: cal)
        // riley matches by username; pat (an admin in the backup) comes in as a helper, not an admin.
        XCTAssertEqual(plan.idMap["2"], "11")
        XCTAssertEqual(plan.newMembers, [Player(id: "12", name: "pat", isAdmin: false, plays: true)])
        XCTAssertEqual(plan.newChores, [dishes])
        XCTAssertEqual(plan.newLogs.count, 1)
        XCTAssertEqual(plan.newLogs[0].playerId, "11")
        XCTAssertEqual(plan.newLogs[0].playerName, "RILEY")
        XCTAssertNil(plan.newLogs[0].remoteId)
        XCTAssertEqual(plan.newLogs[0].status, Status.pending)
        XCTAssertEqual(plan.newLogs[0].timestamp, day1)
        XCTAssertEqual(plan.skippedLogs, 1)
        XCTAssertEqual(plan.summary, "1 person, 1 chore, 1 logged chore added (1 already here)")
    }

    func testMergeSkipsRowsTheFamilyAlreadyHas() {
        let family = [Player(id: "2", name: "riley")]
        let existing = [log("2", "riley", dishes, day1.addingTimeInterval(-86400 * 3), remote: "srv9")]
        let plan = sample().mergePlan(members: family, chores: [bed, dishes], logs: existing, nextId: 5, calendar: cal)
        XCTAssertEqual(plan.newLogs.map(\.choreId), ["make-bed"])
        XCTAssertEqual(plan.skippedLogs, 1)
    }

    func testMergingTheSameBackupAgainAddsNothing() {
        let b = sample()
        let family = [Player(id: "10", name: "mom", isAdmin: true, plays: false)]
        let first = b.mergePlan(members: family, chores: [], logs: [], nextId: 11, calendar: cal)
        let again = b.mergePlan(members: family + first.newMembers, chores: first.newChores, logs: first.newLogs, nextId: 13, calendar: cal)
        XCTAssertTrue(again.isEmpty)
        XCTAssertEqual(again.summary, "nothing new: everything in this backup is already here.")
    }

    /// A chore whose name the family already has maps to the family's id; one whose id the family
    /// uses for something else gets a fresh id. Logs follow both.
    func testChoresMatchByNameAndGetFreshIdsWhenTaken() {
        let familyBed = Chore(id: "bed-1", name: "Make Bed", cat: "bedroom", pts: 8, tiers: [5], tierDays: [0])
        let clash = Chore(id: "dishes", name: "walk the dog", cat: "pets", pts: 10, tiers: [10], tierDays: [0])
        let family = [Player(id: "2", name: "riley")]
        let plan = sample().mergePlan(members: family, chores: [familyBed, clash], logs: [], nextId: 5, calendar: cal)
        XCTAssertEqual(plan.choreMap["make-bed"], "bed-1")
        let freshDishes = plan.choreMap["dishes"]!
        XCTAssertNotEqual(freshDishes, "dishes")
        XCTAssertEqual(plan.newChores.map(\.id), [freshDishes])
        XCTAssertEqual(plan.newChores.first?.name, "do dishes")
        XCTAssertEqual(Set(plan.newLogs.map(\.choreId)), ["bed-1", freshDishes])
    }

    /// Someone taken off the family's list whose username matches nobody comes back as someone new,
    /// so their restored history isn't hidden.
    func testARemovedPlayerComesBackWithAFreshId() {
        let plan = sample().mergePlan(members: [Player(id: "9", name: "mom", isAdmin: true, plays: false)], chores: [bed, dishes],
                                      logs: [], nextId: 10, calendar: cal)
        XCTAssertEqual(plan.idMap["2"], "11")
        XCTAssertEqual(plan.newLogs.filter { $0.playerId == "11" }.count, 2)
    }

    /// A backup the iOS public app wrote (demo family: pat the admin, riley, sam; a month of chores).
    func testReadsARealIOSBackup() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "ios-public-backup", withExtension: "json", subdirectory: "Fixtures"))
        let b = try Backup.read(Data(contentsOf: url))
        XCTAssertEqual(b.source, "ios-public")
        XCTAssertEqual(b.players.map(\.name), ["pat", "riley", "sam"])
        XCTAssertTrue(b.hasAdmin)
        XCTAssertEqual(b.chores.count, 27)
        XCTAssertEqual(b.logs.count, 292)
        XCTAssertTrue(b.codes.values.contains { $0.matches("2468") })
    }

    /// A backup the Android app wrote with its own encoder (BackupSampleTest): mom (playing admin,
    /// code 1357), kai ("Kai 🦖"), lena; five starter chores plus a custom "feed the fish" whose id,
    /// make-bed, clashes with the starter "make bed". Numbers below are the ones Android asserts.
    func testReadsARealAndroidBackup() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "android-family-backup", withExtension: "json", subdirectory: "Fixtures"))
        let b = try Backup.read(Data(contentsOf: url))
        XCTAssertEqual(b.source, "android-family")
        XCTAssertEqual(b.players.map(\.name), ["mom", "kai", "lena"])
        XCTAssertEqual(b.players[1].shownName, "Kai 🦖")
        XCTAssertTrue(b.hasAdmin)
        XCTAssertTrue(b.codes["1"]!.matches("1357"))
        XCTAssertEqual(b.summary, "3 players, 6 chores, 47 logged")
        XCTAssertEqual(Dictionary(grouping: b.logs, by: \.status).mapValues(\.count), ["approved": 44, "pending": 2, "rejected": 1])
        XCTAssertEqual(b.gameDares, [Dare(from: "2", target: "3", choreId: "make-bed", day: "2026-11-12")])
        XCTAssertEqual(b.puzzleLevels, ["2": 3])

        // Restored as a whole (the public app): the same scores as on Android.
        var denver = Calendar(identifier: .gregorian); denver.timeZone = TimeZone(identifier: "America/Denver")!
        let now = b.exportedDate, logs = b.choreLogs
        func week(_ id: String) -> Int { Engine.weekPoints(playerId: id, logs: logs, dares: b.gameDares, now: now, calendar: denver) }
        // kai dared lena "make-bed" (feed the fish) on the 12th and she did it, approved: +10 kai, +5 lena.
        XCTAssertEqual([week("1"), week("2"), week("3")], [35, 400, 41])
        let withoutDares = ["1", "2", "3"].map { Engine.weekPoints(playerId: $0, logs: logs, dares: [], now: now, calendar: denver) }
        XCTAssertEqual(withoutDares, [35, 390, 36])
        let pool = Dictionary(b.chores.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let days = Engine.recentDays(now: now, calendar: denver)
        func hits(_ id: String) -> Int {
            let by = Engine.minutesByDay(playerId: id, logs: logs, pool: pool, calendar: denver)
            return days.filter { (by[$0] ?? 0) >= Engine.dailyMinutes }.count
        }
        XCTAssertEqual([hits("1"), hits("2"), hits("3")], [0, 6, 0])

        // Merged into a family on the starter list: the five starter chores map to the family's own
        // by name; "feed the fish" can't keep make-bed (the family's "make bed"), so it gets a fresh
        // id and its ten logs follow it.
        let starter = try JSONDecoder().decode([Chore].self, from: Data(contentsOf: XCTUnwrap(Self.starterURL)))
        let plan = b.mergePlan(members: [], chores: starter, logs: [], nextId: 1, calendar: denver)
        XCTAssertEqual(plan.newChores.map(\.name), ["feed the fish"])
        let fish = plan.newChores[0].id
        XCTAssertNotEqual(fish, "make-bed")
        XCTAssertEqual(plan.choreMap["make-bed"], fish)
        XCTAssertEqual(plan.newLogs.filter { $0.choreId == fish }.count, 10)
        XCTAssertEqual(plan.newLogs.filter { $0.choreId == "make-bed" }.count, 0)
        XCTAssertEqual(plan.newLogs.count, 47)
        XCTAssertEqual(plan.newMembers.map(\.name), ["mom", "kai", "lena"])
    }

    /// The app's starter list (`native/chores.json`), found from this test file's location.
    static var starterURL: URL? {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<6 {
            let candidate = dir.appendingPathComponent("native/chores.json")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

    func testFileName() {
        XCTAssertEqual(Backup.fileName(day1, calendar: cal), "doyourwork-backup-2026-11-06.json")
    }
}
