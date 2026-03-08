## FurnitureBaker — bakes procedural furniture pieces into ImageTextures via SubViewport.
## Each unique (sn, se, h, top_c, side_c, rot, type) combination is baked once at startup,
## then served as Sprite2D nodes by ProceduralBuilding._fb() / _fn().
##
## Usage in World._ready():
##   await FurnitureBaker.warm_batch(
##       FurnitureLibrary.get_box_specs(), FurnitureLibrary.get_flat_specs())
##   _generate_map()

extends Node

## Reference coordinate system — calibrated for a 4×4-tile building.
## BAKE_NV / BAKE_EV match the nv/ev vectors that ProceduralBuilding.setup()
## computes for a 4×4 tile footprint (TILE_W=64, TILE_H=32).
const BAKE_W  : int     = 320
const BAKE_H  : int     = 256
## Pixel in the baked texture that corresponds to the furniture's floor-contact point.
const BAKE_FC : Vector2 = Vector2(160.0, 200.0)
const BAKE_NV : Vector2 = Vector2(0.0,  -16.0)   # north axis (1-tile half-extent = TILE_H*0.5)
const BAKE_EV : Vector2 = Vector2(32.0,   0.0)   # east axis  (1-tile E vertex = TILE_W*0.5, purely horizontal)

## key → ImageTexture
var _cache : Dictionary = {}


# ── Key generation ──────────────────────────────────────────────────────────────

func box_key(sn: float, se: float, h: float, tc: Color, sc: Color, rot: int = 0) -> String:
	return "b_%.3f_%.3f_%.1f_%s_%s_r%d" % [sn, se, h, tc.to_html(false), sc.to_html(false), rot]

func flat_key(sn: float, se: float, col: Color) -> String:
	return "f_%.3f_%.3f_%s" % [sn, se, col.to_html(true)]


# ── Public API ──────────────────────────────────────────────────────────────────

func has_texture(key: String) -> bool:
	return _cache.has(key)

func get_texture(key: String) -> ImageTexture:
	return _cache.get(key) as ImageTexture

## Returns a Sprite2D that places the BAKE_FC pixel at local_c with no rotation.
func make_sprite(key: String, nv: Vector2, ev: Vector2, local_c: Vector2, rot: int = 0) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture        = _cache[key]
	spr.centered       = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.transform = Transform2D(
		Vector2(1.0, 0.0), Vector2(0.0, 1.0),
		local_c - Vector2(BAKE_FC.x, BAKE_FC.y))
	return spr


## Bakes all unique specs into cached ImageTextures.
## Box spec format: Dictionary with keys sn, se, h, top_c, side_c,
##   optional rots (Array, default [0]), optional type (String, default "generic").
## Flat spec format still uses Array [sn, se, col] for backward compat.
func warm_batch(box_specs: Array, flat_specs: Array) -> void:
	var pairs : Array = []

	for spec in box_specs:
		var sn    : float  = spec["sn"]
		var se    : float  = spec["se"]
		var h     : float  = spec["h"]
		var top_c : Color  = spec["top_c"]
		var side_c: Color  = spec["side_c"]
		var rots  : Array  = spec.get("rots", [0])
		var type  : String = spec.get("type", "generic")
		for rot in rots:
			var key := box_key(sn, se, h, top_c, side_c, rot)
			if _cache.has(key):
				continue
			var vp   := _make_viewport()
			var root := Node2D.new()
			vp.add_child(root)
			_bake_box_into(root, sn, se, h, top_c, side_c, rot, type)
			add_child(vp)
			pairs.append({ "key": key, "vp": vp })

	for spec in flat_specs:
		var key := flat_key(spec[0], spec[1], spec[2])
		if _cache.has(key):
			continue
		var vp   := _make_viewport()
		var root := Node2D.new()
		vp.add_child(root)
		_bake_flat_into(root, spec[0], spec[1], spec[2])
		add_child(vp)
		pairs.append({ "key": key, "vp": vp })

	if pairs.is_empty():
		return

	# Wait two process frames so UPDATE_ONCE SubViewports complete their render pass.
	await get_tree().process_frame
	await get_tree().process_frame

	# Store the ViewportTexture directly — gl_compatibility's get_image() strips the
	# alpha channel (returns RGB8), but ViewportTexture retains it natively.
	# SubViewports are kept alive as children; UPDATE_ONCE means zero GPU cost
	# after the first render. Memory cost ≈ 46 × 320×256 × 4 bytes ≈ 15 MB.
	for p in pairs:
		var vp : SubViewport = p["vp"]
		_cache[p["key"]] = vp.get_texture()


# ── Internal helpers ────────────────────────────────────────────────────────────

func _make_viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.size                      = Vector2i(BAKE_W, BAKE_H)
	vp.transparent_bg            = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	return vp


## Adds a closed Line2D outline around a convex polygon.
func _add_outline(target: Node2D, pts: Array, col: Color, width: float) -> void:
	var ol := Line2D.new()
	ol.default_color = col
	ol.width         = width
	ol.closed        = true
	for p in pts:
		ol.add_point(p)
	target.add_child(ol)


