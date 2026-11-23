import SwiftData
import XCTest
@testable import ExpenseTracker

final class BackupTests: XCTestCase {
    private var context: ModelContext!

    override func setUpWithError() throws {
        context = ModelContext(try .forApp(ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    /// JSON dates keep whole seconds, so test dates have none to lose.
    private func date(_ month: Int, _ day: Int) -> Date {
        Date(timeIntervalSince1970: 1_767_225_600 + Double((month - 1) * 31 + day) * 86_400)
    }

    func testBackupHoldsEverythingTheStoreHolds() throws {
        let legacyExpense = Expense(amount: Decimal(string: "1234.56")!, categoryName: "Food", note: "Dinner", date: date(3, 2))
        legacyExpense.accountName = nil
        context.insert(legacyExpense)
        context.insert(Expense(amount: Decimal(string: "0.1")!, categoryName: "Bills", note: "", date: date(3, 1), account: .cash))
        context.insert(BalanceEntry(amount: 500, source: nil, destination: .main, date: date(1, 1), isStartingBalance: true))
        context.insert(BalanceEntry(amount: Decimal(string: "80.25")!, source: .main, destination: .savings, date: date(2, 1)))
        context.insert(Budget(plan: BudgetPlan(amount: 900, start: date(3, 1), end: nil)))

        let backup = try Backup(context: context, at: date(4, 1))

        XCTAssertEqual(backup.version, 2)
        XCTAssertEqual(backup.categories.map(\.name), ["Food", "Transport", "Shopping", "Health", "Entertainment", "Bills", "Other"])
        XCTAssertEqual(backup.expenses, [
            .init(amount: "0.1", categoryName: "Bills", note: "", date: date(3, 1), accountName: "cash"),
            .init(amount: "1234.56", categoryName: "Food", note: "Dinner", date: date(3, 2), accountName: nil),
        ])
        XCTAssertEqual(backup.balanceEntries, [
            .init(amount: "500", sourceName: nil, destinationName: "spending", date: date(1, 1), isStartingBalance: true),
            .init(amount: "80.25", sourceName: "spending", destinationName: "savings", date: date(2, 1), isStartingBalance: false),
        ])
        XCTAssertEqual(backup.budgets, [.init(amount: "900", startDate: date(3, 1), endDate: nil)])
    }

    func testBackupSurvivesTheFileUnchanged() throws {
        context.insert(Expense(amount: Decimal(string: "12.5")!, categoryName: "Food", note: "Lunch, \"spicy\"", date: date(3, 1)))
        context.insert(Budget(plan: BudgetPlan(amount: 300, start: date(3, 1), end: date(3, 20))))
        let backup = try Backup(context: context, at: date(4, 1))

        let restored = try Backup(json: try backup.json())

        XCTAssertEqual(restored, backup)
        XCTAssertEqual(Decimal(string: restored.expenses[0].amount, locale: Locale(identifier: "en_US_POSIX")), Decimal(string: "12.5"))
    }

    func testFileIsNamedForTheDayItWasMade() throws {
        let backup = try Backup(context: context, at: date(4, 1))

        XCTAssertTrue(backup.fileName.hasPrefix("Expenses backup 2026-04-"))
    }

    private func fillStore() throws {
        let food = try XCTUnwrap(try context.fetch(FetchDescriptor<ExpenseCategory>()).first { $0.name == "Food" })
        food.monthlyBudget = Decimal(string: "250.5")
        context.insert(Expense(amount: Decimal(string: "12.5")!, categoryName: "Food", note: "Lunch", date: date(3, 1), account: .cash))
        context.insert(BalanceEntry(amount: 500, source: nil, destination: .main, date: date(1, 1), isStartingBalance: true))
        context.insert(BalanceEntry(amount: 80, source: .main, destination: .savings, date: date(2, 1)))
        context.insert(Budget(plan: BudgetPlan(amount: 900, start: date(3, 1), end: nil)))
        let rent = RecurringExpense(amount: 700, categoryName: "Bills", note: "Rent", account: .main, startDate: date(1, 5))
        rent.addedCount = 2
        context.insert(rent)
        try context.save()
    }

    func testRestoreBringsBackExactlyWhatWasBackedUp() throws {
        try fillStore()
        let backup = try Backup(context: context, at: date(4, 1))
        let file = try backup.json()

        try context.fetch(FetchDescriptor<Expense>()).forEach(context.delete)
        context.insert(Expense(amount: 99, categoryName: "Other", note: "Added after the backup", date: date(3, 9)))
        try context.fetch(FetchDescriptor<RecurringExpense>()).forEach(context.delete)
        try context.save()

        try Backup(json: file).restore(into: context)

        XCTAssertEqual(try Backup(context: context, at: date(4, 1)), backup)
        XCTAssertFalse(context.hasChanges, "The restore should be saved straight away")
    }

    func testVersionOneFileRestoresWithNoBudgetsOrRecurringExpenses() throws {
        let file = Data("""
        {
          "version": 1,
          "exportedAt": "2026-03-01T10:00:00Z",
          "categories": [{"name": "Food", "icon": "fork.knife", "colorName": "orange", "sortOrder": 0}],
          "expenses": [{"amount": "12.5", "categoryName": "Food", "note": "", "date": "2026-02-27T12:00:00Z"}],
          "balanceEntries": [],
          "budgets": []
        }
        """.utf8)

        try Backup(json: file).restore(into: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<ExpenseCategory>()).map(\.name), ["Food"])
        XCTAssertEqual(try context.fetch(FetchDescriptor<ExpenseCategory>()).map(\.monthlyBudget), [nil])
        let expenses = try context.fetch(FetchDescriptor<Expense>())
        XCTAssertEqual(expenses.map(\.amount), [Decimal(string: "12.5")!])
        XCTAssertEqual(expenses.map(\.account), [.main])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RecurringExpense>()), 0)
    }

