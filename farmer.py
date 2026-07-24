"""
FarmFeed — Farmer Routes
========================
Handles livestock management, feed formulation requests, and production predictions.
"""

from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity

from database.db import db
from database.models import User, LivestockRecord, FeedFormulation, ProductionPrediction, FarmerIngredient, FeedIngredient, SimulationRun
from utils.helpers import (
    success_response,
    error_response,
    validate_required_fields,
)
import json
import numpy as np

farmer_bp = Blueprint("farmer", __name__, url_prefix="/api/farmer")

# ── Dashboard ──────────────────────────────────────────────────────────────────
@farmer_bp.route("/dashboard", methods=["GET"])
@jwt_required()
def get_dashboard():
    user_id = int(get_jwt_identity())
    user = User.query.get(user_id)
    if not user or user.role != "farmer":
        return error_response("Access denied. Farmer role required.", 403)

    livestock_count = user.livestock_records.count()
    formulation_count = user.feed_formulations.count()

    return success_response(data={
        "farmer": user.to_dict(),
        "stats": {
            "livestock_records": livestock_count,
            "feed_formulations": formulation_count,
            "predictions": ProductionPrediction.query.filter_by(farmer_id=user_id).count(),
            "simulations": user.simulation_runs.count() if hasattr(user, 'simulation_runs') else 0,
        },
        "recent_formulations": [f.to_dict() for f in user.feed_formulations.order_by(FeedFormulation.created_at.desc()).limit(5).all()],
    })


# ── Livestock Management ───────────────────────────────────────────────────────
VALID_LIVESTOCK = [
    'Cattle (Beef)', 'Cattle (Dairy)', 'Goats', 
    'Poultry (Layers)', 'Poultry (Broilers)', 'Pigs', 'Sheep'
]

@farmer_bp.route("/livestock", methods=["GET"])
@jwt_required()
def get_livestock():
    user_id = int(get_jwt_identity())
    user = User.query.get(user_id)
    if not user or user.role != "farmer":
        return error_response("Access denied.", 403)
    
    records = [r.to_dict() for r in user.livestock_records.order_by(LivestockRecord.created_at.desc()).all()]
    return success_response(data={"livestock": records})


@farmer_bp.route("/livestock", methods=["POST"])
@jwt_required()
def create_livestock_record():
    user_id = int(get_jwt_identity())
    data = request.get_json(silent=True) or {}
    
    required = ["animal_type", "herd_size", "average_weight_kg"]
    missing = validate_required_fields(data, required)
    if missing:
        return error_response(f"Missing fields: {', '.join(missing)}", 422)

    animal_type = data["animal_type"]
    if animal_type not in VALID_LIVESTOCK:
        return error_response(f"Invalid livestock type. Must be one of: {', '.join(VALID_LIVESTOCK)}", 422)

    try:
        herd_size = int(data["herd_size"])
        avg_weight = float(data["average_weight_kg"])
        
        # Validation logic for realistic values
        if herd_size <= 0:
            return error_response("Herd size must be greater than zero.", 422)
            
        # Basic biological constraints check
        if "Cattle" in animal_type and avg_weight > 1500:
            return error_response("Unrealistic weight for cattle (>1500kg).", 422)
        if "Poultry" in animal_type and avg_weight > 10:
            return error_response("Unrealistic weight for poultry (>10kg).", 422)

        record = LivestockRecord(
            farmer_id=user_id,
            animal_type=animal_type,
            breed_category=data.get("breed_category", "Indigenous"),
            production_stage=data.get("production_stage", "Growing"),
            herd_size=herd_size,
            average_weight_kg=avg_weight,
            age_in_months=int(data.get("age_in_months", 1)),
            feeding_frequency=int(data.get("feeding_frequency", 2)),
            notes=data.get("notes", "")
        )
        db.session.add(record)
        db.session.commit()
        
        return success_response(data={"record": record.to_dict()}, message="Livestock record added.", status_code=201)
        
    except ValueError:
        return error_response("Size and weight must be numeric.", 422)
    except Exception as e:
        db.session.rollback()
        return error_response(str(e), 500)


