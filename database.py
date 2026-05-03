import sqlite3

DB_PATH = "expenses.db"

def get_connection():
    """Open and return a connection to the database."""
    conn = sqlite3.connect(DB_PATH)
    # This make rows behave like dictionaries so you can do row["amount"] instead of row[0]
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    """Create the expenses table if it doesn't exist yet"""
    conn = get_connection()
    conn.execute("""
                 CREATE TABLE IF NOT EXISTS expenses(
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    amount REAL NOT NULL,
                    category TEXT NOT NULL,
                    note TEXT,
                    date TEXT NOT NULL
                 )
                 """)
    
    conn.commit()
    conn.close()
    print("Database ready.")

#run this file directly to test: python3 database.py
if __name__ == "__main__":
    init_db()

    conn = get_connection()
    conn.execute(
        "INSERT INTO expenses (amount, category, note, date) VALUES (?, ?, ?, ?)",
        (12.50, "Food", "Lunch at the canteen", "2026-05-03")
    )
    conn.commit()

    # Read it back
    rows = conn.execute("SELECT * FROM expenses").fetchall()
    for row in rows:
        print(f" id={row['id']} amount={row['amount']} category={row['category']} note={row['note']} date={row['date']}")
    conn.close()