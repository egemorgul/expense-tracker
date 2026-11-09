import SwiftData
import SwiftUI

/// The budget on the Overview tab: what's left to spend today, and how the period is going.
struct BudgetCard: View {
    let status: BudgetStatus
    let edit: () -> Void

    var body: some View {
        Button(action: edit) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(heading)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                switch status {
                case .active(let day):
                    ActiveBudget(day: day)
                case .upcoming(let starts):
                    Text("Starts \(starts.formatted(.dateTime.day().month(.wide)))")
                        .font(.title3.weight(.semibold))
                case .ended(let lastDay):
                    Text("Ended \(lastDay.formatted(.dateTime.day().month(.wide)))")
                        .font(.title3.weight(.semibold))
                    Text("Tap to plan your next budget")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityHint("Edits your budget")
    }

    private var heading: String {
        switch status {
        case .active: "Left to spend today"
        case .upcoming, .ended: "Budget"
        }
    }
}

private struct ActiveBudget: View {
    let day: BudgetDay

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(day.leftToday < 0 ? "\((-day.leftToday).euros) over" : day.leftToday.euros)
                .font(.money(.title, prominent: true))
                .foregroundStyle(day.leftToday < 0 ? Color.negative : Color.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.default, value: day.leftToday)
            // Before anything is spent the figure above is the whole daily budget, so this doesn't repeat it.
            Text(day.spentToday > 0 ? "\(day.spentToday.euros) spent of today's \(day.dailyBudget.euros)" : "Nothing spent yet today")
                .font(.caption)
                .foregroundStyle(.secondary)

            ProgressView(value: day.spentFraction)
                .tint(day.left < 0 ? Color.negative : Color.brand)
                .accessibilityLabel("Budget spent")

            HStack {
                Text(day.left < 0 ? "\((-day.left).euros) over \(day.amount.euros)" : "\(day.left.euros) of \(day.amount.euros) left")
                    .foregroundStyle(day.left < 0 ? Color.negative : .secondary)
                Spacer()
                Text(daysLeft)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }

    private var daysLeft: String {
        let until = day.lastDay.formatted(.dateTime.day().month(.abbreviated))
        return day.daysLeft == 1 ? "Last day, \(until)" : "\(day.daysLeft) days left, to \(until)"
    }
}

struct BudgetFormView: View {
    enum Kind: String, CaseIterable, Identifiable {
        case monthly = "Monthly"
        case custom = "Custom dates"

        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let budget: Budget?

    @State private var amountText: String
    @State private var kind: Kind
    @State private var start: Date
    @State private var end: Date
    @State private var isConfirmingRemoval = false

    init(editing budget: Budget?) {
        self.budget = budget
        let start = budget?.startDate ?? Calendar.current.startOfDay(for: .now)
        _amountText = State(initialValue: budget.map { "\($0.amount)" } ?? "")
        _kind = State(initialValue: budget?.endDate == nil ? .monthly : .custom)
        _start = State(initialValue: start)
        _end = State(initialValue: budget?.endDate
            ?? Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: start)
            ?? start)
    }

    private var amount: Decimal? {
        Decimal(amountInput: amountText).flatMap { $0 > 0 ? $0 : nil }
    }

    private var plan: BudgetPlan? {
        amount.map { BudgetPlan(amount: $0, start: start, end: kind == .custom ? end : nil) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AmountField(text: $amountText)
                }

                Section {
                    Picker("Repeats", selection: $kind) {
                        ForEach(Kind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    DatePicker("Starts", selection: $start, displayedComponents: .date)
                    if kind == .custom {
                        DatePicker("Ends", selection: $end, in: start..., displayedComponents: .date)
                    }
                } footer: {
                    Text(explanation)
                }
                .warmRows()

                if budget != nil {
                    Section {
                        Button("Remove budget", role: .destructive) {
                            isConfirmingRemoval = true
                        }
                    }
                    .warmRows()
                }
            }
            .warmPage()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(budget == nil ? "Set a budget" : "Edit budget")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: start) { _, newValue in
                if end < newValue { end = newValue }
            }
            .confirmationDialog("Remove your budget?", isPresented: $isConfirmingRemoval, titleVisibility: .visible) {
                Button("Remove budget", role: .destructive, action: remove)
            } message: {
                Text("Your expenses are kept")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .bold()
                        .disabled(plan == nil)
                }
            }
        }
    }

    private var explanation: String {
        let daily = "Each day at midnight, what's left is split over the days remaining to give that day's budget."
        switch kind {
        case .monthly:
            let next = Calendar.current.date(byAdding: .month, value: 1, to: start) ?? start
            return "Runs from \(start.formatted(.dateTime.day().month(.wide))) to \(next.formatted(.dateTime.day().month(.wide))), then starts again each month. \(daily)"
        case .custom:
            return "Runs from the start of the first day to the end of the last. \(daily)"
        }
    }

    private func save() {
        guard let plan else { return }
        if let budget {
            budget.plan = plan
        } else {
            modelContext.insert(Budget(plan: plan))
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func remove() {
        if let budget {
            modelContext.delete(budget)
        }
        dismiss()
    }
}
