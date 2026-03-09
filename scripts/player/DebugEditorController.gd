class_name DebugEditorController
extends Node2D

## Debug-build-only in-game world editor.
## Mirrors the BuildModeController pattern: Node2D child of the local Player.
## F4 toggles the mode.  All world changes go through World debug RPCs.
## Only instantiated when OS.is_debug_build() is true (see Player._spawn()).

# ── Category constants ────────────────────────────────────────────────────────
const CAT_FLOOR     := 0
const CAT_WALL      := 1
const CAT_DOOR      := 2
const CAT_WINDOW    := 3
const CAT_FURNITURE := 4
const CAT_PROP      := 5
const CAT_ZOMBIE    := 6
const CAT_COUNT     := 7

const CAT_NAMES: Array[String] = [
	"Floor", "Wall", "Door", "Window", "Furniture", "Prop", "Zombie"
]

# ── Floor tile assets (CAT_FLOOR) ─────────────────────────────────────────────
const FLOOR_TYPES: Array[int] = [
	MapData.TILE_GRASS, MapData.TILE_ROAD, MapData.TILE_DIRT,
	MapData.TILE_FLOOR, MapData.TILE_PAVEMENT,
]
const FLOOR_NAMES: Array[String] = ["Grass", "Road", "Dirt", "Floor", "Pavement"]
const FLOOR_COLORS: Array[Color] = [
	Color(0.28, 0.44, 0.20),   # grass
	Color(0.28, 0.28, 0.28),   # road
	Color(0.55, 0.42, 0.28),   # dirt
	Color(0.44, 0.41, 0.36),   # indoor floor
	Color(0.38, 0.38, 0.36),   # pavement
]

# ── Wall directions (CAT_WALL) ────────────────────────────────────────────────
const WALL_DIRS:  Array[int]    = [MapData.DIR_N, MapData.DIR_W]
const WALL_NAMES: Array[String] = ["North/NE face", "West/NW face"]

# ── Door directions (CAT_DOOR) ────────────────────────────────────────────────
const DOOR_DIRS:  Array[int]    = [MapData.DIR_N, MapData.DIR_W]
const DOOR_NAMES: Array[String] = ["North/NE face", "West/NW face"]

# ── Window (CAT_WINDOW) ───────────────────────────────────────────────────────
const WIN_DIRS:         Array[int]    = [MapData.DIR_N, MapData.DIR_W]
const WIN_DIR_NAMES:    Array[String] = ["North/NE face", "West/NW face"]
const WIN_STATE_NAMES:  Array[String] = ["Intact", "Cracked", "Broken", "Open"]

# ── Furniture (CAT_FURNITURE) ─────────────────────────────────────────────────
const FURN_TYPES: Array[int] = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]
const FURN_NAMES: Array[String] = [
	"Bed","Desk","Chair","Table","Sofa","Shelf","Counter",
	"Stove","Locker","Nightstand","Fridge","Dresser","Bathtub","Couch","Stairs",
]
# Fallback ghost colors indexed by FURN_TYPES position (for types without a box spec)
const FURN_FALLBACK_COLORS: Array[Color] = [
	Color(0.42,0.32,0.28), Color(0.55,0.45,0.35), Color(0.55,0.45,0.35),
	Color(0.55,0.45,0.35), Color(0.42,0.32,0.28), Color(0.30,0.25,0.20),
	Color(0.35,0.28,0.22), Color(0.22,0.22,0.22), Color(0.25,0.30,0.35),
	Color(0.42,0.32,0.28), Color(0.18,0.22,0.30), Color(0.42,0.32,0.28),
	Color(0.22,0.28,0.38), Color(0.38,0.22,0.15), Color(0.52,0.46,0.36),
]

# ── Prop types (CAT_PROP) ─────────────────────────────────────────────────────
const PROP_TYPES: Array[int] = [
	MapData.PROP_TRASH_CAN, MapData.PROP_DUMPSTER, MapData.PROP_MAILBOX,
	MapData.PROP_CAR, MapData.PROP_LAMPPOST, MapData.PROP_CRATE,
	MapData.PROP_BARREL, MapData.PROP_FIRE_HYDRANT,
]
const PROP_NAMES: Array[String] = [
	"Trash Can","Dumpster","Mailbox","Car","Lamppost","Crate","Barrel","Fire Hydrant"
]
const PROP_COLORS: Array[Color] = [
	Color(0.22,0.24,0.20), Color(0.13,0.25,0.13), Color(0.18,0.22,0.50),
	Color(0.50,0.12,0.12), Color(0.38,0.38,0.36), Color(0.55,0.42,0.28),
	Color(0.30,0.20,0.10), Color(0.74,0.10,0.08),
]

