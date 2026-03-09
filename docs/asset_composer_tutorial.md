# Asset Composer Tutorial

## Fast path

1. Open `res://tools/AssetComposer.tscn`.
2. In Asset Browser:
   - filter by text
   - choose category (`all`, `favorites`, `floors`, `walls`, etc.)
   - optionally set favorite/tag on selected assets
3. In structure header:
   - set name/notes
   - set template metadata (`category`, `spawn_weight`, `tags`)
   - set size (`width`, `depth`, `floors`)
4. Set wall/floor/door generation assets and generate shell.
5. Use **Visual Isometric Grid** to place and drag assets.
6. Add rooms and fill room metadata:
   - type
   - lighting
   - spawn points
   - loot table
7. Add furniture and assign room.
8. For spritesheets:
   - select image
   - set metadata fields
   - open visual spritesheet viewer
9. Click **Validate Template**.
10. Save local and export.

## Notes

- Validation currently checks placement presence, layer coverage, overlap, rough wall coverage, and room bounds.
- Advanced wall-edge graph validation and simulation preview are planned follow-ups.
