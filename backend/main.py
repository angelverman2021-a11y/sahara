"""
SAHARA Backend — HTTP Server, Routing, Size Guard & Graceful Shutdown
Standard library only (zero external pip packages).
"""

import argparse
import json
import os
import signal
import sys
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any, Optional
from urllib.parse import parse_qs, unquote, urlparse

from backend.database import DEFAULT_DB_PATH, get_db, init_db
from backend.sync import (
    ValidationError,
    create_family_link,
    create_or_update_user,
    get_emergency_feed,
    get_family_members,
    get_messages_for_user,
    get_user,
    get_user_by_phone,
    sync_emergency_reports,
    sync_messages,
    update_user_status,
    validate_family,
    validate_user,
)

MAX_REQUEST_BYTES = 256 * 1024  # 256 KB


class SaharaServer(ThreadingHTTPServer):
    """Threading HTTP server with embedded database path."""
    def __init__(self, server_address, RequestHandlerClass, db_path: str = DEFAULT_DB_PATH):
        self.db_path = db_path
        super().__init__(server_address, RequestHandlerClass)


class SaharaHandler(BaseHTTPRequestHandler):
    """Request handler implementing strict size guarding, routing, and JSON API."""

    server_version = "SaharaSync/1.0"

    def log_message(self, format: str, *args: Any) -> None:
        """Custom clean logging."""
        sys.stderr.write(f"[{self.log_date_time_string()}] {args[0]} {args[1]} -> {args[2]}\n")

    def send_json(self, status_code: int, data: Any) -> None:
        """Send a JSON formatted response."""
        response_bytes = json.dumps(data, indent=2).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(response_bytes)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(response_bytes)

    def read_json_body(self) -> Any:
        """
        Reads and parses JSON payload with strict 256 KB size limit enforcement.
        Raises ValueError on size violation or syntax errors.
        """
        content_length_header = self.headers.get("Content-Length")
        if not content_length_header:
            raise ValidationError("Missing 'Content-Length' header.")

        try:
            content_length = int(content_length_header)
        except ValueError:
            raise ValidationError("Invalid 'Content-Length' header.")

        if content_length > MAX_REQUEST_BYTES:
            # Drain body to avoid TCP RST on client before HTTP 413 can be read
            self.close_connection = True
            remaining = content_length
            while remaining > 0:
                chunk = self.rfile.read(min(remaining, 65536))
                if not chunk:
                    break
                remaining -= len(chunk)
            raise OverflowError(f"Request payload exceeds maximum allowed size of {MAX_REQUEST_BYTES} bytes.")

        raw_body = self.rfile.read(content_length)
        if len(raw_body) != content_length:
            raise ValidationError("Incomplete request body received.")

        try:
            return json.loads(raw_body.decode("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError) as e:
            raise ValidationError(f"Malformed JSON payload: {str(e)}")

    def do_OPTIONS(self) -> None:
        """Handle CORS pre-flight requests."""
        self.send_response(HTTPStatus.NO_CONTENT)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self) -> None:
        """Route GET requests."""
        parsed_url = urlparse(self.path)
        path = parsed_url.path.rstrip("/")

        try:
            # 1. Health check
            if path == "/health" or path == "":
                self.send_json(HTTPStatus.OK, {
                    "status": "ok",
                    "system": "SAHARA Cloud Sync",
                    "wal": True,
                    "db": self.server.db_path,
                })
                return

            # 2. Phone Lookup for Discovery: GET /api/lookup/phone/<phone>
            if path.startswith("/api/lookup/phone/"):
                raw_phone = unquote(path[len("/api/lookup/phone/"):].strip())
                if not raw_phone:
                    self.send_json(HTTPStatus.BAD_REQUEST, {"error": "Missing phone number parameter."})
                    return
                try:
                    with get_db(self.server.db_path) as conn:
                        user = get_user_by_phone(conn, raw_phone)
                except ValidationError as e:
                    self.send_json(HTTPStatus.BAD_REQUEST, {"error": str(e)})
                    return
                if not user:
                    self.send_json(HTTPStatus.NOT_FOUND, {"error": "User with this phone number not found."})
                    return
                # Returns user_id, name, status (phone is omitted)
                self.send_json(HTTPStatus.OK, user)
                return

            # 3. Get User Profile: GET /api/users/<user_id>
            if path.startswith("/api/users/"):
                user_id = path[len("/api/users/"):].strip()
                if not user_id:
                    self.send_json(HTTPStatus.BAD_REQUEST, {"error": "Missing user_id parameter."})
                    return
                with get_db(self.server.db_path) as conn:
                    user = get_user(conn, user_id)
                if not user:
                    self.send_json(HTTPStatus.NOT_FOUND, {"error": f"User '{user_id}' not found."})
                    return
                self.send_json(HTTPStatus.OK, user)
                return

            # 3. Get Family Members: GET /api/family/<user_id>
            if path.startswith("/api/family/"):
                user_id = path[len("/api/family/"):].strip()
                if not user_id:
                    self.send_json(HTTPStatus.BAD_REQUEST, {"error": "Missing user_id parameter."})
                    return
                with get_db(self.server.db_path) as conn:
                    members = get_family_members(conn, user_id)
                self.send_json(HTTPStatus.OK, members)
                return

            # 4. Get Synced Messages: GET /api/messages/<user_id>
            if path.startswith("/api/messages/"):
                user_id = path[len("/api/messages/"):].strip()
                if not user_id:
                    self.send_json(HTTPStatus.BAD_REQUEST, {"error": "Missing user_id parameter."})
                    return
                with get_db(self.server.db_path) as conn:
                    messages = get_messages_for_user(conn, user_id)
                self.send_json(HTTPStatus.OK, messages)
                return

            # 5. Get Emergency Priority Feed: GET /api/emergency/feed
            if path == "/api/emergency/feed":
                with get_db(self.server.db_path) as conn:
                    feed = get_emergency_feed(conn)
                self.send_json(HTTPStatus.OK, feed)
                return

            # Not Found
            self.send_json(HTTPStatus.NOT_FOUND, {"error": f"Endpoint '{self.path}' not found."})

        except Exception as e:
            self.send_json(HTTPStatus.INTERNAL_SERVER_ERROR, {"error": f"Internal server error: {str(e)}"})

    def do_POST(self) -> None:
        """Route POST requests with size checking and validation."""
        parsed_url = urlparse(self.path)
        path = parsed_url.path.rstrip("/")

        try:
            body = self.read_json_body()
        except OverflowError as e:
            self.send_json(HTTPStatus.REQUEST_ENTITY_TOO_LARGE, {"error": str(e)})
            return
        except ValidationError as e:
            self.send_json(HTTPStatus.BAD_REQUEST, {"error": str(e)})
            return
        except Exception as e:
            self.send_json(HTTPStatus.BAD_REQUEST, {"error": f"Invalid request body: {str(e)}"})
            return

        try:
            # 1. Register/Update User: POST /api/users
            if path == "/api/users":
                validated = validate_user(body)
                with get_db(self.server.db_path) as conn:
                    result = create_or_update_user(conn, validated)
                self.send_json(HTTPStatus.CREATED, result)
                return

            # 2. Update User Status: POST /api/users/<user_id>/status
            if path.startswith("/api/users/") and path.endswith("/status"):
                prefix = "/api/users/"
                suffix = "/status"
                user_id = path[len(prefix):-len(suffix)].strip()
                if not user_id:
                    self.send_json(HTTPStatus.BAD_REQUEST, {"error": "Missing user_id parameter in path."})
                    return
                if not isinstance(body, dict) or "status" not in body:
                    self.send_json(HTTPStatus.BAD_REQUEST, {"error": "Field 'status' is required."})
                    return
                with get_db(self.server.db_path) as conn:
                    result = update_user_status(conn, user_id, body["status"])
                self.send_json(HTTPStatus.OK, result)
                return

            # 2. Register Family Link: POST /api/family
            if path == "/api/family":
                validated = validate_family(body)
                with get_db(self.server.db_path) as conn:
                    result = create_family_link(conn, validated)
                self.send_json(HTTPStatus.CREATED, result)
                return

            # 3. Batch Sync Offline Messages: POST /api/sync/messages
            if path == "/api/sync/messages":
                with get_db(self.server.db_path) as conn:
                    result = sync_messages(conn, body)
                self.send_json(HTTPStatus.OK, result)
                return

            # 4. Batch Sync Emergency/SOS Reports: POST /api/sync/emergency
            if path == "/api/sync/emergency":
                with get_db(self.server.db_path) as conn:
                    result = sync_emergency_reports(conn, body)
                self.send_json(HTTPStatus.OK, result)
                return

            # Not Found
            self.send_json(HTTPStatus.NOT_FOUND, {"error": f"Endpoint '{self.path}' not found."})

        except ValidationError as e:
            self.send_json(HTTPStatus.BAD_REQUEST, {"error": str(e)})
        except Exception as e:
            self.send_json(HTTPStatus.INTERNAL_SERVER_ERROR, {"error": f"Internal server error: {str(e)}"})


def run_server(host: str = "0.0.0.0", port: int = 8000, db_path: str = DEFAULT_DB_PATH) -> None:
    """Initializes the database and runs the multithreaded HTTP server with graceful shutdown."""
    init_db(db_path)
    server = SaharaServer((host, port), SaharaHandler, db_path=db_path)

    def shutdown_signal_handler(signum, frame):
        print("\n[SAHARA] Graceful shutdown initiated. Closing database and HTTP server...")
        # Run shutdown in a background thread to prevent deadlocking the handler
        import threading
        threading.Thread(target=server.shutdown).start()

    signal.signal(signal.SIGINT, shutdown_signal_handler)
    signal.signal(signal.SIGTERM, shutdown_signal_handler)

    print(f"==================================================")
    print(f" SAHARA Backend Server Running                    ")
    print(f" Address: http://{host}:{port}                    ")
    print(f" Database: {db_path} (SQLite WAL mode)            ")
    print(f" Max Request Body: {MAX_REQUEST_BYTES // 1024} KB ")
    print(f" Press Ctrl+C to gracefully stop                  ")
    print(f"==================================================")

    try:
        server.serve_forever()
    finally:
        server.server_close()
        print("[SAHARA] Server closed cleanly.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="SAHARA Cloud Sync Backend Server")
    parser.add_argument("--host", type=str, default="0.0.0.0", help="Binding host address (default: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=8000, help="Binding port (default: 8000)")
    parser.add_argument("--db", type=str, default=DEFAULT_DB_PATH, help="Path to SQLite database file")
    args = parser.parse_args()

    run_server(host=args.host, port=args.port, db_path=args.db)