    func testFileWithAnUnreadableAmountChangesNothing() throws {
        try fillStore()
        let before = try Backup(context: context, at: date(4, 1))
        var json = try XCTUnwrap(String(data: before.json(), encoding: .utf8))
        json = json.replacingOccurrences(of: "\"12.5\"", with: "\"twelve\"")

        XCTAssertThrowsError(try Backup(json: Data(json.utf8)).restore(into: context))

        XCTAssertEqual(try Backup(context: context, at: date(4, 1)), before)
    }

    func testFileFromANewerVersionIsRefused() throws {
        let file = Data("""
        {"version": 99, "exportedAt": "2026-03-01T10:00:00Z", "categories": [], "expenses": [], "balanceEntries": [], "budgets": []}
        """.utf8)

        XCTAssertThrowsError(try Backup(json: file).restore(into: context)) { error in
            XCTAssertEqual(error as? Backup.RestoreError, .newerVersion)
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExpenseCategory>()), 7)
    }

    func testSummarySaysWhatTheBackupHolds() throws {
        try fillStore()

        let summary = try Backup(context: context, at: date(4, 1)).summary

        XCTAssertTrue(summary.contains("1 expense,"), summary)
        XCTAssertTrue(summary.contains("2 balance entries"), summary)
        XCTAssertTrue(summary.contains("7 categories"), summary)
        XCTAssertTrue(summary.contains("1 recurring expense"), summary)
        XCTAssertTrue(summary.contains("a budget"), summary)
    }

    func testReminderIsDueAWeekAfterTheLastBackupOnceThereIsData() {
        let now = date(4, 1)

        XCTAssertFalse(BackupReminder.isDue(lastBackup: nil, hasData: false, at: now))
        XCTAssertTrue(BackupReminder.isDue(lastBackup: nil, hasData: true, at: now))
        XCTAssertFalse(BackupReminder.isDue(lastBackup: now.addingTimeInterval(-6 * 86_400), hasData: true, at: now))
        XCTAssertTrue(BackupReminder.isDue(lastBackup: now.addingTimeInterval(-7 * 86_400), hasData: true, at: now))
    }

    func testLastBackupIsRemembered() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "BackupTests"))
        defaults.removePersistentDomain(forName: "BackupTests")

        XCTAssertNil(BackupReminder.lastBackup(in: defaults))
        BackupReminder.recordBackup(at: date(4, 1), in: defaults)
        XCTAssertEqual(BackupReminder.lastBackup(in: defaults), date(4, 1))
    }
}
