import Foundation
import SwiftData
import SwiftUI

/// The raw values are stored, so a color's look can change but its name can't.
enum CategoryColor: String, CaseIterable {
    case orange, blue, pink, green, purple, red, gray, teal, yellow, indigo, brown, mint

    var color: Color {
        switch self {
        case .orange: Color(hex: 0xD9772B)
        case .blue: Color(hex: 0x3F7E8C)
        case .pink: Color(hex: 0xC8607A)
        case .green: Color(hex: 0x5E8C4A)
        case .purple: Color(hex: 0x8A5A83)
        case .red: Color(hex: 0xB8432F)
        case .gray: Color(hex: 0x8C7B6B)
        case .teal: Color(hex: 0x2F8F83)
        case .yellow: Color(hex: 0xD9A521)
        case .indigo: Color(hex: 0x5A5F9A)
        case .brown: Color(hex: 0x8A5A3A)
        case .mint: Color(hex: 0x79A88E)
        }
    }
}

/// Expenses refer to a category by name, so a category can't be renamed without updating them.
@Model
final class ExpenseCategory {
    static let defaultIcon = "🏷️"

    var name: String
    var icon: String
    var colorName: String
    var sortOrder: Int

    init(name: String, icon: String, color: CategoryColor, sortOrder: Int) {
        self.name = name
        self.icon = icon
        self.colorName = color.rawValue
        self.sortOrder = sortOrder
    }

    var color: Color {
        (CategoryColor(rawValue: colorName) ?? .gray).color
    }

    /// The category list is never empty after the first launch, because the last one can't be deleted.
    static func seedDefaultsIfNeeded(in context: ModelContext) throws {
        guard try context.fetchCount(FetchDescriptor<ExpenseCategory>()) == 0 else { return }
        let defaults: [(String, String, CategoryColor)] = [
            ("Food", "🍕", .orange),
            ("Transport", "🚌", .blue),
            ("Shopping", "🛍️", .pink),
            ("Health", "💊", .green),
            ("Entertainment", "🎬", .purple),
            ("Bills", "📄", .red),
            ("Other", "📦", .gray),
        ]
        for (index, category) in defaults.enumerated() {
            context.insert(ExpenseCategory(name: category.0, icon: category.1, color: category.2, sortOrder: index))
        }
        try context.save()
    }
}

extension Array where Element == ExpenseCategory {
    var byName: [String: ExpenseCategory] {
        Dictionary(map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func containsName(_ name: String) -> Bool {
        contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Appends to the end of the list, using a color no other category has while any are left.
    func makeCategory(name: String, icon: String) -> ExpenseCategory {
        let usedColors = Set(map(\.colorName))
        let palette = CategoryColor.allCases
        let color = palette.first { !usedColors.contains($0.rawValue) } ?? palette[count % palette.count]
        return ExpenseCategory(name: name, icon: icon, color: color, sortOrder: (map(\.sortOrder).max() ?? -1) + 1)
    }
}

@Model
final class Expense {
    var amount: Decimal
    var categoryName: String
    var note: String
    var date: Date
    /// Nil on expenses saved before an account could be chosen. They came out of the main balance.
    var accountName: String?

    init(amount: Decimal, categoryName: String, note: String, date: Date, account: BalanceAccount = .main) {
        self.amount = amount
        self.categoryName = categoryName
        self.note = note
        self.date = date
        self.accountName = account.rawValue
    }

    var account: BalanceAccount {
        accountName.flatMap(BalanceAccount.init(rawValue:)) ?? .main
    }
}

struct CategoryTotal: Identifiable {
    let categoryName: String
    let subtotal: Decimal

    var id: String { categoryName }
}

struct ExpenseDay: Identifiable {
    let date: Date
    let expenses: [Expense]

    var id: Date { date }
}

extension Array where Element == Expense {
    /// Latest day first, keeping the order of the expenses within each day.
    func groupedByDay(calendar: Calendar) -> [ExpenseDay] {
        Dictionary(grouping: self) { calendar.startOfDay(for: $0.date) }
            .map { ExpenseDay(date: $0.key, expenses: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var groupedByDay: [ExpenseDay] {
        groupedByDay(calendar: .current)
    }

    /// Includes the whole of both the first and the last day.
    func within(from: Date, to: Date, calendar: Calendar = .current) -> [Expense] {
        guard let days = calendar.wholeDays(from: from, to: to) else { return [] }
        return filter { days.contains($0.date) }
    }

    var total: Decimal {
        reduce(0) { $0 + $1.amount }
    }

    /// Largest subtotal first.
    var categoryTotals: [CategoryTotal] {
        Dictionary(grouping: self, by: \.categoryName)
            .map { CategoryTotal(categoryName: $0.key, subtotal: $0.value.total) }
            .sorted { $0.subtotal > $1.subtotal }
    }
}

extension Calendar {
    func wholeDays(from: Date, to: Date) -> Range<Date>? {
        let start = startOfDay(for: from)
        guard let end = date(byAdding: .day, value: 1, to: startOfDay(for: to)), start < end else { return nil }
        return start..<end
    }
}

extension Decimal {
    /// Always shows the sign, except on zero.
    var signedEuros: String {
        formatted(.currency(code: "EUR").sign(strategy: .always(showZero: false)))
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
