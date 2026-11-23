import XCTest

/// Adding, editing and deleting expenses, and the totals and lists that show them.
final class ExpenseUITests: UITestCase {
    func testAddShowsInTotalsAndDeleteRemovesIt() {
        addExpense(amount: "12.50")

        XCTAssertTrue(app.staticTexts[euros("12.5")].firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["across 1 category"].exists)

        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.staticTexts["100%"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Activity"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Home"].tap()

        let expense = app.cells.containing(.staticText, identifier: "Food").firstMatch
        XCTAssertTrue(scrollClearOfAddButton(expense))
        tapSwipeAction("Delete", on: expense)

        XCTAssertTrue(app.staticTexts["No expenses yet. Tap + to add one."].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["across 0 categories"].exists)
    }

    func testTappingACategoryShowsItsExpenses() {
        addExpense(amount: "12.50")
        XCTAssertTrue(app.staticTexts[euros("12.5")].firstMatch.waitForExistence(timeout: 15))
        addExpense(amount: "7")
        XCTAssertTrue(app.staticTexts[euros("19.5")].firstMatch.waitForExistence(timeout: 15))

        app.tabBars.buttons["Insights"].tap()
        let food = app.cells.containing(.staticText, identifier: "Food").firstMatch
        XCTAssertTrue(food.waitForExistence(timeout: 15))
        food.tap()

        XCTAssertTrue(app.navigationBars["Food"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["2 expenses"].exists)
        XCTAssertTrue(app.staticTexts[euros("19.5")].firstMatch.exists)
        XCTAssertTrue(app.staticTexts[euros("12.5")].exists)
        XCTAssertTrue(app.staticTexts[euros("7")].exists)
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

    func testPeriodStepsBetweenMonthsOnActivityAndInsights() {
        addExpense(amount: "5")
        app.tabBars.buttons["Activity"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 15))

        app.buttons["Previous month"].tap()
        XCTAssertTrue(app.staticTexts["No transactions"].waitForExistence(timeout: 15))

        app.tabBars.buttons["Insights"].tap()
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
        XCTAssertTrue(app.staticTexts["\(euros("80")) available"].exists, "The expense's own amount should count as available")

        typeAtEnd(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2) + "5", into: amount)
        app.buttons["Transport"].tap()
        app.buttons["Savings"].tap()
        app.buttons["Save"].tap()

        // The form shows these same category names, so only check the rows once it has closed.
        XCTAssertTrue(app.navigationBars["Edit expense"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.cells.containing(.staticText, identifier: "Transport").firstMatch.waitForExistence(timeout: 15))
        XCTAssertFalse(foodRow.exists)

        app.tabBars.buttons["Home"].tap()
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
        XCTAssertTrue(app.staticTexts["No transactions"].waitForExistence(timeout: 15))
    }

    func testDeletedExpenseCanBeUndone() {
        addExpense(amount: "12.50")
        XCTAssertTrue(app.staticTexts[euros("12.5")].firstMatch.waitForExistence(timeout: 15))

        let expense = app.cells.containing(.staticText, identifier: "Food").firstMatch
        XCTAssertTrue(scrollClearOfAddButton(expense))
        tapSwipeAction("Delete", on: expense)
        XCTAssertTrue(app.staticTexts["Expense deleted"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["across 0 categories"].exists)

        app.buttons["Undo"].tap()

        XCTAssertTrue(app.staticTexts["across 1 category"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts[euros("12.5")].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Expense deleted"].waitForNonExistence(timeout: 5))
    }

    func testRepeatingExpenseIsListedUnderRecurringUntilStopped() {
        app.buttons["Add expense"].tap()
        type("700", into: app.textFields["Amount (€)"])
        app.buttons["Bills"].tap()
        flipSwitch("Repeat monthly", to: "1")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Added again on the same day each month'")).firstMatch.exists)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[euros("700")].firstMatch.waitForExistence(timeout: 15))

        app.tabBars.buttons["Activity"].tap()
        app.navigationBars.buttons["Recurring"].tap()
        // Activity's own Bills row sits behind the sheet, so find the recurring one by its next date.
        let rent = app.cells.containing(NSPredicate(format: "label BEGINSWITH 'Next on'")).firstMatch
        XCTAssertTrue(rent.waitForExistence(timeout: 15))

        tapSwipeAction("Stop", on: rent)
        XCTAssertTrue(app.staticTexts["Nothing repeats"].waitForExistence(timeout: 15))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.cells.containing(.staticText, identifier: "Bills").firstMatch.waitForExistence(timeout: 15), "The expense already added stays")
    }

    func testSearchFindsExpensesFromAnyMonth() {
        addExpense(amount: "12.50")
        XCTAssertTrue(app.staticTexts[euros("12.5")].firstMatch.waitForExistence(timeout: 15))

        app.tabBars.buttons["Activity"].tap()
        app.buttons["Previous month"].tap()
        XCTAssertTrue(app.staticTexts["No transactions"].waitForExistence(timeout: 15))

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        search.tap()
        search.typeText("12,5")

        XCTAssertTrue(app.staticTexts["Searching all time"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.cells.containing(.staticText, identifier: "Food").firstMatch.waitForExistence(timeout: 15))

        search.typeText("9")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'No Results'")).firstMatch.waitForExistence(timeout: 15))
    }

    func testInsightsShowsTheLastSixMonths() {
        addExpense(amount: "30")
        XCTAssertTrue(app.staticTexts[euros("30")].firstMatch.waitForExistence(timeout: 15))

        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.staticTexts["Last 6 months"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "\(euros("30")) in ")).firstMatch.exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Insights with the six month trend"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