func _make_poly(pts: Array, col: Color) -> Polygon2D:
	var p   := Polygon2D.new()
	p.polygon = PackedVector2Array(pts)
	p.color   = col
	return p


## Interpolate a point on a diamond face.
## t=0→N tip, t=1→S tip; side=0.0→left edge (N→W→S), side=1.0→right edge (N→E→S).
func _top_lerp(pN: Vector2, pW: Vector2, pS: Vector2, pE: Vector2,
		t: float, side: float) -> Vector2:
	var lp: Vector2
	var rp: Vector2
	if t <= 0.5:
		var u := t * 2.0
		lp = lerp(pN, pW, u)
		rp = lerp(pN, pE, u)
	else:
		var u := (t - 0.5) * 2.0
		lp = lerp(pW, pS, u)
		rp = lerp(pE, pS, u)
	return lerp(lp, rp, side)


## Draw a simple iso box on target: 3 faces + outlines.
## Used for sub-components (headboard, arms, shelf boards, etc.)
## No shadow/AO/grain — those are handled by the full generic pass.
func _bake_sub_box(target: Node2D, center: Vector2, dn: Vector2, de: Vector2,
		h: float, top_c: Color, side_c: Color) -> void:
	var up := Vector2(0.0, -h)
	var gN := center + dn
	var gE := center + de
	var gS := center - dn
	var gW := center - de
	var ol_c := ArtPalette.cool_shadow(side_c, 0.55).darkened(0.35)
	ol_c.a   = 0.85
	target.add_child(_make_poly([gW, gS, gS+up, gW+up], side_c))
	target.add_child(_make_poly([gE, gS, gS+up, gE+up],
		ArtPalette.cool_shadow(side_c, 0.20).darkened(0.28)))
	target.add_child(_make_poly([gN+up, gE+up, gS+up, gW+up],
		ArtPalette.warm_highlight(top_c, 0.06).lightened(0.15)))
	_add_outline(target, [gW, gS, gS+up, gW+up], ol_c, 1.2)
	_add_outline(target, [gE, gS, gS+up, gE+up], ol_c, 1.2)
	_add_outline(target, [gN+up, gE+up, gS+up, gW+up], ol_c, 1.0)


# ── Top-level bake dispatcher ─────────────────────────────────────────────────

## Dispatches to a per-type bake function.
## rot (0–3): 90° CW increments — re-binds which faces appear as lit W / dark E.
func _bake_box_into(target: Node2D,
		sn: float, se: float, h: float,
		top_c: Color, side_c: Color, rot: int = 0,
		type: String = "generic") -> void:
	var c  := BAKE_FC
	var dn: Vector2
	var de: Vector2
	match rot:
		1:
			# "east" axis = map(0,+1) = screen(−32,+16)
			# se ≤ 1: tile S-diamond vertex (0, 16*se)
			# se > 1: first tile vertex + (se-1) full isometric S-steps
			dn = BAKE_EV * sn
			de = (Vector2(-BAKE_EV.x * (se - 1.0), -BAKE_NV.y * se)
				if se > 1.0
				else Vector2(0.0, -BAKE_NV.y) * se)
		2:
			# "east" axis = map(−1,0) = screen(−32,−16)
			dn = -BAKE_NV * sn
			de = (Vector2(-BAKE_EV.x * se, BAKE_NV.y * (se - 1.0))
				if se > 1.0
				else -BAKE_EV * se)
		3:
			# "east" axis = map(0,−1) = screen(+32,−16)
			dn = -BAKE_EV * sn
			de = (Vector2(BAKE_EV.x * (se - 1.0), BAKE_NV.y * se)
				if se > 1.0
				else Vector2(0.0, BAKE_NV.y) * se)
		_:  # rot=0 — "east" axis = map(+1,0) = screen(+32,+16)
			# se ≤ 1: tile E-diamond vertex (32*se, 0) — correct, no y offset
			# se > 1: tile E-vertex + (se-1) full isometric E-steps adds y
			dn = BAKE_NV * sn
			de = (Vector2(BAKE_EV.x * se, -BAKE_NV.y * (se - 1.0))
				if se > 1.0
				else BAKE_EV * se)

	match type:
		"bed":      _bake_bed_into(target, c, dn, de, h, top_c, side_c)
		"sofa":     _bake_sofa_into(target, c, dn, de, h, top_c, side_c)
		"shelf":    _bake_shelf_into(target, c, dn, de, h, top_c, side_c)
		"counter":  _bake_counter_into(target, c, dn, de, h, top_c, side_c)
		"wardrobe": _bake_wardrobe_into(target, c, dn, de, h, top_c, side_c)
		"chair":    _bake_chair_into(target, c, dn, de, h, top_c, side_c)
		"stove":    _bake_stove_into(target, c, dn, de, h, top_c, side_c)
		"filing":   _bake_filing_into(target, c, dn, de, h, top_c, side_c)
		"fridge":   _bake_fridge_into(target, c, dn, de, h, top_c, side_c)
		"dresser":  _bake_dresser_into(target, c, dn, de, h, top_c, side_c)
		"bathtub":  _bake_bathtub_into(target, c, dn, de, h, top_c, side_c)
		_:          _bake_generic_into(target, c, dn, de, h, top_c, side_c)


