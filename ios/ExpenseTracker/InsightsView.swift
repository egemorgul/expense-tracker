import Charts
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
        // Category budgets are monthly, so a custom range shows none.
        let showsBudgets = period.isWholeMonth()

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

                    if showsBudgets {
                        Section {
                            SpendingTrend(months: expenses.monthlyTotals(endingWith: period.from, count: 6))
                        }
                        .ledgerRows()
                    }

                    Section {
                        ForEach(totals) { row in
                            NavigationLink(value: row.categoryName) {
                                let category = categoriesByName[row.categoryName]
                                CategoryRow(row: row, category: category, total: total, budget: showsBudgets ? category?.monthlyBudget : nil)
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
    /// The category's monthly budget, when the period is a month.
    let budget: Decimal?

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
                if let budget {
                    let left = budget - row.subtotal
                    Text(left < 0 ? "\((-left).euros) over the \(budget.euros) budget" : "\(left.euros) left of \(budget.euros)")
                        .font(.caption)
                        .foregroundStyle(left < 0 ? Color.negative : Color.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// Spending in the six months up to the one shown, to see how it compares. Tapping a bar shows its total.
private struct SpendingTrend: View {
    let months: [MonthTotal]
    @State private var selection: Date?

    var body: some View {
        let focused = selection.flatMap { selected in
            months.first { Calendar.current.isDate($0.month, equalTo: selected, toGranularity: .month) }
        } ?? months.last
        // Months before the first spending are left out, so starting to track doesn't drag it down.
        let tracked = months.drop { $0.total == 0 }
        let average = tracked.isEmpty ? 0 : tracked.map(\.total).reduce(0, +) / Decimal(tracked.count)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Caption("Last 6 months")
                    if let focused {
                        Text("\(focused.total.euros) in \(focused.month.formatted(.dateTime.month(.wide)))")
                            .font(.money(.subheadline, prominent: true))
                            .contentTransition(.numericText())
                    }
                }
                Spacer()
                if tracked.count > 1 {
                    Text("Average \(average.roundedDown.euros)")
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
            }

            Chart {
                // A floor for the bars, so months with nothing spent still read as zero.
                RuleMark(y: .value("Nothing spent", 0))
                    .foregroundStyle(Color.hairline)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .accessibilityHidden(true)
                ForEach(months) { item in
                    BarMark(
                        x: .value("Month", item.month, unit: .month),
                        y: .value("Spent", item.total.doubleValue),
                        width: .ratio(0.5)
                    )
                    .cornerRadius(4)
                    .foregroundStyle(item.month == focused?.month ? Color.ink : Color.chartMuted)
                    .accessibilityLabel(item.month.formatted(.dateTime.month(.wide).year()))
                    .accessibilityValue(item.total.euros)
                }
            }
            .chartXSelection(value: $selection)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .frame(height: 120)
            .animation(.default, value: focused?.month)
        }
        .padding(.vertical, 6)
    }
}
