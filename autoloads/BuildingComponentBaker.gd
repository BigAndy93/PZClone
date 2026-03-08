## BuildingComponentBaker — bakes building wall faces, door frames, window variants,
## and floor tiles into ImageTextures via SubViewport, then serves cached Sprite2D nodes.
##
## The baked geometry is pixel-identical to BuildingTileRenderer's procedural _draw()
## output. Each unique component (type, face direction, height, window state) is baked
## once at startup with UPDATE_ONCE SubViewports (zero GPU cost after first render).
##
## Usage in World._ready():
##   await BuildingComponentBaker.warm(3)   # max height_tiles used in the map
##   _generate_map()
##
## BuildingTileRenderer.setup() then calls get_sprite(key) to obtain positioned Sprite2Ds.

extends Node

# ── Geometry constants (match BuildingTileRenderer exactly) ─────────────────────
const WALL_H_PER_TILE : float = 32.0

const WALL_NE_BASE  := Color(0.38, 0.35, 0.30, 1.0)   # shadow (right-leaning NE face)
const WALL_NW_BASE  := Color(0.62, 0.58, 0.50, 1.0)   # lit    (left-leaning  NW face)
const OUTLINE_COLOR := Color(0.10, 0.08, 0.06, 0.85)
const FLOOR_COLOR   := Color(0.44, 0.41, 0.36, 1.0)
const DOOR_COL      := Color(0.55, 0.38, 0.22, 1.0)
const GLASS_COL     := Color(0.55, 0.72, 0.90, 1.0)
const GLASS_BROKEN  := Color(0.06, 0.06, 0.08, 1.0)

# ── Wall-thickness geometry ──────────────────────────────────────────────────────
# WALL_T: horizontal extent of the top face / end-cap depth in screen pixels.
# depth vector per face type (perpendicular to face, toward building interior):
#   NE face → map(0,+1) → screen(-32,+16)/tile → (-WALL_T, WALL_T*0.4)
#   NW face → map(+1,0) → screen(+32,+16)/tile → (+WALL_T, WALL_T*0.4)
const WALL_T       : float = 5.0
# Extra bake-viewport height so the wall top + top face fit inside the texture.
# Without this, pt_n+up lands at y≈-12 (above viewport) for h=1 walls.
const TOP_FACE_PAD : int   = 16

# ── Viewport dimensions ─────────────────────────────────────────────────────────
# Width wide enough for 1 diamond face (half a 64px tile = 32px each leg).
# Pivot is at (BAKE_PIVOT_X, BAKE_PIVOT_Y) — the diamond-tip corner where the wall sits.
const BAKE_W       : int   = 80     # px wide
const BAKE_PIVOT_X : float = 40.0   # centre of the viewport horizontally
const BAKE_PIVOT_Y : float = 52.0   # diamond-contact point (south end of face)

# Floor tile uses a square viewport centred on the diamond.
const FLOOR_W      : int   = 80
const FLOOR_H      : int   = 48
const FLOOR_PX     : float = 40.0   # pivot x (centre)
const FLOOR_PY     : float = 32.0   # pivot y (south vertex of diamond)

## key → ViewportTexture (kept alive inside SubViewport children)
var _cache : Dictionary = {}


# ── Public API ──────────────────────────────────────────────────────────────────

## Pre-bake all building component variants for height_tiles 1..max_h.
## Awaits two process frames for UPDATE_ONCE SubViewports to render.
func warm(max_h: int = 3) -> void:
	var pairs: Array = []

	# Floor tile (single, shared by all buildings)
	_queue_bake("floor", pairs, func(vp): _bake_floor_into(vp))

	# Wall, door, and window faces for each height
	for h in range(1, max_h + 1):
		_queue_bake("wall_ne_%d" % h, pairs, func(vp): _bake_wall_into(vp, WALL_NE_BASE, h, false))
		_queue_bake("wall_nw_%d" % h, pairs, func(vp): _bake_wall_into(vp, WALL_NW_BASE, h, true))
		_queue_bake("door_ne_%d" % h, pairs, func(vp): _bake_door_into(vp, WALL_NE_BASE, h, false))
		_queue_bake("door_nw_%d" % h, pairs, func(vp): _bake_door_into(vp, WALL_NW_BASE, h, true))
		for state in range(4):
			_queue_bake("win_ne_%d_%d" % [state, h], pairs,
				func(vp): _bake_window_into(vp, WALL_NE_BASE, h, state, false))
			_queue_bake("win_nw_%d_%d" % [state, h], pairs,
				func(vp): _bake_window_into(vp, WALL_NW_BASE, h, state, true))

	if pairs.is_empty():
		return

	await get_tree().process_frame
	await get_tree().process_frame

	for p in pairs:
		var vp: SubViewport = p["vp"]
		_cache[p["key"]] = vp.get_texture()


