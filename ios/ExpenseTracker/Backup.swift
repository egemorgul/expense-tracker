import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Everything the app stores, as a JSON file the user keeps outside the app, because the phone holds
/// the only copy. Each record keeps the model's stored values as they are, so `restore` rebuilds the
/// store from it. Amounts are written as exact decimal strings, and dates to the second.
struct Backup: Codable, Equatable {
    /// 1 had no category budgets or recurring expenses, and reads as having none.
    static let currentVersion = 2

    struct CategoryRecord: Codable, Equatable {
        let name: String
        let icon: String
        let colorName: String
        let sortOrder: Int
        /// Nil when the category has no budget, and in version 1 files.
        let monthlyBudget: String?
    }

    struct ExpenseRecord: Codable, Equatable {
        let amount: String
        let categoryName: String
        let note: String
        let date: Date
        /// Nil on expenses saved before an account could be chosen, which came out of the main balance.
        let accountName: String?
    }

    struct BalanceEntryRecord: Codable, Equatable {
        let amount: String
        /// Nil on money added, and set on money moved between accounts.
        let sourceName: String?
        let destinationName: String
        let date: Date
        let isStartingBalance: Bool
    }

    struct BudgetRecord: Codable, Equatable {
        let amount: String
        let startDate: Date
        /// Nil when the budget repeats monthly.
        let endDate: Date?
    }

    struct RecurringExpenseRecord: Codable, Equatable {
        let amount: String
        let categoryName: String
        let note: String
        let accountName: String
        let startDate: Date
        let addedCount: Int
    }

    enum RestoreError: LocalizedError {
        case newerVersion
        case unreadableAmount
        case noCategories

        var errorDescription: String? {
            switch self {
            case .newerVersion: "This backup was made by a newer version of the app."
            case .unreadableAmount: "An amount in this backup can't be read, so the file may have been changed."
            case .noCategories: "This backup has no categories, so it isn't complete."
            }
        }
    }

    let version: Int
    let exportedAt: Date
    let categories: [CategoryRecord]
    let expenses: [ExpenseRecord]
    let balanceEntries: [BalanceEntryRecord]
    let budgets: [BudgetRecord]
    let recurringExpenses: [RecurringExpenseRecord]

    /// Includes changes the context hasn't saved yet.
    init(context: ModelContext, at date: Date = .now) throws {
        version = Self.currentVersion
        exportedAt = date
        categories = try context.fetch(FetchDescriptor<ExpenseCategory>(sortBy: [SortDescriptor(\.sortOrder)])).map(CategoryRecord.init)
        expenses = try context.fetch(FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.date)])).map(ExpenseRecord.init)
        balanceEntries = try context.fetch(FetchDescriptor<BalanceEntry>(sortBy: [SortDescriptor(\.date)])).map(BalanceEntryRecord.init)
        budgets = try context.fetch(FetchDescriptor<Budget>(sortBy: [SortDescriptor(\.startDate)])).map(BudgetRecord.init)
        recurringExpenses = try context.fetch(FetchDescriptor<RecurringExpense>(sortBy: [SortDescriptor(\.startDate)]))
            .map(RecurringExpenseRecord.init)
    }

    init(json: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self = try decoder.decode(Backup.self, from: json)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        categories = try container.decode([CategoryRecord].self, forKey: .categories)
        expenses = try container.decode([ExpenseRecord].self, forKey: .expenses)
        balanceEntries = try container.decode([BalanceEntryRecord].self, forKey: .balanceEntries)
        budgets = try container.decode([BudgetRecord].self, forKey: .budgets)
        recurringExpenses = try container.decodeIfPresent([RecurringExpenseRecord].self, forKey: .recurringExpenses) ?? []
    }

    func json() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    var fileName: String {
        "Expenses backup \(exportedAt.formatted(.iso8601.year().month().day()))"
    }

    /// What restoring would bring back, for the user to check first.
    var summary: String {
        func count(_ number: Int, _ one: String, _ many: String) -> String {
            "\(number) \(number == 1 ? one : many)"
        }
        var parts = [
            count(expenses.count, "expense", "expenses"),
            count(balanceEntries.count, "balance entry", "balance entries"),
            count(categories.count, "category", "categories"),
        ]
        if !recurringExpenses.isEmpty { parts.append(count(recurringExpenses.count, "recurring expense", "recurring expenses")) }
        if !budgets.isEmpty { parts.append("a budget") }
        return "Saved \(exportedAt.formatted(date: .abbreviated, time: .shortened)), with \(parts.formatted(.list(type: .and)))."
    }

    /// Replaces everything in the store with this backup. The whole file is checked before anything
    /// changes, and a failed save rolls back, so the store is either fully replaced or left as it was.
    func restore(into context: ModelContext) throws {
        guard version <= Self.currentVersion else { throw RestoreError.newerVersion }
        guard !categories.isEmpty else { throw RestoreError.noCategories }
        let newCategories = try categories.map { try $0.makeCategory() }
        let newExpenses = try expenses.map { record in
            guard let expense = record.makeExpense() else { throw RestoreError.unreadableAmount }
            return expense
        }
        let newEntries = try balanceEntries.map { record in
            guard let entry = record.makeEntry() else { throw RestoreError.unreadableAmount }
            return entry
        }
        let newBudgets = try budgets.map { try $0.makeBudget() }
        let newRecurring = try recurringExpenses.map { try $0.makeRecurringExpense() }

        do {
            try context.fetch(FetchDescriptor<ExpenseCategory>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<Expense>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<BalanceEntry>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<Budget>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<RecurringExpense>()).forEach(context.delete)

            newCategories.forEach(context.insert)
            newExpenses.forEach(context.insert)
            newEntries.forEach(context.insert)
            newBudgets.forEach(context.insert)
            newRecurring.forEach(context.insert)
            try context.saveNow()
        } catch {
            context.rollback()
            throw error
        }
    }
}