# ── Zombie types (CAT_ZOMBIE) ─────────────────────────────────────────────────
const ZOMBIE_TYPES:  Array[int]    = [0, 1, 2]
const ZOMBIE_NAMES:  Array[String] = ["Regular", "Runner", "Brute"]
const ZOMBIE_COLORS: Array[Color]  = [
	Color(0.35,0.45,0.30), Color(0.65,0.30,0.20), Color(0.25,0.25,0.45),
]

# ── Ghost colours ─────────────────────────────────────────────────────────────
const GHOST_WALL_COL   := Color(0.90, 0.80, 0.30, 0.85)
const GHOST_DOOR_COL   := Color(0.90, 0.55, 0.20, 0.85)
const GHOST_WINDOW_COL := Color(0.40, 0.70, 1.00, 0.85)
const GHOST_ALPHA      := 0.55
const HUD_ON_COL       := Color(1.00, 0.30, 0.30, 0.90)

# ── Runtime state ─────────────────────────────────────────────────────────────
var _active:    bool        = false
var _player:    Player
var _world:     World
var _tilemap:   WorldTileMap
var _origin:    Vector2i

var _category:  int         = CAT_FURNITURE   # default on open
var _asset_idx: int         = 0
var _rotation:  int         = 0               # furniture rot / wall dir cycle
var _variant:   int         = 0               # window state / zombie type

# Furniture pick-up / move
var _held_furn:     int     = MapData.FURN_NONE
var _held_furn_rot: int     = 0

# Hovered tile (map-space, no origin)
var _hover_tile: Vector2i   = Vector2i.ZERO

# HUD
var _hud_layer: CanvasLayer = null
var _hud_label: Label       = null


# ── Public API ────────────────────────────────────────────────────────────────

func setup(player: Player) -> void:
	_player  = player
	_world   = player.get_tree().get_first_node_in_group("world_node") as World
	if _world:
		_tilemap = _world.tilemap
		_origin  = _world._map_data.origin_offset
	set_process_input(false)
	visible = false
	_build_hud()


func toggle() -> void:
	_active = not _active
	visible = _active
	set_process_input(_active)
	_hud_layer.visible = _active
	if not _active:
		_held_furn     = MapData.FURN_NONE
		_held_furn_rot = 0
		queue_redraw()
	else:
		# Re-cache world/tilemap in case the world loaded after setup().
		if _world == null:
			_world = _player.get_tree().get_first_node_in_group("world_node") as World
		if _world and _tilemap == null:
			_tilemap = _world.tilemap
			_origin  = _world._map_data.origin_offset
		_refresh_hud()


# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not _active or _tilemap == null:
		return

	if event is InputEventMouseMotion:
		var wp      := _screen_to_world((event as InputEventMouseMotion).global_position)
		_hover_tile  = _world_to_tile(wp)
		queue_redraw()

	elif event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if not mbe.pressed:
			return
		match mbe.button_index:
			MOUSE_BUTTON_LEFT:
				_do_place()
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_RIGHT:
				_do_erase()
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP:
				if Input.is_key_pressed(KEY_SHIFT):
					_category  = (_category + 1) % CAT_COUNT
					_asset_idx = 0
					_rotation  = 0
					_variant   = 0
				else:
					_asset_idx = (_asset_idx + 1) % _cat_size()
				_refresh_hud()
				queue_redraw()
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				if Input.is_key_pressed(KEY_SHIFT):
					_category  = (_category - 1 + CAT_COUNT) % CAT_COUNT
					_asset_idx = 0
					_rotation  = 0
					_variant   = 0
				else:
					_asset_idx = (_asset_idx - 1 + _cat_size()) % _cat_size()
				_refresh_hud()
				queue_redraw()
				get_viewport().set_input_as_handled()

	elif event is InputEventKey and event.pressed and not event.echo:
		var kc: Key = (event as InputEventKey).physical_keycode
		match kc:
			KEY_R:
				_rotation = (_rotation + 1) % 4
				_refresh_hud()
				queue_redraw()
				get_viewport().set_input_as_handled()
			KEY_T:
				_variant = (_variant + 1) % _variant_count()
				_refresh_hud()
				queue_redraw()
				get_viewport().set_input_as_handled()