## Returns a new Sprite2D whose pivot (BAKE_PIVOT) maps to local_pos.
## The sprite is positioned so the baked geometry appears at the correct tile position.
## Pass flip_h=true to mirror a NE face into a SW face or NW into SE.
func get_sprite(key: String, local_pos: Vector2, flip_h: bool = false) -> Sprite2D:
	if not _cache.has(key):
		push_warning("BuildingComponentBaker: key not found: %s" % key)
		return Sprite2D.new()
	var spr                := Sprite2D.new()
	spr.texture             = _cache[key]
	spr.centered            = false
	spr.texture_filter      = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.flip_h              = flip_h
	# Without flip: pivot at (BAKE_PIVOT_X, BAKE_PIVOT_Y) should land at local_pos.
	if key == "floor":
		# Diamond centre in bake space is at (FLOOR_PX, FLOOR_H - FLOOR_PY) = (40, 16).
		# Align that pixel to local_pos (the tile centre in node space).
		spr.position = local_pos - Vector2(FLOOR_PX, float(FLOOR_H) - FLOOR_PY)
	else:
		var bake_h: int = _viewport_h_for_key(key)
		if flip_h:
			# When flipped, Godot mirrors around x=0 of the sprite; BAKE_PIVOT_X from right
			spr.position = local_pos - Vector2(float(BAKE_W) - BAKE_PIVOT_X, float(bake_h) - BAKE_PIVOT_Y)
		else:
			spr.position = local_pos - Vector2(BAKE_PIVOT_X, float(bake_h) - BAKE_PIVOT_Y)
	return spr


## Returns true if the key has been baked.
func has_component(key: String) -> bool:
	return _cache.has(key)


# ── Internal helpers ─────────────────────────────────────────────────────────────

func _viewport_h_for_key(key: String) -> int:
	# Extract height tiles from key suffix _N
	var parts := key.split("_")
	var h_tiles := int(parts[-1])
	if h_tiles <= 0:
		h_tiles = 1
	return int(WALL_H_PER_TILE * float(h_tiles)) + int(BAKE_PIVOT_Y) + 4 + TOP_FACE_PAD


func _make_viewport(w: int, h: int) -> SubViewport:
	var vp                          := SubViewport.new()
	vp.size                          = Vector2i(w, h)
	vp.transparent_bg                = true
	vp.render_target_update_mode     = SubViewport.UPDATE_ONCE
	return vp


func _queue_bake(key: String, pairs: Array, bake_fn: Callable) -> void:
	if _cache.has(key):
		return
	var bake_h : int
	if key == "floor":
		bake_h = FLOOR_H
	else:
		bake_h = _viewport_h_for_key(key)
	var vp   := _make_viewport(BAKE_W, bake_h)
	var root := Node2D.new()
	vp.add_child(root)
	bake_fn.call(root)
	add_child(vp)
	pairs.append({"key": key, "vp": vp})


func _make_poly(pts: Array, col: Color) -> Polygon2D:
	var p         := Polygon2D.new()
	p.polygon      = PackedVector2Array(pts)
	p.color        = col
	return p