# ── Generic furniture box ─────────────────────────────────────────────────────
## Design bible §1–§9: NW-light value separation, surface grain, rim highlights, AO base.

func _bake_generic_into(target: Node2D, c: Vector2, dn: Vector2, de: Vector2,
		h: float, top_c: Color, side_c: Color) -> void:
	var up := Vector2(0.0, -h)
	var gN := c + dn
	var gE := c + de
	var gS := c - dn
	var gW := c - de

	var outline_col := ArtPalette.cool_shadow(side_c, 0.55).darkened(0.35)
	outline_col.a   = 0.85

	# ── 1. Contact shadow ─────────────────────────────────────────────────
	var sh_col := ArtPalette.cool_shadow(ArtPalette.SHADOW_BASE, 0.65)
	sh_col.a   = 0.28
	var sh_pts : Array[Vector2] = []
	var sh_rh  := max(5.0, de.length() * 0.55)
	var sh_rv  := max(2.5, dn.length() * 0.28)
	for i in 10:
		var a := TAU * float(i) / 10.0
		sh_pts.append(c + Vector2(3.0, 5.0) + Vector2(cos(a) * sh_rh, sin(a) * sh_rv))
	target.add_child(_make_poly(sh_pts, sh_col))

	# ── 2. AO base — darken floor-contact edges ────────────────────────────
	var ao_col := ArtPalette.cool_shadow(side_c, 0.40)
	ao_col.a = 0.38
	var ao_w := Line2D.new()
	ao_w.default_color = ao_col;  ao_w.width = 2.5
	ao_w.add_point(gW);  ao_w.add_point(gS)
	target.add_child(ao_w)
	var ao_e := Line2D.new()
	ao_e.default_color = ao_col;  ao_e.width = 2.5
	ao_e.add_point(gE);  ao_e.add_point(gS)
	target.add_child(ao_e)

	# ── 3. W face — lit side ──────────────────────────────────────────────
	target.add_child(_make_poly([gW, gS, gS + up, gW + up], side_c))
	var wg_n := max(1, int(de.length() / 10.0))
	for i in range(1, wg_n + 1):
		var t  := float(i) / float(wg_n + 1)
		var wg := Line2D.new()
		wg.default_color = Color(side_c.darkened(0.05 + 0.04 * float(i % 2)), 0.22)
		wg.width = 1.0
		wg.add_point(lerp(gW, gS, t))
		wg.add_point(lerp(gW + up, gS + up, t))
		target.add_child(wg)
	_add_outline(target, [gW, gS, gS + up, gW + up], outline_col, 1.2)

	# ── 4. E face — dark side ─────────────────────────────────────────────
	target.add_child(_make_poly(
			[gE, gS, gS + up, gE + up],
			ArtPalette.cool_shadow(side_c, 0.20).darkened(0.28)))
	_add_outline(target, [gE, gS, gS + up, gE + up], outline_col, 1.2)

	# ── 5. Top face — warm highlight + cross-grain ────────────────────────
	var lit_top := ArtPalette.warm_highlight(top_c, 0.06).lightened(0.15)
	target.add_child(_make_poly([gN + up, gE + up, gS + up, gW + up], lit_top))
	var tg_n := max(1, int(dn.length() * 2.0 / 5.0))
	for i in range(1, tg_n + 1):
		var t  := float(i) / float(tg_n + 1)
		var tg := Line2D.new()
		tg.default_color = Color(lit_top.darkened(0.06 + 0.04 * float(i % 2)), 0.28)
		tg.width = 1.0
		tg.add_point(_top_lerp(gN + up, gW + up, gS + up, gE + up, t, 0.0))
		tg.add_point(_top_lerp(gN + up, gW + up, gS + up, gE + up, t, 1.0))
		target.add_child(tg)
	var top_ol := ArtPalette.cool_shadow(top_c, 0.40).darkened(0.25)
	top_ol.a = 0.70
	_add_outline(target, [gN + up, gE + up, gS + up, gW + up], top_ol, 1.0)

	# ── 6. Rim highlights ─────────────────────────────────────────────────
	var nw_rim := Line2D.new()
	nw_rim.default_color = ArtPalette.warm_highlight(top_c, 0.10).lightened(0.28)
	nw_rim.width = 1.0
	nw_rim.add_point(gN + up);  nw_rim.add_point(gW + up)
	target.add_child(nw_rim)
	var ne_rim := Line2D.new()
	ne_rim.default_color = ArtPalette.warm_highlight(top_c, 0.06).lightened(0.18)
	ne_rim.width = 1.0
	ne_rim.add_point(gN + up);  ne_rim.add_point(gE + up)
	target.add_child(ne_rim)
	var bevel := Line2D.new()
	bevel.default_color = ArtPalette.warm_highlight(top_c, 0.08).lightened(0.24)
	bevel.width = 1.0
	bevel.add_point(gS + up);  bevel.add_point(gW + up)
	target.add_child(bevel)


# ── Per-type baking functions ─────────────────────────────────────────────────

