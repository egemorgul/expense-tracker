import SwiftData
import SwiftUI

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var amountText = ""
    @State private var category = ExpenseCategory.food
    @State private var note = ""
    @State private var date = Date.now

    private var amount: Decimal? {
        Decimal(amountInput: amountText).flatMap { $0 > 0 ? $0 : nil }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Amount (€)", text: $amountText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif

                Picker("Category", selection: $category) {
                    ForEach(ExpenseCategory.allCases) { category in
                        Text("\(category.icon) \(category.rawValue)").tag(category)
                    }
                }

                TextField("Note (optional)", text: $note)

                DatePicker("Date", selection: $date, displayedComponents: .date)
            }
            .navigationTitle("Add expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(amount == nil)
                }
            }
        }
    }

    private func save() {
        guard let amount else { return }
        modelContext.insert(Expense(amount: amount, category: category, note: note, date: date))
        dismiss()
    }
}
