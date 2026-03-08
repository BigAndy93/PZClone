# SimZombie / PZClone – Building Asset Naming & Thematic Construction Rules
*Asset naming convention, tileset organization, and Claude Code generation rules for building-specific assets*

---

## Purpose

This document defines a strict naming convention and content-tagging system for building assets so that:

1. you can organize a very large library of wall, floor, door, window, furniture, and decor sprites
2. Claude Code can reliably select only the correct assets for a given building type
3. procedural or semi-procedural building generation can stay theme-correct
4. future tools can validate whether a room contains appropriate content

This is a production pipeline standard, not just a file naming guide.

---

# 1. Core Principle

Treat each asset as a data-driven building piece with:

- a visual identity
- a physical type
- a room/theme tag
- a placement rule
- a material/style family
- optional district, wealth, era, or decay tags

Claude should never choose assets by filename alone.
Use predictable filenames plus metadata.

---

# 2. Naming Convention Formula

Use:

```text
[category]_[theme]_[subtheme]_[assetname]_[variant]_[orientation]_[state]_[size]
```

Not every field must always appear, but the order should remain consistent.

## Fields

### category
Examples:
- wall
- floor
- door
- window
- roof
- trim
- furn
- decor
- clutter
- sign
- fixture

### theme
Examples:
- res
- school
- office
- medical
- industrial
- retail
- restaurant
- warehouse
- utility
- government
- church
- police
- fire
- lab

### subtheme
Examples:
- classroom
- hallway
- cafeteria
- library
- principal
- bathroom
- kitchen
- bedroom
- exam
- reception
- storage
- breakroom

### assetname
Examples:
- tile
- linoleum
- chalkboard
- desk_student
- locker
- wall_panel
- window_tall
- door_single
- shelf_metal

### variant
Examples:
- v01
- v02
- a
- b
- c

### orientation
Examples:
- n
- e
- s
- w
- front
- back
- left
- right
- inner
- outer
- horz
- vert

### state
Examples:
- clean
- dirty
- damaged
- broken
- boarded
- bloody
- burned
- abandoned
- faded
- dented
- dusty

### size
Examples:
- 1x1
- 2x1
- 2x2
- 3x2

---

# 3. Good Naming Examples

## Structural

```text
wall_school_classroom_painted_v01_horz_clean
wall_school_hallway_cinderblock_v02_vert_dirty
floor_school_classroom_tile_v01_clean
floor_school_hallway_linoleum_v02_dirty
door_school_classroom_single_v01_left_clean
window_school_classroom_tall_v01_vert_clean
roof_school_main_flat_v01_clean
trim_school_hallway_baseboard_v01_clean
```

## Furniture

```text
furn_school_classroom_desk_student_v01_front_clean_1x1
furn_school_classroom_desk_teacher_v01_front_clean_2x1
furn_school_hallway_locker_single_v01_front_dented_1x1
furn_school_library_bookshelf_tall_v02_front_dusty_1x1
furn_school_cafeteria_table_long_v01_front_dirty_3x1
```

## Decor / clutter / signs

```text
decor_school_classroom_chalkboard_v01_front_clean_2x1
decor_school_classroom_poster_math_v02_front_faded_1x1
clutter_school_classroom_papers_scattered_v01_front_dirty_1x1
sign_school_hallway_roomnumber_101_v01_front_clean_1x1
```

---

# 4. Controlled Vocabulary

Do not let naming drift into random synonyms.

Bad:
- desk
- studentdesk
- schooldesk
- class_desk

Good:
- always use one approved term, such as `desk_student`

## Recommended themes

```text
res
school
office
medical
industrial
retail
restaurant
warehouse
utility
government
church
police
fire
lab
farm
hotel
```

## Recommended room tags

```text
entry
hallway
classroom
library
cafeteria
kitchen
bathroom
bedroom
office_room
storage
breakroom
reception
exam
labroom
cell
garage
boiler
utility_room
living
dining
laundry
gym
nurse
principal
waiting
```

---

# 5. Folder Structure

