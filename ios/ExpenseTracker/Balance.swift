import Foundation
import SwiftData

enum BalanceAccount: String, CaseIterable, Identifiable {
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

/// Money added to an account, or moved between accounts when it has a source. Balances are always
/// worked out from these entries and the expenses, so deleting either one undoes its effect.
@Model
final class BalanceEntry {
    var amount: Decimal
    var sourceName: String?
    var destinationName: String
    var date: Date

    init(amount: Decimal, source: BalanceAccount?, destination: BalanceAccount, date: Date) {
        self.amount = amount
        self.sourceName = source?.rawValue
        self.destinationName = destination.rawValue
        self.date = date
    }

    var source: BalanceAccount? {
        sourceName.flatMap(BalanceAccount.init(rawValue:))
    }

    var destination: BalanceAccount {
        BalanceAccount(rawValue: destinationName) ?? .main
    }
}

struct Balances {
    private var amounts: [BalanceAccount: Decimal] = [:]

    /// Every expense comes out of its account straight away, including ones dated in the future.
    init(entries: [BalanceEntry], expenses: [Expense]) {
        for entry in entries {
            amounts[entry.destination, default: 0] += entry.amount
            if let source = entry.source {
                amounts[source, default: 0] -= entry.amount
            }
        }
        for expense in expenses {
            amounts[expense.account, default: 0] -= expense.amount
        }
    }

    subscript(account: BalanceAccount) -> Decimal {
        amounts[account, default: 0]
    }
}
