# expense-tracker

A personal expense tracker for iPhone, with balances for separate accounts and spending broken down by category. It's a native SwiftUI and SwiftData app that keeps all its data on the device, with no account or server.

The repo also holds the original Flask web app, which stays until the iPhone app fully replaces it. The two are independent and don't share data.

| | iPhone app | Web app |
| --- | --- | --- |
| **Location** | `ios/` | Repo root |
| **Built with** | SwiftUI, SwiftData, Swift Charts | Flask, SQLite, Chart.js |
| **Status** | In active development | Maintained until replaced |
| **Data** | On the iPhone | `expenses.db` on your computer |

Amounts are in euros in both apps, and the currency isn't configurable yet.

## iPhone app

### Features

- **Overview:** your balances, what you've spent this month, and your five most recent expenses
- **Accounts:** separate Main, Savings and Cash balances, with money added to or moved between them
- **Balance history:** every addition and transfer, where deleting an entry undoes its effect
- **Activity:** expenses grouped by day, for any month or custom date range
- **Spending:** totals and percentage shares by category for the same period
- **Categories:** seven defaults (Food, Transport, Shopping, Health, Entertainment, Bills, Other), plus your own with an emoji
- **Flexible amounts:** `12.50` and `12,50` both work, whatever the device's region

An expense can take an account below zero, and the app warns you when it will. A transfer can't move more than the source account holds.

### Limitations

- Expenses can be added and deleted, but not edited.
- Categories can't be renamed. A category with expenses can't be deleted, and neither can the last one.
- There's no sync, backup or export, so the iPhone holds the only copy of your data.

### Requirements

- A Mac with Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- iOS 17 or later

### Build and test

`ios/project.yml` defines the project. `ExpenseTracker.xcodeproj` is generated and gitignored, so run `xcodegen generate` after cloning, adding files or changing the config.

```bash
cd ios
xcodegen generate
xcodebuild test -project ExpenseTracker.xcodeproj -scheme ExpenseTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build/DerivedData
```

If `xcode-select -p` points at the Command Line Tools, prefix these commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

The test suite covers balance calculations, date periods, migrating existing stores, and the main flows through the UI. UI tests launch with `-uiTesting`, which uses an in-memory store.

### Install on an iPhone

To build it under your own Apple account, first change `DEVELOPMENT_TEAM` and `bundleIdPrefix` in `ios/project.yml`, then run `xcodegen generate` again.

Find your device IDs with `xcrun xctrace list devices` and `xcrun devicectl list devices`. The two commands report different IDs. Then, from `ios/`:

```bash
xcodebuild -project ExpenseTracker.xcodeproj -scheme ExpenseTracker -configuration Debug \
  -destination 'platform=iOS,id=<xctrace id>' -derivedDataPath build/DerivedData -allowProvisioningUpdates build
xcrun devicectl device install app --device <devicectl id> build/DerivedData/Build/Products/Debug-iphoneos/ExpenseTracker.app
```

With a free Apple developer account, the app stops opening after 7 days until you reinstall it.

> [!WARNING]
> Always install over the existing app. Deleting the app deletes its data, and changing the bundle ID or signing account makes iOS treat it as a separate app with empty data.

## Web app

A single-page app for logging expenses and seeing the current month's spending. It runs Flask's development server in debug mode and has no login, so use it on your own machine only.

### Features

- Add expenses with an amount, category, note and date
- See this month's total and a breakdown by category
- View a doughnut chart of the month's spending
- Delete any expense
- Use it on a phone or desktop browser

### Getting started

You'll need Python 3.10 or later.

```bash
git clone https://github.com/egemorgul/expense-tracker.git
cd expense-tracker
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python3 app.py
```

Then open http://127.0.0.1:5000. The database is created on first run, as `expenses.db` in the directory you start the app from.

### How it works

Flask queries SQLite and renders the page on the server. Adding or deleting an expense sends a form POST, which updates the database and redirects back to the home page. The chart loads its data separately from the `/chart-data` JSON endpoint and draws it with Chart.js.

## Project structure

```
expense-tracker/
├── ios/
│   ├── project.yml                # XcodeGen project definition
│   ├── ExpenseTracker/            # App source
│   │   ├── ExpenseTrackerApp.swift    # Entry point and data store setup
│   │   ├── ContentView.swift          # Tabs and the Overview screen
│   │   ├── ActivityView.swift         # Expenses by day
│   │   ├── SpendingView.swift         # Totals by category
│   │   ├── AddExpenseView.swift       # New expense form
│   │   ├── BalanceViews.swift         # Add or move money, balance history
│   │   ├── CategoriesView.swift       # Manage categories
│   │   ├── Expense.swift              # Expense and category models
│   │   ├── Balance.swift              # Accounts, entries and balance calculation
│   │   ├── Period.swift               # Date ranges and the period picker
│   │   └── Theme.swift                # Colors and shared components
│   ├── ExpenseTrackerTests/       # Unit and migration tests
│   └── ExpenseTrackerUITests/     # UI flow tests
├── app.py                         # Flask routes and template filters
├── database.py                    # SQLite connection and table setup
├── templates/index.html           # Web page, with inline CSS and JS
├── static/chart.js                # Vendored Chart.js
└── requirements.txt
```

## License

MIT
