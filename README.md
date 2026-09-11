# SAHARA — Offline Emergency Communication System

> **"When infrastructure fails, nearby people become the communication network."**

SAHARA is a lightweight, offline-first emergency communication system engineered specifically for **flood and cyclone disaster scenarios in India**. When cellular networks and internet infrastructure collapse, SAHARA transforms nearby smartphones into a temporary, decentralized mesh network. Civilians can send one-tap SOS alerts, find separated family members, broadcast critical safety information, and communicate peer-to-peer—all without cell towers or internet access.

---

## 🏗️ Repository Architecture & Strict Decoupling Rules

The repository is organized strictly into **three independent top-level folders**:

```text
SAHARA/
│
├── dataset/      # Disaster scenarios, test users, and simulation datasets
├── frontend/     # Core offline-first Android/Flutter application & mesh engine
└── backend/      # Minimal optional cloud sync service (when internet returns)
```

> [!IMPORTANT]
> **Strict Module Isolation Policy:**
> * **`frontend/`** is completely decoupled from `backend/` and `dataset/`. The mobile app operates with 100% autonomy in zero-connectivity environments. It does not depend on backend APIs to function and will never bundle raw datasets directly into the client binary.
> * **`backend/`** is strictly auxiliary. It only syncs data when connectivity is restored and does not control, manage, or interfere with frontend mesh routing or offline logic.
> * **`dataset/`** is purely for simulation, testing, and benchmarking. It is strictly separated from frontend production assets and backend runtime databases.

---

## 📁 Folder Responsibilities

| Directory | Purpose | Key Responsibilities |
| :--- | :--- | :--- |
| [`frontend/`](./frontend/) | **Core Mobile Application** | Minimal UI, Nearby discovery (Google Nearby Connections / BLE / Wi-Fi Direct), multi-hop mesh relay, store-and-forward queue, local SQLite persistence, battery discipline. Strict **8–10 MB** size limit. |
| [`backend/`](./backend/) | **Cloud Synchronization** | Optional server-side sync when internet is restored (user directory, family relationships, synchronizing offline emergency reports and messages). |
| [`dataset/`](./dataset/) | **Testing & Simulation Data** | Realistic flood and cyclone disaster datasets (India only), emergency message corpus, simulated user nodes, and family topology test cases. |

---

## ⚡ Core Features

### 1. One-Tap SOS
Send an immediate distress signal with a single press.
- **Packet Contents:** User ID, Emergency Status, GPS Location (if available), Timestamp, Battery Level.
- **Priority:** Highest priority packet across the mesh.

### 2. Multi-Hop Mesh Communication
Every phone running SAHARA acts as an autonomous relay node:
$$\text{Phone A} \longrightarrow \text{Phone B} \longrightarrow \text{Phone C} \longrightarrow \text{Phone D}$$
- Automatic discovery and local connection establishment.
- Application-level routing without requiring native Bluetooth Mesh hardware support.

### 3. Store and Forward
If a destination or intermediate hop is temporarily unavailable:
1. The message is persisted locally in an on-device SQLite database.
2. When a new suitable peer node comes into range, the queued message is automatically dispatched.

### 4. Duplicate Prevention & TTL Control
- **Unique Message IDs:** (`message_id`) ensure nodes discard already-processed messages immediately, preventing broadcast storms.
- **Time-to-Live (TTL):** Each message carries a hop limit (e.g., $\text{TTL} = 8$), decremented at each hop. Packets with $\text{TTL} = 0$ are dropped.

### 5. Battery Discipline
Communication protocols automatically adapt to the device's remaining power to preserve the phone as lifelines:
- **Battery > 60%:** Normal discovery frequency and full mesh relay.
- **Battery 30%–60%:** Reduced peer discovery frequency.
- **Battery < 30%:** Prioritizes SOS and critical emergency traffic only.

### 6. Emergency Broadcast
Allows any node or authority to broadcast hyper-local hazard updates (e.g., *"Road blocked near Gate 2. Water level rising."*) that propagate to all reachable nodes across the mesh.

### 7. Person-to-Person Messaging
Send direct messages across multiple hops to specific recipients without intermediate nodes inspecting message payloads.

### 8. Family Finding
Assigns temporary node identifiers (e.g., `NODE_A72`) to track reachability and hop distance to family members across the mesh:
```text
YOU  ──▶  NODE_21  ──▶  NODE_43  ──▶  MOTHER (Reachable | 3 hops)
```

---

## 📱 Target Constraints & Design Principles

- **Binary Size:** Strict target of **8–10 MB** maximum to allow rapid Bluetooth/side-loaded sharing in disaster zones.
- **Target Platform:** Low-end Android smartphones.
- **Minimal Stress-Friendly UI:** **"Open → Understand → Act"** with zero unnecessary animations, feeds, or dashboards.
- **Zero Internet Requirement:** The core application must function seamlessly with `Internet = OFF`.

---

## 🚀 Getting Started

Refer to the individual folder guides for detailed instructions:
- [Frontend Setup & Architecture](./frontend/README.md)
- [Backend Service & Synchronization](./backend/README.md)
- [Dataset Specifications & Benchmarks](./dataset/README.md)
