# PZClone — Building Asset Guide
*Naming conventions, sprite sheet specs, folder layout, metadata standards, and code integration*

This is the canonical reference for creating building assets and wiring them into the generation system. Follow it exactly so Claude can filter and place assets correctly.

---

## 1. Core Principle

Every asset is a **data-driven building piece** described by metadata, not just a filename. Claude (and the generation system) selects assets by querying metadata — not by guessing from filenames.

A placed asset is only valid if:
1. `allowed_buildings` contains the current building type
2. `allowed_rooms` contains the current room type
3. Its category matches the current placement layer
4. It is **not** in the forbidden list for that room archetype
5. Its footprint fits available free tiles

---

## 2. Naming Convention Formula

```
[category]_[theme]_[subtheme]_[assetname]_[variant]_[orientation]_[state]_[size]
```

Not every field must be present, but the **order must be consistent**. Omit trailing fields when not applicable.

### Field Definitions

| Field | Purpose | Examples |
|---|---|---|
| `category` | Asset type | `wall`, `floor`, `door`, `window`, `roof`, `trim`, `furn`, `decor`, `clutter`, `sign`, `fixture` |
| `theme` | Building theme tag | `res`, `school`, `office`, `medical`, `industrial`, `retail`, `restaurant`, `warehouse`, `government`, `church`, `police`, `fire`, `lab`, `farm`, `hotel` |
| `subtheme` | Room type | `classroom`, `hallway`, `cafeteria`, `library`, `bathroom`, `kitchen`, `bedroom`, `exam`, `reception`, `storage`, `breakroom`, `cell`, `garage`, `living`, `dining`, `laundry`, `gym`, `nurse`, `principal` |
| `assetname` | Specific item name | `tile`, `linoleum`, `chalkboard`, `desk_student`, `locker_single`, `wall_panel`, `door_single`, `shelf_metal` |
| `variant` | Visual variant | `v01`, `v02`, `a`, `b` |
| `orientation` | Facing or alignment | `n`, `e`, `s`, `w`, `front`, `back`, `horz`, `vert`, `inner`, `outer` |
| `state` | Condition | `clean`, `dirty`, `damaged`, `broken`, `boarded`, `bloody`, `burned`, `abandoned`, `faded`, `dented`, `dusty` |
| `size` | Tile footprint | `1x1`, `2x1`, `2x2`, `3x1` |

### Controlled Vocabulary

**Never let naming drift.** Use exactly one approved term per concept.

Bad: `desk`, `studentdesk`, `schooldesk`, `class_desk`
Good: `desk_student` (always)

---

## 3. Naming Examples

### Structural (floors, walls, doors, windows)

```
floor_school_classroom_tile_v01_clean
floor_school_hallway_linoleum_v02_dirty
floor_res_bedroom_wood_v01_clean
floor_res_kitchen_checker_v01_dirty
floor_medical_exam_linoleum_v01_clean
floor_industrial_garage_concrete_v01_dirty

wall_school_classroom_painted_v01_horz_clean
wall_school_hallway_cinderblock_v02_vert_dirty
wall_res_bedroom_wallpaper_v02_horz_faded
wall_medical_exam_tile_v01_vert_clean
wall_industrial_warehouse_metal_v01_vert_dirty

door_school_classroom_single_v01_s_clean
window_school_classroom_tall_v01_vert_clean
roof_school_main_flat_v01_clean
trim_school_hallway_baseboard_v01_clean
```

### Furniture

```
furn_school_classroom_desk_student_v01_s_clean_1x1
furn_school_classroom_desk_teacher_v01_s_clean_2x1
furn_school_hallway_locker_single_v01_s_dented_1x1
furn_school_library_bookshelf_tall_v02_s_dusty_1x1
furn_school_cafeteria_table_long_v01_s_dirty_3x1
furn_res_bedroom_bed_double_v01_n_clean_2x2
furn_res_kitchen_counter_v01_n_clean_2x1
furn_res_living_sofa_v01_e_dirty_2x1
furn_medical_exam_bed_v01_n_clean_2x1
furn_medical_reception_desk_v01_s_clean_2x1
furn_industrial_warehouse_shelf_metal_v01_n_clean_1x3
furn_police_cell_bed_cot_v01_n_damaged_1x1
furn_church_nave_pew_v01_s_clean_3x1
```

### Decor / Clutter / Signs

```
decor_school_classroom_chalkboard_v01_s_clean_2x1
decor_school_classroom_poster_math_v02_s_faded_1x1
decor_school_hallway_bulletin_board_v01_s_dirty_1x1
clutter_school_classroom_papers_scattered_v01_s_dirty_1x1
sign_school_hallway_roomnumber_v01_s_clean_1x1
```

