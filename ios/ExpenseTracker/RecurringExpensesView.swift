import SwiftData
import SwiftUI

/// The expenses that repeat each month. They're set up from the Add expense form, and stopped here.
struct RecurringExpensesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecurringExpense.startDate) private var recurring: [RecurringExpense]
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]
    @State private var saveError: String?

    var body: some View {
        let categoriesByName = categories.byName

        NavigationStack {
            List {
                Section {
                    ForEach(recurring) { item in
                        RecurringRow(item: item, category: categoriesByName[item.categoryName])
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Stop", systemImage: "stop.circle", role: .destructive) {
                                    stop(item)
                                }
                            }
                    }
                } footer: {
                    if !recurring.isEmpty {
                        Text("Swipe left to stop one. Expenses it already added are kept.")
                    }
                }
                .ledgerRows()
            }
            .ledgerPage()
            .overlay {
                if recurring.isEmpty {
                    ContentUnavailableView(
                        "Nothing repeats",
                        systemImage: "repeat",
                        description: Text("Turn on Repeat monthly when adding an expense, for rent or a subscription")
                    )
                }
            }
            .navigationTitle("Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .errorAlert("Couldn't save", message: $saveError)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func stop(_ item: RecurringExpense) {
        modelContext.delete(item)
        saveError = modelContext.saveNowFailure()
    }
}

private struct RecurringRow: View {
    let item: RecurringExpense
    let category: ExpenseCategory?

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(category: category)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.note.isEmpty ? item.categoryName : item.note)
                Text(details)
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
            }
            Spacer()
            Text(item.amount.euros)
                .font(.money(.body))
        }
    }

    private var details: String {
        let next = item.nextDate().map { "Next on \($0.formatted(.dateTime.day().month(.abbreviated)))" } ?? "Monthly"
        return item.account == .main ? next : "\(next) · \(item.account.title)"
    }
}
