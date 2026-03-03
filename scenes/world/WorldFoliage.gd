class_name WorldFoliage
extends Node2D

## A single foliage cell (tree trunk / bush base) rendered as an individual Node2D.
## Its `position` is set to the tile's world centre so it participates in
## the parent Entities node's y_sort_enabled sorting alongside players and zombies,
## giving correct isometric depth (player behind trunk = tree occludes player).

const TILE_W: float = 64.0
const TILE_H: float = 32.0

# Foliage colours sourced from ArtPalette.
static var FOLIAGE_COLORS: Array[Color] = [
	ArtPalette.FOLIAGE_LARGE,   # large tree — deep muted green
	ArtPalette.FOLIAGE_MEDIUM,  # medium tree
	ArtPalette.FOLIAGE_BUSH,    # bush — lighter desaturated green
]

## Set by World._spawn_props() before add_child().
var ftype:    int      = 0
var tile_pos: Vector2i = Vector2i.ZERO


func _draw() -> void:
	var hw    := TILE_W * 0.5
	var hh    := TILE_H * 0.5
	var color: Color = FOLIAGE_COLORS[clampi(ftype, 0, FOLIAGE_COLORS.size() - 1)]
	_draw_foliage_base(Vector2.ZERO, ftype, color, hw, hh)


# ── Isometric box primitive ───────────────────────────────────────────────────
func _iso_box(ctr: Vector2, s: float, h: float,
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


# ── Per-type trunk/base drawing ───────────────────────────────────────────────
func _draw_foliage_base(ctr: Vector2, ft: int, color: Color, hw: float, hh: float) -> void:
	# Bark from ArtPalette — cool shadow on right face, warm highlight on top.
	var bark   := ArtPalette.BARK_BASE
	var bark_t := ArtPalette.warm_highlight(bark, 0.06).lightened(0.06)
	var bark_l := bark
	var bark_r := ArtPalette.cool_shadow(bark, 0.16).darkened(0.14)
	# SE-biased shadow colour (top-left light source per art bible §2.2)
	var shadow_col := ArtPalette.cool_shadow(ArtPalette.SHADOW_BASE, 0.60)

	match ft:

		0:  # Large tree — SE-offset ground shadow + 3D trunk.
			# Shadow offset southeast to match top-left moonlight
			draw_colored_polygon(PackedVector2Array([
				ctr + Vector2(  4.0,       -hh * 0.13),
				ctr + Vector2( hw * 0.34,   hh * 0.08),
				ctr + Vector2(  4.0,        hh * 0.26),
				ctr + Vector2(-hw * 0.28,   hh * 0.08),
			]), Color(shadow_col.r, shadow_col.g, shadow_col.b, 0.46))
			_iso_box(ctr, 0.09, 22.0, bark_t, bark_l, bark_r, hw, hh)

		1:  # Medium tree — SE-offset shadow + shorter trunk.
			draw_colored_polygon(PackedVector2Array([
				ctr + Vector2(  3.0,       -hh * 0.10),
				ctr + Vector2( hw * 0.25,   hh * 0.05),
				ctr + Vector2(  3.0,        hh * 0.18),
				ctr + Vector2(-hw * 0.20,   hh * 0.05),
			]), Color(shadow_col.r, shadow_col.g, shadow_col.b, 0.40))
			_iso_box(ctr, 0.07, 14.0, bark_t, bark_l, bark_r, hw, hh)

		2:  # Bush — low SE-offset ground shadow only (crown in WorldCanopyLayer).
			draw_colored_polygon(PackedVector2Array([
				ctr + Vector2(  4.0,       -hh * 0.16),
				ctr + Vector2( hw * 0.48,   hh * 0.10),
				ctr + Vector2(  4.0,        hh * 0.30),
				ctr + Vector2(-hw * 0.40,   hh * 0.10),
			]), ArtPalette.cool_shadow(color, 0.30).darkened(0.28))
