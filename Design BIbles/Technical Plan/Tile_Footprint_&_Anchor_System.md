# Tile Footprint & Anchor System for Isometric Furniture

### Companion Design Document – Z-Sims / PZClone

---

# 1. Purpose

This document defines how **multi-tile furniture is anchored and rendered** in the isometric tile system.

It prevents the following problems:

* furniture clipping through walls
* furniture appearing stretched or misaligned
* incorrect rotations
* incorrect collision footprints
* inconsistent sprite offsets
* large furniture drifting outside room boundaries

This system must be used by:

* procedural furniture generator
* building blueprint editor
* room layout templates
* physics / collision systems
* rendering pipeline

---

# 2. Base Tile System

The world grid uses an isometric diamond tile.

```text
Tile Size
64 × 32 pixels
```

Diamond representation:

```text
      ◇
   ◇  ◇  ◇
◇  ◇  ◇  ◇
   ◇  ◇  ◇
      ◇
```

All floor placement is aligned to this grid.

---

# 3. Sprite Anchor Rule

All furniture sprites use the **BOTTOM CENTER ANCHOR**.

The anchor tile is the tile used for placement logic and rendering.

Example:

```text
128 × 128 sprite

+-----------------------+
|                       |
|       object          |
|                       |
|                       |
|           ◇           |
+-----------------------+
```

The diamond represents the **anchor tile**.

---

# 4. Anchor Tile Concept

Large furniture occupies multiple tiles, but is **anchored to one tile**.

Example:

```text
2×2 table footprint

◇ ◇
◇ A
```

`A` = anchor tile.

The sprite origin is attached to this tile.

All other tiles are simply **reserved by the footprint**.

---

# 5. Footprint Definitions

Furniture footprints describe the tile area occupied by an object.

### 1×1 Object

Example: chair

```text
A
```

---

### 2×1 Object

Example: couch

```text
◇ A
```

---

### 1×2 Object

Example: narrow shelf

```text
◇
A
```

---

### 2×2 Object

Example: dining table

```text
◇ ◇
◇ A
```

---

### 3×2 Object

Example: sectional couch

```text
◇ ◇ ◇
◇ ◇ A
```

---

# 6. Rotation Handling

Furniture footprints rotate with the object.

Example couch:

### Facing South

```text
◇ A
```

### Facing East

```text
◇
A
```

### Facing North

```text
A ◇
```

### Facing West

```text
A
◇
```

The generator must rotate the footprint accordingly.

---

# 7. Sprite Canvas Size

Furniture sprites are larger than their tile footprint.

Recommended canvas sizes:

| Object Type       | Canvas  |
| ----------------- | ------- |
| small furniture   | 128×128 |
| medium furniture  | 128×128 |
| tall furniture    | 128×192 |
| wardrobes/fridges | 128×192 |
| large furniture   | 128×256 |

Objects extend **above their anchor tile**.

---

# 8. Anchor Placement Diagram

Example: 2×2 dining table sprite

```text
          tabletop
      ┌─────────────┐
     /               \
    /                 \
        table legs
           ◇
```

Anchor tile = bottom center.

The table visually covers 4 tiles, but only **one tile anchors the sprite**.

---

# 9. Rendering Order (Y-Sort)

Objects must render based on their anchor tile position.

Rule:

```text
Lower Y coordinate = drawn behind
Higher Y coordinate = drawn in front
```

This prevents objects from appearing incorrectly layered.

---

# 10. Hard Footprint vs Soft Footprint

Furniture placement must use two footprint types.

### Hard Footprint

Tiles physically occupied by the object.

Example table:

```text
◇ ◇
◇ A
```

---

### Soft Footprint

Additional space required for usability.

Example dining table:

```text
soft footprint

◇ ◇ ◇ ◇
◇ ◇ ◇ ◇
◇ ◇ A ◇
◇ ◇ ◇ ◇
```

Soft footprint ensures:

* chairs can spawn
* player can walk around object
* rooms remain believable

---

# 11. Collision Map

Furniture footprints reserve tiles in the occupancy grid.

Example:

```text
Legend
. = free
F = furniture
```

Example placement:

```text
..........
..FF......
..FA......
..........
```

Generator must verify all footprint tiles before placement.

---

# 12. Clearance Rules

Furniture may require clearance tiles.

Example:

```json
{
"id":"table_dining_01",

"footprint":[2,2],

"clearance":{
"front":1,
"back":1,
"left":1,
"right":1
}
}
```

This ensures space for:

* chairs
* walking paths
* interactions

---

# 13. Wall-Bound Objects

Some objects must align to walls.

Example:

* beds
* couches
* refrigerators
* dressers
* toilets
* sinks

Example footprint:

```text
wall
#####

object
◇ A
```

Rules:

```text
anchor tile must be adjacent to wall
object must face interior
```

---

# 14. Modular Furniture Chains

Some furniture must be assembled from segments.

Examples:

Kitchen counters:

```text
counter_left
counter_middle
counter_corner
counter_sink
counter_stove
counter_right
```

Generator should build runs along walls.

---

# 15. Visual Alignment Guidelines

Furniture must align visually with tile edges.

Rules:

* base of furniture sits on diamond floor plane
* anchor tile sits directly beneath object center
* no sprite scaling allowed
* sprite offset must match anchor tile

---

# 16. Placement Validation

Before placing furniture, the system must verify:

```text
footprint tiles inside room
footprint tiles not blocked
clearance tiles valid
not blocking doorways
not blocking pathfinding
```

If any rule fails, placement must be rejected.

---

# 17. Common Errors Prevented

This system prevents:

* furniture protruding through walls
* multi-tile objects overlapping
* rotated objects misaligning
* path blocking
* distorted furniture scaling
* incorrect sprite offsets

---

# 18. Integration with Procedural Generator

The furniture generator must:

1. read furniture footprint metadata
2. rotate footprint based on orientation
3. test placement against occupancy grid
4. validate clearance space
5. score candidate placement
6. reserve tiles upon placement

---

# 19. Example Placement Pipeline

```text
1. generate room grid
2. detect walls and doors
3. compute placement zones
4. place large furniture (footprint aware)
5. reserve footprint tiles
6. place smaller furniture
7. add decorative clutter
```

---

# 20. Summary

This document defines the **standard footprint and anchor system** for all multi-tile furniture.

By using this system, the procedural generator will:

* place large furniture correctly
* avoid clipping through walls
* maintain believable layouts
* preserve walking paths
* maintain correct isometric rendering alignment

---

END DOCUMENT