@farmer_bp.route("/livestock/<int:record_id>", methods=["DELETE"])
@jwt_required()
def delete_livestock_record(record_id):
    user_id = int(get_jwt_identity())
    record = LivestockRecord.query.get(record_id)
    
    if not record or record.farmer_id != user_id:
        return error_response("Record not found or access denied.", 404)
        
    db.session.delete(record)
    db.session.commit()
    return success_response(message="Record deleted successfully.")


@farmer_bp.route("/livestock/<int:record_id>", methods=["PUT"])
@jwt_required()
def update_livestock_record(record_id):
    user_id = int(get_jwt_identity())
    record = LivestockRecord.query.get(record_id)
    
    if not record or record.farmer_id != user_id:
        return error_response("Record not found or access denied.", 404)
        
    data = request.json or {}
    
    try:
        if "animal_type" in data: record.animal_type = data["animal_type"]
        if "breed_category" in data: record.breed_category = data["breed_category"]
        if "production_stage" in data: record.production_stage = data["production_stage"]
        if "herd_size" in data: record.herd_size = int(data["herd_size"])
        if "average_weight_kg" in data: record.average_weight_kg = float(data["average_weight_kg"])
        if "age_in_months" in data: record.age_in_months = int(data["age_in_months"])
        if "feeding_frequency" in data: record.feeding_frequency = int(data["feeding_frequency"])
        if "notes" in data: record.notes = data["notes"]
            
        db.session.commit()
        return success_response(data={"record": record.to_dict()}, message="Record updated successfully.")
    except ValueError:
        return error_response("Invalid numbered types given.", 422)
    except Exception as e:
        db.session.rollback()
        return error_response(str(e), 500)


# ── Farmer Ingredient Inventory ──────────────────────────────────────────────
@farmer_bp.route("/marketplace", methods=["GET"])
@jwt_required()
def get_market_ingredients():
    """Discover all ingredients listed by suppliers."""
    ingredients = FeedIngredient.query.filter_by(available=True).all()
    result = []
    for ing in ingredients:
        d = ing.to_dict()
        # Add supplier info
        d['supplier_name'] = ing.supplier.company_name
        d['source'] = 'Market'
        result.append(d)
        
    return success_response(data={"ingredients": result})


@farmer_bp.route("/inventory", methods=["GET"])
@jwt_required()
def get_inventory():
    user_id = int(get_jwt_identity())
    ingredients = FarmerIngredient.query.filter_by(farmer_id=user_id).all()
    return success_response(data={"inventory": [i.to_dict() for i in ingredients]})


@farmer_bp.route("/inventory", methods=["POST"])
@jwt_required()
def add_inventory():
    user_id = int(get_jwt_identity())
    data = request.json or {}
    
    required = ["name", "target_livestock_type", "crude_protein_pct", "metabolizable_energy", "cost_paid_usd_per_kg"]
    missing = validate_required_fields(data, required)
    if missing:
        return error_response(f"Missing: {', '.join(missing)}", 422)

    try:
        item = FarmerIngredient(
            farmer_id=user_id,
            name=data["name"],
            target_livestock_type=data["target_livestock_type"],
            crude_protein_pct=float(data["crude_protein_pct"]),
            metabolizable_energy=float(data["metabolizable_energy"]),
            crude_fibre_pct=float(data.get("crude_fibre_pct", 0)),
            cost_paid_usd_per_kg=float(data["cost_paid_usd_per_kg"]),
            stock_kg=float(data.get("stock_kg", 0)),
            notes=data.get("notes", "")
        )
        db.session.add(item)
        db.session.commit()
        return success_response(data={"item": item.to_dict()}, message="Ingredient added to your inventory.")
    except Exception as e:
        db.session.rollback()
        return error_response(str(e), 500)


