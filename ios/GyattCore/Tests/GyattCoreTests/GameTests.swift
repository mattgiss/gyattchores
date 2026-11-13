import XCTest
@testable import GyattCore

/// A day played end to end through `Game`, and the save file surviving a round trip.
final class GameTests: XCTestCase {
    let kid = ChoreCatalog.players[0]
    let sibling = ChoreCatalog.players[1]
    let now = Date(timeIntervalSince1970: 1_794_411_000)   // 2026-11-11T15:30:00Z

    var engine: Engine {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return Engine(calendar: calendar)
    }

    private func newGame() -> Game { Game(engine: engine) }

    private func pickCard(_ game: Game, for player: Player) -> [CardChore] {
        let pool = game.engine.pickableChores(playerId: player.id, logs: game.logs, now: now)
        let ids = Set(game.engine.suggestFill(picked: [], pool: pool))
        return pool.filter { ids.contains($0.id) }
    }

    func testAFullDay() {
        var game = newGame()
        XCTAssertNil(game.card(for: kid.id, now: now), "nothing picked yet")

        // Build the card.
        let chores = pickCard(game, for: kid)
        XCTAssertFalse(chores.isEmpty)
        game.buildCard(for: kid.id, chores: chores, now: now)
        var card = game.card(for: kid.id, now: now)!
        XCTAssertEqual(card.chores, chores)
        XCTAssertFalse(card.submitted)
        XCTAssertNil(game.card(for: sibling.id, now: now), "cards are per player")

        // Can't submit until everything is checked off.
        XCTAssertFalse(game.submitCard(for: kid, now: now))
        XCTAssertTrue(game.logs.isEmpty)
        for index in chores.indices { game.toggleChore(at: index, for: kid.id, now: now) }
        game.toggleChore(at: 0, for: kid.id, now: now)   // changed their mind…
        XCTAssertFalse(game.submitCard(for: kid, now: now))
        game.toggleChore(at: 0, for: kid.id, now: now)   // …and back
        game.toggleChore(at: 99, for: kid.id, now: now)  // out of range is ignored

        // Submit.
        XCTAssertTrue(game.submitCard(for: kid, now: now))
        card = game.card(for: kid.id, now: now)!
        XCTAssertTrue(card.submitted)
        XCTAssertEqual(game.logs.count, chores.count)
        XCTAssertTrue(game.logs.allSatisfy { $0.status == .pending })
        XCTAssertEqual(Set(game.logs.map(\.choreId)), Set(chores.map(\.id)))
        XCTAssertEqual(game.engine.xp(playerId: kid.id, logs: game.logs), 0, "pending earns nothing")

        // A submitted card is frozen.
        XCTAssertFalse(game.submitCard(for: kid, now: now), "no double submit")
        game.toggleChore(at: 0, for: kid.id, now: now)
        game.discardCard(for: kid.id, now: now)
        XCTAssertEqual(game.card(for: kid.id, now: now), card)
        XCTAssertEqual(game.logs.count, chores.count)

        // Parent approves all but one.
        let rejected = game.logs[0]
        for log in game.logs { game.setStatus(log.id == rejected.id ? .rejected : .approved, forLog: log.id) }
        game.setStatus(.approved, forLog: "no-such-log")
        let expectedXP = chores.filter { $0.id != rejected.choreId }.reduce(0) { $0 + $1.pts }
        XCTAssertEqual(game.engine.xp(playerId: kid.id, logs: game.logs), expectedXP)
        XCTAssertEqual(game.engine.streak(playerId: kid.id, logs: game.logs, now: now), 1)
        let today = game.engine.todayState(playerId: kid.id, logs: game.logs, card: card, now: now)
        XCTAssertEqual(today.statusByChore[rejected.choreId], .rejected)
        XCTAssertTrue(today.bonus.isEmpty)
    }

    func testBonusRoundLogsEachChoreOncePerDay() {
        var game = newGame()
        let chores = pickCard(game, for: kid)
        game.buildCard(for: kid.id, chores: chores, now: now)
        for index in chores.indices { game.toggleChore(at: index, for: kid.id, now: now) }
        game.submitCard(for: kid, now: now)

        let later = now.addingTimeInterval(600)
        let pool = game.engine.pickableChores(playerId: kid.id, logs: game.logs, now: later)
        let extra = pool.first { candidate in !chores.contains { $0.id == candidate.id } }!

        // One new chore plus one that's already on the card.
        game.logBonus(for: kid, chores: [extra, chores[0]], now: later)
        XCTAssertEqual(game.logs.count, chores.count + 1)
        XCTAssertEqual(game.logs.first?.choreId, extra.id, "logs stay newest first")

        game.logBonus(for: kid, chores: [extra], now: later.addingTimeInterval(60))
        XCTAssertEqual(game.logs.count, chores.count + 1, "same bonus chore twice in a day is ignored")

        let card = game.card(for: kid.id, now: later)!
        let today = game.engine.todayState(playerId: kid.id, logs: game.logs, card: card, now: later)
        XCTAssertEqual(today.bonus.map(\.id), [extra.id])
    }

