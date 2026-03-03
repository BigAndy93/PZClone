Building Overhaul Plan
3-tile-high buildings, room subdivision, sensible furniture placement, PZ-like doors/windows
Problem Summary (current build)

Furniture orientation is inconsistent because “facing” is not derived from a stable wall/room coordinate system.

Buildings are effectively “floor diamonds with a wall ring,” not true interior volumes with walls as boundaries.

There is no authoritative interior model (rooms / edges / portals), so doors and windows can’t behave like PZ.

Furniture placement is random, not constrained to walls, corners, or room archetypes.

Overhaul Goal

Create a data-driven building generator with:

Buildings at least 3 tiles high (visual height + correct layering)

Room subdivision (multiple rooms + corridors + doors)

Furniture placement that makes sense (wall hugging, clearance, room-purpose)

Doors and windows that behave like Project Zomboid (block movement/vision when closed, openable, occlusion changes)

0) Non-Negotiable Contracts (These stop drift forever)
0.1 One authoritative tile grid

Use TileMap.map_to_local(cell) and TileMap.local_to_map(pos) everywhere.

Stop using custom iso math in some places and TileMap functions elsewhere unless proven identical.

0.2 Two separate truths

Grid truth: what tiles are floor/wall/door/window + occupancy.

Visual truth: sprites, wall height, roof, shading overlays.
Grid truth drives gameplay and placement. Visual truth follows it.

0.3 Wall edges exist on boundaries, not “inside tiles”

Project Zomboid effectively has walls on tile boundaries. We emulate that even if we render walls as tiles.

1) New Building Data Model (Authoritative)

Create a BuildingBlueprint (pure data) generated first, then rendered.

BuildingBlueprint:
- id
- bounds: Rect2i (min_cell, size)
- floor: Set<Vector2i>
- walls: Set<Edge>          # edges between adjacent tiles
- doors: Dictionary<Edge, DoorDef>
- windows: Dictionary<Edge, WindowDef>
- rooms: Array<RoomDef>
- entry_edges: Array<Edge>  # exterior doors
- height_tiles: int         # >= 3 (visual height, see section 6)
Edge representation (critical)

Represent walls/doors/windows on edges:

Edge:
- cell: Vector2i    # “owner” cell (the lower-left or canonical one)
- dir: int          # 0=N,1=E,2=S,3=W (edge direction)

This fixes 90% of door/window weirdness and makes “against wall” placement deterministic.

2) Build Generation Pipeline (Do in this order)
Phase A — Create shell

Choose building bounds (width/height in tiles).

Create initial interior floor set (all tiles inside bounds).

Create exterior wall edges around bounds.

Phase B — Subdivide into rooms

Use BSP / recursive split:

Minimum room dimension: 3×3 tiles (tune)

Randomly split along X or Y

Ensure each final room has reasonable aspect ratio

Output: a set of RoomDefs containing floor tiles and boundary edges.

Phase C — Add interior walls

Convert room boundaries into wall edges.

Phase D — Add doors (portals between rooms)

For each adjacent room pair that shares a boundary:

pick 1 door location along their shared wall (avoid corners)

mark that edge as a DoorDef

remove wall edge there or mark it as “door edge” that can block/unblock

Guarantee connectivity:

Flood fill through open portals (doors exist but considered passable for connectivity test)

Ensure all rooms reachable from main entry area

Phase E — Add windows on exterior edges

For each exterior wall edge:

windows only on exterior edges

spacing: don’t place in corners, don’t place adjacent to doors

random chance per edge segment

Phase F — Furniture placement per-room archetype

Assign each room a purpose (weighted random):

kitchen, bedroom, living, bathroom, storage, hallway

Place furniture using wall-aware anchors (section 4).

3) Tile Classification (Interior logic)

Maintain a per-tile grid:

TileInfo:
- type: FLOOR | VOID
- room_id: int (or -1)
- occupied: bool

Walls/doors/windows are not tile types; they live as edges.

This eliminates “fridge isn’t against wall” ambiguity.

4) Furniture Placement System (Wall-Aware, Room-Aware)
4.1 Furniture def must include:

footprint (w,h tiles)

pivot_in_footprint

allowed_rooms (kitchen, etc.)

wall_preference:

AGAINST_WALL

CORNER

FREE

preferred_facing_rule:

FACE_INTO_ROOM

FACE_ALONG_WALL

clearance requirements (min walk tiles around)

4.2 How to place “against wall” furniture (like fridge)

