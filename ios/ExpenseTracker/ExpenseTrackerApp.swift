import SwiftData
import SwiftUI

@main
struct ExpenseTrackerApp: App {
    private let container: ModelContainer

    init() {
        WarmAppearance.apply()
        let inMemory = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        do {
            container = try .forApp(ModelConfiguration(isStoredInMemoryOnly: inMemory))
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

extension ModelContainer {
    static func forApp(_ configuration: ModelConfiguration) throws -> ModelContainer {
        let container = try ModelContainer(for: Expense.self, ExpenseCategory.self, BalanceEntry.self, configurations: configuration)
        try ExpenseCategory.seedDefaultsIfNeeded(in: ModelContext(container))
        return container
    }
}