## BED: headboard + footboard + pillow + mattress seams + leg stubs.
## Custom draw order for correct isometric layering:
##   shadow → headboard (behind) → mattress → footboard (front) → pillow → legs.
func _bake_bed_into(target: Node2D, c: Vector2, dn: Vector2, de: Vector2,
		h: float, top_c: Color, side_c: Color) -> void:
	var up := Vector2(0.0, -h)
	var gN := c + dn;  var gE := c + de
	var gS := c - dn;  var gW := c - de

	# 1. Contact shadow
	var sh_col := ArtPalette.cool_shadow(ArtPalette.SHADOW_BASE, 0.65);  sh_col.a = 0.28
	var sh_pts : Array[Vector2] = []
	var sh_rh  := max(5.0, de.length() * 0.55);  var sh_rv := max(2.5, dn.length() * 0.28)
	for i in 10:
		var a := TAU * float(i) / 10.0
		sh_pts.append(c + Vector2(3.0, 5.0) + Vector2(cos(a)*sh_rh, sin(a)*sh_rv))
	target.add_child(_make_poly(sh_pts, sh_col))

	# 2. Headboard — dark wood, taller, N end (rendered BEHIND mattress)
	var wood := ArtPalette.FURN_WOOD_DARK
	_bake_sub_box(target, c + dn*0.65, dn*0.35, de, h*1.85,
		wood.lightened(0.07), wood)

	# 3. Mattress — full dims
	var ol_c := ArtPalette.cool_shadow(side_c, 0.55).darkened(0.35);  ol_c.a = 0.85
	var ao   := ArtPalette.cool_shadow(side_c, 0.40);  ao.a = 0.38
	var aow  := Line2D.new();  aow.default_color = ao;  aow.width = 2.5
	aow.add_point(gW);  aow.add_point(gS);  target.add_child(aow)
	var aoe  := Line2D.new();  aoe.default_color = ao;  aoe.width = 2.5
	aoe.add_point(gE);  aoe.add_point(gS);  target.add_child(aoe)
	target.add_child(_make_poly([gW, gS, gS+up, gW+up], side_c))
	target.add_child(_make_poly([gE, gS, gS+up, gE+up],
		ArtPalette.cool_shadow(side_c, 0.20).darkened(0.28)))
	_add_outline(target, [gW, gS, gS+up, gW+up], ol_c, 1.2)
	_add_outline(target, [gE, gS, gS+up, gE+up], ol_c, 1.2)
	var lit_top := ArtPalette.warm_highlight(top_c, 0.06).lightened(0.15)
	target.add_child(_make_poly([gN+up, gE+up, gS+up, gW+up], lit_top))
	var top_ol := ArtPalette.cool_shadow(top_c, 0.40).darkened(0.25);  top_ol.a = 0.70
	_add_outline(target, [gN+up, gE+up, gS+up, gW+up], top_ol, 1.0)
	# Mattress seam lines (2 horizontal folds)
	var seam_c := Color(top_c.darkened(0.22), 0.45)
	for t in [0.30, 0.68]:
		var sl := Line2D.new();  sl.default_color = seam_c;  sl.width = 1.0
		sl.add_point(_top_lerp(gN+up, gW+up, gS+up, gE+up, t, 0.12))
		sl.add_point(_top_lerp(gN+up, gW+up, gS+up, gE+up, t, 0.88))
		target.add_child(sl)

	# 4. Footboard — shorter, S end (drawn after mattress = rendered in front)
	_bake_sub_box(target, c - dn*0.78, dn*0.22, de, h*0.55,
		wood.lightened(0.05), wood)

	# 5. Pillow — bone-white flat diamond near N end of mattress top
	var pi_c := c + dn*0.36 + Vector2(0.0, -h - 0.8)
	var pi_d := dn*0.25;  var pi_e := de*0.60
	var pi_col := ArtPalette.warm_highlight(ArtPalette.BONE_WHITE, 0.04)
	target.add_child(_make_poly([pi_c+pi_d, pi_c+pi_e, pi_c-pi_d, pi_c-pi_e], pi_col))
	_add_outline(target, [pi_c+pi_d, pi_c+pi_e, pi_c-pi_d, pi_c-pi_e],
		Color(ArtPalette.FURN_WOOD_SOFT.darkened(0.30), 0.42), 0.8)

	# 6. Leg stubs at diamond corners
	var leg_c := Color(wood.darkened(0.40), 0.55)
	for corner: Vector2 in [gN, gE, gS, gW]:
		var lg := Line2D.new();  lg.default_color = leg_c;  lg.width = 2.5
		lg.add_point(corner);  lg.add_point(corner + Vector2(0.0, 4.0))
		target.add_child(lg)


