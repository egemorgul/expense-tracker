import XCTest
@testable import ExpenseTracker

final class CategoryIconTests: XCTestCase {
    func testEmojiSavedBeforeSymbolsShowAsTheirClosestSymbol() {
        XCTAssertEqual(ExpenseCategory(name: "Food", icon: "🍕", color: .orange, sortOrder: 0).symbolName, "fork.knife")
        XCTAssertEqual(ExpenseCategory(name: "Pets", icon: "🐶", color: .teal, sortOrder: 0).symbolName, "pawprint")
    }

    func testUnknownEmojiFallsBackToATag() {
        XCTAssertEqual(ExpenseCategory(name: "Fun", icon: "🦄", color: .pink, sortOrder: 0).symbolName, ExpenseCategory.defaultIcon)
    }

    func testSymbolNamesAreKept() {
        XCTAssertEqual(ExpenseCategory(name: "Car", icon: "car", color: .blue, sortOrder: 0).symbolName, "car")
    }

    func testEveryChoiceIsARealSymbol() {
        for symbol in CategorySymbol.choices + CategorySymbol.forEmoji.values {
            XCTAssertNotNil(UIImage(systemName: symbol), symbol)
        }
    }
}
