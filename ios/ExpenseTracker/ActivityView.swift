import SwiftData
import SwiftUI

struct ActivityView: View {
    @Environment(\.modelContext) private var modelContext

    let expenses: [Expense]
    let categoriesByName: [String: ExpenseCategory]
    @Binding var period: Period
    let addExpense: () -> Void
    let editExpense: (Expense) -> Void

    var body: some View {
        let days = expenses.within(from: period.from, to: period.to).groupedByDay

        NavigationStack {
            List {
                ForEach(days) { day in
                    Section {
                        ForEach(day.expenses) { expense in
                            ExpenseRow(expense: expense, category: categoriesByName[expense.categoryName], showsDate: false)
                                .editDeleteSwipeActions(
                                    edit: { editExpense(expense) },
                                    delete: { modelContext.delete(expense) }
                                )
                        }
                    } header: {
                        HStack {
                            Text(day.date.dayTitle)
                                .font(.system(.subheadline, design: .serif, weight: .semibold))
                                .textCase(nil)
                            Spacer()
                            Text(day.expenses.total.euros)
                                .font(.system(.subheadline, design: .serif, weight: .semibold))
                                .monospacedDigit()
                        }
                    }
                    .warmRows()
                }
            }
            .warmPage()
            .overlay {
                if days.isEmpty {
                    ContentUnavailableView(
                        "No expenses",
                        systemImage: "tray",
                        description: Text("Nothing was spent in this period.")
                    )
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) {
                PeriodBar(period: $period)
            }
            .addExpenseButton(action: addExpense)
        }
    }
}
