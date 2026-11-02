import SwiftData
import SwiftUI

private enum AppTab {
    case overview, transactions, activity, spending
}

struct ContentView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]
    @Query private var balanceEntries: [BalanceEntry]
    @State private var tab = AppTab.overview
    @State private var isAddingExpense = false
    @State private var expenseBeingEdited: EditRequest<Expense>?
    @State private var incomeBeingEdited: EditRequest<BalanceEntry>?
    @State private var period = Period.month(containing: .now)

    var body: some View {
        let balances = Balances(entries: balanceEntries, expenses: expenses)
        let categoriesByName = categories.byName
        let addExpense = { isAddingExpense = true }
        let editExpense = { (expense: Expense) in expenseBeingEdited = EditRequest(expense) }

        TabView(selection: $tab) {
            OverviewView(
                expenses: expenses,
                categoriesByName: categoriesByName,
                balances: balances,
                addExpense: addExpense,
                editExpense: editExpense,
                showSpending: { tab = .spending },
                showActivity: { tab = .activity }
            )
            .tabItem { Label("Overview", systemImage: "house") }
            .tag(AppTab.overview)

            TransactionsView(
                entries: balanceEntries,
                expenses: expenses,
                categoriesByName: categoriesByName,
                period: $period,
                addExpense: addExpense,
                editExpense: editExpense,
                editIncome: { incomeBeingEdited = EditRequest($0) }
            )
            .tabItem { Label("Transactions", systemImage: "arrow.up.arrow.down") }
            .tag(AppTab.transactions)

            ActivityView(expenses: expenses, categoriesByName: categoriesByName, period: $period, addExpense: addExpense, editExpense: editExpense)
                .tabItem { Label("Activity", systemImage: "list.bullet") }
                .tag(AppTab.activity)

            SpendingView(expenses: expenses, categoriesByName: categoriesByName, period: $period, addExpense: addExpense)
                .tabItem { Label("Spending", systemImage: "chart.bar") }
                .tag(AppTab.spending)
        }
        .tint(.brand)
        .foregroundStyle(Color.ink)
        .sheet(isPresented: $isAddingExpense) {
            ExpenseFormView(balances: balances)
                .warmSheet()
        }
        .sheet(item: $expenseBeingEdited) { request in
            ExpenseFormView(balances: balances, editing: request.model)
                .warmSheet()
        }
        .sheet(item: $incomeBeingEdited) { request in
            BalanceEntryView(isTransfer: false, balances: balances, editing: request.model)
                .warmSheet()
        }
        .task(id: WidgetSnapshot(balances)) {
            WidgetSnapshot(balances).publish()
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

private struct OverviewView: View {
    private static let recentCount = 5

    @Environment(\.modelContext) private var modelContext
    @State private var isManagingCategories = false
    @State private var isAddingMoney = false
    @State private var isMovingMoney = false
    @State private var isShowingHistory = false

    let expenses: [Expense]
    let categoriesByName: [String: ExpenseCategory]
    let balances: Balances
    let addExpense: () -> Void
    let editExpense: (Expense) -> Void
    let showSpending: () -> Void
    let showActivity: () -> Void

    var body: some View {
        let month = Period.month(containing: .now)
        let monthExpenses = expenses.within(from: month.from, to: month.to)
        let recent = Array(expenses.prefix(Self.recentCount))

        NavigationStack {
            List {
                Section {
                    Text(greeting)
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section {
                    MainBalanceCard(
                        balance: balances[.main],
                        addMoney: { isAddingMoney = true },
                        moveMoney: { isMovingMoney = true }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    HStack(spacing: 12) {
                        AccountTile(account: .savings, systemImage: "building.columns.fill", tint: .positive, caption: "Set aside", value: balances[.savings])
                        AccountTile(account: .cash, systemImage: "banknote.fill", tint: .coinDark, caption: "On hand", value: balances[.cash])
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    MonthSummary(
                        total: monthExpenses.total,
                        totals: monthExpenses.categoryTotals,
                        categoriesByName: categoriesByName,
                        showSpending: showSpending
                    )
                }
                .warmRows()

                Section {
                    if expenses.isEmpty {
                        Text("No expenses yet. Tap + to add one.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(recent) { expense in
                        ExpenseRow(expense: expense, category: categoriesByName[expense.categoryName])
                            .editDeleteSwipeActions(
                                edit: { editExpense(expense) },
                                delete: { modelContext.delete(expense) }
                            )
                    }
                } header: {
                    HStack {
                        Text("Recent")
                            .font(.system(.subheadline, design: .serif, weight: .semibold))
                            .textCase(nil)
                        Spacer()
                        if expenses.count > Self.recentCount {
                            Button("See all", action: showActivity)
                                .font(.subheadline.weight(.medium))
                                .textCase(nil)
                        }
                    }
                }
                .warmRows()
            }
            .warmPage()
            .listSectionSpacing(.compact)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $isShowingHistory) {
                BalanceHistoryView(balances: balances)
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Categories", systemImage: "tag") {
                        isManagingCategories = true
                    }
                    Button("Balance history", systemImage: "clock.arrow.circlepath") {
                        isShowingHistory = true
                    }
                }
            }
            .addExpenseButton(action: addExpense)
            .sheet(isPresented: $isManagingCategories) {
                CategoriesView()
                    .warmSheet()
            }
            .sheet(isPresented: $isAddingMoney) {
                BalanceEntryView(isTransfer: false, balances: balances)
                    .warmSheet()
            }
            .sheet(isPresented: $isMovingMoney) {
                BalanceEntryView(isTransfer: true, balances: balances)
                    .warmSheet()
            }
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }
}

private struct MainBalanceCard: View {
    let balance: Decimal
    let addMoney: () -> Void
    let moveMoney: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if balance < 0 {
                    Label("Main balance overdrawn", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.heroNegative)
                } else {
                    Text("Main balance")
                        .font(.subheadline.weight(.medium))
                        .opacity(0.85)
                }
                Text(balance.euros)
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(balance < 0 ? Color.heroNegative : Color.heroText)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.default, value: balance)
            }
                Spacer(minLength: 0)
                HearthMark()
                    .frame(height: 72)
            }
            HStack(spacing: 10) {
                CardButton(title: "Add money", systemImage: "plus", action: addMoney)
                CardButton(title: "Move money", systemImage: "arrow.left.arrow.right", action: moveMoney)
            }
        }
        .foregroundStyle(Color.heroText)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient(colors: [.heroTop, .heroBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.coinLight.opacity(0.18))
        }
    }
}

private struct CardButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.heroText.opacity(0.16), in: Capsule())
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private struct AccountTile: View {
    let account: BalanceAccount
    let systemImage: String
    let tint: Color
    let caption: String
    let value: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.15), in: Circle())
                    .accessibilityHidden(true)
                Text(account.title)
                    .font(.subheadline.weight(.medium))
            }
            Text(value.euros)
                .font(.system(.title2, design: .serif, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(value < 0 ? Color.negative : Color.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(value < 0 ? "Overdrawn" : caption)
                .font(.caption)
                .foregroundStyle(value < 0 ? Color.negative : .secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.heroBottom.opacity(0.08), radius: 8, y: 3)
    }
}

private struct MonthSummary: View {
    let total: Decimal
    let totals: [CategoryTotal]
    let categoriesByName: [String: ExpenseCategory]
    let showSpending: () -> Void

    var body: some View {
        Button(action: showSpending) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Spent this month")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                Text(total.euros)
                    .font(.system(.title, design: .serif, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if !totals.isEmpty {
                    CategoryShareBar(totals: totals, categoriesByName: categoriesByName)
                }
                Text("across \(totals.count) \(totals.count == 1 ? "category" : "categories")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityHint("Shows spending by category")
    }
}
