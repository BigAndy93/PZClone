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
