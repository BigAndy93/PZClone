class_name BuildingTileRenderer
extends Node2D

## Sprite-based building renderer.  All geometry is baked into ImageTextures at
## startup by BuildingComponentBaker (walls/doors/windows/floor) and FurnitureBaker
## (furniture).  During setup() each component is instantiated as a Sprite2D child.
## Visibility transitions (cutaway) are achieved purely by tweening sprite.modulate.a
## — no canvas redraw is ever triggered at runtime.
##
## 4-direction wall coverage using flip_h:
##   N-edge → wall_ne_{h}  (right-leaning NE face)
##   W-edge → wall_nw_{h}  (left-leaning  NW face)
##   S-edge → wall_ne_{h} + flip_h  (mirrored NE = SE face)
##   E-edge → wall_nw_{h} + flip_h  (mirrored NW = SW face)


const WALL_H_PER_TILE  : float = 32.0
const UNEXPLORED_ALPHA : float = 0.0   # target alpha for rooms not yet entered

# Baseboard strip drawn at the base of every wall face.
# Stays partially visible when the wall above is cut away (occlusion hint).
const BASEBOARD_H         : float = 3.0    # screen-pixel height of the strip
const BASEBOARD_MIN_ALPHA : float = 0.35   # alpha floor when wall is fully faded
const BASEBOARD_NE_COL    := Color(0.22, 0.20, 0.17, 1.0)   # dark  (NE shadow face)
const BASEBOARD_NW_COL    := Color(0.38, 0.35, 0.28, 1.0)   # light (NW lit face)

# Tall furniture types that receive extra fade when inside (System 6)
const TALL_FURN := [
	MapData.FURN_SHELF, MapData.FURN_LOCKER, MapData.FURN_COUNTER,
	MapData.FURN_FRIDGE, MapData.FURN_COUCH,
]


var _bp:          BuildingBlueprint
var _data:        MapData
var _tilemap:     WorldTileMap
var _origin:      Vector2i
var _pos_outside: Vector2   # SW corner — correct y-sort when player is outside
var _pos_inside:  Vector2   # NW corner — correct y-sort when player is inside


# ── Multi-layer visibility state ─────────────────────────────────────────────────
var tile_to_room:          Dictionary = {}   # Vector2i → int room_id
var _target_room_alphas:   Dictionary = {}   # room_id → float
var _current_room_alphas:  Dictionary = {}   # room_id → float
var _target_front_alpha:   float = 1.0
var _current_front_alpha:  float = 1.0
var _target_furn_alpha:    float = 1.0
var _current_furn_alpha:   float = 1.0
var _is_inside:            bool     = false
var _player_tile:          Vector2i = Vector2i(-1, -1)
var _explored_rooms:       Dictionary = {}   # room_id (int) → true

const LERP_RATE:   float = 0.15
const LERP_THRESH: float = 0.005


# ── Sprite collections ───────────────────────────────────────────────────────────
# Wall entry: {sprite, rid_a, rid_b, is_front, edge_key, is_window}
var _wall_sprites:      Array = []
# Baseboard entry: {poly, rid_a, rid_b, is_front, nw_face, tile_x, tile_y}
var _baseboard_sprites: Array = []
# Furn entry: {sprite, rid, is_tall}
var _furn_sprites:      Array = []
# Floor entry: {sprite, rid}
var _floor_sprites:     Array = []


func _ready() -> void:
	set_process(false)


# ── Setup ────────────────────────────────────────────────────────────────────────

func setup(bp: BuildingBlueprint, data: MapData,
		tilemap: WorldTileMap, origin: Vector2i) -> void:
	_bp      = bp
	_data    = data
	_tilemap = tilemap
	_origin  = origin
	var r    := bp.bounds
	_pos_outside = tilemap.map_to_local(Vector2i(r.position.x, r.end.y) + origin)
	_pos_inside  = tilemap.map_to_local(Vector2i(r.position.x, r.position.y) + origin)
	position = _pos_outside
	_build_room_lookup()
	_spawn_wall_sprites()
	_spawn_floor_sprites()
	_spawn_furn_sprites()


## Backwards-compatible shim — kept for any legacy call sites.
func set_cutaway(inside: bool) -> void:
	set_visibility_data(-1, [], inside)


