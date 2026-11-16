import SwiftData
import SwiftUI

/// Every expense and every bit of income in the period, latest day first. Transfers and starting
/// balances are left out, see `MoneyTransaction.list`.
struct ActivityView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case spent = "Spent"
        case income = "Income"

        var id: Self { self }

        func includes(_ transaction: MoneyTransaction) -> Bool {
            switch self {
            case .all: true
            case .spent: transaction.signedAmount < 0
            case .income: transaction.signedAmount > 0
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @State private var filter = Filter.all

    let entries: [BalanceEntry]
    let expenses: [Expense]
    let categoriesByName: [String: ExpenseCategory]
    @Binding var period: Period
    let addExpense: () -> Void
    let editExpense: (Expense) -> Void
    let editIncome: (BalanceEntry) -> Void

    var body: some View {
        let transactions = MoneyTransaction.list(entries: entries, expenses: expenses, from: period.from, to: period.to)
        let shown = transactions.filter(filter.includes)

        NavigationStack {
            List {
                // The summary covers the whole period whatever the filter, so it doesn't jump around.
                if !transactions.isEmpty {
                    Section {
                        SummaryColumns(summary: TransactionSummary(transactions))
                    }
                    .ledgerRows()
                }

                ForEach(shown.groupedByDay()) { day in
                    Section {
                        ForEach(day.transactions) { transaction in
                            row(for: transaction)
                        }
                    } header: {
                        DayHeader(date: day.date, total: day.total.signedEuros, totalColor: day.total.signColor)
                    }
                    .ledgerRows()
                }
            }
            .ledgerPage()
            .overlay {
                if shown.isEmpty {
                    emptyState
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 8) {
                    PeriodBar(period: $period)
                    Picker("Show", selection: $filter) {
                        ForEach(Filter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 8)
                .background(Color.paper)
            }
            .addExpenseButton(action: addExpense)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch filter {
        case .all:
            ContentUnavailableView("No transactions", systemImage: "list.bullet", description: Text("No money came in or went out in this period"))
        case .spent:
            ContentUnavailableView("No expenses", systemImage: "tray", description: Text("Nothing was spent in this period"))
        case .income:
            ContentUnavailableView("No income", systemImage: "arrow.down.left", description: Text("No money came in during this period"))
        }
    }

    @ViewBuilder
    private func row(for transaction: MoneyTransaction) -> some View {
        switch transaction.kind {
        case .income(let entry):
            IncomeRow(entry: entry)
                .editDeleteSwipeActions(
                    edit: { editIncome(entry) },
                    delete: { modelContext.delete(entry) }
                )
        case .expense(let expense):
            ExpenseRow(expense: expense, category: categoriesByName[expense.categoryName], showsDate: false, showsSign: true)
                .editDeleteSwipeActions(
                    edit: { editExpense(expense) },
                    delete: { modelContext.delete(expense) }
                )
        }
    }
}

private struct SummaryColumns: View {
    let summary: TransactionSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Zero stays neutral, since only a real amount in or out is news.
            column("Money in", value: summary.income.euros, color: summary.income > 0 ? .positive : .ink)
            column("Spent", value: summary.expenses.euros, color: .ink)
            column("Net", value: summary.total.signedEuros, color: summary.total.signColor)
        }
        .padding(.vertical, 4)
    }

    private func column(_ title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.inkSecondary)
            Text(value)
                .font(.money(.subheadline, prominent: true))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

private struct IncomeRow: View {
    let entry: BalanceEntry

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(systemName: "arrow.down.left", color: .positive)
            VStack(alignment: .leading, spacing: 2) {
                Text("Income")
                if entry.destination != .main {
                    Text("to \(entry.destination.title)")
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            Spacer()
            Text(entry.amount.signedEuros)
                .font(.money(.body))
                .foregroundStyle(Color.positive)
        }
    }
}

private extension Decimal {
    var signColor: Color {
        if self > 0 { return .positive }
        if self < 0 { return .negative }
        return .ink
    }
}
