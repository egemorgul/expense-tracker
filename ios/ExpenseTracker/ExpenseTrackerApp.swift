import SwiftData
import SwiftUI

@main
struct ExpenseTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Expense.self, inMemory: ProcessInfo.processInfo.arguments.contains("-uiTesting"))
    }
}
