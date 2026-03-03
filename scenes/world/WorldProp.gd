@tool
class_name WorldProp
extends Node2D

## A single world prop rendered as an individual Node2D.
## Its `position` is set to the tile's world centre so it participates in
## the parent Entities node's y_sort_enabled sorting alongside players and
## zombies, giving correct isometric depth.

const TILE_W: float = 64.0
const TILE_H: float = 32.0

# Slightly desaturated car colours — vibrant enough to read, muted enough for art bible.
const CAR_COLORS := [
	Color(0.50, 0.12, 0.12),   # dark red
	Color(0.14, 0.20, 0.44),   # steel blue
	Color(0.68, 0.68, 0.66),   # silver
	Color(0.13, 0.13, 0.12),   # near-black
	Color(0.58, 0.50, 0.20),   # dusty gold
	Color(0.16, 0.30, 0.16),   # army green
]

## Set by World._spawn_props() before add_child().
var prop_type: int      = 0
var tile_pos:  Vector2i = Vector2i.ZERO


func _draw() -> void:
	var hw := TILE_W * 0.5
	var hh := TILE_H * 0.5
	_draw_prop(Vector2.ZERO, prop_type, tile_pos, hw, hh)


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


## Draw SE-offset elliptical ground shadow beneath a prop.
## shadow_hw/hh: shadow ellipse radii in screen pixels.
func _prop_shadow(ctr: Vector2, shadow_hw: float, shadow_hh: float,
				  opacity: float = 0.30) -> void:
	var shadow_col := ArtPalette.cool_shadow(ArtPalette.SHADOW_BASE, 0.65)
	shadow_col.a   = opacity
	# Offset SE to align with art bible top-left moonlight
	var ox := 4.0
	var oy := 6.0
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * float(i) / 10.0
		pts.append(Vector2(ox + cos(a) * shadow_hw, oy + sin(a) * shadow_hh))
	draw_colored_polygon(pts, shadow_col)


