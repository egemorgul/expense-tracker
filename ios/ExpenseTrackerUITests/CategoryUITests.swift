import XCTest

/// Managing categories from Insights, including their monthly budgets.
final class CategoryUITests: UITestCase {
    func testNewCategoryCanBeUsedAndIsOnlyDeletableWhenUnused() {
        openCategories()
        type("Pets", into: app.textFields["Name"])
        app.buttons["Add category"].tap()
        XCTAssertTrue(categoryRow("Pets", usage: "Not used").waitForExistence(timeout: 15))
        app.buttons["Done"].tap()

        app.buttons["Add expense"].tap()
        type("5", into: app.textFields["Amount (€)"])
        app.buttons["Pets"].tap()
        app.buttons["Save"].tap()
        app.tabBars.buttons["Home"].tap()
        let expense = app.cells.containing(.staticText, identifier: "Pets").firstMatch
        XCTAssertTrue(scrollClearOfAddButton(expense))

        openCategories()
        let usedPets = categoryRow("Pets", usage: "1 expense")
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 15))
        XCTAssertTrue(scrollTo(usedPets))
        usedPets.swipeLeft()
        XCTAssertFalse(app.buttons["Delete"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.navigationBars["Pets"].exists, "A swipe shouldn't open the icon picker")
        app.buttons["Done"].tap()

        app.tabBars.buttons["Home"].tap()
        tapSwipeAction("Delete", on: expense)
        XCTAssertTrue(app.staticTexts["No expenses yet. Tap + to add one."].waitForExistence(timeout: 15))

        openCategories()
        let unusedPets = categoryRow("Pets", usage: "Not used")
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 15))
        XCTAssertTrue(scrollTo(unusedPets))
        tapSwipeAction("Delete", on: unusedPets)
        XCTAssertTrue(unusedPets.waitForNonExistence(timeout: 15))
    }

    func testCategoryIconCanBeChangedWithASwipe() {
        openCategories()
        let food = categoryRow("Food", usage: "Not used")
        XCTAssertTrue(food.waitForExistence(timeout: 15))
        tapSwipeAction("Edit", on: food)

        XCTAssertTrue(app.navigationBars["Food"].waitForExistence(timeout: 15))
        // The new-category picker in the sheet underneath has the same icons.
        let car = app.otherElements["Icons for Food"].buttons["car"]
        car.tap()
        XCTAssertTrue(car.isSelected)
        app.navigationBars["Food"].buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Categories"].waitForExistence(timeout: 15))
    }

    func testDuplicateCategoryNameIsRejected() {
        openCategories()
        let add = app.buttons["Add category"]
        XCTAssertTrue(add.waitForExistence(timeout: 15))
        XCTAssertFalse(add.isEnabled)

        type("food", into: app.textFields["Name"])
        XCTAssertTrue(app.staticTexts["That category already exists"].waitForExistence(timeout: 15))
        XCTAssertFalse(add.isEnabled)
    }

    func testCategoryBudgetShowsWhatIsLeftInInsights() {
        openCategories()
        let food = categoryRow("Food", usage: "Not used")
        XCTAssertTrue(food.waitForExistence(timeout: 15))
        tapSwipeAction("Edit", on: food)

        type("100", into: app.textFields["Monthly budget (€)"])
        app.navigationBars["Food"].buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["\(euros("100")) a month"].waitForExistence(timeout: 15))
        app.buttons["Done"].tap()

        addExpense(amount: "30")
        XCTAssertTrue(app.staticTexts["\(euros("70")) left of \(euros("100"))"].waitForExistence(timeout: 15))

        addExpense(amount: "90")
        XCTAssertTrue(app.staticTexts["\(euros("20")) over the \(euros("100")) budget"].waitForExistence(timeout: 15))
    }
}
