# PZClone Unified Design Bible (Auto‑Combined)

This file merges all available design documents found in the uploaded archive.

---

# Source: GODOT ISOMETRIC GRID + BUILDING + FURNITURE INTEGRATION SPEC.txt





---

# Source: New Text Document.txt





---

# Source: procedurally_generated_furniture.md


# procedurally_generated_furniture.md
## High‑Quality Procedural Furniture / Props / Foliage (Godot, Isometric PZClone Style) — 4 Directions (N/E/S/W)

This document specifies a **production-grade procedural asset pipeline** for PZClone that generates **high-quality, style-consistent** furniture, props, and foliage while guaranteeing **grid alignment**, **stable pivots**, and **4-direction outputs (N/E/S/W)** suitable for worldgen and later player placement/rotation.

> Key philosophy: **Generate → Validate → Bake → Place**  
> Procedural geometry is great for variety, but **baked sprites** are what make placement, sorting, occlusion, and performance sane.

---

## 0) Definitions

### Coordinate & Facing
- Isometric camera is fixed. North is up on screen (your established convention).
- Each asset must provide **4 facings**: `N, E, S, W`.
- “Facing” means “the front of the object points toward that direction on the map.”

### Asset Output Contract (required for every asset type)
Each procedurally generated asset must output:

- `textures[4]`: ImageTexture or atlas region for N/E/S/W
- `pivot_px_offset[4]`: Vector2 (per facing)
- `footprint`: Vector2i (tile width/height)
- `pivot_in_footprint`: Vector2i (usually bottom tile for tall objects)
- Optional: `collision_shapes[4]` (simple rectangles/polygons, not per-pixel)

---

## 1) Style Constraints (Match PZClone “brooding indie / soft-grain analog horror”)

All generated art should follow these constraints:

### Palette & Values
- Use a **limited palette** per category (metal, wood, plastic, fabric, foliage).
- Avoid pure black/white. Keep highlights muted.
- Use **value separation** to imply depth:
  - Top faces lightest
  - One side medium
  - Other side darkest

### Edges & Texture
- Prefer **subtle pixel noise** or dithered grain to avoid flat fills.
- Add edge accents sparingly (1px or 2px line weight depending on scale).

### Readability
- Silhouette must read at gameplay zoom.
- Important affordances (handles, doors, knobs) must pop with tiny contrast boosts.

---

## 2) The “Bake-first” Strategy (Recommended)

Procedural assets should be generated as **parametric models**, then baked into sprites:
- Stable in Godot rendering & sorting
- Faster runtime (no procedural meshes per instance)
- Easy to pack into atlases
- Easy to align to grid via pivot offsets

### Two viable baking approaches
1) **SubViewport Bake (Godot)** — generate and render into a fixed frame.
2) **Offline Bake (Python/Blender)** — generate model, render frames, import PNGs.

This document focuses on **Godot SubViewport Bake**, since you’re already in Godot and iterating fast.

---

## 3) Universal Procedural Asset Pipeline

### 3.1 Generate (Parametric)
Each asset is produced from a **seed** and a small set of parameters:
- Dimensions (w/h/d)
- Material palette (metal/wood/etc.)
- Details toggles (handles, vents, shelves, labels)
- Wear level (clean → grimy)
- Damage state (optional later)

**Determinism requirement:** same seed → same output.

### 3.2 Validate (Shape + Footprint + Pivot)
Before baking:
- Compute tile footprint from dimensions
- Compute pivot tile and pivot pixel
- Ensure the base fits inside footprint projection
- Ensure the asset doesn’t exceed maximum allowed bounding box

### 3.3 Bake (4 facings)
Bake 4 facings into fixed-size frames (e.g., 128×128 or 192×192).
Output:
- PNG with transparency
- JSON/Resource sidecar containing pivot offsets, footprint, metadata

### 3.4 Place (Grid-aligned)
Placement in world:
- Node2D at `TileMap.map_to_local(pivot_cell)`
- Add `pivot_px_offset[facing]`
- Sprite2D draws baked texture for facing

---

## 4) 4-Direction System (N/E/S/W) — Correctness Rules

### 4.1 Camera & Exposed Faces
In your iso view, a box shows 2 vertical faces + a top face.
When you rotate the object:
- The **visible faces swap roles**.
- Some facings show **front**, others show **back**.

### 4.2 Procedural generation rule
You must define **semantic faces** on the model:
- `FRONT`, `BACK`, `LEFT`, `RIGHT`, `TOP`

Then create a deterministic mapping for each facing:

- Facing **N**: FRONT points north ⇒ camera sees mostly BACK + RIGHT
- Facing **E**: FRONT points east  ⇒ camera sees FRONT + RIGHT
- Facing **S**: FRONT points south ⇒ camera sees FRONT + LEFT
- Facing **W**: FRONT points west  ⇒ camera sees BACK + LEFT

> This matches your fridge reference logic.

### 4.3 Do NOT “flip” sprites as a shortcut
Horizontal flip sometimes works for symmetrical objects, but often breaks:
- text labels
- handle sides
- vents
- asymmetrical wear
- lighting consistency

**Correct approach:** generate/bake all 4 explicitly, using a shared semantic face model.

---

## 5) Baking in Godot (SubViewport Method)

### 5.1 Scene structure
Create an `AssetBaker.tscn` containing:
- `SubViewport` (size = frame size)
- `Camera2D` (fixed)
- `Node2D` root for the asset
- Optional: flat background (transparent)

### 5.2 Frame size guidelines
Pick one standard per category:
- Small props: 96×96
- Medium furniture: 128×128
- Large/tall furniture: 192×192 or 256×256

**Rule:** Don’t vary frame sizes frequently; it complicates atlasing & pivots.

### 5.3 Pivot pixel anchor inside frame
Decide one pivot pixel for all assets, e.g.:
- `pivot_px = Vector2(frame_w/2, frame_h*0.80)` (near bottom center)

During baking, position the generated object so its “floor contact point” lands on `pivot_px`.

### 5.4 Export output
For each seed:
- Bake 4 facings into one sheet (4 frames) or separate PNGs.
- Save metadata:
  - footprint
  - pivot_in_footprint
  - pivot_px_offset[4]
  - tags (kitchen, storage, etc.)

---

## 6) Procedural Furniture (Detailed Recipes)

### 6.1 Refrigerator (example archetype)
Parameters:
- height tiers (short/standard/tall)
- top freezer vs side-by-side
- handle style (left/right/center)
- back vent panel (always on BACK face)
- door seams
- dents/scratches

Generation steps:
1) Build a cuboid volume with slight bevels.
2) Assign semantic faces: FRONT/BACK/LEFT/RIGHT/TOP.
3) Add features:
   - FRONT: door seams + handles
   - BACK: vent grille + compressor panel
   - SIDES: subtle shading + occasional stickers/dirt
4) Apply wear:
   - bottom edge grime
   - corner scuffs
5) Bake 4 facings using semantic mapping in section 4.

Footprint:
- Usually `1×1` footprint; “tall” is visual, not extra footprint.
- If you simulate “2 tiles tall” occupancy, keep it as metadata (blocks vision/hits), but placement footprint stays 1×1 unless you want it to block a second tile.

### 6.2 Tables / Counters
Parameters:
- length (1–3 tiles)
- thickness
- legs style
- clutter density (optional)

Rules:
- Counters always hug walls in worldgen.
- Tables prefer center with clearance.

Procedural details:
- Top face wood grain via 2–3 noise bands.
- Edge highlights on top rim.

### 6.3 Shelves / Lockers
Parameters:
- number of compartments
- door count
- vent slots
- label plates

Rules:
- Often against wall.
- Asymmetry allowed for realism, but keep semantic face mapping.

---

## 7) Procedural Props (Small Items)

Examples:
- boxes, cans, bottles, tools, batteries, ammo boxes, books

High-quality prop rule:
- 1 strong silhouette + 1–2 detail cues
- small highlight on top face
- shadow contact at base

Generation pattern:
- Pick prop archetype
- Randomize dimensions within tight ranges
- Add 1 signature detail (label band, cap, handle)
- Apply subtle noise
- Bake 4 facings (many can share N/S or E/W if truly symmetric, but default to 4)

---

## 8) Procedural Foliage (Trees, Bushes, Grass)

### 8.1 Trees (Isometric billboard + volume hybrid)
Parameters:
- trunk height/width
- canopy radius
- leaf clump count
- season tint (optional)

Generation:
1) Trunk: tapered column with 2–3 shade bands.
2) Canopy: layered clumps (3–7 blobs) with varying alpha/brightness.
3) Ground shadow blob (soft, dithered).
4) Bake 4 facings:
   - Keep trunk consistent
   - Slightly shift canopy clumps per facing to avoid obvious repetition

### 8.2 Bushes
Parameters:
- silhouette shape
- clump count
- berry/flower toggles

Rules:
- Ensure footprint reads 1×1 or 2×1 depending on size.
- Collision often smaller than visual for movement flow.

### 8.3 Grass / weeds
Use tile decals, not sprites, for performance:
- generate small overlay textures that can be scattered
- random rotation (visual only) is acceptable

---

## 9) Lighting & Shading Consistency (Critical)

Define one global light direction for sprites:
- Example: light from **NW** (top-left)

Shading rules:
- TOP face: +15% brightness
- Lit side: baseline
- Dark side: -15% brightness
- Ambient occlusion: darken base edges and wall-contact edges slightly

