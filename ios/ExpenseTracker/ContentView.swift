import Charts
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @State private var isAddingExpense = false

    var body: some View {
        let monthly = expenses.inSameMonth(as: .now)
        let monthlyTotal = monthly.total
        let categoryTotals = monthly.categoryTotals

        NavigationStack {
            List {
                Section(Date.now.formatted(.dateTime.month(.wide).year())) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(monthlyTotal.euros)
                            .font(.largeTitle.bold())
                        Text("across \(categoryTotals.count) \(categoryTotals.count == 1 ? "category" : "categories")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if !categoryTotals.isEmpty {
                    Section("Spending by category") {
                        Chart(categoryTotals) { row in
                            SectorMark(
                                angle: .value("Amount", NSDecimalNumber(decimal: row.subtotal).doubleValue),
                                innerRadius: .ratio(0.68)
                            )
                            .foregroundStyle(row.category.color)
                        }
                        .frame(height: 200)
                        .padding(.vertical, 8)

                        ForEach(categoryTotals) { row in
                            CategoryRow(row: row, monthlyTotal: monthlyTotal)
                        }
                    }
                }

                Section("All expenses") {
                    if expenses.isEmpty {
                        Text("No expenses yet. Tap + to add one.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(expenses) { expense in
                        ExpenseRow(expense: expense)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            modelContext.delete(expenses[index])
                        }
                    }
                }
            }
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add expense", systemImage: "plus") {
                        isAddingExpense = true
                    }
                }
            }
            .sheet(isPresented: $isAddingExpense) {
                AddExpenseView()
            }
        }
    }
}

private struct CategoryRow: View {
    let row: CategoryTotal
    let monthlyTotal: Decimal

    private var percent: Int {
        guard monthlyTotal > 0 else { return 0 }
        return Int(NSDecimalNumber(decimal: row.subtotal / monthlyTotal * 100).doubleValue.rounded())
    }

    var body: some View {
        HStack {
            Circle()
                .fill(row.category.color)
                .frame(width: 10, height: 10)
            Text(row.category.rawValue)
            Spacer()
            Text(row.subtotal.euros)
                .fontWeight(.semibold)
            Text("\(percent)%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ExpenseRow: View {
    let expense: Expense

    private var meta: String {
        let date = expense.date.formatted(date: .abbreviated, time: .omitted)
        return expense.note.isEmpty ? date : "\(date) · \(expense.note)"
    }

    var body: some View {
        HStack {
            Text(expense.category.icon)
                .font(.title3)
            VStack(alignment: .leading) {
                Text(expense.category.rawValue)
                Text(meta)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(expense.amount.euros)
                .fontWeight(.semibold)
        }
    }
}
