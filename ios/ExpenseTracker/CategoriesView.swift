import SwiftData
import SwiftUI

struct CategoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]
    @Query private var expenses: [Expense]

    @State private var name = ""
    @State private var icon = ExpenseCategory.defaultIcon
    @State private var categoryBeingEdited: EditRequest<ExpenseCategory>?
    @FocusState private var isEditing: Bool
    @State private var saveError: String?

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDuplicate: Bool {
        categories.containsName(trimmedName)
    }

    var body: some View {
        let expenseCounts = Dictionary(grouping: expenses, by: \.categoryName).mapValues(\.count)

        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    Section {
                        TextField("Name", text: $name)
                            .focused($isEditing)
                        CategoryIconGrid(selection: $icon, color: categories.nextColor.color)
                        Button("Add category", action: add)
                            .disabled(trimmedName.isEmpty || isDuplicate)
                    } header: {
                        Text("New category")
                    } footer: {
                        if isDuplicate {
                            Text("That category already exists")
                        }
                    }
                    .ledgerRows()

                    Section {
                        ForEach(categories) { category in
                            let count = expenseCounts[category.name, default: 0]
                            HStack(spacing: 12) {
                                CategoryBadge(category: category)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.name)
                                    if let budget = category.monthlyBudget {
                                        Text("\(budget.euros) a month")
                                            .font(.caption)
                                            .foregroundStyle(Color.inkSecondary)
                                    }
                                }
                                Spacer()
                                Text(usage(count))
                                    .font(.caption)
                                    .foregroundStyle(Color.inkSecondary)
                            }
                            // A row that's a button opens on a swipe when it can't be deleted, so a
                            // category is edited with a swipe right, like editing elsewhere in the app.
                            .swipeActions(edge: .leading) {
                                Button("Edit", systemImage: "pencil") {
                                    categoryBeingEdited = EditRequest(category)
                                }
                                .tint(.brand)
                            }
                            .id(category.name)
                            .deleteDisabled(count > 0 || categories.count == 1)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                modelContext.delete(categories[index])
                            }
                            save()
                        }
                    } header: {
                        Text("Categories")
                    } footer: {
                        Text("Swipe right on a category to change its icon or monthly budget, or left to delete it. Categories with expenses can't be deleted, and at least one has to remain.")
                    }
                    .ledgerRows()
                }
                .ledgerPage()
                // A new category goes to the end of the list, which can be off-screen.
                .onChange(of: categories.count) { oldCount, newCount in
                    guard newCount > oldCount, let last = categories.last else { return }
                    withAnimation { proxy.scrollTo(last.name, anchor: .bottom) }
                }
            }
            .navigationTitle("Categories")
            .errorAlert("Couldn't save", message: $saveError)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $categoryBeingEdited) { request in
                EditCategorySheet(category: request.model)
                    .ledgerSheet()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func usage(_ count: Int) -> String {
        switch count {
        case 0: "Not used"
        case 1: "1 expense"
        default: "\(count) expenses"
        }
    }

    private func add() {
        let category = categories.makeCategory(name: trimmedName, icon: icon)
        modelContext.insert(category)
        guard save() else { return }
        name = ""
        icon = ExpenseCategory.defaultIcon
        isEditing = false
    }

    /// Shows an alert when the change can't be saved, and leaves what was typed in place to try again.
    @discardableResult
    private func save() -> Bool {
        saveError = modelContext.saveNowFailure()
        return saveError == nil
    }
}

/// The line icons a category can use, with the chosen one marked in the category's color.
struct CategoryIconGrid: View {
    @Binding var selection: String
    let color: Color

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
            ForEach(CategorySymbol.choices, id: \.self) { symbol in
                let isSelected = symbol == selection
                Button {
                    selection = symbol
                } label: {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isSelected ? color : Color.inkSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            isSelected ? color.opacity(0.12) : Color.ink.opacity(0.04),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(isSelected ? color : Color.hairline, lineWidth: isSelected ? 2 : 1)
                        }
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(symbol.replacingOccurrences(of: ".", with: " "))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

/// Changes a category's icon and monthly budget. Nothing changes until Save.
private struct EditCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let category: ExpenseCategory

    @State private var icon: String
    @State private var budgetText: String
    @State private var saveError: String?

    init(category: ExpenseCategory) {
        self.category = category
        // An emoji saved before icons were symbols starts as the symbol it's shown as.
        _icon = State(initialValue: category.symbolName)
        _budgetText = State(initialValue: category.monthlyBudget.map { "\($0)" } ?? "")
    }

    /// Nil when the field is empty, which means no budget, or can't be read.
    private var budget: Decimal? {
        Decimal(amountInput: budgetText).flatMap { $0 > 0 ? $0 : nil }
    }

    private var isBudgetValid: Bool {
        budgetText.trimmingCharacters(in: .whitespaces).isEmpty || budget != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Icon") {
                    CategoryIconGrid(selection: $icon, color: category.color)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("Icons for \(category.name)")
                }
                .ledgerRows()

                Section {
                    HStack {
                        Text("€")
                            .foregroundStyle(Color.inkSecondary)
                            .accessibilityHidden(true)
                        TextField("No budget", text: $budgetText)
                            .keyboardType(.decimalPad)
                            .accessibilityLabel("Monthly budget (€)")
                    }
                } header: {
                    Text("Monthly budget")
                } footer: {
                    if !isBudgetValid {
                        Text("Use at most two decimals, like 200 or 12.50")
                            .foregroundStyle(Color.negative)
                    } else {
                        Text("Insights shows how much of it is left each month. Leave it empty for no budget.")
                    }
                }
                .ledgerRows()
            }
            .ledgerPage()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(category.name)
            .navigationBarTitleDisplayMode(.inline)
            .errorAlert("Couldn't save", message: $saveError)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .bold()
                        .disabled(!isBudgetValid)
                }
            }
        }
    }

    private func save() {
        guard isBudgetValid else { return }
        category.icon = icon
        category.monthlyBudget = budget
        saveError = modelContext.saveNowFailure()
        guard saveError == nil else { return }
        dismiss()
    }
}
