"""
FarmFeed — Supplier Routes
==========================
Handles supplier stock management and procurement request processing.
"""

from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity

from database.db import db
from database.models import User, FeedIngredient, ProcurementRequest, Notification
from utils.helpers import success_response, error_response, validate_required_fields

supplier_bp = Blueprint("supplier", __name__, url_prefix="/api/supplier")


@supplier_bp.route("/dashboard", methods=["GET"])
@jwt_required()
def get_dashboard():
    user_id = int(get_jwt_identity())
    user = User.query.get(user_id)
    if not user or user.role != "supplier":
        return error_response("Access denied. Supplier role required.", 403)

    sp = user.supplier_profile
    if not sp:
        return error_response("Supplier profile not found.", 404)

    ingredient_count = sp.ingredients.count()
    pending_requests = ProcurementRequest.query.filter_by(
        supplier_profile_id=sp.id, status="pending"
    ).count()
    
    # New: Count of public requests available for bidding
    open_bidding_count = ProcurementRequest.query.filter_by(
        supplier_profile_id=None, status="pending"
    ).count()

    return success_response(data={
        "supplier": user.to_dict(),
        "stats": {
            "total_ingredients": ingredient_count,
            "pending_requests": pending_requests,
            "open_biddings": open_bidding_count,
            "fulfilled_requests": ProcurementRequest.query.filter_by(
                supplier_profile_id=sp.id, status="fulfilled"
            ).count(),
        },
    })


# ── Ingredient Management ──────────────────────────────────────────────────────

@supplier_bp.route("/ingredients", methods=["GET"])
@jwt_required()
def get_ingredients():
    user_id = int(get_jwt_identity())
    user = User.query.get(user_id)
    if not user or user.role != "supplier":
        return error_response("Access denied.", 403)
    sp = user.supplier_profile
    if not sp:
        return error_response("Supplier profile not found.", 404)
    ingredients = [i.to_dict() for i in sp.ingredients.order_by(FeedIngredient.name).all()]
    return success_response(data={"ingredients": ingredients})


@supplier_bp.route("/ingredients", methods=["POST"])
@jwt_required()
def add_ingredient():
    user_id = int(get_jwt_identity())
    user = User.query.get(user_id)
    if not user or user.role != "supplier":
        return error_response("Access denied.", 403)
    
    sp = user.supplier_profile
    data = request.get_json(silent=True) or {}
    
    required = ["name", "crude_protein_pct", "metabolizable_energy", "cost_usd_per_kg"]
    missing = validate_required_fields(data, required)
    if missing:
        return error_response(f"Missing fields: {', '.join(missing)}", 422)

    cp = float(data["crude_protein_pct"])
    me = float(data["metabolizable_energy"])
    cf = float(data.get("crude_fibre_pct", 0.0))
    cost = float(data["cost_usd_per_kg"])
    stock = float(data.get("stock_kg", 0.0))

    # Range Validation
    if not (0 <= cp <= 100): return error_response("CP must be 0-100%", 422)
    if not (0 <= me <= 50): return error_response("ME must be 0-50 MJ", 422)
    if not (0 <= cf <= 100): return error_response("CF must be 0-100%", 422)
    if cost <= 0 or cost > 5000: return error_response("Invalid cost range", 422)
    if stock < 0 or stock > 1000000: return error_response("Invalid stock range", 422)

    try:
        ingredient = FeedIngredient(
            supplier_id=sp.id,
            name=data["name"],
            crude_protein_pct=cp,
            metabolizable_energy=me,
            crude_fibre_pct=cf,
            calcium_phosphorus_ratio=float(data.get("calcium_phosphorus_ratio", 0.0)),
            dry_matter_pct=float(data.get("dry_matter_pct", 88.0)),
            cost_usd_per_kg=cost,
            stock_kg=stock,
            target_livestock_type=data.get("target_livestock_type"),
            description=data.get("description", ""),
            available=bool(data.get("available", True))
        )
        db.session.add(ingredient)
        db.session.commit()
        return success_response(data={"ingredient": ingredient.to_dict()}, message="Ingredient added.", status_code=201)
    except Exception as e:
        db.session.rollback()
        return error_response(str(e), 500)


