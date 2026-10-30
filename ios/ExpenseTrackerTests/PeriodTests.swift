import XCTest
@testable import ExpenseTracker

final class PeriodTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testMonthCoversItsFirstAndLastDay() {
        let period = Period.month(containing: date(2024, 2, 15), calendar: calendar)

        XCTAssertTrue(calendar.isDate(period.from, inSameDayAs: date(2024, 2, 1)))
        XCTAssertTrue(calendar.isDate(period.to, inSameDayAs: date(2024, 2, 29)))
        XCTAssertTrue(period.isWholeMonth(calendar: calendar))
    }

    func testCustomRangeIsNotAWholeMonth() {
        let period = Period(from: date(2024, 2, 3), to: date(2024, 2, 20))

        XCTAssertFalse(period.isWholeMonth(calendar: calendar))
    }

    func testShiftingCrossesYearsAndMonthsOfDifferentLengths() {
        let january = Period.month(containing: date(2025, 1, 31), calendar: calendar)

        let december = january.shifted(byMonths: -1, calendar: calendar)
        XCTAssertTrue(calendar.isDate(december.from, inSameDayAs: date(2024, 12, 1)))
        XCTAssertTrue(calendar.isDate(december.to, inSameDayAs: date(2024, 12, 31)))

        let february = january.shifted(byMonths: 1, calendar: calendar)
        XCTAssertTrue(calendar.isDate(february.to, inSameDayAs: date(2025, 2, 28)))
    }

    func testShiftingACustomRangeLandsOnAWholeMonth() {
        let period = Period(from: date(2024, 3, 10), to: date(2024, 5, 2))

        let shifted = period.shifted(byMonths: 1, calendar: calendar)

        XCTAssertTrue(calendar.isDate(shifted.from, inSameDayAs: date(2024, 4, 1)))
        XCTAssertTrue(shifted.isWholeMonth(calendar: calendar))
    }

    func testExpensesAreGroupedByDayLatestFirst() {
        let early = Expense(amount: 1, categoryName: "Food", note: "", date: date(2024, 3, 10, hour: 8))
        let late = Expense(amount: 2, categoryName: "Food", note: "", date: date(2024, 3, 10, hour: 20))
        let next = Expense(amount: 3, categoryName: "Food", note: "", date: date(2024, 3, 11))

        let days = [next, late, early].groupedByDay(calendar: calendar)

        XCTAssertEqual(days.count, 2)
        XCTAssertEqual(days[0].expenses.total, 3)
        XCTAssertEqual(days[1].expenses.total, 3)
        XCTAssertEqual(days[1].expenses.map(\.amount), [2, 1])
    }
}
