"""
FarmFeed Authentication Routes
================================
POST /api/auth/register  — Create farmer or supplier account
POST /api/auth/login     — Login and receive JWT
GET  /api/auth/me        — Get current user profile
PUT  /api/auth/me        — Update profile
"""

import json
import re
from flask import Blueprint, request
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity

from database.db import db
from database.models import User, FarmerProfile, SupplierProfile, Notification
from utils.helpers import (
    hash_password,
    verify_password,
    success_response,
    error_response,
    validate_required_fields,
    ZIMBABWE_PROVINCES,
    USER_ROLES,
)

auth_bp = Blueprint("auth", __name__, url_prefix="/api/auth")


# ── Helpers ────────────────────────────────────────────────────────────────────
def is_valid_email(email: str) -> bool:
    return bool(re.match(r"^[\w\.-]+@[\w\.-]+\.\w{2,}$", email.strip()))


def is_valid_phone(phone: str) -> bool:
    # Accept Zimbabwean formats: 07X, +2637X, 2637X
    cleaned = re.sub(r"[\s\-()]", "", phone)
    return bool(re.match(r"^(\+?263|0)[0-9]{8,9}$", cleaned))


# ── Register ───────────────────────────────────────────────────────────────────
@auth_bp.route("/register", methods=["POST"])
def register():
    data = request.get_json(silent=True)
    if not data:
        return error_response("Request body must be JSON.", 400)

    # ── Required field check ───────────────────────────────────────────────────
    base_required = [
        "first_name", "last_name", "email", "phone",
        "password", "confirm_password", "role"
    ]
    missing = validate_required_fields(data, base_required)
    if missing:
        return error_response(
            f"Missing required fields: {', '.join(missing)}",
            400,
            errors={f: "This field is required." for f in missing},
        )

    # ── Field validations ──────────────────────────────────────────────────────
    errors = {}

    email = data["email"].strip().lower()
    if not is_valid_email(email):
        errors["email"] = "Please enter a valid email address."

    phone = data["phone"].strip()
    if not is_valid_phone(phone):
        errors["phone"] = "Please enter a valid Zimbabwean phone number (e.g. 0771234567)."

    password = data["password"]
    if len(password) < 8:
        errors["password"] = "Password must be at least 8 characters."

    if password != data.get("confirm_password"):
        errors["confirm_password"] = "Passwords do not match."

    role = data["role"].strip().lower()
    if role not in USER_ROLES:
        errors["role"] = f"Role must be one of: {', '.join(USER_ROLES)}."

    province = data.get("province", "").strip()
    if province and province not in ZIMBABWE_PROVINCES:
        errors["province"] = f"Please select a valid Zimbabwe province."

    if errors:
        return error_response("Validation failed. Please correct the errors.", 422, errors=errors)

    # ── Duplicate email check ──────────────────────────────────────────────────
    existing = User.query.filter_by(email=email).first()
    if existing:
        return error_response("An account with this email already exists.", 409)

    # ── Role-specific validation ───────────────────────────────────────────────
    # Removed mandatory farm_name and company_name to simplify registration.

    # ── Create User ────────────────────────────────────────────────────────────
    try:
        user = User(
            first_name=data["first_name"].strip(),
            last_name=data["last_name"].strip(),
            email=email,
            phone=phone,
            password_hash=hash_password(password),
            role=role,
            province=province or None,
            city=data.get("city", "").strip() or None,
            street_address=data.get("street_address", "").strip() or None,
            location_description=data.get("location_description", "").strip() or None,
        )
        db.session.add(user)
        db.session.flush()  # get user.id before commit

        # ── Create role profile ────────────────────────────────────────────────
        if role == "farmer":
            livestock_types = data.get("livestock_types", [])
            if isinstance(livestock_types, list):
                livestock_json = json.dumps(livestock_types)
            else:
                livestock_json = "[]"

            farmer_profile = FarmerProfile(
                user_id=user.id,
                farm_name=data.get("farm_name", f"{user.first_name}'s Farm").strip(),
                livestock_types=livestock_json,
                farm_size_ha=data.get("farm_size_ha") or None,
                total_herd_size=int(data.get("total_herd_size", 0) or 0),
                primary_production_goal=data.get("primary_production_goal", "Mixed").strip(),
            )
            db.session.add(farmer_profile)

        elif role == "supplier":
            supplier_profile = SupplierProfile(
                user_id=user.id,
                company_name=data.get("company_name", f"{user.first_name}'s Company").strip(),
                business_reg_no=data.get("business_reg_no", "").strip() or None,
                description=data.get("description", "").strip() or None,
                operating_hours=data.get("operating_hours", "").strip() or None,
                delivery_available=bool(data.get("delivery_available", False)),
                delivery_radius_km=data.get("delivery_radius_km") or None,
            )
            db.session.add(supplier_profile)

        db.session.commit()

        # ── Issue JWT ──────────────────────────────────────────────────────────
        token = create_access_token(
            identity=str(user.id),
            additional_claims={"role": user.role, "email": user.email},
        )

        return success_response(
            data={"token": token, "user": user.to_dict()},
            message=f"Welcome to FarmFeed, {user.first_name}! Your account has been created.",
            status_code=201,
        )

    except Exception as e:
        db.session.rollback()
        print(f"Registration error: {e}")
        return error_response("Registration failed due to a server error. Please try again.", 500)