@supplier_bp.route("/ingredients/<int:id>", methods=["PUT"])
@jwt_required()
def update_ingredient(id):
    """Update an existing feed ingredient."""
    user_id = int(get_jwt_identity())
    user = User.query.get(user_id)
    ingredient = FeedIngredient.query.get(id)
    
    if not ingredient or ingredient.supplier_id != user.supplier_profile.id:
        return error_response("Ingredient not found or access denied.", 404)
        
    data = request.get_json(silent=True) or {}
    
    # Update fields if provided with validation
    if "name" in data: ingredient.name = data["name"]
    
    if "crude_protein_pct" in data:
        val = float(data["crude_protein_pct"])
        if 0 <= val <= 100: ingredient.crude_protein_pct = val
        else: return error_response("Invalid CP", 422)
        
    if "metabolizable_energy" in data:
        val = float(data["metabolizable_energy"])
        if 0 <= val <= 50: ingredient.metabolizable_energy = val
        else: return error_response("Invalid ME", 422)
        
    if "crude_fibre_pct" in data:
        val = float(data["crude_fibre_pct"])
        if 0 <= val <= 100: ingredient.crude_fibre_pct = val
        else: return error_response("Invalid CF", 422)
        
    if "cost_usd_per_kg" in data:
        val = float(data["cost_usd_per_kg"])
        if 0 < val <= 5000: ingredient.cost_usd_per_kg = val
        else: return error_response("Invalid Cost", 422)
        
    if "stock_kg" in data:
        val = float(data["stock_kg"])
        if 0 <= val <= 1000000: ingredient.stock_kg = val
        else: return error_response("Invalid Stock", 422)
        
    if "target_livestock_type" in data: ingredient.target_livestock_type = data["target_livestock_type"]
    if "description" in data: ingredient.description = data["description"]
    if "available" in data: ingredient.available = bool(data["available"])
    
    try:
        db.session.commit()
        return success_response(data={"ingredient": ingredient.to_dict()}, message="Ingredient updated.")
    except Exception as e:
        db.session.rollback()
        return error_response(str(e), 500)


@supplier_bp.route("/ingredients/<int:id>", methods=["DELETE"])
@jwt_required()
def delete_ingredient(id):
    user_id = int(get_jwt_identity())
    ingredient = FeedIngredient.query.get(id)
    user = User.query.get(user_id)
    
    if not ingredient or ingredient.supplier_id != user.supplier_profile.id:
        return error_response("Ingredient not found or access denied.", 404)
    
    db.session.delete(ingredient)
    db.session.commit()
    return success_response(message="Ingredient deleted.")


# ── Public: All suppliers list (for farmer discovery) ──────────────────────────

@supplier_bp.route("/all", methods=["GET"])
@jwt_required()
def get_all_suppliers():
    suppliers = User.query.filter_by(role="supplier", is_active=True).all()
    result = []
    for s in suppliers:
        info = {
            "id": s.id,
            "full_name": f"{s.first_name} {s.last_name}",
            "email": s.email,
            "phone": s.phone,
            "location": f"{s.city}, {s.province}" if s.city else s.province,
        }
        if s.supplier_profile:
            info["company_name"] = s.supplier_profile.company_name
            info["supplier_profile_id"] = s.supplier_profile.id
            info["description"] = s.supplier_profile.description
            info["delivery_available"] = s.supplier_profile.delivery_available
            info["ingredient_count"] = s.supplier_profile.ingredients.count()
        result.append(info)
    return success_response(data={"suppliers": result, "total": len(result)})


# ── Procurement / Order Management ─────────────────────────────────────────────

@supplier_bp.route("/orders", methods=["GET"])
@jwt_required()
def get_orders():
    """List all procurement requests for this supplier."""
    user_id = int(get_jwt_identity())
    user = User.query.get(user_id)
    if not user or user.role != "supplier":
        return error_response("Access denied.", 403)
    
    sp = user.supplier_profile
    if not sp:
        return error_response("Supplier profile not found.", 404)
        
    requests = ProcurementRequest.query.filter_by(supplier_profile_id=sp.id).order_by(ProcurementRequest.requested_at.desc()).all()
    
    orders = []
    for r in requests:
        d = r.to_dict()
        # Add farmer info
        d['farmer_name'] = f"{r.farmer.first_name} {r.farmer.last_name}"
        # Add ingredient info
        d['ingredient_name'] = r.ingredient.name
        orders.append(d)
        
    return success_response(data={"orders": orders})