This must be applied consistently across furniture, props, foliage.

---

## 10) Pivot, Footprint, and Placement Alignment

### 10.1 Recommended pivot conventions
- Place pivot at **bottom tile center**.
- For tall objects, pivot still bottom contact (do not center vertically).

### 10.2 Per-facing pivot offset
Even baked frames need micro offsets per facing due to projection. Store:
- `pivot_px_offset[N/E/S/W]`

### 10.3 Debug tools required
- Footprint overlay (diamonds)
- Pivot dot (magenta)
- Visual pivot dot (cyan)
- Bounding box outline (optional)

Acceptance:
- Pivot dot stays locked to tile center across all 4 facings.
- Sprite appears “seated” on the tile, not floating.

---

## 11) Variation System (Make it feel hand-made)

Each asset class should have:
- 3–7 base archetypes
- 5–20 parameter permutations each
- wear states
- rare variants (stickers, dents, missing handle)

Suggested deterministic randomization:
- Seed = `(chunk_seed, building_id, room_id, item_index)`

Avoid pure noise chaos; keep ranges tight.

---

## 12) Performance & Caching

Runtime should **not** generate complex assets every frame.
Recommended:
- Bake to disk once per seed (cache).
- On chunk load, load baked sprite + metadata.
- Keep an LRU cache for recently used textures.

For foliage:
- Prefer instancing and tile decals for small plants.

---

## 13) Deliverables Checklist (What Claude Should Build)

1) `FurnitureDef` / `PropDef` / `FoliageDef` resources with:
   - footprint, pivot, 4 textures, 4 pivot offsets
2) `AssetBaker` tool scene:
   - given (type, seed) → outputs PNG(s) + metadata JSON
3) `AtlasPacker` (optional):
   - pack generated PNGs into an atlas
4) Worldgen placement uses defs, not ad-hoc sprites

---

## 14) Quick “Rules of Thumb”

- Generate semantic faces first; map to facings later.
- Always bake 4 facings; do not rely on flipping except for truly symmetric items.
- Keep one global light direction across all assets.
- Prefer baked sprites for stable placement and performance.
- Use debug overlays until alignment is perfect.

---

End of file.




---

# Source: PZClone_Art_Bible.md

PROJECT: ZOMBOID-STYLE SURVIVAL GAME
VISUAL DIRECTION & ART PIPELINE DOCUMENT
Style: Soft-Grainy Analog Horror (Stylized Indie)
1. VISUAL IDENTITY LOCK
1.1 Core Tone

Emotional direction:

Quiet dread

Faded reality

VHS decay

Subtle loneliness

Slow rot, not explosive chaos

This is not:

Cartoon horror

Neon gore

Hyper-saturated survival arcade

World mood:
“The world did not end loudly. It decayed quietly.”

2. ART STYLE RULES (NON-NEGOTIABLE)
2.1 Palette Discipline

Use:

Desaturated greens

Sickly browns

Cold blue shadows

Dusty warm lamp glows

Avoid:

Pure black (#000000)

Pure white (#FFFFFF)

High-saturation primaries

Darkest value:
Deep navy or green-charcoal

Brightest value:
Soft bone or dusty yellow

All procedural and AI assets must map into this controlled palette.

2.2 Lighting Rules

Primary light source:

Top-left cool moonlight

Secondary light source:

Warm interior practical lights

Shadows:

Cool-toned

Never fully black

All sprites must obey:

Top edges lighter

Bottom/right edges darker

Subtle drop shadow baked in

2.3 Grain & Analog Effects (Post-Process Layer)

Global screen overlay:

5–8% static grain

Subtle vignette

Very faint scanline pattern

Optional micro chromatic offset

These are not baked into sprites.
They are post-process layers applied to entire render.

3. TECHNICAL ART SPECIFICATIONS
3.1 Tile System

Tile size: 64x64
Character height: 112–128px
Sprite directions: 8 (N, NE, E, SE, S, SW, W, NW)

Minimum animation:

Idle

Walk (4 frames)

Future:

Sneak

Rest

Attack

3.2 Character Model Architecture

All characters (players, NPCs, zombies) follow modular layering:

Base Model (underwear only)

Clothing overlay

Bag overlay

Damage overlay

Dirt overlay

Shadow overlay

No full baked characters.
Everything must layer.

Zombie differentiation:

Slight shoulder slump

Slightly longer arms

Desaturated gray-green skin shift

Subtle darker eye sockets

No exaggerated monster anatomy.

4. PROCEDURAL ART SYSTEM (PATH B)

Goal:
High-quality rule-driven procedural sprite generation.

4.1 Procedural Asset Pipeline

Instead of:

Generate shape → render

Use:

Generate base silhouette
→ Apply controlled palette color
→ Apply vertical gradient
→ Apply shadow mask (top-left lighting)
→ Apply grime mask
→ Apply edge highlight
→ Export sprite
→ Global grain applied at runtime

4.2 Constrained Randomization

All randomness must operate within defined style bounds.

Example:

Chair:

Base template A/B/C

Leg style short/angled

Palette limited to approved swatches

Damage probability: 20%

Dirt intensity: 0–30%

Never allow:
Unbounded color generation.
Unbounded shape distortion.

Style consistency > maximum variation.

4.3 Building Generation Pipeline

Generate layout grid
→ Apply structural tileset
→ Apply window rules
→ Apply damage mask
→ Apply dirt overlay
→ Apply lighting overlay
→ Apply ambient shadow mask

Windows must be darker than walls.
Walls must have subtle vertical gradient.

5. AI-ASSET PIPELINE (PATH C)

Goal:
Use AI for base sprite production, then normalize to style.

5.1 AI Role

AI generates:

Base body sprite sheets

Clothing overlays

Furniture bases

Environmental props

AI does NOT define final palette.
All outputs must be post-processed.

5.2 AI Generation Rules

When generating sprites:

Neutral lighting

Minimal strong highlights

Clear silhouette

Transparent background

Front-facing orthographic or isometric consistency

No baked heavy grain

Prompt tone:
“desaturated, analog horror, muted tones, soft lighting, indie pixel art, top-down isometric”

5.3 Post-Processing Pipeline (Mandatory)

All AI assets must pass through:

Palette remap → Style normalization
Shadow overlay pass
Highlight pass
Grime overlay
Export
Runtime grain overlay

AI is a base generator.
Final look is system-controlled.

6. ATMOSPHERIC SYSTEM INTEGRATION

To reinforce analog horror mood:

Add runtime systems:

Slow-moving fog layers

Subtle parallax haze

Flickering interior lights

Soft flashlight cone with grain visible inside beam

Zombie fade-to-grain when leaving sight cone

When occlusion hides zombies:
They should dissolve into grain, not pop out.

7. QUALITY CONTROL CHECKLIST

Before approving any asset:

Does it obey palette constraints?

Does it obey lighting direction?

Does it avoid pure black/white?

Does it maintain strong silhouette?

Does it feel faded, not vibrant?

Does it look consistent beside existing assets?

If any answer is no:
Reprocess asset.

8. PRODUCTION STRATEGY

Hybrid model:

Core assets:

AI-assisted base generation

Hand-cleaned key sprites

Variation:

Procedural overlays (dirt, damage, palette shifts)

Global:

Post-process grain & analog filters unify everything

Goal:
System-driven cohesion.
Not hand-drawn chaos.

9. LONG-TERM STYLE GUIDELINE

This world should always feel:

Slightly cold

Slightly dusty

Slightly quiet

Slightly deteriorated

Never glossy.
Never neon.
Never heroic.

Survival is mundane.
Horror is subtle.

END OF DOCUMENT.



---

# Source: PZClone_Interior_Design_Bible.md

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




---

# Source: PZClone_Vision_Sytem.md

GODOT VISION SYSTEM v1 (HYBRID C)
Cone-Directed Vision + Wall/Door Occlusion (Upgrade Path to B)
GOALS

Vision depends on facing direction (cone).

Vision is blocked by walls and CLOSED doors.

Vision reveals only what is actually visible (no “cone through walls”).

System supports interiors, tight corridors, and door gameplay.

Later upgrade to pure LoS polygon (B) with minimal refactor.

CORE IDEA

Render a visibility mask each frame:

Cone defines intent (where player is looking).

Rays define occlusion (where player can actually see).

Result is a clipped visibility polygon (or wedge polygon with occlusion edges).

Use it as a screen/world mask: visible inside, dark outside.

This starts as “cone + rays” (C) and naturally becomes full 360° rays (B).

DATA + COLLISION SETUP
Physics layers (must be consistent)

Layer: VISION_BLOCKER

Walls: ON

Closed doors: ON

Open doors: OFF

Large blocking furniture: optional ON (if you want furniture to block sight)

Movement blockers can be separate. Vision blockers are specifically what occludes sight.

Door toggle must change collision layer membership or enable/disable the occluder collider.

INPUTS

Player world position origin

Facing direction unit vector dir

Vision range R (pixels or world units)

Vision cone angle θ (e.g. 90°–120°)

Ray count N (start at 64; tune to 96/128 if needed)

Optional “hearing reveal” is separate (not part of this doc)

OUTPUTS

A polygon (list of points) describing visible area

A mask texture / polygon drawn to Viewport (SubViewport) used for shading/visibility

ALGORITHM (HYBRID C)
Step 1: Build cone rays

Compute cone start angle and end angle around dir.

Generate N ray angles evenly in that range.

For each ray:

Cast physics ray from origin to origin + ray_dir * R

If hit something on VISION_BLOCKER:

endpoint = hit position (slightly inset along normal to avoid z-fighting)

else:

endpoint = max range point

Collect endpoints in angular order.

Step 2: Add “edge refinement” rays (important)

To avoid seeing through thin wall edges:

For each ray hit:

Cast 2 extra rays at angle ±ε (epsilon like 0.5°–1.0°)
This catches corners and makes doorways look correct.

Step 3: Construct visibility polygon

Polygon points:

First point: origin

Then append endpoints in sorted angular order

This yields a wedge-shaped visibility polygon that respects occlusion.

Step 4: Render mask

Render the polygon into a mask layer:

White = visible

Black = unseen
Then composite:

World outside mask darkened + grain/vignette

World inside mask normal brightness (or lightly graded)

RENDERING OPTIONS IN GODOT (PRACTICAL)
Option A (simple): DrawPolygon2D as mask

Use a SubViewport + ColorRect shader that uses the SubViewport texture as mask.

Render visibility polygon into SubViewport each frame.

Option B (fast): Use Light2D with occluders (future-friendly)

Godot 2D lights + LightOccluder2D can do occlusion.

BUT you want a directional cone + custom reveal rules.

This can still work, but is less controllable for “seen stays visible” rules.
Recommended only if you want quick wins and accept constraints.

Preferred for your game: Option A (custom mask), because you already have special visibility rules.

DOORS IN VISION SYSTEM

Each door has:

state OPEN/CLOSED

when CLOSED:

collider belongs to VISION_BLOCKER

when OPEN:

collider removed from VISION_BLOCKER (or disabled)
Vision polygon will automatically reveal through open doorways.

“SEEN STAYS VISIBLE” RULE (YOUR PRIOR SPEC)

Maintain a fog-of-war memory:

If a pickup/consumable is seen once, it remains visible after turning away.

Zombies fade out after leaving cone unless audible/close enough.

Implementation note:

The vision mask controls “currently visible area.”

A second “memory mask” or per-entity visibility state handles “previously seen.”

So don’t bake memory into the mask—track it per entity:

if entity enters current visible polygon => set seen=true and last_seen_time=now

pickups: render if seen==true

zombies: render at alpha based on time since last_seen AND hearing checks

PERFORMANCE NOTES

Start with N=64 + corner refinement rays only when hits occur.

Update at 20–30 Hz (timer) instead of every frame if needed.

Recompute immediately on:

player moved > small threshold

facing changed > small threshold

door toggled

Otherwise reuse last polygon.

UPGRADE PATH TO PURE B (FULL LoS)

To transition from C → B:

Change ray angles from “cone only” to “full 360°”

Keep the same raycast + polygon build system

Optionally add more edge refinement around every hit

The renderer and entity “seen memory” logic remains unchanged

So the only thing that changes is the ray angle sampling domain:

C: angles in [dir-θ/2, dir+θ/2]

B: angles in [0, 2π)

VISUAL TUNING FOR ANALOG HORROR

Outside mask: darker + grain + slight vignette

Inside mask: normal with subtle grading

Boundary: soft feather (1–3px blur) to avoid harsh aliasing

Doors/corners should produce strong readable shadows (structural dread)

DELIVERABLES (IMPLEMENTATION CHECKLIST)

Create VISION_BLOCKER collision layer.

Mark walls and CLOSED doors as blockers.

Implement cone raycasting + epsilon corner rays.

Construct polygon points and render into SubViewport mask.

Composite world using mask.

Add per-entity memory for pickups and fading for zombies.

Add recompute throttling.



---

# Source: Sprite_Template_Bible.md

SPRITE SHEET LAYOUT TEMPLATE
Soft-Grainy Analog Horror – Isometric 8 Direction
1. GLOBAL SPRITE RULES

Tile Size: 64x64
Character Height: 120px target
Canvas per frame: 128x128
Padding per frame: 8px safe margin

All sprites centered consistently on:

Foot pivot point (ground anchor)

Same Y alignment across frames

2. DIRECTION ORDER (LOCK THIS)

Always use this order:

Row 1: N
Row 2: NE
Row 3: E
Row 4: SE
Row 5: S
Row 6: SW
Row 7: W
Row 8: NW

Never change this order.
Your animation system will depend on it.

3. BASIC WALK CYCLE SHEET
Sheet Dimensions

Directions: 8
Frames per direction: 4

Grid layout:

Columns: 4 (frames)
Rows: 8 (directions)

Total canvas:

Width: 4 × 128 = 512px
Height: 8 × 128 = 1024px

Final sheet size:
512x1024

4. FRAME TIMING

Walk cycle:
Frame 1 – Contact
Frame 2 – Passing
Frame 3 – Opposite Contact
Frame 4 – Passing

Playback speed:
6–8 frames per second

Keep motion subtle.
No exaggerated limb swing.

5. IDLE SHEET

Frames per direction: 2
Subtle breathing animation.

Sheet layout:

Columns: 2
Rows: 8

Canvas:
256x1024

6. LAYERED CHARACTER SYSTEM

Each layer must follow identical sheet structure.

Required layers:

base_body.png
shirt_overlay.png
pants_overlay.png
bag_overlay.png
damage_overlay.png
shadow_overlay.png

Each sheet:
Same dimensions
Same pivot alignment
Same frame ordering

No exceptions.

7. PIVOT & ALIGNMENT RULES

The ground contact pixel must:

Be identical position in every frame

Match across every layer

Match across every direction

Recommended anchor:
Center bottom third of canvas.

If pivot drifts:
Animation will wobble.

8. ZOMBIE VARIANT SHEET

Same structure.

Differences:

Slight forward hunch

Lower arm resting position

Slightly slower walk cycle (5–6 fps)

Optional:
1 extra frame for stagger effect.

9. FURNITURE SHEETS

Furniture does NOT animate (initially).

Single-frame per orientation.

Recommended:

64x64 for small objects
128x128 for large objects

Directional rule:
Only render additional angles if gameplay requires rotation.

Otherwise:
Use baked lighting.

10. EXPORT SETTINGS

PNG

Transparent background

No baked grain

No baked vignette

No compression artifacts

Grain is applied at runtime.

11. OPTIONAL FUTURE EXPANSION

Sneak animation:
Same sheet structure as walk.

Attack animation:
6-frame sheet.
Same 8-direction layout.

Death animation:
Can break structure (separate sheet allowed).

PRODUCTION RECOMMENDATION FOR YOU

Since you're using:

Local models

ComfyUI

Procedural system

Best setup:

Generate single clean base pose.

Use ControlNet openpose for consistent directional turns.

Generate each direction separately.

Assemble into sheet via script.

Run through palette normalization tool.

I can even generate you a:

Python script that auto-assembles directional PNGs into sheets.

Now — next decision:

Do you want me to:

A) Generate a visual diagram of the sprite sheet layout
B) Generate a starter base-body sprite sheet example
C) Write a sheet-assembly Python script
D) Design your AI prompt pack for consistent sprite generation

Pick one and we build your art pipeline properly.



---

# Source: AI_Agent_Reference.md

# PZClone — AI Agent Reference Guide

When modifying this project:

1. Respect Authoritative Host rules.
2. Never allow client-side inventory mutation.
3. Always define:
   - Authority owner
   - Replication policy
   - Message types
4. Update relevant Bible before implementing new systems.
5. Preserve 1–4 player co-op focus.

This file is the canonical reference for AI-assisted development.




---

# Source: Design_Bible_v1.md

# PZClone — Design Bible v1
1–4 Player Cooperative Survival Simulation

## Core Identity
PZClone is survival with close friends.
Every system must reinforce:
- Dependence
- Shared consequences
- Emergent stories
- Scarcity-driven decisions

Single-player is supported but not the primary design driver.

## Design Pillars
1. Co-op First
2. Authoritative Simulation
3. Emergent Systems > Scripted Events
4. Scarcity Creates Drama
5. Meaningful Time

## Core Gameplay Loop
Spawn → Scavenge → Manage Needs → Avoid/Fight → Secure Shelter → Improve Base → Survive

## Emotional Goals
Players should regularly say:
- “Don’t sprint — you’ll pull them!”
- “Cover me while I barricade!”
- “We should head back before dark.”

If systems don’t create these moments, redesign them.




---

# Source: Procedural_World_Generation_Bible_v1.md

PZClone — Procedural World Generation Bible v1
Towns, Buildings, Scenery, Foliage & Fauna
1. World Generation Philosophy

The world must feel:

Lived in

Believable

Structurally logical

Risk-layered

System-supportive

Procedural does NOT mean random chaos.

It means:

Structured randomness guided by systemic rules.

2. World Structure Model
2.1 Macro World Layout (Layer 1)

World divided into:

Regions

Districts

Blocks

Lots

Tiles

Region Types

Residential suburb

Commercial strip

Industrial zone

Rural farmland

Forest outskirts

Highway / road network

Each region defines:

Building density

Zombie density modifier

Loot rarity bias

Foliage density

Fauna density

Sightline complexity

3. Generation Order (Critical)

Generation must happen in layered passes:

Terrain height + biome

Road network

District zoning

Lot subdivision

Building placement

Building interior generation

Scenery props

Foliage

Fauna spawn tables

Loot seeding

Never mix layers.

4. Terrain & Biomes
4.1 Terrain

Keep mostly flat (urban realism), but support:

Slight elevation differences