# ── Place / Erase ─────────────────────────────────────────────────────────────

func _do_place() -> void:
	if _world == null:
		return
	var tx := _hover_tile.x
	var ty := _hover_tile.y

	match _category:

		CAT_FLOOR:
			_world.rpc_id(1, "rpc_debug_set_tile", tx, ty, FLOOR_TYPES[_asset_idx])

		CAT_WALL:
			_world.rpc_id(1, "rpc_debug_set_wall",
					tx, ty, WALL_DIRS[_asset_idx], true)

		CAT_DOOR:
			# edge_mode 1 = door, state 0 = place, state -1 = remove
			_world.rpc_id(1, "rpc_debug_set_edge",
					tx, ty, DOOR_DIRS[_asset_idx], 1, 0)

		CAT_WINDOW:
			_world.rpc_id(1, "rpc_debug_set_edge",
					tx, ty, WIN_DIRS[_asset_idx], 2, _variant)

		CAT_FURNITURE:
			var ftype: int
			var frot:  int
			if _held_furn != MapData.FURN_NONE:
				# Place a previously picked-up piece.
				ftype      = _held_furn
				frot       = _held_furn_rot
				_held_furn = MapData.FURN_NONE
			else:
				# If the tile already has furniture → pick it up.
				var existing := _world._map_data.get_furniture(tx, ty)
				if existing != MapData.FURN_NONE:
					_held_furn     = existing
					_held_furn_rot = _world._map_data.get_furn_rot(tx, ty)
					_world.rpc_id(1, "rpc_debug_set_furniture",
							tx, ty, MapData.FURN_NONE, 0)
					_refresh_hud()
					queue_redraw()
					return
				ftype = FURN_TYPES[_asset_idx]
				frot  = _rotation
			_world.rpc_id(1, "rpc_debug_set_furniture", tx, ty, ftype, frot)

		CAT_PROP:
			_world.rpc_id(1, "rpc_debug_set_prop",
					Vector2i(tx, ty), PROP_TYPES[_asset_idx])

		CAT_ZOMBIE:
			var cell := Vector2i(tx, ty) + _origin
			_world.rpc_id(1, "rpc_debug_spawn_zombie",
					_tilemap.map_to_local(cell), ZOMBIE_TYPES[_variant])

	_refresh_hud()
	queue_redraw()


func _do_erase() -> void:
	if _world == null:
		return

	# Cancel a furniture hold without placing.
	if _held_furn != MapData.FURN_NONE:
		_held_furn     = MapData.FURN_NONE
		_held_furn_rot = 0
		_refresh_hud()
		queue_redraw()
		return

	var tx := _hover_tile.x
	var ty := _hover_tile.y

	match _category:
		CAT_FLOOR:
			_world.rpc_id(1, "rpc_debug_set_tile", tx, ty, MapData.TILE_GRASS)
		CAT_WALL:
			_world.rpc_id(1, "rpc_debug_set_wall",
					tx, ty, WALL_DIRS[_asset_idx], false)
		CAT_DOOR:
			_world.rpc_id(1, "rpc_debug_set_edge",
					tx, ty, DOOR_DIRS[_asset_idx], 1, -1)
		CAT_WINDOW:
			_world.rpc_id(1, "rpc_debug_set_edge",
					tx, ty, WIN_DIRS[_asset_idx], 2, -1)
		CAT_FURNITURE:
			_world.rpc_id(1, "rpc_debug_set_furniture",
					tx, ty, MapData.FURN_NONE, 0)
		CAT_PROP:
			_world.rpc_id(1, "rpc_debug_set_prop", Vector2i(tx, ty), -1)
		CAT_ZOMBIE:
			pass   # zombies are removed by normal gameplay


# ── Ghost drawing ─────────────────────────────────────────────────────────────