## SOFA: call generic (seat body), then add back panel, arms, cushion divider.
func _bake_sofa_into(target: Node2D, c: Vector2, dn: Vector2, de: Vector2,
		h: float, top_c: Color, side_c: Color) -> void:
	_bake_generic_into(target, c, dn, de, h, top_c, side_c)

	# Back panel: darker, slightly taller, N end (25% depth)
	var bk_c := side_c.darkened(0.18)
	_bake_sub_box(target, c + dn*0.76, dn*0.24, de, h*1.06,
		bk_c.lightened(0.05), bk_c)

	# Left arm: W end, 16% width, 80% height
	var arm_c := side_c.darkened(0.10)
	_bake_sub_box(target, c - de*0.84, dn, de*0.16, h*0.80,
		arm_c.lightened(0.04), arm_c)

	# Right arm: E end, 16% width, 80% height
	_bake_sub_box(target, c + de*0.84, dn, de*0.16, h*0.80,
		arm_c.lightened(0.04), arm_c)

	# Cushion division line on seat top
	var gN := c+dn;  var gE := c+de;  var gS := c-dn;  var gW := c-de
	var up  := Vector2(0.0, -h)
	var div := Line2D.new();  div.default_color = Color(side_c.darkened(0.38), 0.55);  div.width = 1.2
	div.add_point(_top_lerp(gN+up, gW+up, gS+up, gE+up, 0.50, 0.16))
	div.add_point(_top_lerp(gN+up, gW+up, gS+up, gE+up, 0.50, 0.84))
	target.add_child(div)


## SHELF: call generic (frame), then add shelf boards as horizontal lines + thin top-faces.
func _bake_shelf_into(target: Node2D, c: Vector2, dn: Vector2, de: Vector2,
		h: float, top_c: Color, side_c: Color) -> void:
	_bake_generic_into(target, c, dn, de, h, top_c, side_c)

	var gW := c - de;  var gS := c - dn;  var gE := c + de
	var board_edge_c := Color(ArtPalette.warm_highlight(top_c, 0.08).lightened(0.14), 0.80)
	var board_top_c  := ArtPalette.warm_highlight(top_c, 0.10).lightened(0.16)

	for t in [0.25, 0.55, 0.82]:
		# Front edge of board on W face
		var wl := Line2D.new();  wl.default_color = board_edge_c;  wl.width = 1.5
		wl.add_point(gW + Vector2(0.0, -h*t))
		wl.add_point(gS + Vector2(0.0, -h*t))
		target.add_child(wl)
		# Front edge on E face (slightly darker)
		var el := Line2D.new();  el.default_color = Color(board_edge_c.darkened(0.15), 0.60);  el.width = 1.5
		el.add_point(gE + Vector2(0.0, -h*t))
		el.add_point(gS + Vector2(0.0, -h*t))
		target.add_child(el)
		# Board top-face diamond (thin flat)
		var bt_ctr := c + Vector2(0.0, -h*t - 1.5)
		var bt_dn  := dn * 0.80;  var bt_de := de * 0.80
		target.add_child(_make_poly(
			[bt_ctr+bt_dn, bt_ctr+bt_de, bt_ctr-bt_dn, bt_ctr-bt_de], board_top_c))


## COUNTER: call generic, then add cabinet dividers + handle bar on front face.
func _bake_counter_into(target: Node2D, c: Vector2, dn: Vector2, de: Vector2,
		h: float, top_c: Color, side_c: Color) -> void:
	_bake_generic_into(target, c, dn, de, h, top_c, side_c)

	var gW := c - de;  var gS := c - dn;  var up := Vector2(0.0, -h)
	var door_c   := Color(side_c.darkened(0.26), 0.62)
	var handle_c := Color(top_c.lightened(0.28), 0.82)

	# Cabinet dividers (vertical lines on W face)
	for f in [0.34, 0.67]:
		var dv := Line2D.new();  dv.default_color = door_c;  dv.width = 1.0
		dv.add_point(lerp(gW, gS, f))
		dv.add_point(lerp(gW, gS, f) + up)
		target.add_child(dv)

	# Handle bar at 35% height
	var hl := Line2D.new();  hl.default_color = handle_c;  hl.width = 1.5
	hl.add_point(lerp(gW, gS, 0.14) + Vector2(0.0, -h*0.35))
	hl.add_point(lerp(gW, gS, 0.86) + Vector2(0.0, -h*0.35))
	target.add_child(hl)

	# Front panel recess: slightly darker strip at bottom of W face
	var panel_c := Color(side_c.darkened(0.18), 0.50)
	target.add_child(_make_poly([
		gW + Vector2(0.0, -h*0.02), gS + Vector2(0.0, -h*0.02),
		gS + Vector2(0.0, -h*0.28), gW + Vector2(0.0, -h*0.28)
	], panel_c))


