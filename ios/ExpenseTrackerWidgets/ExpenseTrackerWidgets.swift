import SwiftUI
import WidgetKit

@main
struct ExpenseTrackerWidgets: WidgetBundle {
    var body: some Widget {
        BalanceWidget()
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