---

## 4. Folder Structure

```
res://assets/
└── buildings/
    ├── tilesets/
    │   ├── floors/          ← floor_[theme]_[room]_*.png
    │   ├── walls/           ← wall_[theme]_[room]_*.png
    │   ├── doors/           ← door_[theme]_[room]_*.png
    │   ├── windows/         ← window_[theme]_[room]_*.png
    │   ├── roofs/           ← roof_[theme]_*.png
    │   ├── stairs/
    │   └── trim_overlays/   ← trim_[theme]_[room]_*.png
    ├── furniture/
    │   ├── residential/     ← furn_res_*_sheet.png
    │   ├── school/          ← furn_school_*_sheet.png
    │   ├── office/          ← furn_office_*_sheet.png
    │   ├── medical/         ← furn_medical_*_sheet.png
    │   ├── industrial/      ← furn_industrial_*_sheet.png
    │   ├── retail/          ← furn_retail_*_sheet.png (convenience store, pharmacy)
    │   ├── restaurant/      ← furn_restaurant_*_sheet.png
    │   ├── government/      ← furn_police_* / furn_fire_*
    │   ├── church/          ← furn_church_*_sheet.png
    │   └── utility/         ← shared utility furniture
    ├── decor/
    ├── clutter/
    ├── signage/
    └── metadata/            ← JSON data files (see Section 8)
```

**Separate structural tiles from furniture, decor, clutter, and signage at all times.**

---

## 5. Sprite Sheet Format

### Sprite Sheet Naming

Sheets group related assets by family:

```
[category]_[theme]_[subtheme]_[family]_[setname]_sheet.png
```

Examples:
```
wall_school_classroom_painted_set01_sheet.png
floor_school_hallway_linoleum_set01_sheet.png
furn_school_classroom_desks_set01_sheet.png
furn_school_hallway_lockers_set01_sheet.png
decor_school_classroom_teaching_set01_sheet.png
```

### Frame Layout — Furniture (4 Directions)

All furniture sprites must provide **4 facings: N, E, S, W** (the front of the object points that direction on the map).

**Standard frame sizes:**
| Object category | Frame size |
|---|---|
| Small props (1×1) | 96×96 px |
| Medium furniture (1×1 or 2×1) | 128×128 px |
| Large / tall furniture (2×2 or bigger) | 192×192 px or 256×256 px |

**Frame ordering within a sheet (top to bottom):**
```
Frame 0 (y=0):   facing N  — FRONT points north (camera sees BACK + RIGHT faces)
Frame 1 (y=h):   facing E  — FRONT points east  (camera sees FRONT + RIGHT faces)
Frame 2 (y=2h):  facing S  — FRONT points south (camera sees FRONT + LEFT faces)
Frame 3 (y=3h):  facing W  — FRONT points west  (camera sees BACK + LEFT faces)
```

**Do not use horizontal flipping as a substitute for explicit facings.** Asymmetric features (handles, labels, vents, wear patterns) break when flipped.

**Pivot placement:** anchor at bottom tile center. For tall objects, pivot stays at floor contact point — do not center vertically.

### Frame Mapping File (Required)

Each sheet must have a sidecar `.json` frame map:

```json
{
  "sheet": "furn_school_classroom_desks_set01_sheet.png",
  "frame_width": 128,
  "frame_height": 128,
  "frames": {
    "0": "furn_school_classroom_desk_student_v01_n_clean_1x1",
    "1": "furn_school_classroom_desk_student_v01_e_clean_1x1",
    "2": "furn_school_classroom_desk_student_v01_s_clean_1x1",
    "3": "furn_school_classroom_desk_student_v01_w_clean_1x1",
    "4": "furn_school_classroom_desk_teacher_v01_n_clean_2x1",
    "5": "furn_school_classroom_desk_teacher_v01_e_clean_2x1",
    "6": "furn_school_classroom_desk_teacher_v01_s_clean_2x1",
    "7": "furn_school_classroom_desk_teacher_v01_w_clean_2x1"
  }
}
```

### Floor / Wall Tiles

