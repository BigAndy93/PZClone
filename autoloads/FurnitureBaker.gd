## FurnitureBaker — bakes procedural furniture pieces into ImageTextures via SubViewport.
## Each unique (sn, se, h, top_c, side_c) combination is baked once at startup,
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
const BAKE_EV : Vector2 = Vector2(32.0,  16.0)   # east axis  (1-tile step = TILE_W*0.5, TILE_H*0.5)

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
## The bake canvas uses BAKE_NV=(0,-16) / BAKE_EV=(32,16) — screen-axis-aligned — so
## rendering without rotation keeps furniture aligned with the tile grid on all building
## shapes (square or rectangular).  nv/ev are unused but kept for API compatibility.
## rot is encoded in the key — the correct pre-baked orientation is fetched from cache.
func make_sprite(key: String, nv: Vector2, ev: Vector2, local_c: Vector2, rot: int = 0) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture        = _cache[key]
	spr.centered       = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Axis-aligned: bake X → screen right (1,0), bake Y → screen down (0,1).
	# BAKE_FC pixel lands at local_c; furniture aligns with the tile grid.
	spr.transform = Transform2D(
		Vector2(1.0, 0.0), Vector2(0.0, 1.0),
		local_c - Vector2(BAKE_FC.x, BAKE_FC.y))
	return spr


## Bakes all unique specs into cached ImageTextures.
## Awaitable coroutine — World._ready() must await this before _generate_map().
## Re-calling with already-cached keys is safe and returns instantly.
##
## Box spec format: [sn, se, h, tc, sc]  OR  [sn, se, h, tc, sc, [rot0, rot1, ...]]
## If a rots array (element 5) is present, all listed rotations are baked.
## Otherwise only rot=0 is baked (backward-compatible).
func warm_batch(box_specs: Array, flat_specs: Array) -> void:
	var pairs : Array = []   # [{key, vp}]

	for spec in box_specs:
		var rots: Array = [0]
		if spec.size() >= 6 and spec[5] is Array:
			rots = spec[5]
		for rot in rots:
			var key := box_key(spec[0], spec[1], spec[2], spec[3], spec[4], rot)
			if _cache.has(key):
				continue
			var vp   := _make_viewport()
			var root := Node2D.new()
			vp.add_child(root)
			_bake_box_into(root, spec[0], spec[1], spec[2], spec[3], spec[4], rot)
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

	for p in pairs:
		var vp  : SubViewport = p["vp"]
		var img              := vp.get_texture().get_image()
		if img == null or img.is_empty():
			push_warning("FurnitureBaker: bake capture failed for key " + p["key"])
			vp.queue_free()
			continue
		_cache[p["key"]] = ImageTexture.create_from_image(img)
		vp.queue_free()


# ── Internal helpers ────────────────────────────────────────────────────────────

func _make_viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.size                      = Vector2i(BAKE_W, BAKE_H)
	vp.transparent_bg            = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	return vp


## Adds a closed Line2D outline around a convex polygon.
## pts must be in order (same winding as the polygon).
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


