import SwiftData
import SwiftUI

struct CategoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]
    @Query private var expenses: [Expense]

    @State private var name = ""
    @State private var icon = ""
    @FocusState private var isEditing: Bool

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
                        TextField("Emoji (optional)", text: $icon)
                            .focused($isEditing)
                            .onChange(of: icon) { _, newValue in
                                if newValue.count > 1 { icon = String(newValue.suffix(1)) }
                            }
                        Button("Add category", action: add)
                            .disabled(trimmedName.isEmpty || isDuplicate)
                    } header: {
                        Text("New category")
                    } footer: {
                        if isDuplicate {
                            Text("That category already exists.")
                        }
                    }

                    Section {
                        ForEach(categories) { category in
                            let count = expenseCounts[category.name, default: 0]
                            HStack(spacing: 12) {
                                CategoryBadge(icon: category.icon, color: category.color)
                                Text(category.name)
                                    .font(.body.weight(.medium))
                                Spacer()
                                Text(usage(count))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .id(category.name)
                            .deleteDisabled(count > 0 || categories.count == 1)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                modelContext.delete(categories[index])
                            }
                        }
                    } header: {
                        Text("Categories")
                    } footer: {
                        Text("Swipe left to delete a category. Categories with expenses can't be deleted, and at least one has to remain.")
                    }
                }
                // A new category goes to the end of the list, which can be off-screen.
                .onChange(of: categories.count) { oldCount, newCount in
                    guard newCount > oldCount, let last = categories.last else { return }
                    withAnimation { proxy.scrollTo(last.name, anchor: .bottom) }
                }
            }
            .navigationTitle("Categories")
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
        let category = categories.makeCategory(name: trimmedName, icon: icon.isEmpty ? ExpenseCategory.defaultIcon : icon)
        modelContext.insert(category)
        name = ""
        icon = ""
        isEditing = false
    }
}
