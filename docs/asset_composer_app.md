# Asset Composer App

`res://tools/AssetComposer.tscn` is an in-project editor utility for building map-generator-ready structure data from existing assets.

## Implemented feature alignment (from design doc)

Implemented now:

- Asset browser with search + category filters + favorites + tagging
- Visual isometric placement viewport in two workspaces:
  - Composer tab for detailed editing
  - Viewport tab for clean empty-grid template blockout
- Spritesheet metadata editor + visual frame-grid viewer
- Structure composition with floors/walls/doors/props via layers
- Room designation with metadata fields:
  - Room type
  - Lighting type
  - Spawn points
  - Loot table
- Template metadata fields:
  - Category
  - Spawn weight
  - Tags
  - Derived size and room count
- Validation pass button before save/export
- Save/load/export JSON pipeline for procedural generation

Partially implemented / future work:

- Paint tool suite (rectangle/line/fill/eraser/eyedropper)
- Wall-edge segment system with auto corners
- Full preview mode simulation
- Advanced path/accessibility validation

## Data output

Export includes:

- `version`
- `exported_at_unix`
- `sprite_metadata`
- `asset_browser`
  - `favorites`
  - `tags`
- `types`
  - `building_templates`
  - `scenes`
  - `map_chunks`

Each structure includes:

- core fields (`id`, `name`, `notes`, `width`, `depth`, `floors`)
- `template_metadata` (`category`, `spawn_weight`, `tags`, derived size/room_count)
- `generation`
- `rooms`
- `furniture`
- `placements`

## Main workflow

1. Select asset category/filter/tag in left panel.
2. Place on visual isometric grid (click to place, drag to move).
3. Define structure metadata and generation rules.
4. Define rooms and room metadata.
5. Populate furniture/props.
6. Run **Validate Template**.
7. Save local and export for generator.


