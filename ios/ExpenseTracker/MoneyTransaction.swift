import Foundation
import SwiftData

/// One line on the Transactions tab: income coming in or an expense going out.
struct MoneyTransaction: Identifiable {
    enum Kind {
        case income(BalanceEntry)
        case expense(Expense)
    }

    let kind: Kind
    let date: Date
    /// Positive for income and negative for an expense.
    let signedAmount: Decimal
    let id: PersistentIdentifier

    init(income entry: BalanceEntry) {
        kind = .income(entry)
        date = entry.date
        signedAmount = entry.amount
        id = entry.persistentModelID
    }

    init(expense: Expense) {
        kind = .expense(expense)
        date = expense.date
        signedAmount = -expense.amount
        id = expense.persistentModelID
    }

    /// Transfers and starting balances are left out, because neither is money earned or spent.
    /// Includes the whole of both the first and the last day, latest first.
    static func list(
        entries: [BalanceEntry],
        expenses: [Expense],
        from: Date,
        to: Date,
        calendar: Calendar = .current
    ) -> [MoneyTransaction] {
        guard let days = calendar.wholeDays(from: from, to: to) else { return [] }
        return all(entries: entries, expenses: expenses).filter { days.contains($0.date) }
    }

    /// Every transaction ever, latest first. Transfers and starting balances are left out, like `list`.
    static func all(entries: [BalanceEntry], expenses: [Expense]) -> [MoneyTransaction] {
        let income = entries.filter(\.countsAsIncome).map(MoneyTransaction.init(income:))
        let spent = expenses.map(MoneyTransaction.init(expense:))
        return (income + spent).sorted { $0.date > $1.date }
    }

    /// Matches a note, category or account, ignoring case and accents, or an amount typed with either
    /// decimal separator: "12,50" finds 12.50, and "12" finds anything with 12 in its amount.
    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        let amount = abs(signedAmount)
        if let typed = Decimal(amountInput: query), typed == amount { return true }
        if "\(amount)".contains(query.replacingOccurrences(of: ",", with: ".")) { return true }

        let words: [String] = switch kind {
        case .expense(let expense): [expense.note, expense.categoryName, expense.account.title]
        case .income(let entry): ["Income", entry.destination.title]
        }
        return words.contains { $0.localizedStandardContains(query) }
    }
}

struct TransactionDay: Identifiable {
    let date: Date
    let transactions: [MoneyTransaction]

    var id: Date { date }

    var total: Decimal {
        transactions.reduce(0) { $0 + $1.signedAmount }
    }
}

struct TransactionSummary {
    private(set) var income: Decimal = 0
    private(set) var expenses: Decimal = 0

    init(_ transactions: [MoneyTransaction]) {
        for transaction in transactions {
            if transaction.signedAmount > 0 {
                income += transaction.signedAmount
            } else {
                expenses -= transaction.signedAmount
            }
        }
    }

    var total: Decimal {
        income - expenses
    }
}

extension Array where Element == MoneyTransaction {
    /// Latest day first, keeping the order of the transactions within each day.
    func groupedByDay(calendar: Calendar = .current) -> [TransactionDay] {
        Dictionary(grouping: self) { calendar.startOfDay(for: $0.date) }
            .map { TransactionDay(date: $0.key, transactions: $0.value) }
            .sorted { $0.date > $1.date }
    }
}
