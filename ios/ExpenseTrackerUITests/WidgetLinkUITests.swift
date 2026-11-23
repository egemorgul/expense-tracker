import XCTest

/// The Add expense widget's link into the app.
final class WidgetLinkUITests: UITestCase {
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
}
