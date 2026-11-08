import Foundation

// Used by both the app and its widgets, so the widget can work out a new day's budget at midnight
// without the app running.

/// How much can be spent over a period. Without an end date it repeats monthly from its start, so a
/// plan starting on 1 September runs to 1 October, then to 1 November, and so on.
struct BudgetPlan: Codable, Equatable {
    var amount: Decimal
    var start: Date
    /// The last day the plan covers, included. Nil when it repeats monthly.
    var end: Date?

    enum Timing: Equatable {
        case upcoming(starts: Date)
        /// From the start of its first day to the start of the day after its last.
        case active(DateInterval)
        case ended(lastDay: Date)
    }

    func timing(at date: Date, calendar: Calendar = .current) -> Timing {
        let first = calendar.startOfDay(for: start)
        guard date >= first else { return .upcoming(starts: first) }

        if let end {
            let lastDay = calendar.startOfDay(for: end)
            let after = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
            return date < after ? .active(DateInterval(start: first, end: after)) : .ended(lastDay: lastDay)
        }

        // Each month is counted from the first start, so one beginning on the 31st comes back to the
        // 31st after a shorter month instead of drifting to the 28th.
        func monthStart(_ months: Int) -> Date {
            calendar.startOfDay(for: calendar.date(byAdding: .month, value: months, to: first) ?? first)
        }
        var months = calendar.dateComponents([.month], from: first, to: date).month ?? 0
        while months > 0, monthStart(months) > date { months -= 1 }
        while monthStart(months + 1) <= date { months += 1 }
        return .active(DateInterval(start: monthStart(months), end: monthStart(months + 1)))
    }

    func status(spending: [BudgetSpending], at date: Date, calendar: Calendar = .current) -> BudgetStatus {
        switch timing(at: date, calendar: calendar) {
        case .upcoming(let starts): .upcoming(starts: starts)
        case .ended(let lastDay): .ended(lastDay: lastDay)
        case .active(let period): .active(BudgetDay(amount: amount, period: period, spending: spending, at: date, calendar: calendar))
        }
    }
}

struct BudgetSpending: Codable, Equatable {
    let date: Date
    let amount: Decimal
}

enum BudgetStatus: Equatable {
    case upcoming(starts: Date)
    case active(BudgetDay)
    case ended(lastDay: Date)
}

/// Where a budget stands on one day. The daily budget is set at the start of the day and doesn't
/// change as the day's spending comes in. Overspending today lowers tomorrow's budget instead.
struct BudgetDay: Equatable {
    let amount: Decimal
    let period: DateInterval
    /// Including today.
    let daysLeft: Int
    /// Everything in the period, including expenses dated later than today.
    let spent: Decimal
    let spentToday: Decimal
    let dailyBudget: Decimal

    init(amount: Decimal, period: DateInterval, spending: [BudgetSpending], at date: Date, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: date)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? period.end
        let inPeriod = spending.filter { $0.date >= period.start && $0.date < period.end }
        let spentToday = inPeriod.filter { $0.date >= today && $0.date < tomorrow }.total
        let spent = inPeriod.total
        let daysLeft = max(1, calendar.dateComponents([.day], from: today, to: period.end).day ?? 1)

        self.amount = amount
        self.period = period
        self.daysLeft = daysLeft
        self.spent = spent
        self.spentToday = spentToday
        // Expenses already planned for later days are set aside, so the daily budget leaves room for them.
        // Rounding down keeps the days' budgets from adding up to more than is left.
        self.dailyBudget = max(0, (amount - (spent - spentToday)) / Decimal(daysLeft)).roundedDown
    }

    /// Below zero once today's spending goes over the daily budget.
    var leftToday: Decimal { dailyBudget - spentToday }

    /// Below zero once the period's spending goes over the whole budget.
    var left: Decimal { amount - spent }

    /// How much of the budget is spent, from 0 to 1.
    var spentFraction: Double {
        guard amount > 0 else { return 1 }
        return min(1, max(0, (spent / amount).doubleValue))
    }

    /// How much of today's budget is left, from 0 to 1.
    var leftTodayFraction: Double {
        guard dailyBudget > 0 else { return 0 }
        return min(1, max(0, (leftToday / dailyBudget).doubleValue))
    }

    /// The period's last day, included.
    var lastDay: Date {
        period.end.addingTimeInterval(-1)
    }
}

/// A copy of the budget for the widget, like `WidgetSnapshot`. It holds the period's spending
/// rather than the day's result, so the widget can work out each new day itself.
struct BudgetSnapshot: Codable, Equatable {
    static let widgetKind = "BudgetWidget"
    private static let key = "budget"

    /// Nil when there's no budget.
    var plan: BudgetPlan?
    var spending: [BudgetSpending]

    func status(at date: Date) -> BudgetStatus? {
        plan?.status(spending: spending, at: date)
    }

    /// Nil until the app has run once.
    static func load(from defaults: UserDefaults? = UserDefaults(suiteName: WidgetSnapshot.appGroup)) -> BudgetSnapshot? {
        defaults?.data(forKey: key).flatMap { try? JSONDecoder().decode(BudgetSnapshot.self, from: $0) }
    }

    func save(to defaults: UserDefaults? = UserDefaults(suiteName: WidgetSnapshot.appGroup)) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults?.set(data, forKey: Self.key)
    }
}

extension Array where Element == BudgetSpending {
    var total: Decimal {
        reduce(0) { $0 + $1.amount }
    }
}

extension Decimal {
    /// To the cent below.
    var roundedDown: Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, 2, .down)
        return result
    }

    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
