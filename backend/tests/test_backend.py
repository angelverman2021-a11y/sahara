"""
SAHARA Backend — Comprehensive Test Suite
Validates all 9 core requirements plus phone discovery and auto-generated User ID.
Standard library only (zero external pip packages).
"""

import json
import os
import tempfile
import threading
import time
import unittest
import urllib.error
import urllib.request

from backend.database import get_db, init_db
from backend.main import MAX_REQUEST_BYTES, SaharaHandler, SaharaServer
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
    validate_emergency_report,
    validate_family,
    validate_message,
    validate_user,
)


class TestSaharaBackendUnit(unittest.TestCase):
    """Unit tests for validation, database persistence, TTL, priority ordering, and phone discovery."""

    def setUp(self):
        self.temp_db_file = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
        self.db_path = self.temp_db_file.name
        self.temp_db_file.close()
        init_db(self.db_path)

    def tearDown(self):
        for ext in ["", "-wal", "-shm"]:
            path = self.db_path + ext
            if os.path.exists(path):
                try:
                    os.remove(path)
                except OSError:
                    pass

    # 1. Validation & Auto-generated User ID
    def test_user_validation_and_creation(self):
        with get_db(self.db_path) as conn:
            # Registration without client providing user_id
            user = validate_user({"name": "Aarav Sharma", "phone": "+919876543201", "status": "SAFE"})
            saved = create_or_update_user(conn, user)
            self.assertTrue(saved["user_id"].startswith("SH-"))
            self.assertEqual(saved["name"], "Aarav Sharma")
            self.assertEqual(saved["status"], "SAFE")

            # Verify retrieval by user_id
            fetched = get_user(conn, saved["user_id"])
            self.assertIsNotNone(fetched)
            self.assertEqual(fetched["name"], "Aarav Sharma")
            self.assertEqual(fetched["status"], "SAFE")

    def test_phone_lookup_and_omission(self):
        with get_db(self.db_path) as conn:
            user = validate_user({"name": "Mother", "phone": "+919876543202", "status": "SAFE"})
            saved = create_or_update_user(conn, user)

            # Lookup by phone
            profile = get_user_by_phone(conn, "+919876543202")
            self.assertIsNotNone(profile)
            self.assertEqual(profile["user_id"], saved["user_id"])
            self.assertEqual(profile["name"], "Mother")
            self.assertEqual(profile["status"], "SAFE")
            # CRITICAL PRIVACY CHECK: phone number MUST NOT be in lookup response!
            self.assertNotIn("phone", profile)

    def test_user_status_update(self):
        with get_db(self.db_path) as conn:
            user = validate_user({"name": "Bikash Borah", "phone": "+919876543205", "status": "SAFE"})
            saved = create_or_update_user(conn, user)
            uid = saved["user_id"]

            # Update status to SOS
            updated = update_user_status(conn, uid, "SOS")
            self.assertEqual(updated["status"], "SOS")

            # Lookup reflects updated status
            lookup = get_user_by_phone(conn, "+919876543205")
            self.assertEqual(lookup["status"], "SOS")

            # Invalid status rejected
            with self.assertRaises(ValidationError):
                update_user_status(conn, uid, "UNKNOWN_STATUS")

    def test_invalid_user_payloads(self):
        with self.assertRaises(ValidationError):
            validate_user({"name": "Test"})  # Missing phone
        with self.assertRaises(ValidationError):
            validate_user({"name": "", "phone": "+919876543201"})  # Empty name
        with self.assertRaises(ValidationError):
            validate_user({"name": "Test", "phone": "123"})  # Too short phone
        with self.assertRaises(ValidationError):
            validate_user("not a dict")

    # 2. Family Validation (Both users must exist)
    def test_family_validation_users_must_exist(self):
        with get_db(self.db_path) as conn:
            # Attempt to link users who do not exist yet
            with self.assertRaises(ValidationError) as ctx:
                create_family_link(conn, {
                    "family_id": "F01",
                    "user_id": "SH-9999",
                    "family_member_id": "SH-8888",
                    "relationship": "Mother",
                })
            self.assertIn("does not exist", str(ctx.exception))

            # Register both users with backend-generated User IDs
            u1 = create_or_update_user(conn, validate_user({"name": "Child", "phone": "+919876543211"}))
            u2 = create_or_update_user(conn, validate_user({"name": "Mother", "phone": "+919876543212"}))

            # Linking should now succeed using User IDs
            link = create_family_link(conn, {
                "family_id": "F01",
                "user_id": u1["user_id"],
                "family_member_id": u2["user_id"],
                "relationship": "Mother",
            })
            self.assertEqual(link["relationship"], "Mother")

            # Verify retrieval
            members = get_family_members(conn, u1["user_id"])
            self.assertEqual(len(members), 1)
            self.assertEqual(members[0]["family_member_id"], u2["user_id"])
            self.assertEqual(members[0]["name"], "Mother")

    def test_family_self_linking_rejected(self):
        with self.assertRaises(ValidationError):
            validate_family({
                "family_id": "F01",
                "user_id": "SH-1010",
                "family_member_id": "SH-1010",
                "relationship": "Self",
            })

    # 3. Message Deduplication, TTL, and Status
    def test_message_deduplication_and_ttl(self):
        with get_db(self.db_path) as conn:
            msg_batch = [
                {
                    "message_id": "MSG_001",
                    "sender_id": "NODE_A",
                    "receiver_id": "NODE_B",
                    "type": "SOS",
                    "priority": "Highest",
                    "content": "Water level rising rapidly at Sector 4.",
                    "ttl": 7,
                    "status": "SYNCED",
                    "timestamp": 1726000100,
                },
                {
                    "message_id": "MSG_002",
                    "sender_id": "NODE_B",
                    "receiver_id": "NODE_C",
                    "type": "FAMILY",
                    "priority": "Normal",
                    "content": "Safe at cyclone shelter.",
                    "ttl": 4,
                    "status": "PENDING",
                    "timestamp": 1726000200,
                },
            ]

            # First sync: 2 synced, 0 duplicates
            res1 = sync_messages(conn, msg_batch)
            self.assertEqual(res1["synced"], 2)
            self.assertEqual(res1["duplicates"], 0)

            # Second sync with exact same batch: 0 synced, 2 duplicates
            res2 = sync_messages(conn, msg_batch)
            self.assertEqual(res2["synced"], 0)
            self.assertEqual(res2["duplicates"], 2)

            # Verify message retrieval and TTL stored
            msgs = get_messages_for_user(conn, "NODE_B")
            self.assertEqual(len(msgs), 1)
            self.assertEqual(msgs[0]["message_id"], "MSG_001")
            self.assertEqual(msgs[0]["ttl"], 7)
            self.assertEqual(msgs[0]["priority"], "Highest")

    def test_message_content_limit_rejection(self):
        oversized_content = "X" * 2049
        with self.assertRaises(ValidationError) as ctx:
            validate_message({
                "message_id": "MSG_OVER",
                "sender_id": "N1",
                "receiver_id": "N2",
                "type": "EMERGENCY",
                "priority": "High",
                "content": oversized_content,
                "ttl": 5,
                "status": "SYNCED",
                "timestamp": 1000,
            })
        self.assertIn("exceeds maximum length", str(ctx.exception))

    def test_invalid_ttl_rejection(self):
        with self.assertRaises(ValidationError):
            validate_message({
                "message_id": "MSG_TTL",
                "sender_id": "N1",
                "receiver_id": "N2",
                "type": "EMERGENCY",
                "priority": "High",
                "content": "Help",
                "ttl": -1,  # negative TTL
                "status": "SYNCED",
                "timestamp": 1000,
            })

    # 4. Emergency Priority and Timestamp Ordering
    def test_emergency_priority_and_timestamp_ordering(self):
        with get_db(self.db_path) as conn:
            reports = [
                {
                    "report_id": "R_NORMAL",
                    "sender_id": "U1",
                    "type": "HAZARD",
                    "priority": "Normal",
                    "details": "Minor puddle near street",
                    "timestamp": 100,
                },
                {
                    "report_id": "R_HIGH",
                    "sender_id": "U2",
                    "type": "HAZARD",
                    "priority": "High",
                    "details": "Tree fell across road",
                    "timestamp": 200,
                },
                {
                    "report_id": "R_SOS_OLD",
                    "sender_id": "U3",
                    "type": "SOS",
                    "priority": "Highest",
                    "details": "Family on rooftop",
                    "timestamp": 150,
                },
                {
                    "report_id": "R_SOS_NEW",
                    "sender_id": "U4",
                    "type": "SOS",
                    "priority": "Highest",
                    "details": "Medical emergency trapped",
                    "timestamp": 300,
                },
            ]

            sync_emergency_reports(conn, reports)
            feed = get_emergency_feed(conn)

            # Must be ordered:
            # 1. R_SOS_NEW (Highest, ts 300)
            # 2. R_SOS_OLD (Highest, ts 150)
            # 3. R_HIGH    (High, ts 200)
            # 4. R_NORMAL  (Normal, ts 100)
            feed_ids = [r["report_id"] for r in feed]
            self.assertEqual(feed_ids, ["R_SOS_NEW", "R_SOS_OLD", "R_HIGH", "R_NORMAL"])


