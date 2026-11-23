import SwiftData
import SwiftUI

private enum AppTab {
    case home, activity, insights
}

struct ContentView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]
    @Query private var balanceEntries: [BalanceEntry]
    /// There's at most one, sorted so that `first` would always pick the same one regardless.
    @Query(sort: \Budget.startDate) private var budgets: [Budget]
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    /// Moves on when the day changes, so the budget gets each new day's figure.
    @State private var now = Date.now
    @State private var tab = AppTab.home
    @State private var isAddingExpense = false
    @State private var expenseBeingEdited: EditRequest<Expense>?
    @State private var incomeBeingEdited: EditRequest<BalanceEntry>?
    /// Shared by Activity and Insights, so both look at the same days.
    @State private var period = Period.month(containing: .now)
    @State private var undoOffer: UndoOffer?

    var body: some View {
        let balances = Balances(entries: balanceEntries, expenses: expenses)
        let categoriesByName = categories.byName
        let addExpense = { isAddingExpense = true }
        let editExpense = { (expense: Expense) in expenseBeingEdited = EditRequest(expense) }
        let budget = budgets.first
        let budgetSnapshot = BudgetSnapshot(plan: budget?.plan, expenses: expenses, at: now)

        TabView(selection: $tab) {
            HomeView(
                expenses: expenses,
                categoriesByName: categoriesByName,
                balances: balances,
                today: now,
                budget: budget,
                budgetStatus: budgetSnapshot.status(at: now),
                addExpense: addExpense,
                editExpense: editExpense,
                showInsights: { tab = .insights },
                showActivity: { tab = .activity }
            )
            .undoBanner($undoOffer)
            .tabItem { Label("Home", systemImage: "house") }
            .tag(AppTab.home)

            ActivityView(
                entries: balanceEntries,
                expenses: expenses,
                categoriesByName: categoriesByName,
                period: $period,
                addExpense: addExpense,
                editExpense: editExpense,
                editIncome: { incomeBeingEdited = EditRequest($0) }
            )
            .undoBanner($undoOffer)
            .tabItem { Label("Activity", systemImage: "list.bullet") }
            .tag(AppTab.activity)

            InsightsView(expenses: expenses, categoriesByName: categoriesByName, period: $period, addExpense: addExpense, editExpense: editExpense)
                .undoBanner($undoOffer)
                .tabItem { Label("Insights", systemImage: "chart.pie") }
                .tag(AppTab.insights)
        }
        .tint(.brand)
        .foregroundStyle(Color.ink)
        .animation(.default, value: undoOffer)
        .environment(\.undoableDelete, UndoableDelete { undoOffer = $0 })
        .sheet(isPresented: $isAddingExpense) {
            ExpenseFormView(balances: balances)
                .ledgerSheet()
        }
        .sheet(item: $expenseBeingEdited) { request in
            ExpenseFormView(balances: balances, editing: request.model)
                .ledgerSheet()
        }
        .sheet(item: $incomeBeingEdited) { request in
            BalanceEntryView(isTransfer: false, balances: balances, editing: request.model)
                .ledgerSheet()
        }
        .task(id: WidgetSnapshot(balances)) {
            WidgetSnapshot(balances).publish()
        }
        .task(id: budgetSnapshot) {
            budgetSnapshot.publish()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            now = .now
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = .now }
        }
        .task(id: now) {
            // Fails only when the store can't be written, and then the next day or launch tries again.
            try? RecurringExpense.addDueExpenses(in: modelContext, at: now)
        }
        .onChange(of: now) { previous, current in
            period = period.following(from: previous, to: current)
        }
        .onOpenURL { url in
            // Asking for a second sheet over an open one fails, and would leave this flag stuck on.
            if url == WidgetLink.addExpense, !UIApplication.shared.isPresentingSheet {
                isAddingExpense = true
            }
        }
    }
}

private extension UIApplication {
    var isPresentingSheet: Bool {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .contains { $0.rootViewController?.presentedViewController != nil }
    }
}

private struct HomeView: View {
    private static let recentCount = 5

    @Environment(\.undoableDelete) private var delete
    @Environment(\.modelContext) private var modelContext
    @AppStorage(BackupReminder.key) private var lastBackupSeconds: Double = 0
    @State private var backupFlow = BackupFlow()
    @State private var isAddingMoney = false
    @State private var isMovingMoney = false
    @State private var isShowingHistory = false
    @State private var isEditingBudget = false

    let expenses: [Expense]
    let categoriesByName: [String: ExpenseCategory]
    let balances: Balances
    let today: Date
    let budget: Budget?
    /// Nil when there's no budget.
    let budgetStatus: BudgetStatus?
    let addExpense: () -> Void
    let editExpense: (Expense) -> Void
    let showInsights: () -> Void
    let showActivity: () -> Void