Drainage dips

Forest density shifts

Water bodies (future)

Noise-based heightmap:

Low amplitude

Smoothed

Limited vertical variation

4.2 Biome Types

Suburban grassland

Dense woodland

Light woodland

Roadside scrub

Abandoned lot overgrowth

Biome influences:

Tree density

Grass density

Zombie wander behavior

Fauna types

5. Road Network Generation

Roads define civilization.

5.1 Road Hierarchy

Main roads (arteries)

Secondary roads

Side streets

Driveways

Dirt paths (rural)

Use:

Grid-based for suburban

Slight variation offsets to avoid rigid repetition

Intersections must:

Align with zoning rules

Create logical traffic flow

6. Zoning System

Each block assigned zoning:

Residential Low Density

Residential Medium

Commercial Small

Commercial Large

Industrial

Rural

Zoning determines:

Lot size

Building templates

Prop density

Loot bias

Zombie density bias

7. Building Generation System
7.1 Building Archetypes

Each building type defined by:

Footprint size range

Room layout patterns

Prop sets

Loot table link

Structural integrity value

Residential

Small house

Medium house

Duplex

Apartment (future)

Commercial

Convenience store

Pharmacy

Hardware store

Restaurant

Office

Industrial

Warehouse

Storage yard

Garage

7.2 Building Footprint Placement

Must not overlap roads

Must respect lot bounds

Must align with driveway rules

Maintain setback from street

7.3 Interior Layout Generation

Interior generated from:

Predefined room modules

Procedural room connectors

Weighted adjacency rules

Example adjacency rules:

Bathroom adjacent to bedroom or hallway

Kitchen near exterior wall

Commercial storage in back room

Office near front entrance

Interior must be navigable and readable from isometric camera.

8. Prop & Scenery Placement

After building placement:

8.1 Exterior Props

Trash cans

Mailboxes

Fences

Vehicles (future)

Dumpsters (commercial)

Rules:

Must not block doorways

Must respect collision grid

Clutter increases stealth complexity

8.2 Interior Props

Furniture

Shelving

Counters

Fridges

Cabinets

Placement rules:

Maintain pathing lanes

Avoid unreachable loot spots

Respect room type

9. Foliage System

Foliage must serve gameplay:

Break line-of-sight

Affect stealth

Affect zombie pathing (optional slowdown)

9.1 Tree Types

Large tree (blocks vision fully)

Medium tree

Bush (partial vision block)

Tall grass (stealth modifier)

9.2 Growth Model (Optional Future)

Over time:

Grass spreads

Abandoned lots overgrow

Roads crack

This reinforces world decay.

10. Fauna System (Future Layer)

Fauna is NOT cosmetic.

Animals should:

Move in herds or pairs

React to noise

Potentially attract zombies

Provide survival resource (food)

Initial fauna types:

Deer

Stray dog

Crows

Fauna states:

Idle graze

Flee noise

Wander

Dead carcass (lootable)

11. Loot Seeding Integration

Loot seeded AFTER building and prop placement.

Each container:

Uses deterministic seed based on:

World seed

Chunk coordinates

Container ID

This prevents:

Loot duplication

Desync between sessions

12. Zombie Density Mapping

Zombie spawn density influenced by:

Region type

Noise history

Player activity heatmap

Time since world start

Urban core > suburbs > rural.

13. Performance Considerations
Chunk System

World divided into chunks.

Each chunk stores:

Terrain

Buildings

Containers

Props

Zombie instances

Fauna instances

Chunks:

Load on proximity

Unload outside radius

Persist diffs only

14. Emergent Map Goals

The map must allow:

Safehouse strategy

Chokepoints

Ambushes

Long sightlines

Dense blind corners

Forest escape routes

If terrain prevents tactical decisions, redesign generation rules.

15. Replayability Rules

Avoid:

Identical block repetition

Symmetry across regions

Overuse of rare building types

Use:

Weighted distribution

Regional personality

Seed-based variety

16. World Personality System (Optional Advanced)

Each world seed generates:

Slight economic bias

Slight zombie density bias

Slight weather pattern bias

Slight building condition bias

This makes worlds feel different without extreme changes.

17. Testing Requirements

World generation must support:

Seed override input

Debug overlays for:

Zoning

Pathing grid

Zombie density map

Loot rarity heatmap

Foliage density map

18. What Not To Do

Do not:

Randomly scatter buildings without zoning

Place loot before finalizing building placement

Overload map with clutter early

Generate navmesh after every small prop

19. Long-Term Vision

Eventually:

Vehicles integrated with road logic

Wildlife hunting

Seasonal changes

Migration events

Procedural small towns stitched together

End of World Generation Bible v1



---

# Source: Production_Content_Bible_v1.md

\# PZClone — Production \& Content Bible v1



This document defines all non-network, non-core-architecture development domains.

It exists to ensure design consistency, content scalability, and long-term production clarity.



---



\# 1. Content Philosophy



PZClone is systemic, not scripted.

Content should support systems — not replace them.



No quest chains.

No forced missions.

No linear campaign gating.



Instead:



\* Environmental storytelling

\* Systemic events

\* Dynamic world decay

\* Player-driven goals



---



\# 2. Art Direction Bible



\## Visual Goals



\* Top-down isometric

\* Grounded realism

\* Muted palette with strong contrast lighting

\* Night visibility tension



\## Environment Principles



\* Clutter supports gameplay (line-of-sight blockers)

\* Interiors readable from iso angle

\* Doors/windows clearly readable states

\* Barricades visually communicate durability



\## Zombie Visual Philosophy



\* Subtle variation > extreme mutation

\* Clothing variation from civilian types

\* Damage states visually degrade



---



\# 3. Audio Design Bible



\## Audio Pillars



1\. Silence is tension.

2\. Distance must be readable by ear.

3\. Directional awareness is critical.



\## Categories



\* Footsteps by surface

\* Door interactions

\* Zombie groans (distance-variant)

\* Ambient world loops

\* Interior vs exterior reverb



Audio must inform player decisions.



---



\# 4. Survival Systems Expansion Bible



\## Injury System Roadmap



\* Bleeding (bandage required)

\* Infection chance

\* Fractures (movement penalty)

\* Pain (stamina regen penalty)



\## Temperature System



\* Clothing insulation value

\* Wetness modifier

\* Heatstroke / hypothermia thresholds



\## Fatigue \& Sleep



\* Sleep quality depends on safety

\* Interrupted sleep events possible



---



\# 5. Progression Philosophy



No XP grind.



Progression comes from:



\* Surviving longer

\* Finding better tools

\* Improving base

\* Player skill mastery



Optional soft skill growth (low-impact):



\* Faster crafting

\* Reduced stamina drain



---



\# 6. Loot Economy Bible



\## Loot Rules



\* Scarcity increases over time

\* Loot tables vary by building type

\* Rare items gated by risk zones



\## Building Types



\* Residential

\* Convenience store

\* Hardware store

\* Clinic

\* Warehouse



\## Rarity Tiers



\* Common

\* Uncommon

\* Rare

\* Extremely rare



Loot must drive risk-taking.



---



\# 7. World Simulation Bible



\## Power \& Water



\* Configurable shutoff window

\* Post-shutoff survival shift



\## Weather



\* Rain reduces visibility

\* Storms increase noise masking

\* Fog reduces zombie vision



\## Meta Events



\* Helicopter noise event

\* Horde migration pulse



---



\# 8. Zombie Evolution Philosophy



No super zombies.



Variation through:



\* Speed variants (rare)

\* Health variance

\* Sensory strength variance



Balance over spectacle.



---



\# 9. UX \& Interface Bible



\## Principles



\* Minimal UI

\* Information earned through play

\* No cluttered overlays



\## HUD



\* Health

\* Stamina

\* Hunger/Thirst icons

\* Time indicator



Inventory UI must be fast and readable.



---



\# 10. Modding Forward Compatibility



Future-proof:



\* Data-driven items

\* Data-driven loot tables

\* JSON/Resource-based definitions



Keep logic separate from data.



---



\# 11. Production Roadmap Structure



\## Milestone 1



Multiplayer vertical slice



\## Milestone 2



Survival loop depth



\## Milestone 3



Emergent co-op moments



\## Milestone 4



World decay \& long-term depth



---



\# 12. Scope Protection Rules



Do not add:



\* Large NPC factions before core loop stable

\* Vehicles before survival depth feels complete

\* Complex crafting trees early



Stability > Feature count.



---



\# End of Production \& Content Bible v1







---

# Source: README.txt

PZClone Bible Package
Generated: 2026-02-23T02:36:25.570004

Files Included:
- Design_Bible_v1.md
- Technical_Bible_v1.md
- Production_Content_Bible_v1.md
- AI_Agent_Reference.md
- Precedural_World_Generation_Bible_v1.md

Place these in your project root.
Point Claude or other AI agents to AI_Agent_Reference.md as the canonical guide.




---

# Source: Technical_Bible_v1.md

# PZClone — Technical Bible v1
Godot | Authoritative Host | Steam Co-op

## Network Model
- Authoritative Host
- Direct IP (dev)
- Steam Invites (release)
- 1–4 player cap

## Authority
Host owns:
- Zombie AI
- Loot generation
- Containers
- Time/weather
- Save/load

Clients may predict:
- Own movement only

## Replication
Players: 20Hz
Zombies: 8–12Hz
World: 1–2Hz

