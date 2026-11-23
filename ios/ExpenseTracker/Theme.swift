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

enum LedgerAppearance {
    /// Bars can only be fully restyled through UIKit, so this runs once when the app starts.
    static func apply() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = .paper
        navigation.shadowColor = .clear
        navigation.titleTextAttributes = [.foregroundColor: UIColor.ink, .font: font(.headline, weight: .semibold)]
        navigation.largeTitleTextAttributes = [.foregroundColor: UIColor.ink, .font: font(.largeTitle, weight: .bold)]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation

        let tabs = UITabBarAppearance()
        tabs.configureWithOpaqueBackground()
        tabs.backgroundColor = .paper
        tabs.shadowColor = UIColor(light: 0xE4E3DD, dark: 0x2C2C29)
        UITabBar.appearance().standardAppearance = tabs
        UITabBar.appearance().scrollEdgeAppearance = tabs
    }

    private static func font(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let size = UIFont.preferredFont(forTextStyle: style).pointSize
        return UIFontMetrics(forTextStyle: style).scaledFont(for: .systemFont(ofSize: size, weight: weight))
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
    /// The screen's one primary action. Sits above the tab bar, within thumb reach, and the list
    /// scrolls clear of it.
    func addExpenseButton(action: @escaping () -> Void) -> some View {
        safeAreaInset(edge: .bottom) {
            Button(action: action) {
                Label("Add expense", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(Color.paper)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 50)
                    .background(Color.ink, in: Capsule())
            }
            .buttonStyle(PressableButtonStyle())
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    /// The paper behind a list or form. Pair it with `ledgerRows()` on each section.
    func ledgerPage() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.paper)
    }

    func ledgerRows() -> some View {
        listRowBackground(Color.card)
    }

    /// Sheets don't inherit these from the screen that opens them.
    func ledgerSheet() -> some View {
        tint(.brand)
            .foregroundStyle(Color.ink)
    }

    /// A card that sits straight on the paper, outside a list section. Its corners match the list's
    /// own sections, which iOS 26 rounds much more than earlier versions.
    func ledgerCard(padding: CGFloat = 16) -> some View {
        let radius: CGFloat = if #available(iOS 26, *) { 26 } else { 12 }
        return self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Clears a row's list styling, for cards laid out by hand inside a list.
    func bareRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    /// Shows an alert while `message` is set, and clears it when dismissed.
    func errorAlert(_ title: String, message: Binding<String?>) -> some View {
        alert(title, isPresented: Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )) {
            Button("OK") {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }

    /// Swipe right to edit a list row and left to delete it. A full swipe doesn't delete, so a row
    /// can't be lost to a slip of the thumb: the Delete button has to be tapped. Delete is declared here rather than with
    /// `onDelete`, because a row with custom swipe actions can lose the one `onDelete` provides.
    func editDeleteSwipeActions(edit: (() -> Void)?, delete: @escaping () -> Void) -> some View {
        swipeActions(edge: .leading) {
            if let edit {
                Button("Edit", systemImage: "pencil", action: edit)
                    .tint(.brand)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", systemImage: "trash", role: .destructive, action: delete)
        }
    }
}

/// The small label above a group of figures, like "Main balance".
struct Caption: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Color.inkSecondary)
    }
}

/// A day's heading in a list, with that day's total on the right.
struct DayHeader: View {
    let date: Date
    let total: String
    var totalColor = Color.inkSecondary

    var body: some View {
        HStack {
            Text(date.dayTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ink)
            Spacer()
            Text(total)
                .font(.money(.subheadline))
                .foregroundStyle(totalColor)
        }
        .textCase(nil)
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
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A neutral icon in the same place as a category badge, for rows that aren't expenses.
struct SymbolBadge: View {
    let systemName: String
    var color = Color.inkSecondary

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(color)
            .frame(width: 36, height: 36)
            .background(Color.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct ExpenseRow: View {
    let expense: Expense
    let category: ExpenseCategory?
    var showsDate = true
    /// Shows the amount as money going out, for lists that mix in income.
    var showsSign = false
    /// In a list of one category the name would repeat on every row, so the note leads instead.
    var showsCategory = true

    private var title: String {
        if !showsCategory, !expense.note.isEmpty { return expense.note }
        return expense.categoryName
    }

    private var meta: String {
        var parts: [String] = []
        if showsDate { parts.append(expense.date.formatted(date: .abbreviated, time: .omitted)) }
        if expense.account != .main { parts.append("from \(expense.account.title)") }
        if showsCategory, !expense.note.isEmpty { parts.append(expense.note) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(category: category)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if !meta.isEmpty {
                    Text(meta)
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
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
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

/// The large amount at the top of a form, with a specific message once the input can't be read.
struct AmountField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 48

    /// Laid out like every other amount in the app, which follows the region, like "0,00 €".
    private static let sample = Decimal(0).euros
    private static let symbolComesFirst = sample.hasPrefix("€")
    private static let placeholder = "0\(Locale.current.decimalSeparator ?? ".")00"

    private var symbol: some View {
        Text("€")
            .foregroundStyle(Color.inkSecondary)
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
            .font(.system(size: size, weight: .semibold).monospacedDigit())

            if isInvalid {
                Label("Use at most two decimals, like 12.50", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(Color.negative)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .listRowBackground(Color.clear)
        .onAppear { isFocused = true }
    }
}