@farmer_bp.route("/inventory/<int:item_id>", methods=["PUT"])
@jwt_required()
def edit_inventory(item_id):
    user_id = int(get_jwt_identity())
    item = FarmerIngredient.query.get(item_id)
    if not item or item.farmer_id != user_id:
        return error_response("Item not found.", 404)
        
    data = request.json or {}
    
    if "name" in data: item.name = data["name"]
    if "target_livestock_type" in data: item.target_livestock_type = data["target_livestock_type"]
    if "crude_protein_pct" in data: item.crude_protein_pct = float(data["crude_protein_pct"])
    if "metabolizable_energy" in data: item.metabolizable_energy = float(data["metabolizable_energy"])
    if "crude_fibre_pct" in data: item.crude_fibre_pct = float(data["crude_fibre_pct"])
    if "cost_paid_usd_per_kg" in data: item.cost_paid_usd_per_kg = float(data["cost_paid_usd_per_kg"])
    if "stock_kg" in data: item.stock_kg = float(data["stock_kg"])
    if "notes" in data: item.notes = data["notes"]
    
    try:
        db.session.commit()
        return success_response(data={"item": item.to_dict()}, message="Ingredient updated successfully.")
    except Exception as e:
        db.session.rollback()
        return error_response(str(e), 500)


@farmer_bp.route("/inventory/<int:item_id>", methods=["DELETE"])
@jwt_required()
def delete_inventory(item_id):
    user_id = int(get_jwt_identity())
    item = FarmerIngredient.query.get(item_id)
    if not item or item.farmer_id != user_id:
        return error_response("Item not found.", 404)
    
    db.session.delete(item)
    db.session.commit()
    return success_response(message="Item removed from inventory.")


# ── Feed Optimization & Simulation 
from utils.nutrition import get_requirements
from utils.optimization import solve_feed_optimization
from utils.ml_engine import ml_engine
from database.models import FeedIngredient, SimulationRun

@farmer_bp.route("/optimize", methods=["POST"])
@jwt_required()
def optimize_feed():
    """Predicts optimal feed formulations based on cost and nutrient requirements."""
    user_id = int(get_jwt_identity())
    data = request.get_json(silent=True) or {}
    
    livestock_id = data.get("livestock_record_id")
    if not livestock_id:
        return error_response("livestock_record_id is required.", 422)
        
    record = LivestockRecord.query.get(livestock_id)
    if not record or record.farmer_id != user_id:
        return error_response("Livestock record not found.", 404)

    reqs = get_requirements(record.animal_type, record.production_stage)
    
    # 1. Get specific ingredients by IDs (could be local stock or market items)
    ingredient_ids = data.get("ingredient_ids", [])
    if not ingredient_ids:
        return error_response("Please select at least one ingredient for analysis.", 422)

    all_ingredients = []
    
    for full_id in ingredient_ids:
        try:
            if not isinstance(full_id, str):
                continue
                
            parts = full_id.split('_')
            if len(parts) < 2:
                continue
                
            source, raw_id = parts[0], int(parts[1])
            
            if source == 'inv':
                # Local Farmer Stock
                item = FarmerIngredient.query.filter_by(id=raw_id, farmer_id=user_id).first()
                if item:
                    d = item.to_dict()
                    d['id'] = f"farm_{item.id}"
                    d['cost_usd_per_kg'] = item.cost_paid_usd_per_kg
                    all_ingredients.append(d)
            elif source == 'mkt':
                # Marketplace Ingredient
                item = FeedIngredient.query.get(raw_id)
                if item and item.available:
                    d = item.to_dict()
                    d['id'] = f"supp_{item.id}"
                    all_ingredients.append(d)
        except (ValueError, IndexError):
            continue

    if not all_ingredients:
        return error_response("Requested ingredients were not found.", 404)

    # Solve Least-Cost Ration
    solution, err = solve_feed_optimization(all_ingredients, reqs)
    if err:
        return error_response(err, 400)

    # Calculate demand based on herd size
    daily_kg_per_head = record.average_weight_kg * (reqs['dmi'] / 100.0)
    total_daily_kg = daily_kg_per_head * record.herd_size

    # Add ID and source info to the ingredients list for reliable procurement later
    for ingredient in solution['ingredients']:
        # Find the original item in our merged list to recover its ID
        match = next((item for item in all_ingredients if item['name'] == ingredient['name']), None)
        if match:
            ingredient['source_id'] = match['id'] # e.g. 'supp_3' or 'farm_1'

    # Store total_daily_kg in structured data for reliable parsing
    achieved_nutrients = solution['achieved_nutrients']
    achieved_nutrients['total_daily_kg'] = round(total_daily_kg, 2)

    formulation = FeedFormulation(
        farmer_id=user_id,
        livestock_record_id=record.id,
        formulation_name=f"Optimal {record.animal_type} Mix",
        ingredients_json=json.dumps(solution['ingredients']),
        nutrient_summary_json=json.dumps(achieved_nutrients),
        total_cost_usd=solution['total_cost_usd_per_kg'],
        nutrient_adequacy=solution['adequacy'],
        notes=f"Total daily requirement: {round(total_daily_kg, 1)}kg for {record.herd_size} head."
    )
    db.session.add(formulation)
    db.session.commit()

    return success_response(data={
        "formulation": formulation.to_dict(),
        "daily_requirement_kg": round(total_daily_kg, 1),
        "requirements": reqs
    }, message="Optimal formulation generated.")


