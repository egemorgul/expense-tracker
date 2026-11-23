import XCTest

/// Adding and moving money between accounts, and income in Activity.
final class BalanceUITests: UITestCase {
    func testAddingAndMovingMoneyUpdatesBothBalances() {
        app.buttons["Add money"].tap()
        type("80", into: app.textFields["Amount (€)"])
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[euros("80")].waitForExistence(timeout: 15))

        app.buttons["Move money"].tap()
        type("90", into: app.textFields["Amount (€)"])
        XCTAssertTrue(app.staticTexts["That's more than this balance holds"].waitForExistence(timeout: 15))
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

    func testActivityShowsIncomeAndExpensesButNotTransfers() {
        addMoney("100", to: "Main")
        addExpense(amount: "30")
        app.buttons["Move money"].tap()
        type("10", into: app.textFields["Amount (€)"])
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["Move money"].waitForExistence(timeout: 15))

        app.tabBars.buttons["Activity"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts[euros("100")].exists)
        XCTAssertTrue(app.staticTexts[euros("30")].exists)
        XCTAssertEqual(app.staticTexts.matching(identifier: signedEuros("70")).count, 2, "The month and the day should both total +70")
        XCTAssertTrue(app.cells.containing(.staticText, identifier: signedEuros("100")).firstMatch.exists)
        XCTAssertTrue(app.cells.containing(.staticText, identifier: signedEuros("-30")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts[signedEuros("10")].exists)
    }

    func testActivityFilterShowsOnlySpentOrIncome() {
        addMoney("100", to: "Main")
        addExpense(amount: "30")
        app.tabBars.buttons["Activity"].tap()
        let expense = app.cells.containing(.staticText, identifier: "Food").firstMatch
        XCTAssertTrue(incomeRow.waitForExistence(timeout: 15))
        XCTAssertTrue(expense.exists)

        app.buttons["Spent"].tap()
        XCTAssertTrue(incomeRow.waitForNonExistence(timeout: 15))
        XCTAssertTrue(expense.exists)

        app.buttons["Income"].tap()
        XCTAssertTrue(incomeRow.waitForExistence(timeout: 15))
        XCTAssertFalse(expense.exists)
    }

    func testStartingBalanceKeepsTheBalanceButIsNotIncome() {
        addMoney("100", to: "Main")
        addExpense(amount: "30")

        app.tabBars.buttons["Activity"].tap()
        let income = incomeRow
        XCTAssertTrue(income.waitForExistence(timeout: 15))
        tapSwipeAction("Edit", on: income)

        flipSwitch("Starting balance", to: "1")
        app.buttons["Save"].tap()

        XCTAssertTrue(income.waitForNonExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts.matching(identifier: signedEuros("-30")).count, 3, "The month, the day and the expense should all show -30")

        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.staticTexts[euros("70")].waitForExistence(timeout: 15))

        app.buttons["Balance history"].tap()
        let entry = app.cells.containing(.staticText, identifier: "Starting balance in Main").firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 15))
        tapSwipeAction("Edit", on: entry)
        flipSwitch("Starting balance", to: "0")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.cells.containing(.staticText, identifier: "Added to Main").firstMatch.waitForExistence(timeout: 15))
    }

    func testEditingIncomeChangesTheBalance() {
        addMoney("100", to: "Main")
        app.tabBars.buttons["Activity"].tap()
        let income = incomeRow
        XCTAssertTrue(income.waitForExistence(timeout: 15))
        tapSwipeAction("Edit", on: income)

        let amount = app.textFields["Amount (€)"]
        XCTAssertTrue(amount.waitForExistence(timeout: 15))
        XCTAssertEqual(amount.value as? String, "100")
        typeAtEnd(XCUIKeyboardKey.delete.rawValue, into: amount)
        app.buttons["Save"].tap()

        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.staticTexts[euros("10")].waitForExistence(timeout: 15))
    }
}
