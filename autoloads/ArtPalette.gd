## ArtPalette — Centralised colour authority for PZClone.
## All colour constants in world-rendering files should reference this.
## Registered as autoload "ArtPalette" in project.godot.
##
## Art-bible §2.1 rules:
##   - No pure black (#000) or pure white (#FFF)
##   - Darkest value: deep navy / green-charcoal
##   - Brightest value: soft bone / dusty yellow
##   - Avoid high-saturation primaries

extends Node
# Note: no class_name here — autoload scripts must not declare a class_name
# that matches the autoload node name, or Godot raises a global-name conflict.
# Access this singleton as the global "ArtPalette" (registered in project.godot).

# ── Core swatches ─────────────────────────────────────────────────────────────
const SHADOW_BASE  := Color(0.10, 0.11, 0.16)   # deep navy-charcoal (darkest)
const BONE_WHITE   := Color(0.86, 0.84, 0.74)   # soft bone (brightest)
const COLD_BLUE    := Color(0.32, 0.36, 0.50)   # shadow tint
const WARM_LAMP    := Color(0.92, 0.82, 0.52)   # interior practical light
const SICK_GREEN   := Color(0.26, 0.34, 0.20)   # desaturated foliage key
const DUSTY_BROWN  := Color(0.44, 0.36, 0.24)   # dirt / wood base

# ── Ground tiles ──────────────────────────────────────────────────────────────
const TILE_GRASS    := Color(0.25, 0.38, 0.19)
const TILE_ROAD     := Color(0.30, 0.31, 0.34)
const TILE_DIRT     := Color(0.46, 0.36, 0.23)
const TILE_FLOOR    := Color(0.40, 0.34, 0.29)
const TILE_PAVEMENT := Color(0.36, 0.37, 0.41)

# ── Zone building palettes ────────────────────────────────────────────────────
# Each zone maps to [wall_main, wall_shadow_face, roof]
const ZONE_PAL: Dictionary = {
	0: [Color(0.44, 0.44, 0.44), Color(0.54, 0.54, 0.54), Color(0.60, 0.60, 0.60)], # EMPTY
	1: [Color(0.30, 0.24, 0.16), Color(0.38, 0.30, 0.20), Color(0.44, 0.37, 0.24)], # FOREST
	2: [Color(0.48, 0.39, 0.28), Color(0.56, 0.47, 0.34), Color(0.64, 0.55, 0.40)], # RESIDENTIAL
	3: [Color(0.28, 0.34, 0.44), Color(0.36, 0.44, 0.54), Color(0.46, 0.52, 0.62)], # COMMERCIAL
	4: [Color(0.26, 0.26, 0.28), Color(0.33, 0.33, 0.36), Color(0.40, 0.40, 0.44)], # INDUSTRIAL
	5: [Color(0.42, 0.35, 0.24), Color(0.50, 0.43, 0.30), Color(0.56, 0.48, 0.33)], # RURAL
}

# ── Foliage ───────────────────────────────────────────────────────────────────
const FOLIAGE_LARGE  := Color(0.12, 0.20, 0.10)
const FOLIAGE_MEDIUM := Color(0.16, 0.26, 0.12)
const FOLIAGE_BUSH   := Color(0.20, 0.30, 0.14)
const BARK_BASE      := Color(0.28, 0.20, 0.11)

# ── Furniture ─────────────────────────────────────────────────────────────────
const FURN_WOOD_DARK  := Color(0.46, 0.34, 0.20)   # dark wood
const FURN_WOOD_SOFT  := Color(0.58, 0.46, 0.28)   # soft wood
const FURN_MATTRESS_T := Color(0.64, 0.60, 0.54)   # mattress top
const FURN_MATTRESS_S := Color(0.52, 0.48, 0.42)   # mattress side
const FURN_SOFA       := Color(0.30, 0.25, 0.36)   # sofa fabric
const FURN_SHELF      := Color(0.34, 0.26, 0.16)   # shelf board
const FURN_APPLIANCE  := Color(0.22, 0.20, 0.18)   # dark appliance
const FURN_COUNTER_T  := Color(0.44, 0.38, 0.28)   # counter top
const FURN_COUNTER_S  := Color(0.32, 0.26, 0.18)   # counter side
const FURN_APPLI_GREY := Color(0.26, 0.28, 0.30)   # appliance grey
const FURN_PALLET     := Color(0.44, 0.40, 0.30)   # pallet
const FURN_RUG        := Color(0.38, 0.22, 0.14)   # rug


# ── Helpers ───────────────────────────────────────────────────────────────────

## Return col shifted ±range_v (seeded so the same seed always gives same result).
static func vary(col: Color, seed: int, range_v: float) -> Color:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var shift: float = (rng.randf() - 0.5) * 2.0 * range_v
	return col.lightened(shift) if shift > 0.0 else col.darkened(-shift)


## Lerp col toward COLD_BLUE by amount (0–1).
static func cool_shadow(col: Color, amount: float) -> Color:
	return col.lerp(COLD_BLUE, clampf(amount, 0.0, 1.0))


## Lerp col toward WARM_LAMP by amount (0–1).
static func warm_highlight(col: Color, amount: float) -> Color:
	return col.lerp(WARM_LAMP, clampf(amount, 0.0, 1.0))


## Per-vertex gradient for an isometric diamond tile.
## Vertex order: top(N), right(E), bottom(S), left(W).
static func tile_gradient(col: Color) -> PackedColorArray:
	return PackedColorArray([
		col.lightened(0.09),         # top   — catches top-left moonlight
		col.darkened(0.02),          # right — slightly shadowed
		cool_shadow(col, 0.06).darkened(0.05),  # bottom — cool shadow
		cool_shadow(col, 0.04),      # left  — cool-tinted
	])
