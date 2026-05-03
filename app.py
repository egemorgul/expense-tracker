from flask import Flask, render_template, redirect, request, url_for
from database import init_db, get_connection
import datetime
import json

app = Flask(__name__)

# Create the database table whe the app starts
with app.app_context():
    init_db()

# Jinja2 filters

CATEGORY_ICONS = {
    "Food": "🍕",
    "Transport": "🚌",
    "Shopping": "🛍",
    "Health": "💊",
    "Entertainment": "🎬",
    "Bills": "📄",
    "Other": "📦",
}

CATEGORY_COLORS = ["#1a1a1a","#555555","#888888","#aaaaaa","#4a90d9","#e8834a","#5cb85c","#d9534f"]

@app.template_filter("category_icon")
def category_icon(category):
    """Return the emoji for a category name"""
    return CATEGORY_ICONS.get(category,"📦")

@app.template_filter("category_color")
def category_color(index):
    """Return a color for a given loop index (1-based from Jinja2)"""
    return CATEGORY_COLORS[(index - 1) % len(CATEGORY_COLORS)]

# Routes

@app.route("/")
def index():
    """Home page - will show the form and all expenses."""
    conn = get_connection()

    expenses = conn.execute("SELECT * FROM expenses ORDER BY date DESC").fetchall()


    total = sum(row["amount"] for row in expenses)

    today = datetime.date.today()
    current_month = today.strftime("%Y-%m")

    monthly_expenses = conn.execute("SELECT * FROM expenses WHERE date LIKE ? ORDER BY date DESC", (current_month + "%",)).fetchall()

    monthly_total = sum(row["amount"] for row in monthly_expenses)


    category_totals = conn.execute(
        """
        SELECT category, SUM(amount) as subtotal
        FROM expenses
        WHERE date LIKE ?
        GROUP BY category
        ORDER BY subtotal DESC
        """,
        (current_month +"%",)).fetchall()
    
    conn.close()

    chart_data = {
        "labels":[row["category"] for row in category_totals],
        "values":[row["subtotal"] for row in category_totals],
    }
    return render_template("index.html", expenses = expenses, total=total,monthly_total=monthly_total,category_totals=category_totals, current_month=today.strftime("%B %Y"), chart_data=json.dumps(chart_data))

@app.route("/add", methods=["POST"])
def add_expense():
    amount = request.form.get("amount")
    category = request.form.get("category")
    note = request.form.get("note")
    date = request.form.get("date")

    if not amount or not category:
        return redirect(url_for("index"))
    
    conn = get_connection()
    conn.execute(
        "INSERT INTO expenses (amount, category, note, date) VALUES (?, ?, ?, ?)",
        (float(amount), category, note, date)
        )
    conn.commit()
    conn.close()

    return redirect(url_for("index"))

@app.route("/delete/<int:expense_id>", methods=["POST"])
def delete_expense(expense_id):
    """Delete a single expense by its id"""
    conn = get_connection()
    conn.execute("DELETE FROM expenses WHERE id = ?",(expense_id,))
    conn.commit()
    conn.close()
    return redirect(url_for("index"))

@app.route("/chart-data")
def chart_data():
    today = datetime.date.today()
    current_month = today.strftime("%Y-%m")

    conn = get_connection()
    rows = conn.execute(
        """
        SELECT category, SUM(amount) as subtotal
        FROM expenses
        WHERE date LIKE ?
        GROUP BY category
        ORDER BY subtotal DESC
        """,
        (current_month + "%",)
    ).fetchall()
    conn.close()

    data= {
        "labels": [row["category"] for row in rows],
        "values": [row["subtotal"] for row in rows]
    }
    return json.dumps(data)


if __name__ == "__main__":
    app.run(debug=True)