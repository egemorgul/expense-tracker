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

        XCTAssertTrue(app.staticTexts[euros("12.5")].firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["across 1 category"].exists)

        app.tabBars.buttons["Spending"].tap()
        XCTAssertTrue(app.staticTexts["100%"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Activity"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Overview"].tap()

        let expense = app.cells.containing(.staticText, identifier: "🍕").firstMatch
        XCTAssertTrue(scrollClearOfAddButton(expense))
        tapSwipeAction("Delete", on: expense)

        XCTAssertTrue(app.staticTexts["No expenses yet. Tap + to add one."].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["across 0 categories"].exists)
    }

    func testCommaAndDotAreBothDecimalSeparators() {
        addExpense(amount: "12.50")
        XCTAssertTrue(app.staticTexts[euros("12.5")].firstMatch.waitForExistence(timeout: 15))

        addExpense(amount: "7,25")
        XCTAssertTrue(app.staticTexts[euros("19.75")].firstMatch.waitForExistence(timeout: 15))

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
        XCTAssertTrue(categoryRow("Pets", usage: "Not used").waitForExistence(timeout: 15))
        app.buttons["Done"].tap()

        app.buttons["Add expense"].tap()
        type("5", into: app.textFields["Amount (€)"])
        app.buttons["Pets"].tap()
        app.buttons["Save"].tap()
        let expense = app.cells.containing(.staticText, identifier: "🏷️").firstMatch
        XCTAssertTrue(scrollClearOfAddButton(expense))

        app.buttons["Categories"].tap()
        let usedPets = categoryRow("Pets", usage: "1 expense")
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 15))
        XCTAssertTrue(scrollTo(usedPets))
        usedPets.swipeLeft()
        XCTAssertFalse(app.buttons["Delete"].waitForExistence(timeout: 2))
        app.buttons["Done"].tap()

        tapSwipeAction("Delete", on: expense)
        XCTAssertTrue(app.staticTexts["No expenses yet. Tap + to add one."].waitForExistence(timeout: 15))

        app.buttons["Categories"].tap()
        let unusedPets = categoryRow("Pets", usage: "Not used")
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 15))
        XCTAssertTrue(scrollTo(unusedPets))
        tapSwipeAction("Delete", on: unusedPets)
        XCTAssertTrue(unusedPets.waitForNonExistence(timeout: 15))
    }

    func testDuplicateCategoryNameIsRejected() {
        app.buttons["Categories"].tap()
        let add = app.buttons["Add category"]
        XCTAssertTrue(add.waitForExistence(timeout: 15))
        XCTAssertFalse(add.isEnabled)

        type("food", into: app.textFields["Name"])
        XCTAssertTrue(app.staticTexts["That category already exists."].waitForExistence(timeout: 15))
        XCTAssertFalse(add.isEnabled)
    }

    func testAddingAndMovingMoneyUpdatesBothBalances() {
        app.buttons["Add money"].tap()
        type("80", into: app.textFields["Amount (€)"])
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[euros("80")].waitForExistence(timeout: 15))

        app.buttons["Move money"].tap()
        type("90", into: app.textFields["Amount (€)"])
        XCTAssertTrue(app.staticTexts["That's more than this balance holds."].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["Save"].isEnabled)

        app.textFields["Amount (€)"].typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2) + "30")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[euros("50")].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts[euros("30")].exists)

        addExpense(amount: "5")
        XCTAssertTrue(app.staticTexts[euros("45")].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts[euros("30")].exists)

        app.buttons["Balance history"].tap()
        let move = app.cells.containing(.staticText, identifier: "Moved from Main to Savings").firstMatch
        XCTAssertTrue(move.waitForExistence(timeout: 15))
        tapSwipeAction("Delete", on: move)
        XCTAssertTrue(move.waitForNonExistence(timeout: 15))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts[euros("75")].waitForExistence(timeout: 15))
    }

    func testExpensePaidFromSavingsLeavesMainUntouched() {
        app.buttons["Add money"].tap()
        type("80", into: app.textFields["Amount (€)"])
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[euros("80")].waitForExistence(timeout: 15))

        app.buttons["Add money"].tap()
        type("50", into: app.textFields["Amount (€)"])
        app.buttons["Savings"].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[euros("50")].waitForExistence(timeout: 15))

        app.buttons["Add expense"].tap()
        type("20", into: app.textFields["Amount (€)"])
        app.buttons["Savings"].tap()
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts[euros("30")].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts[euros("80")].exists)
        XCTAssertTrue(app.staticTexts[euros("20")].firstMatch.exists)
    }

    func testMoneyCanMoveToCashAndPayForAnExpense() {
        app.buttons["Add money"].tap()
        type("80", into: app.textFields["Amount (€)"])
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[euros("80")].waitForExistence(timeout: 15))

        app.buttons["Move money"].tap()
        type("30", into: app.textFields["Amount (€)"])
        app.segmentedControls.element(boundBy: 1).buttons["Cash"].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[euros("50")].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts[euros("30")].exists)

        app.buttons["Add expense"].tap()
        type("10", into: app.textFields["Amount (€)"])
        app.buttons["Cash"].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[euros("20")].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts[euros("50")].exists)
    }

    func testMoneyCannotMoveToTheAccountItComesFrom() {
        app.buttons["Move money"].tap()
        XCTAssertTrue(app.segmentedControls.element(boundBy: 1).waitForExistence(timeout: 15))
        XCTAssertFalse(app.segmentedControls.element(boundBy: 1).buttons["Main"].exists)

        app.segmentedControls.element(boundBy: 0).buttons["Savings"].tap()
        XCTAssertTrue(app.segmentedControls.element(boundBy: 1).buttons["Main"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.segmentedControls.element(boundBy: 1).buttons["Savings"].exists)
    }

    func testPeriodStepsBetweenMonthsOnActivityAndSpending() {
        addExpense(amount: "5")
        app.tabBars.buttons["Activity"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 15))

        app.buttons["Previous month"].tap()
        XCTAssertTrue(app.staticTexts["No expenses"].waitForExistence(timeout: 15))

        app.tabBars.buttons["Spending"].tap()
        XCTAssertTrue(app.staticTexts["Nothing to show"].waitForExistence(timeout: 15))

        app.buttons["Next month"].tap()
        XCTAssertTrue(app.staticTexts["100%"].waitForExistence(timeout: 15))
    }

    func testEditingChangesAmountCategoryAndAccountAndUpdatesBalances() {
        addMoney("80", to: "Main")
        addMoney("50", to: "Savings")
        addExpense(amount: "20")
        XCTAssertTrue(app.staticTexts[euros("60")].waitForExistence(timeout: 15))

        app.tabBars.buttons["Activity"].tap()
        let foodRow = app.cells.containing(.staticText, identifier: "Food").firstMatch
        XCTAssertTrue(foodRow.waitForExistence(timeout: 15))
        tapSwipeAction("Edit", on: foodRow)

        let amount = app.textFields["Amount (€)"]
        XCTAssertTrue(amount.waitForExistence(timeout: 15))
        XCTAssertEqual(amount.value as? String, "20")
        XCTAssertTrue(app.staticTexts["\(euros("80")) available."].exists, "The expense's own amount should count as available")

        typeAtEnd(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2) + "5", into: amount)
        app.buttons["Transport"].tap()
        app.buttons["Savings"].tap()
        app.buttons["Save"].tap()

        // The form shows these same category names, so only check the rows once it has closed.
        XCTAssertTrue(app.navigationBars["Edit expense"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.cells.containing(.staticText, identifier: "Transport").firstMatch.waitForExistence(timeout: 15))
        XCTAssertFalse(foodRow.exists)

        app.tabBars.buttons["Overview"].tap()
        XCTAssertTrue(app.staticTexts[euros("80")].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts[euros("45")].exists)
    }

    func testCancellingAnEditChangesNothing() {
        addExpense(amount: "20")
        app.tabBars.buttons["Activity"].tap()
        let row = app.cells.containing(.staticText, identifier: "Food").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        tapSwipeAction("Edit", on: row)

        typeAtEnd("0", into: app.textFields["Amount (€)"])
        app.buttons["Cancel"].tap()

        XCTAssertTrue(app.staticTexts[euros("20")].firstMatch.waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts[euros("200")].exists)
    }

    func testDeleteStillWorksInActivity() {
        addExpense(amount: "20")
        app.tabBars.buttons["Activity"].tap()
        let row = app.cells.containing(.staticText, identifier: "Food").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        tapSwipeAction("Delete", on: row)
        XCTAssertTrue(app.staticTexts["No expenses"].waitForExistence(timeout: 15))
    }

    func testTransactionsShowsIncomeAndExpensesButNotTransfers() {
        addMoney("100", to: "Main")
        addExpense(amount: "30")
        app.buttons["Move money"].tap()
        type("10", into: app.textFields["Amount (€)"])
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["Move money"].waitForExistence(timeout: 15))

        app.tabBars.buttons["Transactions"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts[euros("100")].exists)
        XCTAssertTrue(app.staticTexts[euros("30")].exists)
        XCTAssertEqual(app.staticTexts.matching(identifier: signedEuros("70")).count, 2, "The month and the day should both total +70")
        XCTAssertTrue(app.cells.containing(.staticText, identifier: signedEuros("100")).firstMatch.exists)
        XCTAssertTrue(app.cells.containing(.staticText, identifier: signedEuros("-30")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts[signedEuros("10")].exists)
    }

    func testStartingBalanceKeepsTheBalanceButIsNotIncome() {
        addMoney("100", to: "Main")
        addExpense(amount: "30")

        app.tabBars.buttons["Transactions"].tap()
        let income = incomeRow
        XCTAssertTrue(income.waitForExistence(timeout: 15))
        tapSwipeAction("Edit", on: income)

        flipStartingBalance(to: "1")
        app.buttons["Save"].tap()

        XCTAssertTrue(income.waitForNonExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts.matching(identifier: signedEuros("-30")).count, 3, "The month, the day and the expense should all show -30")

        app.tabBars.buttons["Overview"].tap()
        XCTAssertTrue(app.staticTexts[euros("70")].waitForExistence(timeout: 15))

        app.buttons["Balance history"].tap()
        let entry = app.cells.containing(.staticText, identifier: "Starting balance in Main").firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 15))
        tapSwipeAction("Edit", on: entry)
        flipStartingBalance(to: "0")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.cells.containing(.staticText, identifier: "Added to Main").firstMatch.waitForExistence(timeout: 15))
    }

    func testEditingIncomeChangesTheBalance() {
        addMoney("100", to: "Main")
        app.tabBars.buttons["Transactions"].tap()
        let income = incomeRow
        XCTAssertTrue(income.waitForExistence(timeout: 15))
        tapSwipeAction("Edit", on: income)

        let amount = app.textFields["Amount (€)"]
        XCTAssertTrue(amount.waitForExistence(timeout: 15))
        XCTAssertEqual(amount.value as? String, "100")
        typeAtEnd(XCUIKeyboardKey.delete.rawValue, into: amount)
        app.buttons["Save"].tap()

        app.tabBars.buttons["Overview"].tap()
        XCTAssertTrue(app.staticTexts[euros("10")].waitForExistence(timeout: 15))
    }

    func testWidgetLinkOpensTheAddExpenseFormReadyToType() {
        openWidgetLink()

        let amount = app.textFields["Amount (€)"]
        XCTAssertTrue(amount.waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["Add expense"].exists)
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: amount)
        XCTAssertEqual(XCTWaiter.wait(for: [focused], timeout: 15), .completed)
    }

    func testWidgetLinkLeavesAnOpenFormAloneAndNothingStuck() {
        addMoney("80", to: "Main")
        app.buttons["Add money"].tap()
        XCTAssertTrue(app.navigationBars["Add money"].waitForExistence(timeout: 15))

        openWidgetLink()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.navigationBars["Add money"].waitForExistence(timeout: 10), "The form in progress should stay open")
        app.buttons["Cancel"].tap()

        XCTAssertTrue(app.staticTexts[euros("80")].waitForExistence(timeout: 10), "The app shouldn't have restarted and lost its data")
        addExpense(amount: "5")
        XCTAssertTrue(app.staticTexts[euros("75")].waitForExistence(timeout: 10), "The add button should still work")
        app.buttons["Add money"].tap()
        XCTAssertTrue(app.navigationBars["Add money"].waitForExistence(timeout: 15), "The add money button should still work")
    }

    func testWidgetLinkLeavesAnEditFormAloneAndNothingStuck() {
        addExpense(amount: "20")
        app.tabBars.buttons["Activity"].tap()
        let row = app.cells.containing(.staticText, identifier: "Food").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        tapSwipeAction("Edit", on: row)
        XCTAssertTrue(app.navigationBars["Edit expense"].waitForExistence(timeout: 15))

        openWidgetLink()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.navigationBars["Edit expense"].waitForExistence(timeout: 10), "The form in progress should stay open")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Edit expense"].waitForNonExistence(timeout: 10))

        addExpense(amount: "5")
        XCTAssertTrue(app.staticTexts[euros("25")].firstMatch.waitForExistence(timeout: 10), "The add button should still work")
    }

    /// Expense rows sit below the summary and new categories at the end of their list, so they can start off-screen.
    private func scrollTo(_ element: XCUIElement) -> Bool {
        scroll(element) { $0.maxY < app.frame.maxY - 34 }
    }

    /// A swipe that starts under the floating Add expense button doesn't reach the row.
    private func scrollClearOfAddButton(_ element: XCUIElement) -> Bool {
        scroll(element) { $0.maxY < app.buttons["Add expense"].firstMatch.frame.minY }
    }

    /// Checks position, because asking whether a moving element is hittable fails the test outright.
    private func scroll(_ element: XCUIElement, until isClear: (CGRect) -> Bool) -> Bool {
        for _ in 0..<5 {
            if element.exists, !element.frame.isEmpty, element.frame.minY > 0, isClear(element.frame) { return true }
            app.swipeUp()
            sleep(1)
        }
        return element.exists && !element.frame.isEmpty && isClear(element.frame)
    }

    /// A swipe can fall short of revealing the row's button on a busy simulator.
    private func tapSwipeAction(_ title: String, on row: XCUIElement) {
        let button = app.buttons[title].firstMatch
        for _ in 0..<3 {
            if title == "Edit" { row.swipeRight() } else { row.swipeLeft() }
            if button.waitForExistence(timeout: 3) { break }
        }
        button.tap()
    }

    /// Matches on usage too, because the expense list behind the sheet can show the same name.
    private func categoryRow(_ name: String, usage: String) -> XCUIElement {
        app.cells
            .containing(.staticText, identifier: name)
            .containing(.staticText, identifier: usage)
            .firstMatch
    }

    /// Goes through the system like a widget tap. `app.open` would restart the app and lose its data.
    private func openWidgetLink() {
        XCUIDevice.shared.system.open(URL(string: "expensetracker://add-expense")!)
        let confirm = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Open"]
        if confirm.waitForExistence(timeout: 2) { confirm.tap() }
    }

    /// The summary at the top of the Transactions tab also says "Income", and comes first.
    private var incomeRow: XCUIElement {
        app.cells.containing(.staticText, identifier: "Income").element(boundBy: 1)
    }

    private func flipStartingBalance(to value: String) {
        let toggle = app.switches["Starting balance"]
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

    private func addMoney(_ amount: String, to account: String) {
        app.buttons["Add money"].tap()
        type(amount, into: app.textFields["Amount (€)"])
        app.buttons[account].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["Add money"].waitForExistence(timeout: 15))
    }

    private func addExpense(amount: String) {
        app.buttons["Add expense"].tap()
        type(amount, into: app.textFields["Amount (€)"])
        app.buttons["Save"].tap()
    }

    /// The form focuses its amount field with the cursor at the end, and tapping could move it.
    private func typeAtEnd(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
        XCTAssertEqual(XCTWaiter.wait(for: [focused], timeout: 15), .completed)
        field.typeText(text)
    }

    /// The sheet is still animating right after it opens, so a single tap can miss. The first sheet
    /// after launch also has to load the keyboard, which is slow on a busy simulator.
    private func type(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 15))
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

    private func signedEuros(_ amount: String) -> String {
        Decimal(string: amount)!.formatted(.currency(code: "EUR").sign(strategy: .always(showZero: false)))
    }
}