```text
Assets/
└── Buildings/
    ├── Tilesets/
    │   ├── Structural/
    │   ├── Floors/
    │   ├── Walls/
    │   ├── Doors/
    │   ├── Windows/
    │   ├── Roofs/
    │   ├── Stairs/
    │   └── Trim_Overlays/
    ├── Furniture/
    │   ├── Residential/
    │   ├── School/
    │   ├── Office/
    │   ├── Medical/
    │   ├── Industrial/
    │   ├── Retail/
    │   ├── Restaurant/
    │   └── Utility/
    ├── Decor/
    ├── Clutter/
    ├── Signage/
    └── Metadata/
```

Separate structural tiles from furniture, decor, clutter, and signage.

---

# 6. Sprite Sheet Naming

For sheets, name by family:

```text
[category]_[theme]_[subtheme]_[family]_[setname]_sheet
```

Examples:

```text
wall_school_classroom_painted_set01_sheet
floor_school_hallway_linoleum_set01_sheet
furn_school_classroom_desks_set01_sheet
furn_school_hallway_lockers_set01_sheet
decor_school_classroom_teaching_set01_sheet
```

---

# 7. Frame Mapping

Do not rely on raw frame numbers without a mapping file.

Example:

```text
Sheet: furn_school_classroom_desks_set01_sheet.png

Frames:
0 = furn_school_classroom_desk_student_v01_front_clean_1x1
1 = furn_school_classroom_desk_student_v02_front_clean_1x1
2 = furn_school_classroom_desk_teacher_v01_front_clean_2x1
3 = furn_school_classroom_chair_v01_front_clean_1x1
```

Use a sidecar data file for mapping.

---

# 8. Metadata Standard

Every asset should have metadata.

Example:

```json
{
  "id": "furn_school_classroom_desk_student_v01_front_clean_1x1",
  "category": "furn",
  "theme": "school",
  "room_tags": ["classroom"],
  "asset_name": "desk_student",
  "footprint": [1,1],
  "placement_type": "floor",
  "orientations": ["front"],
  "state": "clean",
  "allowed_buildings": ["school"],
  "allowed_rooms": ["classroom"],
  "blocking": true,
  "tags": ["student", "desk", "education"],
  "rarity": "common"
}
```

This is how Claude stays on-theme.

---

# 9. How Claude Should Filter Assets

Claude should ask:

> Given this building type and room type, what assets are allowed here?

Filter by:

1. building type
2. room type
3. asset category
4. placement rules
5. condition profile
6. optional district / wealth / era rules

Pipeline:

```text
building type
    ↓
room type
    ↓
asset category
    ↓
allowed asset pool
    ↓
placement rules
    ↓
weighted random selection
```

---

# 10. Building Theme Rules

Each building type should define a whitelist.

## School

Allowed room types:
- classroom
- hallway
- library
- cafeteria
- bathroom
- office_room
- storage
- gym
- nurse
- principal

Allowed assets:
- desks
- lockers
- chalkboards
- bookshelves
- cafeteria tables
- school posters
- bulletin boards
- trophy cases

Disallowed:
- hospital surgery tools
- office cubicles
- retail checkout counters
- luxury home furniture

## Medical

Allowed room types:
- reception
- exam
- waiting
- bathroom
- labroom
- storage
- office_room

Allowed assets:
- exam beds
- medicine cabinets
- privacy curtains
- waiting chairs
- front desk
- sinks
- medical carts

Disallowed:
- school lockers
- student desks
- restaurant booths
- church pews

## Residential

Allowed room types:
- bedroom
- bathroom
- kitchen
- living
- dining
- garage
- hallway
- laundry

Allowed assets:
- couches
- beds
- fridges
- counters
- dressers
- home tables
- bookshelves
- TVs

Disallowed:
- classroom desks in bulk
- hospital equipment
- prison cells

---

# 11. Room Archetypes

Each room type should define required, optional, and forbidden assets.

## School classroom

Required:
- teacher desk
- multiple student desks or desk-chair combos
- chalkboard or whiteboard
- classroom door
- classroom floor type
- classroom wall type

Common optional:
- posters
- bookshelf
- trash can
- cabinet
- clock
- scattered papers

Rare optional:
- TV cart
- science model
- broken desk
- blood stains
- barricade elements

## School hallway

