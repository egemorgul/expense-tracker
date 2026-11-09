import Charts
import SwiftUI

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
        // Titles use the system sans. The serif is kept for money, see `Font.money`.
        navigation.titleTextAttributes = [.foregroundColor: UIColor.ink, .font: semibold(style: .headline)]
        navigation.largeTitleTextAttributes = [.foregroundColor: UIColor.ink, .font: semibold(style: .largeTitle)]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation

        let tabs = UITabBarAppearance()
        tabs.configureWithOpaqueBackground()
        tabs.backgroundColor = .paper
        tabs.shadowColor = UIColor.ink.withAlphaComponent(0.08)
        UITabBar.appearance().standardAppearance = tabs
        UITabBar.appearance().scrollEdgeAppearance = tabs
    }

    private static func semibold(style: UIFont.TextStyle) -> UIFont {
        let size = UIFont.preferredFont(forTextStyle: style).pointSize
        return UIFontMetrics(forTextStyle: style).scaledFont(for: .systemFont(ofSize: size, weight: .semibold))
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
                    .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
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

/// A category's line icon in its color, which matches its part of the spending charts.
struct CategoryBadge: View {
    let category: ExpenseCategory?

    var body: some View {
        let color = category?.color ?? CategoryColor.gray.color
        Image(systemName: category?.symbolName ?? ExpenseCategory.defaultIcon)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(color)
            .frame(width: 36, height: 36)
            .background(color.opacity(0.14), in: Circle())
            .accessibilityHidden(true)
    }
}

/// A neutral icon in the same place as a category badge, for rows that aren't expenses.
struct SymbolBadge: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 36, height: 36)
            .background(Color.ink.opacity(0.06), in: Circle())
            .accessibilityHidden(true)
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
            CategoryBadge(category: category)
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.categoryName)
                if !meta.isEmpty {
                    Text(meta)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(showsSign ? (-expense.amount).signedEuros : expense.amount.euros)
                .font(.money(.body))
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

    /// Laid out like every other amount in the app, which follows the region, like "0,00 €".
    private static let sample = Decimal(0).euros
    private static let symbolComesFirst = sample.hasPrefix("€")
    private static let placeholder = "0\(Locale.current.decimalSeparator ?? ".")00"

    private var symbol: some View {
        Text("€")
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }

    private var isInvalid: Bool {
        !text.isEmpty && Decimal(amountInput: text) == nil
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                if Self.symbolComesFirst { symbol }
                // The field is as wide as its placeholder, so the placeholder goes once typing starts.
                // Otherwise a symbol after the amount, like "18 €", would sit apart from it.
                TextField(text.isEmpty ? Self.placeholder : "", text: $text)
                    .tint(.brand)
                    .keyboardType(.decimalPad)
                    .focused($isFocused)
                    .fixedSize()
                    .accessibilityLabel("Amount (€)")
                if !Self.symbolComesFirst { symbol }
            }
            .font(.money(.largeTitle, prominent: true))

            if isInvalid {
                Label("Use at most two decimals, like 12.50", systemImage: "exclamationmark.circle")
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