## Entity Rules
Every entity must have:
- entity_id
- replication_policy
- owner_type

No client may mutate authoritative state.




---

# Source: Base_Management_Spec_v2.md

# PZClone — Base Management System Spec v2

## Base Stats
- Defense Rating
- Food Stockpile
- Water Stockpile
- Morale
- Population

## Zones
- Storage
- Sleeping
- Medical
- Workshop
- Guard Post

NPCs assigned per zone.
Zones modify base stats.




---

# Source: Cooperative_Mechanics_Spec_v2.md

# PZClone — Cooperative Mechanics Spec v2

## Downed State
- Player incapacitated
- Teammate revive window
- Bleed-out timer

## Drag / Carry
- Movement speed penalty
- Noise increase while dragging

## Heavy Object Carry
- Requires 2 players
- Shared stamina drain

## Group Dynamics
- Shared noise consequences
- Shared risk in combat




---

# Source: Diplomacy_Raid_Spec_v2.md

# PZClone — Diplomacy & Raid System Spec v2

## Diplomacy Events
- Trade Offer
- Alliance Request
- Non-aggression Pact
- Territory Dispute

## Raid Conditions
Triggered by:
- High aggression faction nearby
- Low player defense
- Resource abundance

Raid resolution:
- Simulated combat if off-screen
- Real combat if player present




---

# Source: Faction_Core_Systems_v2.md

# PZClone — Faction Core Systems Spec v2

## Faction Identity Model
Each faction contains:
- faction_id
- leader_id
- personality_profile
- aggression_level
- trust_baseline
- resource_pressure
- territory_zones

## Personality Profiles
- Defensive
- Opportunistic
- Isolationist
- Cooperative
- Militarized

Profiles influence diplomacy and raid likelihood.




---

# Source: NPC_Companion_AI_Spec_v2.md

# PZClone — NPC Companion AI Spec v2

## State Machine
Idle → Task → Assist → Combat → Flee → Recover → Idle

## Skill Types
- Combat
- Medical
- Scavenging
- Crafting
- Guarding

NPC performance scales with morale.
Host authoritative AI.




---

# Source: README.txt

PZClone Bible Package v2
Generated: 2026-02-23T02:47:05.648881

Files Included:
- Zombie_AI_Deep_Spec_v2.md
- Survival_Systems_Spec_v2.md
- Replication_Optimization_Spec_v2.md
- Steam_Integration_Spec_v2.md
- Cooperative_Mechanics_Spec_v2.md

Add this entire folder to Claude's workstation after core gameplay loop stabilizes.

PZClone Faction Expansion v2
Generated: 2026-02-23T04:33:01.666972

Files Included:
- Faction_Core_Systems_v2.md
- Reputation_Loyalty_Spec_v2.md
- NPC_Companion_AI_Spec_v2.md
- Base_Management_Spec_v2.md
- Diplomacy_Raid_Spec_v2.md

Add after core survival + co-op loop is stable.





---

# Source: Replication_Optimization_Spec_v2.md

# PZClone — Replication Optimization Spec v2

## Interest Management
- Radius-based scoping
- Entity visibility buckets

## Snapshot Compression
- Delta compression
- Quantized positions
- Animation state bit-packing

## Performance Targets
- 4 players
- 300–500 zombies active
- Stable under 150ms latency

## Debug Tools
- Snapshot rate monitor
- Bandwidth graph
- Desync checksum comparison




---

# Source: Reputation_Loyalty_Spec_v2.md

# PZClone — Reputation & Loyalty System Spec v2

## Reputation Levels
- Hostile
- Suspicious
- Neutral
- Friendly
- Loyal

Reputation tracked:
- Per NPC
- Per faction

## Loyalty Formula
Loyalty = (Reputation + Morale + Safety) - ResourceStress

Low loyalty → desertion risk.
High loyalty → combat + work bonuses.




---

# Source: Steam_Integration_Spec_v2.md

# PZClone — Steam Integration Spec v2

## Goals
- Invite-only co-op
- NAT traversal support
- Seamless session joining

## Flow
1. Host creates Steam session
2. Friends accept invite
3. Game launches into session

## Requirements
- Steam session ID mapping
- Lobby metadata (version, player count)
- Graceful disconnect handling

Transport layer must remain abstracted from gameplay logic.




---

# Source: Survival_Systems_Spec_v2.md

# PZClone — Survival Systems Expansion Spec v2

## Injury Model
- Bleeding (bandage required)
- Deep wound (stitch required)
- Fracture (movement penalty)
- Infection progression
- Pain modifier affecting stamina

## Temperature System
- Clothing insulation values
- Wetness state
- Heatstroke / Hypothermia thresholds

## Fatigue & Sleep
- Sleep quality modifier by safety
- Interrupted sleep events
- Exhaustion penalties

All survival stats synchronized via host authority.




---

# Source: Zombie_AI_Deep_Spec_v2.md

# PZClone — Zombie AI Deep Spec v2

## AI Philosophy
Zombies are simple individually but dangerous collectively.
Emergent swarm behavior > complex individual intelligence.

## State Machine

Idle → Roam → Investigate Noise → Chase → Attack → Search → Disengage

### Perception
- Vision cone (angle + distance)
- Hearing radius (noise-based)
- Memory timer (last known position)

### Aggro Rules
- Highest intensity noise wins
- Line-of-sight boosts priority
- Losing target triggers Search state

### Horde Logic (v2)
- Noise clustering pulls nearby zombies
- Migration pulses move idle groups
- Optional late-game aggression scaling

Host authoritative simulation only.




---

# Source: Design_Bible_v3.md

# PZClone — Design Bible v3

## Core Identity
PZClone is a 1–4 player cooperative survival simulation focused on long-term settlement building and leadership.

The evolution path:
Survival → Safehouse → Recruitment → Faction Growth → Base Expansion → Territory Influence

## Updated Pillars (V3)

1. Co-op First
2. Authoritative Simulation
3. Emergent Systems
4. Scarcity & Risk
5. Meaningful Time
6. Leadership & Responsibility

Players are not just survivors.
They become leaders.

---

## Late-Game Direction (V3 Expansion)

Once NPC & faction foundation exists:

- Survivors can be recruited to live at your base.
- Safehouses evolve into structured settlements.
- Players assign jobs and roles.
- Morale and loyalty influence stability.
- Bases can expand physically and functionally.
- Command and delegation become core mechanics.

---

## Emotional Evolution

Early Game:
"We barely survived."

Mid Game:
"This is our safehouse."

Late Game:
"They depend on us."




---

# Source: Faction_Territory_Spec_v3.md

# PZClone — Advanced Faction & Territory Spec v3

## Territory System

Each base has:
- Territory influence radius
- Patrol coverage zone
- Scavenging reach

Influence affects:
- Zombie density
- Loot depletion rate
- Encounter frequency

---

## Inter-Faction Relations

Possible states:
- Neutral
- Trade Partner
- Allied
- Rival
- Hostile

Events:
- Trade caravans
- Joint defense requests
- Raids
- Resource negotiations

---

## Leadership Pressure System

As settlement grows:
- Leadership decisions impact morale
- Resource mismanagement amplifies penalties
- Death of key NPC causes morale shock





---

# Source: README.txt

PZClone Master Bible Package v3
Generated: 2026-02-25T04:18:37.448319

Included:
- Design_Bible_v3.md
- Technical_Bible_v3.md
- Settlement_Management_Spec_v3.md
- Faction_Territory_Spec_v3.md

This version introduces full survivor recruitment,
base expansion, and settlement leadership mechanics.

Add to Claude workstation after NPC & faction foundation is stable.




---

# Source: Settlement_Management_Spec_v3.md

# PZClone — Settlement & Survivor Management Spec v3

## Recruitment Requirements
- Safehouse declared
- Adequate food stockpile
- Available sleeping space
- Reputation threshold met

## Survivor Evaluation Logic
NPC joins based on:
- Safety perception
- Resource stability
- Player reputation
- Existing morale

## Survivor Needs
- Food
- Sleep
- Safety
- Social morale
- Leadership confidence

Failure to maintain needs leads to:
- Desertion
- Conflict
- Reduced productivity

---

## Base Morale Formula
Morale = (Food Stability + Safety + Leadership Reputation) - (Deaths + Resource Shortage)

High morale:
- Productivity boost
- Combat efficiency boost

Low morale:
- Desertion risk
- Internal disputes

---

## Growth Stages

Stage 1: Safehouse (1–4 NPCs)
Stage 2: Organized Base (5–10 NPCs)
Stage 3: Settlement (10+ NPCs, defense structures)
Stage 4: Regional Influence (optional future)





---

# Source: Technical_Bible_v3.md

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




---

# Source: Gameplay_Bible_v3.1_Inventory_Update.md

# PZClone — Gameplay Bible v3.1 (Inventory Update)

## Grid-Based Inventory System

The inventory system is grid-based.

### Core Rules

- Each inventory has a 2D grid.
- Items occupy multiple grid squares.
- Items have unique shapes (not only rectangles).
- Rotation is allowed (90° increments).
- Placement must respect collision within grid.

### Item Size Categories

Small:
- Bandages
- Ammunition boxes
- Tools

Medium:
- Pistols
- Food containers
- Medical kits

Large:
- Rifles
- Toolboxes
- Crowbars

### Unique Shape Containers

Certain container items have custom shapes:
- Guitar case → asymmetrical layout
- Backpack → rectangular with partition bonus
- Duffel bag → wide rectangular
- Toolbox → compact square layout

