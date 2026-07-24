"""
FarmFeed Database Models
All SQLAlchemy ORM models for the FarmFeed application.
"""

from datetime import datetime
import json
from database.db import db


# ── User 
class User(db.Model):
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True)
    first_name = db.Column(db.String(100), nullable=False)
    last_name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(200), unique=True, nullable=False, index=True)
    phone = db.Column(db.String(25), nullable=False)
    password_hash = db.Column(db.String(512), nullable=False)
    role = db.Column(db.String(20), nullable=False)  # 'farmer' | 'supplier'

    # ── Location & Contact 
    province = db.Column(db.String(100), nullable=True)
    city = db.Column(db.String(100), nullable=True)
    street_address = db.Column(db.String(300), nullable=True)
    location_description = db.Column(db.String(500))  #  "Near Mvurwi Growth Point"

    # ── Meta 
    profile_photo_url = db.Column(db.String(500))
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # ── Relationships
    farmer_profile = db.relationship("FarmerProfile", backref="user", uselist=False, cascade="all, delete-orphan")
    supplier_profile = db.relationship("SupplierProfile", backref="user", uselist=False, cascade="all, delete-orphan")
    livestock_records = db.relationship("LivestockRecord", backref="owner", lazy="dynamic", cascade="all, delete-orphan")
    feed_formulations = db.relationship("FeedFormulation", backref="farmer", lazy="dynamic", cascade="all, delete-orphan")
    simulation_runs = db.relationship("SimulationRun", backref="farmer", lazy="dynamic", cascade="all, delete-orphan")
    inventory = db.relationship("FarmerIngredient", backref="farmer", lazy="dynamic", cascade="all, delete-orphan")

    def to_dict(self, include_profile=True):
        data = {
            "id": self.id,
            "first_name": self.first_name,
            "last_name": self.last_name,
            "full_name": f"{self.first_name} {self.last_name}",
            "email": self.email,
            "phone": self.phone,
            "role": self.role,
            "province": self.province,
            "city": self.city,
            "street_address": self.street_address,
            "location_description": self.location_description,
            "profile_photo_url": self.profile_photo_url,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
        if include_profile:
            if self.role == "farmer" and self.farmer_profile:
                data["profile"] = self.farmer_profile.to_dict()
            elif self.role == "supplier" and self.supplier_profile:
                data["profile"] = self.supplier_profile.to_dict()
        return data

    def __repr__(self):
        return f"<User {self.email} [{self.role}]>"


# ── Farmer Profile 
class FarmerProfile(db.Model):
    __tablename__ = "farmer_profiles"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, unique=True)
    farm_name = db.Column(db.String(200), nullable=False)
    livestock_types = db.Column(db.Text)       # JSON array: '["Cattle (Beef)", "Goats"]'
    farm_size_ha = db.Column(db.Float)
    total_herd_size = db.Column(db.Integer, default=0)
    primary_production_goal = db.Column(db.String(100))  # Meat / Milk / Eggs / Mixed
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def get_livestock_types(self):
        if self.livestock_types:
            try:
                return json.loads(self.livestock_types)
            except Exception:
                return []
        return []

    def to_dict(self):
        return {
            "farm_name": self.farm_name,
            "livestock_types": self.get_livestock_types(),
            "farm_size_ha": self.farm_size_ha,
            "total_herd_size": self.total_herd_size,
            "primary_production_goal": self.primary_production_goal,
        }

    def __repr__(self):
        return f"<FarmerProfile {self.farm_name}>"


# ── Supplier Profile 
class SupplierProfile(db.Model):
    __tablename__ = "supplier_profiles"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, unique=True)
    company_name = db.Column(db.String(200), nullable=False)
    business_reg_no = db.Column(db.String(100))
    description = db.Column(db.Text)
    operating_hours = db.Column(db.String(200))  # e.g. "Mon-Fri 08:00-17:00"
    delivery_available = db.Column(db.Boolean, default=False)
    delivery_radius_km = db.Column(db.Float)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    # ── Relationships 
    ingredients = db.relationship("FeedIngredient", backref="supplier", lazy="dynamic", cascade="all, delete-orphan")
    procurement_requests = db.relationship("ProcurementRequest", backref="supplier_company", lazy="dynamic")

    def to_dict(self):
        return {
            "company_name": self.company_name,
            "business_reg_no": self.business_reg_no,
            "description": self.description,
            "operating_hours": self.operating_hours,
            "delivery_available": self.delivery_available,
            "delivery_radius_km": self.delivery_radius_km,
        }

    def __repr__(self):
        return f"<SupplierProfile {self.company_name}>"


