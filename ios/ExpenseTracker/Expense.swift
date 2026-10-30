import Foundation
import SwiftData
import SwiftUI

enum ExpenseCategory: String, CaseIterable, Identifiable {
    case food = "Food"
    case transport = "Transport"
    case shopping = "Shopping"
    case health = "Health"
    case entertainment = "Entertainment"
    case bills = "Bills"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .food: "🍕"
        case .transport: "🚌"
        case .shopping: "🛍️"
        case .health: "💊"
        case .entertainment: "🎬"
        case .bills: "📄"
        case .other: "📦"
        }
    }

    var color: Color {
        switch self {
        case .food: .orange
        case .transport: .blue
        case .shopping: .pink
        case .health: .green
        case .entertainment: .purple
        case .bills: .red
        case .other: .gray
        }
    }
}

@Model
final class Expense {
    var amount: Decimal
    var categoryName: String
    var note: String
    var date: Date

    init(amount: Decimal, category: ExpenseCategory, note: String, date: Date) {
        self.amount = amount
        self.categoryName = category.rawValue
        self.note = note
        self.date = date
    }

    var category: ExpenseCategory {
        ExpenseCategory(rawValue: categoryName) ?? .other
    }
}

struct CategoryTotal: Identifiable {
    let category: ExpenseCategory
    let subtotal: Decimal

    var id: String { category.id }
}

extension Array where Element == Expense {
    func inSameMonth(as date: Date, calendar: Calendar = .current) -> [Expense] {
        filter { calendar.isDate($0.date, equalTo: date, toGranularity: .month) }
    }

    var total: Decimal {
        reduce(0) { $0 + $1.amount }
    }

    /// Largest subtotal first.
    var categoryTotals: [CategoryTotal] {
        Dictionary(grouping: self, by: \.category)
            .map { CategoryTotal(category: $0.key, subtotal: $0.value.total) }
            .sorted { $0.subtotal > $1.subtotal }
    }
}

extension Decimal {
    var euros: String {
        formatted(.currency(code: "EUR"))
    }

    /// Reads a typed amount with either "." or "," as the decimal separator, whatever the device
    /// region. Anything with more than two decimals, like "1.250", is rejected as ambiguous.
    init?(amountInput: String) {
        let normalized = amountInput
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard normalized.wholeMatch(of: /\d+\.?\d{0,2}|\.\d{1,2}/) != nil else { return nil }
        self.init(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }
}
