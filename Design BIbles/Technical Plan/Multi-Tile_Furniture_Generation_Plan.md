# Multi-Tile Furniture Procedural Generation System

### Design Document – Z-Sims / PZClone

---

# 1. Purpose

The current procedural furnishing system works well for **1×1 tile furniture**, but larger objects (2×1, 2×2, etc.) frequently:

* stretch or distort visually
* clip through walls
* overlap other furniture
* protrude outside building boundaries
* block doorways and paths

This document defines a **footprint-aware procedural placement system** to correctly place large furniture while preserving believable room layouts.

The system should remain compatible with:

* tile-based interiors
* procedural building generation
* room detection
* cutaway wall rendering

---

# 2. Core Principle

Furniture placement must shift from:

```
"Place object at coordinate"
```

to:

```
"Find a valid tile footprint region that satisfies all placement rules, 
then anchor the object there."
```

Large objects are **multi-tile structures**, not oversized single tiles.

---

# 3. Key System Components

The improved system consists of **five major components**:

1. **Furniture Metadata System**
2. **Room Occupancy Grid**
3. **Room Placement Zones**
4. **Footprint Validation**
5. **Placement Scoring**

Together these ensure large furniture fits naturally inside generated rooms.

---

# 4. Furniture Metadata System

Each furniture asset must include placement metadata.

Example:

```json
{
"id": "table_kitchen_01",
"category": "furniture",
"footprint": [2,2],
"anchor": "bottom_right",
"rotations": ["N","E","S","W"],

"clearance":{
"front":1,
"back":0,
"left":1,
"right":1
},

"placement_rules":{
"preferred_zone":"center",
"min_distance_from_door":2,
"allow_against_wall":false,
"must_face_room":false
}
}
```

### Required Metadata Fields

| Field          | Description                    |
| -------------- | ------------------------------ |
| id             | unique object identifier       |
| footprint      | tile width × height            |
| anchor         | tile used for sprite anchoring |
| rotations      | allowed orientations           |
| clearance      | tiles required around object   |
| preferred_zone | placement region inside room   |
| door_distance  | minimum spacing from doors     |
| wall_affinity  | if object must align to wall   |

---

# 5. Room Occupancy Grid

Each generated room must maintain a **tile occupancy map**.

Example grid representation:

```
Legend
. = free tile
# = wall boundary
D = door keepout
P = reserved path tile
F = furniture
A = candidate anchor
```

Example:

```
##########
#........#
#..A.....#
#..A.....#
#....D...#
##########
```

The grid tracks:

* usable interior floor tiles
* walls
* door locations
* reserved path areas
* occupied furniture tiles

All placement checks reference this grid.

---

# 6. Room Placement Zones

Rooms should be divided into functional placement zones.

Zones help the generator place objects logically.

### Zone Types

| Zone            | Purpose                      |
| --------------- | ---------------------------- |
| wall_zone       | objects that attach to walls |
| corner_zone     | small corner furniture       |
| center_zone     | large central furniture      |
| doorway_keepout | prevents blocking doors      |
| walkway_zone    | preserves movement paths     |
| window_keepout  | avoids blocking windows      |

Example bedroom zones:

```
wall_zone
center_zone
doorway_keepout
window_keepout
```

---

# 7. Furniture Classes

Furniture should be categorized by placement behavior.

---

## A. Wall-Bound Furniture

These objects should attach to a wall.

Examples:

* bed
* couch
* refrigerator
* stove
* dresser
* sink
* toilet

Rules:

```
must align to wall
must face interior
cannot block windows or doors
```

---

## B. Center Furniture

Placed in open areas.

Examples:

* dining tables
* rugs
* coffee tables
* islands

Rules:

```
requires open space
preserve walk paths
prefer center_zone
```

---

## C. Modular Furniture Chains

Objects that form connected runs.

Examples:

* kitchen counters
* cabinets
* shelving
* sectional couches

Instead of placing one large object, assemble pieces:

```
counter_end_left
counter_middle
counter_corner_inner
counter_corner_outer
counter_end_right
```

---

# 8. Object Footprint System

Large objects occupy multiple tiles.

Example table footprint:

```
◇ ◇
◇ ◇
```

Placement requires checking **every tile in the footprint**.

Placement is rejected if:

* any tile overlaps wall
* any tile overlaps furniture
* any tile lies outside room bounds
* clearance rules are violated

---

# 9. Hard Footprint vs Soft Footprint

Some furniture needs space around it.

Example kitchen table:

```
hard footprint = 2×2
soft footprint = 4×4
```

Hard footprint = tiles occupied
Soft footprint = usable space needed around it.

Soft footprint ensures chairs and movement still fit.

---

# 10. Placement Pipeline

Furniture placement should follow this order.

### Step 1 – Generate Interior Grid

Calculate:

* interior floor tiles
* door locations
* wall adjacency
* walkable zones

---

### Step 2 – Place Large Furniture First

Example order:

Kitchen

```
counters
fridge
stove
sink
table
chairs
small clutter
```

Bedroom

```
bed
dresser
wardrobe
nightstand
chairs
small props
```

Large objects must be placed first to avoid blocking placement space.

---

### Step 3 – Generate Candidate Placements

For each object:

1. find anchor tile candidates
2. test all rotations
3. validate footprint
4. compute placement score

---

### Step 4 – Score Placement Options

Candidate placements should be scored.

Example scoring system:

```
+30 preferred zone
+20 correct wall alignment
+15 preserves path space
+10 good orientation

-50 near doorway
-40 awkward spacing
-100 path blockage
-1000 outside room
```

The highest scoring valid candidate is selected.

---

### Step 5 – Reserve Occupied Tiles

After placement:

* mark footprint tiles as occupied
* mark clearance tiles as reserved
* update pathfinding grid

---

### Step 6 – Place Small Objects

After major furniture is placed:

```
clutter
decor
small props
loot containers
```

Small items should **never determine room layout**.

---

# 11. Room Layout Templates (Recommended)

Purely random layouts often produce unrealistic rooms.

Instead, use **layout templates**.

Example bedroom templates:

```
bed_left_wall
bed_top_wall
twin_beds
master_bedroom
```

Example kitchen templates:

```
galley
L_shaped
single_wall
eat_in_kitchen
```

Templates define **major object placement**, while the generator fills in details procedurally.

---

# 12. Common Failure Causes

Large furniture distortion often results from:

### Sprite Scaling

Sprites should never be resized to fit rooms.

### Incorrect Anchor Tile

Large objects anchored like 1×1 objects drift through walls.

### Footprint Mismatch

Sprite visually exceeds defined tile footprint.

### No Boundary Check

Placement allowed near walls without verifying footprint area.

### No Interior Padding

Rooms must reserve margin between walls and furniture.

---

# 13. System Summary

The improved furniture system must include:

```
footprint-aware placement
room occupancy grid
zone-based placement
clearance validation
candidate scoring
large-first placement ordering
optional layout templates
```

---

# 14. Expected Result

After implementing this system:

Large furniture will:

* remain inside room boundaries
* align correctly to walls
* avoid blocking doors
* preserve walkable paths
* produce believable interior layouts
* eliminate stretched or distorted placements

---

# 15. Implementation Goal

Refactor the current furniture generator to use:

```
Footprint-aware procedural placement
Zone-based layout logic
Validation-driven candidate placement
```

instead of simple coordinate-based placement.

---
