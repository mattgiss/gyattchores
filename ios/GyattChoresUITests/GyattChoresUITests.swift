import XCTest

/// Drives the real app in a simulator: a kid's day from picking chores to submitting, the bonus
/// round, the save surviving a relaunch, and the parent gate. Screenshots are attached to the results.
///
/// The same tests run on an iPhone (one screen at a time) and an iPad (home list on the left, the
/// open screen on the right); the helpers below paper over the difference in getting around.
///
/// Every launch passes `-uiTesting`, which gives the app a separate data folder and turns sync
/// off — these tests must never reach the family's real chores. `launch` checks that it took.
final class GyattChoresUITests: XCTestCase {
    private let wait: TimeInterval = 20
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Helpers

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + extra
        app.launch()
        XCTAssertTrue(app.staticTexts["GYATTCHORES"].waitForExistence(timeout: wait))
        let syncOff = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'off (ui testing)'")).firstMatch
        XCTAssertTrue(syncOff.waitForExistence(timeout: wait), "the app must be in test mode (no sync) before a test touches anything")
        return app
    }

    /// The row on the home screen that opens a player's day (it's the one showing their streak).
    private func playerRow(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS '🔥'", name)).firstMatch
    }

    /// The big "> LABEL" button at the bottom of the picker and the card. The home screen's player
    /// rows and its dares button also start with "> ", and the home screen is still around while
    /// the next screen slides in (and always, on an iPad), so rule those out.
    private func mainButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '> ' AND NOT (label CONTAINS '🔥') AND NOT (label CONTAINS 'DARES')")).firstMatch
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
    /// the parent area, the dares or the bonus picker is open.
    private func goBack(in app: XCUIApplication) {
        let back = app.buttons["← back"]
        if back.exists { back.tap() }
        XCTAssertTrue(app.staticTexts["GYATTCHORES"].waitForExistence(timeout: wait))
    }

    // MARK: Tests

    func testADayFromPickingToSubmitting() {
        let app = launch(["-resetData"])

        // Home: both players, nobody has cleared a day yet.
        XCTAssertTrue(playerRow("bekindhearted", in: app).exists)
        XCTAssertTrue(playerRow("megadinolava", in: app).exists)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == '0/30 · 0%'")).count, 2)
        screenshot("01-home-empty", of: app)

        // Picker: nothing picked, so the card can't be locked in yet.
        open("bekindhearted", in: app)
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
        XCTAssertTrue(app.staticTexts["card submitted — waiting on a parent"].waitForExistence(timeout: wait))
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
        XCTAssertTrue(app.staticTexts["card submitted — waiting on a parent"].exists)
        screenshot("08-card-with-bonus", of: app)

        // Relaunch: the day is still there.
        app.terminate()
        let relaunched = launch()
        open("bekindhearted", in: relaunched)
        XCTAssertTrue(relaunched.staticTexts["card submitted — waiting on a parent"].waitForExistence(timeout: wait))
        XCTAssertTrue(relaunched.staticTexts["BONUS ROUND"].exists)

        // The other player's day is untouched.
        goBack(in: relaunched)
        open("megadinolava", in: relaunched)
        XCTAssertTrue(relaunched.buttons["> PICK OR SUGGEST CHORES"].waitForExistence(timeout: wait))
    }

    func testParentGateRejectsAWrongCode() {
        let app = launch(["-resetData"])
        let title = app.staticTexts["GYATTCHORES"]
        let code = app.secureTextFields.firstMatch

        // Four taps aren't enough.
        title.tap(withNumberOfTaps: 4, numberOfTouches: 1)
        XCTAssertFalse(code.waitForExistence(timeout: 3))

        sleep(3)   // let the tap streak lapse
        title.tap(withNumberOfTaps: 5, numberOfTouches: 1)
        XCTAssertTrue(code.waitForExistence(timeout: wait))
        code.tap()
        code.typeText("definitely-not-it")
        app.buttons["> UNLOCK"].tap()
        XCTAssertTrue(app.staticTexts["that code didn't match"].waitForExistence(timeout: wait))
        XCTAssertEqual(app.segmentedControls.count, 0, "a wrong code must not reach the approvals")
        XCTAssertFalse(app.buttons["+ add player"].exists)
        screenshot("09-admin-wrong-code", of: app)

        goBack(in: app)
    }

    func testDemoHistoryShowsTheDailyLogAndVerdicts() {
        let app = launch(["-resetData", "-demoData"])

        // Thirty days: the steady player takes every ninth day off, so 27 of 30.
        XCTAssertTrue(app.staticTexts["27/30 · 90%"].waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["15/30 · 50%"].exists)
        XCTAssertFalse(playerRow("bekindhearted", in: app).label.contains("v1.0"), "a month of approved chores levels you up")
        screenshot("10-home-with-history", of: app)

        // The second player's chores for today are waiting on a parent.
        open("megadinolava", in: app)
        XCTAssertTrue(app.staticTexts["card submitted — waiting on a parent"].waitForExistence(timeout: wait))
        screenshot("11-card-awaiting", of: app)

        // The first player's are approved.
        goBack(in: app)
        open("bekindhearted", in: app)
        XCTAssertTrue(app.staticTexts["✓ all approved — nice work"].waitForExistence(timeout: wait))
        screenshot("12-card-approved", of: app)

        // Say whose phone this is: the home screen swaps the question for the dares button.
        goBack(in: app)
        app.buttons["bekindhearted"].tap()
        XCTAssertTrue(app.buttons["> DARES · 3 LEFT TODAY"].waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["this phone: bekindhearted"].exists)
        screenshot("13-home-with-dares", of: app)

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

        open("megadinolava", in: app)
        let main = mainButton(in: app)
        XCTAssertTrue(main.waitForExistence(timeout: wait))
        XCTAssertEqual(main.label, "> PICK OR SUGGEST CHORES", "a day of rejections should offer the picker, not a finished card")
        XCTAssertTrue(app.staticTexts["today's earlier chores were rejected — build a new card"].exists)
        XCTAssertFalse(app.buttons["+ bonus round"].exists)
        screenshot("15-rejected-day-picker", of: app)

        app.buttons["✨ suggest a 25-min card"].tap()
        XCTAssertEqual(main.label, "> LOCK IN CARD")
        main.tap()
        checkOffEverything(in: app).tap()

        // The new card is in and waiting; nothing on it reads as rejected.
        let waiting = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'waiting on a parent'")).firstMatch
        XCTAssertTrue(waiting.waitForExistence(timeout: wait))
        XCTAssertEqual(uncheckedChores(in: app).count, 0)
        screenshot("16-rejected-day-resubmitted", of: app)

        // Someone else's day is untouched.
        goBack(in: app)
        open("bekindhearted", in: app)
        XCTAssertTrue(app.staticTexts["✓ all approved — nice work"].waitForExistence(timeout: wait))
    }

    func testIPadShowsTheListAndTheDaySideBySide() throws {
        try XCTSkipUnless(isPad, "two panes are the iPad layout")
        let app = launch(["-resetData", "-demoData"])

        // Nothing picked yet: the list on the left, a prompt on the right.
        XCTAssertTrue(app.staticTexts["> pick a player"].waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["27/30 · 90%"].exists)
        screenshot("ipad-01-nothing-picked", of: app)

        // A player's day opens on the right; the list stays, with that player highlighted.
        open("megadinolava", in: app)
        XCTAssertTrue(app.staticTexts["card submitted — waiting on a parent"].waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["27/30 · 90%"].exists, "the home list stays on screen")
        XCTAssertFalse(app.staticTexts["> pick a player"].exists)
        XCTAssertFalse(app.buttons["← back"].exists, "nothing to go back to beside the list")
        let listRight = playerRow("megadinolava", in: app).frame.maxX
        let dayLeft = app.staticTexts["card submitted — waiting on a parent"].frame.minX
        XCTAssertLessThan(listRight, dayLeft, "the day sits to the right of the list, not over it")
        screenshot("ipad-02-day-beside-list", of: app)

        // Picking someone else swaps the right-hand side.
        open("bekindhearted", in: app)
        XCTAssertTrue(app.staticTexts["✓ all approved — nice work"].waitForExistence(timeout: wait))
        XCTAssertFalse(playerRow("megadinolava", in: app).isSelected)

        // The bonus picker needs its own way back, since there's no screen behind it.
        app.buttons["+ bonus round"].tap()
        XCTAssertTrue(app.buttons["> PICK CHORES TO LOG"].waitForExistence(timeout: wait))
        goBack(in: app)
        XCTAssertTrue(app.staticTexts["✓ all approved — nice work"].waitForExistence(timeout: wait))

        // The parent area opens on the right too, and closing it returns to the day.
        app.staticTexts["GYATTCHORES"].tap(withNumberOfTaps: 5, numberOfTouches: 1)
        XCTAssertTrue(app.secureTextFields.firstMatch.waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["27/30 · 90%"].exists, "the home list stays on screen")
        XCTAssertFalse(playerRow("bekindhearted", in: app).isSelected, "no player is highlighted while the parent area is open")
        screenshot("ipad-03-parent-area", of: app)
        goBack(in: app)
        XCTAssertTrue(app.staticTexts["✓ all approved — nice work"].waitForExistence(timeout: wait))

        // Turned sideways it's still two panes on the same screen.
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.staticTexts["✓ all approved — nice work"].waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["27/30 · 90%"].exists)
        XCTAssertTrue(playerRow("bekindhearted", in: app).isSelected)
        let wide = app.windows.firstMatch.frame
        XCTAssertGreaterThan(wide.width, wide.height, "the app should have turned with the iPad")
        XCTAssertLessThan(playerRow("bekindhearted", in: app).frame.maxX,
                          app.staticTexts["✓ all approved — nice work"].frame.minX)
        // The whole screen, not the app's own snapshot, which comes back cropped when sideways.
        let sideways = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        sideways.name = "ipad-04-landscape"
        sideways.lifetime = .keepAlways
        add(sideways)
        XCUIDevice.shared.orientation = .portrait
    }
}
