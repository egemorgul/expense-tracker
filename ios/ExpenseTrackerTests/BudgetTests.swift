import XCTest
@testable import ExpenseTracker

final class BudgetTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func spent(_ amount: Decimal, on day: Date) -> BudgetSpending {
        BudgetSpending(date: day, amount: amount)
    }

    private func activeDay(_ plan: BudgetPlan, spending: [BudgetSpending] = [], at day: Date, file: StaticString = #filePath, line: UInt = #line) -> BudgetDay? {
        guard case .active(let budgetDay) = plan.status(spending: spending, at: day, calendar: calendar) else {
            XCTFail("Budget isn't active", file: file, line: line)
            return nil
        }
        return budgetDay
    }

    // MARK: Periods

    func testMonthlyBudgetRunsToTheSameDayNextMonthAndRepeats() {
        let plan = BudgetPlan(amount: 1000, start: date(2026, 9, 1), end: nil)

        XCTAssertEqual(
            plan.timing(at: date(2026, 9, 30, hour: 23), calendar: calendar),
            .active(DateInterval(start: date(2026, 9, 1, hour: 0), end: date(2026, 10, 1, hour: 0)))
        )
        XCTAssertEqual(
            plan.timing(at: date(2026, 10, 1, hour: 0), calendar: calendar),
            .active(DateInterval(start: date(2026, 10, 1, hour: 0), end: date(2026, 11, 1, hour: 0)))
        )
        XCTAssertEqual(
            plan.timing(at: date(2027, 1, 15), calendar: calendar),
            .active(DateInterval(start: date(2027, 1, 1, hour: 0), end: date(2027, 2, 1, hour: 0)))
        )
    }

    func testMonthlyBudgetStartingMidMonthRunsMidMonthToMidMonth() {
        let plan = BudgetPlan(amount: 1000, start: date(2026, 9, 25), end: nil)

        XCTAssertEqual(
            plan.timing(at: date(2026, 10, 3), calendar: calendar),
            .active(DateInterval(start: date(2026, 9, 25, hour: 0), end: date(2026, 10, 25, hour: 0)))
        )
    }

    func testMonthlyBudgetStartingOnThe31stComesBackToThe31st() {
        let plan = BudgetPlan(amount: 1000, start: date(2027, 1, 31), end: nil)

        XCTAssertEqual(
            plan.timing(at: date(2027, 3, 1), calendar: calendar),
            .active(DateInterval(start: date(2027, 2, 28, hour: 0), end: date(2027, 3, 31, hour: 0)))
        )
        XCTAssertEqual(
            plan.timing(at: date(2027, 3, 31), calendar: calendar),
            .active(DateInterval(start: date(2027, 3, 31, hour: 0), end: date(2027, 4, 30, hour: 0)))
        )
    }

    func testCustomBudgetIncludesItsLastDayAndThenEnds() {
        let plan = BudgetPlan(amount: 300, start: date(2026, 11, 10), end: date(2026, 11, 16))

        XCTAssertEqual(plan.timing(at: date(2026, 11, 9), calendar: calendar), .upcoming(starts: date(2026, 11, 10, hour: 0)))
        XCTAssertEqual(
            plan.timing(at: date(2026, 11, 16, hour: 23), calendar: calendar),
            .active(DateInterval(start: date(2026, 11, 10, hour: 0), end: date(2026, 11, 17, hour: 0)))
        )
        XCTAssertEqual(plan.timing(at: date(2026, 11, 17, hour: 0), calendar: calendar), .ended(lastDay: date(2026, 11, 16, hour: 0)))
    }

    func testBudgetBeforeItsFirstMonthIsUpcoming() {
        let plan = BudgetPlan(amount: 1000, start: date(2026, 12, 1), end: nil)

        XCTAssertEqual(plan.status(spending: [], at: date(2026, 11, 20), calendar: calendar), .upcoming(starts: date(2026, 12, 1, hour: 0)))
    }

    // MARK: Daily budget

    func testFirstDaySplitsTheWholeBudget() {
        let plan = BudgetPlan(amount: 1000, start: date(2026, 9, 1), end: nil)
        guard let day = activeDay(plan, spending: [spent(20, on: date(2026, 9, 1))], at: date(2026, 9, 1)) else { return }

        XCTAssertEqual(day.daysLeft, 30)
        XCTAssertEqual(day.dailyBudget, Decimal(string: "33.33")!)
        XCTAssertEqual(day.spentToday, 20)
        XCTAssertEqual(day.leftToday, Decimal(string: "13.33")!)
        XCTAssertEqual(day.left, 980)
    }

    func testNextDaySplitsWhatIsLeftOverTheRemainingDays() {
        let plan = BudgetPlan(amount: 1000, start: date(2026, 9, 1), end: nil)
        guard let day = activeDay(plan, spending: [spent(20, on: date(2026, 9, 1))], at: date(2026, 9, 2, hour: 0)) else { return }

        // 980 over 29 days is 33.793..., rounded down.
        XCTAssertEqual(day.daysLeft, 29)
        XCTAssertEqual(day.dailyBudget, Decimal(string: "33.79")!)
        XCTAssertEqual(day.leftToday, Decimal(string: "33.79")!)
    }

    func testSpendingTodayDoesNotChangeTodaysBudget() {
        let plan = BudgetPlan(amount: 300, start: date(2026, 11, 1), end: date(2026, 11, 30))
        let before = activeDay(plan, at: date(2026, 11, 11))
        let after = activeDay(plan, spending: [spent(50, on: date(2026, 11, 11))], at: date(2026, 11, 11))

        XCTAssertEqual(before?.dailyBudget, 15)
        XCTAssertEqual(after?.dailyBudget, 15)
        XCTAssertEqual(after?.leftToday, -35)
    }

    func testExpensesPlannedForLaterAreSetAside() {
        let plan = BudgetPlan(amount: 1000, start: date(2026, 9, 1), end: nil)
        let rent = spent(700, on: date(2026, 9, 20))
        guard let day = activeDay(plan, spending: [rent], at: date(2026, 9, 1)) else { return }

        XCTAssertEqual(day.dailyBudget, 10)
        XCTAssertEqual(day.left, 300)
    }

    func testOnlyThisPeriodsSpendingCounts() {
        let plan = BudgetPlan(amount: 310, start: date(2026, 9, 1), end: nil)
        let spending = [spent(500, on: date(2026, 9, 30)), spent(20, on: date(2026, 11, 1))]
        guard let day = activeDay(plan, spending: spending, at: date(2026, 10, 1)) else { return }

        XCTAssertEqual(day.spent, 0)
        XCTAssertEqual(day.dailyBudget, 10)
    }

    func testOverspentBudgetLeavesNothingForTheDay() {
        let plan = BudgetPlan(amount: 100, start: date(2026, 9, 1), end: nil)
        guard let day = activeDay(plan, spending: [spent(150, on: date(2026, 9, 3))], at: date(2026, 9, 10)) else { return }

        XCTAssertEqual(day.dailyBudget, 0)
        XCTAssertEqual(day.left, -50)
        XCTAssertEqual(day.spentFraction, 1)
    }

    func testLastDayGetsEverythingLeft() {
        let plan = BudgetPlan(amount: 100, start: date(2026, 9, 1), end: date(2026, 9, 5))
        guard let day = activeDay(plan, spending: [spent(Decimal(string: "62.50")!, on: date(2026, 9, 2))], at: date(2026, 9, 5, hour: 23)) else { return }

        XCTAssertEqual(day.daysLeft, 1)
        XCTAssertEqual(day.dailyBudget, Decimal(string: "37.50")!)
    }

    // MARK: Widget copy

    func testWidgetCopyKeepsOnlySpendingFromThisPeriodOn() {
        let plan = BudgetPlan(amount: 1000, start: date(2026, 9, 1), end: nil)
        let now = Date.now
        let expenses = [
            Expense(amount: 5, categoryName: "Food", note: "", date: now),
            Expense(amount: 7, categoryName: "Food", note: "", date: calendar.date(byAdding: .month, value: -2, to: now)!, account: .cash),
        ]

        let snapshot = BudgetSnapshot(plan: plan, expenses: expenses, at: now)

        XCTAssertEqual(snapshot.spending.map(\.amount), [5])
    }

    func testWidgetCopyRoundTrips() {
        let suite = "BudgetTests"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let snapshot = BudgetSnapshot(
            plan: BudgetPlan(amount: Decimal(string: "999.99")!, start: date(2026, 9, 1), end: date(2026, 12, 24)),
            spending: [spent(Decimal(string: "12.34")!, on: date(2026, 10, 2))]
        )

        XCTAssertNil(BudgetSnapshot.load(from: defaults))
        snapshot.save(to: defaults)

        XCTAssertEqual(BudgetSnapshot.load(from: defaults), snapshot)
    }
}
