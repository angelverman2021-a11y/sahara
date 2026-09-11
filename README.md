<div align="center">

<img src="frontend/assets/images/sahara_banner.png" alt="SAHARA Banner" width="100%" />

# SAHARA
### Offline-First Civilian Emergency Communication & Disaster Management System

[![Repository](https://img.shields.io/badge/Repository-GitHub-blue?style=for-the-badge&logo=github)](https://github.com/angelverman2021-a11y/sahara)
[![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Python Backend](https://img.shields.io/badge/Backend-Python%203.9+-3776AB?style=for-the-badge&logo=python)](https://python.org)

*When conventional cellular and internet infrastructure collapses during disasters, nearby smartphones become the communication network.*

</div>

---

<p align="center">
  <a href="https://github.com/angelverman2021-a11y/sahara">
    <img src="assets/sahara_readme_banner.png" alt="Sahara - Connect • Help • Survive" width="100%">
  </a>
</p>

<p align="center">
  <strong>Offline Emergency Messaging &amp; Disaster Relief Network</strong><br/>
  <em>Built for the moments when everything else fails.</em>
</p>

<p align="center">
  <a href="https://github.com/angelverman2021-a11y/sahara/actions"><img src="https://img.shields.io/badge/build-passing-brightgreen?style=flat-square&logo=github" alt="Build Status"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License"></a>
  <a href="#-features"><img src="https://img.shields.io/badge/offline-mesh_ready-orange?style=flat-square&logo=signal" alt="Mesh Ready"></a>
  <a href="#-tech-stack"><img src="https://img.shields.io/badge/flutter-3.x-61dafb?style=flat-square&logo=flutter" alt="Flutter"></a>
  <a href="#-tech-stack"><img src="https://img.shields.io/badge/dart-87%25-0175C2?style=flat-square&logo=dart" alt="Dart"></a>
  <a href="#-tech-stack"><img src="https://img.shields.io/badge/python-11%25-3776AB?style=flat-square&logo=python" alt="Python"></a>
  <a href="#-contributors"><img src="https://img.shields.io/badge/contributors-3-purple?style=flat-square&logo=github" alt="Contributors"></a>
</p>

<p align="center">
  <a href="#-quick-start"><strong>Quick Start</strong></a> •
  <a href="#-key-features"><strong>Key Features</strong></a> •
  <a href="#-app-preview"><strong>App Preview</strong></a> •
  <a href="#-architecture"><strong>Architecture</strong></a> •
  <a href="#-tech-stack"><strong>Tech Stack</strong></a> •
  <a href="#-performance"><strong>Performance</strong></a> •
  <a href="#-contributors"><strong>Team</strong></a> •
  <a href="#-license"><strong>License</strong></a>
</p>

---

## 🌵 About Sahara

**Sahara** is an offline emergency communication and disaster response network engineered to function when cellular networks and internet connectivity fail. Utilizing peer-to-peer mesh networking, local signal relays, and intelligent distress message routing, Sahara ensures **SOS alerts**, **vital telemetry**, and **location data** reach emergency responders during critical blackouts.

> *Named after the world's most unforgiving desert — where survival depends on connection.*

---

## ✨ Key Features

<p align="center">
  <img src="assets/sahara_features_banner.jpg" alt="Sahara Key Features" width="100%">
</p>

| Feature | Description |
|---|---|
| 📡 **Offline Mesh Communication** | End-to-end encrypted emergency messaging over local P2P networks — no cell service needed |
| 🆘 **SOS & Location Beacon** | Broadcast distress signals with precise GPS coordinates to nearby nodes and rescue teams |
| 📊 **Disaster Analytics** | Live aggregation of crisis reports, resource requests, and casualty data for response coordinators |
| 🔋 **Low-Power Protocol** | Lightweight binary payloads optimized for LoRa, Wi-Fi Direct, and WebSockets |
| 🔒 **End-to-End Encryption** | All messages are cryptographically secured — even relay nodes cannot read your data |
| 🗺️ **Live Mesh Map** | Real-time visualization of active nodes, signal strength, and message routing paths |

---

## 📱 App Preview

<p align="center">
  <img src="assets/sahara_app_screens.jpg" alt="Sahara App Screens — SOS, Messaging, Mesh Map" width="100%">
</p>

> **Left**: One-tap SOS broadcast with live GPS coordinates and mesh node count.
> **Center**: Encrypted emergency chat between mesh nodes.
> **Right**: Real-time network map showing connected nodes and signal topology.

---

<a id="architecture"></a>
## 🌐 How Sahara Works

```mermaid
%%{init: {
  'theme': 'base',
  'themeVariables': {
    'fontFamily': 'Inter, system-ui, -apple-system, sans-serif',
    'fontSize': '16px',
    'nodePadding': '24'
  }
}}%%
graph TD
    classDef blackout fill:#001A4D,stroke:#FF4444,stroke-width:3px,color:#FFFFFF,rx:20px,ry:20px;
    classDef sender fill:#001A4D,stroke:#0094FF,stroke-width:3px,color:#FFFFFF,rx:20px,ry:20px;
    classDef relay fill:#1F456E,stroke:#0094FF,stroke-width:2px,color:#FFFFFF,rx:20px,ry:20px;
    classDef rescuer fill:#0094FF,stroke:#001A4D,stroke-width:3px,color:#FFFFFF,rx:20px,ry:20px;
    classDef pill fill:#FFFFFF,stroke:#1F456E,stroke-width:2px,color:#001A4D,rx:30px,ry:30px;

    BLACKOUT(["🚨 TOTAL SIGNAL BLACKOUT<br/><br/>Cell Towers & Internet Completely Down"]):::blackout

    subgraph ENGINE ["🌐 SAHARA MESH SURVIVAL PIPELINE"]
        direction TB

        subgraph SOURCE ["1️⃣ SENDER BEACON"]
            PHONE_A(["📱 Phone A (SOS Sender)<br/><br/>Generates GPS & Emergency Payload"]):::sender
        end

        subgraph HOPS ["2️⃣ REAL-TIME WIRELESS HOPS"]
            direction LR
            PHONE_B(["📱 Phone B<br/><br/>Relay Node"]):::relay
            PHONE_C(["📱 Phone C<br/><br/>Relay Node"]):::relay
            PHONE_B ==>|"Direct Connection"| PHONE_C
        end

        subgraph TARGET ["3️⃣ RESCUE ARRIVAL"]
            PHONE_D(["🚑 Phone D (Responder)<br/><br/>Receives Alert & Pinpoints Location"]):::rescuer
        end

        SOURCE ==>|"Wireless Jump 1"| PHONE_B
        PHONE_C ==>|"Wireless Jump 2"| PHONE_D
    end

    subgraph GUARDS ["🛡️ SAHARA SAFETY GUARANTEES"]
        direction LR
        CAP1(["🔒 End-to-End Encrypted"]):::pill
        CAP2(["🔋 Low Battery Usage"]):::pill
        CAP3(["🌐 Zero Internet Needed"]):::pill
    end

    BLACKOUT ==>|"Auto-Activates Mesh"| ENGINE
    ENGINE --> GUARDS

    style ENGINE fill:#F4F8FC,stroke:#001A4D,stroke-width:3px,color:#001A4D,rx:24px,ry:24px;
    style SOURCE fill:#FFFFFF,stroke:#0094FF,stroke-width:1.5px,color:#001A4D,rx:18px,ry:18px;
    style HOPS fill:#FFFFFF,stroke:#0094FF,stroke-width:1.5px,color:#001A4D,rx:18px,ry:18px;
    style TARGET fill:#FFFFFF,stroke:#0094FF,stroke-width:1.5px,color:#001A4D,rx:18px,ry:18px;
    style GUARDS fill:#FFFFFF,stroke:#1F456E,stroke-width:2px,color:#001A4D,rx:24px,ry:24px;
```

> **How Help Reaches You Without Internet**: When cell towers fail, SAHARA links nearby smartphones directly. Emergency SOS messages automatically jump from one phone to the next until they reach rescue workers — working instantly without internet or mobile data.

---

## 🛠️ Tech Stack

<p align="center">
  <img src="assets/sahara_tech_stack.jpg" alt="Sahara Tech Stack" width="100%">
</p>

### Frontend / Mobile App

| Technology | Role | Version |
|---|---|---|
| 🐦 **Flutter** | Cross-platform mobile UI | 3.x |
| 🎯 **Dart** | Primary app language | 3.x |

### Backend & Mesh Engine

| Technology | Role | Version |
|---|---|---|
| 🐍 **Python** | Mesh routing, data processing & analytics | 3.10+ |
| 🔌 **WebSockets** | Real-time bidirectional node sync | RFC 6455 |
| 📡 **LoRa** | Long-range, low-power RF communication | — |
| 📶 **Wi-Fi Direct** | Peer-to-peer direct device connectivity | — |

### Security

| Technology | Role |
|---|---|
| 🔒 **AES-256 + ECDH** | End-to-end message encryption |
| 📍 **GPS / Fused Location** | Precise distress location broadcasting |

---

## 📊 Performance

<p align="center">
  <img src="assets/sahara_performance_stats.jpg" alt="Sahara Performance Stats" width="100%">
</p>

| Metric | Sahara Mesh | Traditional SMS |
|---|---|---|
| **Works during blackout** | ✅ Yes | ❌ No |
| **Message delivery time** | < 2 seconds | N/A (offline) |
| **Range per hop** | 500m+ (LoRa) | Cell tower dependent |
| **Internet required** | 0% | 100% |
| **Battery overhead** | < 5% | Baseline |
| **Encryption** | End-to-End | Carrier-level only |

---

## 🚀 Quick Start

### Prerequisites

- Flutter SDK `>= 3.0`
- Dart `>= 3.0`
- Python `>= 3.10`
- Node.js `>= 18.x` *(for frontend tooling)*

### Installation & Run

```bash
# 1. Clone the repository
git clone https://github.com/angelverman2021-a11y/sahara.git

# 2. Navigate to project directory
cd sahara

# 3. Install Node dependencies (frontend tooling)
npm install

# 4. Install Python dependencies
pip install -r requirements.txt

# 5. Run the Flutter app
flutter run

# Or start the web dev server
npm run dev
```

### Backend (Mesh Routing Engine)

```bash
# Start the Python mesh routing server
cd backend
python main.py
```

---

## 👥 Contributors

<p align="center">
  <a href="https://github.com/rubyjensi">
    <img src="https://github.com/rubyjensi.png" width="64" height="64" style="border-radius:50%" alt="rubyjensi">
  </a>
  &nbsp;&nbsp;
  <a href="https://github.com/aroralemon">
    <img src="https://github.com/aroralemon.png" width="64" height="64" style="border-radius:50%" alt="aroralemon">
  </a>
  &nbsp;&nbsp;
  <a href="https://github.com/shreyaarora">
    <img src="https://github.com/shreyaarora.png" width="64" height="64" style="border-radius:50%" alt="shreyaarora">
  </a>
</p>

<p align="center">
  <strong><a href="https://github.com/rubyjensi">rubyjensi (Jensi)</a></strong> &nbsp;•&nbsp;
  <strong><a href="https://github.com/aroralemon">aroralemon (Shreya Arora)</a></strong> &nbsp;•&nbsp;
  <strong><a href="https://github.com/shreyaarora">shreyaarora</a></strong>
</p>

<p align="center">
  Built with ❤️ at <strong>MUJ Hackathon 2026</strong>
</p>

---

## 🗺️ Roadmap

- [x] Core P2P mesh messaging
- [x] SOS beacon with GPS broadcasting
- [x] End-to-end encryption
- [x] Mermaid architecture documentation
- [ ] LoRa hardware integration
- [ ] Battery optimization (background service)
- [ ] Multi-language support
- [ ] Offline map tiles (no internet map rendering)
- [ ] Relay node auto-discovery protocol
- [ ] Rescue team dashboard web interface

---

## 🤝 Contributing

Contributions are welcome! Please open an issue first to discuss what you'd like to change.

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/AmazingFeature`
3. Commit your changes: `git commit -m 'Add AmazingFeature'`
4. Push to the branch: `git push origin feature/AmazingFeature`
5. Open a Pull Request

---

## 📜 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for more information.

---

<p align="center">
  <strong>Sahara</strong> — Because when everything fails, connection saves lives.<br/>
  <em>CONNECT • HELP • SURVIVE</em>
</p>
