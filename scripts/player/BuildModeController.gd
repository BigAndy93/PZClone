class_name BuildModeController
extends Node2D

## Client-only Node2D attached to the local Player.
## B-key toggles build mode.  LMB drag places a row of WALL_N edges;
## RMB drag places a column of WALL_W edges.
## Ghost preview is drawn via _draw() in this node's local space.

const GHOST_N_COL := Color(0.25, 0.85, 1.00, 0.80)   # cyan  — WALL_N ghost
const GHOST_W_COL := Color(0.30, 1.00, 0.55, 0.80)   # green — WALL_W ghost
const HUD_ON_COL  := Color(1.00, 0.90, 0.20, 0.90)   # yellow indicator dot

const MAX_DRAG_TILES := 40   # safety cap on wall length per drag

var _active:  bool = false
var _player:  Player
var _tilemap: WorldTileMap
var _origin:  Vector2i

# Drag state
var _dragging:    bool         = false
var _drag_start:  Vector2i     = Vector2i.ZERO
var _wall_dir:    int          = MapData.DIR_N
var _ghost_edges: Array        = []   # each entry: [tx, ty, dir]

# Hover (non-drag) preview
var _hover_tile:  Vector2i     = Vector2i.ZERO
var _hover_dir:   int          = MapData.DIR_N


func setup(player: Player) -> void:
	_player = player
	var world := player.get_tree().get_first_node_in_group("world_node") as World
	if world:
		_tilemap = world.tilemap
		_origin  = world._map_data.origin_offset
	set_process_input(false)
	visible = false


func toggle() -> void:
	_active = not _active
	visible = _active
	set_process_input(_active)
	if not _active:
		_dragging    = false
		_ghost_edges = []
		queue_redraw()


# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not _active or _tilemap == null:
		return

	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if mbe.button_index == MOUSE_BUTTON_LEFT:
			if mbe.pressed:
				_start_drag(mbe.global_position, MapData.DIR_N)
			else:
				_end_drag()
			get_viewport().set_input_as_handled()
		elif mbe.button_index == MOUSE_BUTTON_RIGHT:
			if mbe.pressed:
				_start_drag(mbe.global_position, MapData.DIR_W)
			else:
				_end_drag()
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		var mot := event as InputEventMouseMotion
		if _dragging:
			_extend_drag(mot.global_position)
		else:
			_update_hover(mot.global_position)
		queue_redraw()


# ── Drag logic ────────────────────────────────────────────────────────────────

func _start_drag(screen_pos: Vector2, dir: int) -> void:
	var wp        := _screen_to_world(screen_pos)
	_drag_start    = _world_to_tile(wp)
	_wall_dir      = dir
	_dragging      = true
	_ghost_edges   = [[_drag_start.x, _drag_start.y, dir]]
	queue_redraw()


func _extend_drag(screen_pos: Vector2) -> void:
	var wp       := _screen_to_world(screen_pos)
	var tile_end := _world_to_tile(wp)
	var delta    := tile_end - _drag_start

	_ghost_edges = []

	if _wall_dir == MapData.DIR_N:
		# Horizontal row: fixed ty, vary tx.
		var step := signi(delta.x) if delta.x != 0 else 1
		var tx   := _drag_start.x
		while true:
			_ghost_edges.append([tx, _drag_start.y, MapData.DIR_N])
			if tx == tile_end.x or _ghost_edges.size() >= MAX_DRAG_TILES:
				break
			tx += step
	else:
		# Vertical column: fixed tx, vary ty.
		var step := signi(delta.y) if delta.y != 0 else 1
		var ty   := _drag_start.y
		while true:
			_ghost_edges.append([_drag_start.x, ty, MapData.DIR_W])
			if ty == tile_end.y or _ghost_edges.size() >= MAX_DRAG_TILES:
				break
			ty += step


func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	if _ghost_edges.is_empty():
		return

	# Send to server.  World.rpc_request_place_wall expects Array of [tx,ty,dir].
	var world := _player.get_tree().get_first_node_in_group("world_node") as World
	if world:
		world.rpc_id(1, "rpc_request_place_wall", _ghost_edges.duplicate())

	_ghost_edges = []
	queue_redraw()


func _update_hover(screen_pos: Vector2) -> void:
	var wp       := _screen_to_world(screen_pos)
	_hover_tile   = _world_to_tile(wp)
	# Show WALL_N by default; player chooses with LMB vs RMB on click.
	_hover_dir    = MapData.DIR_N


# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	if not _active or _tilemap == null:
		return

	if _dragging or not _ghost_edges.is_empty():
		# Draw confirmed ghost edges from drag.
		for edge: Array in _ghost_edges:
			_draw_ghost_edge(edge[0], edge[1], edge[2])
	else:
		# Draw single hover preview.
		_draw_ghost_edge(_hover_tile.x, _hover_tile.y, _hover_dir)

	# HUD indicator: small pulsing dot in top-left of screen space.
	# We're in world space so convert: place the dot near the player origin.
	draw_circle(Vector2(0.0, -28.0), 5.0, HUD_ON_COL)


func _draw_ghost_edge(tx: int, ty: int, dir: int) -> void:
	var center := _tilemap.map_to_local(Vector2i(tx, ty) + _origin) - global_position
	var pt_n   := center + Vector2(  0.0, -16.0)
	var pt_e   := center + Vector2( 32.0,   0.0)
	var pt_w   := center + Vector2(-32.0,   0.0)

	if dir == MapData.DIR_N:
		draw_line(pt_n, pt_e, GHOST_N_COL, 3.0)
		# Fill ghost face with translucent polygon.
		var up := Vector2(0.0, -32.0)
		draw_colored_polygon(PackedVector2Array([
			pt_n, pt_e, pt_e + up, pt_n + up]), Color(GHOST_N_COL, 0.20))
	else:  # DIR_W
		draw_line(pt_n, pt_w, GHOST_W_COL, 3.0)
		var up := Vector2(0.0, -32.0)
		draw_colored_polygon(PackedVector2Array([
			pt_n, pt_w, pt_w + up, pt_n + up]), Color(GHOST_W_COL, 0.20))


# ── Coordinate helpers ────────────────────────────────────────────────────────

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return _player.get_viewport().get_canvas_transform().affine_inverse() \
	       * screen_pos


func _world_to_tile(world_pos: Vector2) -> Vector2i:
	# Inverse of isometric map_to_local (TILE_W=64, TILE_H=32):
	#   center(tx, ty) = ((tx-ty)*32, (tx+ty)*16)
	#   tx = (wx/32 + wy/16) / 2,  ty = (wy/16 - wx/32) / 2
	var tx := int(floor((world_pos.x / 32.0 + world_pos.y / 16.0) * 0.5))
	var ty := int(floor((world_pos.y / 16.0 - world_pos.x / 32.0) * 0.5))
	return Vector2i(tx, ty) - _origin
