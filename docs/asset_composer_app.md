# Asset Composer App

`res://tools/AssetComposer.tscn` is an in-project editor utility for building map-generator-ready structure data from existing assets.

## What it does

- Scans `res://assets` recursively and loads sprite, scene, resource, audio, and JSON files into a searchable asset library.
- Lets you organize placements into three structure groups:
  - Building templates
  - Scenes
  - Map chunks
- Lets you build placements by assigning:
  - Asset path
  - Tile coordinates (`x`, `y`, `z`)
  - Rotation in degrees
  - Scale
  - Layer tag
  - Unique flag
- Supports placement duplication for quickly creating one-off variants.
- Saves and loads a working file from `user://asset_composer_structures.json`.
- Exports map-generator input JSON to `res://resources/map_templates/asset_composer_export.json`.

## Running it

1. Open Godot.
2. Open and run `tools/AssetComposer.tscn`.
3. Use the left panel to choose assets.
4. Use the right panel to create/edit structures and placements.
5. Click **Export For Map Generator** when ready.

## Export format

The export JSON contains:

- `version`
- `exported_at_unix`
- `types`
  - `building_templates`: array of structure objects
  - `scenes`: array of structure objects
  - `map_chunks`: array of structure objects

Each structure object includes:

- `id`
- `name`
- `notes`
- `placements`: array of placement objects

Each placement object includes:

- `asset`
- `x`, `y`, `z`
- `rotation_deg`
- `scale`
- `layer`
- `unique`

This format is intentionally data-driven so map generation systems can consume it directly or via a converter pass.