@farmer_bp.route("/predict", methods=["POST"])
@jwt_required()
def predict_performance():
    """Analyse livestock production performance indicators using Machine Learning (Random Forest)."""
    user_id = int(get_jwt_identity())
    data = request.get_json(silent=True) or {}
    
    formulation_id = data.get("formulation_id")
    if not formulation_id:
        return error_response("formulation_id is required.", 422)
        
    formula = FeedFormulation.query.get(formulation_id)
    if not formula or formula.farmer_id != user_id:
        return error_response("Formulation not found.", 404)

    record = LivestockRecord.query.get(formula.livestock_record_id)
    reqs = get_requirements(record.animal_type, record.production_stage)
    achieved = json.loads(formula.nutrient_summary_json)

    # Use lightweight ML Engine for prediction with Lifecycle awareness
    ml_result = ml_engine.predict(
        animal_type=record.animal_type,
        stage=record.production_stage,
        achieved_nutrients=achieved,
        requirements=reqs,
        age_months=record.age_in_months,
        breed=record.breed_category
    )

    # Nutrient Adequacy Assessment (Traditional for cross-verification)
    protein_ratio = achieved['crude_protein_pct'] / reqs['cp']
    energy_ratio = achieved['metabolizable_energy'] / reqs['me']
    overall_adequacy = min(protein_ratio, energy_ratio, 1.0)

    # Merge results
    performance = {
        **ml_result,
        "production_efficiency": round(overall_adequacy * 100, 1),
        "status": "Optimal" if overall_adequacy > 0.95 else "Sub-optimal",
        "limiting_nutrient": "Protein" if protein_ratio < energy_ratio else "Energy"
    }

    # Save prediction with correct health monitoring mapping
    # Handle both quantitative ("12.5 Litres/Day") and qualitative ("High Consistency") values
    predicted_val = 0.0
    raw_value = ml_result.get('value', '')
    if raw_value and ml_result.get('is_quantifiable', True):
        try:
            predicted_val = float(raw_value.split()[0])
        except (ValueError, IndexError):
            predicted_val = 0.0
    
    prediction = ProductionPrediction(
        farmer_id=user_id,
        livestock_record_id=record.id,
        formulation_id=formula.id,
        predicted_milk_yield=predicted_val if "Milk" in ml_result.get('label', '') else 0.0,
        predicted_weight_gain=predicted_val if "Weight" in ml_result.get('label', '') else 0.0,
        predicted_egg_production=predicted_val if "Egg" in ml_result.get('label', '') or "Consistency" in ml_result.get('label', '') else 0.0,
        model_confidence=0.85 if ml_result.get('confidence') == "High" else 0.65,
        input_features_json=json.dumps({"raw_label": ml_result.get('value', 'N/A')}) if not ml_result.get('is_quantifiable', True) else formula.nutrient_summary_json
    )
    db.session.add(prediction)
    db.session.commit()

    return success_response(data={"analysis": performance})


