import sqlite3
import os

# Path to your database
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
DB_PATH = os.path.join(BASE_DIR, 'farmfeed.db')

def migrate():
    if not os.path.exists(DB_PATH):
        print(f"Database not found at {DB_PATH}")
        return

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    try:
        print("Starting migration to allow NULL values for location fields...")

        # 1. Check current structure
        cursor.execute("PRAGMA table_info(users)")
        columns = cursor.fetchall()
        
        # 2. Create a temporary table with the new schema (nullable location fields)
        # Note: In the original schema, province, city, street_address were NOT NULL.
        # We want them to be nullable.
        
        cursor.execute("""
            CREATE TABLE users_new (
                id INTEGER PRIMARY KEY,
                first_name VARCHAR(100) NOT NULL,
                last_name VARCHAR(100) NOT NULL,
                email VARCHAR(200) NOT NULL UNIQUE,
                phone VARCHAR(25) NOT NULL,
                password_hash VARCHAR(512) NOT NULL,
                role VARCHAR(20) NOT NULL,
                province VARCHAR(100),
                city VARCHAR(100),
                street_address VARCHAR(300),
                location_description VARCHAR(500),
                profile_photo_url VARCHAR(500),
                is_active BOOLEAN,
                created_at DATETIME,
                updated_at DATETIME
            )
        """)

        # 3. Copy data from old table to new table
        cursor.execute("""
            INSERT INTO users_new (
                id, first_name, last_name, email, phone, password_hash, role, 
                province, city, street_address, location_description, 
                profile_photo_url, is_active, created_at, updated_at
            )
            SELECT 
                id, first_name, last_name, email, phone, password_hash, role, 
                province, city, street_address, location_description, 
                profile_photo_url, is_active, created_at, updated_at
            FROM users
        """)

        # 4. Drop old table
        cursor.execute("DROP TABLE users")

        # 5. Rename new table to original name
        cursor.execute("ALTER TABLE users_new RENAME TO users")

        # 6. Recreate index on email
        cursor.execute("CREATE UNIQUE INDEX ix_users_email ON users (email)")

        conn.commit()
        print("✅ Migration successful! Location fields are now optional.")

    except Exception as e:
        conn.rollback()
        print(f"❌ Migration failed: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    migrate()
