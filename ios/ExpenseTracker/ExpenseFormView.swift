import SwiftData
import SwiftUI

/// Adds a new expense, or changes an existing one when given `editing`.
struct ExpenseFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    let balances: Balances
    private let expense: Expense?

    @State private var amountText: String
    @State private var account: BalanceAccount
    @State private var categoryName: String
    @State private var note: String
    @State private var date: Date

    init(balances: Balances, editing expense: Expense? = nil) {
        self.balances = balances
        self.expense = expense
        _amountText = State(initialValue: expense.map { "\($0.amount)" } ?? "")
        _account = State(initialValue: expense?.account ?? .main)
        _categoryName = State(initialValue: expense?.categoryName ?? "")
        _note = State(initialValue: expense?.note ?? "")
        _date = State(initialValue: expense?.date ?? .now)
    }

    private var amount: Decimal? {
        Decimal(amountInput: amountText).flatMap { $0 > 0 ? $0 : nil }
    }

    /// The balance already has the edited expense taken out, so its own amount is available to it.
    private var available: Decimal {
        guard let expense, expense.account == account else { return balances[account] }
        return balances[account] + expense.amount
    }

    private var exceedsBalance: Bool {
        guard let amount else { return false }
        return amount > available
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AmountField(text: $amountText)
                }

                Section("Category") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(categories) { category in
                            CategoryChip(category: category, isSelected: category.name == categoryName) {
                                categoryName = category.name
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .warmRows()

                Section {
                    Picker("Pay from", selection: $account) {
                        ForEach(BalanceAccount.allCases) { account in
                            Text(account.title).tag(account)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Pay from")
                } footer: {
                    if exceedsBalance {
                        Text("This will take \(account.title) below zero.")
                            .foregroundStyle(Color.negative)
                    } else {
                        Text("\(available.euros) available.")
                    }
                }
                .warmRows()

                Section {
                    TextField("Note (optional)", text: $note)

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                .warmRows()
            }
            .warmPage()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(expense == nil ? "Add expense" : "Edit expense")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if categoryName.isEmpty {
                    categoryName = categories.first?.name ?? ""
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .bold()
                        .disabled(amount == nil || categoryName.isEmpty)
                }
            }
        }
    }

    private func save() {
        guard let amount else { return }
        if let expense {
            expense.amount = amount
            expense.categoryName = categoryName
            expense.note = note
            expense.date = date
            expense.accountName = account.rawValue
        } else {
            modelContext.insert(Expense(amount: amount, categoryName: categoryName, note: note, date: date, account: account))
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

private struct CategoryChip: View {
    let category: ExpenseCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(category.icon)
                    .font(.title2)
                Text(category.name)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                isSelected ? category.color.opacity(0.22) : Color.paper,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(category.color, lineWidth: 2)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(category.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
