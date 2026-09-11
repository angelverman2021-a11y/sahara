# SAHARA — Cloud Synchronization Backend

## Overview

The `backend/` directory houses the minimal, lightweight cloud synchronization service for SAHARA.

> [!IMPORTANT]
> **Strict Decoupling Policy:**
> * **Zero Mesh Dependency:** The backend plays **no role in peer discovery, local multi-hop routing, or offline message delivery**. The entire emergency mesh operates autonomously on the devices.
> * **Asynchronous Sync Only:** The backend only receives and processes data when an individual user's device eventually reconnects to the internet.
> * **No Frontend Interference:** Backend schema changes or server downtime never impact the offline operational readiness of the frontend mobile app.

---

## Directory Architecture

```text
backend/
│
├── routes/       # API endpoints (users, family, sync-messages, sync-emergency)
├── services/     # Cloud sync processing, deduplication, conflict resolution
└── database/     # Minimal relational or document schema definitions & migrations
```

---

## Backend Responsibilities & Endpoints

### 1. User Directory (`/routes/users`)
Maintains basic civilian user records for identity resolution when internet is available:
- `user_id`, `name`, `created_at`

### 2. Family Graph Synchronization (`/routes/family`)
Persists pre-registered family connections:
- `family_id`, `user_id`, `family_member_id`, `relationship`

### 3. Offline Message Uplink (`/routes/sync/messages`)
When a smartphone regains 4G/5G/Wi-Fi connectivity, it transmits previously queued offline messages to the cloud to reach authorities or recipients outside the disaster zone:
- `message_id`, `sender_id`, `receiver_id`, `type`, `priority`, `timestamp`, `status`

### 4. Emergency Incident Synchronization (`/routes/sync/emergency`)
Collects aggregated SOS signals and broadcast incident reports for disaster response organizations and relief teams:
- `report_id`, `sender_id`, `type`, `location`, `timestamp`, `priority`