class TestSaharaBackendHTTPIntegration(unittest.TestCase):
    """End-to-end HTTP integration tests against live SaharaServer."""

    @classmethod
    def setUpClass(cls):
        cls.temp_db_file = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
        cls.db_path = cls.temp_db_file.name
        cls.temp_db_file.close()
        init_db(cls.db_path)

        # Bind to localhost on an ephemeral free port (port 0)
        cls.server = SaharaServer(("127.0.0.1", 0), SaharaHandler, db_path=cls.db_path)
        cls.port = cls.server.server_address[1]
        cls.base_url = f"http://127.0.0.1:{cls.port}"

        cls.server_thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.server_thread.start()
        time.sleep(0.1)

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        for ext in ["", "-wal", "-shm"]:
            path = cls.db_path + ext
            if os.path.exists(path):
                try:
                    os.remove(path)
                except OSError:
                    pass

    def make_request(self, method: str, endpoint: str, data=None):
        url = self.base_url + endpoint
        encoded_data = None
        headers = {}
        if data is not None:
            if isinstance(data, (dict, list)):
                encoded_data = json.dumps(data).encode("utf-8")
                headers["Content-Type"] = "application/json"
            elif isinstance(data, bytes):
                encoded_data = data
                headers["Content-Type"] = "application/octet-stream"

        req = urllib.request.Request(url, data=encoded_data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req) as resp:
                status = resp.status
                body = json.loads(resp.read().decode("utf-8"))
                return status, body
        except urllib.error.HTTPError as e:
            status = e.code
            try:
                body = json.loads(e.read().decode("utf-8"))
            except Exception:
                body = {"raw": e.read()}
            return status, body
        except (urllib.error.URLError, PermissionError) as e:
            if "Operation not permitted" in str(e):
                self.skipTest(f"Live socket loopback disabled in sandbox: {e}")
            raise

    def test_01_health(self):
        status, body = self.make_request("GET", "/health")
        self.assertEqual(status, 200)
        self.assertEqual(body["status"], "ok")
        self.assertTrue(body["wal"])

    def test_02_register_with_auto_generated_user_id(self):
        # Client registers without choosing user_id
        status, body = self.make_request("POST", "/api/users", {
            "name": "Manas Mohapatra",
            "phone": "+919876543211",
            "status": "SAFE",
        })
        self.assertEqual(status, 201)
        self.assertTrue(body["user_id"].startswith("SH-"))
        self.assertEqual(body["name"], "Manas Mohapatra")
        self.assertEqual(body["status"], "SAFE")

        # Save generated user_id for subsequent tests
        self.__class__.user1_id = body["user_id"]

    def test_03_phone_lookup_and_privacy(self):
        # Search for user by phone
        status, body = self.make_request("GET", "/api/lookup/phone/%2B919876543211")
        self.assertEqual(status, 200)
        self.assertEqual(body["user_id"], self.__class__.user1_id)
        self.assertEqual(body["name"], "Manas Mohapatra")
        self.assertEqual(body["status"], "SAFE")
        # Ensure phone number is NOT returned in response
        self.assertNotIn("phone", body)

        # Lookup non-existent phone
        status, body = self.make_request("GET", "/api/lookup/phone/9999999999")
        self.assertEqual(status, 404)

    def test_04_update_user_status_http(self):
        user_id = getattr(self.__class__, "user1_id", None)
        if not user_id:
            self.skipTest("user1_id not available (test_02 skipped)")
        # Update status to NEEDS_HELP
        status, body = self.make_request(
            "POST",
            f"/api/users/{user_id}/status",
            {"status": "NEEDS_HELP"},
        )
        self.assertEqual(status, 200)
        self.assertEqual(body["status"], "NEEDS_HELP")

        # Phone lookup now reflects new status
        status, body = self.make_request("GET", "/api/lookup/phone/%2B919876543211")
        self.assertEqual(status, 200)
        self.assertEqual(body["status"], "NEEDS_HELP")

    def test_05_family_validation_and_link(self):
        # Register second user
        status, body = self.make_request("POST", "/api/users", {
            "name": "Smruti Mohapatra",
            "phone": "+919876543212",
            "status": "SAFE",
        })
        self.assertEqual(status, 201)
        user2_id = body["user_id"]

        # Link successfully using the backend-generated User IDs
        status, body = self.make_request("POST", "/api/family", {
            "family_id": "FAM_01",
            "user_id": self.__class__.user1_id,
            "family_member_id": user2_id,
            "relationship": "Sister",
        })
        self.assertEqual(status, 201)

        # Query family members
        status, body = self.make_request("GET", f"/api/family/{self.__class__.user1_id}")
        self.assertEqual(status, 200)
        self.assertEqual(len(body), 1)
        self.assertEqual(body[0]["family_member_id"], user2_id)
        self.assertEqual(body[0]["relationship"], "Sister")

    def test_06_sync_messages_and_deduplication(self):
        messages = [
            {
                "message_id": "MSG_CYCLONE_1",
                "sender_id": "NODE_A",
                "receiver_id": "NODE_D",
                "type": "EMERGENCY",
                "priority": "High",
                "content": "Shelter open at school hall.",
                "ttl": 8,
                "status": "SYNCED",
                "timestamp": 1726000500,
            }
        ]

        # First sync
        status, body = self.make_request("POST", "/api/sync/messages", messages)
        self.assertEqual(status, 200)
        self.assertEqual(body["synced"], 1)
        self.assertEqual(body["duplicates"], 0)

        # Duplicate sync
        status, body = self.make_request("POST", "/api/sync/messages", messages)
        self.assertEqual(status, 200)
        self.assertEqual(body["synced"], 0)
        self.assertEqual(body["duplicates"], 1)

        # Query message for receiver
        status, body = self.make_request("GET", "/api/messages/NODE_D")
        self.assertEqual(status, 200)
        self.assertEqual(len(body), 1)
        self.assertEqual(body[0]["message_id"], "MSG_CYCLONE_1")

    def test_07_emergency_sync_and_feed(self):
        reports = [
            {
                "report_id": "EMERG_01",
                "sender_id": "NODE_X",
                "type": "SOS",
                "location": "Puri Beach Road",
                "priority": "Highest",
                "details": "Severe flooding, medical help required.",
                "timestamp": 1726000999,
            }
        ]
        status, body = self.make_request("POST", "/api/sync/emergency", reports)
        self.assertEqual(status, 200)
        self.assertEqual(body["synced"], 1)

        status, body = self.make_request("GET", "/api/emergency/feed")
        self.assertEqual(status, 200)
        self.assertTrue(any(r["report_id"] == "EMERG_01" for r in body))

    def test_08_oversized_payload_returns_413(self):
        # Generate payload larger than 256 KB (e.g. 270 KB)
        oversized_bytes = b"{" + b"A" * (MAX_REQUEST_BYTES + 5000) + b"}"
        status, body = self.make_request("POST", "/api/sync/messages", data=oversized_bytes)
        self.assertEqual(status, 413)
        self.assertIn("exceeds maximum allowed size", body["error"])


if __name__ == "__main__":
    unittest.main()