## WARDROBE: call generic, then add door seam, handles, top moulding.
func _bake_wardrobe_into(target: Node2D, c: Vector2, dn: Vector2, de: Vector2,
		h: float, top_c: Color, side_c: Color) -> void:
	_bake_generic_into(target, c, dn, de, h, top_c, side_c)

	var gN := c+dn;  var gE := c+de;  var gS := c-dn;  var gW := c-de
	var up  := Vector2(0.0, -h)
	var seam_c   := Color(side_c.darkened(0.30), 0.72)
	var handle_c := Color(top_c.lightened(0.30), 0.86)
	var mould_c  := Color(side_c.lightened(0.24), 0.68)

	# Centre door seam (vertical midline of W face)
	var sm := Line2D.new();  sm.default_color = seam_c;  sm.width = 1.0
	sm.add_point(lerp(gW, gS, 0.50))
	sm.add_point(lerp(gW+up, gS+up, 0.50))
	target.add_child(sm)

	# Door handles (small circles at 25% and 75% on W face, at mid-height)
	for f: float in [0.25, 0.75]:
		var hpos := gW.lerp(gS, f) + Vector2(0.0, -h*0.46)
		var h_pts : Array[Vector2] = []
		for i in 8:
			var a := TAU * float(i) / 8.0
			h_pts.append(hpos + Vector2(cos(a)*2.2, sin(a)*1.4))
		target.add_child(_make_poly(h_pts, handle_c))

	# Top moulding: bright line along NW and NE top edges
	var m1 := Line2D.new();  m1.default_color = mould_c;  m1.width = 2.0
	m1.add_point(gN+up);  m1.add_point(gW+up)
	target.add_child(m1)
	var m2 := Line2D.new();  m2.default_color = mould_c;  m2.width = 2.0
	m2.add_point(gN+up);  m2.add_point(gE+up)
	target.add_child(m2)


## CHAIR: call generic (body), then add prominent back rest.
func _bake_chair_into(target: Node2D, c: Vector2, dn: Vector2, de: Vector2,
		h: float, top_c: Color, side_c: Color) -> void:
	_bake_generic_into(target, c, dn, de, h, top_c, side_c)

	# Back rest: thin, taller, N end — clearly visible above seat
	_bake_sub_box(target, c + dn*0.78, dn*0.22, de*0.78, h*1.40,
		side_c.darkened(0.10), side_c.darkened(0.08))

	# Leg stubs at E, S, W corners (N is hidden by back rest)
	var leg_c := Color(side_c.darkened(0.40), 0.58)
	for corner: Vector2 in [c+de, c-dn, c-de]:
		var lg := Line2D.new();  lg.default_color = leg_c;  lg.width = 2.0
		lg.add_point(corner);  lg.add_point(corner + Vector2(0.0, 3.5))
		target.add_child(lg)


## STOVE: call generic, then add 4 burner rings + control knobs + oven seam.
func _bake_stove_into(target: Node2D, c: Vector2, dn: Vector2, de: Vector2,
		h: float, top_c: Color, side_c: Color) -> void:
	_bake_generic_into(target, c, dn, de, h, top_c, side_c)

	var up := Vector2(0.0, -h)
	var gN := c+dn;  var gE := c+de;  var gS := c-dn;  var gW := c-de
	var burner_c := Color(side_c.darkened(0.48), 0.88)
	var inner_c  := Color(side_c.darkened(0.22), 0.70)

	# 4 burner rings on top face (2×2 grid)
	var burner_pos := [
		_top_lerp(gN+up, gW+up, gS+up, gE+up, 0.28, 0.28),
		_top_lerp(gN+up, gW+up, gS+up, gE+up, 0.28, 0.72),
		_top_lerp(gN+up, gW+up, gS+up, gE+up, 0.72, 0.28),
		_top_lerp(gN+up, gW+up, gS+up, gE+up, 0.72, 0.72),
	]
	for bpos: Vector2 in burner_pos:
		var rpts : Array[Vector2] = []
		for i in 10:
			var a := TAU * float(i) / 10.0
			rpts.append(bpos + Vector2(cos(a)*3.5, sin(a)*2.0))
		target.add_child(_make_poly(rpts, burner_c))
		var ipts : Array[Vector2] = []
		for i in 10:
			var a := TAU * float(i) / 10.0
			ipts.append(bpos + Vector2(cos(a)*1.8, sin(a)*1.0))
		target.add_child(_make_poly(ipts, inner_c))

	# Control knobs on front W face (3 dots)
	var knob_c := Color(top_c.lightened(0.22), 0.82)
	for k in 3:
		var f    := (float(k) + 1.0) / 4.0
		var kpos := gW.lerp(gS, f) + Vector2(0.0, -h*0.32)
		var kpts : Array[Vector2] = []
		for i in 7:
			var a := TAU * float(i) / 7.0
			kpts.append(kpos + Vector2(cos(a)*2.0, sin(a)*1.2))
		target.add_child(_make_poly(kpts, knob_c))

	# Oven door seam line
	var dsm := Line2D.new();  dsm.default_color = Color(side_c.darkened(0.32), 0.66);  dsm.width = 1.0
	dsm.add_point(lerp(gW, gS, 0.08) + Vector2(0.0, -h*0.55))
	dsm.add_point(lerp(gW, gS, 0.92) + Vector2(0.0, -h*0.55))
	target.add_child(dsm)


