

from flask import Flask, jsonify
from flask_jwt_extended import JWTManager
from flask_cors import CORS

from config import Config
from database.db import init_db
from routes.auth import auth_bp
from routes.farmer import farmer_bp
from routes.supplier import supplier_bp
from routes.community import community_bp


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    # Extensions 
    CORS(app, origins=Config.CORS_ORIGINS)
    JWTManager(app)
    init_db(app)

    # Blueprints 
    app.register_blueprint(auth_bp)
    app.register_blueprint(farmer_bp)
    app.register_blueprint(supplier_bp)
    app.register_blueprint(community_bp)

    # ── Health check
    @app.route("/api/health", methods=["GET"])
    def health():
        return jsonify({
            "status": "ok",
            "app": "FarmFeed API",
            "version": "1.0.0",
            "message": "Server is running. Zimbabwe Livestock Feed Optimization System.",
        })

    # ── JWT error handlers 
    @app.errorhandler(404)
    def not_found(e):
        return jsonify({"success": False, "message": "Endpoint not found."}), 404

    @app.errorhandler(405)
    def method_not_allowed(e):
        return jsonify({"success": False, "message": "Method not allowed."}), 405

    @app.errorhandler(500)
    def server_error(e):
        return jsonify({"success": False, "message": "Internal server error."}), 500

    return app


if __name__ == "__main__":
    app = create_app()
    print("=" * 55)
    print("   FarmFeed API Server Starting...")
    print(f"   Listening on http://0.0.0.0:{Config.PORT}")
    print(f"   Flutter device: http://10.50.1.253:{Config.PORT}/api")
    print("=" * 55)
    app.run(host=Config.HOST, port=Config.PORT, debug=Config.DEBUG)
