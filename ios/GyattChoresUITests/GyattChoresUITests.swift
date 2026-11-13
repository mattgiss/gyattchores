import XCTest

/// Drives the real app in a simulator: setting a family up from nothing, a player's day from
/// picking chores to submitting, the bonus round, the save surviving a relaunch, and the admin
/// area. Screenshots are attached to the results.
///
/// The same tests run on an iPhone (one screen at a time) and an iPad (home list on the left, the
/// open screen on the right); the helpers below paper over the difference in getting around.
///
/// Every launch passes `-uiTesting`, which gives the app a separate data folder. `-resetData`
/// starts from a fresh install; `-demoFamily` adds a family that's already set up (pat is the
/// admin, code 2468; riley and sam play); `-demoData` adds a made-up month of chores on top.
final class GyattChoresUITests: XCTestCase {
    private let wait: TimeInterval = 20
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Helpers

    private let adminCode = "2468"

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + extra
        app.launch()
        XCTAssertTrue(app.staticTexts["GYATTCHORES"].waitForExistence(timeout: wait))
        return app
    }

    private func type(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: wait))
        field.tap()
        field.typeText(text)
    }

    /// Opens the admin area and unlocks it.
    private func unlockAdmin(in app: XCUIApplication, code: String? = nil) {
        app.buttons["admin"].tap()
        type(code ?? adminCode, into: app.secureTextFields.firstMatch)
        app.buttons["> UNLOCK"].tap()
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: wait), "the right code opens the admin area")
    }

    private func adminSection(_ name: String, in app: XCUIApplication) {
        app.segmentedControls.firstMatch.buttons[name].tap()
    }

    /// Flips a switch. Tapping the middle of a labelled switch lands on its label, which does nothing.
    private func flip(_ toggle: XCUIElement) {
        XCTAssertTrue(toggle.waitForExistence(timeout: wait))
        let before = toggle.value as? String
        let inner = toggle.switches.firstMatch
        if inner.exists { inner.tap() } else { toggle.tap() }
        if (toggle.value as? String) == before {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
        XCTAssertNotEqual(toggle.value as? String, before, "the switch should have flipped")
    }

    /// The row on the home screen that opens a player's day (it's the one showing their streak).
    private func playerRow(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS '🔥'", name)).firstMatch
    }

    /// The big "> LABEL" button at the bottom of the picker and the card. The home screen's player
    /// rows also start with "> ", and the home screen is still around while the next screen slides
    /// in (and always, on an iPad), so rule those out.
    private func mainButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '> ' AND NOT (label CONTAINS '🔥')")).firstMatch
    }

    private func uncheckedChores(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "value == 'not checked'"))
    }

    private func screenshot(_ name: String, of app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func nudgeUp(_ app: XCUIApplication) {
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.40))
        from.press(forDuration: 0.05, thenDragTo: to)
    }

    /// Checks off every chore on the card and returns the submit button, now enabled.
    private func checkOffEverything(in app: XCUIApplication) -> XCUIElement {
        let submit = app.buttons["> SUBMIT FOR APPROVAL"]
        var steps = 0
        while !submit.exists, steps < 40 {
            steps += 1
            let next = uncheckedChores(in: app).firstMatch
            if next.exists, next.isHittable { next.tap() } else { nudgeUp(app) }
        }
        XCTAssertTrue(submit.exists, "checking every chore off should enable submit")
        XCTAssertTrue(submit.isEnabled)
        return submit
    }

    private func open(_ name: String, in app: XCUIApplication) {
        let row = playerRow(name, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: wait), "\(name) should be on the home screen")
        row.tap()
        if isPad {
            // The day opens beside the list; there's nothing to go back to.
            XCTAssertTrue(row.isSelected, "\(name) should be highlighted in the list")
        } else {
            XCTAssertTrue(app.buttons["← back"].waitForExistence(timeout: wait), "\(name)'s screen should open")
        }
    }

    /// Back to the home list. On an iPad it never left, so there's only something to close when
    /// the admin area or the bonus picker is open.
    private func goBack(in app: XCUIApplication) {
        let back = app.buttons["← back"]
        if back.exists { back.tap() }
        XCTAssertTrue(app.staticTexts["GYATTCHORES"].waitForExistence(timeout: wait))
    }

    // MARK: Tests

    func testADayFromPickingToSubmitting() {
        let app = launch(["-resetData", "-demoFamily"])

        // Home: both players, nobody has cleared a day yet.
        XCTAssertTrue(playerRow("riley", in: app).exists)
        XCTAssertTrue(playerRow("sam", in: app).exists)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == '0/30 · 0%'")).count, 2)
        screenshot("01-home-empty", of: app)

        // Picker: nothing picked, so the card can't be locked in yet.
        open("riley", in: app)
        let main = mainButton(in: app)
        XCTAssertTrue(main.waitForExistence(timeout: wait))
        XCTAssertEqual(main.label, "> PICK OR SUGGEST CHORES")
        XCTAssertFalse(main.isEnabled)
        XCTAssertTrue(app.staticTexts["0 / 25m"].exists)
        screenshot("02-picker-empty", of: app)

        // Suggest a full card, then lock it in.
        app.buttons["✨ suggest a 25-min card"].tap()
        XCTAssertEqual(main.label, "> LOCK IN CARD")
        XCTAssertTrue(main.isEnabled)
        XCTAssertFalse(app.staticTexts["0 / 25m"].exists, "the suggestion added minutes")
        screenshot("03-picker-suggested", of: app)
        main.tap()

        // Card: submit stays off until every chore is checked.
        XCTAssertTrue(app.buttons["> CHECK OFF EVERYTHING FIRST"].waitForExistence(timeout: wait))
        XCTAssertFalse(mainButton(in: app).isEnabled)
        XCTAssertGreaterThan(uncheckedChores(in: app).count, 0)
        screenshot("04-card-unchecked", of: app)

        let submit = checkOffEverything(in: app)
        screenshot("05-card-checked", of: app)

        submit.tap()
        XCTAssertTrue(app.staticTexts["card submitted — waiting on an admin"].waitForExistence(timeout: wait))
        XCTAssertEqual(uncheckedChores(in: app).count, 0, "a submitted card can't be unchecked")
        screenshot("06-card-submitted", of: app)

        // Bonus round: one extra chore, logged straight to pending.
        app.buttons["+ bonus round"].tap()
        XCTAssertTrue(app.buttons["> PICK CHORES TO LOG"].waitForExistence(timeout: wait))
        uncheckedChores(in: app).firstMatch.tap()
        let logOne = app.buttons["> LOG 1 CHORES"]
        XCTAssertTrue(logOne.waitForExistence(timeout: wait))
        screenshot("07-bonus-picker", of: app)
        logOne.tap()
        XCTAssertTrue(app.staticTexts["BONUS ROUND"].waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["card submitted — waiting on an admin"].exists)
        screenshot("08-card-with-bonus", of: app)

        // Relaunch: the day is still there.
        app.terminate()
        let relaunched = launch()
        open("riley", in: relaunched)
        XCTAssertTrue(relaunched.staticTexts["card submitted — waiting on an admin"].waitForExistence(timeout: wait))
        XCTAssertTrue(relaunched.staticTexts["BONUS ROUND"].exists)

        // The other player's day is untouched.
        goBack(in: relaunched)
        open("sam", in: relaunched)
        XCTAssertTrue(relaunched.buttons["> PICK OR SUGGEST CHORES"].waitForExistence(timeout: wait))
    }

    func testAdminGateAndApprovals() {
        let app = launch(["-resetData", "-demoData"])
        let code = app.secureTextFields.firstMatch

        // A wrong code gets nowhere.
        app.buttons["admin"].tap()
        type("definitely-not-it", into: code)
        app.buttons["> UNLOCK"].tap()
        XCTAssertTrue(app.staticTexts["that code didn't match"].waitForExistence(timeout: wait))
        XCTAssertEqual(app.segmentedControls.count, 0, "a wrong code must not reach the approvals")
        XCTAssertFalse(app.buttons["✓ approve"].exists)
        screenshot("09-admin-wrong-code", of: app)

        // The admin's code opens it: sam's chores from today are waiting.
        type(adminCode, into: code)
        app.buttons["> UNLOCK"].tap()
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: wait))
        let approve = app.buttons["✓ approve"].firstMatch
        XCTAssertTrue(approve.waitForExistence(timeout: wait))
        screenshot("09b-admin-approvals", of: app)
        var approved = 0
        while approve.exists, approved < 20 { approve.tap(); approved += 1 }
        XCTAssertGreaterThan(approved, 0)
        XCTAssertTrue(app.staticTexts["nothing pending"].waitForExistence(timeout: wait))

        // Back on sam's card, everything reads approved.
        goBack(in: app)
        open("sam", in: app)
        XCTAssertTrue(app.staticTexts["✓ all approved — nice work"].waitForExistence(timeout: wait))
    }

    /// From a fresh install to a working scoreboard, with chores written in the family's own words.
    func testSettingUpFromNothing() {
        let app = launch(["-resetData"])

        // No players are built in: a fresh install starts with the welcome.
        let start = app.buttons["> SET UP THIS DEVICE"]
        XCTAssertTrue(start.waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["· everything stays on this device"].exists)
        XCTAssertTrue(app.staticTexts["· no accounts, no sign-in, no ads, no tracking"].exists)
        XCTAssertFalse(app.buttons["admin"].exists)
        screenshot("20-setup-welcome", of: app)
        start.tap()

        // Who's in charge: a name and a code typed twice.
        let next = app.buttons["> NEXT"]
        XCTAssertTrue(next.waitForExistence(timeout: wait))
        XCTAssertFalse(next.isEnabled)
        type("pat", into: app.textFields["admin-name"])
        type("2468", into: app.secureTextFields["admin-code"])
        type("246", into: app.secureTextFields["admin-code-again"])
        XCTAssertTrue(app.staticTexts["those two codes don't match"].waitForExistence(timeout: wait))
        XCTAssertFalse(next.isEnabled)
        app.secureTextFields["admin-code-again"].typeText("8\n")
        XCTAssertFalse(app.staticTexts["those two codes don't match"].exists)
        XCTAssertTrue(next.isEnabled)
        screenshot("21-setup-admin", of: app)
        next.tap()

        // Who's playing: one added with the button, one left in the box.
        XCTAssertTrue(app.staticTexts["who's playing?"].waitForExistence(timeout: wait))
        XCTAssertFalse(next.isEnabled, "someone has to play")
        type("riley\n", into: app.textFields["player-name"])
        XCTAssertTrue(app.staticTexts["riley"].waitForExistence(timeout: wait))
        type("sam", into: app.textFields["player-name"])
        screenshot("22-setup-players", of: app)
        next.tap()

        // What needs doing: said in a sentence, sorted into a list.
        let own = app.buttons["write or say your own"]
        XCTAssertTrue(own.waitForExistence(timeout: wait))
        XCTAssertTrue(app.buttons["> USE THE STARTER LIST"].exists)
        own.tap()
        type("We need to do the dishes and take out the trash, someone has to feed the dog for 5 minutes. Water plants", into: app.textViews["chore-text"])
        screenshot("23-setup-chores-written", of: app)
        app.buttons["> SORT INTO CHORES"].tap()
        XCTAssertTrue(app.buttons["> ADD 4 CHORES"].waitForExistence(timeout: wait))
        for name in ["do the dishes", "take out the trash", "feed the dog", "water plants"] {
            XCTAssertTrue(app.textFields.matching(NSPredicate(format: "value == %@", name)).firstMatch.exists, "\(name) should be on the list")
        }
        XCTAssertTrue(app.staticTexts["5m"].exists, "the time that was mentioned is kept")
        screenshot("24-setup-chores-sorted", of: app)
        app.buttons["leave out water plants"].tap()
        let add = app.buttons["> ADD 3 CHORES"]
        XCTAssertTrue(add.waitForExistence(timeout: wait))
        add.tap()

        // The scoreboard: the two players, and not the admin, who doesn't do chores.
        XCTAssertTrue(playerRow("riley", in: app).waitForExistence(timeout: wait))
        XCTAssertTrue(playerRow("sam", in: app).exists)
        XCTAssertFalse(playerRow("pat", in: app).exists)
        screenshot("25-setup-done", of: app)

        // Their own three chores are what there is to pick, at their normal times: nothing starts overdue.
        open("riley", in: app)
        XCTAssertTrue(mainButton(in: app).waitForExistence(timeout: wait))
        XCTAssertEqual(uncheckedChores(in: app).count, 3)
        XCTAssertTrue(app.staticTexts["feed the dog"].exists || app.descendants(matching: .any)["feed the dog"].exists)
        XCTAssertFalse(app.staticTexts["!!"].exists)
        screenshot("26-own-chores-picker", of: app)
        goBack(in: app)

        // It's all still there after a restart, and the code chosen at setup opens the admin area.
        app.terminate()
        let relaunched = launch()
        XCTAssertTrue(playerRow("sam", in: relaunched).waitForExistence(timeout: wait))
        XCTAssertFalse(relaunched.buttons["> SET UP THIS DEVICE"].exists)
        unlockAdmin(in: relaunched)
        goBack(in: relaunched)
    }

    /// Admins add players, hand out admin rights and change the chore list.
    func testAdminsChangePlayersAndChores() {
        let app = launch(["-resetData", "-demoFamily"])
        unlockAdmin(in: app)

        // Add a player.
        adminSection("players", in: app)
        app.buttons["+ add player"].tap()
        let save = app.buttons["> SAVE"]
        XCTAssertTrue(save.waitForExistence(timeout: wait))
        XCTAssertFalse(save.isEnabled, "a player needs a name")
        type("sam", into: app.textFields["member-name"])
        XCTAssertTrue(app.staticTexts["someone already has that name"].waitForExistence(timeout: wait))
        XCTAssertFalse(save.isEnabled)
        app.textFields["member-name"].typeText("antha")
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.buttons["edit samantha"].waitForExistence(timeout: wait))

        // Make her an admin: that needs a code of her own.
        app.buttons["edit samantha"].tap()
        flip(app.switches["admin"])
        XCTAssertFalse(save.isEnabled, "an admin needs a code")
        type("1357", into: app.secureTextFields["member-code"])
        XCTAssertTrue(save.isEnabled)
        screenshot("27-admin-edit-player", of: app)
        save.tap()
        XCTAssertTrue(app.buttons["edit samantha"].waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["admin · not playing"].exists, "pat runs the scoreboard without doing chores")
        screenshot("28-admin-players", of: app)

        // The last admin can't be removed, but a player can.
        app.buttons["edit pat"].tap()
        XCTAssertTrue(save.waitForExistence(timeout: wait))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'remove pat'")).firstMatch.exists, "with two admins, either can go")
        app.buttons["cancel"].tap()

        // Add a chore in plain words, then find it on the list.
        adminSection("chores", in: app)
        app.buttons["+ add chores"].tap()
        type("feed the fish 2 minutes, make bed", into: app.textViews["chore-text"])
        app.buttons["> SORT INTO CHORES"].tap()
        let add = app.buttons["> ADD 1 CHORE"]
        XCTAssertTrue(add.waitForExistence(timeout: wait), "make bed is already on the list, so only the fish is new")
        add.tap()
        XCTAssertTrue(app.buttons["edit feed the fish"].waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["28 chores. left undone, a chore takes longer the next time it's picked."].exists)
        screenshot("29-admin-chores", of: app)

        // Out on the scoreboard: the new player is there, and her code opens the admin area too.
        goBack(in: app)
        XCTAssertTrue(playerRow("samantha", in: app).waitForExistence(timeout: wait))
        unlockAdmin(in: app, code: "1357")
        goBack(in: app)
    }

    /// Everything the app holds can be wiped from inside it.
    func testEraseEverythingStartsOver() {
        let app = launch(["-resetData", "-demoData"])
        XCTAssertTrue(app.staticTexts["27/30 · 90%"].waitForExistence(timeout: wait))
        unlockAdmin(in: app)
        adminSection("device", in: app)
        XCTAssertTrue(app.staticTexts["YOUR DATA"].waitForExistence(timeout: wait))
        screenshot("30-admin-device", of: app)
        app.buttons["erase everything…"].tap()
        let confirm = app.buttons["Erase players, chores and points"]
        XCTAssertTrue(confirm.waitForExistence(timeout: wait))
        confirm.tap()

        // Back to a fresh install, and it stays that way after a restart.
        XCTAssertTrue(app.buttons["> SET UP THIS DEVICE"].waitForExistence(timeout: wait))
        XCTAssertFalse(playerRow("riley", in: app).exists)
        app.terminate()
        let relaunched = launch()
        XCTAssertTrue(relaunched.buttons["> SET UP THIS DEVICE"].waitForExistence(timeout: wait))
        XCTAssertFalse(relaunched.staticTexts["27/30 · 90%"].exists)
    }

    func testDemoHistoryShowsTheDailyLogAndVerdicts() {
        let app = launch(["-resetData", "-demoData"])

        // Thirty days: the steady player takes every ninth day off, so 27 of 30.
        XCTAssertTrue(app.staticTexts["27/30 · 90%"].waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["15/30 · 50%"].exists)
        XCTAssertFalse(playerRow("riley", in: app).label.contains("v1.0"), "a month of approved chores levels you up")
        screenshot("10-home-with-history", of: app)

        // The second player's chores for today are waiting on an admin.
        open("sam", in: app)
        XCTAssertTrue(app.staticTexts["card submitted — waiting on an admin"].waitForExistence(timeout: wait))
        screenshot("11-card-awaiting", of: app)

        // The first player's are approved.
        goBack(in: app)
        open("riley", in: app)
        XCTAssertTrue(app.staticTexts["✓ all approved — nice work"].waitForExistence(timeout: wait))
        screenshot("12-card-approved", of: app)

        goBack(in: app)
        // However far the list is pushed, the title stays where it is.
        let title = app.staticTexts["GYATTCHORES"]
        let before = title.frame
        app.staticTexts["27/30 · 90%"].swipeUp()
        XCTAssertEqual(title.frame, before, "the title shouldn't scroll away")
        XCTAssertTrue(title.isHittable)
        screenshot("14-home-pushed-up", of: app)
    }

    /// A bug we shipped: chores were submitted under a player's name, a parent rejected them all, and
    /// the player was stuck — a card of ✗s, nothing left to pick, "already submitted" for the day.
    /// A rejected day isn't a finished day: they get the picker back and can submit a new card.
    func testARejectedDayStartsOver() {
        let app = launch(["-resetData", "-demoData", "-demoRejectedDay"])

        open("sam", in: app)
        let main = mainButton(in: app)
        XCTAssertTrue(main.waitForExistence(timeout: wait))
        XCTAssertEqual(main.label, "> PICK OR SUGGEST CHORES", "a day of rejections should offer the picker, not a finished card")
        XCTAssertTrue(app.staticTexts["today's earlier chores were rejected — build a new card"].exists)
        // The other player's six approved chores are spoken for today.
        XCTAssertTrue(app.staticTexts["6 chores already taken by someone else today"].exists)
        XCTAssertFalse(app.buttons["+ bonus round"].exists)
        screenshot("15-rejected-day-picker", of: app)

        app.buttons["✨ suggest a 25-min card"].tap()
        XCTAssertEqual(main.label, "> LOCK IN CARD")
        main.tap()
        checkOffEverything(in: app).tap()

        // The new card is in and waiting; nothing on it reads as rejected.
        let waiting = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'waiting on an admin'")).firstMatch
        XCTAssertTrue(waiting.waitForExistence(timeout: wait))
        XCTAssertEqual(uncheckedChores(in: app).count, 0)
        screenshot("16-rejected-day-resubmitted", of: app)

        // Someone else's day is untouched.
        goBack(in: app)
        open("riley", in: app)
        XCTAssertTrue(app.staticTexts["✓ all approved — nice work"].waitForExistence(timeout: wait))
    }

    /// A display name is a nickname on top of the username: it shows everywhere the player does,
    /// survives a relaunch, and can be dropped again, leaving the username as it was.
    func testADisplayNameSitsOnTopOfTheUsername() {
        let app = launch(["-resetData", "-demoFamily"])
        let nickname = "xX_D1no_K1ng_Xx"

        // A player gives themselves a display name from their own screen: no admin needed.
        open("sam", in: app)
        app.buttons["✎ name"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: wait))
        field.typeText(nickname)
        app.alerts.buttons["Save"].tap()

        // It replaces the username wherever the player is shown…
        XCTAssertTrue(app.staticTexts[nickname].waitForExistence(timeout: wait))
        XCTAssertTrue(mainButton(in: app).waitForExistence(timeout: wait), "their day still opens as normal")
        goBack(in: app)
        XCTAssertTrue(playerRow(nickname, in: app).waitForExistence(timeout: wait))
        XCTAssertFalse(playerRow("sam", in: app).exists)
        XCTAssertTrue(playerRow("riley", in: app).exists, "nobody else's name changes")
        screenshot("19-display-name", of: app)

        // …is still there after the app restarts…
        app.terminate()
        let relaunched = launch()
        XCTAssertTrue(playerRow(nickname, in: relaunched).waitForExistence(timeout: wait))

        // …and comes off again, with the username underneath untouched.
        open(nickname, in: relaunched)
        relaunched.buttons["✎ name"].tap()
        XCTAssertTrue(relaunched.alerts.buttons["Use my username"].waitForExistence(timeout: wait))
        relaunched.alerts.buttons["Use my username"].tap()
        goBack(in: relaunched)
        XCTAssertTrue(playerRow("sam", in: relaunched).waitForExistence(timeout: wait))
        XCTAssertFalse(playerRow(nickname, in: relaunched).exists)
    }

    /// One chore, one person, per day — including when two players go for the same chores at once.
    func testAChoreCanOnlyBeOnePersonsEachDay() {
        let app = launch(["-resetData", "-demoFamily"])

        // sam builds a card but doesn't submit it yet.
        open("sam", in: app)
        app.buttons["✨ suggest a 25-min card"].tap()
        app.buttons["> LOCK IN CARD"].tap()
        XCTAssertTrue(app.buttons["> CHECK OFF EVERYTHING FIRST"].waitForExistence(timeout: wait))
        let onCard = uncheckedChores(in: app).count
        XCTAssertGreaterThan(onCard, 0)

        // riley is offered the same suggestion, takes it, and gets it in first.
        goBack(in: app)
        open("riley", in: app)
        app.buttons["✨ suggest a 25-min card"].tap()
        app.buttons["> LOCK IN CARD"].tap()
        checkOffEverything(in: app).tap()
        XCTAssertTrue(app.staticTexts["card submitted — waiting on an admin"].waitForExistence(timeout: wait))

        // Back on sam's card every chore now reads as taken, and it can't be submitted.
        goBack(in: app)
        open("sam", in: app)
        let blocked = app.buttons["> ALL TAKEN TODAY — CHANGE PICKS"]
        XCTAssertTrue(blocked.waitForExistence(timeout: wait))
        XCTAssertFalse(blocked.isEnabled)
        XCTAssertEqual(uncheckedChores(in: app).count, 0, "taken chores can't be checked off")
        XCTAssertTrue(app.staticTexts["taken = someone else got it first today — it won't be submitted"].exists)
        screenshot("17-card-all-taken", of: app)

        // Picking again offers only what's left, and that card goes in.
        app.buttons["change my picks"].tap()
        let taken = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH 'already taken by someone else today'")).firstMatch
        XCTAssertTrue(taken.waitForExistence(timeout: wait))
        XCTAssertTrue(taken.label.hasPrefix("\(onCard) chore"), taken.label)
        screenshot("18-picker-with-taken", of: app)
        app.buttons["✨ suggest a 25-min card"].tap()
        app.buttons["> LOCK IN CARD"].tap()
        checkOffEverything(in: app).tap()
        XCTAssertTrue(app.staticTexts["card submitted — waiting on an admin"].waitForExistence(timeout: wait))
    }

    func testIPadShowsTheListAndTheDaySideBySide() throws {
        try XCTSkipUnless(isPad, "two panes are the iPad layout")
        let app = launch(["-resetData", "-demoData"])

        // Nothing picked yet: the list on the left, a prompt on the right.
        XCTAssertTrue(app.staticTexts["> pick a player"].waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["27/30 · 90%"].exists)
        screenshot("ipad-01-nothing-picked", of: app)

        // A player's day opens on the right; the list stays, with that player highlighted.
        open("sam", in: app)
        XCTAssertTrue(app.staticTexts["card submitted — waiting on an admin"].waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["27/30 · 90%"].exists, "the home list stays on screen")
        XCTAssertFalse(app.staticTexts["> pick a player"].exists)
        XCTAssertFalse(app.buttons["← back"].exists, "nothing to go back to beside the list")
        let listRight = playerRow("sam", in: app).frame.maxX
        let dayLeft = app.staticTexts["card submitted — waiting on an admin"].frame.minX
        XCTAssertLessThan(listRight, dayLeft, "the day sits to the right of the list, not over it")
        screenshot("ipad-02-day-beside-list", of: app)

        // Picking someone else swaps the right-hand side.
        open("riley", in: app)
        XCTAssertTrue(app.staticTexts["✓ all approved — nice work"].waitForExistence(timeout: wait))
        XCTAssertFalse(playerRow("sam", in: app).isSelected)

        // The bonus picker needs its own way back, since there's no screen behind it.
        app.buttons["+ bonus round"].tap()
        XCTAssertTrue(app.buttons["> PICK CHORES TO LOG"].waitForExistence(timeout: wait))
        goBack(in: app)
        XCTAssertTrue(app.staticTexts["✓ all approved — nice work"].waitForExistence(timeout: wait))

        // The admin area opens on the right too, and closing it returns to the day.
        app.buttons["admin"].tap()
        XCTAssertTrue(app.secureTextFields.firstMatch.waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["27/30 · 90%"].exists, "the home list stays on screen")
        XCTAssertFalse(playerRow("riley", in: app).isSelected, "no player is highlighted while the admin area is open")
        screenshot("ipad-03-admin-area", of: app)
        goBack(in: app)
        XCTAssertTrue(app.staticTexts["✓ all approved — nice work"].waitForExistence(timeout: wait))

        // Turned sideways it's still two panes on the same screen.
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.staticTexts["✓ all approved — nice work"].waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["27/30 · 90%"].exists)
        XCTAssertTrue(playerRow("riley", in: app).isSelected)
        let wide = app.windows.firstMatch.frame
        XCTAssertGreaterThan(wide.width, wide.height, "the app should have turned with the iPad")
        XCTAssertLessThan(playerRow("riley", in: app).frame.maxX,
                          app.staticTexts["✓ all approved — nice work"].frame.minX)
        // The whole screen, not the app's own snapshot, which comes back cropped when sideways.
        let sideways = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        sideways.name = "ipad-04-landscape"
        sideways.lifetime = .keepAlways
        add(sideways)
        XCUIDevice.shared.orientation = .portrait
    }
}