## Draws one furniture box into target using BAKE_NV/BAKE_EV centred at BAKE_FC.
## Design bible §1–§9: NW-light value separation, surface grain, rim highlights, AO base.
##
## rot (0–3): 90° CW increments — re-binds which world faces appear as the lit W / dark E
## face without any pixel-level rotation (pre-baked separation, no distortion).
##   rot=0: dn=NV*sn,   de=EV*se          (standard — N face, E face)
##   rot=1: dn=EV*sn,   de=(0,16)*se      (90° CW — E face becomes N in world)
##   rot=2: dn=-NV*sn,  de=-EV*se         (180°)
##   rot=3: dn=-EV*sn,  de=(0,-16)*se     (270° CW)
func _bake_box_into(target: Node2D,
		sn: float, se: float, h: float,
		top_c: Color, side_c: Color, rot: int = 0) -> void:
	var c  := BAKE_FC
	# ── Rotate the diamond axes (no pixel rotation — re-binds face identity) ─
	var dn: Vector2
	var de: Vector2
	match rot:
		1:
			dn = BAKE_EV * sn
			de = Vector2(0.0, -BAKE_NV.y) * se   # = (0, 16) * se
		2:
			dn = -BAKE_NV * sn
			de = -BAKE_EV * se
		3:
			dn = -BAKE_EV * sn
			de = Vector2(0.0, BAKE_NV.y) * se    # = (0, -16) * se
		_:  # rot=0 — default
			dn = BAKE_NV * sn
			de = BAKE_EV * se

	var up := Vector2(0.0, -h)
	var gN := c + dn
	var gE := c + de
	var gS := c - dn
	var gW := c - de

	# ── Outline colour — deep navy tint per art bible (no pure black) ──────
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

	# ── 3. W face — lit side (NW light, design bible: baseline value) ──────
	target.add_child(_make_poly([gW, gS, gS + up, gW + up], side_c))
	# Vertical grain on W face (subtle, deterministic).
	var wg_n := max(1, int(de.length() / 10.0))
	for i in range(1, wg_n + 1):
		var t  := float(i) / float(wg_n + 1)
		var wg := Line2D.new()
		wg.default_color = Color(side_c.darkened(0.05 + 0.04 * float(i % 2)), 0.22)
		wg.width = 1.0
		wg.add_point(lerp(gW, gS, t))
		wg.add_point(lerp(gW + up, gS + up, t))
		target.add_child(wg)
	# W face outline.
	_add_outline(target, [gW, gS, gS + up, gW + up], outline_col, 1.2)

	# ── 4. E face — dark side (away from NW light, cool shadow) ───────────
	# Contrast increased vs previous (was cool_shadow 0.12 + darkened 0.18)
	# to match the ~30% face separation visible in the hand-drawn sprite sheets.
	target.add_child(_make_poly(
			[gE, gS, gS + up, gE + up],
			ArtPalette.cool_shadow(side_c, 0.20).darkened(0.28)))
	# E face outline.
	_add_outline(target, [gE, gS, gS + up, gE + up], outline_col, 1.2)

	# ── 5. Top face — warm, +15% brightness (design bible §9) ─────────────
	var lit_top := ArtPalette.warm_highlight(top_c, 0.06).lightened(0.15)
	target.add_child(_make_poly([gN + up, gE + up, gS + up, gW + up], lit_top))
	# Cross-grain lines on top face (N→S parameterisation).
	var tg_n := max(1, int(dn.length() * 2.0 / 5.0))
	for i in range(1, tg_n + 1):
		var t  := float(i) / float(tg_n + 1)
		var tg := Line2D.new()
		tg.default_color = Color(lit_top.darkened(0.06 + 0.04 * float(i % 2)), 0.28)
		tg.width = 1.0
		tg.add_point(_top_lerp(gN + up, gW + up, gS + up, gE + up, t, 0.0))
		tg.add_point(_top_lerp(gN + up, gW + up, gS + up, gE + up, t, 1.0))
		target.add_child(tg)
	# Top face outline — slightly lighter than side outlines.
	var top_outline_col := ArtPalette.cool_shadow(top_c, 0.40).darkened(0.25)
	top_outline_col.a = 0.70
	_add_outline(target, [gN + up, gE + up, gS + up, gW + up], top_outline_col, 1.0)

	# ── 6. Rim highlights on top edges ────────────────────────────────────
	# NW edge: brightest (faces light source directly).
	var nw_rim := Line2D.new()
	nw_rim.default_color = ArtPalette.warm_highlight(top_c, 0.10).lightened(0.28)
	nw_rim.width = 1.0
	nw_rim.add_point(gN + up);  nw_rim.add_point(gW + up)
	target.add_child(nw_rim)
	# NE edge: medium highlight.
	var ne_rim := Line2D.new()
	ne_rim.default_color = ArtPalette.warm_highlight(top_c, 0.06).lightened(0.18)
	ne_rim.width = 1.0
	ne_rim.add_point(gN + up);  ne_rim.add_point(gE + up)
	target.add_child(ne_rim)
	# SW edge: front bevel (most visible to camera).
	var bevel := Line2D.new()
	bevel.default_color = ArtPalette.warm_highlight(top_c, 0.08).lightened(0.24)
	bevel.width = 1.0
	bevel.add_point(gS + up);  bevel.add_point(gW + up)
	target.add_child(bevel)


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