# ── Login ──────────────────────────────────────────────────────────────────────
@auth_bp.route("/login", methods=["POST"])
def login():
    data = request.get_json(silent=True)
    if not data:
        return error_response("Request body must be JSON.", 400)

    missing = validate_required_fields(data, ["email", "password"])
    if missing:
        return error_response("Email and password are required.", 400)

    email = data["email"].strip().lower()
    password = data["password"]

    user = User.query.filter_by(email=email).first()
    if not user or not verify_password(password, user.password_hash):
        return error_response("Invalid email or password. Please try again.", 401)

    if not user.is_active:
        return error_response("Your account has been deactivated. Please contact support.", 403)

    token = create_access_token(
        identity=str(user.id),
        additional_claims={"role": user.role, "email": user.email},
    )

    return success_response(
        data={"token": token, "user": user.to_dict()},
        message=f"Welcome back, {user.first_name}!",
    )


# ── Get Current User ───────────────────────────────────────────────────────────
@auth_bp.route("/me", methods=["GET"])
@jwt_required()
def get_me():
    user_id = int(get_jwt_identity())
    user = User.query.get(user_id)
    if not user:
        return error_response("User not found.", 404)
    return success_response(data={"user": user.to_dict()})


# ── Update Profile ─────────────────────────────────────────────────────────────
@auth_bp.route("/me", methods=["PUT"])
@jwt_required()
def update_me():
    user_id = int(get_jwt_identity())
    user = User.query.get(user_id)
    if not user:
        return error_response("User not found.", 404)

    data = request.get_json(silent=True) or {}
    updatable_fields = ["first_name", "last_name", "phone", "city", "street_address", "location_description", "profile_photo_url"]

    for field in updatable_fields:
        if field in data and data[field] is not None:
            setattr(user, field, str(data[field]).strip())

    # Province validation
    if "province" in data:
        if data["province"] in ZIMBABWE_PROVINCES:
            user.province = data["province"]
        else:
            return error_response("Invalid province selected.", 422)

    # Update role profile
    if user.role == "farmer" and user.farmer_profile:
        fp = user.farmer_profile
        if "farm_name" in data:
            fp.farm_name = data["farm_name"].strip()
        if "livestock_types" in data and isinstance(data["livestock_types"], list):
            fp.livestock_types = json.dumps(data["livestock_types"])
        if "farm_size_ha" in data:
            size = data["farm_size_ha"]
            if size is not None and float(size) >= 0:
                fp.farm_size_ha = float(size)
        if "primary_production_goal" in data:
            fp.primary_production_goal = data["primary_production_goal"]

    elif user.role == "supplier" and user.supplier_profile:
        sp = user.supplier_profile
        if "company_name" in data:
            sp.company_name = data["company_name"].strip()
        if "description" in data:
            sp.description = data["description"]
        if "operating_hours" in data:
            sp.operating_hours = data["operating_hours"]
        if "delivery_available" in data:
            sp.delivery_available = bool(data["delivery_available"])
        if "delivery_radius_km" in data:
            sp.delivery_radius_km = data["delivery_radius_km"]

    try:
        db.session.commit()
        return success_response(data={"user": user.to_dict()}, message="Profile updated successfully.")
    except Exception as e:
        db.session.rollback()
        return error_response("Failed to update profile.", 500)


# ── Change Password ────────────────────────────────────────────────────────────
@auth_bp.route("/change-password", methods=["POST"])
@jwt_required()
def change_password():
    user_id = int(get_jwt_identity())
    user = User.query.get(user_id)
    if not user:
        return error_response("User not found.", 404)

    data = request.get_json(silent=True) or {}
    current = data.get("current_password", "")
    new_pwd = data.get("new_password", "")
    confirm = data.get("confirm_password", "")

    if not verify_password(current, user.password_hash):
        return error_response("Current password is incorrect.", 401)
    if len(new_pwd) < 8:
        return error_response("New password must be at least 8 characters.", 422)
    if new_pwd != confirm:
        return error_response("Passwords do not match.", 422)

    user.password_hash = hash_password(new_pwd)
    db.session.commit()
    return success_response(message="Password changed successfully.")


# ── Notifications ──────────────────────────────────────────────────────────────

@auth_bp.route("/notifications", methods=["GET"])
@jwt_required()
def get_notifications():
    """Get all notifications for the current user."""
    user_id = int(get_jwt_identity())
    notifs = Notification.query.filter_by(user_id=user_id).order_by(Notification.created_at.desc()).all()
    
    unread_count = Notification.query.filter_by(user_id=user_id, is_read=False).count()
    
    return success_response(data={
        "notifications": [n.to_dict() for n in notifs],
        "unread_count": unread_count
    })


@auth_bp.route("/notifications/read-all", methods=["POST"])
@jwt_required()
def mark_all_notifications_read():
    """Mark all notifications for the user as read."""
    user_id = int(get_jwt_identity())
    Notification.query.filter_by(user_id=user_id, is_read=False).update({"is_read": True})
    db.session.commit()
    return success_response(message="All notifications marked as read.")


@auth_bp.route("/notifications/<int:id>/read", methods=["POST"])
@jwt_required()
def mark_notification_read(id):
    """Mark a specific notification as read."""
    user_id = int(get_jwt_identity())
    notif = Notification.query.filter_by(id=id, user_id=user_id).first()
    if not notif:
        return error_response("Notification not found.", 404)
    
    notif.is_read = True
    db.session.commit()
    return success_response(message="Notification marked as read.")