@farmer_bp.route("/simulate", methods=["POST"])
@jwt_required()
def simulate_scenarios():
    """Simulate and compare alternative feeding scenarios (Monte Carlo)."""
    user_id = int(get_jwt_identity())
    data = request.get_json(silent=True) or {}
    
    formulation_id = data.get("formulation_id")
    formula = FeedFormulation.query.get(formulation_id)
    if not formula:
        return error_response("Base formulation required.", 422)

    # Simulation parameters
    n_trials = 500
    price_volatility = 0.15 # 15% price variation
    nutrient_variance = 0.05 # 5% variation in ingredient quality
    
    base_cost = formula.total_cost_usd
    
    # Monte Carlo simulation of total cost and yield
    costs = np.random.normal(base_cost, base_cost * price_volatility, n_trials)
    yields = np.random.normal(100.0, 5.0, n_trials) # simplified yield dist
    
    results = {
        "expected_cost_mean": round(float(np.mean(costs)), 3),
        "cost_95_ci": [round(float(np.percentile(costs, 2.5)), 3), round(float(np.percentile(costs, 97.5)), 3)],
        "profitability_risk": "Low" if np.std(costs)/np.mean(costs) < 0.1 else "Medium",
        "best_case_cost": round(float(np.min(costs)), 3),
        "worst_case_cost": round(float(np.max(costs)), 3)
    }

    sim = SimulationRun(
        farmer_id=user_id,
        scenario_name="Cost & Yield Volatility Analysis",
        scenario_params_json=json.dumps({"n_trials": n_trials, "volatility": price_volatility}),
        results_json=json.dumps(results),
        n_simulations=n_trials
    )
    db.session.add(sim)
    db.session.commit()

    return success_response(data={"simulation": results})


@farmer_bp.route("/procure", methods=["POST"])
@jwt_required()
def initiate_procurement():
    """Convert a formulation into formal procurement requests for suppliers."""
    user_id = int(get_jwt_identity())
    data = request.json or {}
    
    formulation_id = data.get("formulation_id")
    formula = FeedFormulation.query.get(formulation_id)
    if not formula or formula.farmer_id != user_id:
        return error_response("Formulation not found.", 404)

    record = LivestockRecord.query.get(formula.livestock_record_id)
    if not record:
        return error_response("Associated livestock record not found.", 404)
        
    ingredients = json.loads(formula.ingredients_json)
    
    # Extract target nutrients for the whole batch or individual ingredients
    try:
        achieved = json.loads(formula.nutrient_summary_json)
        daily_req = float(achieved.get('total_daily_kg', 10.0))
        # We'll use the achieved CP/ME as the "Target" for suppliers to match
        target_cp = achieved.get('crude_protein_pct')
        target_me = achieved.get('metabolizable_energy')
    except (ValueError, TypeError):
        daily_req = 10.0
        target_cp, target_me = None, None
    
    from database.models import ProcurementRequest
    
    try:
        requests_created = 0
        for ing_result in ingredients:
            # ── Debugging Logs ──
            print(f"Procuring ingredient: {ing_result['name']}")
            
            # Calculate 15-day supply (User requested 15 days standard)
            days = 15
            # The key in the formulation JSON is 'kg_per_unit' (fraction of 1kg mix)
            kg_fraction = float(ing_result.get('kg_per_unit', 0.0))
            quantity = kg_fraction * daily_req * days
            
            # Strip decorators for the public request
            clean_name = ing_result['name'].split(' (')[0].strip()
            
            # Safe cost calculation (handle None unit costs)
            unit_cost = ing_result.get('cost_usd_per_kg')
            if unit_cost is None: unit_cost = 0.5
            
            # Use the base animal type (e.g. 'Cattle (Beef)') for filtering
            livestock_group = record.animal_type if record.animal_type else "General"
            display_group = f"{record.animal_type} ({record.production_stage})" if record.production_stage else record.animal_type
            
            new_req = ProcurementRequest(
                farmer_id=user_id,
                supplier_profile_id=None, # Public/Broadcast
                ingredient_id=None,       # Public/Broadcast
                ingredient_name=clean_name,
                quantity_kg=round(quantity, 1),
                estimated_cost_usd=round(quantity * unit_cost, 2),
                target_cp_pct=target_cp,
                target_me_mj=target_me,
                livestock_category=livestock_group,
                status="pending",
                farmer_notes=f"Public Bidding: Requested for {display_group} based on ML-optimized needs."
            )
            db.session.add(new_req)
            requests_created += 1

        if requests_created == 0:
            return error_response("No ingredients found in formulation to procure.", 400)

        db.session.commit()
        print(f"Successfully created {requests_created} requests.")
        return success_response(message=f"Success! Broadcasted {requests_created} requirements to the Marketplace Dispatch.")
        
    except Exception as e:
        import traceback
        print("CRITICAL PROCUREMENT ERROR:")
        traceback.print_exc()
        db.session.rollback()
        return error_response(f"Internal Error: {str(e)}", 500)


