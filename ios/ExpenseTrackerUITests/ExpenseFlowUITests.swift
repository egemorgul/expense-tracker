import XCTest

final class ExpenseFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    func testAddShowsInTotalsAndDeleteRemovesIt() {
        addExpense(amount: "12.50")

        XCTAssertTrue(app.staticTexts[euros("12.5")].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["across 1 category"].exists)
        XCTAssertTrue(app.staticTexts["100%"].exists)

        app.cells.containing(.staticText, identifier: "🍕").firstMatch.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["No expenses yet. Tap + to add one."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["across 0 categories"].exists)
    }

    func testCommaAndDotAreBothDecimalSeparators() {
        addExpense(amount: "12.50")
        XCTAssertTrue(app.staticTexts[euros("12.5")].firstMatch.waitForExistence(timeout: 5))

        addExpense(amount: "7,25")
        XCTAssertTrue(app.staticTexts[euros("7.25")].firstMatch.waitForExistence(timeout: 5))

        XCTAssertTrue(app.staticTexts[euros("19.75")].firstMatch.exists)
    }

    func testSaveIsDisabledForMissingOrAmbiguousAmounts() {
        app.buttons["Add expense"].tap()
        let save = app.buttons["Save"]
        XCTAssertFalse(save.isEnabled)

        type("1.250", into: app.textFields["Amount (€)"])
        XCTAssertFalse(save.isEnabled)

        app.textFields["Amount (€)"].typeText(XCUIKeyboardKey.delete.rawValue)
        XCTAssertTrue(save.isEnabled)
    }

    private func addExpense(amount: String) {
        app.buttons["Add expense"].tap()
        type(amount, into: app.textFields["Amount (€)"])
        app.buttons["Save"].tap()
    }

    /// The sheet is still animating right after it opens, so a single tap can miss.
    private func type(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let focused = NSPredicate(format: "hasKeyboardFocus == true")
        for _ in 0..<5 {
            field.tap()
            let expectation = XCTNSPredicateExpectation(predicate: focused, object: field)
            if XCTWaiter.wait(for: [expectation], timeout: 2) == .completed { break }
        }
        field.typeText(text)
    }

    private func euros(_ amount: String) -> String {
        Decimal(string: amount)!.formatted(.currency(code: "EUR"))
    }
}
