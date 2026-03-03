class_name WorldCanopyLayer
extends Node2D

## Draws only the ELEVATED portions of foliage and tall props.
## This node is added to the scene AFTER Entities, so it renders above
## players/zombies — giving the "walking under a tree" depth effect.
##
## Tree crowns are simulated as 3-D spheres using stacked flat polygons:
##   1. Shadow underside  (cool-tinted dark triangle pointing south)
##   2. Main crown body   (full diamond — dominant mid-tone)
##   3. Lit upper half    (upper-right triangle — warm-highlighted)
##   4. Apex highlight    (small top triangle — brightest point)

const TILE_W: float = 64.0
const TILE_H: float = 32.0

# Foliage colours sourced from ArtPalette.
static var FOLIAGE_COLORS: Array[Color] = [
	ArtPalette.FOLIAGE_LARGE,   # large tree  — deep muted green
	ArtPalette.FOLIAGE_MEDIUM,  # medium tree
	ArtPalette.FOLIAGE_BUSH,    # bush        — lighter desaturated green
]

var _map_data: MapData = null


func setup_from_map_data(data: MapData) -> void:
	_map_data = data
	queue_redraw()


func _tile_to_local(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x - cell.y) * TILE_W * 0.5,
		(cell.x + cell.y) * TILE_H * 0.5
	)


## Small isometric box helper (mirrors WorldTileMap._draw_iso_box).
func _draw_iso_box(ctr: Vector2, s: float, h: float,
				   top_c: Color, left_c: Color, right_c: Color,
				   hw: float, hh: float) -> void:
	var gN := ctr + Vector2(  0.0,  -hh * s)
	var gE := ctr + Vector2( hw * s,   0.0)
	var gS := ctr + Vector2(  0.0,   hh * s)
	var gW := ctr + Vector2(-hw * s,   0.0)
	var up  := Vector2(0.0, -h)
	draw_colored_polygon(PackedVector2Array([gW, gS, gS + up, gW + up]), left_c)
	draw_colored_polygon(PackedVector2Array([gE, gS, gS + up, gE + up]), right_c)
	draw_colored_polygon(PackedVector2Array([gN + up, gE + up, gS + up, gW + up]), top_c)


func _draw() -> void:
	if _map_data == null:
		return
	var hw := TILE_W * 0.5
	var hh := TILE_H * 0.5

	# ── Foliage canopies ──────────────────────────────────────────────────────
	for entry in _map_data.foliage_cells:
		var pos   : Vector2i = entry["pos"]
		var ftype : int      = entry["type"]
		var cell             := pos + _map_data.origin_offset
		var ctr              := _tile_to_local(cell)
		var color : Color    = FOLIAGE_COLORS[clampi(ftype, 0, FOLIAGE_COLORS.size() - 1)]
		_draw_canopy(ctr, ftype, color, hw, hh)

	# ── Lamppost heads ────────────────────────────────────────────────────────
	for entry in _map_data.prop_cells:
		var ptype : int = entry["type"]
		if ptype != MapData.PROP_LAMPPOST:
			continue
		var pos  : Vector2i = entry["pos"]
		var cell            := pos + _map_data.origin_offset
		var ctr             := _tile_to_local(cell)
		_draw_lamppost_head(ctr, hw, hh)


