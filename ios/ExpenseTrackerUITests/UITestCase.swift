import XCTest

/// Launches the app on an in-memory store for each test, with the steps the suites share.
/// Each suite is its own class so the suites can run in parallel on separate simulators.
class UITestCase: XCTestCase {
    var app: XCUIApplication!

    /// Tests start as just backed up, so Home's backup reminder stays out of the way. See `BackupUITests`.
    var launchArguments: [String] { ["-uiTesting"] }

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = launchArguments
        app.launch()
    }

    func openBackupMenu() {
        let menu = app.navigationBars.buttons["Backup"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15))
        menu.tap()
    }

    /// Expense rows sit below the summary and new categories at the end of their list, so they can start off-screen.
    func scrollTo(_ element: XCUIElement) -> Bool {
        scroll(element) { $0.maxY < app.frame.maxY - 34 }
    }

    /// A swipe that starts under the floating Add expense button doesn't reach the row.
    func scrollClearOfAddButton(_ element: XCUIElement) -> Bool {
        scroll(element) { $0.maxY < app.buttons["Add expense"].firstMatch.frame.minY }
    }

    /// Checks position, because asking whether a moving element is hittable fails the test outright.
    func scroll(_ element: XCUIElement, until isClear: (CGRect) -> Bool) -> Bool {
        for _ in 0..<5 {
            if element.exists, !element.frame.isEmpty, element.frame.minY > 0, isClear(element.frame) { return true }
            app.swipeUp()
            sleep(1)
        }
        return element.exists && !element.frame.isEmpty && isClear(element.frame)
    }

    /// A swipe can fall short of revealing the row's button on a busy simulator.
    func tapSwipeAction(_ title: String, on row: XCUIElement) {
        let button = app.buttons[title].firstMatch
        for _ in 0..<3 {
            if title == "Edit" { row.swipeRight() } else { row.swipeLeft() }
            if button.waitForExistence(timeout: 3) { break }
        }
        button.tap()
    }

    /// Matches on usage too, because the expense list behind the sheet can show the same name.
    func categoryRow(_ name: String, usage: String) -> XCUIElement {
        app.cells
            .containing(.staticText, identifier: name)
            .containing(.staticText, identifier: usage)
            .firstMatch
    }

    /// Goes through the system like a widget tap. `app.open` would restart the app and lose its data.
    func openWidgetLink() {
        XCUIDevice.shared.system.open(URL(string: "expensetracker://add-expense")!)
        let confirm = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Open"]
        if confirm.waitForExistence(timeout: 2) { confirm.tap() }
    }

    var incomeRow: XCUIElement {
        app.cells.containing(.staticText, identifier: "Income").firstMatch
    }

    /// Categories are managed from the Insights tab.
    func openCategories() {
        app.tabBars.buttons["Insights"].tap()
        app.buttons["Categories"].tap()
    }

    func flipSwitch(_ name: String, to value: String) {
        let toggle = app.switches[name]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        // The keyboard can cover the switch. Asking whether it's hittable while it's moving throws, so use its position.
        for _ in 0..<5 {
            let keyboard = app.keyboards.firstMatch
            let limit = keyboard.exists ? keyboard.frame.minY : app.frame.maxY
            if !toggle.frame.isEmpty, toggle.frame.maxY < limit { break }
            app.swipeUp()
            sleep(1)
        }
        // A tap can land while the form is still settling after the scroll.
        for _ in 0..<3 where toggle.value as? String != value {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            let flipped = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: toggle)
            _ = XCTWaiter.wait(for: [flipped], timeout: 3)
        }
        XCTAssertEqual(toggle.value as? String, value)
    }

    func addMoney(_ amount: String, to account: String) {
        app.buttons["Add money"].tap()
        type(amount, into: app.textFields["Amount (€)"])
        app.buttons[account].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["Add money"].waitForExistence(timeout: 15))
    }

    func addExpense(amount: String) {
        app.buttons["Add expense"].tap()
        type(amount, into: app.textFields["Amount (€)"])
        app.buttons["Save"].tap()
    }

    /// The form focuses its amount field with the cursor at the end, and tapping could move it.
    func typeAtEnd(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
        XCTAssertEqual(XCTWaiter.wait(for: [focused], timeout: 15), .completed)
        field.typeText(text)
    }

    /// The sheet is still animating right after it opens, so a single tap can miss. The first sheet
    /// after launch also has to load the keyboard, which is slow on a busy simulator.
    func type(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        for _ in 0..<5 {
            field.tap()
            let expectation = XCTNSPredicateExpectation(predicate: focused, object: field)
            if XCTWaiter.wait(for: [expectation], timeout: 2) == .completed { break }
        }
        field.typeText(text)
    }

    func euros(_ amount: String) -> String {
        Decimal(string: amount)!.formatted(.currency(code: "EUR"))
    }

    func signedEuros(_ amount: String) -> String {
        Decimal(string: amount)!.formatted(.currency(code: "EUR").sign(strategy: .always(showZero: false)))
    }
}
