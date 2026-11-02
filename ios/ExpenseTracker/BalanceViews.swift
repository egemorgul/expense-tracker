import SwiftData
import SwiftUI

struct BalanceEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let isTransfer: Bool
    let balances: Balances
    /// Only money added can be edited, so this is never a transfer.
    private let entry: BalanceEntry?

    @State private var amountText: String
    /// Where the money goes when adding, and where it comes from when moving.
    @State private var account: BalanceAccount
    /// Only used when moving.
    @State private var destination = BalanceAccount.savings
    /// Only used when adding. A transfer is dated when it's made.
    @State private var date: Date
    /// Only used when adding.
    @State private var isStartingBalance: Bool

    init(isTransfer: Bool, balances: Balances, editing entry: BalanceEntry? = nil) {
        self.isTransfer = isTransfer
        self.balances = balances
        self.entry = entry
        _amountText = State(initialValue: entry.map { "\($0.amount)" } ?? "")
        _account = State(initialValue: entry?.destination ?? .main)
        _date = State(initialValue: entry?.date ?? .now)
        _isStartingBalance = State(initialValue: entry?.isStartingBalance ?? false)
    }

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
                .warmRows()

                if isTransfer {
                    Section("Move to") {
                        Picker("To", selection: $destination) {
                            ForEach(BalanceAccount.allCases.filter { $0 != account }) { account in
                                Text(account.title).tag(account)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .warmRows()
                } else {
                    Section {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                        Toggle("Starting balance", isOn: $isStartingBalance)
                    } footer: {
                        Text("Turn on for money you already had. It counts towards your balance, but not as income.")
                    }
                    .warmRows()
                }
            }
            .warmPage()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(title)
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

    private var title: String {
        if isTransfer { return "Move money" }
        return entry == nil ? "Add money" : "Edit money added"
    }

    private func save() {
        guard let amount else { return }
        if let entry {
            entry.amount = amount
            entry.destinationName = account.rawValue
            entry.date = date
            entry.isStartingBalance = isStartingBalance
        } else if isTransfer {
            modelContext.insert(BalanceEntry(amount: amount, source: account, destination: destination, date: .now))
        } else {
            modelContext.insert(BalanceEntry(amount: amount, source: nil, destination: account, date: date, isStartingBalance: isStartingBalance))
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

struct BalanceHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BalanceEntry.date, order: .reverse) private var entries: [BalanceEntry]
    @State private var entryBeingEdited: EditRequest<BalanceEntry>?

    let balances: Balances

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
                            .background((entry.source == nil ? Color.positive : .brand).opacity(0.15), in: Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading) {
                            Text(title(for: entry))
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(entry.amount.euros)
                            .font(.system(.body, design: .serif, weight: .semibold))
                            .monospacedDigit()
                    }
                    .editDeleteSwipeActions(
                        edit: entry.source == nil ? { entryBeingEdited = EditRequest(entry) } : nil,
                        delete: { modelContext.delete(entry) }
                    )
                }
            } footer: {
                Text("Swipe right to edit money you added, or left to delete an entry and undo its effect on your balances.")
            }
            .warmRows()
        }
        .warmPage()
        .navigationTitle("Balance history")
        .sheet(item: $entryBeingEdited) { request in
            BalanceEntryView(isTransfer: false, balances: balances, editing: request.model)
                .warmSheet()
        }
    }

    private func title(for entry: BalanceEntry) -> String {
        if let source = entry.source {
            return "Moved from \(source.title) to \(entry.destination.title)"
        }
        if entry.isStartingBalance {
            return "Starting balance in \(entry.destination.title)"
        }
        return "Added to \(entry.destination.title)"
    }
}