func _draw_canopy(ctr: Vector2, ftype: int, color: Color, hw: float, hh: float) -> void:
	match ftype:

		# ── Large tree — 3D spherical crown ──────────────────────────────────
		0:
			var cx    := hw * 0.62
			var cy    := hh * 0.74
			var crown := ctr + Vector2(0.0, -22.0)

			# 1. Shadow underside — cool-tinted dark arc (SE-biased per top-left light)
			draw_colored_polygon(PackedVector2Array([
				crown + Vector2(-cx * 0.75,  0.0),
				crown + Vector2(  0.0,       cy * 0.88),
				crown + Vector2( cx * 0.75,  0.0),
			]), ArtPalette.cool_shadow(color, 0.30).darkened(0.40))

			# 2. Main crown body (full diamond)
			draw_colored_polygon(PackedVector2Array([
				crown + Vector2(  0.0,  -cy),
				crown + Vector2( cx,     0.0),
				crown + Vector2(  0.0,   cy),
				crown + Vector2(-cx,     0.0),
			]), color)

			# 3. Lit upper half — warm-highlighted, mimics top-left moonlight
			draw_colored_polygon(PackedVector2Array([
				crown + Vector2(  0.0,  -cy),
				crown + Vector2( cx,     0.0),
				crown + Vector2(  0.0,   0.0),
			]), ArtPalette.warm_highlight(color, 0.08).lightened(0.10))

			# 4. Apex highlight — small bright triangle at very top
			draw_colored_polygon(PackedVector2Array([
				crown + Vector2(  0.0,        -cy),
				crown + Vector2( cx * 0.52, -cy * 0.38),
				crown + Vector2(-cx * 0.52, -cy * 0.38),
			]), ArtPalette.warm_highlight(color, 0.12).lightened(0.24))

		# ── Medium tree ───────────────────────────────────────────────────────
		1:
			var cx    := hw * 0.48
			var cy    := hh * 0.60
			var crown := ctr + Vector2(0.0, -14.0)

			draw_colored_polygon(PackedVector2Array([
				crown + Vector2(-cx * 0.70,  0.0),
				crown + Vector2(  0.0,       cy * 0.82),
				crown + Vector2( cx * 0.70,  0.0),
			]), ArtPalette.cool_shadow(color, 0.26).darkened(0.34))

			draw_colored_polygon(PackedVector2Array([
				crown + Vector2(  0.0,  -cy),
				crown + Vector2( cx,     0.0),
				crown + Vector2(  0.0,   cy),
				crown + Vector2(-cx,     0.0),
			]), color)

			draw_colored_polygon(PackedVector2Array([
				crown + Vector2(  0.0,  -cy),
				crown + Vector2( cx,     0.0),
				crown + Vector2(  0.0,   0.0),
			]), ArtPalette.warm_highlight(color, 0.07).lightened(0.09))

			draw_colored_polygon(PackedVector2Array([
				crown + Vector2(  0.0,        -cy),
				crown + Vector2( cx * 0.50, -cy * 0.38),
				crown + Vector2(-cx * 0.50, -cy * 0.38),
			]), ArtPalette.warm_highlight(color, 0.12).lightened(0.20))

		# ── Bush — small rounded top ──────────────────────────────────────────
		2:
			var cx    := hw * 0.50
			var cy    := hh * 0.42
			var crown := ctr + Vector2(0.0, -6.0)

			draw_colored_polygon(PackedVector2Array([
				crown + Vector2(-cx * 0.65,  0.0),
				crown + Vector2(  0.0,       cy * 0.78),
				crown + Vector2( cx * 0.65,  0.0),
			]), ArtPalette.cool_shadow(color, 0.22).darkened(0.28))

			draw_colored_polygon(PackedVector2Array([
				crown + Vector2(  0.0,  -cy),
				crown + Vector2( cx,     0.0),
				crown + Vector2(  0.0,   cy),
				crown + Vector2(-cx,     0.0),
			]), color)

			draw_colored_polygon(PackedVector2Array([
				crown + Vector2(  0.0,  -cy),
				crown + Vector2( cx,     0.0),
				crown + Vector2(  0.0,   0.0),
			]), ArtPalette.warm_highlight(color, 0.06).lightened(0.08))


func _draw_lamppost_head(ctr: Vector2, hw: float, hh: float) -> void:
	var pole_top  := ctr + Vector2(0.0, -hh * 1.80)
	var housing_c := Color(0.36, 0.36, 0.34)

	# Horizontal arm extending east from pole tip
	draw_line(pole_top, pole_top + Vector2(hw * 0.22, -hh * 0.05),
			Color(0.38, 0.38, 0.36), 2.0)

	# Lamp housing — small isometric box at end of arm
	var arm_tip := pole_top + Vector2(hw * 0.22, -hh * 0.05)
	_draw_iso_box(arm_tip, 0.10, 4.0,
			housing_c.lightened(0.12), housing_c, housing_c.darkened(0.18), hw, hh)

	# Glow bulb — warm lamp colour from ArtPalette
	draw_circle(arm_tip + Vector2(0.0, -5.0), 3.8,
			Color(ArtPalette.WARM_LAMP.r, ArtPalette.WARM_LAMP.g, ArtPalette.WARM_LAMP.b, 0.94))
	# Soft halo (large, low alpha)
	draw_circle(arm_tip + Vector2(0.0, -5.0), 7.0,
			Color(ArtPalette.WARM_LAMP.r, ArtPalette.WARM_LAMP.g, ArtPalette.WARM_LAMP.b, 0.20))
