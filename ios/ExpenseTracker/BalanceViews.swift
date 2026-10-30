import SwiftData
import SwiftUI

struct BalanceEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let isTransfer: Bool
    let balances: Balances

    @State private var amountText = ""
    /// Where the money goes when adding, and where it comes from when moving.
    @State private var account = BalanceAccount.main
    /// Only used when moving.
    @State private var destination = BalanceAccount.savings

    private var amount: Decimal? {
        Decimal(amountInput: amountText).flatMap { $0 > 0 ? $0 : nil }
    }

    private var exceedsBalance: Bool {
        guard isTransfer, let amount else { return false }
        return amount > balances[account]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AmountField(text: $amountText)
                }

                Section {
                    Picker(isTransfer ? "From" : "Add to", selection: $account) {
                        ForEach(BalanceAccount.allCases) { account in
                            Text(account.title).tag(account)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text(isTransfer ? "Move from" : "Add to")
                } footer: {
                    if exceedsBalance {
                        Text("That's more than this balance holds.")
                            .foregroundStyle(Color.negative)
                    } else if isTransfer {
                        Text("\(balances[account].euros) available.")
                    }
                }

                if isTransfer {
                    Section("Move to") {
                        Picker("To", selection: $destination) {
                            ForEach(BalanceAccount.allCases.filter { $0 != account }) { account in
                                Text(account.title).tag(account)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isTransfer ? "Move money" : "Add money")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: account) { _, newValue in
                if destination == newValue {
                    destination = BalanceAccount.allCases.first { $0 != newValue } ?? destination
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .bold()
                        .disabled(amount == nil || exceedsBalance)
                }
            }
        }
    }

    private func save() {
        guard let amount else { return }
        let entry = isTransfer
            ? BalanceEntry(amount: amount, source: account, destination: destination, date: .now)
            : BalanceEntry(amount: amount, source: nil, destination: account, date: .now)
        modelContext.insert(entry)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

struct BalanceHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BalanceEntry.date, order: .reverse) private var entries: [BalanceEntry]

    var body: some View {
        List {
            Section {
                if entries.isEmpty {
                    Text("No money added or moved yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(entries) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: entry.source == nil ? "plus" : "arrow.left.arrow.right")
                            .font(.subheadline.bold())
                            .foregroundStyle(entry.source == nil ? Color.positive : .brand)
                            .frame(width: 40, height: 40)
                            .background((entry.source == nil ? Color.positive : .brand).opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading) {
                            Text(title(for: entry))
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(entry.amount.euros)
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        modelContext.delete(entries[index])
                    }
                }
            } footer: {
                Text("Swipe left to delete an entry and undo its effect on your balances.")
            }
        }
        .navigationTitle("Balance history")
    }

    private func title(for entry: BalanceEntry) -> String {
        if let source = entry.source {
            return "Moved from \(source.title) to \(entry.destination.title)"
        }
        return "Added to \(entry.destination.title)"
    }
}
