from app import create_app
from database.db import db
from database.models import *

app = create_app()
with app.app_context():
    db.create_all()
    print("Database tables created/checked successfully.")
