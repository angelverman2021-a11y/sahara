<div align="center">

<img src="frontend/assets/images/sahara_logo.png" alt="SAHARA Logo" width="450" />

# 🚨 SAHARA
### Offline-First Civilian Emergency Communication & Disaster Management System

[![Repository](https://img.shields.io/badge/Repository-GitHub-blue?style=for-the-badge&logo=github)](https://github.com/angelverman2021-a11y/sahara)[cite: 1]
[![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Python Backend](https://img.shields.io/badge/Backend-Python%203.9+-3776AB?style=for-the-badge&logo=python)](https://python.org)
[![SQLite Local DB](https://img.shields.io/badge/Database-SQLite-003B57?style=for-the-badge&logo=sqlite)](https://sqlite.org)

*When conventional cellular and internet infrastructure collapses during disasters, nearby smartphones become the communication network.*

</div>

---

## 🌩️ 1. The Problem & The Solution

<div align="center">

| 🛑 The Breakdown (When Infrastructure Fails) | 💡 The SAHARA Solution (Decoupled Mesh) |
| :--- | :--- |
| • Cellular towers & internet collapse instantly during floods and cyclones[cite: 3].<br>• Families cannot confirm safety or location.<br>• Communities remain completely isolated. | • Turns nearby smartphones into a decentralized local network[cite: 3].<br>• Operates **100% independently** of cell towers or internet[cite: 3].<br>• Relays emergency data dynamically across devices. |

</div>

---

## 🌐 2. How the Mesh Network Works (Visual Guide)

```text
               [ TOTAL INTERNET / CELLULAR BLACKOUT ]
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                     SAHARA MESH NETWORK                     │
│                                                             │
│   📱 Phone A  ◄──────►  📱 Phone B  ◄──────►  📱 Phone C    │
│  (Sender)               (Relay Node)           (Receiver)   │
└─────────────────────────────────────────────────────────────┘
          Messages hop dynamically across devices in real time.

--

### Component 4: Flooding & Deduplication State Machine Flowchart
*Explains the core routing logic without heavy algorithms.*
```markdown
##### 🔄 Inside the Relay Engine (Flooding + Deduplication)
```text
[ Incoming Packet Received ] 
             │
             ▼
{ Is message_id already in local SQLite? }
             ├──► YES ──► [ Discard Packet Instantly (Prevent Loops)[cite: 2] ]
             │
             └──► NO  ──► [ 1. Save Locally in SQLite ]
                          [ 2. Decrease TTL Hop Counter by 1[cite: 2] ]
                          [ 3. Re-broadcast to Nearby Nodes[cite: 3] ]

---

### Component 5: Store & Forward Lifecycle Sequence Diagram
*Shows how un-deliverable messages are saved and auto-forwarded later.*
```markdown
##### 📦 Store & Forward Data Lifecycle
```text
[ User Sends Message ] 
          │
          ▼
{ Is Destination Reachable? }
          ├──► YES ──► [ Deliver Immediately ]
          │
          └──► NO  ──► [ Save in Local SQLite Queue ('pending')[cite: 1, 2] ]
                       │
                       ▼
               [ Wait for Next Node / Route ]
                       │
                       ▼
               [ Auto-Forward when Node Appears ]


---

### Component 6: Battery Discipline Tier Table
*Demonstrates how SAHARA protects phone batteries during prolonged emergencies.*
```markdown
## 🔋 3. Smart Battery Discipline Tiers

| Battery Level Status | Mesh Discovery Behavior | Core Priority Focus |
| :--- | :--- | :--- |
| **🟢 > 60% Battery** | Normal discovery frequency | Full mesh relay and standard messaging |
| **🟡 30% – 60% Battery** | Reduced discovery frequency | Conserving power while maintaining links |
| **🔴 < 30% Battery** | Strict power-saving mode | **SOS & Emergency messages prioritized only** |

---

Component 7: Family Finding & Multi-Hop Distance Tree

Visualizes how users trace family members across reachable device hops.
Markdown

## 👨‍👩‍👧 4. Family Finding Across the Mesh

```text
[ YOU ] ──(1 hop)──► [ NODE_21 ] ──(2 hops)──► [ NODE_43 ] ──(3 hops)──► [ MOTHER ]

    Status: Reachable via local mesh relay nodes[cite: 3].

    Connection Distance: 3 hops away.

    Last Known Location: Pulled securely from local node caches.


---

### Component 8: Zero-Bloat Minimalist Tech Stack Table
*Styled like elite GitHub repositories—compact, professional, and clear.*
```markdown
## 🛠️ 5. Minimalist Tech Stack & Size Strategy
*Built with a strict zero-bloat policy to maintain an ultra-light APK footprint (~8.5 MB) optimized for low-end hardware[cite: 1].*

| Component | Technology | Optimization & Architecture Strategy |
| :--- | :--- | :--- |
| **📱 Frontend Mobile App** | Flutter (Dart) | Compiled using `flutter build apk --split-per-abi` (~8.5 MB standalone builds)[cite: 1, 3]. |
| **🔗 Mesh Networking** | BLE & Nearby Connections | Simple Flooding + Deduplication (`message_id` tracking)[cite: 2, 3]. |
| **💾 Local Persistence** | SQLite (`sqflite`) | Handles offline chat history, pending queues, and duplicate checks[cite: 1, 2]. |
| **📍 On-Demand GPS** | Android GPS Services | Polls coordinates for only 3 seconds upon SOS press (Zero continuous background drain). |
| **🖥️ Sync Backend** | Python 3.9+ (Standard Lib) | Built-in `http.server` & `sqlite3` (**0 third-party pip packages**, zero Docker needed)[cite: 3]. |

---

Component 9: Universal Message Model Schema Structure

Highlights the exact 9 fields requested by your leader[cite: 1, 2].
Markdown

## 🗄️ 6. Universal Message Model Schema (`message_model.dart`)

```dart
class MessageModel {
  final String messageId;   // Unique tracking identifier for duplicate checking[cite: 1, 2]
  final String senderId;    // Originating node / user ID[cite: 1, 2]
  final String receiverId;  // Target destination ID (or broadcast channel)[cite: 1, 2]
  final String type;        // SOS, Emergency, Family, Broadcast, Normal[cite: 1, 2]
  final String priority;    // High, Medium, Low sorting flags[cite: 1, 2]
  final String content;     // Payload message text[cite: 1, 2]
  final String timestamp;   // Creation timestamp[cite: 1, 2]
  final int ttl;            // Time-to-Live hop counter limit[cite: 1, 2]
  final String status;      // pending, sent, delivered[cite: 1, 2]
}


---

### Component 10: Cloud Sync Endpoints Route Table
*Lists the 4 lightweight sync endpoints for backend integration[cite: 3].*
```markdown
## ⚡ 7. Cloud Sync API Endpoints (Post-Recovery)

| Endpoint | Method | Action / Purpose |
| :--- | :--- | :--- |
| `/api/sync/messages` | `POST` | Uploads offline message queue; server saves new entries and drops duplicates[cite: 3]. |
| `/api/sync/emergency` | `POST` | Uploads SOS alerts and hazard notices for disaster relief teams[cite: 3]. |
| `/api/users` | `POST / GET` | Registers and fetches civilian profile names and node IDs[cite: 3]. |
| `/api/family` | `POST / GET` | Links and queries pre-registered family member statuses[cite: 3]. |

---
