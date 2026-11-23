import XCTest

/// The budget on Home.
final class BudgetUITests: UITestCase {
    func testBudgetCanBeSetEditedAndRemoved() {
        app.buttons["Set a budget"].tap()
        type("300", into: app.textFields["Amount (€)"])
        app.buttons["Custom dates"].tap()
        XCTAssertTrue(app.staticTexts["Ends"].waitForExistence(timeout: 15))
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Left to spend today"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["\(euros("300")) of \(euros("300")) left"].exists)

        addExpense(amount: "500")
        XCTAssertTrue(app.staticTexts["\(euros("200")) over \(euros("300"))"].waitForExistence(timeout: 15))

        app.staticTexts["Left to spend today"].tap()
        XCTAssertTrue(app.navigationBars["Edit budget"].waitForExistence(timeout: 15))
        app.buttons["Remove budget"].tap()
        let confirm = app.sheets.buttons["Remove budget"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 15))
        confirm.tap()

        XCTAssertTrue(app.buttons["Set a budget"].waitForExistence(timeout: 15))
    }
}
