import SwiftData
import SwiftUI

struct ActivityView: View {
    @Environment(\.modelContext) private var modelContext

    let expenses: [Expense]
    let categoriesByName: [String: ExpenseCategory]
    @Binding var period: Period
    let addExpense: () -> Void

    var body: some View {
        let days = expenses.within(from: period.from, to: period.to).groupedByDay

        NavigationStack {
            List {
                ForEach(days) { day in
                    Section {
                        ForEach(day.expenses) { expense in
                            ExpenseRow(expense: expense, category: categoriesByName[expense.categoryName], showsDate: false)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                modelContext.delete(day.expenses[index])
                            }
                        }
                    } header: {
                        HStack {
                            Text(title(for: day.date))
                            Spacer()
                            Text(day.expenses.total.euros)
                                .monospacedDigit()
                        }
                    }
                }
            }
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

    private func title(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}
