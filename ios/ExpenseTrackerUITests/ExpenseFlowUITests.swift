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

        app.tabBars.buttons["Spending"].tap()
        XCTAssertTrue(app.staticTexts["100%"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Activity"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Overview"].tap()

        let expense = app.cells.containing(.staticText, identifier: "🍕").firstMatch
        XCTAssertTrue(scrollTo(expense))
        expense.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["No expenses yet. Tap + to add one."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["across 0 categories"].exists)
    }

    func testCommaAndDotAreBothDecimalSeparators() {
        addExpense(amount: "12.50")
        XCTAssertTrue(app.staticTexts[euros("12.5")].firstMatch.waitForExistence(timeout: 5))

        addExpense(amount: "7,25")
        XCTAssertTrue(app.staticTexts[euros("19.75")].firstMatch.waitForExistence(timeout: 5))

        XCTAssertTrue(scrollTo(app.staticTexts[euros("7.25")].firstMatch))
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

    func testNewCategoryCanBeUsedAndIsOnlyDeletableWhenUnused() {
        app.buttons["Categories"].tap()
        type("Pets", into: app.textFields["Name"])
        app.buttons["Add category"].tap()
        XCTAssertTrue(categoryRow("Pets", usage: "Not used").waitForExistence(timeout: 5))
        app.buttons["Done"].tap()

        app.buttons["Add expense"].tap()
        type("5", into: app.textFields["Amount (€)"])
        app.buttons["Pets"].tap()
        app.buttons["Save"].tap()
        let expense = app.cells.containing(.staticText, identifier: "🏷️").firstMatch
        XCTAssertTrue(scrollTo(expense))

        app.buttons["Categories"].tap()
        let usedPets = categoryRow("Pets", usage: "1 expense")
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        XCTAssertTrue(scrollTo(usedPets))
        usedPets.swipeLeft()
        XCTAssertFalse(app.buttons["Delete"].waitForExistence(timeout: 2))
        app.buttons["Done"].tap()

        expense.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["No expenses yet. Tap + to add one."].waitForExistence(timeout: 5))

        app.buttons["Categories"].tap()
        let unusedPets = categoryRow("Pets", usage: "Not used")
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        XCTAssertTrue(scrollTo(unusedPets))
        unusedPets.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(unusedPets.waitForNonExistence(timeout: 5))
    }

    func testDuplicateCategoryNameIsRejected() {
        app.buttons["Categories"].tap()
        let add = app.buttons["Add category"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        XCTAssertFalse(add.isEnabled)

        type("food", into: app.textFields["Name"])
        XCTAssertFalse(add.isEnabled)
        XCTAssertTrue(app.staticTexts["That category already exists."].exists)
    }

    func testAddingAndMovingMoneyUpdatesBothBalances() {
        app.buttons["Add money"].tap()
        type("80", into: app.textFields["Amount (€)"])
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[euros("80")].waitForExistence(timeout: 5))

        app.buttons["Move money"].tap()
        type("90", into: app.textFields["Amount (€)"])
        XCTAssertFalse(app.buttons["Save"].isEnabled)
        XCTAssertTrue(app.staticTexts["That's more than this balance holds."].exists)

        app.textFields["Amount (€)"].typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2) + "30")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[euros("50")].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[euros("30")].exists)

        addExpense(amount: "5")
        XCTAssertTrue(app.staticTexts[euros("45")].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[euros("30")].exists)

        app.buttons["Balance history"].tap()
        let move = app.cells.containing(.staticText, identifier: "Moved from Main to Savings").firstMatch
        XCTAssertTrue(move.waitForExistence(timeout: 5))
        move.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(move.waitForNonExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts[euros("75")].waitForExistence(timeout: 5))
    }

    func testExpensePaidFromSavingsLeavesMainUntouched() {
        app.buttons["Add money"].tap()
        type("80", into: app.textFields["Amount (€)"])
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[euros("80")].waitForExistence(timeout: 5))

        app.buttons["Add money"].tap()
        type("50", into: app.textFields["Amount (€)"])
        app.buttons["Savings"].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[euros("50")].waitForExistence(timeout: 5))

        app.buttons["Add expense"].tap()
        type("20", into: app.textFields["Amount (€)"])
        app.buttons["Savings"].tap()
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts[euros("30")].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[euros("80")].exists)
        XCTAssertTrue(app.staticTexts[euros("20")].firstMatch.exists)
    }

    func testMoneyCanMoveToCashAndPayForAnExpense() {
        app.buttons["Add money"].tap()
        type("80", into: app.textFields["Amount (€)"])
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[euros("80")].waitForExistence(timeout: 5))

        app.buttons["Move money"].tap()
        type("30", into: app.textFields["Amount (€)"])
        app.segmentedControls.element(boundBy: 1).buttons["Cash"].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[euros("50")].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[euros("30")].exists)

        app.buttons["Add expense"].tap()
        type("10", into: app.textFields["Amount (€)"])
        app.buttons["Cash"].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[euros("20")].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[euros("50")].exists)
    }

    func testMoneyCannotMoveToTheAccountItComesFrom() {
        app.buttons["Move money"].tap()
        XCTAssertTrue(app.segmentedControls.element(boundBy: 1).waitForExistence(timeout: 5))
        XCTAssertFalse(app.segmentedControls.element(boundBy: 1).buttons["Main"].exists)

        app.segmentedControls.element(boundBy: 0).buttons["Savings"].tap()
        XCTAssertTrue(app.segmentedControls.element(boundBy: 1).buttons["Main"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.segmentedControls.element(boundBy: 1).buttons["Savings"].exists)
    }

    func testPeriodStepsBetweenMonthsOnActivityAndSpending() {
        addExpense(amount: "5")
        app.tabBars.buttons["Activity"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 5))

        app.buttons["Previous month"].tap()
        XCTAssertTrue(app.staticTexts["No expenses"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Spending"].tap()
        XCTAssertTrue(app.staticTexts["Nothing to show"].waitForExistence(timeout: 5))

        app.buttons["Next month"].tap()
        XCTAssertTrue(app.staticTexts["100%"].waitForExistence(timeout: 5))
    }

    /// Expense rows sit below the summary and new categories at the end of their list, so they can start off-screen.
    private func scrollTo(_ element: XCUIElement) -> Bool {
        for _ in 0..<5 {
            if element.exists && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

    /// Matches on usage too, because the expense list behind the sheet can show the same name.
    private func categoryRow(_ name: String, usage: String) -> XCUIElement {
        app.cells
            .containing(.staticText, identifier: name)
            .containing(.staticText, identifier: usage)
            .firstMatch
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