// Records also bring back a deleted expense or entry, see `UndoableDelete`.

extension Backup.CategoryRecord {
    init(_ category: ExpenseCategory) {
        self.init(
            name: category.name,
            icon: category.icon,
            colorName: category.colorName,
            sortOrder: category.sortOrder,
            monthlyBudget: category.monthlyBudget.map { "\($0)" }
        )
    }

    func makeCategory() throws -> ExpenseCategory {
        let category = ExpenseCategory(name: name, icon: icon, color: .gray, sortOrder: sortOrder)
        category.colorName = colorName
        if let monthlyBudget {
            guard let amount = Decimal(recordAmount: monthlyBudget) else { throw Backup.RestoreError.unreadableAmount }
            category.monthlyBudget = amount
        }
        return category
    }
}

extension Backup.ExpenseRecord {
    init(_ expense: Expense) {
        self.init(amount: "\(expense.amount)", categoryName: expense.categoryName, note: expense.note, date: expense.date, accountName: expense.accountName)
    }

    /// Nil when the amount can't be read, which only a file edited by hand could cause.
    func makeExpense() -> Expense? {
        guard let amount = Decimal(recordAmount: amount) else { return nil }
        let expense = Expense(amount: amount, categoryName: categoryName, note: note, date: date)
        expense.accountName = accountName
        return expense
    }
}

extension Backup.BalanceEntryRecord {
    init(_ entry: BalanceEntry) {
        self.init(
            amount: "\(entry.amount)",
            sourceName: entry.sourceName,
            destinationName: entry.destinationName,
            date: entry.date,
            isStartingBalance: entry.isStartingBalance
        )
    }

    /// Nil when the amount can't be read, which only a file edited by hand could cause.
    func makeEntry() -> BalanceEntry? {
        guard let amount = Decimal(recordAmount: amount) else { return nil }
        let entry = BalanceEntry(amount: amount, source: nil, destination: .main, date: date, isStartingBalance: isStartingBalance)
        entry.sourceName = sourceName
        entry.destinationName = destinationName
        return entry
    }
}

extension Backup.BudgetRecord {
    init(_ budget: Budget) {
        self.init(amount: "\(budget.amount)", startDate: budget.startDate, endDate: budget.endDate)
    }

    func makeBudget() throws -> Budget {
        guard let amount = Decimal(recordAmount: amount) else { throw Backup.RestoreError.unreadableAmount }
        return Budget(plan: BudgetPlan(amount: amount, start: startDate, end: endDate))
    }
}

extension Backup.RecurringExpenseRecord {
    init(_ recurring: RecurringExpense) {
        self.init(
            amount: "\(recurring.amount)",
            categoryName: recurring.categoryName,
            note: recurring.note,
            accountName: recurring.accountName,
            startDate: recurring.startDate,
            addedCount: recurring.addedCount
        )
    }

    func makeRecurringExpense() throws -> RecurringExpense {
        guard let amount = Decimal(recordAmount: amount) else { throw Backup.RestoreError.unreadableAmount }
        let recurring = RecurringExpense(amount: amount, categoryName: categoryName, note: note, account: .main, startDate: startDate)
        recurring.accountName = accountName
        recurring.addedCount = addedCount
        return recurring
    }
}

private extension Decimal {
    /// Records write amounts the way `Decimal` describes itself, which never depends on the region.
    init?(recordAmount: String) {
        self.init(string: recordAmount, locale: Locale(identifier: "en_US_POSIX"))
    }
}

/// The backup as a file for `fileExporter`, which saves it wherever the user picks in Files.
struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    let data: Data
    let fileName: String

    init(_ backup: Backup) throws {
        data = try backup.json()
        fileName = backup.fileName
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
        fileName = configuration.file.filename ?? "Expenses backup"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// When to remind the user to back up. The last backup's date is kept in the app's own settings.
enum BackupReminder {
    static let key = "lastBackupDate"
    static let interval: TimeInterval = 7 * 24 * 60 * 60

    /// Due once there's something to lose and no backup in the last week.
    static func isDue(lastBackup: Date?, hasData: Bool, at date: Date) -> Bool {
        guard hasData else { return false }
        guard let lastBackup else { return true }
        return date.timeIntervalSince(lastBackup) >= interval
    }

    static func lastBackup(in defaults: UserDefaults = .standard) -> Date? {
        let seconds = defaults.double(forKey: key)
        return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
    }

    static func recordBackup(at date: Date = .now, in defaults: UserDefaults = .standard) {
        defaults.set(date.timeIntervalSince1970, forKey: key)
    }
}