func _draw() -> void:
	if not _active or _tilemap == null:
		return

	var center := _tile_center(_hover_tile)
	var hw     := 32.0
	var hh     := 16.0
	var pt_n   := center + Vector2(  0.0, -hh)
	var pt_e   := center + Vector2( hw,    0.0)
	var pt_s   := center + Vector2(  0.0,  hh)
	var pt_w   := center + Vector2(-hw,    0.0)
	var diamond := PackedVector2Array([pt_n, pt_e, pt_s, pt_w])

	match _category:

		CAT_FLOOR:
			var col := Color(FLOOR_COLORS[_asset_idx], GHOST_ALPHA)
			draw_colored_polygon(diamond, col)
			draw_polyline(PackedVector2Array([pt_n, pt_e, pt_s, pt_w, pt_n]),
					FLOOR_COLORS[_asset_idx].lightened(0.30), 1.5)

		CAT_WALL:
			_draw_edge_ghost(center, WALL_DIRS[_asset_idx], GHOST_WALL_COL)

		CAT_DOOR:
			_draw_edge_ghost(center, DOOR_DIRS[_asset_idx], GHOST_DOOR_COL)

		CAT_WINDOW:
			_draw_edge_ghost(center, WIN_DIRS[_asset_idx], GHOST_WINDOW_COL)
			# Small state label drawn near the edge midpoint.
			var dir    := WIN_DIRS[_asset_idx]
			var mp     := (center + (pt_e if dir == MapData.DIR_N else pt_w)) * 0.5
			draw_string(ThemeDB.fallback_font, mp + Vector2(-12, -18),
					WIN_STATE_NAMES[_variant], HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
					Color(0.9, 0.9, 0.9, 0.9))

		CAT_FURNITURE:
			var ftype := _held_furn if _held_furn != MapData.FURN_NONE \
					else FURN_TYPES[_asset_idx]
			var fi    := FURN_TYPES.find(ftype)
			var spec  := FurnitureLibrary.spec_for_furn(ftype, _rotation)
			var top_c : Color
			if spec.has("top_c"):
				top_c = Color(spec["top_c"], GHOST_ALPHA + 0.10)
			else:
				top_c = Color(FURN_FALLBACK_COLORS[maxi(fi, 0)], GHOST_ALPHA + 0.10)
			var sn    : float = spec.get("sn", 0.45)
			var n2    := center + Vector2(  0.0, -hh * sn)
			var e2    := center + Vector2( hw * sn,  0.0)
			var s2    := center + Vector2(  0.0,  hh * sn)
			var w2    := center + Vector2(-hw * sn,  0.0)
			draw_colored_polygon(PackedVector2Array([n2, e2, s2, w2]),
					Color(top_c, GHOST_ALPHA))
			draw_polyline(PackedVector2Array([n2, e2, s2, w2, n2]),
					top_c.lightened(0.25), 1.5)
			# Held-piece indicator
			if _held_furn != MapData.FURN_NONE:
				draw_circle(center + Vector2(0.0, -hh - 6.0), 4.0,
						Color(1.0, 0.9, 0.2, 0.9))

		CAT_PROP:
			var pcol := Color(PROP_COLORS[_asset_idx], GHOST_ALPHA)
			var sp   := 0.28
			var n2   := center + Vector2(  0.0, -hh * sp)
			var e2   := center + Vector2( hw * sp,  0.0)
			var s2   := center + Vector2(  0.0,  hh * sp)
			var w2   := center + Vector2(-hw * sp,  0.0)
			draw_colored_polygon(PackedVector2Array([n2, e2, s2, w2]), pcol)
			draw_polyline(PackedVector2Array([n2, e2, s2, w2, n2]),
					PROP_COLORS[_asset_idx].lightened(0.22), 1.5)

		CAT_ZOMBIE:
			var zcol := Color(ZOMBIE_COLORS[_variant], GHOST_ALPHA + 0.10)
			draw_circle(center, 10.0, zcol)
			draw_arc(center, 10.0, 0.0, TAU, 12, zcol.lightened(0.28), 1.5)
			# Dot color encodes type.
			var dot_cols: Array[Color] = [
				Color(0.85, 0.85, 0.85),   # regular — white
				Color(1.00, 0.40, 0.20),   # runner  — orange
				Color(0.50, 0.50, 1.00),   # brute   — blue
			]
			draw_circle(center + Vector2(0.0, -13.0), 3.5, dot_cols[_variant])

	# Red indicator dot above player head (always drawn when active).
	draw_circle(Vector2(0.0, -28.0), 5.0, HUD_ON_COL)


