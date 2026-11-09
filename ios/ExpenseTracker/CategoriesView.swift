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
                    .warmRows()

                    Section {
                        ForEach(categories) { category in
                            let count = expenseCounts[category.name, default: 0]
                            HStack(spacing: 12) {
                                CategoryBadge(category: category)
                                Text(category.name)
                                Spacer()
                                Text(usage(count))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            // A row that's a button opens on a swipe when it can't be deleted, so the
                            // icon is changed with a swipe right, like editing elsewhere in the app.
                            .swipeActions(edge: .leading) {
                                Button("Icon", systemImage: "square.grid.2x2") {
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
                        }
                    } header: {
                        Text("Categories")
                    } footer: {
                        Text("Swipe right on a category to change its icon, or left to delete it. Categories with expenses can't be deleted, and at least one has to remain.")
                    }
                    .warmRows()
                }
                .warmPage()
                // A new category goes to the end of the list, which can be off-screen.
                .onChange(of: categories.count) { oldCount, newCount in
                    guard newCount > oldCount, let last = categories.last else { return }
                    withAnimation { proxy.scrollTo(last.name, anchor: .bottom) }
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $categoryBeingEdited) { request in
                CategoryIconSheet(category: request.model)
                    .warmSheet()
                    .presentationDetents([.medium])
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
        name = ""
        icon = ExpenseCategory.defaultIcon
        isEditing = false
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
                        .foregroundStyle(isSelected ? color : .secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            isSelected ? color.opacity(0.14) : Color.paper,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(isSelected ? color : .clear, lineWidth: 1.5)
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

private struct CategoryIconSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var category: ExpenseCategory

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CategoryIconGrid(selection: $category.icon, color: category.color)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("Icons for \(category.name)")
                }
                .warmRows()
            }
            .warmPage()
            .navigationTitle(category.name)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // An emoji saved before icons were symbols becomes the symbol it's shown as.
                if category.icon != category.symbolName { category.icon = category.symbolName }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
