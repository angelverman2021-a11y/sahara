# SAHARA — Dataset & Simulation Benchmarks

## Overview

The `dataset/` folder contains realistic Indian disaster data, emergency message corpuses, simulated mesh user nodes, and family topology structures.

> [!WARNING]
> **Strict Decoupling Policy:**
> * These datasets are strictly for development, unit testing, mesh simulation, and offline routing benchmarks.
> * **Zero App Bundling:** In accordance with the strict **8–10 MB** maximum mobile application size constraint, these datasets **must never be bundled directly into the frontend production binary**.
> * **Scope Restriction:** Restricted exclusively to **Indian Floods** and **Indian Cyclones**.

---

## Files in this Directory

| File | Purpose | Key Fields |
| :--- | :--- | :--- |
| [`disasters_india.csv`](./disasters_india.csv) | Historical and scenario flood & cyclone events across Indian states | `disaster_id`, `disaster_type`, `state`, `district`, `location`, `start_date`, `end_date`, `severity`, `affected_population` |
| [`emergency_messages.csv`](./emergency_messages.csv) | Curated emergency broadcast and SOS text templates | `message_id`, `category`, `priority`, `content`, `suggested_action` |
| [`test_users.csv`](./test_users.csv) | Simulated civilian node identities for multi-hop mesh testing | `user_id`, `name`, `node_id`, `device_model`, `initial_battery` |
| [`family_test_data.csv`](./family_test_data.csv) | Graph relationships for family-finding and reachability testing | `family_id`, `user_id`, `family_member_id`, `relationship` |

---

## Disaster Scope (India Floods & Cyclones)

This dataset focuses on disaster-prone Indian regions including:
- **Floods:** Assam (Brahmaputra basin), Bihar, Kerala, Uttarakhand, Odisha.
- **Cyclones:** Odisha (Bay of Bengal coast), West Bengal, Andhra Pradesh, Tamil Nadu, Gujarat (Arabian Sea coast).