    var body: some View {
        let month = Period.month(containing: today)
        let monthExpenses = expenses.within(from: month.from, to: month.to)
        let recent = Array(expenses.prefix(Self.recentCount))
        let lastBackup = lastBackupSeconds > 0 ? Date(timeIntervalSince1970: lastBackupSeconds) : nil
        let hasData = !expenses.isEmpty || balances[.main] != 0 || balances[.savings] != 0 || balances[.cash] != 0

        NavigationStack {
            List {
                Section {
                    Text(today.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.largeTitle.bold())
                        .bareRow()
                }

                Section {
                    MainBalanceCard(
                        balance: balances[.main],
                        showHistory: { isShowingHistory = true },
                        addMoney: { isAddingMoney = true },
                        moveMoney: { isMovingMoney = true }
                    )
                    .bareRow()

                    HStack(spacing: 12) {
                        AccountTile(account: .savings, caption: "Set aside", value: balances[.savings])
                        AccountTile(account: .cash, caption: "On hand", value: balances[.cash])
                    }
                    .bareRow()
                    .padding(.top, 12)
                }

                if BackupReminder.isDue(lastBackup: lastBackup, hasData: hasData, at: today) {
                    Section {
                        BackupReminderCard(lastBackup: lastBackup) {
                            backupFlow.backUp(from: modelContext)
                        }
                    }
                    .ledgerRows()
                }

                Section {
                    if let budgetStatus {
                        BudgetCard(status: budgetStatus) { isEditingBudget = true }
                    } else {
                        Button {
                            isEditingBudget = true
                        } label: {
                            Label("Set a budget", systemImage: "calendar.badge.plus")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color.brand)
                        }
                    }
                }
                .ledgerRows()

                Section {
                    MonthSummary(
                        total: monthExpenses.total,
                        totals: monthExpenses.categoryTotals,
                        categoriesByName: categoriesByName,
                        showInsights: showInsights
                    )
                }
                .ledgerRows()

                Section {
                    if expenses.isEmpty {
                        Text("No expenses yet. Tap + to add one.")
                            .foregroundStyle(Color.inkSecondary)
                    }
                    ForEach(recent) { expense in
                        ExpenseRow(expense: expense, category: categoriesByName[expense.categoryName])
                            .editDeleteSwipeActions(
                                edit: { editExpense(expense) },
                                delete: { delete(expense) }
                            )
                    }
                } header: {
                    HStack {
                        Text("Recent")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.ink)
                        Spacer()
                        if expenses.count > Self.recentCount {
                            Button("See all", action: showActivity)
                                .font(.subheadline.weight(.medium))
                        }
                    }
                    .textCase(nil)
                }
                .ledgerRows()
            }
            .ledgerPage()
            .listSectionSpacing(16)
            // An empty, solid bar rather than a hidden one, so the page scrolls under the paper and not
            // under the status bar. A large title would hold the date, but iOS 26 doesn't draw it here.
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Backup", systemImage: "externaldrive") {
                        Button("Back up", systemImage: "square.and.arrow.up") {
                            backupFlow.backUp(from: modelContext)
                        }
                        Button("Restore from backup", systemImage: "arrow.counterclockwise") {
                            backupFlow.isImporting = true
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $isShowingHistory) {
                BalanceHistoryView(balances: balances)
            }
            .addExpenseButton(action: addExpense)
            .backupFlow(backupFlow)
            .sheet(isPresented: $isAddingMoney) {
                BalanceEntryView(isTransfer: false, balances: balances)
                    .ledgerSheet()
            }
            .sheet(isPresented: $isMovingMoney) {
                BalanceEntryView(isTransfer: true, balances: balances)
                    .ledgerSheet()
            }
            .sheet(isPresented: $isEditingBudget) {
                BudgetFormView(editing: budget)
                    .ledgerSheet()
            }
        }
    }
}

private struct MainBalanceCard: View {
    let balance: Decimal
    let showHistory: () -> Void
    let addMoney: () -> Void
    let moveMoney: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if balance < 0 {
                        Label("Main balance overdrawn", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.negative)
                    } else {
                        Caption("Main balance")
                    }
                    Spacer()
                    Button(action: showHistory) {
                        HStack(spacing: 2) {
                            Text("History")
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                        }
                        .font(.subheadline.weight(.medium))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())
                    .foregroundStyle(Color.brand)
                    .accessibilityLabel("Balance history")
                }
                .frame(height: 24)
                Text(balance.euros)
                    .font(.system(.largeTitle, weight: .bold).monospacedDigit())
                    .foregroundStyle(balance < 0 ? Color.negative : Color.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.default, value: balance)
            }
            HStack(spacing: 10) {
                CardButton(title: "Add money", systemImage: "plus", action: addMoney)
                CardButton(title: "Move money", systemImage: "arrow.left.arrow.right", action: moveMoney)
            }
        }
        .ledgerCard(padding: 20)
    }
}

private struct CardButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.ink.opacity(0.05), in: Capsule())
            .overlay { Capsule().strokeBorder(Color.hairline) }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private struct AccountTile: View {
    let account: BalanceAccount
    let caption: String
    let value: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Caption(account.title)
            Text(value.euros)
                .font(.money(.title3, prominent: true))
                .foregroundStyle(value < 0 ? Color.negative : Color.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(value < 0 ? "Overdrawn" : caption)
                .font(.caption)
                .foregroundStyle(value < 0 ? Color.negative : Color.inkSecondary)
        }
        .ledgerCard()
    }
}

private struct MonthSummary: View {
    let total: Decimal
    let totals: [CategoryTotal]
    let categoriesByName: [String: ExpenseCategory]
    let showInsights: () -> Void

    var body: some View {
        Button(action: showInsights) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Caption("Spent this month")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(Color.inkSecondary)
                        .accessibilityHidden(true)
                }
                Text(total.euros)
                    .font(.money(.title, prominent: true))
                    .foregroundStyle(Color.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if !totals.isEmpty {
                    CategoryShareBar(totals: totals, categoriesByName: categoriesByName)
                }
                Text("across \(totals.count) \(totals.count == 1 ? "category" : "categories")")
                    .font(.caption)
                    .foregroundStyle(Color.inkSecondary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityHint("Shows spending by category")
    }
}