Required:
- hallway floor
- hallway wall
- hallway doors

Common optional:
- lockers
- bulletin boards
- room number signs
- benches
- water fountain

Rare optional:
- trophy case
- fallen ceiling tile
- broken locker door

---

# 12. Separate Structure from Dressing

Claude should build rooms in layers.

## Layer 1: structural shell
- floor
- wall
- doors
- windows

## Layer 2: functional furniture
- desks
- beds
- counters
- shelves
- lockers
- tables

## Layer 3: decor
- posters
- signs
- lamps
- bulletin boards

## Layer 4: clutter
- papers
- broken glass
- blood
- debris
- bags
- trash

---

# 13. Placement Rules

Each asset should include placement logic.

## Wall-mounted
- chalkboard
- posters
- room signs
- clocks
- bulletin boards

Only place on valid wall edges.

## Floor furniture
- desks
- lockers
- shelves
- beds
- tables

Must fit within open floor tiles.

## Corner-friendly
- trash can
- potted plant
- utility bucket

Prefer corners or wall-adjacent positions.

## Centerpiece
- cafeteria table
- principal desk
- lab workstation

Prefer center or dominant room positions.

---

# 14. Footprints and Affinities

Every placeable asset should include a footprint.

Examples:

```text
1x1 = chair, trash can, end table
2x1 = desk, sink, couch segment
2x2 = bed, large table
3x1 = long cafeteria table
```

Recommended metadata:

```json
"footprint": [2,1]
"placement_affinity": ["wall"]
```

Common affinities:
- wall
- corner
- center
- entry_near
- window_near
- front_of_room
- hallway_wall

---

# 15. Required / Optional / Forbidden Rules

Example:

```json
{
  "room_type": "classroom",
  "required": ["desk_teacher", "desk_student", "chalkboard"],
  "optional": ["bookshelf_short", "poster_educational", "trashcan"],
  "forbidden": ["hospital_bed", "stove_industrial", "prison_bunk"]
}
```

Claude order:
1. place required
2. place optional
3. never place forbidden

---

# 16. Weighted Randomization

Do not pick all assets evenly.

Example classroom weights:

```text
desk_student = 100
chair_student = 100
chalkboard = 90
poster_educational = 65
bookshelf_short = 35
globe = 8
skeleton_model = 2
```

---

# 17. Condition Profiles

Use condition profiles to filter variants.

Examples:
- maintained
- lightly_dirty
- abandoned
- looted
- barricaded
- bloodstained
- burned

Example:
`school_classroom_abandoned`

Allowed states:
- dirty
- broken
- faded
- papers scattered

---

# 18. Shared Utility Assets

Some assets are valid across themes.

Examples:
- trash can
- mop bucket
- exit sign
- fluorescent ceiling light
- utility sink
- generic metal shelf

Mark them with:

```json
"shared_utility": true
```

Use shared utility assets only when explicitly allowed.

---

# 19. Recommended Data Files

Maintain:

- `asset_registry.json`
- `building_theme_rules.json`
- `room_archetypes.json`
- `shared_utility_assets.json`
- `tileset_sheet_map.json`

---

# 20. Example Data

## Building theme rule

```json
{
  "building_type": "school",
  "allowed_rooms": [
    "classroom",
    "hallway",
    "library",
    "cafeteria",
    "bathroom",
    "office_room",
    "storage",
    "gym",
    "nurse",
    "principal"
  ],
  "shared_utilities_allowed": true
}
```

## Room archetype rule

```json
{
  "room_type": "hallway",
  "allowed_buildings": ["school"],
  "required_categories": ["floor", "wall", "door"],
  "required_assets": [],
  "optional_assets": [
    "locker_single",
    "bulletin_board",
    "roomnumber_sign",
    "bench",
    "water_fountain"
  ],
  "forbidden_assets": [
    "hospital_bed",
    "student_desk",
    "restaurant_booth"
  ],
  "placement_hints": [
    "long_wall_alignment",
    "door_spacing",
    "decor_sparse"
  ]
}
```

## Asset registry entry

