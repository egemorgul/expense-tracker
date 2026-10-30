import SwiftData
import XCTest
@testable import ExpenseTracker

/// The store as shipped before categories became a model: expenses only.
private enum StoreV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Expense.self] }

    @Model
    final class Expense {
        var amount: Decimal
        var categoryName: String
        var note: String
        var date: Date

        init(amount: Decimal, categoryName: String, note: String, date: Date) {
            self.amount = amount
            self.categoryName = categoryName
            self.note = note
            self.date = date
        }
    }
}

/// The store as shipped before balances: expenses and categories.
private enum StoreV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Expense.self, ExpenseCategory.self] }

    @Model
    final class Expense {
        var amount: Decimal
        var categoryName: String
        var note: String
        var date: Date

        init(amount: Decimal, categoryName: String, note: String, date: Date) {
            self.amount = amount
            self.categoryName = categoryName
            self.note = note
            self.date = date
        }
    }

    @Model
    final class ExpenseCategory {
        var name: String
        var icon: String
        var colorName: String
        var sortOrder: Int

        init(name: String, icon: String, colorName: String, sortOrder: Int) {
            self.name = name
            self.icon = icon
            self.colorName = colorName
            self.sortOrder = sortOrder
        }
    }
}

/// The store as shipped before an expense could choose its account.
private enum StoreV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] { [Expense.self, ExpenseCategory.self, BalanceEntry.self] }

    @Model
    final class Expense {
        var amount: Decimal
        var categoryName: String
        var note: String
        var date: Date

        init(amount: Decimal, categoryName: String, note: String, date: Date) {
            self.amount = amount
            self.categoryName = categoryName
            self.note = note
            self.date = date
        }
    }

    @Model
    final class ExpenseCategory {
        var name: String
        var icon: String
        var colorName: String
        var sortOrder: Int

        init(name: String, icon: String, colorName: String, sortOrder: Int) {
            self.name = name
            self.icon = icon
            self.colorName = colorName
            self.sortOrder = sortOrder
        }
    }

    @Model
    final class BalanceEntry {
        var amount: Decimal
        var sourceName: String?
        var destinationName: String
        var date: Date

        init(amount: Decimal, sourceName: String?, destinationName: String, date: Date) {
            self.amount = amount
            self.sourceName = sourceName
            self.destinationName = destinationName
            self.date = date
        }
    }
}

final class StoreMigrationTests: XCTestCase {
    private var directory: URL!
    private var storeURL: URL { directory.appending(path: "test.store") }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testExistingStoreKeepsItsExpensesAndGainsTheDefaultCategories() throws {
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        do {
            let old = try ModelContainer(for: Schema(versionedSchema: StoreV1.self), configurations: ModelConfiguration(url: storeURL))
            let context = ModelContext(old)
            context.insert(StoreV1.Expense(amount: Decimal(string: "12.50")!, categoryName: "Food", note: "Lunch", date: date))
            context.insert(StoreV1.Expense(amount: 7, categoryName: "Other", note: "", date: date))
            try context.save()
        }

        let context = ModelContext(try .forApp(ModelConfiguration(url: storeURL)))

        let expenses = try context.fetch(FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.amount, order: .reverse)]))
        XCTAssertEqual(expenses.map(\.amount), [Decimal(string: "12.50")!, 7])
        XCTAssertEqual(expenses.map(\.categoryName), ["Food", "Other"])
        XCTAssertEqual(expenses.map(\.note), ["Lunch", ""])
        XCTAssertEqual(expenses.map(\.date), [date, date])

        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>(sortBy: [SortDescriptor(\.sortOrder)]))
        XCTAssertEqual(categories.map(\.name), ["Food", "Transport", "Shopping", "Health", "Entertainment", "Bills", "Other"])
    }

    func testStoreWithCategoriesKeepsThemAndStartsWithNoBalanceEntries() throws {
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        do {
            let old = try ModelContainer(for: Schema(versionedSchema: StoreV2.self), configurations: ModelConfiguration(url: storeURL))
            let context = ModelContext(old)
            context.insert(StoreV2.ExpenseCategory(name: "Pets", icon: "🐶", colorName: "teal", sortOrder: 0))
            context.insert(StoreV2.Expense(amount: 9, categoryName: "Pets", note: "Treats", date: date))
            try context.save()
        }

        let context = ModelContext(try .forApp(ModelConfiguration(url: storeURL)))

        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        XCTAssertEqual(categories.map(\.name), ["Pets"])
        XCTAssertEqual(categories.map(\.icon), ["🐶"])
        XCTAssertEqual(categories.map(\.colorName), ["teal"])

        let expenses = try context.fetch(FetchDescriptor<Expense>())
        XCTAssertEqual(expenses.map(\.amount), [9])
        XCTAssertEqual(expenses.map(\.categoryName), ["Pets"])
        XCTAssertEqual(expenses.map(\.note), ["Treats"])
        XCTAssertEqual(expenses.map(\.date), [date])

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<BalanceEntry>()), 0)
    }

    func testExistingExpensesAndBalanceEntriesStayOnTheMainBalance() throws {
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        do {
            let old = try ModelContainer(for: Schema(versionedSchema: StoreV3.self), configurations: ModelConfiguration(url: storeURL))
            let context = ModelContext(old)
            context.insert(StoreV3.ExpenseCategory(name: "Pets", icon: "🐶", colorName: "teal", sortOrder: 0))
            context.insert(StoreV3.Expense(amount: 9, categoryName: "Pets", note: "Treats", date: date))
            context.insert(StoreV3.BalanceEntry(amount: 80, sourceName: nil, destinationName: "spending", date: date))
            context.insert(StoreV3.BalanceEntry(amount: 30, sourceName: "spending", destinationName: "savings", date: date))
            try context.save()
        }

        let context = ModelContext(try .forApp(ModelConfiguration(url: storeURL)))

        let expenses = try context.fetch(FetchDescriptor<Expense>())
        XCTAssertEqual(expenses.map(\.amount), [9])
        XCTAssertEqual(expenses.map(\.categoryName), ["Pets"])
        XCTAssertEqual(expenses.map(\.note), ["Treats"])
        XCTAssertEqual(expenses.map(\.date), [date])
        XCTAssertEqual(expenses.map(\.account), [.main])

        XCTAssertEqual(try context.fetch(FetchDescriptor<ExpenseCategory>()).map(\.name), ["Pets"])

        let balances = Balances(entries: try context.fetch(FetchDescriptor<BalanceEntry>()), expenses: expenses)
        XCTAssertEqual(balances[.main], 41)
        XCTAssertEqual(balances[.savings], 30)
    }

    func testDeletedDefaultCategoriesStayDeletedAfterRelaunch() throws {
        do {
            let context = ModelContext(try .forApp(ModelConfiguration(url: storeURL)))
            let food = try context.fetch(FetchDescriptor<ExpenseCategory>()).first { $0.name == "Food" }
            context.delete(try XCTUnwrap(food))
            try context.save()
        }

        let context = ModelContext(try .forApp(ModelConfiguration(url: storeURL)))

        let names = try context.fetch(FetchDescriptor<ExpenseCategory>()).map(\.name)
        XCTAssertEqual(names.count, 6)
        XCTAssertFalse(names.contains("Food"))
    }
}