@supplier_bp.route("/orders/<int:id>/status", methods=["POST"])
@jwt_required()
def update_order_status(id):
    """Update order status and notify the farmer."""
    user_id = int(get_jwt_identity())
    user = User.query.get(user_id)
    req = ProcurementRequest.query.get(id)
    
    if not req or req.supplier_profile_id != user.supplier_profile.id:
        return error_response("Order not found or access denied.", 404)
        
    data = request.json or {}
    new_status = data.get("status") # pending | accepted | rejected | fulfilled
    if new_status not in ["pending", "accepted", "rejected", "fulfilled"]:
        return error_response("Invalid status.", 400)
        
    old_status = req.status
    req.status = new_status
    req.supplier_notes = data.get("notes", req.supplier_notes)
    
    # Create Notification for Farmer
    notif = Notification(
        user_id=req.farmer_id,
        type="order_update",
        title="Order Status Updated",
        body=f"Supplier {user.supplier_profile.company_name} has marked your {req.ingredient.name} order as {new_status.upper()}.",
        link_id=str(req.id)
    )
    db.session.add(notif)
    db.session.commit()
    
    return success_response(message=f"Order status updated from {old_status} to {new_status}.")


@supplier_bp.route("/procurement/<int:req_id>/bid", methods=["POST"])
@jwt_required()
def bid_on_procurement(req_id):
    """Supplier submits a specific bid (quantity/price) for a farmer's request."""
    user_id = int(get_jwt_identity())
    user = User.query.get(user_id)
    if not user or user.role != "supplier":
        return error_response("Access denied.", 403)

    req = ProcurementRequest.query.get(req_id)
    if not req:
        return error_response("Request not found.", 404)

    # Prevent duplicate bids from the same supplier
    from database.models import SupplierBid
    existing_bid = SupplierBid.query.filter_by(
        procurement_request_id=req_id,
        supplier_id=user_id
    ).first()
    if existing_bid:
        return error_response("You have already submitted a bid for this request. Please wait for the farmer's response.", 400)

    data = request.json or {}
    required = ["offered_quantity_kg", "offered_cost_usd_per_kg"]
    missing = validate_required_fields(data, required)
    if missing:
        return error_response(f"Missing: {', '.join(missing)}", 422)

    if not user.supplier_profile:
        return error_response("Supplier profile not found. Please complete your profile first.", 400)

    try:
        from database.models import SupplierBid
        # 1. Create and Commit the Bid first to get an ID
        bid = SupplierBid(
            procurement_request_id=req.id,
            supplier_id=user.id,
            supplier_ingredient_id=data.get("supplier_ingredient_id"), # New Linkage
            offered_quantity_kg=float(data["offered_quantity_kg"]),
            offered_cost_usd_per_kg=float(data["offered_cost_usd_per_kg"]),
            notes=data.get("notes", "")
        )
        db.session.add(bid)
        db.session.flush() # Get ID without full commit yet
        
        print(f"DEBUG: Bid {bid.id} created for Request {req.id} with Ing {bid.supplier_ingredient_id}")
        
        # 2. Create Notification using the Bid ID
        new_notif = Notification(
            user_id=req.farmer_id,
            type="bid_received",
            title="New Bid Received",
            body=f"Supplier {user.supplier_profile.company_name} has submitted a bid for your {req.ingredient_name} request.",
            link_id=str(bid.id)
        )
        db.session.add(new_notif)
        db.session.commit()
        
        print("DEBUG: Bid and Notification committed successfully.")
        return success_response(data={"bid": bid.to_dict()}, message="Bid submitted successfully.")
    except Exception as e:
        import traceback
        print("CRITICAL BID SUBMISSION ERROR:")
        traceback.print_exc()
        db.session.rollback()
        return error_response(f"Bidding Error: {str(e)}", 500)
@supplier_bp.route("/open_market", methods=["GET"])
@jwt_required()
def get_open_market():
    """List all public procurement requests available for bidding."""
    user_id = int(get_jwt_identity())
    # Include requests that are pending OR accepted (if the current supplier bidded on them)
    from sqlalchemy import or_
    requests = ProcurementRequest.query.filter(
        ProcurementRequest.supplier_profile_id == None,
        or_(ProcurementRequest.status == "pending", ProcurementRequest.status == "accepted")
    ).order_by(ProcurementRequest.requested_at.desc()).all()
    
    result = []
    from database.models import SupplierBid
    for r in requests:
        # Check if current supplier has bidded
        existing_bid = SupplierBid.query.filter_by(
            procurement_request_id=r.id,
            supplier_id=user_id
        ).first()

        # If it's accepted by someone else and I didn't bid, skip it
        if r.status == "accepted" and not existing_bid:
            continue
            
        d = r.to_dict()
        d['farmer_name'] = f"{r.farmer.first_name} {r.farmer.last_name}"
        d['location'] = f"{r.farmer.city}, {r.farmer.province}" if r.farmer.city else r.farmer.province
        
        d['has_bidded'] = existing_bid is not None
        d['bid_status'] = existing_bid.status if existing_bid else None
        
        result.append(d)
        
    return success_response(data={"requests": result})