```json
{
  "id": "furn_school_hallway_locker_single_v01_front_dented_1x1",
  "sheet": "furn_school_hallway_lockers_set01_sheet",
  "frame": 3,
  "category": "furn",
  "theme": "school",
  "room_tags": ["hallway"],
  "asset_name": "locker_single",
  "footprint": [1,1],
  "placement_type": "floor",
  "placement_affinity": ["wall"],
  "allowed_buildings": ["school"],
  "allowed_rooms": ["hallway"],
  "blocking": true,
  "state": "dented",
  "shared_utility": false
}
```

---

# 21. Structural Naming Rules

## Floors
```text
floor_[theme]_[room]_[material]_[variant]_[state]
```

Examples:
```text
floor_school_classroom_tile_v01_clean
floor_school_hallway_linoleum_v02_dirty
floor_medical_exam_linoleum_v01_clean
floor_res_kitchen_checker_v01_dirty
```

## Walls
```text
wall_[theme]_[room]_[material]_[variant]_[orientation]_[state]
```

Examples:
```text
wall_school_classroom_painted_v01_horz_clean
wall_school_hallway_cinderblock_v01_vert_dirty
wall_res_bedroom_wallpaper_v02_horz_faded
```

## Doors
```text
door_[theme]_[room]_[style]_[variant]_[orientation]_[state]
```

## Windows
```text
window_[theme]_[room]_[style]_[variant]_[orientation]_[state]
```

---

# 22. Furniture / Decor / Clutter Naming

## Furniture
```text
furn_[theme]_[room]_[object]_[variant]_[orientation]_[state]_[size]
```

## Decor
```text
decor_[theme]_[room]_[object]_[variant]_[orientation]_[state]_[size]
```

## Clutter
```text
clutter_[theme]_[room]_[object]_[variant]_[orientation]_[state]_[size]
```

## Signs
```text
sign_[theme]_[room]_[object]_[variant]_[orientation]_[state]_[size]
```

---

# 23. How Claude Should Build a Room

Algorithm:

1. identify building type and room archetype
2. resolve allowed themes
3. choose structural shell
4. place required functional assets
5. place optional furniture
6. place decor
7. place clutter
8. validate

Example classroom shell:
- floor from `floor_school_classroom_*`
- walls from `wall_school_classroom_*`
- door from `door_school_classroom_*`

---

# 24. Validation Rules

Before finalizing a room/building:

## Structural validation
- required floor, wall, and door assets exist
- windows only on valid exterior walls

## Theme validation
- all placed assets belong to allowed theme or shared utility
- no forbidden assets present

## Layout validation
- no overlap
- doors accessible
- key furniture reachable
- enough walkable space remains

## Archetype validation
- required assets present
- optional count remains reasonable

---

# 25. Stable IDs and Versioning

Once an asset ID is used in data, avoid renaming it.

If visual art changes but gameplay meaning stays the same:
- keep the same ID

If design meaning changes:
- make a new variant

Example:
```text
furn_school_classroom_desk_student_v01_front_clean_1x1
furn_school_classroom_desk_student_v02_front_clean_1x1
```

---

# 26. Claude Code Prompt Block

Paste this into Claude Code:

```text
When generating buildings, do not select assets by loose keyword matching.

Use asset metadata and naming rules.

Only place an asset if:
- its allowed_buildings contains the current building type
- its allowed_rooms contains the current room type
- its category matches the current placement phase
- it is not in the forbidden list for the room archetype
- its footprint fits the available free tiles

Use shared utility assets only when explicitly allowed.

Build rooms in this order:
1. structural shell
2. required functional assets
3. optional furniture
4. decor
5. clutter

After placement, validate:
- theme correctness
- footprint overlap
- room accessibility
- required asset presence
```

---

# 27. Production Pipeline

```text
sprite sheet art
    ↓
sheet/frame map
    ↓
asset registry metadata
    ↓
building theme rules
    ↓
room archetype rules
    ↓
Claude generation pass
    ↓
validation pass
```

---

# 28. Bottom Line

If you want Claude to only build believable buildings out of relevant assets:

- keep names strict
- keep vocabulary controlled
- separate themes and room archetypes
- use metadata, not just filenames
- whitelist by building type and room type
- use required / optional / forbidden rules
- validate after generation

With this structure, your building generation becomes scalable.
