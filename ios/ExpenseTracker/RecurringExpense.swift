import Foundation
import SwiftData

/// An expense that comes back every month on the same day, like rent or a subscription. What it adds
/// are ordinary expenses, so editing or deleting one leaves the others alone, and stopping it keeps
/// the ones already added.
@Model
final class RecurringExpense {
    var amount: Decimal
    var categoryName: String
    var note: String
    var accountName: String
    /// The first expense's date. Each later one is counted from it, so one starting on the 31st comes
    /// back to the 31st after a shorter month instead of drifting to the 28th.
    var startDate: Date
    /// How many expenses it has added so far, the first one included.
    var addedCount: Int

    /// Starts with nothing added. The form adds the first expense itself and counts it.
    init(amount: Decimal, categoryName: String, note: String, account: BalanceAccount, startDate: Date) {
        self.amount = amount
        self.categoryName = categoryName
        self.note = note
        self.accountName = account.rawValue
        self.startDate = startDate
        self.addedCount = 0
    }

    var account: BalanceAccount {
        BalanceAccount(rawValue: accountName) ?? .main
    }

    /// The date of its expense number `index`, counting the first as 0.
    func date(ofExpense index: Int, calendar: Calendar = .current) -> Date? {
        calendar.date(byAdding: .month, value: index, to: startDate)
    }

    /// The next expense it will add.
    func nextDate(calendar: Calendar = .current) -> Date? {
        date(ofExpense: addedCount, calendar: calendar)
    }

    /// Adds each expense whose day has begun by `date`, including any missed while the app was closed.
    func addDueExpenses(in context: ModelContext, at date: Date, calendar: Calendar = .current) {
        while let next = nextDate(calendar: calendar), calendar.startOfDay(for: next) <= date {
            let expense = Expense(amount: amount, categoryName: categoryName, note: note, date: next)
            expense.accountName = accountName
            context.insert(expense)
            addedCount += 1
        }
    }

    /// Called when the app opens and when the day changes.
    static func addDueExpenses(in context: ModelContext, at date: Date, calendar: Calendar = .current) throws {
        for recurring in try context.fetch(FetchDescriptor<RecurringExpense>()) {
            recurring.addDueExpenses(in: context, at: date, calendar: calendar)
        }
        try context.saveNow()
    }
}