These container shapes affect:
- What items can fit
- Packing efficiency
- Strategic loadout decisions

Encumbrance is calculated based on weight,
but spatial constraints are equally important.




---

# Source: Inventory_Design_Bible_v1.md

# PZClone — Inventory Design Bible v1

## Design Philosophy

Inventory management should feel:

- Tactile
- Strategic
- Spatial
- Survival-driven

## Container Identity

Backpack:
- Balanced grid
- Moderate weight bonus

Guitar Case:
- Long-item specialist
- Poor for compact items

Military Crate (future):
- Large rectangular grid
- Heavy carry penalty

## Emergent Gameplay

Moments created:

- “We don’t have space for this.”
- “Drop the rifle or ditch food?”
- “Bring the duffel for supply run.”




---

# Source: README.txt

PZClone Bible Update — Grid Inventory System (v3.1)
Generated: 2026-02-26T05:37:50.458643

Included:
- Gameplay_Bible_v3.1_Inventory_Update.md
- Technical_Bible_v3.1_Inventory_Update.md
- Inventory_Design_Bible_v1.md

This update formalizes the grid-based, shaped inventory system
with multiplayer-safe placement validation.




---

# Source: Technical_Bible_v3.1_Inventory_Update.md

# PZClone — Technical Bible v3.1 (Grid Inventory Spec)

## Inventory Data Model

Each inventory container contains:

- container_id
- grid_width
- grid_height
- slot_matrix (2D array)
- weight_limit
- owner_id

Each item contains:

- item_guid
- width
- height
- shape_mask (2D boolean array)
- weight
- rotation_state

## Placement Rules

To place item:

1. Check bounds
2. Check collision with slot_matrix
3. Apply shape_mask
4. Update matrix
5. Recalculate weight

Host-authoritative placement validation required in multiplayer.

## Networking

All item move requests must include:

- container_id
- item_guid
- target_x
- target_y
- rotation_state

Host validates and broadcasts updated grid state.




---

# Source: Character_Model_Bible_v1.md

# PZClone — Character Model & Sprite System Bible v1

## Core Philosophy

All characters (Players, NPCs, Zombies) share a unified base body system.

Design goals:
- Modular layering
- Consistent animation alignment
- Directional readability (isometric)
- Performance stability
- Easy clothing & gear expansion

---

# 1. Base Model Structure

Each character consists of:

1. Base Body (underwear only)
2. Clothing layers
3. Gear layers (bags, weapons, tools)
4. State overlays (blood, dirt, wounds)

The base body sprite must exist independently of all equipment.

---

# 2. Directional Sprite Requirements

All character types require 8 directional sprites:

- N
- NE
- E
- SE
- S
- SW
- W
- NW

Each direction must have consistent:
- Foot placement
- Shoulder alignment
- Head orientation

Directional consistency is critical for layering clothes and gear.

---

# 3. Animation States

## Universal States (All Characters)

- Idle
- Walk
- Run
- Attack
- Hit/Stagger
- Death

## Player & NPC Exclusive States

- Sneak (crouched walk)
- Sneak Idle
- Rest (sitting or kneeling)
- Interaction (looting, crafting)
- Aim (optional future)

## Zombie Exclusive Variants

- Slow Walk
- Aggressive Lunge
- Idle Sway
- Collapse Death

---

# 4. Sneaking Animation Requirements

Sneaking must:

- Lower body center of gravity
- Reduce stride length
- Reduce arm swing
- Maintain 8-direction support

Sneak silhouette should clearly differ from normal walk.

---

# 5. Resting Pose Requirements

Resting may include:

- Sitting on floor
- Leaning against wall
- Kneeling

Rest state is static or low-frame animation.
Used for stamina recovery and immersion.

---

# 6. Clothing Layer System

Clothing layers stack in this order:

1. Base body
2. Underwear (optional cosmetic)
3. Pants
4. Shirt
5. Jacket/Outerwear
6. Armor (future)
7. Backpack / Bags
8. Held items (weapons/tools)

Each clothing item must:

- Match 8-direction sprite set
- Match animation frame count
- Align to base body anchor points

---

# 7. Anchor & Alignment System

Each sprite direction must define anchor points:

- Head
- Torso
- Left hand
- Right hand
- Back mount (for backpack)
- Waist

These anchors ensure:

- Clothing aligns correctly
- Weapons appear correctly in hands
- Backpacks sit naturally

---

# 8. Zombie Clothing System

Zombies use same base model system,
but clothing may:

- Appear torn
- Be partially missing
- Show blood overlays

Zombie clothing variations increase world realism.

---

# 9. Sprite Sheet Organization

Each character state stored as:

character_type/state/direction/frame.png

Example:

player/walk/N/frame_01.png

Maintain consistent naming convention.

---

# 10. Performance Guidelines

- Use atlas packing per state
- Avoid oversized textures
- Maintain consistent pixel density
- Reuse animation frames when possible

---

# 11. Visual Consistency Rules

Characters must:

- Be readable at gameplay zoom
- Have clear silhouette differences (walk vs sneak)
- Avoid excessive animation noise
- Maintain grounded realism

---

# 12. Future Expansion Hooks

System must support:

- Body type variations
- Gender variations
- Injury overlays
- Dynamic blood accumulation
- Clothing degradation states

---

# Design North Star

Characters should feel:

Readable.
Grounded.
Modular.
Expandable.

If adding new clothing requires modifying base sprites,
the system is incorrect.

---

# End of Character Model Bible v1




---

# Source: README.txt

PZClone Character Model Bible v1
Generated: 2026-02-26T06:50:49.652162

Includes:
- Character_Model_Bible_v1.md

Defines base model layering system,
8-direction sprite requirements,
animation states, and modular clothing framework.




---

# Source: Gameplay_Bible_v1.md

# PZClone — Gameplay Bible v1
Co-op Survival + Base & Survivor Management

Core Inspiration: Project Zomboid-style co-op survival
Evolution: Settlement leadership & shared base management

---

# 1. Core Gameplay Identity

PZClone plays as:

- 1–4 player cooperative survival
- Top-down isometric
- System-driven sandbox
- Long-term survival progression

The game evolves through stages:

Stage 1: Survival
Stage 2: Safehouse Establishment
Stage 3: Recruitment & Management
Stage 4: Settlement Growth
Stage 5: Territory Influence

---

# 2. Core Gameplay Loop

Spawn → Scavenge → Survive → Secure Location → Declare Safehouse → Recruit → Expand → Defend → Manage → Influence

Survival remains central even in late game.

---

# 3. Safehouse System

## 3.1 Declaring a Safehouse

Any player can declare a safehouse if:

- Interior space secured
- No immediate zombie threat
- Player has control of structure

Declaring creates:
- Safehouse boundary zone
- Storage authority
- Recruitment eligibility

---

## 3.2 Independent vs Shared Safehouses

Each player may:

Option A: Declare independent safehouse
- Personal survivor group
- Personal supply storage
- Personal leadership decisions

Option B: Share a safehouse
- Declare shared territory
- Vote or assign leader
- Pool supplies
- Pool recruited survivors

Shared safehouse enables deeper management gameplay.

---

# 4. Leadership Model

In shared safehouse:

- Players may vote to assign leader
- Leader gains:
  - Authority to assign survivor roles
  - Base expansion permissions
  - Diplomatic decision control

Optional settings:
- Democratic mode (votes required)
- Leader mode (single authority)
- Open mode (all equal permissions)

---

# 5. Recruitment System

## Requirements
- Safehouse declared
- Food stability
- Sleeping capacity
- Positive reputation

## Recruitment Types

- Lone survivors
- Small survivor groups
- Defected faction members

NPCs evaluate:
- Safety
- Leadership stability
- Resource availability
- Player reputation

---

# 6. Survivor Roles

Survivors can be assigned to:

- Guard
- Scavenger
- Builder
- Medic
- Crafter
- Farmer (future)

Roles influence:
- Base defense
- Resource generation
- Construction speed
- Morale stability

---

# 7. Base Management Gameplay

Base has:

- Defense Rating
- Food Supply
- Water Supply
- Morale
- Population
- Resource Inventory

Players must balance:

- Expansion vs sustainability
- Defense vs resource consumption
- Recruitment vs food strain

---

# 8. Shared Resource Pooling

In shared safehouse:

- All resources deposited into central storage
- Withdrawal permissions configurable
- Resource misuse affects morale

Independent safehouses maintain separate inventories.

---

# 9. Conflict & Cooperation

## Player Conflict (Optional)

Server settings may allow:
- Resource disputes
- Leadership challenges
- Safehouse splits

## Faction Interaction

Bases interact with:

- NPC factions
- Rival settlements
- Trade caravans
- Raid events

---

# 10. Death & Consequences

If player dies:

- Survivors react emotionally
- Morale drop
- Leadership reevaluation possible

If key NPC dies:
- Productivity penalties
- Loyalty reduction

Death must have emotional and systemic impact.

---

# 11. Late-Game Evolution

Settlement grows into:

- Organized base
- Structured defense
- Patrol zones
- Territory influence radius

Players transition from scavengers to leaders.

---

# 12. Gameplay North Star

The game should create moments like:

- “We need more food before recruiting.”
- “Who’s leading this base?”
- “Should we split and start another settlement?”
- “We can’t afford another death.”

If gameplay doesn’t create tension around leadership and survival tradeoffs, redesign systems.

