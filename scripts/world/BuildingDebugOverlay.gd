class_name BuildingDebugOverlay
extends Node2D

## F3 toggle.  Draws wall edges, door edges, window edges, room IDs,
## and furniture footprints directly in world space.
## Add a single instance to the World scene via World._generate_map().

const C_WALL    := Color(0.20, 1.00, 0.25, 0.90)   # green  — normal walls
const C_DOOR    := Color(1.00, 0.85, 0.10, 0.95)   # yellow — door edges
const C_WINDOW  := Color(0.25, 0.70, 1.00, 0.90)   # blue   — window edges
const C_FURN    := Color(1.00, 0.45, 0.10, 0.85)   # orange — furniture
const C_ROOM_ID := Color(1.00, 1.00, 1.00, 0.80)   # white  — room label
const C_PLAYER  := Color(1.00, 0.20, 0.20, 0.80)   # red    — player-built walls

const WALL_H := 96.0   # visual height for edge lines (3 tiles × 32 px)

var _data:    MapData
var _tilemap: WorldTileMap
var _origin:  Vector2i
var _enabled: bool = false
var _chunk_manager: ChunkManager


func setup(data: MapData, tilemap: WorldTileMap, origin: Vector2i, chunk_manager: ChunkManager = null) -> void:
	_data          = data
	_tilemap       = tilemap
	_origin        = origin
	_chunk_manager = chunk_manager
	visible        = false



func _process(_delta: float) -> void:
	if _enabled:
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed \
			and not (event as InputEventKey).echo:
		if (event as InputEventKey).physical_keycode == KEY_F3:
			_enabled = not _enabled
			visible  = _enabled
			queue_redraw()


func _draw() -> void:
	if not _enabled or _data == null:
		return

	var up := Vector2(0.0, -WALL_H)

	# ── Wall / door / window edges ────────────────────────────────────────────
	for ty in range(_data.map_height):
		for tx in range(_data.map_width):
			var flags := _data.get_wall(tx, ty)
			if flags == 0:
				continue

			var center := _tilemap.map_to_local(Vector2i(tx, ty) + _origin) - position
			var pt_n   := center + Vector2(  0.0, -16.0)
			var pt_e   := center + Vector2( 32.0,   0.0)
			var pt_w   := center + Vector2(-32.0,   0.0)
			var is_player_built := bool(flags & MapData.PLAYER_BUILT)

			if flags & MapData.WALL_N:
				var ek  := Vector3i(tx, ty, MapData.DIR_N)
				var col := _edge_color(ek, is_player_built)
				draw_line(pt_n, pt_e, col, 2.0)
				draw_line(pt_n + up, pt_e + up, col, 1.0)
				draw_line(pt_n, pt_n + up, col, 1.0)
				draw_line(pt_e, pt_e + up, col, 1.0)

			if flags & MapData.WALL_W:
				var ek  := Vector3i(tx, ty, MapData.DIR_W)
				var col := _edge_color(ek, is_player_built)
				draw_line(pt_n, pt_w, col, 2.0)
				draw_line(pt_n + up, pt_w + up, col, 1.0)
				draw_line(pt_n, pt_n + up, col, 1.0)
				draw_line(pt_w, pt_w + up, col, 1.0)

	# ── Furniture footprints ─────────────────────────────────────────────────
	for ty in range(_data.map_height):
		for tx in range(_data.map_width):
			var furn := _data.get_furniture(tx, ty)
			if furn == MapData.FURN_NONE:
				continue
			var center := _tilemap.map_to_local(Vector2i(tx, ty) + _origin) - position
			draw_rect(Rect2(center - Vector2(14.0, 10.0), Vector2(28.0, 20.0)),
			          C_FURN, false, 1.5)
			draw_string(ThemeDB.fallback_font, center + Vector2(-6.0, 4.0),
			            str(furn), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, C_FURN)

	# ── Room IDs ──────────────────────────────────────────────────────────────
	for bp: BuildingBlueprint in _data.building_blueprints:
		for room: BuildingBlueprint.RoomDef in bp.rooms:
			var r      := room.bounds
			var center_tile := Vector2i(
				r.position.x + r.size.x / 2,
				r.position.y + r.size.y / 2)
			var screen_pos := _tilemap.map_to_local(center_tile + _origin) - position
			var label      := "R%d" % room.id
			draw_string(ThemeDB.fallback_font, screen_pos + Vector2(-10.0, 4.0),
			            label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_ROOM_ID)

	# ── Chunk telemetry ───────────────────────────────────────────────────────
	if _chunk_manager != null:
		var snap := _chunk_manager.get_debug_snapshot()
		var text := "Chunks A:%d L:%d T:%d" % [
			snap.get("active_count", 0),
			snap.get("loaded_count", 0),
			snap.get("total_count", 0),
		]
		var events: Array = snap.get("recent_events", [])
		var tail := events.back() if not events.is_empty() else "none"
		draw_rect(Rect2(Vector2(10, 10), Vector2(270, 30)), Color(0.05, 0.05, 0.05, 0.70), true)
		draw_string(ThemeDB.fallback_font, Vector2(14, 22), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.95, 0.95, 0.95))
		draw_string(ThemeDB.fallback_font, Vector2(14, 34), "Last: %s" % tail, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.82, 0.82, 0.82, 0.92))


func _edge_color(ek: Vector3i, player_built: bool) -> Color:
	if player_built:
		return C_PLAYER
	if _data.door_edges.has(ek):
		return C_DOOR
	if _data.window_edges.has(ek):
		return C_WINDOW
	return C_WALL