func _draw_edge_ghost(center: Vector2, dir: int, col: Color) -> void:
	var hw  := 32.0
	var hh  := 16.0
	var pt_n := center + Vector2(  0.0, -hh)
	var pt_e := center + Vector2( hw,    0.0)
	var pt_w := center + Vector2(-hw,    0.0)
	var up   := Vector2(0.0, -32.0)
	if dir == MapData.DIR_N:   # NE face
		draw_line(pt_n, pt_e, col, 3.0)
		draw_colored_polygon(PackedVector2Array([pt_n, pt_e, pt_e + up, pt_n + up]),
				Color(col, 0.20))
	else:                      # NW face  (DIR_W)
		draw_line(pt_n, pt_w, col, 3.0)
		draw_colored_polygon(PackedVector2Array([pt_n, pt_w, pt_w + up, pt_n + up]),
				Color(col, 0.20))


# ── HUD ───────────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	_hud_layer         = CanvasLayer.new()
	_hud_layer.layer   = 15          # above normal HUD (layer 10)
	_hud_layer.visible = false
	add_child(_hud_layer)

	var panel                  := PanelContainer.new()
	panel.anchor_left           = 1.0
	panel.anchor_right          = 1.0
	panel.anchor_top            = 0.0
	panel.anchor_bottom         = 0.0
	panel.grow_horizontal       = Control.GROW_DIRECTION_BEGIN
	panel.offset_left           = -324.0
	panel.offset_right          = -4.0
	panel.offset_top            = 4.0
	panel.offset_bottom         = 0.0   # auto-sized by content
	_hud_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "[ DEBUG EDITOR ]"
	title.add_theme_color_override("font_color", Color(1.0, 0.40, 0.40))
	vbox.add_child(title)

	_hud_label = Label.new()
	_hud_label.text = ""
	vbox.add_child(_hud_label)

	var keys := Label.new()
	keys.text = (
		"LMB: Place    RMB: Erase / cancel hold\n"
		+ "Scroll: Cycle asset    Shift+Scroll: Category\n"
		+ "R: Rotate / direction    T: Variant / state"
	)
	keys.add_theme_font_size_override("font_size", 10)
	keys.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	vbox.add_child(keys)


func _refresh_hud() -> void:
	if _hud_label == null:
		return
	var cat    := CAT_NAMES[_category]
	var asset  := _asset_label()
	_hud_label.text = "%s  >  %s" % [cat, asset]


func _asset_label() -> String:
	match _category:
		CAT_FLOOR:
			return FLOOR_NAMES[_asset_idx]
		CAT_WALL:
			return WALL_NAMES[_asset_idx]
		CAT_DOOR:
			return DOOR_NAMES[_asset_idx]
		CAT_WINDOW:
			return "%s  [%s]" % [WIN_DIR_NAMES[_asset_idx], WIN_STATE_NAMES[_variant]]
		CAT_FURNITURE:
			if _held_furn != MapData.FURN_NONE:
				var fi  := FURN_TYPES.find(_held_furn)
				var fn  := FURN_NAMES[fi] if fi >= 0 else "?"
				return "(held) %s  rot=%d" % [fn, _held_furn_rot]
			return "%s  rot=%d" % [FURN_NAMES[_asset_idx], _rotation]
		CAT_PROP:
			return PROP_NAMES[_asset_idx]
		CAT_ZOMBIE:
			return ZOMBIE_NAMES[_variant]
	return ""


# ── Helpers ───────────────────────────────────────────────────────────────────

func _cat_size() -> int:
	match _category:
		CAT_FLOOR:     return FLOOR_TYPES.size()
		CAT_WALL:      return WALL_DIRS.size()
		CAT_DOOR:      return DOOR_DIRS.size()
		CAT_WINDOW:    return WIN_DIRS.size()
		CAT_FURNITURE: return FURN_TYPES.size()
		CAT_PROP:      return PROP_TYPES.size()
		CAT_ZOMBIE:    return ZOMBIE_TYPES.size()
	return 1


func _variant_count() -> int:
	match _category:
		CAT_WINDOW: return 4   # WIN_INTACT … WIN_OPEN
		CAT_ZOMBIE: return 3   # REGULAR / RUNNER / BRUTE
	return 1


func _tile_center(tile: Vector2i) -> Vector2:
	if _tilemap == null:
		return Vector2.ZERO
	return _tilemap.map_to_local(tile + _origin) - global_position


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return _player.get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _world_to_tile(world_pos: Vector2) -> Vector2i:
	# Inverse of isometric map_to_local (TILE_W=64, TILE_H=32).
	var tx := int(floor((world_pos.x / 32.0 + world_pos.y / 16.0) * 0.5))
	var ty := int(floor((world_pos.y / 16.0 - world_pos.x / 32.0) * 0.5))
	return Vector2i(tx, ty) - _origin
