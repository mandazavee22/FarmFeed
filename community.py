"""
FarmFeed — Community Routes
============================
Handles open forum discussions and private direct messages.
"""

from flask import Blueprint, request
from flask_jwt_extended import jwt_required, get_jwt_identity

from database.db import db
from database.models import User, ForumTopic, ForumPost, DirectMessage, Notification
from utils.helpers import success_response, error_response, validate_required_fields

community_bp = Blueprint("community", __name__, url_prefix="/api/community")


# ── Forum ─────────────────────────────────────────────────────────────────────

@community_bp.route("/forum", methods=["GET"])
@jwt_required()
def get_forum_topics():
    """List all forum topics, newest first."""
    topics = ForumTopic.query.order_by(ForumTopic.created_at.desc()).limit(50).all()
    return success_response(data={"topics": [t.to_dict() for t in topics]})


@community_bp.route("/forum", methods=["POST"])
@jwt_required()
def create_forum_topic():
    """Create a new forum topic."""
    user_id = int(get_jwt_identity())
    data = request.get_json(silent=True) or {}

    title = (data.get("title") or "").strip()
    content = (data.get("content") or "").strip()
    category = (data.get("category") or "General").strip()

    if not title:
        return error_response("Title is required.", 422)
    if not content:
        return error_response("Content is required.", 422)
    valid_categories = ["General", "Tips", "Deals", "Alerts"]
    if category not in valid_categories:
        category = "General"

    topic = ForumTopic(
        author_id=user_id,
        title=title,
        content=content,
        category=category,
    )
    db.session.add(topic)
    db.session.commit()
    return success_response(data={"topic": topic.to_dict()}, message="Topic created.", status_code=201)


@community_bp.route("/forum/<int:topic_id>", methods=["GET"])
@jwt_required()
def get_forum_topic(topic_id):
    """Get topic details with all replies."""
    topic = ForumTopic.query.get(topic_id)
    if not topic:
        return error_response("Topic not found.", 404)
    return success_response(data={"topic": topic.to_dict(include_posts=True)})


@community_bp.route("/forum/<int:topic_id>/reply", methods=["POST"])
@jwt_required()
def reply_to_topic(topic_id):
    """Post a reply to a forum topic."""
    user_id = int(get_jwt_identity())
    topic = ForumTopic.query.get(topic_id)
    if not topic:
        return error_response("Topic not found.", 404)

    data = request.get_json(silent=True) or {}
    content = (data.get("content") or "").strip()
    if not content:
        return error_response("Reply content is required.", 422)

    post = ForumPost(topic_id=topic_id, user_id=user_id, content=content)
    db.session.add(post)
    db.session.commit()
    return success_response(data={"post": post.to_dict()}, message="Reply posted.", status_code=201)


# ── Direct Messages (Inbox) ───────────────────────────────────────────────────

@community_bp.route("/inbox", methods=["GET"])
@jwt_required()
def get_inbox():
    """
    Get conversations (threads) for the current user.
    Returns the latest message per conversation partner.
    """
    user_id = int(get_jwt_identity())

    # All messages where user is sender or receiver
    all_msgs = DirectMessage.query.filter(
        (DirectMessage.sender_id == user_id) | (DirectMessage.receiver_id == user_id)
    ).order_by(DirectMessage.created_at.desc()).all()

    # Deduplicate by conversation partner, keep only the latest
    seen = {}
    threads = []
    for msg in all_msgs:
        partner_id = msg.receiver_id if msg.sender_id == user_id else msg.sender_id
        if partner_id not in seen:
            seen[partner_id] = True
            partner = User.query.get(partner_id)
            threads.append({
                "partner_id": partner_id,
                "partner_name": f"{partner.first_name} {partner.last_name}" if partner else "Unknown",
                "last_message": msg.content,
                "is_read": msg.is_read,
                "created_at": msg.created_at.isoformat() if msg.created_at else None,
            })

    return success_response(data={"threads": threads})


@community_bp.route("/inbox/<int:partner_id>", methods=["GET"])
@jwt_required()
def get_conversation(partner_id):
    """Get all messages between the current user and a partner."""
    user_id = int(get_jwt_identity())

    msgs = DirectMessage.query.filter(
        ((DirectMessage.sender_id == user_id) & (DirectMessage.receiver_id == partner_id)) |
        ((DirectMessage.sender_id == partner_id) & (DirectMessage.receiver_id == user_id))
    ).order_by(DirectMessage.created_at.asc()).all()

    # Mark incoming messages as read
    for m in msgs:
        if m.receiver_id == user_id and not m.is_read:
            m.is_read = True
    db.session.commit()

    return success_response(data={"messages": [m.to_dict() for m in msgs]})


@community_bp.route("/message", methods=["POST"])
@jwt_required()
def send_message():
    """Send a private direct message to another user."""
    user_id = int(get_jwt_identity())
    data = request.get_json(silent=True) or {}

    receiver_id = data.get("receiver_id")
    content = (data.get("content") or "").strip()

    if not receiver_id:
        return error_response("receiver_id is required.", 422)
    if not content:
        return error_response("Message content is required.", 422)
    if int(receiver_id) == user_id:
        return error_response("You cannot message yourself.", 422)

    receiver = User.query.get(int(receiver_id))
    if not receiver:
        return error_response("Recipient not found.", 404)

    msg = DirectMessage(sender_id=user_id, receiver_id=int(receiver_id), content=content)
    db.session.add(msg)
    db.session.commit()
    return success_response(data={"message": msg.to_dict()}, message="Message sent.", status_code=201)


# ── Users List (for finding someone to message) ───────────────────────────────

@community_bp.route("/users", methods=["GET"])
@jwt_required()
def get_users():
    """Get list of all users for search/messaging (excludes self)."""
    me = int(get_jwt_identity())
    users = User.query.filter(User.id != me, User.is_active == True).all()
    return success_response(data={"users": [
        {"id": u.id, "name": f"{u.first_name} {u.last_name}", "role": u.role}
        for u in users
    ]})
