import sqlite3
import os

db_path = os.path.join(os.getcwd(), 'farmfeed.db')
print(f"Performing Deep Migration at {db_path}...")

try:
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Check if we need to migrate
    cursor.execute("PRAGMA table_info(procurement_requests);")
    columns = [col[1] for col in cursor.fetchall()]
    
    if 'ingredient_name' in columns:
        print("Schema already has ingredient_name. Checking constraints...")
    
    # SQLite requires table recreation to change NOT NULL to NULL
    print("Recreating procurement_requests table to support Public Bidding...")
    
    # 1. Rename old table
    cursor.execute("ALTER TABLE procurement_requests RENAME TO procurement_requests_old;")
    
    # 2. Create new table with the correct schema (Matches models.py accurately)
    cursor.execute("""
    CREATE TABLE procurement_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        farmer_id INTEGER NOT NULL,
        supplier_profile_id INTEGER,
        ingredient_id INTEGER,
        ingredient_name TEXT,
        quantity_kg REAL NOT NULL,
        estimated_cost_usd REAL,
        target_cp_pct REAL,
        target_me_mj REAL,
        status TEXT DEFAULT 'pending',
        farmer_notes TEXT,
        supplier_notes TEXT,
        requested_at DATETIME,
        updated_at DATETIME,
        FOREIGN KEY(farmer_id) REFERENCES users(id),
        FOREIGN KEY(supplier_profile_id) REFERENCES supplier_profiles(id),
        FOREIGN KEY(ingredient_id) REFERENCES feed_ingredients(id)
    );
    """)
    
    # 3. Copy data if any (mapping old columns to new ones)
    # Note: Using COALESCE or just selecting columns that existed.
    # If the previous partial migration failed, some columns might not exist in _old.
    # We'll use a safer intersection.
    cursor.execute("PRAGMA table_info(procurement_requests_old);")
    old_columns = [col[1] for col in cursor.fetchall()]
    
    common_cols = [c for c in old_columns if c in ['id', 'farmer_id', 'supplier_profile_id', 'ingredient_id', 'quantity_kg', 'estimated_cost_usd', 'status', 'farmer_notes', 'supplier_notes', 'requested_at', 'updated_at']]
    col_str = ", ".join(common_cols)
    
    cursor.execute(f"INSERT INTO procurement_requests ({col_str}) SELECT {col_str} FROM procurement_requests_old;")
    print(f"Restored {cursor.rowcount} records from backup.")
    
    # 4. Drop old table
    cursor.execute("DROP TABLE procurement_requests_old;")
    
    conn.commit()
    conn.close()
    print("✅ Deep Migration Successful. Public Bidding is now enabled at the database level.")

except Exception as e:
    print(f"❌ Migration Failed: {e}")
    # Try to rollback if possible
    try: conn.rollback()
    except: pass
