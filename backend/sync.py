"""
SAHARA Backend — Business Logic, Strict Validation & Deduplication Engine
Standard library only (zero external pip packages).
"""

import time
from typing import Any, Dict, List, Optional, Tuple

VALID_MESSAGE_TYPES = {"SOS", "EMERGENCY", "FAMILY", "BROADCAST", "STATUS"}
VALID_PRIORITIES = {"Highest", "High", "Normal"}
VALID_STATUSES = {"PENDING", "SYNCED", "DELIVERED"}
VALID_EMERGENCY_TYPES = {"SOS", "HAZARD", "EVACUATION", "EMERGENCY"}

MAX_CONTENT_LENGTH = 2048  # Max 2 KB per message/report content


class ValidationError(Exception):
    """Raised when JSON input fails validation checks."""
    pass


# ---------------------------------------------------------------------------
# Strict Validation Handlers
# ---------------------------------------------------------------------------

def validate_user(data: Any) -> Dict[str, Any]:
    if not isinstance(data, dict):
        raise ValidationError("Payload must be a JSON object.")
    
    user_id = data.get("user_id")
    if not isinstance(user_id, str) or not user_id.strip():
        raise ValidationError("Field 'user_id' is required and must be a non-empty string.")
    if len(user_id) > 64:
        raise ValidationError("Field 'user_id' cannot exceed 64 characters.")

    name = data.get("name")
    if not isinstance(name, str) or not name.strip():
        raise ValidationError("Field 'name' is required and must be a non-empty string.")
    if len(name) > 128:
        raise ValidationError("Field 'name' cannot exceed 128 characters.")

    created_at = data.get("created_at")
    if created_at is not None:
        if not isinstance(created_at, int) or created_at < 0:
            raise ValidationError("Field 'created_at' must be a positive integer timestamp.")
    else:
        created_at = int(time.time())

    return {
        "user_id": user_id.strip(),
        "name": name.strip(),
        "created_at": created_at,
    }


def validate_family(data: Any) -> Dict[str, Any]:
    if not isinstance(data, dict):
        raise ValidationError("Payload must be a JSON object.")

    family_id = data.get("family_id")
    if not isinstance(family_id, str) or not family_id.strip():
        raise ValidationError("Field 'family_id' is required and must be a non-empty string.")

    user_id = data.get("user_id")
    if not isinstance(user_id, str) or not user_id.strip():
        raise ValidationError("Field 'user_id' is required and must be a non-empty string.")

    family_member_id = data.get("family_member_id")
    if not isinstance(family_member_id, str) or not family_member_id.strip():
        raise ValidationError("Field 'family_member_id' is required and must be a non-empty string.")

    if user_id.strip() == family_member_id.strip():
        raise ValidationError("Field 'user_id' and 'family_member_id' cannot be the same person.")

    relationship = data.get("relationship")
    if not isinstance(relationship, str) or not relationship.strip():
        raise ValidationError("Field 'relationship' is required and must be a non-empty string.")

    return {
        "family_id": family_id.strip(),
        "user_id": user_id.strip(),
        "family_member_id": family_member_id.strip(),
        "relationship": relationship.strip(),
    }


def validate_message(data: Any) -> Dict[str, Any]:
    if not isinstance(data, dict):
        raise ValidationError("Each message must be a JSON object.")

    message_id = data.get("message_id")
    if not isinstance(message_id, str) or not message_id.strip():
        raise ValidationError("Field 'message_id' is required and must be a non-empty string.")

    sender_id = data.get("sender_id")
    if not isinstance(sender_id, str) or not sender_id.strip():
        raise ValidationError("Field 'sender_id' is required and must be a non-empty string.")

    receiver_id = data.get("receiver_id")
    if not isinstance(receiver_id, str) or not receiver_id.strip():
        raise ValidationError("Field 'receiver_id' is required and must be a non-empty string.")

    msg_type = data.get("type")
    if msg_type not in VALID_MESSAGE_TYPES:
        raise ValidationError(f"Invalid 'type' '{msg_type}'. Must be one of {sorted(VALID_MESSAGE_TYPES)}.")

    priority = data.get("priority")
    if priority not in VALID_PRIORITIES:
        raise ValidationError(f"Invalid 'priority' '{priority}'. Must be one of {sorted(VALID_PRIORITIES)}.")

    content = data.get("content")
    if not isinstance(content, str):
        raise ValidationError("Field 'content' is required and must be a string.")
    if len(content) > MAX_CONTENT_LENGTH:
        raise ValidationError(f"Field 'content' exceeds maximum length of {MAX_CONTENT_LENGTH} characters.")

    ttl = data.get("ttl")
    if not isinstance(ttl, int) or ttl < 0:
        raise ValidationError("Field 'ttl' must be an integer >= 0.")

    status = data.get("status", "SYNCED")
    if status not in VALID_STATUSES:
        raise ValidationError(f"Invalid 'status' '{status}'. Must be one of {sorted(VALID_STATUSES)}.")

    timestamp = data.get("timestamp")
    if not isinstance(timestamp, int) or timestamp < 0:
        raise ValidationError("Field 'timestamp' must be a positive integer timestamp.")

    return {
        "message_id": message_id.strip(),
        "sender_id": sender_id.strip(),
        "receiver_id": receiver_id.strip(),
        "type": msg_type,
        "priority": priority,
        "content": content,
        "ttl": ttl,
        "status": status,
        "timestamp": timestamp,
    }