## Primary visibility API called by World._update_building_cutaway().
func set_visibility_data(player_room_id: int, adjacent_ids: Array, inside: bool,
		player_tile: Vector2i = Vector2i(-1, -1)) -> void:
	_is_inside    = inside
	_player_tile  = player_tile

	# Switch y-sort anchor.  Child sprites live in local space, so compensate
	# their positions by the inverse delta to keep world positions unchanged.
	var old_pos := position
	position    = _pos_inside if inside else _pos_outside
	var delta   := old_pos - position
	if delta != Vector2.ZERO:
		for entry in _wall_sprites:
			entry["sprite"].position += delta
		for entry in _baseboard_sprites:
			entry["poly"].position += delta
		for entry in _floor_sprites:
			entry["sprite"].position += delta
		for entry in _furn_sprites:
			entry["sprite"].position += delta

	if not inside:
		for rid: int in _target_room_alphas:
			_target_room_alphas[rid] = 1.0
		_target_front_alpha = 1.0
		_target_furn_alpha  = 1.0
	else:
		# Mark the room the player is standing in as explored.
		if player_room_id >= 0:
			_explored_rooms[player_room_id] = true
		# Binary alpha: explored rooms = 1.0, unexplored = 0.0.
		for rid: int in _target_room_alphas:
			_target_room_alphas[rid] = 1.0 if is_room_explored(rid) else UNEXPLORED_ALPHA
		_target_front_alpha = 0.0
		_target_furn_alpha  = 0.50

	# Show/hide floor and furniture sprites immediately
	for entry in _floor_sprites:
		entry["sprite"].visible = inside
	for entry in _furn_sprites:
		entry["sprite"].visible = inside

	set_process(true)


## Call when a window state changes (broken/open) to swap in the correct baked texture.
## ek is the canonical edge key (Vector3i) from MapData.edge_key().
func refresh_window_sprites() -> void:
	for entry in _wall_sprites:
		if not entry["is_window"]:
			continue
		var ek    : Vector3i = entry["edge_key"]
		var state : int      = _data.window_edges.get(ek, MapData.WIN_INTACT)
		var h_str : String   = str(_bp.height_tiles)
		var face  : String   = "ne" if not entry.get("nw_face", false) else "nw"
		var key   : String   = "win_%s_%d_%s" % [face, state, h_str]
		var spr   : Sprite2D = entry["sprite"]
		if BuildingComponentBaker.has_component(key):
			spr.texture = BuildingComponentBaker._cache[key]


## Delegates to BuildingBlueprint.contains_point_world.
func contains_point_world(world_pos: Vector2) -> bool:
	return _bp.contains_point_world(world_pos, _tilemap, _origin)


# ── Per-frame lerp ────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	var changed := false

	# Room alphas
	for rid: int in _current_room_alphas:
		var t: float = _target_room_alphas.get(rid, 1.0)
		var c: float = _current_room_alphas[rid]
		var n: float = lerpf(c, t, LERP_RATE)
		if abs(n - c) > LERP_THRESH:
			_current_room_alphas[rid] = n
			changed = true
		else:
			_current_room_alphas[rid] = t

	# Front alpha
	var nf: float = lerpf(_current_front_alpha, _target_front_alpha, LERP_RATE)
	if abs(nf - _current_front_alpha) > LERP_THRESH:
		_current_front_alpha = nf
		changed = true
	else:
		_current_front_alpha = _target_front_alpha

	# Furn alpha
	var nfu: float = lerpf(_current_furn_alpha, _target_furn_alpha, LERP_RATE)
	if abs(nfu - _current_furn_alpha) > LERP_THRESH:
		_current_furn_alpha = nfu
		changed = true
	else:
		_current_furn_alpha = _target_furn_alpha

	if changed:
		_apply_sprite_alphas()
	else:
		_apply_sprite_alphas()  # ensure final exact values are applied
		set_process(false)


