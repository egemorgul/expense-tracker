import SwiftData
import SwiftUI

/// Every expense in one category over the period chosen on the Insights tab, latest day first.
struct CategoryHistoryView: View {
    @Environment(\.undoableDelete) private var delete

    let categoryName: String
    let category: ExpenseCategory?
    let expenses: [Expense]
    @Binding var period: Period
    let editExpense: (Expense) -> Void

    var body: some View {
        let categoryExpenses = expenses
            .filter { $0.categoryName == categoryName }
            .within(from: period.from, to: period.to)
        let days = categoryExpenses.groupedByDay

        List {
            if !categoryExpenses.isEmpty {
                Section {
                    HStack(spacing: 12) {
                        CategoryBadge(category: category)
                        VStack(alignment: .leading, spacing: 2) {
                            Caption("Spent on \(categoryName)")
                            Text(categoryExpenses.total.euros)
                                .font(.money(.title, prominent: true))
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(count(categoryExpenses.count))
                            .font(.caption)
                            .foregroundStyle(Color.inkSecondary)
                    }
                    .padding(.vertical, 4)
                }
                .ledgerRows()
            }

            ForEach(days) { day in
                Section {
                    ForEach(day.expenses) { expense in
                        ExpenseRow(expense: expense, category: category, showsDate: false, showsCategory: false)
                            .editDeleteSwipeActions(
                                edit: { editExpense(expense) },
                                delete: { delete(expense) }
                            )
                    }
                } header: {
                    DayHeader(date: day.date, total: day.expenses.total.euros)
                }
                .ledgerRows()
            }
        }
        .ledgerPage()
        .overlay {
            if categoryExpenses.isEmpty {
                ContentUnavailableView(
                    "No \(categoryName) expenses",
                    systemImage: category?.symbolName ?? ExpenseCategory.defaultIcon,
                    description: Text("Nothing was spent on \(categoryName) in this period")
                )
            }
        }
        .navigationTitle(categoryName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top, spacing: 0) {
            PeriodBar(period: $period)
        }
    }

    private func count(_ count: Int) -> String {
        count == 1 ? "1 expense" : "\(count) expenses"
    }
}