## FILING CABINET: call generic, then add 3 drawer seams + handles + label strips.
func _bake_filing_into(target: Node2D, c: Vector2, dn: Vector2, de: Vector2,
		h: float, top_c: Color, side_c: Color) -> void:
	_bake_generic_into(target, c, dn, de, h, top_c, side_c)

	var gW := c - de;  var gS := c - dn;  var gE := c + de
	var drawer_c := Color(side_c.darkened(0.22), 0.72)
	var handle_c := Color(top_c.lightened(0.38), 0.82)
	var label_c  := Color(ArtPalette.BONE_WHITE, 0.28)

	for d in 3:
		var t := float(d + 1) / 4.0   # at 25%, 50%, 75% of height
		# Seam line on W face
		var sw := Line2D.new();  sw.default_color = drawer_c;  sw.width = 1.0
		sw.add_point(lerp(gW, gS, 0.04) + Vector2(0.0, -h*t))
		sw.add_point(lerp(gW, gS, 0.96) + Vector2(0.0, -h*t))
		target.add_child(sw)
		# Seam line on E face (slightly fainter)
		var se2 := Line2D.new();  se2.default_color = Color(drawer_c.darkened(0.12), 0.55);  se2.width = 1.0
		se2.add_point(lerp(gE, gS, 0.04) + Vector2(0.0, -h*t))
		se2.add_point(lerp(gE, gS, 0.96) + Vector2(0.0, -h*t))
		target.add_child(se2)
		# Handle dot at mid-height of each drawer
		var hpos := gW.lerp(gS, 0.50) + Vector2(0.0, -h*(t - 0.12))
		var hpts : Array[Vector2] = []
		for i in 7:
			var a := TAU * float(i) / 7.0
			hpts.append(hpos + Vector2(cos(a)*2.5, sin(a)*1.5))
		target.add_child(_make_poly(hpts, handle_c))
		# Label strip (thin lighter rect on upper drawer front)
		target.add_child(_make_poly([
			lerp(gW, gS, 0.10) + Vector2(0.0, -h*(t - 0.04)),
			lerp(gW, gS, 0.90) + Vector2(0.0, -h*(t - 0.04)),
			lerp(gW, gS, 0.90) + Vector2(0.0, -h*(t - 0.14)),
			lerp(gW, gS, 0.10) + Vector2(0.0, -h*(t - 0.14)),
		], label_c))


## FRIDGE: tall appliance — door seal seam + recessed handle bar + ice-maker panel.
func _bake_fridge_into(target: Node2D, c: Vector2, dn: Vector2, de: Vector2,
		h: float, top_c: Color, side_c: Color) -> void:
	_bake_generic_into(target, c, dn, de, h, top_c, side_c)

	var gW := c - de;  var gS := c - dn;  var gE := c + de
	var up  := Vector2(0.0, -h)
	var seam_c   := Color(side_c.darkened(0.28), 0.75)
	var handle_c := Color(top_c.lightened(0.32), 0.88)
	var panel_c  := Color(side_c.darkened(0.16), 0.42)

	# Door seam: horizontal line dividing freezer (top ~30%) from fridge body
	var dsm := Line2D.new();  dsm.default_color = seam_c;  dsm.width = 1.2
	dsm.add_point(lerp(gW, gS, 0.04) + Vector2(0.0, -h*0.70))
	dsm.add_point(lerp(gW, gS, 0.96) + Vector2(0.0, -h*0.70))
	target.add_child(dsm)
	# Same seam on E face
	var dsm_e := Line2D.new();  dsm_e.default_color = Color(seam_c.darkened(0.12), 0.55);  dsm_e.width = 1.2
	dsm_e.add_point(lerp(gE, gS, 0.04) + Vector2(0.0, -h*0.70))
	dsm_e.add_point(lerp(gE, gS, 0.96) + Vector2(0.0, -h*0.70))
	target.add_child(dsm_e)

	# Recessed handle bar (near N edge on W face, vertical, at ~45% height)
	var hl := Line2D.new();  hl.default_color = handle_c;  hl.width = 2.5
	hl.add_point(lerp(gW, gS, 0.14) + Vector2(0.0, -h*0.36))
	hl.add_point(lerp(gW, gS, 0.14) + Vector2(0.0, -h*0.58))
	target.add_child(hl)

	# Freezer handle bar (same position on freezer section)
	var hl2 := Line2D.new();  hl2.default_color = handle_c;  hl2.width = 2.5
	hl2.add_point(lerp(gW, gS, 0.14) + Vector2(0.0, -h*0.76))
	hl2.add_point(lerp(gW, gS, 0.14) + Vector2(0.0, -h*0.88))
	target.add_child(hl2)

	# Ice-maker panel: small darker inset on upper-left of main fridge face
	target.add_child(_make_poly([
		lerp(gW, gS, 0.52) + Vector2(0.0, -h*0.10),
		lerp(gW, gS, 0.90) + Vector2(0.0, -h*0.10),
		lerp(gW, gS, 0.90) + Vector2(0.0, -h*0.30),
		lerp(gW, gS, 0.52) + Vector2(0.0, -h*0.30),
	], panel_c))