func _apply_sprite_alphas() -> void:
	var b := _bp.bounds

	# Wall sprites
	for entry in _wall_sprites:
		var alpha: float = _wall_alpha_from_entry(entry, b)
		entry["sprite"].modulate.a = alpha

	# Baseboard strips — follow wall alpha but stay visible at BASEBOARD_MIN_ALPHA
	for entry in _baseboard_sprites:
		entry["poly"].modulate.a = _baseboard_alpha_from_entry(entry, b)

	# Floor sprites — alpha driven by room exploration state.
	for entry in _floor_sprites:
		var spr: Sprite2D = entry["sprite"]
		if not spr.visible:
			continue
		var rid: int  = entry["rid"]
		var ra: float = _current_room_alphas.get(rid, 1.0) if rid >= 0 else 1.0
		spr.modulate.a = ra

	# Furniture sprites (only when visible)
	# Only fade furniture that is at or in front of the player in isometric depth
	# (tile.x + tile.y >= player.x + player.y). Furniture behind the player stays
	# fully opaque — it doesn't occlude the player character.
	var p_depth: int = _player_tile.x + _player_tile.y
	for entry in _furn_sprites:
		var spr: Sprite2D = entry["sprite"]
		if not spr.visible:
			continue
		var tile: Vector2i = entry["tile"]
		if _player_tile.x >= 0 and (tile.x + tile.y) < p_depth:
			spr.modulate.a = 1.0
			continue
		var rid: int  = entry["rid"]
		var ra: float = _current_room_alphas.get(rid, 1.0) if rid >= 0 else 1.0
		var fa: float = minf(ra, _current_furn_alpha) if entry["is_tall"] else ra
		spr.modulate.a = fa


# ── Alpha helpers ─────────────────────────────────────────────────────────────────

func _wall_alpha_from_entry(entry: Dictionary, _b: Rect2i) -> float:
	# Front-facing exterior walls (south/east) fade completely when inside.
	if entry["is_front"]:
		return _current_front_alpha

	# Interior walls that stand between the player and the camera also fade.
	# DIR_N wall (nw_face=false) at row tile_y occludes the player when
	#   the player's tile is north of the wall (player_tile.y < tile_y).
	# DIR_W wall (nw_face=true) at col tile_x occludes the player when
	#   the player's tile is west of the wall (player_tile.x < tile_x).
	if _is_inside and _player_tile.x >= 0:
		var occluding: bool
		if entry["nw_face"]:
			occluding = _player_tile.x < entry["tile_x"]
		else:
			occluding = _player_tile.y < entry["tile_y"]
		if occluding:
			return _current_front_alpha

	# Otherwise: visible if EITHER adjacent room is explored.
	# max() ensures boundary walls between explored+unexplored rooms stay visible.
	var aa: float = _current_room_alphas.get(entry["rid_a"], 1.0) \
					if entry["rid_a"] >= 0 else 1.0
	var ab: float = _current_room_alphas.get(entry["rid_b"], 1.0) \
					if entry["rid_b"] >= 0 else 1.0
	return maxf(aa, ab)


## Baseboard alpha: same as the wall, but clamped to BASEBOARD_MIN_ALPHA when the
## wall is faded (cut-away) so a thin hint strip remains visible.
## Respects room exploration: if neither adjacent room is explored the strip is hidden.
func _baseboard_alpha_from_entry(entry: Dictionary, b: Rect2i) -> float:
	var aa: float = _current_room_alphas.get(entry["rid_a"], 1.0) \
					if entry["rid_a"] >= 0 else 1.0
	var ab: float = _current_room_alphas.get(entry["rid_b"], 1.0) \
					if entry["rid_b"] >= 0 else 1.0
	var room_alpha := maxf(aa, ab)
	# If the room(s) are unexplored the baseboard is fully hidden.
	# Otherwise take the larger of: the normal wall alpha, or the minimum hint alpha.
	return maxf(_wall_alpha_from_entry(entry, b), room_alpha * BASEBOARD_MIN_ALPHA)


# ── Room lookup (used by World.gd externally via tile_to_room) ───────────────────

func _build_room_lookup() -> void:
	tile_to_room.clear()
	_target_room_alphas.clear()
	_current_room_alphas.clear()
	_explored_rooms.clear()
	if _bp == null:
		return
	for room: BuildingBlueprint.RoomDef in _bp.rooms:
		_target_room_alphas[room.id]  = 1.0
		_current_room_alphas[room.id] = 1.0
		for cell: Vector2i in room.floor_cells:
			tile_to_room[cell] = room.id


## Returns true if the given room has been entered by the local player this session.
## room_id < 0 (exterior/unassigned) is always treated as explored.
func is_room_explored(room_id: int) -> bool:
	return room_id < 0 or _explored_rooms.get(room_id, false)


# ── Spawn helpers ─────────────────────────────────────────────────────────────────

## Returns the map-relative tile position in local node space (without _origin offset
## for the blueprint lookup, same as old _cell_local).
func _cell_local(tx: int, ty: int) -> Vector2:
	return _tilemap.map_to_local(Vector2i(tx, ty) + _origin) - position