# ── Feed Ingredient 
class FeedIngredient(db.Model):
    __tablename__ = "feed_ingredients"

    id = db.Column(db.Integer, primary_key=True)
    supplier_id = db.Column(db.Integer, db.ForeignKey("supplier_profiles.id"), nullable=False)
    name = db.Column(db.String(200), nullable=False)
    # Nutritional composition
    crude_protein_pct = db.Column(db.Float, nullable=False)   # % DM
    metabolizable_energy = db.Column(db.Float, nullable=False) # MJ/kg DM
    crude_fibre_pct = db.Column(db.Float, nullable=False)      # % DM
    calcium_phosphorus_ratio = db.Column(db.Float)
    dry_matter_pct = db.Column(db.Float, default=88.0)
    # Economics
    cost_usd_per_kg = db.Column(db.Float, nullable=False)
    stock_kg = db.Column(db.Float, default=0.0)
    available = db.Column(db.Boolean, default=True)
    minimum_order_kg = db.Column(db.Float, default=10.0)
    # Management
    target_livestock_type = db.Column(db.String(100)) # e.g. "Goats", "Pigs"
    # Meta
    description = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "supplier_id": self.supplier_id,
            "name": self.name,
            "crude_protein_pct": self.crude_protein_pct,
            "metabolizable_energy": self.metabolizable_energy,
            "crude_fibre_pct": self.crude_fibre_pct,
            "calcium_phosphorus_ratio": self.calcium_phosphorus_ratio,
            "dry_matter_pct": self.dry_matter_pct,
            "cost_usd_per_kg": self.cost_usd_per_kg,
            "stock_kg": self.stock_kg,
            "available": self.available,
            "minimum_order_kg": self.minimum_order_kg,
            "target_livestock_type": self.target_livestock_type,
            "description": self.description,
        }

    def __repr__(self):
        return f"<FeedIngredient {self.name}>"


# ── Farmer Ingredient Inventory 
class FarmerIngredient(db.Model):
    __tablename__ = "farmer_ingredients"

    id = db.Column(db.Integer, primary_key=True)
    farmer_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    name = db.Column(db.String(200), nullable=False)
    target_livestock_type = db.Column(db.String(100), nullable=False) #  "Goats", "Pigs"
    
    # Nutritional composition (Farmers can manually input what they bought)
    crude_protein_pct = db.Column(db.Float, nullable=False)
    metabolizable_energy = db.Column(db.Float, nullable=False)
    crude_fibre_pct = db.Column(db.Float, nullable=False)
    
    # Management
    cost_paid_usd_per_kg = db.Column(db.Float, nullable=False)
    stock_kg = db.Column(db.Float, default=0.0)
    notes = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "target_livestock_type": self.target_livestock_type,
            "crude_protein_pct": self.crude_protein_pct,
            "metabolizable_energy": self.metabolizable_energy,
            "crude_fibre_pct": self.crude_fibre_pct,
            "cost_paid_usd_per_kg": self.cost_paid_usd_per_kg,
            "stock_kg": self.stock_kg,
            "notes": self.notes,
            "source": "Inventory"
        }


# ── Livestock Record 
class LivestockRecord(db.Model):
    __tablename__ = "livestock_records"

    id = db.Column(db.Integer, primary_key=True)
    farmer_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    animal_type = db.Column(db.String(50), nullable=False)  # Cattle, Goat, Poultry
    breed_category = db.Column(db.String(50))               # Indigenous, Hybrid, Exotic
    production_stage = db.Column(db.String(50))             # Growing, Lactating, Layering
    herd_size = db.Column(db.Integer, default=1)
    average_weight_kg = db.Column(db.Float)
    age_in_months = db.Column(db.Integer, default=1)
    feeding_frequency = db.Column(db.Integer, default=2)    # times per day
    notes = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "animal_type": self.animal_type,
            "breed_category": self.breed_category,
            "production_stage": self.production_stage,
            "herd_size": self.herd_size,
            "average_weight_kg": self.average_weight_kg,
            "age_in_months": self.age_in_months,
            "feeding_frequency": self.feeding_frequency,
            "notes": self.notes,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


# ── Feed Formulation
class FeedFormulation(db.Model):
    __tablename__ = "feed_formulations"

    id = db.Column(db.Integer, primary_key=True)
    farmer_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    livestock_record_id = db.Column(db.Integer, db.ForeignKey("livestock_records.id"))
    formulation_name = db.Column(db.String(200))
    ingredients_json = db.Column(db.Text)       # JSON: [{id, name, kg, cost}]
    nutrient_summary_json = db.Column(db.Text)  # JSON: {protein, energy, fibre, cost}
    total_cost_usd = db.Column(db.Float)
    nutrient_adequacy = db.Column(db.String(20))  # Adequate | Inadequate
    notes = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "formulation_name": self.formulation_name,
            "ingredients": json.loads(self.ingredients_json) if self.ingredients_json else [],
            "nutrient_summary": json.loads(self.nutrient_summary_json) if self.nutrient_summary_json else {},
            "total_cost_usd": self.total_cost_usd,
            "nutrient_adequacy": self.nutrient_adequacy,
            "notes": self.notes,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