def validate_emergency_report(data: Any) -> Dict[str, Any]:
    if not isinstance(data, dict):
        raise ValidationError("Each emergency report must be a JSON object.")

    report_id = data.get("report_id")
    if not isinstance(report_id, str) or not report_id.strip():
        raise ValidationError("Field 'report_id' is required and must be a non-empty string.")

    sender_id = data.get("sender_id")
    if not isinstance(sender_id, str) or not sender_id.strip():
        raise ValidationError("Field 'sender_id' is required and must be a non-empty string.")

    report_type = data.get("type")
    if not isinstance(report_type, str) or report_type not in VALID_EMERGENCY_TYPES:
        raise ValidationError(f"Invalid 'type' '{report_type}'. Must be one of {sorted(VALID_EMERGENCY_TYPES)}.")

    priority = data.get("priority")
    if priority not in VALID_PRIORITIES:
        raise ValidationError(f"Invalid 'priority' '{priority}'. Must be one of {sorted(VALID_PRIORITIES)}.")

    details = data.get("details")
    if not isinstance(details, str):
        raise ValidationError("Field 'details' is required and must be a string.")
    if len(details) > MAX_CONTENT_LENGTH:
        raise ValidationError(f"Field 'details' exceeds maximum length of {MAX_CONTENT_LENGTH} characters.")

    location = data.get("location")
    if location is not None and not isinstance(location, str):
        raise ValidationError("Field 'location' must be a string if provided.")

    timestamp = data.get("timestamp")
    if not isinstance(timestamp, int) or timestamp < 0:
        raise ValidationError("Field 'timestamp' must be a positive integer timestamp.")

    return {
        "report_id": report_id.strip(),
        "sender_id": sender_id.strip(),
        "type": report_type,
        "location": location.strip() if location else None,
        "priority": priority,
        "details": details,
        "timestamp": timestamp,
    }


# ---------------------------------------------------------------------------
# Database CRUD & Deduplication Handlers
# ---------------------------------------------------------------------------

def create_or_update_user(conn, validated_user: Dict[str, Any]) -> Dict[str, Any]:
    """Inserts or updates a user profile."""
    cursor = conn.cursor()
    cursor.execute(
        """
        INSERT INTO users (user_id, name, created_at)
        VALUES (?, ?, ?)
        ON CONFLICT(user_id) DO UPDATE SET
            name = excluded.name;
        """,
        (validated_user["user_id"], validated_user["name"], validated_user["created_at"]),
    )
    return validated_user


def get_user(conn, user_id: str) -> Optional[Dict[str, Any]]:
    """Retrieves a user by user_id."""
    cursor = conn.cursor()
    cursor.execute("SELECT user_id, name, created_at FROM users WHERE user_id = ?;", (user_id,))
    row = cursor.fetchone()
    if not row:
        return None
    return dict(row)


def create_family_link(conn, validated_family: Dict[str, Any]) -> Dict[str, Any]:
    """
    Creates a family relationship after strictly checking that BOTH users exist.
    """
    cursor = conn.cursor()
    cursor.execute("SELECT user_id FROM users WHERE user_id = ?;", (validated_family["user_id"],))
    if not cursor.fetchone():
        raise ValidationError(f"User '{validated_family['user_id']}' does not exist in the database.")

    cursor.execute("SELECT user_id FROM users WHERE user_id = ?;", (validated_family["family_member_id"],))
    if not cursor.fetchone():
        raise ValidationError(f"Family member '{validated_family['family_member_id']}' does not exist in the database.")

    cursor.execute(
        """
        INSERT INTO families (family_id, user_id, family_member_id, relationship)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(family_id, user_id, family_member_id) DO UPDATE SET
            relationship = excluded.relationship;
        """,
        (
            validated_family["family_id"],
            validated_family["user_id"],
            validated_family["family_member_id"],
            validated_family["relationship"],
        ),
    )
    return validated_family