func _add_line(target: Node2D, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var l                := Line2D.new()
	l.default_color       = col
	l.width               = w
	l.add_point(a)
	l.add_point(b)
	target.add_child(l)


func _add_outline(target: Node2D, pts: Array, col: Color, w: float) -> void:
	var ol               := Line2D.new()
	ol.default_color      = col
	ol.width              = w
	ol.closed             = true
	for p in pts:
		ol.add_point(p)
	target.add_child(ol)


# ── Bake functions ───────────────────────────────────────────────────────────────
# All geometry uses the same vertex math as BuildingTileRenderer._draw_*() methods.
# The viewport pivot (BAKE_PIVOT_X, bake_h - BAKE_PIVOT_Y) is the contact point
# at the south vertex of the diamond base where the wall sits.

## Wall geometry helpers.
## For a NE face (nw_face=false): points go pt_n(top-left) → pt_e(bottom-right).
## For a NW face (nw_face=true):  points go pt_n(top-right) → pt_w(bottom-left).
## The pivot is at the bottom diamond-tip of the face.
##
## In BuildingTileRenderer coordinates, for tile (tx, ty):
##   c    = cell_local(tx, ty)          — centre of the diamond tile
##   pt_n = c + Vector2(0, -16)         — north vertex
##   pt_e = c + Vector2(32, 0)          — east vertex
##   pt_w = c + Vector2(-32, 0)         — west vertex
##
## In bake space:
##   For NE face (pt_n → pt_e):
##     pt_n corresponds to (BAKE_PIVOT_X - 32, BAKE_PIVOT_Y - 16) — top-left
##     pt_e corresponds to (BAKE_PIVOT_X,       BAKE_PIVOT_Y)      — pivot (right contact)
##   For NW face (pt_n → pt_w):
##     pt_n corresponds to (BAKE_PIVOT_X + 32, BAKE_PIVOT_Y - 16) — top-right
##     pt_w corresponds to (BAKE_PIVOT_X,       BAKE_PIVOT_Y)      — pivot (left contact)

func _wall_pts(bake_h: int, wall_h: float, nw_face: bool) -> Array:
	# Returns [pt_a, pt_b, up] where pt_a→pt_b is the base of the face.
	var py   : float = float(bake_h) - BAKE_PIVOT_Y   # y of the diamond contact row
	var pt_n := Vector2(BAKE_PIVOT_X, py - 16.0)       # north (top-tip) vertex
	var pt_e := Vector2(BAKE_PIVOT_X + 32.0, py)       # east vertex
	var pt_w := Vector2(BAKE_PIVOT_X - 32.0, py)       # west vertex
	var up   := Vector2(0.0, -wall_h)
	if nw_face:
		return [pt_n, pt_w, up]   # NW face: n→w
	else:
		return [pt_n, pt_e, up]   # NE face: n→e


func _bake_floor_into(target: Node2D) -> void:
	# Isometric diamond centred at (FLOOR_PX, FLOOR_PY - 16)
	var cx : float = FLOOR_PX
	var cy : float = float(FLOOR_H) - FLOOR_PY
	var col        := ArtPalette.tile_gradient(FLOOR_COLOR)
	# tile_gradient returns 4 colours for [top, right, bottom, left] vertices
	var pts := PackedVector2Array([
		Vector2(cx,        cy - 16.0),  # north
		Vector2(cx + 32.0, cy),          # east
		Vector2(cx,        cy + 16.0),  # south
		Vector2(cx - 32.0, cy),          # west
	])
	var p                 := Polygon2D.new()
	p.polygon              = pts
	p.vertex_colors        = col
	target.add_child(p)
	# Outline
	_add_outline(target, [pts[0], pts[1], pts[2], pts[3]], OUTLINE_COLOR, 0.8)


func _bake_wall_into(target: Node2D, base_col: Color, h_tiles: int, nw_face: bool) -> void:
	var bake_h  : int   = _viewport_h_for_key("wall_ne_%d" % h_tiles)
	var wall_h  : float = WALL_H_PER_TILE * float(h_tiles)
	var res             := _wall_pts(bake_h, wall_h, nw_face)
	var a       : Vector2 = res[0]   # pt_n  (north-vertex end)
	var b       : Vector2 = res[1]   # pt_e or pt_w
	var up      : Vector2 = res[2]   # (0, -wall_h)

	# Depth = perpendicular to face, into the building interior (screen space).
	#   NE face: interior is south → map(0,+1) → screen(-WALL_T, +WALL_T*0.4)
	#   NW face: interior is east  → map(+1,0) → screen(+WALL_T, +WALL_T*0.4)
	var depth := Vector2(-WALL_T, WALL_T * 0.4) if not nw_face \
			else Vector2(WALL_T, WALL_T * 0.4)

	# ── 1. Front face — three lightness bands (dark bottom → lighter top) ─────
	var third   := up / 3.0
	var c1      := Color(base_col.r, base_col.g, base_col.b, 1.0)
	var c2      := c1.lightened(0.10)
	var c3      := c1.lightened(0.26)
	target.add_child(_make_poly([a,           b,           b + third,     a + third    ], c1))
	target.add_child(_make_poly([a + third,   b + third,   b + third*2.0, a + third*2.0], c2))
	target.add_child(_make_poly([a+third*2.0, b+third*2.0, b + up,        a + up       ], c3))

	# ── 2. Top face — horizontal slab, lightest value, drawn over front face ──
	var top_col := base_col.lightened(0.45)
	target.add_child(_make_poly([a + up, b + up, b + up + depth, a + up + depth], top_col))

	# ── 3. Outlines — omit the left edge (a→a+up) to avoid inter-tile seams ──
	_add_line(target, a,      b,      OUTLINE_COLOR, 1.0)   # bottom edge
	_add_line(target, b,      b + up, OUTLINE_COLOR, 1.0)   # right edge
	_add_line(target, b + up, a + up, OUTLINE_COLOR, 1.0)   # top edge
	_add_outline(target, [a + up, b + up, b + up + depth, a + up + depth],  OUTLINE_COLOR, 0.8)


func _bake_door_into(target: Node2D, base_col: Color, h_tiles: int, nw_face: bool) -> void:
	var bake_h  : int   = _viewport_h_for_key("door_ne_%d" % h_tiles)
	var wall_h  : float = WALL_H_PER_TILE * float(h_tiles)
	var res             := _wall_pts(bake_h, wall_h, nw_face)
	var a       : Vector2 = res[0]
	var b       : Vector2 = res[1]
	var up      : Vector2 = res[2]

	var depth := Vector2(-WALL_T, WALL_T * 0.4) if not nw_face \
			else Vector2(WALL_T, WALL_T * 0.4)

	# Flanking wall strips (18% of face width on each side)
	var flank  := (b - a) * 0.18
	var door_h := Vector2(0.0, -WALL_H_PER_TILE * 2.0)
	var da     := a + flank
	var db     := b - flank

	# Flanking strips: 3-band front face + top face
	for seg in [[a, da], [db, b]]:
		var fa : Vector2 = seg[0]
		var fb : Vector2 = seg[1]
		var third := up / 3.0
		var c1    := Color(base_col.r, base_col.g, base_col.b, 1.0)
		target.add_child(_make_poly([fa, fb, fb + third,      fa + third     ], c1))
		target.add_child(_make_poly([fa + third, fb + third, fb + third*2.0,  fa + third*2.0], c1.lightened(0.10)))
		target.add_child(_make_poly([fa+third*2.0, fb+third*2.0, fb + up, fa + up], c1.lightened(0.26)))
		# Top face strip on each flank
		target.add_child(_make_poly([fa + up, fb + up, fb + up + depth, fa + up + depth],
				base_col.lightened(0.45)))
		_add_outline(target, [fa + up, fb + up, fb, fa], OUTLINE_COLOR, 1.0)
		_add_outline(target, [fa + up, fb + up, fb + up + depth, fa + up + depth], OUTLINE_COLOR, 0.8)

	# Door-jamb end caps: show wall thickness at the inner edges of the opening.
	# These are drawn after the flanks so they appear in front at the opening edge.
	var jamb_col := base_col.darkened(0.35)
	target.add_child(_make_poly([da, da + up, da + up + depth, da + depth], jamb_col))
	target.add_child(_make_poly([db, db + up, db + up + depth, db + depth], jamb_col))

	# Transom above door gap (only visible for h >= 3)
	var tc := Color(base_col.r, base_col.g, base_col.b, 0.85)
	target.add_child(_make_poly([da + door_h, db + door_h, db + up, da + up], tc))

	# Outer frame outline around gap
	_add_outline(target, [da, da + up, db + up, db], OUTLINE_COLOR, 1.0)


func _bake_window_into(target: Node2D, base_col: Color, h_tiles: int,
		state: int, nw_face: bool) -> void:
	# First draw the surrounding wall face (same as _bake_wall_into)
	_bake_wall_into(target, base_col, h_tiles, nw_face)

	var bake_h  : int   = _viewport_h_for_key("win_ne_0_%d" % h_tiles)
	var wall_h  : float = WALL_H_PER_TILE * float(h_tiles)
	var res             := _wall_pts(bake_h, wall_h, nw_face)
	var a       : Vector2 = res[0]
	var b       : Vector2 = res[1]
	var up      : Vector2 = res[2]

	var margin := (b - a) * 0.18
	var wa     := a + margin
	var wb     := b - margin
	var win_lo := up * 0.28
	var win_hi := up * 0.72

	match state:
		2:  # WIN_BROKEN — dark void + shard triangles at sill
			var gc := Color(GLASS_BROKEN.r, GLASS_BROKEN.g, GLASS_BROKEN.b, 0.85)
			target.add_child(_make_poly([wa+win_lo, wb+win_lo, wb+win_hi, wa+win_hi], gc))
			var sc := Color(GLASS_COL.r*0.6, GLASS_COL.g*0.6, GLASS_COL.b*0.7, 0.6)
			var mid_ab := (wa + wb) * 0.5
			target.add_child(_make_poly([
				wa+win_lo,
				mid_ab*0.5 + wa*0.5 + win_lo + Vector2(0,-4),
				mid_ab*0.5 + wa*0.5 + win_lo], sc))
			target.add_child(_make_poly([
				wb+win_lo,
				mid_ab*0.5 + wb*0.5 + win_lo + Vector2(0,-5),
				mid_ab*0.5 + wb*0.5 + win_lo], sc))

		3:  # WIN_OPEN — dark recessed gap + sash inset lines
			var gc := Color(GLASS_BROKEN.r, GLASS_BROKEN.g, GLASS_BROKEN.b, 0.80)
			target.add_child(_make_poly([wa+win_lo, wb+win_lo, wb+win_hi, wa+win_hi], gc))
			var fc := Color(base_col.r*1.2, base_col.g*1.2, base_col.b*1.1, 0.55)
			var inset := (wb - wa) * 0.12
			_add_outline(target, [
				wa+margin*0.5+win_lo, wb-margin*0.5+win_lo,
				wb-margin*0.5+win_hi, wa+margin*0.5+win_hi], fc, 0.9)

		1:  # WIN_CRACKED — dark-tinted glass + crack lines
			var gc := Color(GLASS_COL.r*0.55, GLASS_COL.g*0.60, GLASS_COL.b*0.72, 0.55)
			target.add_child(_make_poly([wa+win_lo, wb+win_lo, wb+win_hi, wa+win_hi], gc))
			_add_outline(target, [wa+win_lo, wb+win_lo, wb+win_hi, wa+win_hi], OUTLINE_COLOR, 0.8)
			var crack_o := wa + (wb-wa)*0.45 + win_lo + (win_hi-win_lo)*0.38
			var cc       := Color(0.12, 0.10, 0.08, 0.85)
			_add_line(target, crack_o, wa+win_lo+(wb-wa)*0.08,   cc, 0.8)
			_add_line(target, crack_o, wb+win_lo-(wb-wa)*0.10,   cc, 0.8)
			_add_line(target, crack_o, wa+win_hi+(wb-wa)*0.20,   cc, 0.7)
			_add_line(target, crack_o, crack_o + up*0.22,         cc, 0.7)

		_:  # WIN_INTACT — blue glass pane + diagonal highlight
			var gc := Color(GLASS_COL.r, GLASS_COL.g, GLASS_COL.b, 0.65)
			target.add_child(_make_poly([wa+win_lo, wb+win_lo, wb+win_hi, wa+win_hi], gc))
			var hl        := Color(1.0, 1.0, 1.0, 0.18)
			var stripe_a  := wa + (wb-wa)*0.25 + win_lo
			var stripe_b  := wa + (wb-wa)*0.45 + win_hi
			_add_line(target, stripe_a, stripe_b, hl, 1.2)
			_add_outline(target, [wa+win_lo, wb+win_lo, wb+win_hi, wa+win_hi], OUTLINE_COLOR, 0.9)
