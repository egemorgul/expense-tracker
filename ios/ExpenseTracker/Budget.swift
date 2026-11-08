import Foundation
import SwiftData
import WidgetKit

/// The user's spending budget. There's at most one, and the app always uses the first.
@Model
final class Budget {
    var amount: Decimal
    var startDate: Date
    /// The last day, included. Nil when the budget repeats monthly.
    var endDate: Date?

    init(plan: BudgetPlan) {
        self.amount = plan.amount
        self.startDate = plan.start
        self.endDate = plan.end
    }

    var plan: BudgetPlan {
        get { BudgetPlan(amount: amount, start: startDate, end: endDate) }
        set {
            amount = newValue.amount
            startDate = newValue.start
            endDate = newValue.end
        }
    }
}

extension Array where Element == Expense {
    /// Every account's expenses count towards the budget.
    var budgetSpending: [BudgetSpending] {
        map { BudgetSpending(date: $0.date, amount: $0.amount) }
    }
}

extension BudgetSnapshot {
    /// Keeps only the spending the widget can still need: the current period's and anything later.
    init(plan: BudgetPlan?, expenses: [Expense], at date: Date = .now) {
        let from: Date? = switch plan?.timing(at: date) {
        case .upcoming(let starts): starts
        case .active(let period): period.start
        case .ended, nil: nil
        }
        self.init(plan: plan, spending: from.map { from in expenses.filter { $0.date >= from }.budgetSpending } ?? [])
    }

    /// UI tests run on made-up data, which must not reach the widgets.
    func publish() {
        guard !ProcessInfo.processInfo.arguments.contains("-uiTesting"), self != Self.load() else { return }
        save()
        WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
    }
}
