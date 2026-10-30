import SwiftData
import SwiftUI

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    let balances: Balances

    @State private var amountText = ""
    @State private var account = BalanceAccount.main
    @State private var categoryName = ""
    @State private var note = ""
    @State private var date = Date.now

    private var amount: Decimal? {
        Decimal(amountInput: amountText).flatMap { $0 > 0 ? $0 : nil }
    }

    private var exceedsBalance: Bool {
        guard let amount else { return false }
        return amount > balances[account]
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
                        Text("\(balances[account].euros) available.")
                    }
                }

                Section {
                    TextField("Note (optional)", text: $note)

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add expense")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                categoryName = categories.first?.name ?? ""
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
        modelContext.insert(Expense(amount: amount, categoryName: categoryName, note: note, date: date, account: account))
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
                isSelected ? category.color.opacity(0.2) : Color(.tertiarySystemFill),
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
