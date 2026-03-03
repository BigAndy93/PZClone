# PZClone — Technical Bible v3

## Authority Model (unchanged core)
Host authoritative for:
- NPC AI
- Base simulation
- Faction diplomacy
- Resource accounting

## New Systems (V3)

### Base Entity
Each base contains:
- base_id
- territory_radius
- population_count
- defense_rating
- morale
- resource_inventory

### Survivor Assignment System
Each NPC survivor tracks:
- role
- assigned_zone
- loyalty
- productivity_modifier

### Job Types
- Guard
- Scavenger
- Builder
- Medic
- Farmer (future)
- Crafter

Assignments are host-authoritative and replicated.

---

## Base Expansion Model

Buildings within base can be upgraded:
- Walls reinforced
- Watchtowers added
- Storage expanded
- Sleeping quarters expanded

Expansion must:
1. Consume resources.
2. Take time.
3. Increase base stats.

---

## Command System (V3)

Players can issue:
- Follow
- Hold
- Defend Area
- Scavenge Zone
- Repair Structure
- Construct Upgrade

Command state is synced and evaluated by host AI.
