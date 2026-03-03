
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
