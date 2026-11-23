import SwiftData
import XCTest
@testable import ExpenseTracker

final class UndoableDeleteTests: XCTestCase {
    private var context: ModelContext!
    private var offers: [UndoOffer] = []
    private var delete: UndoableDelete!

    override func setUpWithError() throws {
        context = ModelContext(try .forApp(ModelConfiguration(isStoredInMemoryOnly: true)))
        offers = []
        delete = UndoableDelete { [unowned self] in offers.append($0) }
    }

    func testUndoBringsBackTheSameExpense() throws {
        let expense = Expense(amount: Decimal(string: "12.34")!, categoryName: "Food", note: "Lunch", date: .now, account: .cash)
        context.insert(expense)
        try context.save()
        let before = Backup.ExpenseRecord(expense)

        delete(expense)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Expense>()), 0)
        XCTAssertFalse(context.hasChanges, "The delete should be saved straight away")
        XCTAssertEqual(offers.map(\.message), ["Expense deleted"])

        offers[0].undo()

        let restored = try context.fetch(FetchDescriptor<Expense>())
        XCTAssertEqual(restored.map(Backup.ExpenseRecord.init), [before])
        XCTAssertFalse(context.hasChanges, "The undo should be saved straight away")
    }

    func testUndoKeepsAnExpenseFromBeforeAccountsAsMain() throws {
        let expense = Expense(amount: 5, categoryName: "Food", note: "", date: .now)
        expense.accountName = nil
        context.insert(expense)

        delete(expense)
        offers[0].undo()

        XCTAssertNil(try context.fetch(FetchDescriptor<Expense>()).first?.accountName)
    }

    func testUndoBringsBackATransfer() throws {
        let transfer = BalanceEntry(amount: 40, source: .main, destination: .savings, date: .now)
        context.insert(transfer)
        let before = Backup.BalanceEntryRecord(transfer)

        delete(transfer)
        XCTAssertEqual(offers.map(\.message), ["Transfer deleted"])
        offers[0].undo()

        XCTAssertEqual(try context.fetch(FetchDescriptor<BalanceEntry>()).map(Backup.BalanceEntryRecord.init), [before])
    }

    func testMessageSaysWhatKindOfEntryWasDeleted() {
        let income = BalanceEntry(amount: 10, source: nil, destination: .main, date: .now)
        let starting = BalanceEntry(amount: 10, source: nil, destination: .main, date: .now, isStartingBalance: true)
        context.insert(income)
        context.insert(starting)

        delete(income)
        delete(starting)

        XCTAssertEqual(offers.map(\.message), ["Income deleted", "Starting balance deleted"])
    }
}