# ── Per-type drawing ──────────────────────────────────────────────────────────
func _draw_prop(ctr: Vector2, ptype: int, tpos: Vector2i, hw: float, hh: float) -> void:
	match ptype:

		MapData.PROP_TRASH_CAN:
			_prop_shadow(ctr, hw * 0.20, hh * 0.14, 0.28)
			var c := Color(0.22, 0.24, 0.20)
			_iso_box(ctr, 0.15, 10.0,
					c.lightened(0.08), c, ArtPalette.cool_shadow(c, 0.12).darkened(0.18), hw, hh)
			draw_line(
					ctr + Vector2(-hw * 0.15, -10.0),
					ctr + Vector2( hw * 0.15, -10.0),
					c.lightened(0.24), 1.0)

		MapData.PROP_DUMPSTER:
			_prop_shadow(ctr, hw * 0.44, hh * 0.22, 0.30)
			var c   := Color(0.13, 0.25, 0.13)
			var s_d := 0.38
			var h_d := 16.0
			_iso_box(ctr, s_d, h_d,
					c.lightened(0.06), c.lightened(0.04), ArtPalette.cool_shadow(c, 0.14).darkened(0.20), hw, hh)
			draw_line(
					ctr + Vector2(  0.0,     -hh * s_d - h_d),
					ctr + Vector2( hw * s_d,             -h_d),
					c.lightened(0.30), 1.5)
			var rib_h := h_d * 0.40
			draw_line(
					ctr + Vector2( hw * s_d, -rib_h),
					ctr + Vector2(  0.0,  hh * s_d - rib_h),
					c.darkened(0.30), 1.0)

		MapData.PROP_MAILBOX:
			_prop_shadow(ctr, hw * 0.18, hh * 0.12, 0.24)
			draw_line(
					ctr + Vector2(0.0,  hh * 0.28),
					ctr + Vector2(0.0, -hh * 0.06),
					Color(0.42, 0.40, 0.36), 2.0)
			var post_top := ctr + Vector2(0.0, -hh * 0.06)
			var mb := Color(0.18, 0.22, 0.50)
			_iso_box(post_top, 0.15, 8.0,
					mb.lightened(0.10), mb, ArtPalette.cool_shadow(mb, 0.12).darkened(0.20), hw, hh)
			draw_line(
					post_top + Vector2(hw * 0.15, -4.0),
					post_top + Vector2(hw * 0.24, -9.0),
					Color(0.68, 0.14, 0.14), 1.5)

		MapData.PROP_CAR:
			var hash_idx := (tpos.x * 7 + tpos.y * 13) % CAR_COLORS.size()
			var body_c: Color = CAR_COLORS[absi(hash_idx)]

			# Ground shadow — wide ellipse under car.
			_prop_shadow(ctr, hw * 0.60, hh * 0.26, 0.35)

			# ── Body ──
			var body_s := 0.52   # slightly narrower than before
			var body_h := 6.0    # lower profile
			var gN_b := ctr + Vector2(0.0,           -hh * body_s)
			var gE_b := ctr + Vector2( hw * body_s,   0.0)
			var gS_b := ctr + Vector2(0.0,            hh * body_s)
			var gW_b := ctr + Vector2(-hw * body_s,   0.0)
			var up_b := Vector2(0.0, -body_h)
			_iso_box(ctr, body_s, body_h,
					body_c.lightened(0.05), body_c,
					ArtPalette.cool_shadow(body_c, 0.10).darkened(0.24), hw, hh)

			# Body outlines — dark perimeter on visible faces.
			var ol_c := body_c.darkened(0.55)
			ol_c.a   = 0.80
			draw_polyline(PackedVector2Array([
				gN_b + up_b, gW_b + up_b, gS_b + up_b, gE_b + up_b, gN_b + up_b,
			]), ol_c, 1.5, true)
			draw_line(gW_b, gW_b + up_b, ol_c, 1.2)
			draw_line(gS_b, gS_b + up_b, ol_c, 1.0)
			draw_line(gE_b, gE_b + up_b, ol_c, 1.2)

			# ── Hood wedge on NE face ──
			draw_colored_polygon(PackedVector2Array([
				gN_b, gN_b + Vector2(0.0, -4.0), gE_b + Vector2(0.0, -1.5), gE_b,
			]), body_c.darkened(0.08))
			draw_colored_polygon(PackedVector2Array([
				gN_b + Vector2(0.0, -4.0), gE_b + Vector2(0.0, -1.5),
				gE_b + Vector2(0.0, -1.5) + Vector2(0.0, 1.5), gN_b,
			]), body_c.darkened(0.20))

			# ── Cabin ──
			var cab   := ctr + Vector2(-hw * 0.04, -body_h)
			var cab_s := 0.32   # wider cabin
			var cab_h := 8.0
			_iso_box(cab, cab_s, cab_h,
					body_c.darkened(0.16), body_c.darkened(0.10),
					ArtPalette.cool_shadow(body_c, 0.15).darkened(0.32), hw, hh)

			# Cabin outlines.
			var cab_ol := body_c.darkened(0.60)
			cab_ol.a   = 0.75
			var gN_c := cab + Vector2(0.0,          -hh * cab_s)
			var gE_c := cab + Vector2( hw * cab_s,   0.0)
			var gS_c := cab + Vector2(0.0,           hh * cab_s)
			var gW_c := cab + Vector2(-hw * cab_s,   0.0)
			var up_c := Vector2(0.0, -cab_h)
			draw_polyline(PackedVector2Array([
				gN_c + up_c, gW_c + up_c, gS_c + up_c, gE_c + up_c, gN_c + up_c,
			]), cab_ol, 1.2, true)
			draw_line(gW_c, gW_c + up_c, cab_ol, 1.0)
			draw_line(gE_c, gE_c + up_c, cab_ol, 1.0)

			# ── Windshield glass ──
			draw_colored_polygon(PackedVector2Array([
				cab + Vector2( hw * cab_s,          0.0),
				cab + Vector2(   0.0,      hh * cab_s),
				cab + Vector2(   0.0,      hh * cab_s - cab_h),
				cab + Vector2( hw * cab_s,         -cab_h),
			]), Color(0.40, 0.60, 0.72, 0.52))

			# ── Wheels — 4 flat ellipses at wheel-well positions ──
			var wc   := Color(0.15, 0.14, 0.14)       # dark tyre
			var wrim := Color(0.35, 0.34, 0.33)        # rim highlight
			var wr_x := hw * 0.16    # ellipse x-radius
			var wr_y := hh * 0.16    # ellipse y-radius
			# Front-left (NW area), Front-right (NE area),
			# Rear-left (SW area),  Rear-right (SE area).
			var wheel_ctrs: Array[Vector2] = [
				ctr + Vector2(-hw * 0.36, -hh * 0.18),   # front-left
				ctr + Vector2( hw * 0.36, -hh * 0.18),   # front-right
				ctr + Vector2(-hw * 0.30,  hh * 0.28),   # rear-left
				ctr + Vector2( hw * 0.30,  hh * 0.28),   # rear-right
			]
			for wpos: Vector2 in wheel_ctrs:
				draw_colored_polygon(IsoShapes.ellipse_pts(wpos, wr_x, wr_y, 10), wc)
				draw_colored_polygon(IsoShapes.ellipse_pts(wpos, wr_x * 0.55, wr_y * 0.55, 10), wrim)

			# ── Headlights / Taillights ──
			var hl_y := -1.5
			draw_circle(ctr + Vector2( hw * 0.46,  hh * 0.08 + hl_y), 2.2,
					Color(ArtPalette.WARM_LAMP.r, ArtPalette.WARM_LAMP.g, ArtPalette.WARM_LAMP.b, 0.92))
			draw_circle(ctr + Vector2( hw * 0.22,  hh * 0.44 + hl_y), 2.2,
					Color(ArtPalette.WARM_LAMP.r, ArtPalette.WARM_LAMP.g, ArtPalette.WARM_LAMP.b, 0.92))
			draw_circle(ctr + Vector2(-hw * 0.44,  hh * 0.10 + hl_y), 2.0, Color(0.80, 0.10, 0.10, 0.90))
			draw_circle(ctr + Vector2(-hw * 0.22,  hh * 0.44 + hl_y), 2.0, Color(0.80, 0.10, 0.10, 0.90))

			# ── Rust/damage overlay (20% of cars, seeded) ──
			var rust_rng := RandomNumberGenerator.new()
			rust_rng.seed = tpos.x * 3571 + tpos.y * 5413
			if rust_rng.randf() < 0.20:
				# 2–3 rust blobs on the body.
				var n_blobs := rust_rng.randi_range(2, 3)
				for _i in n_blobs:
					var bx := (rust_rng.randf() - 0.5) * hw * body_s * 1.4
					var by := (rust_rng.randf() - 0.5) * hh * body_s * 0.8 - 3.0
					var br := rust_rng.randf_range(2.5, 5.5)
					var rust_col := Color(0.40, 0.18, 0.05,
							rust_rng.randf_range(0.30, 0.50))
					draw_circle(ctr + Vector2(bx, by), br, rust_col)
			# 10% chance broken windshield (independent seed).
			rust_rng.seed = tpos.x * 2311 + tpos.y * 4007
			if rust_rng.randf() < 0.10:
				var wc2 := Color(0.30, 0.44, 0.52, 0.60)
				draw_colored_polygon(PackedVector2Array([
					cab + Vector2( hw * cab_s,          0.0),
					cab + Vector2(   0.0,      hh * cab_s),
					cab + Vector2(   0.0,      hh * cab_s - cab_h),
					cab + Vector2( hw * cab_s,         -cab_h),
				]), wc2)
				# Crack lines.
				var mid_c := cab + Vector2(hw * cab_s * 0.5, hh * cab_s * 0.5 - cab_h * 0.5)
				draw_line(mid_c, mid_c + Vector2(-hw * 0.20,  hh * 0.22), Color(0.16, 0.20, 0.26, 0.80), 1.0)
				draw_line(mid_c, mid_c + Vector2( hw * 0.14, -hh * 0.30), Color(0.16, 0.20, 0.26, 0.80), 1.0)

		MapData.PROP_LAMPPOST:
			# Warm ground light pool below the lamp (atmosphere)
			var pool_col := Color(ArtPalette.WARM_LAMP.r, ArtPalette.WARM_LAMP.g,
								  ArtPalette.WARM_LAMP.b, 0.06)
			var pool_pts := PackedVector2Array()
			for i in 14:
				var a := TAU * float(i) / 14.0
				pool_pts.append(Vector2(cos(a) * hw * 0.90, sin(a) * hh * 0.55))
			draw_colored_polygon(pool_pts, pool_col)
			# Pole (y-sorted with player so it occludes correctly)
			draw_line(
					ctr + Vector2(0.0,  hh * 0.20),
					ctr + Vector2(0.0, -hh * 1.80),
					Color(0.38, 0.38, 0.36), 2.5)
			# Arm + head above player handled by WorldCanopyLayer.

		MapData.PROP_CRATE:
			_prop_shadow(ctr, hw * 0.32, hh * 0.18, 0.28)
			var w   := ArtPalette.FURN_WOOD_SOFT
			var s_c := 0.28
			var h_c := 10.0
			_iso_box(ctr, s_c, h_c,
					ArtPalette.warm_highlight(w, 0.06).lightened(0.06),
					w, ArtPalette.cool_shadow(w, 0.14).darkened(0.18), hw, hh)
			draw_line(ctr + Vector2(  0.0, -hh * s_c - h_c),
					  ctr + Vector2(  0.0,  hh * s_c - h_c), w.darkened(0.28), 1.0)
			draw_line(ctr + Vector2(-hw * s_c, -h_c),
					  ctr + Vector2( hw * s_c, -h_c), w.darkened(0.28), 1.0)
			draw_line(ctr + Vector2(-hw * s_c,  0.0),
					  ctr + Vector2(-hw * s_c, -h_c), w.darkened(0.32), 0.8)
			draw_line(ctr + Vector2(  0.0,  hh * s_c),
					  ctr + Vector2(  0.0,  hh * s_c - h_c), w.darkened(0.32), 0.8)

		MapData.PROP_BARREL:
			_prop_shadow(ctr, hw * 0.22, hh * 0.14, 0.26)
			var b   := ArtPalette.DUSTY_BROWN.darkened(0.30)
			var s_b := 0.17
			var h_b := 15.0
			_iso_box(ctr, s_b, h_b,
					ArtPalette.warm_highlight(b, 0.04).lightened(0.04),
					b, ArtPalette.cool_shadow(b, 0.14).darkened(0.14), hw, hh)
			var band_c := Color(0.46, 0.38, 0.18)
			var band_y := h_b * 0.42
			draw_line(ctr + Vector2( hw * s_b,        -band_y),
					  ctr + Vector2(  0.0,   hh * s_b - band_y), band_c, 1.5)
			draw_line(ctr + Vector2(-hw * s_b,        -band_y),
					  ctr + Vector2(  0.0,   hh * s_b - band_y), band_c, 1.5)
			draw_line(ctr + Vector2(-hw * s_b, -h_b),
					  ctr + Vector2( hw * s_b, -h_b), band_c, 1.0)

		MapData.PROP_FIRE_HYDRANT:
			_prop_shadow(ctr, hw * 0.22, hh * 0.14, 0.26)
			var red  := Color(0.74, 0.10, 0.08)
			var iron := Color(0.20, 0.20, 0.22)
			_iso_box(ctr, 0.18, 3.0,
					iron.lightened(0.06), iron, iron.lightened(0.03), hw, hh)
			_iso_box(ctr + Vector2(0.0, -3.0), 0.12, 9.0,
					ArtPalette.warm_highlight(red, 0.06).lightened(0.10),
					red.darkened(0.10),
					ArtPalette.cool_shadow(red, 0.12).darkened(0.08), hw, hh)
			_iso_box(ctr + Vector2(0.0, -12.0), 0.14, 2.5,
					iron.lightened(0.08), iron, iron.lightened(0.04), hw, hh)
			_iso_box(ctr + Vector2(0.0, -14.5), 0.09, 5.0,
					iron.lightened(0.10), iron, iron.lightened(0.06), hw, hh)
			_iso_box(ctr + Vector2(-hw * 0.13, -7.0), 0.045, 3.0,
					iron.lightened(0.06), iron.darkened(0.08), iron, hw, hh)
			_iso_box(ctr + Vector2( hw * 0.13, -7.0), 0.045, 3.0,
					iron.lightened(0.06), iron.darkened(0.08), iron, hw, hh)
