import os
from datetime import timedelta

BASE_DIR = os.path.abspath(os.path.dirname(__file__))


class Config:
    # Security 
    SECRET_KEY = os.environ.get("SECRET_KEY", "farmfeed-secret-key-zim-2026-!@#$")
    JWT_SECRET_KEY = os.environ.get("JWT_SECRET_KEY", "farmfeed-jwt-zim-2026-!@#$")
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(days=30)

    #  Database 
    SQLALCHEMY_DATABASE_URI = f"sqlite:///{os.path.join(BASE_DIR, 'farmfeed.db')}"
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # CORS 
    CORS_ORIGINS = "*"

    # App 
    DEBUG = True
    HOST = "0.0.0.0"
    PORT = 5000

    #  ML Model Paths
    MODELS_DIR = os.path.join(BASE_DIR, "ml", "saved_models")
