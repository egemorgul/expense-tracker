import XCTest

/// Backing up to Files and restoring, from Home's Backup menu and reminder.
final class BackupUITests: UITestCase {
    func testBackUpOffersToSaveAFile() {
        addExpense(amount: "12.50")
        XCTAssertTrue(app.staticTexts[euros("12.5")].firstMatch.waitForExistence(timeout: 15))

        openBackupMenu()
        app.buttons["Back up"].tap()

        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 15), "The save panel should open")
        let fileName = app.textFields["DOCPicker.filenameTextField"]
        XCTAssertTrue((fileName.value as? String)?.hasPrefix("Expenses backup") == true)
        // The panel shows Cancel as a plain element, not a button.
        app.descendants(matching: .any)["Cancel"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars.buttons["Backup"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts.firstMatch.exists, "Cancelling shouldn't report an error")
    }

    func testRestoreOpensTheFilePicker() {
        openBackupMenu()
        app.buttons["Restore from backup"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["Cancel"].firstMatch.waitForExistence(timeout: 15), "The file picker should open")
        app.descendants(matching: .any)["Cancel"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars.buttons["Backup"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts.firstMatch.exists, "Cancelling shouldn't report an error")
    }
}

/// Launches as if no backup has ever been made, which is when Home reminds the user.
final class BackupReminderUITests: UITestCase {
    override var launchArguments: [String] { ["-uiTesting", "-neverBackedUp"] }

    func testReminderAppearsOnceThereIsDataAndOffersToBackUp() {
        XCTAssertTrue(app.buttons["Add expense"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Back up your data"].exists, "Nothing to lose yet")

        addExpense(amount: "12.50")
        XCTAssertTrue(app.staticTexts["Back up your data"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Not backed up yet"].exists)

        app.buttons["Back up now"].tap()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 15), "The save panel should open")
        app.descendants(matching: .any)["Cancel"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Back up your data"].waitForExistence(timeout: 10), "Cancelling isn't a backup")
    }
}