# ── Production Prediction
class ProductionPrediction(db.Model):
    __tablename__ = "production_predictions"

    id = db.Column(db.Integer, primary_key=True)
    farmer_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    livestock_record_id = db.Column(db.Integer, db.ForeignKey("livestock_records.id"))
    formulation_id = db.Column(db.Integer, db.ForeignKey("feed_formulations.id"))
    predicted_milk_yield = db.Column(db.Float)
    predicted_weight_gain = db.Column(db.Float)
    predicted_egg_production = db.Column(db.Float)
    model_confidence = db.Column(db.Float)
    input_features_json = db.Column(db.Text)
    predicted_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "predicted_milk_yield": self.predicted_milk_yield,
            "predicted_weight_gain": self.predicted_weight_gain,
            "predicted_egg_production": self.predicted_egg_production,
            "model_confidence": self.model_confidence,
            "predicted_at": self.predicted_at.isoformat() if self.predicted_at else None,
        }


# ── Simulation Run 
class SimulationRun(db.Model):
    __tablename__ = "simulation_runs"

    id = db.Column(db.Integer, primary_key=True)
    farmer_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    scenario_name = db.Column(db.String(200))
    scenario_params_json = db.Column(db.Text)    # MC input distributions
    results_json = db.Column(db.Text)            # MC output summary
    n_simulations = db.Column(db.Integer, default=1000)
    run_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "scenario_name": self.scenario_name,
            "scenario_params": json.loads(self.scenario_params_json) if self.scenario_params_json else {},
            "results": json.loads(self.results_json) if self.results_json else {},
            "n_simulations": self.n_simulations,
            "run_at": self.run_at.isoformat() if self.run_at else None,
        }


# ── Procurement Request 
class ProcurementRequest(db.Model):
    __tablename__ = "procurement_requests"

    id = db.Column(db.Integer, primary_key=True)
    farmer_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    # Nullable for "Public" requests before a supplier is selected
    supplier_profile_id = db.Column(db.Integer, db.ForeignKey("supplier_profiles.id"), nullable=True)
    ingredient_id = db.Column(db.Integer, db.ForeignKey("feed_ingredients.id"), nullable=True)
    
    ingredient_name = db.Column(db.String(200)) # The generic type requested, e.g. "Cotton Seedcake"
    quantity_kg = db.Column(db.Float, nullable=False)
    estimated_cost_usd = db.Column(db.Float)
    
    # Target Nutrients for Smart Matching
    target_cp_pct = db.Column(db.Float)
    target_me_mj = db.Column(db.Float)
    livestock_category = db.Column(db.String(50)) # e.g. "Dairy", "Poultry"
    
    status = db.Column(db.String(30), default="pending")  # pending | accepted | rejected | fulfilled
    farmer_notes = db.Column(db.Text)
    supplier_notes = db.Column(db.Text)
    requested_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    farmer = db.relationship("User", backref="procurement_requests", foreign_keys=[farmer_id])
    ingredient = db.relationship("FeedIngredient", backref="requests")

    def to_dict(self):
        return {
            "id": self.id,
            "farmer_id": self.farmer_id,
            "supplier_profile_id": self.supplier_profile_id,
            "ingredient_id": self.ingredient_id,
            "ingredient_name": self.ingredient_name,
            "quantity_kg": self.quantity_kg,
            "estimated_cost_usd": self.estimated_cost_usd,
            "target_cp_pct": self.target_cp_pct,
            "target_me_mj": self.target_me_mj,
            "livestock_category": self.livestock_category,
            # Calculate daily requirements per animal (not multiplied for the whole batch)
            "daily_cp_kg_head": round(((self.target_cp_pct or 0.0) / 100.0) * (self.quantity_kg / 15.0 / (self.farmer.livestock_records[0].herd_size if self.farmer.livestock_records else 1)), 3),
            "daily_me_mj_head": round((self.target_me_mj or 0.0) * (self.quantity_kg / 15.0 / (self.farmer.livestock_records[0].herd_size if self.farmer.livestock_records else 1)), 2),
            "status": self.status,
            "farmer_notes": self.farmer_notes,
            "supplier_notes": self.supplier_notes,
            "requested_at": self.requested_at.isoformat() if self.requested_at else None,
        }

