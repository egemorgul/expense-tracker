import SwiftData
import XCTest
@testable import ExpenseTracker

final class MoneyTransactionTests: XCTestCase {
    private var calendar: Calendar!
    private var context: ModelContext!

    override func setUpWithError() throws {
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Istanbul"))
        context = ModelContext(try .forApp(ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    private func date(_ month: Int, _ day: Int, _ hour: Int = 12) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour)))
    }

    private func income(_ amount: Decimal, on date: Date, isStartingBalance: Bool = false) -> BalanceEntry {
        let entry = BalanceEntry(amount: amount, source: nil, destination: .main, date: date, isStartingBalance: isStartingBalance)
        context.insert(entry)
        return entry
    }

    private func expense(_ amount: Decimal, on date: Date) -> Expense {
        let expense = Expense(amount: amount, categoryName: "Food", note: "", date: date)
        context.insert(expense)
        return expense
    }

    private func october(entries: [BalanceEntry], expenses: [Expense]) throws -> [MoneyTransaction] {
        MoneyTransaction.list(
            entries: entries,
            expenses: expenses,
            from: try date(10, 1),
            to: try date(10, 31),
            calendar: calendar
        )
    }

    func testAnOpenEditFormKeepsItsIdentityWhenTheModelIsFirstSaved() throws {
        let added = expense(20, on: try date(10, 5))
        let request = EditRequest(added)
        let idBeforeSaving = added.persistentModelID
        let requestIDBeforeSaving = request.id

        try context.save()

        XCTAssertNotEqual(added.persistentModelID, idBeforeSaving, "This change is why forms can't use the model's own id")
        XCTAssertEqual(request.id, requestIDBeforeSaving)
    }

    func testSummaryAddsUpIncomeAndExpenses() throws {
        let transactions = try october(
            entries: [income(100, on: try date(10, 5))],
            expenses: [expense(Decimal(string: "30.25")!, on: try date(10, 5)), expense(20, on: try date(10, 6))]
        )

        let summary = TransactionSummary(transactions)

        XCTAssertEqual(summary.income, 100)
        XCTAssertEqual(summary.expenses, Decimal(string: "50.25")!)
        XCTAssertEqual(summary.total, Decimal(string: "49.75")!)
    }

    func testTotalGoesNegativeWhenSpendingMoreThanIncome() throws {
        let summary = TransactionSummary(try october(
            entries: [income(10, on: try date(10, 5))],
            expenses: [expense(25, on: try date(10, 5))]
        ))

        XCTAssertEqual(summary.total, -15)
    }

    func testTransfersAndStartingBalancesAreLeftOut() throws {
        let transfer = BalanceEntry(amount: 40, source: .main, destination: .savings, date: try date(10, 5))
        context.insert(transfer)

        let transactions = try october(
            entries: [transfer, income(500, on: try date(10, 5), isStartingBalance: true), income(100, on: try date(10, 5))],
            expenses: []
        )

        XCTAssertEqual(transactions.map(\.signedAmount), [100])
    }

    func testDaysAreLatestFirstWithTheirOwnTotals() throws {
        let days = try october(
            entries: [income(100, on: try date(10, 5))],
            expenses: [expense(30, on: try date(10, 5)), expense(20, on: try date(10, 6))]
        ).groupedByDay(calendar: calendar)

        XCTAssertEqual(days.map(\.date), [
            calendar.startOfDay(for: try date(10, 6)),
            calendar.startOfDay(for: try date(10, 5)),
        ])
        XCTAssertEqual(days.map(\.total), [-20, 70])
    }

    func testPeriodIncludesAllOfItsFirstAndLastDays() throws {
        let transactions = try october(
            entries: [income(1, on: try date(9, 30, 23)), income(2, on: try date(10, 1, 0))],
            expenses: [expense(3, on: try date(10, 31, 23)), expense(4, on: try date(11, 1, 0))]
        )

        XCTAssertEqual(transactions.map(\.signedAmount).sorted(), [-3, 2])
    }
}