def get_family_members(conn, user_id: str) -> List[Dict[str, Any]]:
    """Retrieves all family members linked to a user with their profile names."""
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT f.family_id, f.family_member_id, u.name, f.relationship
        FROM families f
        JOIN users u ON f.family_member_id = u.user_id
        WHERE f.user_id = ?;
        """,
        (user_id,),
    )
    return [dict(row) for row in cursor.fetchall()]


def sync_messages(conn, raw_payload: Any) -> Dict[str, Any]:
    """
    Batch synchronizes offline messages with duplicate suppression.
    Expects a JSON list or a single JSON object.
    Returns counts of synced vs duplicate messages.
    """
    if isinstance(raw_payload, dict):
        raw_items = [raw_payload]
    elif isinstance(raw_payload, list):
        raw_items = raw_payload
    else:
        raise ValidationError("Payload must be a JSON array of messages or a single message object.")

    if len(raw_items) == 0:
        return {"synced": 0, "duplicates": 0, "total": 0}

    cursor = conn.cursor()
    synced_count = 0
    duplicate_count = 0
    now = int(time.time())

    for item in raw_items:
        msg = validate_message(item)
        
        # Check if already present to report accurate duplicate counts
        cursor.execute("SELECT 1 FROM messages WHERE message_id = ?;", (msg["message_id"],))
        if cursor.fetchone():
            duplicate_count += 1
            continue

        cursor.execute(
            """
            INSERT INTO messages (
                message_id, sender_id, receiver_id, type, priority, content, ttl, status, timestamp, synced_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            (
                msg["message_id"],
                msg["sender_id"],
                msg["receiver_id"],
                msg["type"],
                msg["priority"],
                msg["content"],
                msg["ttl"],
                msg["status"],
                msg["timestamp"],
                now,
            ),
        )
        synced_count += 1

    return {
        "synced": synced_count,
        "duplicates": duplicate_count,
        "total": len(raw_items),
    }


def get_messages_for_user(conn, user_id: str, limit: int = 100) -> List[Dict[str, Any]]:
    """Retrieves all messages for a specific recipient, newest first."""
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT message_id, sender_id, receiver_id, type, priority, content, ttl, status, timestamp, synced_at
        FROM messages
        WHERE receiver_id = ? OR receiver_id = 'BROADCAST'
        ORDER BY timestamp DESC
        LIMIT ?;
        """,
        (user_id, limit),
    )
    return [dict(row) for row in cursor.fetchall()]


def sync_emergency_reports(conn, raw_payload: Any) -> Dict[str, Any]:
    """
    Batch synchronizes SOS distress and emergency hazard reports with deduplication.
    """
    if isinstance(raw_payload, dict):
        raw_items = [raw_payload]
    elif isinstance(raw_payload, list):
        raw_items = raw_payload
    else:
        raise ValidationError("Payload must be a JSON array of emergency reports or a single report object.")

    if len(raw_items) == 0:
        return {"synced": 0, "duplicates": 0, "total": 0}

    cursor = conn.cursor()
    synced_count = 0
    duplicate_count = 0
    now = int(time.time())

    for item in raw_items:
        rpt = validate_emergency_report(item)

        cursor.execute("SELECT 1 FROM emergency_reports WHERE report_id = ?;", (rpt["report_id"],))
        if cursor.fetchone():
            duplicate_count += 1
            continue

        cursor.execute(
            """
            INSERT INTO emergency_reports (
                report_id, sender_id, type, location, priority, details, timestamp, synced_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """,
            (
                rpt["report_id"],
                rpt["sender_id"],
                rpt["type"],
                rpt["location"],
                rpt["priority"],
                rpt["details"],
                rpt["timestamp"],
                now,
            ),
        )
        synced_count += 1

    return {
        "synced": synced_count,
        "duplicates": duplicate_count,
        "total": len(raw_items),
    }


def get_emergency_feed(conn, limit: int = 100) -> List[Dict[str, Any]]:
    """
    Retrieves emergency reports sorted strictly by Priority:
    Highest > High > Normal, and within the same priority, newer messages first (timestamp DESC).
    """
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT report_id, sender_id, type, location, priority, details, timestamp, synced_at
        FROM emergency_reports
        ORDER BY 
            CASE priority 
                WHEN 'Highest' THEN 1 
                WHEN 'High' THEN 2 
                WHEN 'Normal' THEN 3 
                ELSE 4 
            END ASC,
            timestamp DESC
        LIMIT ?;
        """,
        (limit,),
    )
    return [dict(row) for row in cursor.fetchall()]
