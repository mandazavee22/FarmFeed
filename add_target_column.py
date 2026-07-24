import sqlite3
import os

db_path = os.path.join(os.getcwd(), 'farmfeed.db')

def add_column():
    if not os.path.exists(db_path):
        print(f"Error: {db_path} not found.")
        return

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    try:
        print("Checking feed_ingredients table...")
        cursor.execute("PRAGMA table_info(feed_ingredients)")
        columns = [column[1] for column in cursor.fetchall()]
        
        if 'target_livestock_type' not in columns:
            print("Adding 'target_livestock_type' column to 'feed_ingredients'...")
            cursor.execute("ALTER TABLE feed_ingredients ADD COLUMN target_livestock_type TEXT")
            print("Successfully added 'target_livestock_type'.")
        else:
            print("'target_livestock_type' already exists.")

        conn.commit()
    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    add_column()
