import XCTest

/// Drives the real app in a simulator: a kid's day from picking chores to
/// submitting, the bonus round, the parent gate, and the save file surviving a
/// relaunch. Screenshots are attached to the test results.
final class GyattChoresUITests: XCTestCase {
    private let wait: TimeInterval = 20

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Helpers

    private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func chores(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'chore-'"))
    }

    private func screenshot(_ name: String, of app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Tap something that may be sitting under the bottom action bar: nudge the
    /// page up until it can actually be hit.
    private func tapScrollingIntoReach(_ target: XCUIElement, in app: XCUIApplication) {
        var nudges = 0
        while !target.isHittable, nudges < 8 {
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.40))
            from.press(forDuration: 0.05, thenDragTo: to)
            nudges += 1
        }
        target.tap()
    }

    private func label(of identifier: String, in app: XCUIApplication) -> String {
        let found = element(identifier, in: app)
        XCTAssertTrue(found.waitForExistence(timeout: wait), "\(identifier) should be on screen")
        return found.label
    }

    // MARK: Tests

    func testADayFromPickingToSubmitting() {
        let app = launch(["-resetData"])

        // Home: both players, and an empty daily log.
        XCTAssertTrue(element("title", in: app).waitForExistence(timeout: wait))
        XCTAssertTrue(element("player-1", in: app).exists)
        XCTAssertTrue(element("player-2", in: app).exists)
        XCTAssertTrue(app.staticTexts["25-MINUTE DAILY LOG"].exists)
        XCTAssertFalse(element("daily-log-bekindhearted", in: app).exists, "no grid before anything is approved")
        screenshot("01-home-empty", of: app)

        // Picker: nothing picked, so the card can't be locked in yet.
        element("player-1", in: app).tap()
        let confirm = element("confirm", in: app)
        XCTAssertTrue(confirm.waitForExistence(timeout: wait))
        XCTAssertFalse(confirm.isEnabled)
        XCTAssertEqual(chores(in: app).count, 27, "the whole chore pool is offered")
        screenshot("02-picker-empty", of: app)

        // Suggest a full card, then lock it in.
        element("fill", in: app).tap()
        XCTAssertTrue(confirm.isEnabled)
        XCTAssertTrue(confirm.label.hasPrefix("LOCK IN"), confirm.label)
        screenshot("03-picker-suggested", of: app)
        confirm.tap()

        // Card: submit stays off until every chore is checked.
        let submit = element("submit", in: app)
        XCTAssertTrue(submit.waitForExistence(timeout: wait))
        XCTAssertFalse(submit.isEnabled)
        let onCard = chores(in: app).count
        XCTAssertGreaterThan(onCard, 0)
        XCTAssertLessThan(onCard, 27)
        screenshot("04-card-unchecked", of: app)

        for index in 0..<onCard {
            tapScrollingIntoReach(chores(in: app).element(boundBy: index), in: app)
        }
        XCTAssertTrue(submit.isEnabled)
        XCTAssertEqual(submit.label, "SUBMIT CARD")
        screenshot("05-card-checked", of: app)

        submit.tap()
        XCTAssertEqual(label(of: "verdict", in: app), "SUBMITTED — AWAITING APPROVAL")
        screenshot("06-card-submitted", of: app)

        // Bonus round: one extra chore, logged straight to pending.
        element("bonus", in: app).tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: wait))
        XCTAssertEqual(chores(in: app).count, 27 - onCard, "chores already on the card aren't offered again")
        chores(in: app).element(boundBy: 0).tap()
        XCTAssertTrue(confirm.label.hasPrefix("LOG 1 BONUS CHORE"), confirm.label)
        screenshot("07-bonus-picker", of: app)
        confirm.tap()
        let bonusRows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'bonus-'"))
        XCTAssertTrue(bonusRows.firstMatch.waitForExistence(timeout: wait))
        XCTAssertEqual(bonusRows.count, 1)
        screenshot("08-card-with-bonus", of: app)

        // Relaunch: the day is still there.
        app.terminate()
        let relaunched = launch()
        XCTAssertTrue(element("player-1", in: relaunched).waitForExistence(timeout: wait))
        element("player-1", in: relaunched).tap()
        XCTAssertEqual(label(of: "verdict", in: relaunched), "SUBMITTED — AWAITING APPROVAL")
        XCTAssertTrue(relaunched.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'bonus-'")).firstMatch.exists)

        // The other player's day is untouched.
        relaunched.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(element("player-2", in: relaunched).waitForExistence(timeout: wait))
        element("player-2", in: relaunched).tap()
        XCTAssertTrue(element("confirm", in: relaunched).waitForExistence(timeout: wait))
    }

    func testParentGateRejectsAWrongCode() {
        let app = launch(["-resetData"])
        let title = element("title", in: app)
        XCTAssertTrue(title.waitForExistence(timeout: wait))

        // Four taps aren't enough.
        title.tap(withNumberOfTaps: 4, numberOfTouches: 1)
        XCTAssertFalse(element("admin-code", in: app).waitForExistence(timeout: 3))

        sleep(3)   // let the tap streak lapse
        title.tap(withNumberOfTaps: 5, numberOfTouches: 1)
        let code = element("admin-code", in: app)
        XCTAssertTrue(code.waitForExistence(timeout: wait))
        code.tap()
        code.typeText("definitely-not-it")
        element("admin-enter", in: app).tap()
        XCTAssertTrue(element("admin-wrong-code", in: app).waitForExistence(timeout: wait))
        XCTAssertFalse(app.buttons["APPROVE"].exists, "a wrong code must not reach the approvals")
        screenshot("09-admin-wrong-code", of: app)

        app.buttons["Close"].tap()
        XCTAssertTrue(element("player-1", in: app).waitForExistence(timeout: wait))
    }

    func testDemoHistoryShowsTheDailyLogAndStats() {
        let app = launch(["-demoData"])
        XCTAssertTrue(element("title", in: app).waitForExistence(timeout: wait))

        // 30 days: the steady player skips every ninth day, so 27 of 30.
        let steady = label(of: "daily-log-bekindhearted", in: app)
        XCTAssertTrue(steady.contains("27 of the last 30 days"), steady)
        XCTAssertTrue(element("daily-log-megadinolava", in: app).exists)
        screenshot("10-home-with-history", of: app)

        // The second player's chores for today are waiting on a parent.
        element("player-2", in: app).tap()
        XCTAssertEqual(label(of: "verdict", in: app), "SUBMITTED — AWAITING APPROVAL")
        screenshot("11-card-awaiting", of: app)

        // The first player's are approved.
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(element("player-1", in: app).waitForExistence(timeout: wait))
        element("player-1", in: app).tap()
        XCTAssertTrue(label(of: "verdict", in: app).hasPrefix("ALL APPROVED"))
        screenshot("12-card-approved", of: app)
    }
}