## DRESSER: generic frame + horizontal drawer seam lines + small handle pair per drawer.
func _bake_dresser_into(target: Node2D, c: Vector2, dn: Vector2, de: Vector2,
		h: float, top_c: Color, side_c: Color) -> void:
	_bake_generic_into(target, c, dn, de, h, top_c, side_c)

	var gW := c - de;  var gS := c - dn;  var gE := c + de
	var drawer_c := Color(side_c.darkened(0.24), 0.68)
	var handle_c := Color(top_c.lightened(0.34), 0.84)

	# 4 drawer seam lines on W face (divides height evenly)
	for d in 4:
		var t := float(d + 1) / 5.0
		var sl := Line2D.new();  sl.default_color = drawer_c;  sl.width = 1.0
		sl.add_point(lerp(gW, gS, 0.04) + Vector2(0.0, -h*t))
		sl.add_point(lerp(gW, gS, 0.96) + Vector2(0.0, -h*t))
		target.add_child(sl)
		# Faint seam on E face
		var el := Line2D.new();  el.default_color = Color(drawer_c.darkened(0.14), 0.45);  el.width = 1.0
		el.add_point(lerp(gE, gS, 0.04) + Vector2(0.0, -h*t))
		el.add_point(lerp(gE, gS, 0.96) + Vector2(0.0, -h*t))
		target.add_child(el)
		# Two small handle dots per drawer (at 35% and 65% along face)
		for f: float in [0.35, 0.65]:
			var hpos := gW.lerp(gS, f) + Vector2(0.0, -h*(t - 0.10))
			var hpts : Array[Vector2] = []
			for i in 6:
				var a := TAU * float(i) / 6.0
				hpts.append(hpos + Vector2(cos(a)*1.8, sin(a)*1.2))
			target.add_child(_make_poly(hpts, handle_c))


## BATHTUB: low flat box with recessed inner well + faucet stub at N end.
func _bake_bathtub_into(target: Node2D, c: Vector2, dn: Vector2, de: Vector2,
		h: float, top_c: Color, side_c: Color) -> void:
	_bake_generic_into(target, c, dn, de, h, top_c, side_c)

	var up := Vector2(0.0, -h)
	var gN := c+dn;  var gE := c+de;  var gS := c-dn;  var gW := c-de
	var well_c   := Color(side_c.darkened(0.32), 0.70)   # inner well floor
	var rim_c    := Color(top_c.lightened(0.22), 0.78)   # rim highlights
	var faucet_c := Color(ArtPalette.BONE_WHITE.darkened(0.20), 0.85)

	# Inner well: inset flat diamond at top face (85% scale, slightly sunken)
	var inset := 0.82
	var wN := c + dn*inset + up;  var wE := c + de*inset + up
	var wS := c - dn*inset + up;  var wW := c - de*inset + up
	target.add_child(_make_poly([wN, wE, wS, wW], well_c))

	# Rim outline around the inner well
	var rl := Line2D.new();  rl.default_color = Color(rim_c, 0.65);  rl.width = 1.2
	rl.closed = true
	rl.add_point(wN);  rl.add_point(wE);  rl.add_point(wS);  rl.add_point(wW)
	target.add_child(rl)

	# Drain circle near S end of well
	var drain_p := c - dn*0.50 + up
	var dpts : Array[Vector2] = []
	for i in 8:
		var a := TAU * float(i) / 8.0
		dpts.append(drain_p + Vector2(cos(a)*2.0, sin(a)*1.2))
	target.add_child(_make_poly(dpts, well_c.darkened(0.30)))

	# Faucet stub at N end: small bright rectangle rising from rim
	var fpos := c + dn*0.76 + up
	var fdn  := dn * 0.10;  var fde := de * 0.08
	target.add_child(_make_poly(
		[fpos+fdn, fpos+fde, fpos-fdn, fpos-fde], faucet_c))
	# Faucet handles (two small nubs left/right)
	for side: float in [-1.0, 1.0]:
		var hbase := fpos + de * side * 0.22
		var hpts : Array[Vector2] = []
		for i in 6:
			var a := TAU * float(i) / 6.0
			hpts.append(hbase + Vector2(cos(a)*1.4, sin(a)*0.9))
		target.add_child(_make_poly(hpts, faucet_c.darkened(0.14)))


## Draws one flat rhombus into target at BAKE_FC.
## Design bible §7: border hem + cross-grain for rug/floor-mark texture.
func _bake_flat_into(target: Node2D, sn: float, se: float, col: Color) -> void:
	var c  := BAKE_FC
	var dn := BAKE_NV * sn
	var de := BAKE_EV * se
	# Base flat diamond.
	target.add_child(_make_poly([c + dn, c + de, c - dn, c - de], col))
	# Inner border (rug hem / edge trim).
	var hem := Line2D.new()
	hem.closed        = true
	hem.default_color = Color(col.lightened(0.14), col.a * 0.55)
	hem.width         = 1.0
	hem.add_point(lerp(c, c + dn, 0.88))
	hem.add_point(lerp(c, c + de, 0.88))
	hem.add_point(lerp(c, c - dn, 0.88))
	hem.add_point(lerp(c, c - de, 0.88))
	target.add_child(hem)
	# Cross-grain lines parallel to E-W axis.
	var fg_n := max(1, int(dn.length() * 2.0 / 6.0))
	for i in range(1, fg_n + 1):
		var t  := float(i) / float(fg_n + 1)
		var fl := Line2D.new()
		fl.default_color = Color(col.darkened(0.08), col.a * 0.35)
		fl.width = 1.0
		fl.add_point(_top_lerp(c + dn, c - de, c - dn, c + de, t, 0.0))
		fl.add_point(_top_lerp(c + dn, c - de, c - dn, c + de, t, 1.0))
		target.add_child(fl)
