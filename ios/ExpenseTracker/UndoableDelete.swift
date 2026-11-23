import SwiftData
import SwiftUI

/// Deletes an expense or a balance entry and offers to put it back for a few seconds. The offer
/// rebuilds the deleted item from its backup record, rather than going through an `UndoManager`,
/// which would undo whatever changed last.
struct UndoableDelete {
    /// Set by `ContentView`, which shows the offer with `undoBanner`.
    var offer: (UndoOffer) -> Void = { _ in }

    func callAsFunction(_ expense: Expense) {
        let record = Backup.ExpenseRecord(expense)
        delete(expense, message: "Expense deleted", restore: record.makeExpense)
    }

    func callAsFunction(_ entry: BalanceEntry) {
        let record = Backup.BalanceEntryRecord(entry)
        let message = if entry.source != nil {
            "Transfer deleted"
        } else if entry.isStartingBalance {
            "Starting balance deleted"
        } else {
            "Income deleted"
        }
        delete(entry, message: message, restore: record.makeEntry)
    }

    /// A delete that can't be saved is rolled back, so the row comes back on its own.
    private func delete<Model: PersistentModel>(_ model: Model, message: String, restore: @escaping () -> Model?) {
        guard let context = model.modelContext else { return }
        context.delete(model)
        guard (try? context.saveNow()) != nil else { return }
        offer(UndoOffer(message: message) {
            guard let restored = restore() else { return }
            context.insert(restored)
            try? context.saveNow()
        })
    }
}

struct UndoOffer: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let undo: () -> Void

    static func == (lhs: UndoOffer, rhs: UndoOffer) -> Bool {
        lhs.id == rhs.id
    }
}

extension EnvironmentValues {
    @Entry var undoableDelete = UndoableDelete()
}

extension View {
    /// Shows the latest delete's undo offer along the bottom of a tab, above the tab bar.
    func undoBanner(_ offer: Binding<UndoOffer?>) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            UndoBanner(offer: offer)
        }
    }
}

private struct UndoBanner: View {
    private static let duration = Duration.seconds(6)

    @Binding var offer: UndoOffer?

    var body: some View {
        if let current = offer {
            HStack {
                Text(current.message)
                    .font(.subheadline)
                Spacer()
                Button("Undo") {
                    current.undo()
                    offer = nil
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.brand)
                .frame(minHeight: 44)
            }
            .padding(.horizontal, 18)
            .background(Color.card, in: Capsule())
            .overlay { Capsule().strokeBorder(Color.hairline) }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: current.id) {
                AccessibilityNotification.Announcement(current.message).post()
                // A newer offer cancels this wait, and must not be cleared by it.
                guard (try? await Task.sleep(for: Self.duration)) != nil else { return }
                withAnimation { offer = nil }
            }
        }
    }
}
