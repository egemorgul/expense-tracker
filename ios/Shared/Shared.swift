import Foundation
import SwiftUI

// Used by both the app and its widgets.

enum BalanceAccount: String, CaseIterable, Identifiable, Codable {
    /// The raw value is stored in existing data, so it stays "spending".
    case main = "spending"
    case savings
    case cash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .main: "Main"
        case .savings: "Savings"
        case .cash: "Cash"
        }
    }
}

enum WidgetLink {
    static let addExpense = URL(string: "expensetracker://add-expense")!
}

/// A copy of the balances for the widget to read. The app writes it whenever a balance changes, so
/// the expense store itself never has to be shared or moved.
struct WidgetSnapshot: Codable, Equatable {
    static let appGroup = "group.com.egemorgul.ExpenseTracker"
    private static let key = "balances"

    private var amounts: [String: Decimal]

    init(amounts: [BalanceAccount: Decimal]) {
        self.amounts = Dictionary(uniqueKeysWithValues: amounts.map { ($0.key.rawValue, $0.value) })
    }

    subscript(account: BalanceAccount) -> Decimal {
        amounts[account.rawValue, default: 0]
    }

    /// Nil until the app has run once.
    static func load(from defaults: UserDefaults? = UserDefaults(suiteName: appGroup)) -> WidgetSnapshot? {
        defaults?.data(forKey: key).flatMap { try? JSONDecoder().decode(WidgetSnapshot.self, from: $0) }
    }

    func save(to defaults: UserDefaults? = UserDefaults(suiteName: appGroup)) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults?.set(data, forKey: Self.key)
    }
}

extension Font {
    /// Money is set in the system sans with even-width figures, so amounts line up like a ledger's
    /// columns and don't jump around as they change.
    static func money(_ style: Font.TextStyle, prominent: Bool = false) -> Font {
        .system(style, weight: prominent ? .semibold : .regular).monospacedDigit()
    }
}

extension Decimal {
    var euros: String {
        formatted(.currency(code: "EUR"))
    }
}

/// The Ledger palette: paper and ink, with one green for anything that's yours to act on or that
/// adds money. Category colors are the only other color in the app.
extension Color {
    static let paper = Color(uiColor: .paper)
    /// Rows and cards that sit on the paper.
    static let card = Color(light: 0xFFFFFF, dark: 0x1A1A18)
    static let ink = Color(uiColor: .ink)
    /// Supporting text. Passes 4.5:1 on both paper and cards.
    static let inkSecondary = Color(light: 0x5F5F5A, dark: 0xA6A69F)
    static let hairline = Color(light: 0xE4E3DD, dark: 0x2C2C29)

    /// The one accent: tabs, links, progress and money coming in.
    static let brand = Color(light: 0x136F4A, dark: 0x4CC38A)
    /// Text and icons on top of `brand`.
    static let onBrand = Color(light: 0xFFFFFF, dark: 0x05261A)
    static let positive = brand
    static let negative = Color(light: 0xB42318, dark: 0xFF7B6E)

    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    private init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor(light: light, dark: dark))
    }
}

extension UIColor {
    static let paper = UIColor(light: 0xF1F0EB, dark: 0x0E0E0D)
    static let ink = UIColor(light: 0x141414, dark: 0xF2F2EE)

    convenience init(light: UInt32, dark: UInt32) {
        self.init { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// The logo: two entries, the rule under them, and the total in green. Its proportions match
/// `Branding/ledger-app-icon.svg` without the icon's background.
struct LedgerMark: View {
    var entries = Color.ink
    var total = Color.brand

    var body: some View {
        GeometryReader { proxy in
            let unit = proxy.size.width / 100
            VStack(alignment: .leading, spacing: 0) {
                Capsule().fill(entries).frame(width: 72 * unit, height: 12 * unit)
                Spacer(minLength: 0)
                Capsule().fill(entries).frame(width: 50 * unit, height: 12 * unit)
                Spacer(minLength: 0)
                Capsule().fill(entries.opacity(0.4)).frame(width: 100 * unit, height: 4 * unit)
                Spacer(minLength: 0)
                Capsule().fill(total).frame(width: 60 * unit, height: 12 * unit)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .aspectRatio(100 / 80, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