# ── Community & Forum 

class DirectMessage(db.Model):
    __tablename__ = 'direct_messages'
    id = db.Column(db.Integer, primary_key=True)
    sender_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    receiver_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    content = db.Column(db.Text, nullable=False)
    is_read = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    sender = db.relationship('User', foreign_keys=[sender_id])
    receiver = db.relationship('User', foreign_keys=[receiver_id])

    def to_dict(self):
        return {
            'id': self.id,
            'sender_id': self.sender_id,
            'receiver_id': self.receiver_id,
            'sender_name': f'{self.sender.first_name} {self.sender.last_name}',
            'receiver_name': f'{self.receiver.first_name} {self.receiver.last_name}',
            'content': self.content,
            'is_read': self.is_read,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

class ForumTopic(db.Model):
    __tablename__ = 'forum_topics'
    id = db.Column(db.Integer, primary_key=True)
    author_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    title = db.Column(db.String(250), nullable=False)
    content = db.Column(db.Text, nullable=False)
    category = db.Column(db.String(50)) # General, Tips, Deals
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    author = db.relationship('User', foreign_keys=[author_id])
    posts = db.relationship('ForumPost', backref='topic', lazy='dynamic', cascade='all, delete-orphan')

    def to_dict(self, include_posts=False):
        d = {
            'id': self.id,
            'author_id': self.author_id,
            'author_name': f'{self.author.first_name} {self.author.last_name}',
            'title': self.title,
            'content': self.content,
            'category': self.category,
            'reply_count': self.posts.count(),
            'created_at': self.created_at.isoformat() if self.created_at else None
        }
        if include_posts:
            d['posts'] = [p.to_dict() for p in self.posts.order_by('created_at').all()]
        return d

class ForumPost(db.Model):
    __tablename__ = 'forum_posts'
    id = db.Column(db.Integer, primary_key=True)
    topic_id = db.Column(db.Integer, db.ForeignKey('forum_topics.id'), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    content = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    author = db.relationship('User', foreign_keys=[user_id])

    def to_dict(self):
        return {
            'id': self.id,
            'topic_id': self.topic_id,
            'user_id': self.user_id,
            'author_name': f'{self.author.first_name} {self.author.last_name}',
            'content': self.content,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

class Notification(db.Model):
    __tablename__ = 'notifications'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    type = db.Column(db.String(50)) # 'message', 'order_update', 'system'
    title = db.Column(db.String(200))
    body = db.Column(db.Text)
    is_read = db.Column(db.Boolean, default=False)
    link_id = db.Column(db.String(100)) # Optional ID or reference
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User', backref=db.backref('notifications_list', lazy='dynamic'))

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'type': self.type,
            'title': self.title,
            'body': self.body,
            'is_read': self.is_read,
            'link_id': self.link_id,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

class SupplierBid(db.Model):
    __tablename__ = "supplier_bids"

    id = db.Column(db.Integer, primary_key=True)
    procurement_request_id = db.Column(db.Integer, db.ForeignKey("procurement_requests.id"), nullable=False)
    supplier_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False)
    
    # The bid specifics
    supplier_ingredient_id = db.Column(db.Integer, db.ForeignKey("feed_ingredients.id"))
    offered_quantity_kg = db.Column(db.Float, nullable=False)
    offered_cost_usd_per_kg = db.Column(db.Float, nullable=False)
    
    # Meta
    notes = db.Column(db.Text)
    status = db.Column(db.String(30), default="pending") # pending | accepted | rejected
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    # Relationships
    request = db.relationship("ProcurementRequest", backref=db.backref("bids", lazy="dynamic"))
    supplier = db.relationship("User", backref="bids_made", foreign_keys=[supplier_id])
    ingredient = db.relationship("FeedIngredient", backref="bids_placed")

    def to_dict(self):
        d = {
            "id": self.id,
            "procurement_request_id": self.procurement_request_id,
            "supplier_id": self.supplier_id,
            "supplier_ingredient_id": self.supplier_ingredient_id,
            "offered_quantity_kg": self.offered_quantity_kg,
            "offered_cost_usd_per_kg": self.offered_cost_usd_per_kg,
            "total_bid_cost": round(self.offered_quantity_kg * self.offered_cost_usd_per_kg, 2),
            "notes": self.notes,
            "status": self.status,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
        if self.ingredient:
            d['nutrient_specs'] = {
                'cp_pct': self.ingredient.crude_protein_pct,
                'me_mj_kg': self.ingredient.metabolizable_energy
            }
        return d
