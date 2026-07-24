import sqlite3
import os

db_path = os.path.join(os.getcwd(), 'farmfeed.db')
print(f"Updating database at {db_path}...")

try:
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Check if table exists
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='procurement_requests';")
    if not cursor.fetchone():
        print("Table procurement_requests not found. Skipping ALTER.")
    else:
        # We can't easily change NULLABLE in SQLite without a complex table recreation,
        # but SQLite is actually lenient with constraints unless STRICT is used.
        # However, we DO need to add the new columns.
        
        cols_to_add = [
            ("ingredient_name", "TEXT"),
            ("target_cp_pct", "REAL"),
            ("target_me_mj", "REAL")
        ]
        
        for col_name, col_type in cols_to_add:
            try:
                cursor.execute(f"ALTER TABLE procurement_requests ADD COLUMN {col_name} {col_type};")
                print(f"Added column: {col_name}")
            except sqlite3.OperationalError as e:
                # Column might already exist
                if "duplicate column name" in str(e):
                    print(f"Column {col_name} already exists.")
                else:
                    print(f"Error adding {col_name}: {e}")
                    
    conn.commit()
    conn.close()
    print("Database schema update completed.")
except Exception as e:
    print(f"Failed to update database: {e}")
