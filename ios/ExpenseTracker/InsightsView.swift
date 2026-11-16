import SwiftUI

/// Where the money went in the period, by category. Categories are managed from here too.
struct InsightsView: View {
    @State private var isManagingCategories = false

    let expenses: [Expense]
    let categoriesByName: [String: ExpenseCategory]
    @Binding var period: Period
    let addExpense: () -> Void
    let editExpense: (Expense) -> Void

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
                                Caption("Total spent")
                                Text(total.euros)
                                    .font(.system(.largeTitle, weight: .bold).monospacedDigit())
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                            }
                            CategoryShareBar(totals: totals, categoriesByName: categoriesByName)
                        }
                        .padding(.vertical, 6)
                    }
                    .ledgerRows()

                    Section {
                        ForEach(totals) { row in
                            NavigationLink(value: row.categoryName) {
                                CategoryRow(row: row, category: categoriesByName[row.categoryName], total: total)
                            }
                        }
                    } header: {
                        Text("By category")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.ink)
                            .textCase(nil)
                    }
                    .ledgerRows()
                }
            }
            .ledgerPage()
            .overlay {
                if totals.isEmpty {
                    ContentUnavailableView(
                        "Nothing to show",
                        systemImage: "chart.pie",
                        description: Text("Add an expense in this period to see where your money goes")
                    )
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { categoryName in
                CategoryHistoryView(
                    categoryName: categoryName,
                    category: categoriesByName[categoryName],
                    expenses: expenses,
                    period: $period,
                    editExpense: editExpense
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Categories", systemImage: "tag") {
                        isManagingCategories = true
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                PeriodBar(period: $period)
            }
            .addExpenseButton(action: addExpense)
            .sheet(isPresented: $isManagingCategories) {
                CategoriesView()
                    .ledgerSheet()
            }
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
            CategoryBadge(category: category)
            VStack(spacing: 6) {
                HStack {
                    Text(row.categoryName)
                    Spacer()
                    Text(row.subtotal.euros)
                        .font(.money(.body))
                }
                HStack(spacing: 8) {
                    ProgressView(value: share)
                        .tint(category?.color ?? .gray)
                        .accessibilityHidden(true)
                    Text("\(Int((share * 100).rounded()))%")
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                        .monospacedDigit()
                        .frame(minWidth: 36, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
