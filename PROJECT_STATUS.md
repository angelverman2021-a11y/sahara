# SAHARA — PROJECT STATUS

SAHARA is an offline emergency communication application designed for disasters such as floods and cyclones in India.

**Main goal:**
Allow people to communicate when mobile networks and internet are unavailable by using nearby phones as a peer-to-peer mesh.

---

## LOCKED FEATURES

Only these features are part of the current project:

1. **One-Tap SOS**
2. **Multi-Hop Mesh**
3. **Store-and-Forward**
4. **Battery Discipline**
5. **Emergency Broadcast**
6. **Person-to-Person Messaging**
7. **Family Finding through the same messaging/mesh system**

> **DO NOT introduce additional features unless explicitly requested.**

---

## CURRENT PROJECT STRUCTURE

```text
SAHARA/
├── dataset/
├── frontend/
└── backend/
```

> **Do NOT create additional top-level folders.**

---

## WHAT IS ALREADY COMPLETED

### 1. DATASET — DONE

`dataset/` contains exactly:

- `disasters_india.csv`
- `emergency_messages.csv`
- `family_test_data.csv`
- `test_users.csv`

Old/duplicate files were removed.

`test_users.csv` contains 28 simulated users with:
- `name`
- `phone`
- `status`
- `node_id`
- `device_model`
- `initial_battery`

Dataset is only for testing/simulation.

> **Do NOT modify it unless explicitly requested.**

---

### 2. BACKEND — DONE

`backend/` contains:

- `database.py`
- `main.py`
- `sync.py`
- `tests/test_backend.py`

Backend handles:

- User registration
- Automatic `user_id` generation
- Phone lookup
- User status
- Family relationships
- Message synchronization
- Emergency synchronization

**Identity rules:**

- `user_id`: Permanent SAHARA user identity.
- `phone`: ONLY for searching/lookup.
- `node_id`: Physical device identity used by the mesh.

**Backend verification:**
- 18/18 tests PASS.

> **Do NOT redesign the backend.**

---

### 3. MESSAGE MODEL — DONE

**File:**
`frontend/lib/models/message_model.dart`

Unified message structure contains:

- `message_id`
- `sender_id`
- `receiver_id`
- `sender_node_id`
- `receiver_node_id`
- `type`
- `priority`
- `content`
- `timestamp`
- `ttl`
- `status`

**Identity separation:**

- `sender_id = user_id`
- `receiver_id = user_id`
- `sender_node_id = physical node_id`
- `receiver_node_id = physical node_id`
- `phone = lookup only`

**Supported types:**
- `TEXT`
- `SOS`
- `BROADCAST`

**Supported priorities:**
- `Highest`
- `High`
- `Normal`

**Supported statuses:**
- `PENDING`
- `SYNCED`
- `DELIVERED`

Supports JSON and UTF-8 serialization and TTL decrement.

> **Do NOT create another message model.**

---

### 4. MESH ROUTING — DONE

**File:**
`frontend/lib/services/mesh_service.dart`

Core routing is implemented.

It supports:

- Peer management
- Deduplication
- TTL
- Multi-hop forwarding
- Store-and-forward buffer
- Direct messages
- SOS
- Broadcast
- Mock transport
- Mesh event streams

Mesh simulation:
$\text{A} \rightarrow \text{B} \rightarrow \text{C} \rightarrow \text{D}$

All required routing tests passed.

---

### 5. MESH SIMULATION — DONE

5/5 tests PASS:

1. **Direct TEXT:**
   $\text{A} \rightarrow \text{B} \rightarrow \text{C} \rightarrow \text{D}$
   $\text{TTL } 8 \rightarrow 7 \rightarrow 6 \rightarrow 5$

2. **Duplicate message:**
   Duplicate `message_id` is discarded.

3. **Store-and-forward:**
   D disconnected $\rightarrow$ C stores message $\rightarrow$ D reconnects $\rightarrow$ C forwards $\rightarrow$ D receives.

4. **SOS:**
   $\text{A} \rightarrow \text{B} \rightarrow \text{C} \rightarrow \text{D}$
   B, C and D receive SOS and relay it.
   No duplicate/infinite loops.

5. **BROADCAST:**
   All reachable nodes receive the broadcast exactly once.

> **IMPORTANT:**
> This proves the routing logic.
> It does NOT yet prove real phone-to-phone communication.

---

## WHAT STILL NEEDS TO BE DONE

The remaining work should be completed in this order:

---

### STEP 1 — REAL ANDROID P2P TRANSPORT

**CURRENT STATUS:**
TODO

Connect the existing `MeshTransport` interface to real Android phone-to-phone communication.

**Preferred approach:**
Evaluate Google Nearby Connections first.

**Before implementation:**
- Inspect `pubspec.yaml`.
- Inspect Android configuration.
- Check required permissions.
- Check plugin compatibility.
- Consider APK size.
- Do NOT rewrite `MeshService` routing logic.

**The transport should only handle:**
- `DISCOVERY`
- `CONNECT`
- `SEND BYTES`
- `RECEIVE BYTES`
- `DISCONNECT EVENTS`

**`MeshService` continues handling:**
- `TTL`
- `DEDUPLICATION`
- `FORWARDING`
- `SOS`
- `BROADCAST`
- `STORE-AND-FORWARD`

**FIRST TEST:**
$\text{Phone A} \leftrightarrow \text{Phone B}$

$\text{A discovers B} \rightarrow \text{connects} \rightarrow \text{sends MessagePacket} \rightarrow \text{B receives} \rightarrow \text{B decodes MessagePacket}$

> **Do NOT start with 4-phone testing.**

---

### STEP 2 — SQLITE

**CURRENT STATUS:**
TODO / IN PROGRESS

