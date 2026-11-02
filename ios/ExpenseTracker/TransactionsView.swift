import SwiftData
import SwiftUI

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext

    let entries: [BalanceEntry]
    let expenses: [Expense]
    let categoriesByName: [String: ExpenseCategory]
    @Binding var period: Period
    let addExpense: () -> Void
    let editExpense: (Expense) -> Void
    let editIncome: (BalanceEntry) -> Void

    var body: some View {
        let transactions = MoneyTransaction.list(entries: entries, expenses: expenses, from: period.from, to: period.to)

        NavigationStack {
            List {
                if !transactions.isEmpty {
                    Section {
                        SummaryColumns(summary: TransactionSummary(transactions))
                    }
                    .warmRows()
                }

                ForEach(transactions.groupedByDay()) { day in
                    Section {
                        ForEach(day.transactions) { transaction in
                            row(for: transaction)
                        }
                    } header: {
                        HStack {
                            Text(day.date.dayTitle)
                                .font(.system(.subheadline, design: .serif, weight: .semibold))
                                .textCase(nil)
                            Spacer()
                            Text(day.total.signedEuros)
                                .font(.system(.subheadline, design: .serif, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(day.total.signColor)
                        }
                    }
                    .warmRows()
                }
            }
            .warmPage()
            .overlay {
                if transactions.isEmpty {
                    ContentUnavailableView(
                        "No transactions",
                        systemImage: "arrow.up.arrow.down",
                        description: Text("No money came in or went out in this period.")
                    )
                }
            }
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) {
                PeriodBar(period: $period)
            }
            .addExpenseButton(action: addExpense)
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
            column("Income", value: summary.income.euros, color: .positive)
            column("Expenses", value: summary.expenses.euros, color: .negative)
            column("Total", value: summary.total.signedEuros, color: summary.total.signColor)
        }
        .padding(.vertical, 4)
    }

    private func column(_ title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.subheadline, design: .serif, weight: .bold))
                .monospacedDigit()
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
            Image(systemName: "plus")
                .font(.subheadline.bold())
                .foregroundStyle(Color.positive)
                .frame(width: 40, height: 40)
                .background(Color.positive.opacity(0.15), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Income")
                    .font(.body.weight(.medium))
                if entry.destination != .main {
                    Text("to \(entry.destination.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(entry.amount.signedEuros)
                .font(.system(.body, design: .serif, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.positive)
        }
    }
}

private extension Decimal {
    var signColor: Color {
        if self > 0 { return .positive }
        if self < 0 { return .negative }
        return .primary
    }
}