    func testRepickBeforeSubmitting() {
        var game = newGame()
        let chores = pickCard(game, for: kid)
        game.buildCard(for: kid.id, chores: chores, now: now)
        game.toggleChore(at: 0, for: kid.id, now: now)
        game.discardCard(for: kid.id, now: now)
        XCTAssertNil(game.card(for: kid.id, now: now))

        game.buildCard(for: kid.id, chores: [], now: now)
        XCTAssertNil(game.card(for: kid.id, now: now), "an empty card isn't a card")
    }

    func testNewDayStartsFresh() {
        var game = newGame()
        let chores = pickCard(game, for: kid)
        game.buildCard(for: kid.id, chores: chores, now: now)
        for index in chores.indices { game.toggleChore(at: index, for: kid.id, now: now) }
        game.submitCard(for: kid, now: now)
        game.buildCard(for: sibling.id, chores: pickCard(game, for: sibling), now: now)

        let tomorrow = now.addingTimeInterval(86_400)
        XCTAssertNil(game.card(for: kid.id, now: tomorrow), "yesterday's card doesn't carry over")
        XCTAssertNil(game.card(for: sibling.id, now: tomorrow), "nor does an unfinished one")

        XCTAssertEqual(game.state.cards.count, 2)
        game.pruneCards(now: tomorrow)
        XCTAssertTrue(game.state.cards.isEmpty)
        XCTAssertEqual(game.logs.count, chores.count, "the logs are the lasting record")
    }

    func testAnotherDeviceRebuildsTheCardFromLogs() {
        var kidsPhone = newGame()
        let chores = pickCard(kidsPhone, for: kid)
        kidsPhone.buildCard(for: kid.id, chores: chores, now: now)
        for index in chores.indices { kidsPhone.toggleChore(at: index, for: kid.id, now: now) }
        kidsPhone.submitCard(for: kid, now: now)

        // The parent's phone has the logs but never built the card.
        let parentsPhone = Game(state: GameState(logs: kidsPhone.logs), engine: engine)
        XCTAssertNil(parentsPhone.localCard(for: kid.id, now: now))
        let rebuilt = parentsPhone.card(for: kid.id, now: now)!
        XCTAssertTrue(rebuilt.submitted)
        XCTAssertEqual(Set(rebuilt.chores.map(\.id)), Set(chores.map(\.id)))
    }

    func testLogsAreKeptNewestFirst() {
        func log(_ id: String, secondsAgo: Double) -> ChoreLog {
            ChoreLog(id: id, playerId: kid.id, playerName: kid.name, choreId: id, choreName: id,
                     points: 5, timestamp: now.addingTimeInterval(-secondsAgo), status: .approved)
        }
        let game = Game(state: GameState(logs: [log("old", secondsAgo: 300), log("new", secondsAgo: 1), log("mid", secondsAgo: 60)]),
                        engine: engine)
        XCTAssertEqual(game.logs.map(\.id), ["new", "mid", "old"])
    }

    func testDayKey() {
        XCTAssertEqual(newGame().dayKey(now), "2026-11-11")
        XCTAssertEqual(newGame().dayKey(Date(timeIntervalSince1970: 0)), "1970-01-01")
    }

    // MARK: Save file

    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("gyatt-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("game.json")
    }

    func testArchiveRoundTrip() throws {
        var game = newGame()
        let chores = pickCard(game, for: kid)
        game.buildCard(for: kid.id, chores: chores, now: now)
        for index in chores.indices { game.toggleChore(at: index, for: kid.id, now: now) }
        game.submitCard(for: kid, now: now)
        game.setStatus(.approved, forLog: game.logs[0].id)
        game.buildCard(for: sibling.id, chores: pickCard(game, for: sibling), now: now)

        let archive = GameArchive(url: temporaryFile())
        XCTAssertEqual(archive.load(), .empty)
        try archive.save(game.state)

        guard case .loaded(let loaded) = archive.load() else { return XCTFail("expected a saved game") }
        let restored = Game(state: loaded, engine: engine)
        XCTAssertEqual(restored.state.cards, game.state.cards)
        XCTAssertEqual(restored.logs.map(\.id), game.logs.map(\.id))
        XCTAssertEqual(restored.logs.map(\.status), game.logs.map(\.status))
        XCTAssertEqual(restored.logs.map(\.minutes), game.logs.map(\.minutes))
        for (a, b) in zip(restored.logs, game.logs) {
            XCTAssertEqual(a.timestamp.timeIntervalSince1970, b.timestamp.timeIntervalSince1970, accuracy: 0.0005)
        }
        XCTAssertEqual(restored.engine.xp(playerId: kid.id, logs: restored.logs),
                       game.engine.xp(playerId: kid.id, logs: game.logs))
    }

    func testUnreadableSaveIsMovedAsideNotOverwritten() throws {
        let url = temporaryFile()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let garbage = Data("{ this is not a save file".utf8)
        try garbage.write(to: url)

        let archive = GameArchive(url: url)
        guard case .unreadable(let backup?) = archive.load() else { return XCTFail("expected the bad file to be set aside") }
        XCTAssertEqual(try Data(contentsOf: backup), garbage, "the original bytes are kept")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))

        try archive.save(GameState())
        XCTAssertEqual(archive.load(), .loaded(GameState()))
        XCTAssertEqual(try Data(contentsOf: backup), garbage, "saving afterwards doesn't touch the backup")
    }
}
