print("Starting Migration Script...")
try:
    from app import create_app
    from database.db import db
    from sqlalchemy import text
    import traceback
    print("Imports successful.")
    
    app = create_app()
    print("App created.")
    
    with app.app_context():
        print("Got app context.")
        try:
            with db.engine.connect() as conn:
                print("Connected to engine.")
                try:
                    conn.execute(text("ALTER TABLE supplier_bids ADD COLUMN supplier_ingredient_id INTEGER REFERENCES feed_ingredients(id)"))
                    conn.commit()
                    print("Successfully added supplier_ingredient_id to supplier_bids.")
                except Exception as e:
                    print(f"SupplierBid Migration: {e}")
                
                try:
                    conn.execute(text("ALTER TABLE procurement_requests ADD COLUMN livestock_category VARCHAR(50)"))
                    conn.commit()
                    print("Successfully added livestock_category to procurement_requests.")
                except Exception as e:
                    print(f"ProcurementRequest Migration: {e}")
        except Exception as e:
            print(f"Connection error: {e}")
except Exception as global_e:
    print(f"Global Migration Error: {global_e}")
    import traceback
    traceback.print_exc()
