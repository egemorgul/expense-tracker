import XCTest
@testable import ExpenseTracker

final class BalanceTests: XCTestCase {
    private func expense(_ amount: Decimal, on date: Date = .now) -> Expense {
        Expense(amount: amount, categoryName: "Food", note: "", date: date)
    }

    func testAddingMovingAndSpendingAffectTheRightBalances() {
        let entries = [
            BalanceEntry(amount: 80, source: nil, destination: .main, date: .now),
            BalanceEntry(amount: 10, source: nil, destination: .savings, date: .now),
            BalanceEntry(amount: 30, source: .main, destination: .savings, date: .now),
            BalanceEntry(amount: 5, source: .savings, destination: .main, date: .now),
        ]

        let balances = Balances(entries: entries, expenses: [expense(Decimal(string: "12.50")!)])

        XCTAssertEqual(balances[.main], Decimal(string: "42.50")!)
        XCTAssertEqual(balances[.savings], 35)
    }

    func testSpendingMoreThanTheBalanceGoesNegative() {
        let balances = Balances(entries: [], expenses: [expense(20)])

        XCTAssertEqual(balances[.main], -20)
        XCTAssertEqual(balances[.savings], 0)
    }

    func testExpenseComesOutOfItsAccount() {
        let entries = [
            BalanceEntry(amount: 80, source: nil, destination: .main, date: .now),
            BalanceEntry(amount: 50, source: nil, destination: .savings, date: .now),
        ]
        let fromSavings = Expense(amount: 20, categoryName: "Food", note: "", date: .now, account: .savings)

        let balances = Balances(entries: entries, expenses: [fromSavings, expense(5)])

        XCTAssertEqual(balances[.main], 75)
        XCTAssertEqual(balances[.savings], 30)
    }

    func testCashIsItsOwnBalance() {
        let entries = [
            BalanceEntry(amount: 80, source: nil, destination: .main, date: .now),
            BalanceEntry(amount: 30, source: .main, destination: .cash, date: .now),
        ]
        let fromCash = Expense(amount: 10, categoryName: "Food", note: "", date: .now, account: .cash)

        let balances = Balances(entries: entries, expenses: [fromCash])

        XCTAssertEqual(balances[.main], 50)
        XCTAssertEqual(balances[.cash], 20)
        XCTAssertEqual(balances[.savings], 0)
    }

    func testPeriodIncludesAllOfItsFirstAndLastDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Istanbul"))
        func date(_ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) throws -> Date {
            try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)))
        }

        let expenses = [
            expense(1, on: try date(10, 29, 23, 59)),
            expense(2, on: try date(10, 30, 0, 0)),
            expense(3, on: try date(10, 31)),
            expense(4, on: try date(11, 30, 23, 59)),
            expense(5, on: try date(12, 1, 0, 0)),
        ]

        let period = expenses.within(from: try date(10, 30, 15), to: try date(11, 30, 8), calendar: calendar)

        XCTAssertEqual(period.map(\.amount), [2, 3, 4])
    }
}