@farmer_bp.route("/history", methods=["GET"])
@jwt_required()
def get_farmer_history():
    """Get all past formulations, including associated predictions and livestock details."""
    user_id = int(get_jwt_identity())
    
    # Query all formulations for the user, ordered by creation date descending
    formulations = FeedFormulation.query.filter_by(farmer_id=user_id).order_by(FeedFormulation.created_at.desc()).all()
    
    history_data = []
    for formula in formulations:
        base_dict = formula.to_dict()
        
        # Attach Livestock Record details
        if formula.livestock_record_id:
            record = LivestockRecord.query.get(formula.livestock_record_id)
            if record:
                base_dict["livestock"] = record.to_dict()
                
        # Attach latest Prediction for this formulation
        prediction = ProductionPrediction.query.filter_by(formulation_id=formula.id).order_by(ProductionPrediction.predicted_at.desc()).first()
        if prediction:
            pred_dict = prediction.to_dict()
            try:
                feats = json.loads(prediction.input_features_json)
                if isinstance(feats, dict) and "raw_label" in feats:
                    pred_dict["qualitative_label"] = feats["raw_label"]
            except:
                pass
            base_dict["prediction"] = pred_dict
            
        history_data.append(base_dict)
        
    return success_response(data={"history": history_data})

@farmer_bp.route("/bids", methods=["GET"])
@jwt_required()
def get_bids():
    """Retrieve all bids received from suppliers."""
    user_id = int(get_jwt_identity())
    from database.models import SupplierBid, ProcurementRequest
    
    # Get bids for requests owned by this farmer
    bids = SupplierBid.query.join(ProcurementRequest).filter(ProcurementRequest.farmer_id == user_id).all()
    
    result = []
    for b in bids:
        d = b.to_dict()
        req = b.request
        d['supplier_name'] = b.supplier.supplier_profile.company_name
        d['ingredient_name'] = req.ingredient_name
        d['requested_quantity'] = req.quantity_kg
        d['request_status'] = req.status
        
        # ── Smart Match Ranking Logic ──────────────────────────────────────────
        # Matching % = (Nutrient Proximity * 60%) + (Price Score * 40%)
        
        score = 0.0
        
        # 1. Nutrient Score (Based on proximity to target CP/ME)
        if req.target_cp_pct and req.target_me_mj:
            # Use linked ingredient specs
            ing = b.ingredient
            if ing:
                d['offered_cp_pct'] = ing.crude_protein_pct
                d['offered_me_mj'] = ing.metabolizable_energy
                d['target_cp_pct'] = req.target_cp_pct
                d['target_me_mj'] = req.target_me_mj
                
                cp_diff = abs(ing.crude_protein_pct - req.target_cp_pct) / req.target_cp_pct
                me_diff = abs(ing.metabolizable_energy - req.target_me_mj) / req.target_me_mj
                nutrient_match = max(0, 1.0 - ((cp_diff + me_diff) / 2.0))
                score += nutrient_match * 60.0
                d['nutrient_match_pct'] = round(nutrient_match * 100, 1)
        
        # 2. Price Score
        if req.estimated_cost_usd and b.offered_cost_usd_per_kg:
            est_per_kg = req.estimated_cost_usd / req.quantity_kg
            d['target_price_per_kg'] = round(est_per_kg, 2)
            d['offered_price_per_kg'] = round(b.offered_cost_usd_per_kg, 2)
            
            price_ratio = est_per_kg / b.offered_cost_usd_per_kg
            price_score = min(1.0, price_ratio)
            score += price_score * 40.0
            d['price_score_pct'] = round(price_score * 100, 1)
            
        d['match_score'] = round(score, 1)
        
        # Ranking tag
        if score > 94: d['rank_tag'] = "Best Match"
        elif score > 85: d['rank_tag'] = "Top Choice"
        elif score > 75: d['rank_tag'] = "Value Deal"
        else: d['rank_tag'] = "Alternative"
        
        result.append(d)
        
    # Sort by match score descending
    result.sort(key=lambda x: x.get('match_score', 0), reverse=True)
    
    return success_response(data={"bids": result})

