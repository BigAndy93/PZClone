# PZClone -- Building Overhaul & Multi‑Story Interior Design Bible

------------------------------------------------------------------------

## Purpose

This document defines the authoritative system for generating,
rendering, and simulating buildings in PZClone.\
It replaces the current ad‑hoc structure with a data‑driven, edge‑based
architectural model that supports:

-   3‑tile‑high walls (minimum)
-   Room subdivision
-   Wall‑aware furniture placement
-   Project Zomboid--style doors and windows
-   Multi‑story buildings with vertical navigation

------------------------------------------------------------------------

# 0. Core Non‑Negotiables

### 0.1 Single Grid Authority

All spatial math must use:

TileMap.map_to_local(cell)\
TileMap.local_to_map(position)

No duplicated isometric math outside grid authority.

### 0.2 Separate Grid Truth vs Visual Truth

-   Grid truth = floor tiles, wall edges, door edges, window edges,
    occupancy.
-   Visual truth = sprites, height layers, shading, roof overlays.

Gameplay always derives from grid truth.

### 0.3 Walls Exist on Tile Edges

Walls, doors, and windows are edge objects --- not tile types.

------------------------------------------------------------------------

# 1. Building Data Model

BuildingBlueprint: - id - bounds: Rect2i - floor:
Set`<Vector2i>`{=html} - walls: Set`<Edge>`{=html} - doors:
Dictionary\<Edge, DoorDef\> - windows: Dictionary\<Edge, WindowDef\> -
rooms: Array`<RoomDef>`{=html} - entry_edges: Array`<Edge>`{=html} -
height_tiles: int \>= 3 - floors: Array`<FloorLevel>`{=html}

## Edge Definition

Edge: - cell: Vector2i - dir: 0=N,1=E,2=S,3=W

This enables deterministic placement and orientation.

------------------------------------------------------------------------

# 2. Generation Pipeline

1.  Generate building footprint.
2.  Define interior floor tiles.
3.  Create exterior wall edges.
4.  Subdivide into rooms (BSP).
5.  Convert room boundaries into interior wall edges.
6.  Insert doors between rooms.
7.  Validate connectivity (flood fill).
8.  Insert windows on exterior edges.
9.  Assign room archetypes.
10. Place furniture using wall‑aware rules.

------------------------------------------------------------------------

# 3. Room Subdivision

-   Minimum room size: 3x3 tiles.
-   Avoid extreme aspect ratios.
-   Ensure every room has at least one doorway.
-   Guarantee connectivity from main entry.

------------------------------------------------------------------------

# 4. Furniture Placement Rules

Furniture definitions include:

footprint\
pivot_in_footprint\
allowed_rooms\
wall_preference\
preferred_facing_rule\
clearance_requirement

### Against Wall Logic

If a wall edge exists NORTH of tile: → Furniture faces SOUTH.

If wall SOUTH: → Face NORTH.

If wall EAST: → Face WEST.

If wall WEST: → Face EAST.

Must validate clearance and doorway paths.

------------------------------------------------------------------------

# 5. Doors & Windows (PZ‑Style)

## Doors

-   Exist on edges.
-   Have state OPEN/CLOSED.
-   Closed: block movement + vision.
-   Open: allow movement + vision.

## Windows

-   Exterior edges only.
-   Block movement.
-   Allow vision.
-   May support smash/open later.

------------------------------------------------------------------------

# 6. Wall Height & Rendering

Walls must render visually at least 3 tiles high.

Recommended render layers:

1.  Floor
2.  Furniture
3.  Characters
4.  Wall Base
5.  Wall Mid
6.  Wall Cap
7.  Roof

Roof hides when player enters building.

------------------------------------------------------------------------

# 7. Multi‑Story Building System

## 7.1 Data Model Extension

FloorLevel: - level_index - floor_tiles - wall_edges - door_edges -
window_edges - rooms - stairs_up_edges - stairs_down_edges

BuildingBlueprint.floors stores multiple FloorLevel objects.

## 7.2 Vertical Navigation

Stairs are edge‑linked portals:

StairLink: - from_level - to_level - cell_position

Movement logic: - Player enters stair tile. - Transition to target
level. - Preserve world X/Y alignment.

## 7.3 Vision Across Floors

-   Only active floor renders fully.
-   Floors above may render faded silhouettes (optional).
-   Floors below hidden unless stairwell visibility is implemented.

## 7.4 Floor Connectivity Validation

Each floor must: - Be internally connected. - Have stair access if above
ground. - Connect to ground floor through stair graph.

Perform multi‑level flood fill across stair links.

## 7.5 Structural Rules

-   Upper floors must align within lower floor footprint.
-   Exterior walls stack vertically.
-   Windows align or vary intentionally.
-   Stairwells require 2x2 minimum clearance.

## 7.6 Rendering Strategy

Each level renders in separate layer groups:

Level 2\
Level 1\
Ground Floor

Active floor fully opaque.\
Other floors reduced opacity or hidden.

------------------------------------------------------------------------

# 8. Acceptance Criteria

-   All buildings \>= 3 tiles high.
-   Rooms properly subdivided.
-   Doors connect rooms and change collision.
-   Windows only on exterior edges.
-   Furniture placed logically against walls.
-   Multi‑story buildings support stair traversal.
-   Vision and movement respect wall/door states.
-   No floating or misaligned props.

------------------------------------------------------------------------

# 9. Implementation Order

1.  Edge‑based wall system.
2.  BSP room subdivision.
3.  Door connectivity.
4.  Window placement.
5.  Wall‑aware furniture placement.
6.  Multi‑story extension.
7.  Rendering polish.
8.  Vision system integration.

------------------------------------------------------------------------

End of Document.
