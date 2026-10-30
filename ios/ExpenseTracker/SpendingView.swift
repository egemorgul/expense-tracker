import SwiftUI

struct SpendingView: View {
    let expenses: [Expense]
    let categoriesByName: [String: ExpenseCategory]
    @Binding var period: Period
    let addExpense: () -> Void

    var body: some View {
        let periodExpenses = expenses.within(from: period.from, to: period.to)
        let total = periodExpenses.total
        let totals = periodExpenses.categoryTotals

        NavigationStack {
            List {
                if !totals.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Total spent")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(total.euros)
                                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                    .monospacedDigit()
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                            }
                            CategoryShareBar(totals: totals, categoriesByName: categoriesByName)
                        }
                        .padding(.vertical, 6)
                    }

                    Section("By category") {
                        ForEach(totals) { row in
                            CategoryRow(row: row, category: categoriesByName[row.categoryName], total: total)
                        }
                    }
                }
            }
            .overlay {
                if totals.isEmpty {
                    ContentUnavailableView(
                        "Nothing to show",
                        systemImage: "chart.bar",
                        description: Text("Add an expense in this period to see where your money goes.")
                    )
                }
            }
            .navigationTitle("Spending")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) {
                PeriodBar(period: $period)
            }
            .addExpenseButton(action: addExpense)
        }
    }
}

private struct CategoryRow: View {
    let row: CategoryTotal
    let category: ExpenseCategory?
    let total: Decimal

    private var share: Double {
        guard total > 0 else { return 0 }
        return (row.subtotal / total).doubleValue
    }

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(icon: category?.icon ?? ExpenseCategory.defaultIcon, color: category?.color ?? .gray)
            VStack(spacing: 6) {
                HStack {
                    Text(row.categoryName)
                        .font(.body.weight(.medium))
                    Spacer()
                    Text(row.subtotal.euros)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                }
                HStack(spacing: 8) {
                    ProgressView(value: share)
                        .tint(category?.color ?? .gray)
                        .accessibilityHidden(true)
                    Text("\(Int((share * 100).rounded()))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(minWidth: 36, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