func _spawn_wall_sprites() -> void:
	var b        := _bp.bounds
	var h_tiles  : int   = _bp.height_tiles
	var h_str    : String = str(h_tiles)

	for ty in range(b.position.y, b.end.y + 1):
		for tx in range(b.position.x, b.end.x + 1):
			var local_c := _cell_local(tx, ty)

			# ── DIR_N edge (NE face / right-leaning) ────────────────────────
			var ek_n := MapData.edge_key(tx, ty, MapData.DIR_N)
			var has_wall_n := _data.has_wall_edge(tx, ty, MapData.DIR_N)
			var has_door_n := _data.door_edges.has(ek_n)
			var has_win_n  := _data.window_edges.has(ek_n)

			if has_wall_n or has_door_n:
				var key := ""
				var is_win := false
				if has_door_n:
					key = "door_ne_%s" % h_str
				elif has_win_n:
					var st: int = _data.window_edges[ek_n]
					key = "win_ne_%d_%s" % [st, h_str]
					is_win = true
				else:
					key = "wall_ne_%s" % h_str

				# S-edge of tile (ty-1) maps to this same NE face, mirrored
				# Normal N-edge: flip_h = false
				_add_wall_sprite(key, local_c, false, tx, ty, MapData.DIR_N,
					b, ek_n, is_win, false, h_str)

			# ── DIR_W edge (NW face / left-leaning) ─────────────────────────
			var ek_w := MapData.edge_key(tx, ty, MapData.DIR_W)
			var has_wall_w := _data.has_wall_edge(tx, ty, MapData.DIR_W)
			var has_door_w := _data.door_edges.has(ek_w)
			var has_win_w  := _data.window_edges.has(ek_w)

			if has_wall_w or has_door_w:
				var key := ""
				var is_win := false
				if has_door_w:
					key = "door_nw_%s" % h_str
				elif has_win_w:
					var st: int = _data.window_edges[ek_w]
					key = "win_nw_%d_%s" % [st, h_str]
					is_win = true
				else:
					key = "wall_nw_%s" % h_str

				_add_wall_sprite(key, local_c, false, tx, ty, MapData.DIR_W,
					b, ek_w, is_win, true, h_str)


func _add_wall_sprite(key: String, local_c: Vector2, flip_h: bool,
		tx: int, ty: int, dir: int, b: Rect2i,
		ek: Vector3i, is_win: bool, nw_face: bool, _h_str: String) -> void:
	if not BuildingComponentBaker.has_component(key):
		return
	var spr := BuildingComponentBaker.get_sprite(key, local_c, flip_h)
	# Depth-sort: walls sit half-step in front of the tile to their north/west
	# and half-step behind the tile they belong to.  (tx+ty)*2-1 places them
	# between the two flanking tile layers.
	spr.z_index = (tx + ty) * 2 - 1
	add_child(spr)

	# Room IDs on each side of this wall edge
	var ta := Vector2i(tx, ty - 1) if dir == MapData.DIR_N else Vector2i(tx - 1, ty)
	var tb := Vector2i(tx, ty)
	var rid_a: int = tile_to_room.get(ta, -1)
	var rid_b: int = tile_to_room.get(tb, -1)

	# Camera-facing exterior walls (south and east building boundary)
	var is_front := (dir == MapData.DIR_N and ty == b.end.y) \
				 or (dir == MapData.DIR_W and tx == b.end.x)

	_wall_sprites.append({
		"sprite":   spr,
		"rid_a":    rid_a,
		"rid_b":    rid_b,
		"is_front": is_front,
		"edge_key": ek,
		"is_window": is_win,
		"nw_face":  nw_face,
		"tile_x":   tx,
		"tile_y":   ty,
	})

	# Baseboard strip — thin isometric parallelogram at the floor edge of this wall face.
	# NE face (nw_face=false): base runs from pt_n=(0,-16) → pt_e=(+32,0) relative to local_c.
	# NW face (nw_face=true):  base runs from pt_n=(0,-16) → pt_w=(-32,0) relative to local_c.
	var board_a  := Vector2(0.0, -16.0)
	var board_b  := Vector2(-32.0, 0.0) if nw_face else Vector2(32.0, 0.0)
	var board_col: Color = BASEBOARD_NW_COL if nw_face else BASEBOARD_NE_COL
	var board            := Polygon2D.new()
	board.polygon         = PackedVector2Array([
		board_a,
		board_b,
		board_b + Vector2(0.0, -BASEBOARD_H),
		board_a + Vector2(0.0, -BASEBOARD_H),
	])
	board.color           = board_col
	board.position        = local_c
	board.z_index         = (tx + ty) * 2 - 1
	add_child(board)
	_baseboard_sprites.append({
		"poly":     board,
		"rid_a":    rid_a,
		"rid_b":    rid_b,
		"is_front": is_front,
		"nw_face":  nw_face,
		"tile_x":   tx,
		"tile_y":   ty,
	})


