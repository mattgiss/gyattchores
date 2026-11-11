import XCTest

/// Drives the real app in a simulator: a kid's day from picking chores to submitting, the bonus
/// round, the save surviving a relaunch, and the parent gate. Screenshots are attached to the results.
///
/// Every launch passes `-uiTesting`, which gives the app a separate data folder and turns sync
/// off — these tests must never reach the family's real chores. `launch` checks that it took.
final class GyattChoresUITests: XCTestCase {
    private let wait: TimeInterval = 20

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

    /// The big "> LABEL" button at the bottom of the picker and the card.
    private func mainButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH '> '")).firstMatch
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

    private func open(_ name: String, in app: XCUIApplication) {
        let row = playerRow(name, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: wait), "\(name) should be on the home screen")
        row.tap()
    }

    private func goBack(in app: XCUIApplication) {
        app.buttons["← back"].tap()
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

        let submit = app.buttons["> SUBMIT FOR APPROVAL"]
        var steps = 0
        while !submit.exists, steps < 40 {
            steps += 1
            let next = uncheckedChores(in: app).firstMatch
            if next.exists, next.isHittable { next.tap() } else { nudgeUp(app) }
        }
        XCTAssertTrue(submit.exists, "checking every chore off should enable submit")
        XCTAssertTrue(submit.isEnabled)
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
    }
}
