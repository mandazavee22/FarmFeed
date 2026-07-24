from app import create_app
from database.db import db
from database.models import ProcurementRequest, FeedIngredient, LivestockRecord, User
from sqlalchemy import text

app = create_app()
with app.app_context():
    print("--- Starting Category Repair ---")
    
    # 1. Repair Procurement Requests
    reqs = ProcurementRequest.query.filter(
        (ProcurementRequest.livestock_category == None) | 
        (ProcurementRequest.livestock_category == '')
    ).all()
    
    print(f"Found {len(reqs)} requests to repair.")
    for r in reqs:
        # Try to find breed in notes first
        notes = (r.farmer_notes or "").lower()
        new_cat = None
        
        if "cattle (beef)" in notes: new_cat = "Cattle (Beef)"
        elif "cattle (dairy)" in notes: new_cat = "Cattle (Dairy)"
        elif "poultry (layers)" in notes: new_cat = "Poultry (Layers)"
        elif "poultry (broilers)" in notes: new_cat = "Poultry (Broilers)"
        elif "goats" in notes: new_cat = "Goats"
        elif "pigs" in notes: new_cat = "Pigs"
        
        # Fallback: Use farmer's first livestock record
        if not new_cat and r.farmer and r.farmer.livestock_records:
            record = r.farmer.livestock_records[0]
            new_cat = record.animal_type
            
        if new_cat:
            r.livestock_category = new_cat
            print(f"  Fixed REQ {r.id}: Set to {new_cat}")
        else:
            # Final fallback to "Cattle (Beef)" if nothing else found, to make it biddable
            r.livestock_category = "Cattle (Beef)"
            print(f"  Fixed REQ {r.id}: Defaulted to Cattle (Beef)")

    # 2. Repair Supplier Ingredients
    ings = FeedIngredient.query.filter(
        (FeedIngredient.target_livestock_type == None) | 
        (FeedIngredient.target_livestock_type == '')
    ).all()
    
    print(f"\nFound {len(ings)} ingredients to repair.")
    for i in ings:
        # If it's maize meal or generic, default to one of the active breed types
        # This is a guestimate for existing data
        i.target_livestock_type = "Cattle (Beef)"
        print(f"  Fixed ING {i.id}: Defaulted to Cattle (Beef)")

    db.session.commit()
    print("\n✅ Category Repair Complete.")