func _spawn_floor_sprites() -> void:
	if not BuildingComponentBaker.has_component("floor"):
		return
	for cell_key in _bp.floor_cells:
		var cell    := cell_key as Vector2i
		var local_c := _cell_local(cell.x, cell.y)
		var spr     := BuildingComponentBaker.get_sprite("floor", local_c)
		spr.z_index  = 0
		spr.visible  = false
		var rid: int = tile_to_room.get(cell, -1)
		_floor_sprites.append({"sprite": spr, "rid": rid})
		add_child(spr)


func _spawn_furn_sprites() -> void:
	var b           := _bp.bounds
	var sheet_specs := FurnitureLibrary.get_sprite_sheet_specs()
	for ty in range(b.position.y, b.end.y):
		for tx in range(b.position.x, b.end.x):
			var furn: int = _data.get_furniture(tx, ty)
			if furn == MapData.FURN_NONE:
				continue
			var rot:     int      = _data.get_furn_rot(tx, ty)
			var local_c: Vector2  = _cell_local(tx, ty)
			var rid:     int      = tile_to_room.get(Vector2i(tx, ty), -1)
			var is_tall: bool     = furn in TALL_FURN

			# ── Sprite-sheet furniture (e.g. FURN_COUCH) ─────────────────────
			if sheet_specs.has(furn):
				var sd: Dictionary = sheet_specs[furn]
				var tex: Texture2D = FurnitureLibrary.load_sheet_texture(sd["path"])
				if tex == null:
					continue
				var fw:    int     = tex.get_width()  / sd["frame_cols"]
				var fh:    int     = tex.get_height() / sd["frame_rows"]
				var rf: Vector2i   = sd["rot_frames"].get(rot, Vector2i(0, 0))
				var atlas          := AtlasTexture.new()
				atlas.atlas         = tex
				atlas.region        = Rect2(rf.x * fw, rf.y * fh, fw, fh)
				var sc:    float   = sd["scale"]
				var af:    Vector2 = sd["anchor_frac"]
				var spr            := Sprite2D.new()
				spr.texture         = atlas
				spr.centered        = false
				spr.texture_filter  = CanvasItem.TEXTURE_FILTER_NEAREST
				spr.position        = local_c + Vector2(-af.x * fw, -af.y * fh) * sc
				spr.scale           = Vector2(sc, sc)
				spr.z_index         = (tx + ty) * 2
				spr.visible         = false
				_furn_sprites.append({"sprite": spr, "rid": rid, "is_tall": is_tall, "tile": Vector2i(tx, ty)})
				add_child(spr)
				continue

			# ── Procedurally baked furniture ──────────────────────────────────
			var spec: Dictionary = FurnitureLibrary.spec_for_furn(furn, rot)
			if spec.is_empty():
				continue

			var key: String = FurnitureBaker.box_key(
				spec["sn"], spec["se"], spec["h"],
				spec["top_c"], spec["side_c"], rot)

			if not FurnitureBaker.has_texture(key):
				continue

			# Compute nv/ev for this rotation (mirrors FurnitureBaker._bake_box_into)
			var nv: Vector2
			var ev: Vector2
			match rot:
				1:
					nv = FurnitureBaker.BAKE_EV * spec["sn"]
					ev = Vector2(0.0, -FurnitureBaker.BAKE_NV.y) * spec["se"]
				2:
					nv = -FurnitureBaker.BAKE_NV * spec["sn"]
					ev = -FurnitureBaker.BAKE_EV * spec["se"]
				3:
					nv = -FurnitureBaker.BAKE_EV * spec["sn"]
					ev = Vector2(0.0, FurnitureBaker.BAKE_NV.y) * spec["se"]
				_:
					nv = FurnitureBaker.BAKE_NV * spec["sn"]
					ev = FurnitureBaker.BAKE_EV * spec["se"]

			var spr     := FurnitureBaker.make_sprite(key, nv, ev, local_c, rot)
			spr.z_index  = (tx + ty) * 2
			spr.visible  = false

			_furn_sprites.append({
				"sprite":  spr,
				"rid":     rid,
				"is_tall": is_tall,
				"tile":    Vector2i(tx, ty),
			})
			add_child(spr)
