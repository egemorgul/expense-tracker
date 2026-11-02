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

extension Decimal {
    var euros: String {
        formatted(.currency(code: "EUR"))
    }
}

extension Color {
    /// The page, like warm paper, and the cards that sit on it.
    static let paper = Color(uiColor: .paper)
    static let card = Color(light: 0xFFFBF3, dark: 0x2C1A12)
    /// Text. Warm brown-black rather than pure black.
    static let ink = Color(light: 0x2B1A12, dark: 0xF6E9D8)

    /// Terracotta from the logo in light mode, and its glowing coin in dark mode.
    static let brand = Color(light: 0xB4471E, dark: 0xF4A84A)
    /// Text and icons on top of `brand`.
    static let onBrand = Color(light: 0xFFF8EC, dark: 0x2B120A)
    static let positive = Color(light: 0x2F6B3C, dark: 0x8CC98F)
    static let negative = Color(light: 0xA9281F, dark: 0xF28B7D)

    /// The balance card stays dark and glowing in both appearances, so its text is always light.
    static let heroTop = Color(hex: 0x2B120A)
    static let heroBottom = Color(hex: 0x6E2614)
    static let heroNegative = Color(hex: 0xFFB4A0)
    static let heroText = Color(hex: 0xFFF3E0)

    /// The arches of the logo, from the outside in, and its coin.
    static let arches = [Color(hex: 0xD8622E), Color(hex: 0xA9411F), Color(hex: 0x6E2614), Color(hex: 0x2F100A)]
    static let coinLight = Color(hex: 0xFFDC92)
    static let coinMid = Color(hex: 0xF8B040)
    static let coinDark = Color(hex: 0xE58C22)
    static let glow = Color(hex: 0xFF8A2B)

    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    private init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor(light: light, dark: dark))
    }
}

extension UIColor {
    static let paper = UIColor(light: 0xF8EFE0, dark: 0x1B0F0A)

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

/// An arch with a flat base, whose top is a full semicircle.
struct ArchShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = rect.width / 2
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// The logo: arches receding like a hearth, one for each account, around a glowing coin.
/// Its proportions match `Branding/hearth-app-icon.svg`, with the height running to the arch's base.
struct HearthMark: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let unit = width / 744
            ZStack(alignment: .bottom) {
                ForEach(Array(Color.arches.enumerated()), id: \.offset) { index, color in
                    let inset = CGFloat(index) * 76 * unit
                    ArchShape()
                        .fill(color)
                        .frame(width: width - inset * 2, height: proxy.size.height - inset)
                }
                RadialGradient(colors: [.glow.opacity(0.72), .glow.opacity(0)], center: .center, startRadius: 0, endRadius: 300 * unit)
                    .frame(width: 440 * unit, height: 600 * unit)
                    .clipShape(ArchShape())
                Circle()
                    .fill(RadialGradient(colors: [.coinLight, .coinMid, .coinDark], center: .init(x: 0.36, y: 0.3), startRadius: 0, endRadius: 190 * unit))
                    .frame(width: 244 * unit, height: 244 * unit)
                    .offset(y: -160 * unit)
            }
            .frame(width: width, height: proxy.size.height, alignment: .bottom)
        }
        .aspectRatio(744 / 884, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
