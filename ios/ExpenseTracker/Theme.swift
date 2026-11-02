import Charts
import SwiftUI

extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}

extension Date {
    /// The heading for a day in a list of transactions.
    var dayTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return "Today" }
        if calendar.isDateInYesterday(self) { return "Yesterday" }
        return formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

/// Opens a form on one model with `sheet(item:)`. A model's own id changes when it's first saved, a
/// few seconds after being added. Using that id would rebuild an open form and lose what was typed.
struct EditRequest<Model>: Identifiable {
    let id = UUID()
    let model: Model

    init(_ model: Model) {
        self.model = model
    }
}

enum WarmAppearance {
    /// Bars can only be fully restyled through UIKit, so this runs once when the app starts.
    static func apply() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = .paper
        navigation.shadowColor = .clear
        let ink = UIColor(light: 0x2B1A12, dark: 0xF6E9D8)
        navigation.titleTextAttributes = [.foregroundColor: ink, .font: serif(style: .headline)]
        navigation.largeTitleTextAttributes = [.foregroundColor: ink, .font: serif(style: .largeTitle)]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation

        let tabs = UITabBarAppearance()
        tabs.configureWithOpaqueBackground()
        tabs.backgroundColor = .paper
        tabs.shadowColor = UIColor(light: 0xE6D6BE, dark: 0x3A241A)
        UITabBar.appearance().standardAppearance = tabs
        UITabBar.appearance().scrollEdgeAppearance = tabs
    }

    private static func serif(style: UIFont.TextStyle) -> UIFont {
        let base = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style).withSymbolicTraits(.traitBold)
            ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: style)
        return UIFont(descriptor: base.withDesign(.serif) ?? base, size: 0)
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    /// Sits above the tab bar, within thumb reach, and the list scrolls clear of it.
    func addExpenseButton(action: @escaping () -> Void) -> some View {
        safeAreaInset(edge: .bottom) {
            Button(action: action) {
                Label("Add expense", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(Color.onBrand)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 50)
                    .background(Color.brand, in: Capsule())
                    .shadow(color: Color.heroBottom.opacity(0.35), radius: 12, y: 6)
            }
            .buttonStyle(PressableButtonStyle())
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    /// The warm page behind a list or form. Pair it with `warmRows()` on each section.
    func warmPage() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.paper)
    }

    func warmRows() -> some View {
        listRowBackground(Color.card)
    }

    /// Sheets don't inherit these from the screen that opens them.
    func warmSheet() -> some View {
        tint(.brand)
            .foregroundStyle(Color.ink)
    }

    /// Swipe right to edit a list row and left to delete it. Delete is declared here rather than with
    /// `onDelete`, because a row with custom swipe actions can lose the one `onDelete` provides.
    func editDeleteSwipeActions(edit: (() -> Void)?, delete: @escaping () -> Void) -> some View {
        swipeActions(edge: .leading) {
            if let edit {
                Button("Edit", systemImage: "pencil", action: edit)
                    .tint(.brand)
            }
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive, action: delete)
        }
    }
}

struct CategoryBadge: View {
    let icon: String
    let color: Color

    var body: some View {
        Text(icon)
            .font(.title3)
            .frame(width: 40, height: 40)
            .background(color.opacity(0.2), in: Circle())
    }
}

struct ExpenseRow: View {
    let expense: Expense
    let category: ExpenseCategory?
    var showsDate = true
    /// Shows the amount as money going out, for lists that mix in income.
    var showsSign = false

    private var meta: String {
        var parts: [String] = []
        if showsDate { parts.append(expense.date.formatted(date: .abbreviated, time: .omitted)) }
        if expense.account != .main { parts.append("from \(expense.account.title)") }
        if !expense.note.isEmpty { parts.append(expense.note) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(icon: category?.icon ?? ExpenseCategory.defaultIcon, color: category?.color ?? .gray)
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.categoryName)
                    .font(.body.weight(.medium))
                if !meta.isEmpty {
                    Text(meta)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(showsSign ? (-expense.amount).signedEuros : expense.amount.euros)
                .font(.system(.body, design: .serif, weight: .semibold))
                .monospacedDigit()
        }
    }
}

/// Each category's share of the total as one bar, largest first.
struct CategoryShareBar: View {
    let totals: [CategoryTotal]
    let categoriesByName: [String: ExpenseCategory]

    var body: some View {
        Chart(totals) { row in
            BarMark(x: .value("Amount", row.subtotal.doubleValue), stacking: .normalized)
                .foregroundStyle(categoriesByName[row.categoryName]?.color ?? .gray)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .clipShape(Capsule())
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}

/// The large amount at the top of a form, with a specific message once the input can't be read.
struct AmountField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    private var isInvalid: Bool {
        !text.isEmpty && Decimal(amountInput: text) == nil
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text("€")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("0.00", text: $text)
                    .tint(.brand)
                    .keyboardType(.decimalPad)
                    .focused($isFocused)
                    .fixedSize()
                    .accessibilityLabel("Amount (€)")
            }
            .font(.system(.largeTitle, design: .serif, weight: .bold))
            .monospacedDigit()

            if isInvalid {
                Label("Use at most two decimals, like 12.50.", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(Color.negative)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .listRowBackground(Color.clear)
        .onAppear { isFocused = true }
    }
}
