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
final class DOYOURWORKUITests: XCTestCase {
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
        XCTAssertTrue(app.staticTexts["DOYOURWORK"].waitForExistence(timeout: wait))
        return app
    }

    private func type(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: wait))
        field.tap()
        field.typeText(text)
    }

    /// Opens the admin area and unlocks it.
    private func unlockAdmin(in app: XCUIApplication, code: String? = nil) {
        app.buttons["Admin"].tap()
        type(code ?? adminCode, into: app.secureTextFields.firstMatch)
        app.buttons["Unlock"].tap()
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: wait), "the right code opens the admin area")
    }

    private func adminSection(_ name: String, in app: XCUIApplication) {
        app.segmentedControls.firstMatch.buttons[name.prefix(1).uppercased() + name.dropFirst()].tap()
    }

    /// Taps Save in the system's save panel and waits for the app to say the backup was saved. A
    /// backup from earlier in the run has today's file name too, so iOS may first ask whether to
    /// replace it, which on a slow simulator can take a while to appear.
    private func confirmBackupSave(in app: XCUIApplication) {
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: wait), "the save panel should open")
        saveButton.tap()
        let saved = app.staticTexts["Backup saved. Keep it somewhere safe, like Files or iCloud Drive."]
        let replace = app.buttons["Replace"]
        let deadline = Date().addingTimeInterval(wait)
        while Date() < deadline && !saved.exists {
            if replace.exists { replace.tap() }
            _ = saved.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(saved.exists, "the app should say the backup was saved")
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

    /// A full-screen picture for the App Store listing, named "store-…" so CI can tell these from
    /// the other screenshots.
    private func storeScreenshot(_ name: String, of app: XCUIApplication) {
        Thread.sleep(forTimeInterval: 1.5)   // let screens finish sliding in and progress bars finish filling
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "store-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The row on the home screen that opens a player's day (it's the one showing their points).
    private func playerRow(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS ' pts'", name)).firstMatch
    }

    /// The big band button at the bottom of the picker and the card. The home screen is still
    /// around while the next screen slides in (and always, on an iPad), and its dares button is the
    /// same kind of button, so rule that out.
    private func mainButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == 'main' AND NOT (label BEGINSWITH 'Make a dare')")).firstMatch
    }

    /// The puzzle's play button. On a narrow phone it leaves out the puzzle's name, so match the end.
    private func playButton(level: Int, minutes: Int, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "Play level \(level) · ", " \(minutes) min")).firstMatch
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
        let submit = app.buttons["Send it off for approval"]
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
            XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: wait), "\(name)'s screen should open")
        }
    }

    /// Back to the home list. On an iPad it never left, so there's only something to close when
    /// the admin area or the bonus picker is open.
    private func goBack(in app: XCUIApplication) {
        let back = app.buttons["Back"]
        if back.exists { back.tap() }
        XCTAssertTrue(app.staticTexts["DOYOURWORK"].waitForExistence(timeout: wait))
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
        XCTAssertEqual(main.label, "Pick some chores, or let me suggest some")
        XCTAssertFalse(main.isEnabled)
        XCTAssertTrue(app.staticTexts["0 of 25 minutes"].exists)
        screenshot("02-picker-empty", of: app)

        // Suggest a full card, then lock it in.
        app.buttons["Suggest a 25-minute card"].tap()
        XCTAssertEqual(main.label, "Lock in my card")
        XCTAssertTrue(main.isEnabled)
        XCTAssertFalse(app.staticTexts["0 of 25 minutes"].exists, "the suggestion added minutes")
        screenshot("03-picker-suggested", of: app)
        main.tap()

        // Card: submit stays off until every chore is checked.
        XCTAssertTrue(app.buttons["Check everything off first"].waitForExistence(timeout: wait))
        XCTAssertFalse(mainButton(in: app).isEnabled)
        XCTAssertGreaterThan(uncheckedChores(in: app).count, 0)
        screenshot("04-card-unchecked", of: app)

        let submit = checkOffEverything(in: app)
        screenshot("05-card-checked", of: app)

        submit.tap()
        XCTAssertTrue(app.staticTexts["Sent! Now it's waiting for an admin to look at it."].waitForExistence(timeout: wait))
        XCTAssertEqual(uncheckedChores(in: app).count, 0, "a submitted card can't be unchecked")
        screenshot("06-card-submitted", of: app)

        // Bonus round: one extra chore, logged straight to pending.
        app.buttons["Do a bonus round"].tap()
        XCTAssertTrue(app.buttons["Pick the chores you did"].waitForExistence(timeout: wait))
        uncheckedChores(in: app).firstMatch.tap()
        let logOne = app.buttons["Log this chore"]
        XCTAssertTrue(logOne.waitForExistence(timeout: wait))
        screenshot("07-bonus-picker", of: app)
        logOne.tap()
        XCTAssertTrue(app.staticTexts["Bonus round"].waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["Sent! Now it's waiting for an admin to look at it."].exists)
        screenshot("08-card-with-bonus", of: app)

        // Relaunch: the day is still there.
        app.terminate()
        let relaunched = launch()
        open("riley", in: relaunched)
        XCTAssertTrue(relaunched.staticTexts["Sent! Now it's waiting for an admin to look at it."].waitForExistence(timeout: wait))
        XCTAssertTrue(relaunched.staticTexts["Bonus round"].exists)

        // The other player's day is untouched.
        goBack(in: relaunched)
        open("sam", in: relaunched)
        XCTAssertTrue(relaunched.buttons["Pick some chores, or let me suggest some"].waitForExistence(timeout: wait))
    }

    func testAdminGateAndApprovals() {
        let app = launch(["-resetData", "-demoData"])
        let code = app.secureTextFields.firstMatch

        // A wrong code gets nowhere.
        app.buttons["Admin"].tap()
        type("definitely-not-it", into: code)
        app.buttons["Unlock"].tap()
        XCTAssertTrue(app.staticTexts["That code didn't match. Try again?"].waitForExistence(timeout: wait))
        XCTAssertEqual(app.segmentedControls.count, 0, "a wrong code must not reach the approvals")
        XCTAssertFalse(app.buttons["Approve this chore"].exists)
        screenshot("09-admin-wrong-code", of: app)

        // The admin's code opens it: sam's chores from today are waiting.
        type(adminCode, into: code)
        app.buttons["Unlock"].tap()
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: wait))
        let approve = app.buttons["Approve this chore"].firstMatch
        XCTAssertTrue(approve.waitForExistence(timeout: wait))
        screenshot("09b-admin-approvals", of: app)
        var approved = 0
        // Each row redraws as it's judged, so give the next one a moment to appear.
        while approve.waitForExistence(timeout: 2), approved < 30 { approve.tap(); approved += 1 }
        XCTAssertGreaterThan(approved, 0)
        XCTAssertTrue(app.staticTexts["Nothing's waiting for you. All caught up!"].waitForExistence(timeout: wait))

        // Back on sam's card, everything reads approved.
        goBack(in: app)
        open("sam", in: app)
        XCTAssertTrue(app.staticTexts["Everything's approved. Nice work!"].waitForExistence(timeout: wait))
    }

    /// The admin's code box is ready to type into as soon as the lock screen opens, and a day's
    /// worth of one person's chores is approved with one tap.
    func testApproveAllOfADayInOneTap() {
        let app = launch(["-resetData", "-demoData"])
        app.buttons["Admin"].tap()
        XCTAssertTrue(app.secureTextFields.firstMatch.waitForExistence(timeout: wait))
        // No tap on the field first: it already has the keyboard.
        app.typeText(adminCode + "\n")
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: wait), "the code typed straight away should unlock")
        let all = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Approve all'")).firstMatch
        XCTAssertTrue(all.waitForExistence(timeout: wait), "sam has several chores waiting: there should be an approve-all")
        screenshot("09c-approve-all", of: app)
        all.tap()
        XCTAssertTrue(app.staticTexts["Nothing's waiting for you. All caught up!"].waitForExistence(timeout: wait))
    }

    /// A backup saved to Files brings the whole scoreboard back after erasing everything.
    func testBackupSurvivesErasingEverything() throws {
        let app = launch(["-resetData", "-demoData"])
        XCTAssertTrue(app.staticTexts["27/30 · 90%"].waitForExistence(timeout: wait))
        unlockAdmin(in: app)
        adminSection("device", in: app)

        // Save: the system's save panel, into "On My iPhone/iPad".
        let save = app.buttons["save-backup"]
        XCTAssertTrue(save.waitForExistence(timeout: wait))
        save.tap()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: wait), "the save panel should open")
        screenshot("31-backup-save-panel", of: app)
        confirmBackupSave(in: app)
        app.buttons["OK"].tap()

        // Erase, then restore from the first screen, as a new phone would.
        let erase = app.buttons["Erase everything…"]
        XCTAssertTrue(erase.waitForExistence(timeout: wait))
        erase.tap()
        app.buttons["Erase players, chores and points"].tap()
        let restore = app.buttons["restore-backup"]
        XCTAssertTrue(restore.waitForExistence(timeout: wait), "setup offers restoring a backup")
        restore.tap()
        // Today's file by name: a simulator can still hold backups from earlier runs, with older demo history.
        let day = DateFormatter(); day.locale = Locale(identifier: "en_US_POSIX"); day.dateFormat = "yyyy-MM-dd"
        let file = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "doyourwork-backup-\(day.string(from: Date()))")).firstMatch
        // Older iOS opens the picker on Recents, which may not list the file yet: go to where it was saved.
        if !file.waitForExistence(timeout: 5) {
            for place in ["Browse", "On My iPhone", "On My iPad"] {
                let control = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ AND (elementType == %d OR elementType == %d OR elementType == %d)",
                                                                                   place, XCUIElement.ElementType.button.rawValue,
                                                                                   XCUIElement.ElementType.cell.rawValue, XCUIElement.ElementType.staticText.rawValue)).firstMatch
                if control.waitForExistence(timeout: 3) { control.tap() }
                if file.waitForExistence(timeout: 3) { break }
            }
        }
        XCTAssertTrue(file.waitForExistence(timeout: wait), "the saved backup should be in the picker")
        // Tap the file itself: on older iOS a tap on its name label (in the grid view) doesn't open it.
        let cell = app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", "doyourwork-backup-\(day.string(from: Date()))")).firstMatch
        if cell.exists { cell.tap() } else { file.tap() }
        let confirm = app.buttons["Replace everything here"]
        // Older iOS can select the file without opening it: open it.
        if !confirm.waitForExistence(timeout: 5) {
            let open = app.buttons["Open"]
            if open.waitForExistence(timeout: 3) { open.tap() }
            else if file.exists { file.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: 0, dy: -60)).tap() }
        }
        // On some simulators (CI's), iOS's own file picker ignores taps from UI tests: the file is on
        // screen but never opens. Restoring itself is covered by BackupTests in DoYourWorkCore.
        guard confirm.waitForExistence(timeout: wait) else {
            throw XCTSkip("the system file picker didn't open the backup on this simulator; restore is covered by BackupTests")
        }
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '2 players, 27 chores'")).firstMatch.exists)
        screenshot("32-backup-restore-confirm", of: app)
        confirm.tap()

        // Everything's back: the month of history, and the admin's code.
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Restored:'")).firstMatch.waitForExistence(timeout: wait))
        app.buttons["OK"].tap()
        XCTAssertTrue(app.staticTexts["27/30 · 90%"].waitForExistence(timeout: wait))
        XCTAssertTrue(playerRow("riley", in: app).exists)
        unlockAdmin(in: app)

        // Restoring over a scoreboard that's set up, from the admin area: it says so, and the
        // admin area stays open with the scoreboard intact.
        adminSection("device", in: app)
        let again = app.buttons["restore-backup"]
        XCTAssertTrue(again.waitForExistence(timeout: wait))
        again.tap()
        XCTAssertTrue(file.waitForExistence(timeout: wait))
        file.tap()
        let replaceHere = app.buttons["Replace everything here"]
        XCTAssertTrue(replaceHere.waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'replaced by it'")).firstMatch.exists,
                      "over an existing scoreboard the confirmation warns it will be replaced")
        replaceHere.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Restored:'")).firstMatch.waitForExistence(timeout: wait))
        app.buttons["OK"].tap()
        goBack(in: app)
        XCTAssertTrue(app.staticTexts["27/30 · 90%"].waitForExistence(timeout: wait))
    }

    /// On a phone that's linked, a backup is added to what the family's phones share instead of
    /// replacing it.
    func testALinkedPhoneAddsABackupToTheFamily() throws {
        let app = launch(["-resetData", "-demoData"])
        XCTAssertTrue(app.staticTexts["27/30 · 90%"].waitForExistence(timeout: wait))
        unlockAdmin(in: app)
        adminSection("device", in: app)
        let save = app.buttons["save-backup"]
        XCTAssertTrue(save.waitForExistence(timeout: wait))
        save.tap()
        confirmBackupSave(in: app)
        app.buttons["OK"].tap()

        // Linked (to the in-memory relay), the phone offers adding it, not replacing.
        app.buttons["Add a phone"].tap()
        XCTAssertTrue(app.otherElements["joinQR"].waitForExistence(timeout: wait))
        app.buttons["Done"].tap()
        XCTAssertFalse(app.buttons["Erase everything…"].exists, "a phone in a family doesn't erase it")
        app.buttons["restore-backup"].tap()
        let day = DateFormatter(); day.locale = Locale(identifier: "en_US_POSIX"); day.dateFormat = "yyyy-MM-dd"
        let file = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "doyourwork-backup-\(day.string(from: Date()))")).firstMatch
        if !file.waitForExistence(timeout: 5) {
            for place in ["Browse", "On My iPhone", "On My iPad"] {
                let control = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ AND (elementType == %d OR elementType == %d OR elementType == %d)",
                                                                                   place, XCUIElement.ElementType.button.rawValue,
                                                                                   XCUIElement.ElementType.cell.rawValue, XCUIElement.ElementType.staticText.rawValue)).firstMatch
                if control.waitForExistence(timeout: 3) { control.tap() }
                if file.waitForExistence(timeout: 3) { break }
            }
        }
        XCTAssertTrue(file.waitForExistence(timeout: wait), "the saved backup should be in the picker")
        let cell = app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", "doyourwork-backup-\(day.string(from: Date()))")).firstMatch
        if cell.exists { cell.tap() } else { file.tap() }
        let add = app.buttons["Add it to the family"]
        guard add.waitForExistence(timeout: wait) else {
            throw XCTSkip("the system file picker didn't open the backup on this simulator; restore is covered by BackupTests")
        }
        XCTAssertFalse(app.buttons["Replace everything here"].exists)
        screenshot("33-family-restore-confirm", of: app)
        add.tap()
        // It's this family's own backup, so nothing in it is new.
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Nothing new'")).firstMatch.waitForExistence(timeout: wait))
        app.buttons["OK"].tap()
    }

    /// From a fresh install to a working scoreboard, with chores written in the family's own words.
    func testSettingUpFromNothing() {
        let app = launch(["-resetData"])

        // No players are built in: a fresh install starts with the welcome.
        let start = app.buttons["Set up this device"]
        XCTAssertTrue(start.waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["Everything stays on this device."].exists)
        XCTAssertTrue(app.staticTexts["No accounts, no sign-in, no ads, no tracking."].exists)
        XCTAssertFalse(app.buttons["Admin"].exists)
        screenshot("20-setup-welcome", of: app)
        start.tap()

        // Who's in charge: a name and a code typed twice.
        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: wait))
        XCTAssertFalse(next.isEnabled)
        type("pat", into: app.textFields["admin-name"])
        type("2468", into: app.secureTextFields["admin-code"])
        type("246", into: app.secureTextFields["admin-code-again"])
        XCTAssertTrue(app.staticTexts["Those two codes don't match."].waitForExistence(timeout: wait))
        XCTAssertFalse(next.isEnabled)
        app.secureTextFields["admin-code-again"].typeText("8\n")
        XCTAssertFalse(app.staticTexts["Those two codes don't match."].exists)
        XCTAssertTrue(next.isEnabled)
        screenshot("21-setup-admin", of: app)
        next.tap()

        // Who's playing: one added with the button, one left in the box.
        XCTAssertTrue(app.staticTexts["Who's playing?"].waitForExistence(timeout: wait))
        XCTAssertFalse(next.isEnabled, "someone has to play")
        type("riley\n", into: app.textFields["player-name"])
        XCTAssertTrue(app.staticTexts["riley"].waitForExistence(timeout: wait))
        type("sam", into: app.textFields["player-name"])
        screenshot("22-setup-players", of: app)
        next.tap()

        // What needs doing: said in a sentence, sorted into a list.
        let own = app.buttons["Write or say your own"]
        XCTAssertTrue(own.waitForExistence(timeout: wait))
        XCTAssertTrue(app.buttons["Use the starter list"].exists)
        own.tap()
        type("We need to do the dishes and take out the trash, someone has to feed the dog for 5 minutes. Water plants", into: app.textViews["chore-text"])
        screenshot("23-setup-chores-written", of: app)
        app.buttons["Sort into chores"].tap()
        XCTAssertTrue(app.buttons["Add 4 chores"].waitForExistence(timeout: wait))
        for name in ["do the dishes", "take out the trash", "feed the dog", "water plants"] {
            XCTAssertTrue(app.textFields.matching(NSPredicate(format: "value == %@", name)).firstMatch.exists, "\(name) should be on the list")
        }
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label == '5m'")).firstMatch.exists, "the time that was mentioned is kept")
        screenshot("24-setup-chores-sorted", of: app)
        app.buttons["Leave out water plants"].tap()
        let add = app.buttons["Add 3 chores"]
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
        XCTAssertFalse(relaunched.buttons["Set up this device"].exists)
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
        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: wait))
        XCTAssertFalse(save.isEnabled, "a player needs a name")
        type("sam", into: app.textFields["member-name"])
        XCTAssertTrue(app.staticTexts["Someone already has that name."].waitForExistence(timeout: wait))
        XCTAssertFalse(save.isEnabled)
        app.textFields["member-name"].typeText("antha")
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.buttons["Edit samantha"].waitForExistence(timeout: wait))

        // Make her an admin: that needs a code of her own.
        app.buttons["Edit samantha"].tap()
        flip(app.switches["Admin"])
        XCTAssertFalse(save.isEnabled, "an admin needs a code")
        type("1357", into: app.secureTextFields["member-code"])
        XCTAssertTrue(save.isEnabled)
        screenshot("27-admin-edit-player", of: app)
        save.tap()
        XCTAssertTrue(app.buttons["Edit samantha"].waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["Admin · not playing"].exists, "pat runs the scoreboard without doing chores")
        screenshot("28-admin-players", of: app)

        // The last admin can't be removed, but a player can.
        app.buttons["Edit pat"].tap()
        XCTAssertTrue(save.waitForExistence(timeout: wait))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Remove pat'")).firstMatch.exists, "with two admins, either can go")
        app.buttons["Cancel"].tap()

        // Add a chore in plain words, then find it on the list.
        adminSection("chores", in: app)
        app.buttons["+ add chores"].tap()
        type("feed the fish 2 minutes, make bed", into: app.textViews["chore-text"])
        app.buttons["Sort into chores"].tap()
        let add = app.buttons["Add 1 chore"]
        XCTAssertTrue(add.waitForExistence(timeout: wait), "make bed is already on the list, so only the fish is new")
        add.tap()
        XCTAssertTrue(app.buttons["Edit feed the fish"].waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["28 chores. left undone, a chore takes longer the next time it's picked."].exists)
        screenshot("29-admin-chores", of: app)

        // Out on the scoreboard: the new player is there, and her code opens the admin area too.
        goBack(in: app)
        XCTAssertTrue(playerRow("samantha", in: app).waitForExistence(timeout: wait))
        unlockAdmin(in: app, code: "1357")
        goBack(in: app)
    }

    /// Everything the app holds can be wiped from inside it.
    func testEraseEverythingStartsOver() throws {
        let app = launch(["-resetData", "-demoData"])
        XCTAssertTrue(app.staticTexts["27/30 · 90%"].waitForExistence(timeout: wait))
        unlockAdmin(in: app)
        adminSection("device", in: app)
        XCTAssertTrue(app.staticTexts["Your data"].waitForExistence(timeout: wait))
        screenshot("30-admin-device", of: app)
        app.buttons["Erase everything…"].tap()
        let confirm = app.buttons["Erase players, chores and points"]
        XCTAssertTrue(confirm.waitForExistence(timeout: wait))
        confirm.tap()

        // Back to a fresh install, and it stays that way after a restart.
        XCTAssertTrue(app.buttons["Set up this device"].waitForExistence(timeout: wait))
        XCTAssertFalse(playerRow("riley", in: app).exists)
        app.terminate()
        let relaunched = launch()
        XCTAssertTrue(relaunched.buttons["Set up this device"].waitForExistence(timeout: wait))
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
        XCTAssertTrue(app.staticTexts["Sent! Now it's waiting for an admin to look at it."].waitForExistence(timeout: wait))
        screenshot("11-card-awaiting", of: app)

        // The first player's are approved.
        goBack(in: app)
        open("riley", in: app)
        XCTAssertTrue(app.staticTexts["Everything's approved. Nice work!"].waitForExistence(timeout: wait))
        screenshot("12-card-approved", of: app)

        goBack(in: app)
        // However far the list is pushed, the title stays where it is.
        let title = app.staticTexts["DOYOURWORK"]
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
        XCTAssertEqual(main.label, "Pick some chores, or let me suggest some", "a day of rejections should offer the picker, not a finished card")
        XCTAssertTrue(app.staticTexts["Today's earlier chores were turned down, so let's build a new card."].exists)
        // The other player's six approved chores are spoken for today.
        XCTAssertTrue(app.staticTexts["Someone else already has 6 of today's chores."].exists)
        XCTAssertFalse(app.buttons["Do a bonus round"].exists)
        screenshot("15-rejected-day-picker", of: app)

        app.buttons["Suggest a 25-minute card"].tap()
        XCTAssertEqual(main.label, "Lock in my card")
        main.tap()
        checkOffEverything(in: app).tap()

        // The new card is in and waiting; nothing on it reads as rejected.
        let waiting = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'waiting for an admin'")).firstMatch
        XCTAssertTrue(waiting.waitForExistence(timeout: wait))
        XCTAssertEqual(uncheckedChores(in: app).count, 0)
        screenshot("16-rejected-day-resubmitted", of: app)

        // Someone else's day is untouched.
        goBack(in: app)
        open("riley", in: app)
        XCTAssertTrue(app.staticTexts["Everything's approved. Nice work!"].waitForExistence(timeout: wait))
    }

    /// Submitting today's card unlocks the puzzle. A move that isn't allowed changes nothing;
    /// clearing the board levels up, and the next level is remembered on the card.
    func testSubmittingUnlocksThePuzzleAndClearingLevelsUp() {
        let app = launch(["-resetData", "-demoFamily"])
        open("riley", in: app)
        app.buttons["Suggest a 25-minute card"].tap()
        mainButton(in: app).tap()

        // Locked until the card is in.
        XCTAssertTrue(app.staticTexts["The puzzle opens once you send your card."].waitForExistence(timeout: wait))
        XCTAssertFalse(playButton(level: 1, minutes: 60, in: app).exists)
        checkOffEverything(in: app).tap()

        let play = playButton(level: 1, minutes: 60, in: app)
        XCTAssertTrue(play.waitForExistence(timeout: wait), "a submitted card unlocks the puzzle")
        screenshot("puzzle-1-unlocked", of: app)
        play.tap()

        // Level 1 (native/puzzles.json), four wide:
        //   P K . .      cells 0 and 1
        //   . . . K      cell 7
        //   . . . .
        //   . . . .
        //   . . . P      cell 19
        func cell(_ i: Int) -> XCUIElement { app.descendants(matching: .any)["cell-\(i)"] }
        XCTAssertTrue(cell(0).waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["LVL 1"].exists)
        XCTAssertTrue(app.staticTexts["4 blocks left"].exists)
        screenshot("puzzle-2-level-1", of: app)

        // Pink 0 and black 7 aren't in line: nothing happens.
        cell(0).tap()
        XCTAssertTrue(app.staticTexts["Now tap a block of the other colour in line with it."].waitForExistence(timeout: wait))
        cell(7).tap()
        XCTAssertTrue(app.staticTexts["4 blocks left"].exists, "a move that isn't allowed removes nothing")

        // Black 7 straight down to pink 19.
        cell(7).tap()
        cell(19).tap()
        XCTAssertTrue(app.staticTexts["2 blocks left"].waitForExistence(timeout: wait))
        XCTAssertFalse(cell(7).exists)
        XCTAssertFalse(cell(19).exists)

        // The last pair clears the board: level up.
        cell(0).tap()
        cell(1).tap()
        let levelUp = app.descendants(matching: .any)["Level up"]
        XCTAssertTrue(levelUp.waitForExistence(timeout: wait), "clearing the board levels up")
        XCTAssertTrue(app.staticTexts["LVL 2"].exists)
        XCTAssertTrue(app.staticTexts["4 blocks cleared"].exists)
        let next = app.buttons["Next level"]
        XCTAssertTrue(next.waitForExistence(timeout: wait))
        screenshot("puzzle-3-level-up", of: app)
        next.tap()

        // Level 2 is up, and the card remembers it.
        XCTAssertTrue(app.staticTexts["LVL 2"].waitForExistence(timeout: wait))
        XCTAssertFalse(levelUp.exists)
        XCTAssertTrue(app.staticTexts["4 blocks left"].exists)
        screenshot("puzzle-4-level-2", of: app)
        app.buttons["puzzle-back"].tap()
        XCTAssertTrue(playButton(level: 2, minutes: 60, in: app).waitForExistence(timeout: wait))
    }

    /// The puzzle gets an hour a day per player. The play button counts down; when the hour runs
    /// out mid-level the board is covered and only "back" works, and the day screen says so.
    func testThePuzzleStopsAfterAnHourADay() {
        let app = launch(["-resetData", "-demoFamily", "-puzzleSecondsLeft", "125"])
        open("riley", in: app)
        app.buttons["Suggest a 25-minute card"].tap()
        mainButton(in: app).tap()
        checkOffEverything(in: app).tap()
        let play = playButton(level: 1, minutes: 3, in: app)
        XCTAssertTrue(play.waitForExistence(timeout: wait), "125 seconds left shows as 3 minutes")
        app.terminate()

        // Down to the last few seconds: they run out while the board is up.
        let again = launch(["-puzzleSecondsLeft", "3"])
        open("riley", in: again)
        let last = playButton(level: 1, minutes: 1, in: again)
        XCTAssertTrue(last.waitForExistence(timeout: wait))
        last.tap()
        XCTAssertTrue(again.descendants(matching: .any)["cell-0"].waitForExistence(timeout: wait))
        let covered = again.staticTexts["That's your hour of puzzles for today. See you tomorrow!"]
        XCTAssertTrue(covered.waitForExistence(timeout: 10), "the board is covered when time runs out")
        screenshot("puzzle-time-up", of: again)
        again.buttons["puzzle-timeup-back"].tap()
        XCTAssertTrue(again.staticTexts["That's your hour of puzzles for today. See you tomorrow!"].waitForExistence(timeout: wait))
        XCTAssertFalse(again.buttons.matching(NSPredicate(format: "label BEGINSWITH '> PLAY'")).firstMatch.exists)
    }

    /// A display name is a nickname on top of the username: it shows everywhere the player does,
    /// survives a relaunch, and can be dropped again, leaving the username as it was.
    func testADisplayNameSitsOnTopOfTheUsername() {
        let app = launch(["-resetData", "-demoFamily"])
        let nickname = "xX_D1no_K1ng_Xx"

        // A player gives themselves a display name from their own screen: no admin needed.
        open("sam", in: app)
        app.buttons["Rename"].tap()
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
        relaunched.buttons["Rename"].tap()
        XCTAssertTrue(relaunched.alerts.buttons["Use my username"].waitForExistence(timeout: wait))
        relaunched.alerts.buttons["Use my username"].tap()
        goBack(in: relaunched)
        XCTAssertTrue(playerRow("sam", in: relaunched).waitForExistence(timeout: wait))
        XCTAssertFalse(playerRow(nickname, in: relaunched).exists)
    }

    /// Everyone has a character on their tile. A player picks their own from their own screen, it
    /// survives a relaunch, and nobody else can take it while it's theirs.
    func testAPlayerPicksTheirOwnCharacter() {
        let app = launch(["-resetData", "-demoFamily"])
        func mine(_ name: String, in app: XCUIApplication) -> XCUIElement {
            app.buttons.matching(NSPredicate(format: "identifier == 'character' AND label CONTAINS %@", name)).firstMatch
        }

        // Sam starts with one given from their username, and swaps it for the robot.
        open("sam", in: app)
        XCTAssertTrue(app.buttons["character"].waitForExistence(timeout: wait))
        XCTAssertFalse(mine("Robot", in: app).exists)
        app.buttons["character"].tap()
        let robot = app.buttons["character-robot"]
        XCTAssertTrue(robot.waitForExistence(timeout: wait))
        XCTAssertTrue(robot.isEnabled)
        screenshot("20-pick-a-character", of: app)
        robot.tap()
        XCTAssertTrue(mine("Robot", in: app).waitForExistence(timeout: wait))

        // Riley sees the robot is Sam's and can't have it.
        goBack(in: app)
        open("riley", in: app)
        XCTAssertTrue(app.buttons["character"].waitForExistence(timeout: wait))
        app.buttons["character"].tap()
        XCTAssertTrue(app.buttons["character-robot"].waitForExistence(timeout: wait))
        XCTAssertFalse(app.buttons["character-robot"].isEnabled, "the robot is sam's")
        app.buttons["Done"].tap()
        XCTAssertFalse(mine("Robot", in: app).exists)

        // Still Sam's after the app restarts.
        app.terminate()
        let relaunched = launch()
        open("sam", in: relaunched)
        XCTAssertTrue(mine("Robot", in: relaunched).waitForExistence(timeout: wait))
    }

    /// One chore, one person, per day — including when two players go for the same chores at once.
    func testAChoreCanOnlyBeOnePersonsEachDay() {
        let app = launch(["-resetData", "-demoFamily"])

        // sam builds a card but doesn't submit it yet.
        open("sam", in: app)
        app.buttons["Suggest a 25-minute card"].tap()
        app.buttons["Lock in my card"].tap()
        XCTAssertTrue(app.buttons["Check everything off first"].waitForExistence(timeout: wait))
        let onCard = uncheckedChores(in: app).count
        XCTAssertGreaterThan(onCard, 0)

        // riley is offered the same suggestion, takes it, and gets it in first.
        goBack(in: app)
        open("riley", in: app)
        app.buttons["Suggest a 25-minute card"].tap()
        app.buttons["Lock in my card"].tap()
        checkOffEverything(in: app).tap()
        XCTAssertTrue(app.staticTexts["Sent! Now it's waiting for an admin to look at it."].waitForExistence(timeout: wait))

        // Back on sam's card every chore now reads as taken, and it can't be submitted.
        goBack(in: app)
        open("sam", in: app)
        let blocked = app.buttons["Everything's been taken today. Change your picks"]
        XCTAssertTrue(blocked.waitForExistence(timeout: wait))
        XCTAssertFalse(blocked.isEnabled)
        XCTAssertEqual(uncheckedChores(in: app).count, 0, "taken chores can't be checked off")
        XCTAssertTrue(app.staticTexts["Someone else got to the ones marked taken first, so they won't be sent."].exists)
        screenshot("17-card-all-taken", of: app)

        // Picking again offers only what's left, and that card goes in.
        app.buttons["Change my picks"].tap()
        let taken = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Someone else already has'")).firstMatch
        XCTAssertTrue(taken.waitForExistence(timeout: wait))
        XCTAssertTrue(taken.label.contains(onCard == 1 ? "has one of" : "has \(onCard) of"), taken.label)
        screenshot("18-picker-with-taken", of: app)
        app.buttons["Suggest a 25-minute card"].tap()
        app.buttons["Lock in my card"].tap()
        checkOffEverything(in: app).tap()
        XCTAssertTrue(app.staticTexts["Sent! Now it's waiting for an admin to look at it."].waitForExistence(timeout: wait))
    }

    /// Takes the six pictures for the App Store listing, with `-screenshots`' made-up family. CI
    /// runs this on the simulators whose screens match the sizes App Store Connect asks for and
    /// uploads the results (see ios/AppStore/SUBMISSION.md).
    func testAppStoreScreenshots() {
        // 2. A fresh install: what the app is and what it doesn't do with your data.
        let fresh = launch(["-resetData", "-screenshots"])
        XCTAssertTrue(fresh.buttons["Set up this device"].waitForExistence(timeout: wait))
        storeScreenshot("02-private-by-design", of: fresh)
        fresh.terminate()

        // 1. The scoreboard: this week's board, who's playing, and the 30-day log.
        let app = launch(["-resetData", "-demoData", "-screenshots"])
        XCTAssertTrue(playerRow("sockninja", in: app).waitForExistence(timeout: wait))
        if isPad {
            // Half an iPad's screen would be empty with nobody picked: show a day waiting on an admin.
            open("dishwizard", in: app)
            XCTAssertTrue(app.staticTexts["Sent! Now it's waiting for an admin to look at it."].waitForExistence(timeout: wait))
        }
        storeScreenshot("01-scoreboard", of: app)

        // 3. Picking today's chores, with a suggested card.
        open("broomrider", in: app)
        let main = mainButton(in: app)
        XCTAssertTrue(main.waitForExistence(timeout: wait))
        app.buttons["Suggest a 25-minute card"].tap()
        XCTAssertEqual(main.label, "Lock in my card")
        storeScreenshot("03-pick-chores", of: app)

        // 4. The card, partly checked off.
        main.tap()
        XCTAssertTrue(app.buttons["Check everything off first"].waitForExistence(timeout: wait))
        for _ in 0..<2 {
            let next = uncheckedChores(in: app).firstMatch
            XCTAssertTrue(next.waitForExistence(timeout: wait))
            next.tap()
        }
        storeScreenshot("04-todays-card", of: app)

        // 6. The admin area, with today's chores waiting for a yes or no.
        goBack(in: app)
        unlockAdmin(in: app)
        XCTAssertTrue(app.buttons["Approve this chore"].firstMatch.waitForExistence(timeout: wait))
        storeScreenshot("06-approvals", of: app)

        // 5. A household's own chores, said in a sentence and sorted into a list.
        adminSection("chores", in: app)
        app.buttons["+ add chores"].tap()
        type("Wash the car, walk the dog for 15 minutes, feed the fish and tidy the playroom. Clean out the fridge", into: app.textViews["chore-text"])
        app.buttons["Sort into chores"].tap()
        XCTAssertTrue(app.buttons["Add 5 chores"].waitForExistence(timeout: wait))
        storeScreenshot("05-your-own-chores", of: app)
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
        XCTAssertTrue(app.staticTexts["Sent! Now it's waiting for an admin to look at it."].waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["27/30 · 90%"].exists, "the home list stays on screen")
        XCTAssertFalse(app.staticTexts["> pick a player"].exists)
        XCTAssertFalse(app.buttons["Back"].exists, "nothing to go back to beside the list")
        let listRight = playerRow("sam", in: app).frame.maxX
        let dayLeft = app.staticTexts["Sent! Now it's waiting for an admin to look at it."].frame.minX
        XCTAssertLessThan(listRight, dayLeft, "the day sits to the right of the list, not over it")
        screenshot("ipad-02-day-beside-list", of: app)

        // Picking someone else swaps the right-hand side.
        open("riley", in: app)
        XCTAssertTrue(app.staticTexts["Everything's approved. Nice work!"].waitForExistence(timeout: wait))
        XCTAssertFalse(playerRow("sam", in: app).isSelected)

        // The bonus picker needs its own way back, since there's no screen behind it.
        app.buttons["Do a bonus round"].tap()
        XCTAssertTrue(app.buttons["Pick the chores you did"].waitForExistence(timeout: wait))
        goBack(in: app)
        XCTAssertTrue(app.staticTexts["Everything's approved. Nice work!"].waitForExistence(timeout: wait))

        // The admin area opens on the right too, and closing it returns to the day.
        app.buttons["Admin"].tap()
        XCTAssertTrue(app.secureTextFields.firstMatch.waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["27/30 · 90%"].exists, "the home list stays on screen")
        XCTAssertFalse(playerRow("riley", in: app).isSelected, "no player is highlighted while the admin area is open")
        screenshot("ipad-03-admin-area", of: app)
        goBack(in: app)
        XCTAssertTrue(app.staticTexts["Everything's approved. Nice work!"].waitForExistence(timeout: wait))

        // Turned sideways it's still two panes on the same screen.
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.staticTexts["Everything's approved. Nice work!"].waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["27/30 · 90%"].exists)
        XCTAssertTrue(playerRow("riley", in: app).isSelected)
        let wide = app.windows.firstMatch.frame
        XCTAssertGreaterThan(wide.width, wide.height, "the app should have turned with the iPad")
        XCTAssertLessThan(playerRow("riley", in: app).frame.maxX,
                          app.staticTexts["Everything's approved. Nice work!"].frame.minX)
        // The whole screen, not the app's own snapshot, which comes back cropped when sideways.
        let sideways = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        sideways.name = "ipad-04-landscape"
        sideways.lifetime = .keepAlways
        add(sideways)
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: Phones

    private func phonesSection(in app: XCUIApplication) {
        unlockAdmin(in: app)
        adminSection("device", in: app)
        // Right after a join the family is still arriving and the admin area can redraw under the
        // first tap; tap Device again if the section hasn't shown.
        if !app.staticTexts["Phones"].waitForExistence(timeout: 5) { adminSection("device", in: app) }
        XCTAssertTrue(app.staticTexts["Phones"].waitForExistence(timeout: wait))
    }

    private func label(startingWith text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
    }

    /// The first "Add a phone" moves the family to the relay (here, the in-memory one) and shows a code.
    func testAddAPhoneShowsACodeAndListsThisPhone() {
        let app = launch(["-resetData", "-demoFamily"])
        phonesSection(in: app)
        XCTAssertTrue(app.buttons["Join with a code"].exists, "a phone that isn't linked can join a family")
        app.buttons["Add a phone"].tap()
        XCTAssertTrue(app.otherElements["joinQR"].waitForExistence(timeout: wait), "a QR code to scan")
        XCTAssertTrue(label(startingWith: "Expires in", in: app).exists)
        screenshot("40-add-a-phone", of: app)
        app.buttons["Done"].tap()
        XCTAssertTrue(label(startingWith: "This phone · joined", in: app).waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["Encrypted sync. Only this family's phones can read what's sent."].exists)
        XCTAssertFalse(app.buttons["Join with a code"].exists, "a phone in the relay doesn't join another family")
    }

    /// Scanning another phone's code swaps this phone's family for that one, through the relay.
    func testJoiningWithACodeLoadsTheOtherPhonesFamily() {
        let app = launch(["-resetData", "-demoFamily", "-scanResult", "seeded"])
        phonesSection(in: app)
        app.buttons["Join with a code"].tap()
        app.buttons["Scan the code"].tap()
        // The other phone's family (jules and kai) replaces the demo one (riley and sam).
        XCTAssertTrue(playerRow("jules", in: app).waitForExistence(timeout: wait))
        XCTAssertTrue(playerRow("kai", in: app).waitForExistence(timeout: wait))
        XCTAssertFalse(playerRow("riley", in: app).exists)
        screenshot("41-joined-family", of: app)
        // Its admin code came with it, and both phones are listed.
        phonesSection(in: app)
        XCTAssertTrue(label(startingWith: "This phone · joined", in: app).waitForExistence(timeout: wait))
        XCTAssertTrue(label(startingWith: "Phone · joined", in: app).exists)
    }

    func testACodeFromSomewhereElseIsRefused() {
        let app = launch(["-resetData", "-demoFamily", "-scanResult", "https://example.com"])
        phonesSection(in: app)
        app.buttons["Join with a code"].tap()
        app.buttons["Scan the code"].tap()
        XCTAssertTrue(app.staticTexts["That isn't a DOYOURWORK code."].waitForExistence(timeout: wait))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Join with a code"].waitForExistence(timeout: wait), "nothing changed")
    }

    /// Deleting the family from the server stops sync for good on this phone and keeps the family.
    func testDeletingTheFamilyFromTheServerKeepsItHere() {
        let app = launch(["-resetData", "-demoFamily"])
        phonesSection(in: app)
        app.buttons["Add a phone"].tap()
        XCTAssertTrue(app.otherElements["joinQR"].waitForExistence(timeout: wait))
        app.buttons["Done"].tap()
        app.buttons["Delete this family from the server…"].tap()
        app.buttons["Delete from the server"].tap()
        XCTAssertTrue(label(startingWith: "The family is only on this phone.", in: app).waitForExistence(timeout: wait))
        XCTAssertTrue(app.buttons["Join with a code"].exists)
        screenshot("42-deleted-from-server", of: app)
        goBack(in: app)
        XCTAssertTrue(playerRow("riley", in: app).waitForExistence(timeout: wait), "the family stays on this phone")

        // Still on its own after a restart: no sync status, nothing sent.
        app.terminate()
        let again = launch()
        XCTAssertTrue(playerRow("riley", in: again).waitForExistence(timeout: wait))
        XCTAssertTrue(again.staticTexts["Everything here stays on this device. No accounts, nothing sent anywhere."].waitForExistence(timeout: wait))
    }

    /// A new phone joins from the very first screen, before anyone sets it up.
    func testANewPhoneJoinsFromTheFirstScreen() {
        let app = launch(["-resetData", "-scanResult", "seeded"])
        let join = app.buttons["Join a family"]
        XCTAssertTrue(join.waitForExistence(timeout: wait))
        join.tap()
        XCTAssertTrue(playerRow("jules", in: app).waitForExistence(timeout: wait))
        XCTAssertTrue(playerRow("kai", in: app).exists)
        XCTAssertFalse(app.buttons["Set up this device"].exists, "the family it joined is already set up")
        unlockAdmin(in: app)
    }

    /// Another phone deletes the family: this one notices on its next pass and keeps what it has.
    func testAPhoneLeftOutOfTheFamilyIsToldAndKeepsItsData() {
        let app = launch(["-resetData", "-demoFamily", "-scanResult", "seeded", "-seededDeletes"])
        phonesSection(in: app)
        app.buttons["Join with a code"].tap()
        app.buttons["Scan the code"].tap()
        XCTAssertTrue(playerRow("jules", in: app).waitForExistence(timeout: wait))
        // Sync runs every 10 seconds.
        XCTAssertTrue(app.staticTexts["This phone is no longer in the family's sync. Everything on it stays here."].waitForExistence(timeout: 30))
        app.buttons["OK"].tap()
        XCTAssertTrue(playerRow("jules", in: app).exists, "what it had stays")
        phonesSection(in: app)
        XCTAssertTrue(label(startingWith: "The family is only on this phone.", in: app).waitForExistence(timeout: wait))
    }
}
