import SwiftData
import SwiftUI

@main
struct ExpenseTrackerApp: App {
    private let container: ModelContainer

    init() {
        LedgerAppearance.apply()
        let inMemory = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        if inMemory {
            // Tests start as just backed up, so the reminder only shows in the test that asks for it.
            if ProcessInfo.processInfo.arguments.contains("-neverBackedUp") {
                UserDefaults.standard.removeObject(forKey: BackupReminder.key)
            } else {
                BackupReminder.recordBackup()
            }
        }
        do {
            container = try .forApp(inMemory ? ModelConfiguration(isStoredInMemoryOnly: true) : .liveStore)
        } catch {
            fatalError("Could not open the expense store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}

extension ModelConfiguration {
    /// The user's data, in the App Group container. It's named here because SwiftData's default only
    /// lands there while this is the first App Group in the entitlements, and anywhere else would open
    /// an old, out-of-date copy of the store.
    static var liveStore: ModelConfiguration {
        ModelConfiguration(groupContainer: .identifier(WidgetSnapshot.appGroup))
    }
}

extension ModelContext {
    /// Writes changes straight away rather than waiting for autosave, so they survive the app being
    /// closed right after. When saving fails the unsaved changes are rolled back, so trying again
    /// can't add the same thing twice.
    func saveNow() throws {
        guard hasChanges else { return }
        do {
            try save()
        } catch {
            rollback()
            throw error
        }
    }

    /// `saveNow` for forms, which show why it failed with `errorAlert`. Nil once saved.
    func saveNowFailure() -> String? {
        do {
            try saveNow()
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}

extension ModelContainer {
    static func forApp(_ configuration: ModelConfiguration) throws -> ModelContainer {
        let container = try ModelContainer(for: Expense.self, ExpenseCategory.self, BalanceEntry.self, Budget.self, RecurringExpense.self, configurations: configuration)
        try ExpenseCategory.seedDefaultsIfNeeded(in: ModelContext(container))
        return container
    }
}
