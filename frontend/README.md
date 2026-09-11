# SAHARA — Mobile Frontend (Client & Mesh Engine)

## Overview

The `frontend/` directory contains the core SAHARA client application (built with Flutter for Android). It is responsible for all on-device offline emergency functionality, local UI, device discovery, and mesh routing.

> [!IMPORTANT]
> **Strict Decoupling Policy:**
> * **Frontend Autonomy:** The frontend operates with 100% independence. It **must never depend on the backend** to execute peer discovery, mesh routing, message persistence, SOS dispatch, or family reachability checks.
> * **Zero Dataset Pollution:** Files from `dataset/` must **never** be imported or bundled into the application assets. All production data and schemas are maintained natively in local SQLite storage.
> * **Strict Footprint Limit:** The compiled APK must stay within the **8–10 MB limit** to guarantee seamless device-to-device Bluetooth sharing during emergencies.

---

## Directory Architecture

```text
frontend/
│
├── lib/
│   ├── screens/       # Minimalist emergency screens (Home, SOS, Family, Broadcast, Messages)
│   ├── widgets/       # Reusable lightweight UI widgets (SOS button, Mesh status, Battery indicator)
│   ├── models/        # Data models (Message, User, Family, EmergencyReport)
│   ├── database/      # Local SQLite persistence (Store & Forward, Seen message deduplication)
│   └── services/      # Mesh engine, P2P discovery, Battery discipline, Location, Cloud sync
└── assets/            # Lightweight icons & sound cues (strictly audited for 8-10MB limit)
```

---

## Core Modules & Responsibilities

### 1. Minimal UI (`screens/` & `components/`)
Designed strictly around the **"Open → Understand → Act"** paradigm:
* **Home Screen:** Immediate glanceable status (e.g., `12 PEOPLE NEARBY`, `Mesh: ACTIVE`, `Battery: 76%`), prominent `[ SOS ]` trigger, and quick access to `[ MESSAGES ]`, `[ FAMILY ]`, and `[ BROADCAST ]`.
* **Zero Bloat:** No animations, heavy images, continuous map tiles, social feeds, or complex onboarding.

### 2. Mesh & Discovery Engine (`services/`)
* **Discovery Layer:** Google Nearby Connections (P2P Cluster / Star strategy) with fallback abstractions for BLE / Wi-Fi Direct.
* **Routing & Relay Engine:**
  - Dynamic hop forwarding: $\text{Phone A} \rightarrow \text{Phone B} \rightarrow \text{Phone C} \rightarrow \text{Phone D}$.
  - Hop counter decrement ($\text{TTL} = 8 \rightarrow 7 \rightarrow \dots$).
  - Deduplication via globally unique `message_id`.
* **Store-and-Forward Engine:** Local persistence via SQLite. Queues outgoing and relay messages when next-hop nodes are unreachable; dispatches automatically when peers re-enter radio range.
* **Battery Governor:**
  - `> 60%`: Full discovery and continuous mesh relaying.
  - `30% - 60%`: Low-frequency discovery polling intervals.
  - `< 30%`: SOS and high-priority emergency packets only; halts low-priority message relaying to safeguard device life.