Implement SQLite inside:
`frontend/lib/database/`

**Purpose:**
- Save sent messages
- Save received messages
- Save pending messages
- Store-and-forward persistence
- Save seen message IDs
- Save/cache family contacts where required

SQLite must use the existing Message Model.

> **Do NOT create a second message/storage architecture.**

---

### STEP 3 — FLUTTER UI

**CURRENT STATUS:**
IN PROGRESS

UI belongs inside:
- `frontend/lib/screens/`
- `frontend/lib/widgets/`

**Required screens:**
- Login/Register
- Home
- Find Person
- Person Profile
- Messages/Chat
- Family
- SOS
- Emergency Broadcast

UI should call the existing services/models/database.

> **UI must NOT contain mesh routing logic.**

---

### STEP 4 — INTEGRATE UI + SQLITE + MESH

Connect the components:

```text
UI
 ↓
Message Model
 ↓
SQLite
 ↓
MeshService
 ↓
Real P2P Transport
```

**Incoming:**

```text
Real P2P Transport
 ↓
MeshService
 ↓
Message Model
 ↓
SQLite
 ↓
UI
```

---

### STEP 5 — FAMILY FINDING

Family finding uses the existing user system.

**Flow:**
$\text{Phone number entered} \rightarrow \text{lookup user} \rightarrow \text{show basic profile/status} \rightarrow \text{send message} \rightarrow \text{optionally save as family member}$

Family messages use the SAME mesh system.
No continuous tracking.
No separate family tracking system.

---

### STEP 6 — REAL MULTI-HOP TEST

After two-phone communication works:

Test with:
$\text{Phone A} \rightarrow \text{Phone B} \rightarrow \text{Phone C} \rightarrow \text{Phone D}$

**Verify:**
- Direct message
- TTL
- Deduplication
- Store-and-forward
- SOS
- Emergency broadcast

This must work on real Android devices, not only `MockMeshTransport`.

---

### STEP 7 — BATTERY DISCIPLINE

Implement lightweight battery-saving behavior.

**Goal:**
Avoid unnecessary discovery, connections, and forwarding when battery is low.

Do NOT introduce heavy background processing.
Keep this lightweight and suitable for emergency use.

---

### STEP 8 — FINAL INTEGRATION TESTING

Test the complete application:
- Registration
- User ID generation
- Phone lookup
- Family linking
- Person-to-person messaging
- SOS
- Emergency broadcast
- Offline mesh
- Multi-hop
- Store-and-forward
- Deduplication
- TTL
- Battery behavior
- SQLite persistence
- Online backend sync when internet returns

---

### STEP 9 — APK / HACKATHON BUILD

**Final tasks:**
- Build Android APK
- Prefer `arm64-v8a` build
- Check APK size
- Remove unnecessary dependencies
- Test on real Android phones
- Verify permissions
- Verify offline operation
- Prepare final demo

**Target APK:**
Approximately 8–10 MB if realistically achievable.

> **Do NOT claim that this size is guaranteed.**

---

## TEAM / WORK SEPARATION

**FRONTEND UI + SQLITE SIDE:**
- Flutter screens
- Widgets
- Message Model
- SQLite

**MESH/BACKEND SIDE:**
- `MeshService`
- Real P2P transport
- Backend
- Integration of mesh transport

> **IMPORTANT:**
> Both sides work inside `frontend/`, but their responsibilities should remain separated.

---

## IMPORTANT ID RULES

- **`user_id`**: Human's permanent SAHARA identity.
- **`phone`**: Only search/lookup key.
- **`node_id`**: Physical phone/device identity used for mesh routing.

**NEVER:**
- Use phone as mesh routing ID.
- Generate `user_id` from phone.
- Replace `node_id` with phone.
- Mix `user_id` and `node_id`.

---

## IMPORTANT DEVELOPMENT RULES

Before making changes:

1. Read `PROJECT_STATUS.md`.
2. Inspect the actual repository.
3. Check whether the requested feature already exists.
4. Do not duplicate existing code.
5. Do not rewrite completed components unnecessarily.
6. Do not modify another component's responsibility without reason.
7. Do not modify `dataset/` or `backend/` unless specifically requested.
8. Do not add unnecessary dependencies.
9. Do not create new top-level folders.
10. Keep the architecture simple.

---

## CURRENT STATUS — QUICK VIEW

| Component | Status |
|---|:---:|
| **DATASET** | ✅ DONE |
| **BACKEND** | ✅ DONE |
| **BACKEND TESTS** | ✅ 18/18 PASS |
| **MESSAGE MODEL** | ✅ DONE |
| **MESH ROUTING** | ✅ DONE |
| **MESH SIMULATION** | ✅ 5/5 PASS |
| **REAL P2P TRANSPORT** | ⏳ TODO |
| **SQLITE** | ⏳ TODO / IN PROGRESS |
| **FLUTTER UI** | ⏳ IN PROGRESS |
| **MESH + SQLITE INTEGRATION** | ⏳ TODO |
| **UI + MESH INTEGRATION** | ⏳ TODO |
| **REAL 4-PHONE TEST** | ⏳ TODO |
| **BATTERY DISCIPLINE** | ⏳ TODO |
| **FINAL APK TEST** | ⏳ TODO |

---

## NEXT IMMEDIATE TASK

The next technical priority is:

**REAL ANDROID P2P TRANSPORT**

Start with:
$$\text{PHONE A} \leftrightarrow \text{PHONE B}$$

Do not modify the already-tested `MeshService` routing logic.

After $\text{A} \leftrightarrow \text{B}$ works, move to:
$$\text{A} \rightarrow \text{B} \rightarrow \text{C} \rightarrow \text{D}$$

---

**END OF PROJECT STATUS**