---

# End of Gameplay Bible v1




---

# Source: README.txt

PZClone Gameplay Bible v1
Generated: 2026-02-26T03:13:49.796300

Defines core gameplay identity, safehouse mechanics,
shared leadership systems, recruitment, and base management.

Add to Claude workstation under /Design/Gameplay/.




---

# Source: Drag_Drop_UX_Blueprint_v1.md

# PZClone — Drag-and-Drop UX Blueprint v1

## Core UX Principles

- Responsive placement preview
- Clear collision indicators
- No hidden rules
- Immediate feedback

## Drag Behavior

- Item follows cursor at grid cell resolution
- Ghosted preview shows shape_mask footprint
- Rotation preview updates live

## Cancel Rules

- Esc cancels drag
- Dropping outside UI returns item to origin

## Accessibility

- Controller-friendly grid navigation
- Auto-snap toggle option
- Optional auto-arrange assist (off by default)

## Error Handling

- If host rejects placement:
  - Item snaps back
  - Display short error message




---

# Source: Loot_Container_UI_Spec_v1.md

# PZClone — Loot Container UI Spec v1

## Layout Structure

Left Panel: Player Inventory Grid  
Right Panel: Container Inventory Grid  
Center/Top: Container Name + Weight + Capacity  
Bottom: Action Bar (Rotate, Transfer, Drop, Equip)

## Interaction Rules

- Drag and drop between grids
- Right-click for context menu
- Shift-click for quick transfer
- R key rotates item
- Highlight invalid placement (red overlay)

## Visual Feedback

- Green highlight: valid placement
- Red highlight: collision/out of bounds
- Yellow highlight: overweight warning
- Flash grid briefly on successful placement

## Multiplayer Consideration

- Grid state updates from host
- Show lock icon if container in use by another player




---

# Source: Packing_Efficiency_Skill_System_v1.md

# PZClone — Packing Efficiency Skill System v1

## Skill Name
Logistics (or Inventory Management)

## Skill Effects

Level 0:
- No bonuses

Level 1–3:
- Slight auto-rotate assist
- Small reduction in weight penalty

Level 4–6:
- Reduced effective item footprint for select small items
- Faster container interaction time

Level 7–10:
- Minor grid compression bonus (e.g., 5% virtual space efficiency)
- Improved auto-sort optimization

## Design Goal

Inventory mastery becomes progression path.

Encourages:
- Dedicated scavenger roles
- Specialized loadouts
- Strategic base organization

## Multiplayer Balance

Bonuses apply only to player's personal containers.
Shared base storage unaffected to avoid imbalance.




---

# Source: Quick_Transfer_Sorting_Rules_v1.md

# PZClone — Quick Transfer & Sorting Ruleset v1

## Quick Transfer

Shift-click:
- Moves item to opposite inventory
- Attempts first-fit placement
- If no space, denies transfer

Ctrl-click:
- Moves stackable items only

## Auto-Sort (Optional Button)

Sorting Priority:
1. Ammo
2. Medical
3. Food
4. Tools
5. Weapons
6. Misc

Sorting respects:
- Shape compatibility
- Rotation optimization
- Container identity

## Stacking Rules

- Only identical items stack
- Stack size capped by item definition
- Stacks still consume grid space based on footprint

## Multiplayer

Sorting is client-predicted but host-validated.




---

# Source: README.txt

PZClone Inventory Expansion Pack v1
Generated: 2026-02-26T05:43:59.663842

Included:
- Loot_Container_UI_Spec_v1.md
- Drag_Drop_UX_Blueprint_v1.md
- Quick_Transfer_Sorting_Rules_v1.md
- Packing_Efficiency_Skill_System_v1.md

Defines UI behavior, UX logic, sorting systems, and progression mechanics
for the grid-based shaped inventory system.




---

# Source: Lighting_Interior_Bible_v1.md

# PZClone — Lighting & Interior / Furniture Design Bible v1

Guided toward grounded, Project Zomboid–inspired realism.

---

# 1. Lighting Philosophy

Lighting must support:
- Gameplay clarity
- Tension
- Depth perception in isometric view
- Emotional atmosphere
- Performance stability in 4-player co-op

Lighting is gameplay information, not decoration.

---

# 2. Global Lighting Model

Morning:
- Soft warm light
- Long subtle shadows

Midday:
- Neutral white light
- Reduced shadow length
- Clear visibility

Evening:
- Warmer tone
- Increased contrast

Night:
- Deep blue ambient wash
- Strong localized light sources
- High shadow contrast

---

# 3. Interior Lighting Rules

Interiors must:
- Be darker than exterior during day
- Use localized light sources
- Create pockets of visibility
- Encourage flashlight usage at night

Primary interior light sources:
- Ceiling fixtures
- Table lamps
- Windows (day only)

---

# 4. Lighting Layers

1. Ambient light (global)
2. Directional sunlight (day)
3. Local light sources
4. Dynamic light (flashlights, fire)
5. Shadow overlays

Avoid excessive overlapping lights to maintain performance.

---

# 5. Shadow Guidelines

- Soft shadows indoors
- Harder shadows at night
- Interior walls fade when occluding player
- Avoid full darkness areas that hide enemies unfairly

---

# 6. Power State Integration

When power shuts off:
- Interior lights disabled
- Increased flashlight dependency
- Darkness increases threat level

---

# 7. Furniture Philosophy

Furniture must:
- Define navigation flow
- Create line-of-sight blockers
- Support environmental storytelling
- Avoid clutter overload

Rooms must remain navigable.

---

# 8. Residential Furniture Guidelines

Living Room:
- Sofa
- Coffee table
- TV stand
- Bookshelves

Kitchen:
- Fridge
- Stove
- Sink
- Cabinets
- Dining table

Bedroom:
- Bed
- Dresser
- Nightstand

Bathroom:
- Toilet
- Sink
- Bathtub or shower

---

# 9. Commercial Interior Guidelines

Convenience Store:
- Aisle shelving
- Checkout counter
- Back storage room

Pharmacy:
- Tall shelving
- Counter barrier
- Rear supply room

Hardware Store:
- Industrial shelving
- Tool displays
- Storage area

---

# 10. Industrial Interior Guidelines

Warehouse:
- Wide open spaces
- Pallet stacks
- Metal shelving
- Overhead lighting

Garages:
- Tool benches
- Storage racks
- Vehicle bay space

---

# 11. Pathing & Navigation Constraints

Furniture placement must:
- Maintain 1-tile minimum path lanes
- Avoid trapping player in dead-ends
- Avoid unreachable loot spots

Navigation > decoration.

---

# 12. Performance Constraints

- Limit real-time light count per chunk
- Avoid dynamic shadows on every prop
- Prefer baked ambient occlusion overlays
- Use light masks for optimization

---

# 13. Interior Aging Over Time (Future)

As world ages:
- Dust overlays
- Broken furniture states
- Flickering lights (rare)
- Structural damage variants

---

# 14. Visual North Star for Interiors

Interiors should feel:
- Quiet
- Claustrophobic at night
- Practical
- Believable
- Strategically navigable

Lighting and furniture must support tension and tactical decisions.

---

# End of Lighting & Interior Design Bible v1




---

# Source: README.txt

PZClone Lighting & Interior Bible v1
Generated: 2026-02-25T05:42:46.533467

Defines lighting behavior and interior/furniture design standards.
Add to Claude workstation under /Design/Visual/Interiors/.




---

# Source: Occlusion_System_Spec_v1_1.md

# PZClone — Visual Occlusion & Visibility Culling Spec v1.1
(Project Zomboid–Inspired with Persistent Item Memory & Fading Zombies)

---
## Core Update Summary (v1.1)

1. Consumables and pick-ups that the player has already seen remain visible
   even after the player turns away (memory persistence).
2. Zombies that leave the player's sight cone slowly fade out instead of
   instantly disappearing.
3. If a zombie is making noise and the player is within hearing range,
   the zombie becomes visible again (rendered).

---
# 1. Visibility Categories

Each entity is evaluated per-player with the following states:

### A. VISIBLE
- In current line-of-sight (LOS).
- Fully rendered.

### B. MEMORY_VISIBLE (Items Only)
- Previously seen.
- Currently outside LOS.
- Still rendered normally (no fade).
- Cleared only if:
  - Item is picked up
  - Item despawns
  - Item moves outside loaded chunk

### C. FADING (Zombies Only)
- Previously visible.
- Currently outside LOS.
- Slowly fades opacity over time.
- If fade timer expires → becomes HIDDEN.

### D. HEARD_VISIBLE (Zombies Only)
- Outside LOS.
- Within valid hearing range of noise event.
- Immediately rendered at full opacity.
- Overrides fading state.

### E. HIDDEN
- Not visible and not heard.
- Not rendered.

---
# 2. Item Memory System (Consumables & Pickups)

## Rule
If a player has seen a consumable or pickup at least once,
it remains rendered even when outside LOS.

## Rationale
- Prevents frustrating "loot popping"
- Reinforces player spatial memory
- Reduces UI confusion

## Data Requirement

Each item must track:
- seen_by_players[] (bool per player)

When an item enters VISIBLE:
- Mark seen_by_players[player_id] = true

Rendering Rule:
If seen_by_players[player_id] == true → render item regardless of LOS
(unless outside loaded chunk).

---
# 3. Zombie Fade System

## Fade Behavior

When zombie leaves LOS:

State transitions:
VISIBLE → FADING → HIDDEN

