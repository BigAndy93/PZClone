# SimZombie / PZClone – Systems Diagrams
*Visual reference companion to the Technical Implementation Bible*  
Generated: 2026-03-07

---

## Purpose

This document provides **diagram-style references** for the most important foundational systems in SimZombie so that development tools, collaborators, and future implementation passes all use the same mental model.

These diagrams are intentionally simple and readable in plain Markdown.

---

# 1. Wall-Edge Building System Diagram

## Core Rule

Walls do **not** live inside tiles.  
Walls live on the **shared edge between adjacent tiles**.

## Tile Relationship Diagram

```text
     ┌─────────┬─────────┐
     │ Tile A  │ Tile B  │
     │         │         │
     ├─────────┼─────────┤
     │ Tile C  │ Tile D  │
     │         │         │
     └─────────┴─────────┘
```

## Edge Ownership Concept

```text
Each tile stores four edge references:

          north
     ┌─────────────┐
west │    TILE     │ east
     └─────────────┘
          south
```

## Tile Edge Data Model

```text
TileEdges
{
    north_wall
    east_wall
    south_wall
    west_wall
}
```

## Shared Wall Example

```text
Tile A east edge == Tile B west edge
Tile A south edge == Tile C north edge
```

That means a wall should be created **once**, then referenced consistently from both adjacent sides.

## Why This Matters

- Prevents double walls
- Makes room detection easier
- Makes wall destruction cleaner
- Supports door/window placement naturally
- Makes drag-to-build more predictable

## Horizontal Wall Placement

```text
+---+---+---+
| A | B | C |
+===+===+===+   ← wall placed along southern edges
| D | E | F |
+---+---+---+
```

## Vertical Wall Placement

```text
+---+|+---+|+---+
| A || B || C |
+---+|+---+|+---+
| D || E || F |
+---+|+---+|+---+
```

## Blueprint Drag Example

```text
Player drag input:
(start) ----------------------> (end)

System result:
Create BlueprintWall segments on each crossed tile edge
```

## Build Pipeline

```text
Player drag
   ↓
Edge path calculation
   ↓
Blueprint edge generation
   ↓
Validation (blocked? duplicate? allowed?)
   ↓
Confirm build
   ↓
Spawn permanent wall data
```

---

# 2. Room Detection Diagram

## Goal

A room exists when wall edges form a **closed boundary** around a set of floor tiles.

## Closed Room Example

```text
#########
#.......#
#.......#
#.......#
#########
```

Legend:
- `#` = wall boundary
- `.` = walkable indoor floor

## Detection Flow

```text
Detect placed walls
   ↓
Build blocked-edge map
   ↓
Find enclosed floor region
   ↓
Flood fill interior tiles
   ↓
Assign room_id
   ↓
Mark as indoor
```

## Flood Fill Concept

```text
If flood fill escapes outward:
    not a closed room

If flood fill stays bounded:
    valid room
```

## Open Gap Example (Not a Room)

```text
#########
#.......#
#.......
#.......#
#########
```

Because the boundary is broken, the flood fill leaks outside and the area is not marked as a room.

## Room Data Model

```text
Room
{
    id
    tile_list
    indoor = true
    roof_enabled = true
}
```

---

# 3. Auto-Roof Generation Diagram

## Rule

Once a room is valid, a roof overlay can be generated above all tiles in that room.

## Roof Generation Concept

```text
[Room tiles identified]
        ↓
Create roof tile overlay for each room tile
        ↓
Bind roof tiles to room_id
```

## Top-Down Example

```text
Roof layer:
RRRRR
RRRRR
RRRRR

Room floor:
.....
.....
.....
```

Legend:
- `R` = roof overlay tile
- `.` = room floor tile

## Roof Visibility Rules

```text
Player outside building:
    roof visible

Player enters building:
    roof hidden or faded

Camera peeks inside:
    roof hidden selectively if needed
```

---

# 4. Occlusion Rendering Diagram

## Goal

Hide or fade geometry that blocks the player's view.

This mainly applies to:

- roofs
- upper walls
- tall furniture near the camera side

## Basic Camera-to-Player Occlusion

```text
Camera
  ↓

[Front Wall]
[Interior Space]
[Player]
```

If the front wall is between the camera and the player, it should fade or hide.

## Wall Fade Example

```text
State A: Player outside
Wall opacity = 1.0

State B: Player behind wall
Wall opacity = 0.5

State C: Player fully inside room
Front wall opacity = 0.0
Roof opacity = 0.0
```

## Occlusion Logic Flow

```text
Find player room / tile
   ↓
Find geometry between camera and player
   ↓
Tag occluding objects
   ↓
Apply fade or hide state
   ↓
Restore visibility when no longer blocking
```

## Object Priority

```text
Always visible:
- floor tiles
- ground loot
- UI markers

Occlusion candidates:
- front-facing walls
- roofs
- tall furniture
```

## Per-Object Visibility State

```text
OcclusionState
{
    target_alpha
    current_alpha
    fade_speed
}
```

## Example Transition

```text
fully visible → fading → hidden
hidden → fading in → fully visible
```

---

# 5. Vision and Line-of-Sight Diagram

## Rule

An object is visible if it is:

1. inside the player's vision cone
2. not blocked by walls or solid occluders

## Vision Cone Example

```text
           visible
        \    |    /
         \   |   /
          \  |  /
           \ | /
            \|/
         P --+---->
            player facing east
```