@farmer_bp.route("/bids/<int:bid_id>/reject", methods=["POST"])
@jwt_required()
def reject_bid(bid_id):
    """Mark a bid as rejected."""
    user_id = int(get_jwt_identity())
    from database.models import SupplierBid, ProcurementRequest
    
    bid = SupplierBid.query.get_or_404(bid_id)
    if bid.request.farmer_id != user_id:
        return error_response("Unauthorized", 403)
        
    bid.status = "rejected"
    db.session.commit()
    return success_response(message="Bid rejected.")

@farmer_bp.route("/procurement/<int:req_id>/close", methods=["POST"])
@jwt_required()
def close_procurement_request(req_id):
    """Close a procurement request so no and reject all pending bids."""
    user_id = int(get_jwt_identity())
    from database.models import ProcurementRequest, SupplierBid
    
    req = ProcurementRequest.query.get_or_404(req_id)
    if req.farmer_id != user_id:
        return error_response("Unauthorized", 403)
        
    req.status = "closed"
    
    # Also reject all pending bids for this request
    pending_bids = SupplierBid.query.filter_by(procurement_request_id=req.id, status="pending").all()
    for b in pending_bids:
        b.status = "rejected"
        
    db.session.commit()
    return success_response(message="Request closed and pending bids rejected.")

@farmer_bp.route("/bids/<int:bid_id>/accept", methods=["POST"])
@jwt_required()
def accept_bid(bid_id):
    """Mark a bid as accepted and update the procurement request."""
    user_id = int(get_jwt_identity())
    from database.models import SupplierBid, ProcurementRequest
    
    bid = SupplierBid.query.get_or_404(bid_id)
    req = bid.request
    
    if req.farmer_id != user_id:
        return error_response("Unauthorized", 403)
        
    # Update status for both
    bid.status = "accepted"
    req.status = "accepted"
    
    # Reject other bids for this request
    # also mark request fulfilled if we want, but "accepted" means vendor selected
    
    other_bids = SupplierBid.query.filter(
        SupplierBid.procurement_request_id == req.id,
        SupplierBid.id != bid_id
    ).all()
    for ob in other_bids:
        ob.status = "rejected"
        
    db.session.commit()
    return success_response(message="Bid accepted successfully!")
