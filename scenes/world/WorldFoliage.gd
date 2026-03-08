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
	# Seeded bark color variation per tree instance.
	var seed   := tile_pos.x * 3571 + tile_pos.y * 6271
	var bark   := ArtPalette.vary(ArtPalette.BARK_BASE, seed, 0.06)
	var bark_t := ArtPalette.warm_highlight(bark, 0.06).lightened(0.06)
	var bark_l := bark
	var bark_r := ArtPalette.cool_shadow(bark, 0.16).darkened(0.14)
	var shadow_col := ArtPalette.cool_shadow(ArtPalette.SHADOW_BASE, 0.60)

	match ft:

		0:  # Large tree — SE-offset shadow + 3D trunk + root flare + bark lines.
			draw_colored_polygon(PackedVector2Array([
				ctr + Vector2(  4.0,       -hh * 0.13),
				ctr + Vector2( hw * 0.34,   hh * 0.08),
				ctr + Vector2(  4.0,        hh * 0.26),
				ctr + Vector2(-hw * 0.28,   hh * 0.08),
			]), Color(shadow_col.r, shadow_col.g, shadow_col.b, 0.46))
			# Root flare: tapered ridges radiating from trunk base
			var flare_dirs := [
				Vector2( hw * 0.15,  hh * 0.07),
				Vector2( hw * 0.09,  hh * 0.14),
				Vector2(-hw * 0.02,  hh * 0.11),
			]
			for fd: Vector2 in flare_dirs:
				draw_line(ctr, ctr + fd, bark.darkened(0.18), 3.5)
				draw_line(ctr, ctr + fd * 0.65, bark.darkened(0.05), 5.5)
			_iso_box(ctr, 0.09, 22.0, bark_t, bark_l, bark_r, hw, hh)
			# Bark strokes on W face
			var gW_l := ctr + Vector2(-hw * 0.09, 0.0)
			var gS_l := ctr + Vector2(0.0, hh * 0.09)
			for bi in 2:
				var bot := lerp(gW_l, gS_l, float(bi + 1) / 3.0)
				draw_line(bot, bot + Vector2(0.0, -22.0),
					Color(bark.darkened(0.24), 0.62), 0.8)

		1:  # Medium tree — SE-offset shadow + shorter trunk + root flare + bark lines.
			draw_colored_polygon(PackedVector2Array([
				ctr + Vector2(  3.0,       -hh * 0.10),
				ctr + Vector2( hw * 0.25,   hh * 0.05),
				ctr + Vector2(  3.0,        hh * 0.18),
				ctr + Vector2(-hw * 0.20,   hh * 0.05),
			]), Color(shadow_col.r, shadow_col.g, shadow_col.b, 0.40))
			var flare_dirs_m := [
				Vector2( hw * 0.11,  hh * 0.06),
				Vector2(-hw * 0.02,  hh * 0.09),
			]
			for fd: Vector2 in flare_dirs_m:
				draw_line(ctr, ctr + fd, bark.darkened(0.16), 2.8)
				draw_line(ctr, ctr + fd * 0.65, bark.darkened(0.04), 4.0)
			_iso_box(ctr, 0.07, 14.0, bark_t, bark_l, bark_r, hw, hh)
			var gW_m := ctr + Vector2(-hw * 0.07, 0.0)
			var gS_m := ctr + Vector2(0.0, hh * 0.07)
			var bot_m := lerp(gW_m, gS_m, 0.50)
			draw_line(bot_m, bot_m + Vector2(0.0, -14.0),
				Color(bark.darkened(0.22), 0.58), 0.7)

		2:  # Bush — multi-lobe shadow base (crown in WorldCanopyLayer).
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = seed + 1337
			var bs := 0.88 + rng2.randf_range(0.0, 0.24)  # seeded size scale
			# Multi-lobe shadow ellipses simulating clumping
			var lobe_col := ArtPalette.cool_shadow(color, 0.30).darkened(0.28)
			for lo: Vector2 in [
				Vector2( hw * 0.10 * bs,  hh * 0.05 * bs),
				Vector2(-hw * 0.08 * bs,  hh * 0.08 * bs),
				Vector2( 0.0,             0.0),
			]:
				var lc  := ctr + lo + Vector2(3.5, 5.0)
				var lrh := hw * 0.28 * bs;  var lrv := hh * 0.18 * bs
				var lpts := PackedVector2Array()
				for i in 10:
					var a := TAU * float(i) / 10.0
					lpts.append(lc + Vector2(cos(a)*lrh, sin(a)*lrv))
				draw_colored_polygon(lpts,
					Color(lobe_col.r, lobe_col.g, lobe_col.b, 0.34))
