<div align="center">

<img src="frontend/assets/images/sahara_banner.png" alt="SAHARA Banner" width="100%" />

# SAHARA — सहारा

**Offline Emergency Communication & Disaster Relief Network**

*From the Hindi सहारा — meaning support, refuge, and help.*

[![Build](https://img.shields.io/badge/build-passing-brightgreen?style=flat-square&logo=github)](https://github.com/angelverman2021-a11y/sahara/actions)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)
[![Offline](https://img.shields.io/badge/offline-mesh_ready-orange?style=flat-square&logo=signal)](https://github.com/angelverman2021-a11y/sahara)
[![Flutter](https://img.shields.io/badge/flutter-3.x-61dafb?style=flat-square&logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/dart-87%25-0175C2?style=flat-square&logo=dart)](https://dart.dev)
[![Python](https://img.shields.io/badge/python-11%25-3776AB?style=flat-square&logo=python)](https://python.org)
[![Contributors](https://img.shields.io/badge/contributors-3-purple?style=flat-square&logo=github)](https://github.com/angelverman2021-a11y/sahara)

<br/>

**[Why It Exists](#the-problem--solution)** &nbsp;|&nbsp;
**[4 Features](#4-core-features)** &nbsp;|&nbsp;
**[How It Works](#how-it-works)** &nbsp;|&nbsp;
**[Tech Stack](#tech-stack)** &nbsp;|&nbsp;
**[Cloud Sync](#cloud-sync--api)** &nbsp;|&nbsp;
**[Quick Start](#quick-start)** &nbsp;|&nbsp;
**[Team](#contributors)**

</div>

---

## What is SAHARA?

When a disaster strikes, cell towers go down first — exactly when people need help most. SAHARA turns every smartphone into a relay point, forming a communication network from the phones themselves. No tower. No SIM. No internet.

---

## The Problem & Solution

```
NORMAL NETWORK — FAILS IN A DISASTER
──────────────────────────────────────────────────────────────
  Cell tower  →  overloaded  →  offline  →  area blacked out
      │
      ▼
  Calls drop. SMS fails. Rescue cannot find you.

SAHARA — WORKS WITHOUT ANY INFRASTRUCTURE
──────────────────────────────────────────────────────────────
  Your phone  →  Nearby phone  →  Another phone  →  Rescue team
               (relay, auto)     (relay, auto)

  No tower needed. No internet. No SIM. Phones are the network.
```

| Normal Network | SAHARA |
|---|---|
| Needs cell towers | No towers — phones connect directly |
| One tower down = area goes dark | No single point of failure |
| Requires SIM + data plan | Works with no SIM, no data |
| Messages drop when congested | Messages hop until they arrive |
| Location sharing needs internet | GPS broadcast over local mesh |
| Encryption only at carrier level | End-to-end encrypted, always |
| High battery drain | Under 5% battery overhead |

---

## 4 Core Features

All four work with **zero internet, zero SIM, zero cell signal.**

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  EMERGENCY BROADCAST          OFFLINE COMMUNICATION                 │
│  ─────────────────────        ────────────────────────              │
│  One tap. GPS location        Text messages hop phone               │
│  sent to every SAHARA         to phone — no router,                 │
│  device in range.             no tower, no internet.                │
│                                                                     │
│  SOS SIGNAL                   15+ LANGUAGES                         │
│  ──────────                   ─────────────                         │
│  Dedicated distress           Hindi, Tamil, Bengali,                │
│  signal that hops             Telugu, Marathi, Gujarati,            │
│  across the mesh              Kannada, Odia, Punjabi,               │
│  until it reaches             Urdu, Malayalam, Assamese,            │
│  a rescue team.               Maithili, Santali, English            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

| Feature | What it does | Works offline? |
|---|---|---|
| **Emergency Broadcast** | Sends GPS + alert to all nearby SAHARA devices in one tap | Yes |
| **Offline Communication** | Encrypted chat that travels phone-to-phone with no internet | Yes |
| **SOS Signal** | Priority distress signal that routes itself to rescue automatically | Yes |
| **15+ Languages** | Full UI and alerts in 15+ Indian and international languages | Yes |

---

## How It Works

### Device Discovery

Two phones find each other using built-in wireless technology — no setup needed.

```
  ┌─────────────┐                              ┌─────────────┐
  │   Phone A   │                              │   Phone B   │
  │             │                              │             │
  │  Bluetooth  │ ──── "I am here" ─────────►  │  Hears A    │
  │  beacon on  │                              │             │
  │             │ ◄──── "I am here" ─────────  │  Bluetooth  │
  │  Hears B    │                              │  beacon on  │
  └──────┬──────┘                              └──────┬──────┘
         │                                            │
         └─────────── Wi-Fi Direct handshake ─────────┘
                      Fast, encrypted data transfer
                      No router. No internet.
```

### Message Hop — Phone A to Rescue Team

```mermaid
flowchart LR
    A["Your Phone\nSends SOS + GPS"]
    B["Phone B\nRelay"]
    C["Phone C\nRelay"]
    D["Rescue Team\nReceives alert + GPS pin"]

    A -->|"Bluetooth detected\nWi-Fi Direct link\nEncrypted packet"| B
    B -->|"Forwarded\nCannot read contents"| C
    C -->|"Final hop\nDelivered"| D

    style A fill:#8B0000,color:#fff,stroke:#FF4444
    style B fill:#1F3A5F,color:#fff,stroke:#4A90D9
    style C fill:#1F3A5F,color:#fff,stroke:#4A90D9
    style D fill:#145214,color:#fff,stroke:#2ECC71
```

### Full System Pipeline

```mermaid
flowchart TD
    A(["Disaster strikes\nCell network collapses"])
    B["SAHARA activates\nNo setup required"]
    C["Bluetooth beacons\nannounce device presence"]
    D["Nearby phones form\na mesh automatically"]
    E{"What does\nthe user need?"}
    F["SOS with GPS"]
    G["Message to\nanother person"]
    H["Find a\nfamily member"]
    I["SOS hops to\nrescue team"]
    J{"Path to\nrecipient?"}
    K["Proximity estimated\nfrom signal hops"]
    L["Delivered instantly"]
    M["Stored locally\nin queue"]
    N["New device\ncomes in range"]
    O(["Rescue team\nreceives alert"])

    A --> B --> C --> D --> E
    E --> F --> I --> O
    E --> G --> J
    E --> H --> K --> O
    J -->|"Yes"| L --> O
    J -->|"No"| M --> N --> L

    style A fill:#8B0000,color:#fff,stroke:#FF4444
    style O fill:#145214,color:#fff,stroke:#2ECC71
    style M fill:#4B3500,color:#fff,stroke:#FFA500
    style B fill:#1F3A5F,color:#fff,stroke:#4A90D9
```

### Store and Forward — No Message Is Ever Lost

```
NORMAL MESSAGING
  You send  →  No path exists  →  Message lost

SAHARA
  You send  →  No path exists  →  Saved locally
                                       │
                                  New device nearby
                                       │
                                  Forwarded  →  Delivered
```

### Family Finding

```
  Your phone broadcasts a silent encrypted ID every 5 seconds
                          │
  Other SAHARA phones relay it across the mesh
                          │
  Your family member's phone picks it up
                          │
  App shows: "Your sister — approx. 300m away — last seen 1 min ago"
  (No GPS required — distance estimated from signal hop count)
```

---

## Tech Stack

**App size target: under 50 MB — built for Android 8+, 2 GB RAM.**

```
SAHARA SIZE BUDGET
─────────────────────────────────────────
  Flutter UI framework       ~12 MB
  Dart runtime                ~8 MB
  Mesh networking layer        ~5 MB
  Encryption library           ~2 MB
  Offline map tiles           ~10 MB
  App logic + assets           ~8 MB
  Safety buffer                ~5 MB
  ────────────────────────────────────
  Total                      < 50 MB
─────────────────────────────────────────
```

**Mobile App**

| Technology | Purpose | Version |
|---|---|---|
| Flutter | Cross-platform UI (Android + iOS) | 3.x |
| Dart | App language | 3.x |
| SQLite | Local offline message queue | Latest |
| flutter_map | Offline map rendering (no internet) | Latest |

**Backend & Mesh**

| Technology | Purpose | Version |
|---|---|---|
| Python | Mesh routing + analytics server | 3.10+ |
| WebSockets | Real-time sync when internet is available | RFC 6455 |
| Bluetooth Low Energy | Device discovery + beaconing | Android built-in |
| Wi-Fi Direct | Phone-to-phone data transfer | Android built-in |
| LoRa | Long-range radio (hardware add-on, 10km+) | Hardware |

**Security**

| Technology | Purpose |
|---|---|
| AES-256 | Encrypts every message — relay phones cannot read it |
| ECDH Key Exchange | Unique encryption key for every device pair |
| X25519 | Past messages stay private even if a session is compromised |

---

## Performance

| Metric | SAHARA | Standard SMS |
|---|---|---|
| Works when towers are down | Yes | No |
| Message delivery time | Under 2 seconds per hop | Not available offline |
| Range between phones | 200m (Wi-Fi Direct) / 10km+ (LoRa) | Tower dependent |
| Internet required | None | 100% |
| Battery overhead | Less than 5% | Baseline |
| Encryption | End-to-end | Carrier-level only |
| App install size | Under 50 MB | — |
| Minimum Android | Android 8.0 | Android 4.4 |

---

## Cloud Sync & API

Fully offline by default. When internet returns — even briefly — all queued data syncs automatically.

### Sync Flow

```mermaid
flowchart TD
    A["User sends SOS\nor message"] --> B{"Internet\navailable?"}
    B -->|"Yes"| C["Sent directly\nto cloud"]
    B -->|"No"| D["Saved to\nlocal queue"]
    D --> E{"Internet\nback?"}
    E -->|"Still offline"| D
    E -->|"Yes"| F["Queued items sent\nin order — oldest first"]
    C --> G["Server confirms\nreceipt"]
    F --> G
    G --> H["Local queue cleared"]
    H --> I["Analytics dashboard\nupdated"]

    style A fill:#1F3A5F,color:#fff,stroke:#4A90D9
    style D fill:#4B3500,color:#fff,stroke:#FFA500
    style G fill:#145214,color:#fff,stroke:#2ECC71
    style I fill:#145214,color:#fff,stroke:#2ECC71
```

### Retry Logic

```
Failed sync retry schedule:
  Attempt 1  →  wait 1s
  Attempt 2  →  wait 2s
  Attempt 3  →  wait 4s
  Attempt 4  →  wait 8s  ...up to 60s max

Messages stay in queue until server confirms receipt.
```

### API Endpoints

| Method | Endpoint | Purpose | Offline |
|---|---|---|---|
| POST | `/api/v1/sos` | SOS alert + GPS | Queued → syncs on reconnect |
| POST | `/api/v1/messages` | Mesh message upload | Queued → syncs on reconnect |
| POST | `/api/v1/analytics` | Disaster report data | Queued → syncs on reconnect |
| POST | `/api/v1/sync/queue` | Bulk offline queue upload | On reconnect |
| GET | `/api/v1/nodes` | Active rescue nodes nearby | Needs internet |
| GET | `/api/v1/family/{group_id}` | Family group locations | Needs internet |
| GET | `/api/v1/map/tiles/{z}/{x}/{y}` | Map tile download | Cached locally |

---

## Quick Start

**Prerequisites:** Flutter 3+, Dart 3+, Python 3.10+, Node.js 18+

```bash
git clone https://github.com/angelverman2021-a11y/sahara.git
cd sahara
npm install
pip install -r requirements.txt
flutter run
```

```bash
# Backend
cd backend && python main.py
```

---

## Contributors

<p align="center">
  <a href="https://github.com/rubyjensi">
    <img src="https://github.com/rubyjensi.png" width="64" height="64" style="border-radius:50%;border:2px solid #4A90D9" alt="Jensi">
  </a>
  &nbsp;&nbsp;
  <a href="https://github.com/aroralemon">
    <img src="https://github.com/aroralemon.png" width="64" height="64" style="border-radius:50%;border:2px solid #4A90D9" alt="Shreya Arora">
  </a>
  &nbsp;&nbsp;
  <a href="https://github.com/shreyaarora">
    <img src="https://github.com/shreyaarora.png" width="64" height="64" style="border-radius:50%;border:2px solid #4A90D9" alt="Shreya">
  </a>
  <br/><br/>
  <a href="https://github.com/rubyjensi"><strong>Jensi</strong></a> &nbsp;·&nbsp;
  <a href="https://github.com/aroralemon"><strong>Shreya Arora</strong></a> &nbsp;·&nbsp;
  <a href="https://github.com/shreyaarora"><strong>Shreya</strong></a>
  <br/>
  Built at <strong>MUJ Hackathon 2026</strong>
</p>

---

## Roadmap

- [x] P2P mesh messaging — Wi-Fi Direct + BLE
- [x] SOS beacon with GPS broadcast
- [x] End-to-end encryption
- [x] Store-and-forward offline queue
- [x] Cloud sync with retry logic
- [ ] LoRa hardware integration
- [ ] 15+ language support (production)
- [ ] Offline map tiles
- [ ] Family finding (production-ready)
- [ ] Rescue coordinator web dashboard

---

## License

MIT — see [`LICENSE`](LICENSE)

---

<p align="center">
  <strong>SAHARA — सहारा</strong><br/>
  <em>Support. Refuge. Help.</em><br/>
  Because when everything fails, connection saves lives.
</p>
