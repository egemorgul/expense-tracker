import Charts
import SwiftUI

extension Color {
    static let brand = Color(light: 0x1E40AF, dark: 0x60A5FA)
    /// Text and icons on top of `brand`.
    static let onBrand = Color(light: 0xFFFFFF, dark: 0x0F172A)
    static let positive = Color(light: 0x047857, dark: 0x34D399)
    static let negative = Color(light: 0xB91C1C, dark: 0xF87171)

    /// The balance card stays navy in both appearances, so its text is always light.
    static let heroTop = Color(hex: 0x0F172A)
    static let heroBottom = Color(hex: 0x1E3A8A)
    static let heroNegative = Color(hex: 0xFCA5A5)

    private init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    private init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
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
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            }
            .buttonStyle(PressableButtonStyle())
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
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
            .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ExpenseRow: View {
    let expense: Expense
    let category: ExpenseCategory?
    var showsDate = true

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
            Text(expense.amount.euros)
                .font(.system(.body, design: .rounded, weight: .semibold))
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
                    .keyboardType(.decimalPad)
                    .focused($isFocused)
                    .fixedSize()
                    .accessibilityLabel("Amount (€)")
            }
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
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