## LOS Check

```text
Player
  ↓ raycast
Target

If wall hit before target:
    target not directly visible
```

## Memory Rules

```text
Ground items:
    remain known after first sighting

Zombies:
    fade from visibility after leaving LOS
    can reappear if heard nearby
```

---

# 6. Zombie AI State Machine Diagram

## High-Level State Graph

```text
          +------+
          | Idle |
          +--+---+
             |
             v
         +---+----+
         | Wander |
         +---+----+
             |
      noise  |  sees target
             v
   +---------+-----------+
   | InvestigateNoise    |
   +---------+-----------+
             |
             | target confirmed
             v
        +----+-----+
        | Chase    |
        +----+-----+
             |
             | in range
             v
        +----+-----+
        | Attack   |
        +----+-----+
             |
      target lost / blocked
             v
       +-----+------+
       | LostTarget |
       +-----+------+
             |
             v
        +----+-----+
        | Return   |
        |ToWander  |
        +----------+
```

## Trigger Summary

```text
Idle → Wander
    timer / ambient roaming

Wander → InvestigateNoise
    heard sound event

InvestigateNoise → Chase
    target visually confirmed

Chase → Attack
    attack range reached

Attack → Chase
    target moved out of range

Chase → LostTarget
    target no longer visible

LostTarget → ReturnToWander
    search timeout expired
```

## Noise Event Model

```text
NoiseEvent
{
    position
    radius
    intensity
    source_type
}
```

## Group Agitation Concept

```text
One zombie reacts to noise
    ↓
Nearby zombies inherit alert state boost
    ↓
Small local swarm forms
```

---

# 7. Chunk Streaming Diagram

## World Partition

```text
[ ][ ][ ][ ][ ]
[ ][A][A][A][ ]
[ ][A][P][A][ ]
[ ][A][A][A][ ]
[ ][ ][ ][ ][ ]
```

Legend:
- `P` = player chunk
- `A` = active chunk
- blank = inactive chunk

## Rule

Chunks within the configured radius stay loaded and simulated.

Default target:
- active radius = 2 chunks from player

## Streaming Flow

```text
Player crosses chunk boundary
   ↓
Recalculate active chunk set
   ↓
Load newly entered chunks
   ↓
Serialize and unload distant chunks
```

## Chunk State Model

```text
Loaded + Simulated
Loaded + Static
Serialized + Unloaded
```

## What Runs Only in Active Chunks

- zombie AI
- NPC updates
- dynamic lighting
- local physics
- combat interactions

---

# 8. Inventory Grid Diagram

## Grid Example

```text
+--+--+--+--+--+--+
|A |A |  |B |B |  |
+--+--+--+--+--+--+
|A |A |  |B |B |  |
+--+--+--+--+--+--+
|  |  |  |C |C |C |
+--+--+--+--+--+--+
|D |  |  |C |C |C |
+--+--+--+--+--+--+
```

Legend:
- `A` = 2x2 item
- `B` = 2x2 item
- `C` = 3x2 item
- `D` = 1x1 item

## Placement Rules

```text
Item can be placed if:
- all target cells are empty
- item remains within bounds
```

## Container Expansion

```text
Base inventory
    +
equipped backpack
    =
larger total grid
```

---

# 9. Godot Scene / System Ownership Diagram

## Suggested Ownership Model

```text
GameRoot
├── WorldManager
│   ├── ChunkManager
│   ├── TileMapLayer_Ground
│   ├── TileMapLayer_Walls
│   ├── TileMapLayer_Roofs
│   └── LightingManager
├── EntityManager
│   ├── Player
│   ├── Zombies
│   ├── NPCs
│   └── Items
├── BuildingManager
├── VisibilityManager
├── SaveManager
└── UIRoot
```

## Responsibility Split

- `ChunkManager` handles chunk load/unload
- `BuildingManager` handles wall-edge placement, blueprints, room updates
- `VisibilityManager` handles vision, LOS, occlusion fade
- `SaveManager` handles chunk serialization and restore

---

# 10. Recommended Build Order Diagram

```text
1. World grid
   ↓
2. Chunk streaming
   ↓
3. Tile-edge walls
   ↓
4. Room detection
   ↓
5. Auto roofs
   ↓
6. Occlusion + visibility
   ↓
7. Zombie AI
   ↓
8. Inventory grid
   ↓
9. Lighting
   ↓
10. Save/load
```

## Why This Order Works

Each system unlocks the assumptions needed by the next:

- Rooms need wall edges
- Roofs need valid rooms
- Occlusion needs walls and roofs
- AI navigation benefits from finalized world structure
- Save/load should serialize stable system formats

---

# 11. Claude Code Usage Note

When using this file with Claude Code, instruct it to:

1. read this diagrams file
2. read the technical implementation bible
3. use both as source-of-truth references before generating systems

Example instruction:

```text
Read:
- SimZombie_Technical_Implementation_Bible_v2.md
- SimZombie_Systems_Diagrams.md

Use these as the canonical references.

Generate Godot code for:
1. chunk streaming
2. tile-edge building
3. room detection
4. occlusion rendering
```

---

# 12. Final Rule Set

```text
Do not place walls inside tile centers.
Do not use line-drawn building walls as the final runtime model.
Do not merge room logic with rendering logic.
Do not make occlusion depend only on raw distance.
Always treat visibility, room detection, and chunk streaming as separate systems that communicate through clean data.
```