To place a fridge:

Pick candidate floor tiles in the room that have at least 1 adjacent wall edge.

For each candidate tile, identify which side(s) have wall edges.

Choose a wall side and set facing so the fridge front faces into the room.

Facing rule (this fixes your wrong-facing fridge):

If wall edge is NORTH of the pivot tile → fridge faces SOUTH

If wall edge is SOUTH → faces NORTH

If wall edge is EAST → faces WEST

If wall edge is WEST → faces EAST

This is deterministic because wall edges are explicit.

4.3 Visual wall-hug offset (worldgen only)

Apply a small visual-only offset toward the wall side (optional).
But DO NOT use this to “fake” being against a wall—being against a wall must be true in the edge model.

4.4 Layout archetypes (minimum viable)

Kitchen:

fridge AGAINST_WALL

counter segments AGAINST_WALL

stove near counter

keep 1-tile walk lane

Bedroom:

bed against wall

nightstand adjacent

Storage:

shelves along walls

Hallway:

no blocking furniture

4.5 Placement validation

For every candidate placement:

All occupied tiles must be in room.floor

No occupied tile already occupied

Clearance constraints satisfied

Must not block doorway approach tiles (reserve door clearance zone)

5) Doors & Windows Like Project Zomboid
5.1 Door behavior

Each DoorDef:

edge location

orientation (N/E/S/W)

state: OPEN/CLOSED

blocks_movement when closed

blocks_vision when closed

optional: health/barricade later

Door implementation detail

Door must exist as:

a scene/node with collider used by movement

and must also update the edge graph used by occlusion/pathfinding

Closed:

collision enabled

LoS raycasts collide
Open:

collision disabled

LoS raycasts pass

5.2 Window behavior (PZ-like)

Windows exist on exterior wall edges and behave like:

block movement by default

allow vision (optionally attenuated)

can be “opened” later

can be “smashed” later (changes movement/vision)

For now (MVP):

windows are wall edges with a special render

movement blocked

vision allowed OR partially allowed (your choice)

Important: windows should not be treated like doors (no full pass-through when “open”) unless you plan vaulting/climbing.

6) “Buildings at least 3 tiles high” (Visual height + layering)

This is visual height, not grid height.

Implement a wall renderer that draws 3 stacked layers:

Wall base (touching floor)

Wall mid

Wall top/cap

Or one tall sprite per wall edge that visually spans 3 tile-heights.

Rules:

Interior props render below wall cap

Wall cap draws over furniture/characters when appropriate

Roof hides when player inside

This makes interiors feel enclosed and fixes “flat box” look.

7) Rendering & Sorting (Stops furniture looking “outside”)

Implement consistent sorting:

Use Y-sort by world y for furniture/characters

Walls/roof use explicit draw layers:

floor layer

props layer

character layer

wall layer

roof layer (optional)

When roof is hidden:

keep wall caps visible so rooms feel tall.

8) Debug/Validation Tools (mandatory for this overhaul)

Add toggles:

draw room ids on tiles

highlight wall edges

highlight door edges

highlight window edges

show connectivity graph between rooms

show furniture anchors: pivot dots + footprint tiles

show “door clearance zones” so furniture can’t spawn blocking doors

Acceptance tests:

Every building has height >= 3 tiles visually.

Every building has >= 1 room; most have multiple.

Doors connect rooms; flood fill from entry reaches all rooms.

Fridge always spawns on a tile with a wall edge neighbor.

Fridge facing is correct (front faces into room).

Windows only on exterior wall edges and not at corners.

Doors/windows affect movement + vision correctly.

9) Implementation Order (Do not try all at once)

Implement Edge-based walls/doors/windows data model

Generate simple rectangle building + exterior wall edges

Add BSP subdivision into rooms + interior walls

Add door placement + connectivity validation

Add window placement on exterior edges

Add room archetypes + furniture wall-anchor placement

Add 3-tile-high wall rendering and layer sorting polish

Only then revisit vision polygon system (raycasts will finally have correct blockers)

Key Fix for Your Current Screenshot (why fridge is wrong)

Your generator likely decides facing based on “nearest wall tile” or a heuristic, but your wall representation is not stable. With an edge model:

“wall north of tile” is explicit

facing can be computed deterministically

“against wall” becomes a hard constraint, not a vibe

If Claude implements the edge-based wall/door/window system + room subdivision, your fridge placement and facing will stop being random and start behaving like PZ.