Floor tiles: `64 × 32 px` — one isometric diamond per frame (matches the game's tile size).
For variety, use a 4-frame horizontal atlas (`256 × 32 px`) and select a frame by hashing the tile position.

Wall face sheets: `64 × 96 px` (3-tile-high buildings) or `64 × 128 px` (4-tile-high).
Layout is a vertical strip:
```
Row 0 (top):    parapet / cap band     — 64×32 px
Row 1:          upper wall band        — 64×32 px
Row 2:          middle wall band       — 64×32 px
Row 3 (bottom): base wall band         — 64×32 px (4-tile sheets only)
```

---

## 6. Lighting and Art Style Rules

All assets must obey the PZClone art direction — **analog horror / quiet dread**:

- **Palette:** desaturated greens, sickly browns, cold blue shadows, dusty warm lamp glows. No pure black `#000000` or pure white `#FFFFFF`.
- **Light direction:** NW (top-left) is the primary light source.
- **Shading:** top faces +15% brightness; lit side baseline; shadow side −15%; base edges darkened (ambient occlusion).
- **Edges:** 1–2 px edge accents sparingly. Subtle pixel noise preferred over flat fills.
- **Condition:** assets should feel faded, not vibrant. Strong silhouette at gameplay zoom is required.
- **Post-process grain / vignette / scanline** is applied at runtime — do NOT bake these into sprites.

---

## 7. Building Archetype → Theme Tag Table

### Current Archetypes (BuildingBlueprint.Archetype)

| Archetype | Theme Tag | Wall Material | Primary Floor | Wall Height | Notes |
|---|---|---|---|---|---|
| SMALL_HOUSE (0) | `res` | brick or siding | `wood` | 3 tiles | |
| MEDIUM_HOUSE (1) | `res` | brick | `wood` | 3 tiles | |
| CONVENIENCE_STORE (2) | `retail` | concrete + glass | `tile_commercial` | 4 tiles | |
| PHARMACY (3) | `retail` | concrete + glass | `linoleum` | 4 tiles | |
| HARDWARE_STORE (4) | `industrial` | concrete | `concrete` | 4 tiles | mapped to industrial, not retail |
| OFFICE (5) | `office` | concrete + glass | `carpet` | 4 tiles | |
| WAREHOUSE (6) | `warehouse` | corrugated metal | `concrete` | 4 tiles | |
| GARAGE (7) | `industrial` | cinder block | `concrete` | 3 tiles | |
| FARMHOUSE (8) | `res` | white siding | `wood` | 3 tiles | gable roof |
| RESTAURANT (9) | `restaurant` | brick + glass | `tile_commercial` | 4 tiles | |
| DUPLEX (10) | `res` | brick | `wood`/`carpet` | 3 tiles | flat roof |
| STORAGE_YARD (11) | `warehouse` | corrugated metal | `concrete` | 4 tiles | |

### Future Archetypes

| Future Archetype | Theme Tag | Notes |
|---|---|---|
| SCHOOL (12) | `school` | Needs CLASSROOM, SCHOOL_HALLWAY room purposes |
| HOSPITAL (13) | `medical` | Needs PATIENT_ROOM, OPERATING_ROOM, RECEPTION |
| POLICE_STATION (14) | `police` | Needs HOLDING_CELL, OFFICE_POLICE; reuses RECEPTION |
| CHURCH (15) | `church` | Needs NAVE, VESTRY room purposes |
| FIRE_STATION (16) | `fire` | future |
| LAB (17) | `lab` | future |

**Code constant to add in `scripts/world/BuildingBlueprint.gd`:**

```gdscript
enum AssetTheme {
    RES        = 0,
    RETAIL     = 1,
    OFFICE     = 2,
    WAREHOUSE  = 3,
    RESTAURANT = 4,
    INDUSTRIAL = 5,
    SCHOOL     = 6,
    MEDICAL    = 7,
    POLICE     = 8,
    CHURCH     = 9,
    FIRE       = 10,
    LAB        = 11,
}

static func theme_tag(theme: int) -> String:
    match theme:
        AssetTheme.RES:        return "res"
        AssetTheme.RETAIL:     return "retail"
        AssetTheme.OFFICE:     return "office"
        AssetTheme.WAREHOUSE:  return "warehouse"
        AssetTheme.RESTAURANT: return "restaurant"
        AssetTheme.INDUSTRIAL: return "industrial"
        AssetTheme.SCHOOL:     return "school"
        AssetTheme.MEDICAL:    return "medical"
        AssetTheme.POLICE:     return "police"
        AssetTheme.CHURCH:     return "church"
        _: return "res"

static func theme_for_archetype(arch: int) -> int:
    match arch:
        Archetype.SMALL_HOUSE, Archetype.MEDIUM_HOUSE, \
        Archetype.FARMHOUSE,   Archetype.DUPLEX:
            return AssetTheme.RES
        Archetype.CONVENIENCE_STORE, Archetype.PHARMACY:
            return AssetTheme.RETAIL
        Archetype.HARDWARE_STORE, Archetype.GARAGE:
            return AssetTheme.INDUSTRIAL
        Archetype.WAREHOUSE, Archetype.STORAGE_YARD:
            return AssetTheme.WAREHOUSE
        Archetype.OFFICE:
            return AssetTheme.OFFICE
        Archetype.RESTAURANT:
            return AssetTheme.RESTAURANT
        _:
            return AssetTheme.RES

var asset_theme: int = AssetTheme.RES
```

---

## 8. Room Purpose → Floor & Furniture (All Archetypes)

### Room Placement Layers

Build every room in this order:
1. **Structural shell** — floor, walls, doors, windows
2. **Required functional furniture** — must place all
3. **Optional furniture** — place by weighted random
4. **Decor** — wall-mounted items, signs, boards
5. **Clutter** — scattered items, papers, debris

### Residential (`res`) Room Archetypes

| Room Tag | Floor | Required | Optional | Forbidden |
|---|---|---|---|---|
| `bedroom` | `floor_res_bedroom_wood_v0*` | `bed_double`, `nightstand` | `desk_writing`, `dresser`, `wardrobe`, `chair`, `bookshelf_short` | hospital bed, school desk, prison bunk |
| `living` | `floor_res_living_carpet_v0*` | `sofa`, `table_coffee` | `chair`, `bookshelf`, `tv_stand`, `lamp_floor` | industrial shelf, school furniture |
| `kitchen` | `floor_res_kitchen_checker_v0*` | `counter`, `stove` | `fridge`, `table_kitchen`, `chair`, `shelf_pan` | hospital equipment, industrial rack |
| `hallway` | `floor_res_hallway_wood_v0*` | *(none)* | `shelf_small`, `coat_rack` | heavy furniture |
| `bathroom` | `floor_res_bathroom_tile_v0*` | *(none: future sink/toilet)* | *(none for now)* | |
| `storage` | `floor_res_storage_wood_v0*` | `shelf_metal_v0*` | `shelf_metal_v0*` (×2–3 total) | commercial counters |
| `garage` | `floor_res_garage_concrete_v0*` | *(none)* | `shelf_metal`, `workbench`, `counter` | home sofas, beds |

### Retail (`retail`) Room Archetypes
*(CONVENIENCE_STORE, PHARMACY)*

| Room Tag | Floor | Required | Optional | Forbidden |
|---|---|---|---|---|
| `commercial` (store floor) | `floor_retail_commercial_tile_v0*` | `shelf_metal` (×3–4 wall-aligned), `counter` (S wall) | `display_case`, `sign_store` | school desks, beds, sofas |

### Office (`office`) Room Archetypes

| Room Tag | Floor | Required | Optional | Forbidden |
|---|---|---|---|---|
| `office_room` | `floor_office_room_carpet_v0*` | `desk_office`, `chair_office` | `filing_cabinet`, `shelf_short`, `plant_office` | school lockers, industrial rack |
| `reception` | `floor_office_reception_carpet_v0*` | `desk_reception`, `chair_waiting` (×2–3) | `plant_office`, `sign_office` | |
| `storage` | `floor_office_storage_linoleum_v0*` | `shelf_metal`, `filing_cabinet` | *(more shelves)* | |

### Restaurant (`restaurant`) Room Archetypes

| Room Tag | Floor | Required | Optional | Forbidden |
|---|---|---|---|---|
| `dining` | `floor_restaurant_dining_tile_v0*` | `table_dining` (×3–4), `chair` (×8–12) | `booth`, `sign_menu`, `plant_decor` | school desks, beds |
| `kitchen` | `floor_restaurant_kitchen_tile_v0*` | `counter_kitchen`, `stove_commercial` | `shelf_kitchen`, `fridge_commercial` | home furniture |
| `storage` | `floor_restaurant_storage_concrete_v0*` | `shelf_metal` | `fridge_storage` | |

### Industrial — Warehouse (`warehouse`) Room Archetypes
*(WAREHOUSE, STORAGE_YARD)*

| Room Tag | Floor | Required | Optional | Forbidden |
|---|---|---|---|---|
| `storage` (warehouse floor) | `floor_warehouse_storage_concrete_v0*` | `shelf_metal` (×4–6, large, wall-aligned) | `locker_industrial`, `pallet`, `barrel`, `crate` | home furniture, school desks |

### Industrial — Garage (`industrial`) Room Archetypes
*(HARDWARE_STORE, GARAGE)*

| Room Tag | Floor | Required | Optional | Forbidden |
|---|---|---|---|---|
| `garage` | `floor_industrial_garage_concrete_v0*` | `workbench`, `shelf_metal` (×2–3) | `counter`, `toolbox`, `barrel` | home sofas, school furniture |
| `commercial` (hardware store) | `floor_industrial_commercial_concrete_v0*` | `shelf_metal` (×4–5), `counter` | `display_rack`, `sign_store` | home furniture, restaurant booths |

---

### Future Archetypes — Full Room Tables

#### School (`school`)

New `RoomDef.Purpose` constants required:
```gdscript
CLASSROOM     = 7,
SCHOOL_HALLWAY = 8,
CAFETERIA     = 9,
GYM           = 10,
NURSE_OFFICE  = 11,
LIBRARY       = 12,
```

| Room Tag | Floor | Required | Optional | Forbidden |
|---|---|---|---|---|
| `classroom` | `floor_school_classroom_tile_v0*` | `desk_teacher` (×1 front N wall), `desk_student` (×6–10 rows), `chalkboard` (N wall) | `chair_student` (×6–10), `bookshelf_short`, `poster_educational`, `globe`, `trashcan` | hospital bed, store counter, restaurant booth |
| `hallway` | `floor_school_hallway_linoleum_v0*` | `locker_single` (×4–8, both walls) | `bulletin_board`, `sign_roomnumber`, `bench`, `water_fountain` | student desks, beds |
| `cafeteria` | `floor_school_cafeteria_linoleum_v0*` | `table_long` (×3–5), `chair` (×12–20) | `counter_cafeteria`, `tray_rack`, `sign_menu` | |
| `library` | `floor_school_library_carpet_v0*` | `bookshelf_tall` (×4–8), `table_study` (×2–3) | `chair`, `globe`, `desk_librarian` | |
| `storage` | `floor_school_storage_linoleum_v0*` | `shelf_metal` (×2–3) | *(none)* | |
| `bathroom` | `floor_school_bathroom_tile_v0*` | *(none for now)* | | |
| `gym` | `floor_school_gym_wood_v0*` | *(none for now)* | `bleachers` (future), `basket_hoop` (future) | |
| `nurse` | `floor_school_nurse_tile_v0*` | `bed_cot`, `desk_nurse`, `cabinet_medicine` | `chair_waiting` | |
| `office_room` (principal) | `floor_school_principal_carpet_v0*` | `desk_principal`, `chair_office` | `bookshelf`, `flag`, `filing_cabinet` | |

Wall assets:
- Exterior: `wall_school_*_brick_v0*` — brick exterior
- Interior: `wall_school_*_painted_v0*` or `wall_school_hallway_cinderblock_v0*`

---

#### Medical / Hospital (`medical`)

New `RoomDef.Purpose` constants required:
```gdscript
PATIENT_ROOM   = 13,
OPERATING_ROOM = 14,
WAITING_ROOM   = 15,
```
*(reuses RECEPTION from office)*

| Room Tag | Floor | Required | Optional | Forbidden |
|---|---|---|---|---|
| `exam` (patient room) | `floor_medical_exam_linoleum_v0*` | `bed_exam` (×1–2), `nightstand`, `cabinet_medicine` | `chair_waiting`, `curtain_privacy`, `filing_cabinet` | school desks, lockers, church pews |
| `reception` | `floor_medical_reception_linoleum_v0*` | `desk_reception`, `chair_waiting` (×3–4) | `plant_office`, `sign_medical` | |
| `labroom` (OR) | `floor_medical_labroom_tile_v0*` | `table_operating` (center), `shelf_supply` (×2), `counter` | `medical_cart`, `lamp_surgical` (future) | |
| `storage` | `floor_medical_storage_concrete_v0*` | `shelf_metal` (×3–4), `filing_cabinet` | | school furniture, restaurant booths |
| `bathroom` | `floor_medical_bathroom_tile_v0*` | *(none for now)* | | |

Wall assets: `wall_medical_*_plaster_v0*` — white/cream plaster, clinical look

---

#### Police Station (`police`)

New `RoomDef.Purpose` constants required:
```gdscript
HOLDING_CELL  = 16,
BRIEFING_ROOM = 17,
```
*(reuses `office_room`, `reception`)*

| Room Tag | Floor | Required | Optional | Forbidden |
|---|---|---|---|---|
| `cell` (holding cell) | `floor_police_cell_concrete_v0*` | `bed_cot` (×1) | *(nothing else)* | home sofas, school desks |
| `office_room` | `floor_police_office_linoleum_v0*` | `desk_office` (×2–3), `chair_office` (×2–3), `filing_cabinet` (×2–3) | `locker_police`, `sign_badge`, `bulletin_board` | restaurant booths, school desks |
| `reception` | `floor_police_reception_linoleum_v0*` | `desk_reception` (bulletproof style), `chair_waiting` (×2) | `sign_police`, `flag` | |
| `storage` | `floor_police_storage_concrete_v0*` | `shelf_metal` (×3–4), `locker_police` (×2–4) | | |
| `briefing_room` | `floor_police_briefing_linoleum_v0*` | `table_conference`, `chair` (×6–8) | `screen_presentation`, `map_wall` | |

Wall assets:
- Exterior: `wall_police_*_concrete_v0*` or `wall_police_*_brick_v0*`
- Interior: `wall_police_*_painted_v0*`

Distinctive feature: future `WIN_BARRED` window state for holding cells.

---

#### Church (`church`)

New `RoomDef.Purpose` constants required:
```gdscript
NAVE   = 18,
VESTRY = 19,
```

| Room Tag | Floor | Required | Optional | Forbidden |
|---|---|---|---|---|
| `nave` (main hall) | `floor_church_nave_stone_v0*` | `pew` (×8–16 in rows), `altar` (×1 N wall) | `candle_holder`, `lectern`, `cross_wall_decor`, `rug_aisle` | school desks, office chairs, hospital equipment |
| `vestry` | `floor_church_vestry_wood_v0*` | `shelf_metal` (×2), `table_study` (×1) | `cabinet_vestments`, `chair` | |
| `storage` | `floor_church_storage_stone_v0*` | `shelf_metal` (×2) | | |

Wall assets: `wall_church_*_stone_v0*` — stone block exterior, narrow high windows
Distinctive feature: future `WIN_STAINED` window type for nave.

New FURN constants for church:
```gdscript
const FURN_PEW   := 16
const FURN_ALTAR := 17
```

---

## 9. Metadata Standard

Every asset must have a metadata entry in `asset_registry.json`.

```json
{
  "id": "furn_school_classroom_desk_student_v01_s_clean_1x1",
  "sheet": "furn_school_classroom_desks_set01_sheet",
  "frame": 2,
  "category": "furn",
  "theme": "school",
  "subtheme": "classroom",
  "asset_name": "desk_student",
  "footprint": [1, 1],
  "placement_type": "floor",
  "placement_affinity": ["wall_near", "row_pattern"],
  "orientations": ["n", "e", "s", "w"],
  "state": "clean",
  "allowed_buildings": ["school"],
  "allowed_rooms": ["classroom"],
  "blocking": true,
  "shared_utility": false,
  "tags": ["student", "desk", "education"],
  "rarity": "common",
  "weight": 100
}
```

### Placement Affinity Values

| Affinity | Meaning |
|---|---|
| `wall` | Must be adjacent to a wall edge |
| `corner` | Prefer corner tiles |
| `center` | Prefer room center |
| `entry_near` | Prefer tiles near the door |
| `window_near` | Prefer tiles near windows |
| `front_of_room` | Prefer the N/front wall side |
| `hallway_wall` | Long walls in corridor rooms |
| `row_pattern` | Align in rows (student desks) |

### Shared Utility Assets

Some assets are valid across multiple themes (trash cans, mop buckets, exit signs, metal shelves, fluorescent lights). Mark them:

```json
"shared_utility": true,
"allowed_buildings": ["*"]
```

---

## 10. Data Files to Maintain

Create and maintain these files in `res://assets/buildings/metadata/`:

| File | Purpose |
|---|---|
| `asset_registry.json` | Full list of every asset with metadata |
| `building_theme_rules.json` | Per-building-type: allowed rooms, shared utility flag |
| `room_archetypes.json` | Per-room: required, optional, forbidden, placement hints, weights |
| `shared_utility_assets.json` | List of cross-theme shared assets |
| `tileset_sheet_map.json` | Sheet → frame → asset ID mappings |

### Example `building_theme_rules.json` entry

```json
{
  "building_type": "school",
  "theme_tag": "school",
  "allowed_rooms": [
    "classroom", "hallway", "library", "cafeteria",
    "bathroom", "office_room", "storage", "gym", "nurse", "principal"
  ],
  "shared_utilities_allowed": true,
  "wall_height_tiles": 4
}
```

### Example `room_archetypes.json` entry

```json
{
  "room_type": "classroom",
  "allowed_buildings": ["school"],
  "required_assets": ["desk_teacher", "desk_student", "chalkboard"],
  "optional_assets": [
    {"id": "chair_student",       "weight": 100},
    {"id": "bookshelf_short",     "weight": 35},
    {"id": "poster_educational",  "weight": 65},
    {"id": "trashcan",            "weight": 50},
    {"id": "globe",               "weight": 8},
    {"id": "skeleton_model",      "weight": 2}
  ],
  "forbidden_assets": [
    "hospital_bed", "store_counter", "restaurant_booth",
    "prison_bunk", "stove_industrial"
  ],
  "placement_hints": ["desks_in_rows", "teacher_front_wall", "chalkboard_north_wall"]
}
```

---

## 11. Code Changes Required

### A. `scripts/world/BuildingBlueprint.gd`

- Add `AssetTheme` enum (see Section 7)
- Add `theme_tag(theme)` static method
- Add `theme_for_archetype(arch)` static method
- Add `var asset_theme: int = AssetTheme.RES`

### B. `scripts/world/MapData.gd`

Add floor theme constants and grid:
```gdscript
const FLOOR_NONE            := 0
const FLOOR_WOOD            := 1
const FLOOR_CARPET          := 2
const FLOOR_TILE_KITCHEN    := 3
const FLOOR_LINOLEUM        := 4
const FLOOR_CONCRETE        := 5
const FLOOR_TILE_COMMERCIAL := 6
const FLOOR_TILE_MEDICAL    := 7
const FLOOR_STONE           := 8
const FLOOR_CHECKER         := 9

const FLOOR_SHEET_NAMES := {
    FLOOR_WOOD:            "wood",
    FLOOR_CARPET:          "carpet",
    FLOOR_TILE_KITCHEN:    "tile_kitchen",
    FLOOR_LINOLEUM:        "linoleum",
    FLOOR_CONCRETE:        "concrete",
    FLOOR_TILE_COMMERCIAL: "tile_commercial",
    FLOOR_TILE_MEDICAL:    "tile_medical",
    FLOOR_STONE:           "stone",
    FLOOR_CHECKER:         "checker",
}

var floor_theme_grid: PackedInt32Array  # one FLOOR_* per tile, size = map_w * map_h

func get_floor_theme(tx: int, ty: int) -> int:
    return floor_theme_grid[ty * map_width + tx]

func set_floor_theme(tx: int, ty: int, theme: int) -> void:
    floor_theme_grid[ty * map_width + tx] = theme
```

Add new furniture constants:
```gdscript
const FURN_FRIDGE          := 11
const FURN_FILING_CABINET  := 12
const FURN_CHALKBOARD      := 13
const FURN_DRESSER         := 14
const FURN_WARDROBE        := 15
const FURN_PEW             := 16
const FURN_ALTAR           := 17
```

Initialize `floor_theme_grid` alongside `wall_grid` in `MapData` setup.

### C. `scripts/world/MapGenerator.gd`

Set `asset_theme` on blueprint during generation:
```gdscript
bp.asset_theme = BuildingBlueprint.theme_for_archetype(archetype)
```

Add `_paint_room_floors()` and `_floor_theme_for_room()`:
```gdscript
func _paint_room_floors(room: BuildingBlueprint.RoomDef, bp: BuildingBlueprint) -> void:
    var floor_theme := _floor_theme_for_room(room.purpose, bp.asset_theme)
    for cell: Vector2i in room.floor_cells:
        _data.set_floor_theme(cell.x, cell.y, floor_theme)

func _floor_theme_for_room(purpose: int, theme: int) -> int:
    match purpose:
        BuildingBlueprint.RoomDef.Purpose.BEDROOM:   return MapData.FLOOR_WOOD
        BuildingBlueprint.RoomDef.Purpose.HALLWAY:   return MapData.FLOOR_WOOD
        BuildingBlueprint.RoomDef.Purpose.STORAGE:   return MapData.FLOOR_WOOD
        BuildingBlueprint.RoomDef.Purpose.KITCHEN:   return MapData.FLOOR_TILE_KITCHEN
        BuildingBlueprint.RoomDef.Purpose.BATHROOM:  return MapData.FLOOR_TILE_KITCHEN
        BuildingBlueprint.RoomDef.Purpose.LIVING:
            match theme:
                BuildingBlueprint.AssetTheme.RES:    return MapData.FLOOR_CARPET
                BuildingBlueprint.AssetTheme.OFFICE: return MapData.FLOOR_CARPET
                _:                                   return MapData.FLOOR_TILE_COMMERCIAL
        BuildingBlueprint.RoomDef.Purpose.COMMERCIAL:
            match theme:
                BuildingBlueprint.AssetTheme.WAREHOUSE,
                BuildingBlueprint.AssetTheme.INDUSTRIAL: return MapData.FLOOR_CONCRETE
                _:                                       return MapData.FLOOR_TILE_COMMERCIAL
    return MapData.FLOOR_WOOD
```

Update `_furniture_list_for_room()` to be archetype-aware, returning dicts with:
```gdscript
{
    furn_type  = MapData.FURN_*,
    wall_pref  = DIR_N,      # preferred wall side
    facing_rule = DIR_S,     # facing direction
    clearance  = 1,          # required free tiles in front
    weight     = 100,        # probability weight
    required   = true,       # false = optional
}
```

### D. `scripts/world/BuildingTileRenderer.gd`

Add texture loading with null fallback:
```gdscript
var _wall_ne_tex: Texture2D = null
var _wall_nw_tex: Texture2D = null
var _floor_textures: Dictionary = {}  # FLOOR_* → Texture2D

func _load_theme_textures(theme: int) -> void:
    var tag := BuildingBlueprint.theme_tag(theme)
    var ne_path := "res://assets/buildings/tilesets/walls/wall_%s_ne_sheet.png" % tag
    var nw_path := "res://assets/buildings/tilesets/walls/wall_%s_nw_sheet.png" % tag
    if ResourceLoader.exists(ne_path):
        _wall_ne_tex = load(ne_path)
    if ResourceLoader.exists(nw_path):
        _wall_nw_tex = load(nw_path)
    for floor_id in MapData.FLOOR_SHEET_NAMES:
        var fname := MapData.FLOOR_SHEET_NAMES[floor_id]
        var fpath := "res://assets/buildings/tilesets/floors/floor_%s_sheet.png" % fname
        if ResourceLoader.exists(fpath):
            _floor_textures[floor_id] = load(fpath)
```

In `_draw_wall_face()` and `_draw_floor_tile()`:
- If texture is not null → use `draw_textured_polygon()`
- If texture is null → fall back to current `draw_colored_polygon()` (nothing breaks before art exists)

---

## 12. Adding a New Building Type — Checklist

1. Add archetype constant to `BuildingBlueprint.Archetype` enum
2. Add size range in `MapGenerator._archetype_size()`
3. Add to zone picker in `MapGenerator._pick_archetype()`
4. Add theme in `BuildingBlueprint.theme_for_archetype()` and `AssetTheme` enum
5. Add new `RoomDef.Purpose` constants if needed
6. Add purpose assignment logic in `MapGenerator._assign_room_purposes()`
7. Add furniture lists in `MapGenerator._furniture_list_for_room()`
8. Add floor theme mapping in `MapGenerator._floor_theme_for_room()`
9. Add entry in `building_theme_rules.json`
10. Add room archetype entries in `room_archetypes.json`
11. Create asset folder: `res://assets/buildings/furniture/{theme}/`
12. Create sprite sheets following conventions in Section 3 and Section 5
13. Add asset entries to `asset_registry.json`

---

## 13. Asset Creation Checklist Per Theme

Minimum viable set for a new archetype to render correctly:

| Asset | File | Size | Priority |
|---|---|---|---|
| NE wall face sheet | `wall_{theme}_ne_sheet.png` | 64×96 or 64×128 px | Critical |
| NW wall face sheet | `wall_{theme}_nw_sheet.png` | 64×96 or 64×128 px | Critical |
| Primary floor tile | `floor_{theme}_{room}_{material}_sheet.png` | 64×32 px (or 256×32 for variety) | Critical |
| Main furniture sheet | `furn_{theme}_{room}_{family}_set01_sheet.png` | 128×512 px (4 items × 4 dirs) | High |
| Frame map JSON | `furn_{theme}_{room}_{family}_set01_sheet.json` | — | High |
| Roof tile | `roof_{theme}_flat_sheet.png` | 64×32 px | Medium |

---

## 14. Validation Rules

Before finalizing any room or building:

**Structural validation**
- Required floor, wall, and door assets are present
- Windows only placed on valid exterior wall edges
- No windows at corners or adjacent to doors

**Theme validation**
- All placed assets have `allowed_buildings` containing this building type
- All placed assets have `allowed_rooms` containing this room tag
- No forbidden assets present
- Shared utility assets only used when `shared_utilities_allowed = true`

**Layout validation**
- No footprint overlaps
- Doors are accessible (clearance tile is free)
- Required furniture is reachable
- Enough walkable tiles remain (minimum 40% of room floor unblocked)

**Archetype validation**
- All required assets from `room_archetypes.json` are placed
- Optional count is reasonable (not packed wall-to-wall)

---

## 15. How Claude Selects Assets

Claude queries assets through this pipeline:

```
building_type (Archetype enum)
    ↓ theme_for_archetype()
theme_tag (string: "school", "res", etc.)
    ↓ building_theme_rules.json
allowed_room_types for this building
    ↓ for each room
room_archetype (room_archetypes.json)
    ↓
place required assets (required_assets list)
    ↓
place optional assets (by weight, check footprint fits)
    ↓
place decor (separate pass)
    ↓
place clutter (separate pass)
    ↓
validate (theme, footprint, accessibility, required presence)
```

**Claude never selects assets by loose keyword guessing. It uses `allowed_buildings`, `allowed_rooms`, `category`, footprint, and the forbidden list.**
