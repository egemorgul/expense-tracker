# expense-tracker

A mobile-friendly web app to track your daily expenses. Add expenses by category, view a monthly summary, and see your spending broken down in a live doughnut chart — all stored locally in a SQLite database.

Built with Python, Flask, and Chart.js. No external services or accounts required.

## Features

- Add expenses with amount, category, note and date
- 7 categories: Food, Transport, Shopping, Health, Entertainment, Bills, Other
- Monthly total with spending breakdown by category
- Doughnut chart showing where your money goes
- Delete any expense with one click
- Mobile-friendly layout — works on phone and desktop
- Data stored locally in SQLite — no cloud, no account needed

## Requirements

- Python 3.6 or higher
- Flask

## Getting started

**1. Clone the repository**
```bash
git clone https://github.com/egemorgul/expense-tracker.git
cd expense-tracker
```

**2. Create and activate a virtual environment**
```bash
python3 -m venv venv
source venv/bin/activate
```

**3. Install dependencies**
```bash
pip install -r requirements.txt
```

**4. Run the app**
```bash
python3 app.py
```

**5. Open in your browser**
```
http://127.0.0.1:5000
```

The database is created automatically on first run — no setup needed.

## Project structure

```
expense-tracker/
├── app.py            # Flask app, routes, and template filters
├── database.py       # SQLite connection and table setup
├── templates/
│   └── index.html    # Single page UI with form, chart, and expense list
├── static/
│   └── chart.js      # Chart.js library served locally
├── requirements.txt
└── README.md
```

## How it works

The app follows a simple request-response cycle. When you open the page, Flask queries the SQLite database and passes the expenses and monthly totals to the HTML template. When you add or delete an expense, the browser sends a POST request to Flask, which updates the database and redirects back to the home page.

The doughnut chart is powered by a separate `/chart-data` endpoint that returns JSON. JavaScript fetches this on page load and renders the chart with Chart.js — keeping Python and JavaScript cleanly separated.

## License

MIT