Fade Duration:
0.5–2.0 seconds (tunable)

Opacity Curve:
Linear or smoothstep fade to 0.

## Design Goals

- Prevent sudden pop-out.
- Maintain tension.
- Communicate loss of visual certainty.

---
# 4. Hearing Override (Zombies)

If zombie generates or is associated with a noise event:

Conditions:
- Player within effective hearing radius
- Attenuation through walls allowed but reduced

Then:
Zombie state becomes HEARD_VISIBLE
Rendered at full opacity.

When noise decay ends:
Zombie returns to FADING if still not in LOS.

---
# 5. Noise System Integration

Noise events include:
- Footsteps
- Groans
- Smashing doors/windows
- Gunshots
- Chainsaw use

Each noise event has:
- position
- radius
- intensity
- decay time

Hearing calculation occurs at noise trigger time and periodic update ticks.

---
# 6. Multiplayer Rendering Rules

Host:
- Simulates zombie AI and noise events.

Client:
- Computes visibility state locally.
- Applies fade and memory rules.
- Does not affect authoritative world state.

Each client may see different zombie fade states based on their LOS.

---
# 7. Performance Considerations

Visibility sets recalculated at fixed interval (5–10 Hz).
Fade handled client-side without re-running LOS.

Items:
Memory persistence does not increase simulation cost —
only rendering decision flag.

---
# 8. Edge Cases

If zombie re-enters LOS during fade:
- Immediately restore to VISIBLE (opacity 1.0)

If zombie is both heard and fading:
- HEARD_VISIBLE overrides fade.

If item moves while outside LOS:
- Update world position but remain MEMORY_VISIBLE.

---
# 9. Debug Requirements

Add overlays for:
- Visible entities
- Fading zombies
- Memory-visible items
- Heard-visible zombies
- LOS grid

---
# Design Intent

Players remember where loot is.
Zombies feel threatening and uncertain.
Nothing pops unrealistically.

---
# End of Spec v1.1




---

# Source: README.txt

PZClone Occlusion System Spec v1.1
Generated: 2026-02-26T06:13:57.798594

Includes:
- Occlusion_System_Spec_v1_1.md

Adds:
- Persistent visibility for seen items
- Zombie fade-out when leaving LOS
- Hearing override visibility for zombies




---

# Source: README.txt

PZClone Visual Bible v1
Generated: 2026-02-25T04:57:16.212657

This file defines the visual direction inspired by Project Zomboid’s grounded realism.

Add to Claude workstation under /Design/Visual/.




---

# Source: Visual_Design_Bible_v1.md

# PZClone — Visual & Graphical Design Bible v1
Guided Toward a Project Zomboid–Inspired Aesthetic

Reference Inspiration: Project Zomboid (isometric realism, grounded tone)

---

# 1. Visual Philosophy

PZClone should visually communicate:

- Grounded realism
- Practical architecture
- Subtle environmental decay
- Functional clarity
- Readable isometric depth

The goal is NOT stylized exaggeration.
The goal is believable survival spaces.

---

# 2. Camera & Perspective

## Isometric Rules

- Fixed isometric angle (no perspective distortion)
- 2.5D tile-based structure
- Slight vertical exaggeration for readability
- Interior walls fade when occluding player

Maintain gameplay clarity over realism.

---

# 3. Color Palette

## Global Palette Direction

- Muted earth tones
- Desaturated suburban colors
- Soft greens for foliage
- Warm tungsten interior lighting
- Cool blue night lighting

Avoid:
- Neon saturation
- Cartoon contrast
- Overly clean textures

---

# 4. Lighting Model

## Day/Night Tone

Day:
- Soft neutral lighting
- Mild shadow contrast

Night:
- Deep blue ambient wash
- Warm indoor lighting pockets
- Strong shadow gradients

Lighting should create tension without destroying readability.

---

# 5. Building Aesthetic Guidelines

## Residential

- Neutral siding tones
- Brick variations (muted red/brown)
- Slight grime overlays
- Roof shingles with subtle noise variation
- Functional layouts visible from iso view

## Commercial

- Slightly more clutter
- Faded signage
- Window reflections subdued
- Flat roofing common

## Industrial

- Metal siding
- Rust patches
- Wide loading doors
- Stark interior lighting

---

# 6. Texture Philosophy

Textures must:

- Be tileable horizontally
- Support tint variation
- Support grime/damage overlays
- Avoid heavy baked shadows
- Avoid hyper-detailed micro noise

Use layered approach:
Base texture → Color tint → Grime mask → Damage mask

---

# 7. Environmental Storytelling

Visual decay should suggest:

- Abandonment
- Looting
- Emergency evacuation

Subtle cues:
- Fallen trash bins
- Broken windows
- Slight interior disarray
- Overgrown yards

Avoid excessive dramatic destruction early game.

---

# 8. Foliage Style

- Slightly desaturated greens
- Rounded canopy shapes
- Bushes break line-of-sight
- Grass density moderate, not jungle-heavy

Overgrowth increases as world ages.

---

# 9. Zombie Visual Style

Inspired by realism:

- Civilian clothing variation
- Subtle color variance
- Gradual damage states
- No exaggerated mutations

Clothing color palette matches suburban realism.

---

# 10. UI Integration

UI must not clash with realism:

- Minimalistic
- Clean sans-serif fonts
- Neutral color tones
- Subtle iconography

HUD overlays must not overwhelm scene.

---

# 11. Visual Progression Over Time

World visual state shifts:

Early game:
- Clean but abandoned

Mid game:
- Noticeable decay
- Increased overgrowth

Late game:
- Structural damage
- Weather wear
- Settlement modifications visible

---

# 12. Technical Rendering Notes

- Use layered shaders for tint + grime
- Avoid excessive dynamic shadows
- Use simple normal maps sparingly
- Maintain performance for 4-player co-op

---

# 13. What To Avoid

- Stylized cartoon outlines
- Hyper-real PBR photogrammetry
- Unreal Engine–style bloom
- Overly glossy materials
- Excessive particle clutter

---

# 14. Visual North Star

The world should feel:

Quiet.
Practical.
Worn.
Realistic.
Readable.

If a scene looks dramatic but unclear in gameplay, reduce visual noise.

---

# End of Visual & Graphical Design Bible v1




---

# Source: README.txt

PZClone Visual Bible v2
Generated: 2026-02-25T05:44:47.198695

Included:
- Shader_Stack_v2.md
- Tile_Scale_Pixel_Density_v2.md
- Weather_Atmosphere_Spec_v2.md
- Structural_Damage_Spec_v2.md

This expands Visual Bible v1 with rendering systems, material standards,
weather effects, and destruction states.

Add to Claude workstation under /Design/Visual/V2/.




---

# Source: Shader_Stack_v2.md

# PZClone — Shader Stack & Material System Bible v2

## Shader Philosophy
Shaders must support:
- Performance stability in 4-player co-op
- Layered material variation
- Subtle realism
- World aging progression

## Standard Shader Layers
1. Base Albedo Texture
2. Color Tint (HSV modifier)
3. Grime Overlay Mask
4. Damage Overlay Mask
5. Ambient Occlusion (baked)
6. Optional Subtle Normal Map

Avoid:
- Heavy bloom
- Glossy specular highlights
- Overly complex PBR stacks

## Tint System
Every building and prop should support runtime tint variation:
- Wall tint
- Roof tint
- Trim tint

## Damage States
Support 3 visual states:
- Clean
- Worn
- Damaged

Damage overlay intensity must be adjustable via shader parameter.




---

# Source: Structural_Damage_Spec_v2.md

# PZClone — Structural Damage & Destruction Visual Spec v2

## Damage Philosophy
Destruction must feel grounded, not cinematic.

## Window States
- Intact
- Cracked
- Broken
- Boarded

## Wall States (Late Game)
- Clean
- Damaged
- Reinforced
- Breached

## Furniture Damage
- Intact
- Scratched
- Broken
- Burned (future)

## Visual Integration
Damage must:
- Use overlay masks
- Preserve collision clarity
- Not block gameplay readability

Avoid full physics destruction early development.




---

# Source: Tile_Scale_Pixel_Density_v2.md

# PZClone — Tile Scale & Pixel Density Standards v2

## Tile Scale
- 1 Tile = 1 meter (logical gameplay unit)
- Maintain consistent isometric projection

## Texture Resolution Standards
- Small props: 128x128
- Medium props: 256x256
- Large structures: 512x512 (tileable sections)

Avoid oversized textures for memory stability.

## Pixel Density Rule
Maintain consistent texel density across:
- Walls
- Floors
- Roofs
- Furniture

No mismatched scaling artifacts.

## Asset Naming Standard
asset_category_type_variant_resolution.png
Example:
res_wall_brick_a_512.png




---

# Source: Weather_Atmosphere_Spec_v2.md

# PZClone — Weather & Atmospheric Effects Spec v2

## Weather Types
- Clear
- Overcast
- Rain
- Storm
- Fog
- Light Snow (future)

## Visual Behavior

Rain:
- Slight desaturation
- Subtle wet surface darkening
- Reduced contrast

Storm:
- Flash lighting pulses
- Strong wind sound cues

Fog:
- Reduced draw distance
- Lower zombie vision radius
- Soft distance fade

## Atmospheric Layers
1. Sky Tint
2. Ambient Color Shift
3. Particle Layer
4. Surface Wetness Shader Modifier

Performance priority over spectacle.


