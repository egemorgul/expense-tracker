# expense-tracker

A personal expense tracker for iPhone, with balances for separate accounts, a daily budget, and spending broken down by category. It's a native SwiftUI and SwiftData app that keeps all its data on the device, with no account or server.

Amounts are in euros, and the currency isn't configurable yet.

## Features

- **Home:** your balances, today's budget, what you've spent this month, and your five most recent expenses
- **Accounts:** separate Main, Savings and Cash balances, with money added to or moved between them
- **Balance history:** every addition and transfer, where deleting an entry undoes its effect
- **Budget:** a monthly or custom-dates budget, split into a daily allowance each midnight
- **Activity:** income and expenses by day, for any month or custom date range, filtered to All, Spent or Income
- **Search:** find any expense or income by note, category, account or amount, across all time
- **Recurring expenses:** turn on Repeat monthly when adding an expense, for rent or a subscription. Missed months are added the next time the app opens
- **Insights:** totals and shares by category, the last six months' spending, and how much is left of each category's monthly budget
- **Categories:** seven defaults, plus your own, each with a line icon and an optional monthly budget
- **Editing:** swipe right on an expense or on money you added to change it, or left to delete it, with a few seconds to undo
- **Starting balance:** mark money you already had, so it counts towards your balance but not as income
- **Backup and restore:** save everything to a JSON file in Files, and restore from one. Home reminds you when it's been a week
- **Widgets:** your balances, today's budget, and a quick way to add an expense, on the home screen or lock screen
- **Flexible amounts:** `12.50` and `12,50` both work, whatever the device's region

An expense can take an account below zero, and the app warns you when it will. A transfer can't move more than the source account holds.

## Backups

The iPhone holds the only copy of your data, so back it up from the Backup menu on Home and keep the file somewhere else, like iCloud Drive.

Restoring replaces everything in the app with the backup. Before it does, the app saves what it had to Files › On My iPhone › Expenses, as a file named "Before restore" with the date and time, so a restore can itself be undone.

## Limitations

- Transfers can be deleted, but not edited.
- Categories can't be renamed. A category with expenses can't be deleted, and neither can the last one.
- A recurring expense can be stopped, but not edited. Stop it and set it up again instead.
- There's no sync, so backups are made by hand.

## Requirements

- A Mac with Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- iOS 17 or later

## Build and test

`ios/project.yml` defines the project. `ExpenseTracker.xcodeproj` is generated and gitignored, so run `xcodegen generate` after cloning, adding files or changing the config.

```bash
cd ios
xcodegen generate
xcodebuild test -project ExpenseTracker.xcodeproj -scheme ExpenseTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build/DerivedData
```

On a Mac with 16 GB of memory or more, add `-parallel-testing-enabled YES -parallel-testing-worker-count 2` to run the UI test suites side by side on simulator clones, which is about a third faster.

If `xcode-select -p` points at the Command Line Tools, prefix these commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

The unit tests cover balances, budgets, recurring expenses, search, backups and restoring, and migrating every shipped version of the store. The UI tests cover the main flows, one class per area. They launch with `-uiTesting`, which uses an in-memory store.

## Install on an iPhone

To build it under your own Apple account, first change `DEVELOPMENT_TEAM` and `bundleIdPrefix` in `ios/project.yml`, then run `xcodegen generate` again.

Find your device IDs with `xcrun xctrace list devices` and `xcrun devicectl list devices`. The two commands report different IDs. Then, from `ios/`:

```bash
xcodebuild -project ExpenseTracker.xcodeproj -scheme ExpenseTracker -configuration Debug \
  -destination 'platform=iOS,id=<xctrace id>' -derivedDataPath build/DerivedData -allowProvisioningUpdates build
xcrun devicectl device install app --device <devicectl id> build/DerivedData/Build/Products/Debug-iphoneos/ExpenseTracker.app
```

With a free Apple developer account, the app stops opening after 7 days until you reinstall it.

> [!WARNING]
> Always install over the existing app. Deleting the app deletes its data, and changing the bundle ID or signing account makes iOS treat it as a separate app with empty data. Make a backup before installing a new version.

## Project structure

```
ios/
├── project.yml                    # XcodeGen project definition
├── ExpenseTracker/                # App source
│   ├── ExpenseTrackerApp.swift        # Entry point, data store setup and saving
│   ├── ContentView.swift              # Tabs and the Home screen
│   ├── ActivityView.swift             # Income and expenses by day, with search
│   ├── InsightsView.swift             # Spending by category and the six-month trend
│   ├── CategoryHistoryView.swift      # One category's expenses
│   ├── ExpenseFormView.swift          # Add or edit an expense
│   ├── BalanceViews.swift             # Add, edit or move money, balance history
│   ├── BudgetViews.swift              # The budget card and form
│   ├── CategoriesView.swift           # Manage categories and their budgets
│   ├── RecurringExpensesView.swift    # The expenses that repeat each month
│   ├── Expense.swift                  # Expense and category models, and their totals
│   ├── Balance.swift                  # Balance entries and how balances are worked out
│   ├── Budget.swift                   # The budget model
│   ├── RecurringExpense.swift         # Monthly expenses and adding the ones that are due
│   ├── MoneyTransaction.swift         # Income and expenses together, and search
│   ├── Backup.swift                   # The backup file, restoring, and the reminder
│   ├── BackupFlow.swift               # Backing up and restoring from Home
│   ├── UndoableDelete.swift           # Deleting with a few seconds to undo
│   ├── Period.swift                   # Date ranges and the period picker
│   ├── WidgetPublishing.swift         # Sends balances to the widgets
│   └── Theme.swift                    # Shared components and styles
├── ExpenseTrackerWidgets/         # Balance, budget and quick-add widgets
├── Shared/                        # Accounts, the budget plan, colors and the logo, used by both targets
├── Branding/                      # App icon source and the script that draws it
├── ExpenseTrackerTests/           # Unit and migration tests
└── ExpenseTrackerUITests/         # UI flow tests, one class per area
```

## License

MIT
