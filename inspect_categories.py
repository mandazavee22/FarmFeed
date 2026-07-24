from app import create_app
from database.db import db
from database.models import ProcurementRequest, FeedIngredient, LivestockRecord

app = create_app()
with app.app_context():
    reqs = ProcurementRequest.query.all()
    ings = FeedIngredient.query.all()
    lrs = LivestockRecord.query.all()
    
    print(f"--- Livestock Records (Total: {len(lrs)}) ---")
    for r in lrs:
        print(f"ID: {r.id} | Type: [{r.animal_type}] | Stage: [{r.production_stage}]")

    print(f"\n--- Marketplace Requests (Total: {len(reqs)}) ---")
    for r in reqs:
        print(f"ID: {r.id} | Name: {r.ingredient_name} | Category: [{r.livestock_category}] | Notes: {r.farmer_notes[:30]}")
    
    print(f"\n--- Supplier Inventory (Total: {len(ings)}) ---")
    for i in ings:
        print(f"ID: {i.id} | Name: {i.name} | Target: [{i.target_livestock_type}]")
