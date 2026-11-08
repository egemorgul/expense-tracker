import SwiftUI
import WidgetKit

@main
struct ExpenseTrackerWidgets: WidgetBundle {
    var body: some Widget {
        BalanceWidget()
        BudgetWidget()
        QuickAddWidget()
    }
}

// MARK: - Balances

struct BalanceEntry: TimelineEntry {
    let date: Date
    /// Nil until the app has run once.
    let snapshot: WidgetSnapshot?
}

struct BalanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> BalanceEntry {
        BalanceEntry(date: .now, snapshot: WidgetSnapshot(amounts: [.main: 1250, .savings: 500, .cash: 40]))
    }

    func getSnapshot(in context: Context, completion: @escaping (BalanceEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : BalanceEntry(date: .now, snapshot: .load()))
    }

    /// Balances only change in the app, which asks for a reload each time, so this never expires.
    func getTimeline(in context: Context, completion: @escaping (Timeline<BalanceEntry>) -> Void) {
        completion(Timeline(entries: [BalanceEntry(date: .now, snapshot: .load())], policy: .never))
    }
}

struct BalanceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BalanceWidget", provider: BalanceProvider()) { entry in
            BalanceWidgetView(snapshot: entry.snapshot)
                .containerBackground(Color.paper, for: .widget)
        }
        .configurationDisplayName("Balances")
        .description("See what's left in Main, Savings and Cash.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct BalanceWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let snapshot: WidgetSnapshot?

    var body: some View {
        if let snapshot {
            switch family {
            case .accessoryInline:
                Text("\(BalanceAccount.main.title) \(snapshot[.main].euros)")
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(BalanceAccount.allCases) { account in
                        HStack {
                            Text(account.title)
                            Spacer()
                            Text(snapshot[account].euros)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    }
                }
            case .systemMedium:
                HStack(alignment: .top, spacing: 12) {
                    ForEach(BalanceAccount.allCases) { account in
                        AccountAmount(account: account, value: snapshot[account], font: .title3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxHeight: .infinity)
            default:
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(BalanceAccount.allCases) { account in
                        AccountAmount(account: account, value: snapshot[account], font: .subheadline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text("Open Expenses to see your balances.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AccountAmount: View {
    let account: BalanceAccount
    let value: Decimal
    let font: Font.TextStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(account.title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value.euros)
                .font(.system(font, design: .serif, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(value < 0 ? Color.negative : Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

// MARK: - Budget

struct BudgetTimelineEntry: TimelineEntry {
    let date: Date
    /// Nil until the app has run once.
    let snapshot: BudgetSnapshot?

    var status: BudgetStatus? {
        snapshot?.status(at: date)
    }
}

struct BudgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BudgetTimelineEntry {
        let start = Calendar.current.date(byAdding: .day, value: -9, to: .now) ?? .now
        let snapshot = BudgetSnapshot(
            plan: BudgetPlan(amount: 1000, start: start, end: nil),
            spending: [BudgetSpending(date: start, amount: 310), BudgetSpending(date: .now, amount: 12)]
        )
        return BudgetTimelineEntry(date: .now, snapshot: snapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetTimelineEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : BudgetTimelineEntry(date: .now, snapshot: .load()))
    }

    /// Spending only changes in the app, which asks for a reload each time. The day's budget changes
    /// at midnight, so there's an entry for each of the next week's midnights.
    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetTimelineEntry>) -> Void) {
        let snapshot = BudgetSnapshot.load()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let midnights = (1...7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        let entries = [BudgetTimelineEntry(date: .now, snapshot: snapshot)]
            + midnights.map { BudgetTimelineEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct BudgetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: BudgetSnapshot.widgetKind, provider: BudgetProvider()) { entry in
            BudgetWidgetView(status: entry.status)
                .containerBackground(Color.paper, for: .widget)
        }
        .configurationDisplayName("Today's budget")
        .description("See how much you can spend today.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct BudgetWidgetView: View {
    @Environment(\.widgetFamily) private var family

    /// Nil when there's no budget.
    let status: BudgetStatus?

    var body: some View {
        if case .active(let day) = status {
            active(day)
        } else {
            inactive
        }
    }

    @ViewBuilder
    private func active(_ day: BudgetDay) -> some View {
        let over = day.leftToday < 0
        let amount = over ? (-day.leftToday).euros : day.leftToday.euros
        switch family {
        case .accessoryInline:
            Text(over ? "\(amount) over today" : "\(amount) left today")
        case .accessoryCircular:
            Gauge(value: day.leftTodayFraction) {
                Text("Today")
            } currentValueLabel: {
                Text(day.leftToday.wholeEuros)
                    .minimumScaleFactor(0.5)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .accessibilityLabel(over ? "\(amount) over today's budget" : "\(amount) left today")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                Text(over ? "Over today's budget" : "Left today")
                    .font(.caption)
                Text(amount)
                    .font(.system(.title3, design: .serif, weight: .bold))
                    .monospacedDigit()
                    .widgetAccentable()
                Text("of \(day.dailyBudget.euros) · \(day.daysLeft)d left")
                    .font(.caption2)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 4) {
                Text(over ? "Over today" : "Left today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(amount)
                    .font(.system(.title, design: .serif, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(over ? Color.negative : Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("of \(day.dailyBudget.euros)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                ProgressView(value: day.spentFraction)
                    .tint(day.left < 0 ? Color.negative : Color.brand)
                Text("\(day.left.euros) left · \(day.daysLeft) \(day.daysLeft == 1 ? "day" : "days")")
                    .font(.caption2)
                    .foregroundStyle(day.left < 0 ? Color.negative : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var inactive: some View {
        let message = switch status {
        case .upcoming(let starts): "Budget starts \(starts.formatted(.dateTime.day().month(.abbreviated)))"
        case .ended: "Budget ended"
        default: "No budget set"
        }
        switch family {
        case .accessoryInline:
            Text(message)
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "calendar")
                    .font(.title3)
            }
            .accessibilityLabel(message)
        default:
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private extension Decimal {
    /// Fits the small circular widget, like "€23" or "-€5". Cents are dropped, rounding towards zero.
    var wholeEuros: String {
        var value = self
        var whole = Decimal()
        NSDecimalRound(&whole, &value, 0, self < 0 ? .up : .down)
        return whole.formatted(.currency(code: "EUR").precision(.fractionLength(0)))
    }
}

// MARK: - Quick add

struct QuickAddEntry: TimelineEntry {
    let date: Date
}

struct QuickAddProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickAddEntry {
        QuickAddEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickAddEntry) -> Void) {
        completion(QuickAddEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickAddEntry>) -> Void) {
        completion(Timeline(entries: [QuickAddEntry(date: .now)], policy: .never))
    }
}

/// Widgets can't take typed input, so tapping opens the app on the Add Expense form.
struct QuickAddWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickAddWidget", provider: QuickAddProvider()) { _ in
            QuickAddWidgetView()
                .widgetURL(WidgetLink.addExpense)
                .containerBackground(Color.paper, for: .widget)
        }
        .configurationDisplayName("Add expense")
        .description("Jump straight to adding an expense.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryInline])
    }
}

struct QuickAddWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "plus")
                    .font(.title2.bold())
            }
            .accessibilityLabel("Add expense")
        case .accessoryInline:
            Label("Add expense", systemImage: "plus")
        default:
            VStack(spacing: 8) {
                HearthMark()
                    .frame(height: 84)
                Text("Add expense")
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .foregroundStyle(Color.ink)
            }
        }
    }
}
