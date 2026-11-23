import XCTest
@testable import ExpenseTracker

final class MonthlyTotalsTests: XCTestCase {
    private var calendar: Calendar!

    override func setUpWithError() throws {
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Istanbul"))
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)))
    }

    private func expense(_ amount: Decimal, on date: Date) -> Expense {
        Expense(amount: amount, categoryName: "Food", note: "", date: date)
    }

    func testSixMonthsEndingWithTheGivenOneOldestFirstAcrossAYear() throws {
        let totals = [Expense]().monthlyTotals(endingWith: try date(2026, 2, 10), count: 6, calendar: calendar)

        XCTAssertEqual(totals.map(\.month), [
            try date(2025, 9, 1, hour: 0), try date(2025, 10, 1, hour: 0), try date(2025, 11, 1, hour: 0),
            try date(2025, 12, 1, hour: 0), try date(2026, 1, 1, hour: 0), try date(2026, 2, 1, hour: 0),
        ])
        XCTAssertEqual(totals.map(\.total), [0, 0, 0, 0, 0, 0])
    }

    func testEachExpenseCountsInItsOwnMonthOnly() throws {
        let expenses = [
            expense(10, on: try date(2026, 1, 31, hour: 23)),
            expense(5, on: try date(2026, 2, 1, hour: 0)),
            expense(Decimal(string: "2.5")!, on: try date(2026, 2, 28)),
            expense(100, on: try date(2026, 3, 1, hour: 0)),
            expense(7, on: try date(2025, 8, 31)),
        ]

        let totals = expenses.monthlyTotals(endingWith: try date(2026, 2, 15), count: 6, calendar: calendar)

        XCTAssertEqual(totals.map(\.total), [0, 0, 0, 0, 10, Decimal(string: "7.5")!])
    }
}
