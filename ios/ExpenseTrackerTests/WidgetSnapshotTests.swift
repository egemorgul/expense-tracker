import XCTest
@testable import ExpenseTracker

final class WidgetSnapshotTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "WidgetSnapshotTests"

    override func setUp() {
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    func testBalancesReachTheWidgetExactly() {
        let entries = [
            BalanceEntry(amount: Decimal(string: "80.10")!, source: nil, destination: .main, date: .now),
            BalanceEntry(amount: 30, source: .main, destination: .cash, date: .now),
        ]
        let spent = Expense(amount: Decimal(string: "60.30")!, categoryName: "Food", note: "", date: .now)

        WidgetSnapshot(Balances(entries: entries, expenses: [spent])).save(to: defaults)

        let loaded = WidgetSnapshot.load(from: defaults)
        XCTAssertEqual(loaded?[.main], Decimal(string: "-10.20")!)
        XCTAssertEqual(loaded?[.cash], 30)
        XCTAssertEqual(loaded?[.savings], 0)
    }

    func testNothingLoadsBeforeTheAppHasRun() {
        XCTAssertNil(WidgetSnapshot.load(from: defaults))
    }

    func testUnreadableDataLoadsAsNothing() {
        defaults.set(Data("not json".utf8), forKey: "balances")
        XCTAssertNil(WidgetSnapshot.load(from: defaults))
    }
}
