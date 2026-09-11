"""
SAHARA Backend — Database Layer
SQLite connection manager with WAL mode and short-lived connections.
Standard library only (zero external pip packages).
"""

import sqlite3
import time
from contextlib import contextmanager
from typing import Generator

DEFAULT_DB_PATH = "sahara.db"

INIT_SQL = """
PRAGMA journal_mode = WAL;
PRAGMA busy_timeout = 5000;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
    user_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS families (
    family_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    family_member_id TEXT NOT NULL,
    relationship TEXT NOT NULL,
    PRIMARY KEY (family_id, user_id, family_member_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (family_member_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS messages (
    message_id TEXT PRIMARY KEY,
    sender_id TEXT NOT NULL,
    receiver_id TEXT NOT NULL,
    type TEXT NOT NULL,
    priority TEXT NOT NULL,
    content TEXT NOT NULL,
    ttl INTEGER NOT NULL,
    status TEXT NOT NULL,
    timestamp INTEGER NOT NULL,
    synced_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_messages_receiver ON messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_priority ON messages(priority);
CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp DESC);

CREATE TABLE IF NOT EXISTS emergency_reports (
    report_id TEXT PRIMARY KEY,
    sender_id TEXT NOT NULL,
    type TEXT NOT NULL,
    location TEXT,
    priority TEXT NOT NULL,
    details TEXT NOT NULL,
    timestamp INTEGER NOT NULL,
    synced_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_emergency_priority_time ON emergency_reports(priority, timestamp DESC);
"""


def init_db(db_path: str = DEFAULT_DB_PATH) -> None:
    """Initialize SQLite database tables and indexes."""
    conn = sqlite3.connect(db_path, timeout=5.0)
    try:
        conn.executescript(INIT_SQL)
        conn.commit()
    finally:
        conn.close()


@contextmanager
def get_db(db_path: str = DEFAULT_DB_PATH) -> Generator[sqlite3.Connection, None, None]:
    """
    Context manager providing a safe, short-lived SQLite connection per request.
    Enforces WAL mode, busy timeout, foreign keys, and dictionary-like row factory.
    Automatically commits on success or rolls back on exception.
    """
    conn = sqlite3.connect(db_path, timeout=5.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode = WAL;")
    conn.execute("PRAGMA busy_timeout = 5000;")
    conn.execute("PRAGMA foreign_keys = ON;")
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
