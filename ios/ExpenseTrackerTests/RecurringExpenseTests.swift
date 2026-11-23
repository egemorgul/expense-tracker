import SwiftData
import XCTest
@testable import ExpenseTracker

final class RecurringExpenseTests: XCTestCase {
    private var calendar: Calendar!
    private var context: ModelContext!

    override func setUpWithError() throws {
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Istanbul"))
        context = ModelContext(try .forApp(ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    private func date(_ month: Int, _ day: Int, hour: Int = 9) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour)))
    }

    /// Like the form: the first expense is added straight away and counted.
    private func rent(startingOn start: Date, account: BalanceAccount = .main) -> RecurringExpense {
        let rent = RecurringExpense(amount: 900, categoryName: "Bills", note: "Rent", account: account, startDate: start)
        rent.addedCount = 1
        context.insert(rent)
        return rent
    }

    private func addedDates() throws -> [Date] {
        try context.fetch(FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.date)])).map(\.date)
    }

    func testNothingIsAddedBeforeTheNextMonthsDay() throws {
        rent(startingOn: try date(1, 15))

        try RecurringExpense.addDueExpenses(in: context, at: try date(2, 14, hour: 23), calendar: calendar)

        XCTAssertEqual(try addedDates(), [])
    }

    func testNextExpenseIsAddedAsSoonAsItsDayBegins() throws {
        let rent = rent(startingOn: try date(1, 15))

        try RecurringExpense.addDueExpenses(in: context, at: try date(2, 15, hour: 0), calendar: calendar)

        XCTAssertEqual(try addedDates(), [try date(2, 15)])
        XCTAssertEqual(rent.addedCount, 2)
        XCTAssertFalse(context.hasChanges, "What's added should be saved straight away")
    }

    func testMonthsMissedWhileTheAppWasClosedAreAllAdded() throws {
        rent(startingOn: try date(1, 15))

        try RecurringExpense.addDueExpenses(in: context, at: try date(4, 20), calendar: calendar)

        XCTAssertEqual(try addedDates(), [try date(2, 15), try date(3, 15), try date(4, 15)])
    }

    func testRunningAgainTheSameDayAddsNothingMore() throws {
        rent(startingOn: try date(1, 15))

        try RecurringExpense.addDueExpenses(in: context, at: try date(2, 15), calendar: calendar)
        try RecurringExpense.addDueExpenses(in: context, at: try date(2, 15, hour: 20), calendar: calendar)

        XCTAssertEqual(try addedDates().count, 1)
    }

    func testOneStartingOnThe31stComesBackToThe31st() throws {
        rent(startingOn: try date(1, 31))

        try RecurringExpense.addDueExpenses(in: context, at: try date(3, 31), calendar: calendar)

        XCTAssertEqual(try addedDates(), [try date(2, 28), try date(3, 31)])
    }

    func testAddedExpensesCopyTheRecurringOne() throws {
        rent(startingOn: try date(1, 15), account: .savings)

        try RecurringExpense.addDueExpenses(in: context, at: try date(2, 15), calendar: calendar)

        let expense = try XCTUnwrap(try context.fetch(FetchDescriptor<Expense>()).first)
        XCTAssertEqual(expense.amount, 900)
        XCTAssertEqual(expense.categoryName, "Bills")
        XCTAssertEqual(expense.note, "Rent")
        XCTAssertEqual(expense.account, .savings)
    }
}
