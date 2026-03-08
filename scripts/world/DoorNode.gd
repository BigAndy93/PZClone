class_name DoorNode
extends Node2D

## Standalone node placed per door edge.
## Provides toggleable physics collision (StaticBody2D) and an Area2D in the
## "doors" group so the player's F-interact can detect it.
## Animates a Polygon2D door panel; BuildingTileRenderer draws the frame/transom.

const DOOR_COL    := Color(0.55, 0.38, 0.22, 1.0)
const OUTLINE_COL := Color(0.10, 0.08, 0.06, 0.85)
const SWING_SPEED := 3.5   # full open/close in ~0.29 s
const DOOR_H_PX   := 64.0  # 2 tiles × 32 px/tile — always fixed

var _edge_key: Vector3i
var _data:     MapData
var is_open:   bool = false

var _coll: CollisionShape2D
var _area: Area2D

# ── Visual state ─────────────────────────────────────────────────────────────
var _da:        Vector2  # hinge end of door gap (local space)
var _db:        Vector2  # free end of door gap  (local space)
var _door_h_vec: Vector2 # = Vector2(0, -DOOR_H_PX) — constant
var _swing_dir:  Vector2 # floor-plane swing direction
var _panel_len:  float   # length of door gap
var _swing_t:    float = 0.0
var _swing_tgt:  float = 0.0

var _panel:   Polygon2D
var _outline: Line2D


func setup(edge_key: Vector3i, data: MapData,
		tilemap: WorldTileMap, _wall_h: float) -> void:
	_edge_key = edge_key
	_data     = data

	var tx  := edge_key.x
	var ty  := edge_key.y
	var dir := edge_key.z

	var center := tilemap.map_to_local(Vector2i(tx, ty) + data.origin_offset)
	var pt_n   := center + Vector2(  0.0, -16.0)
	var pt_e   := center + Vector2( 32.0,   0.0)
	var pt_w   := center + Vector2(-32.0,   0.0)

	# Place node at mid-edge so y-sort puts it in the right draw order.
	if dir == MapData.DIR_N:
		position = (pt_n + pt_e) * 0.5
	else:
		position = (pt_n + pt_w) * 0.5

	# Gap endpoints in local space (matches _draw_door_frame flank=0.18).
	var a     : Vector2 = pt_n
	var b     : Vector2 = pt_e if dir == MapData.DIR_N else pt_w
	var flank := (b - a) * 0.18
	_da          = (a + flank) - position
	_db          = (b - flank) - position
	_door_h_vec  = Vector2(0.0, -DOOR_H_PX)
	_panel_len   = (_db - _da).length()

	# Swing direction is the floor-plane inward normal of the face.
	if dir == MapData.DIR_N:
		_swing_dir = Vector2(-32.0, 16.0).normalized()
	else:
		_swing_dir = Vector2( 32.0, 16.0).normalized()

	# ── Polygon2D panel (rendered by Godot automatically) ─────────────────
	_panel       = Polygon2D.new()
	_panel.color = DOOR_COL
	add_child(_panel)

	_outline                = Line2D.new()
	_outline.default_color  = OUTLINE_COL
	_outline.width          = 1.2
	_outline.closed         = true
	add_child(_outline)

	_update_visual()
	set_process(false)

	# ── Physics body (blocks passage when closed) ─────────────────────────
	var body             := StaticBody2D.new()
	body.collision_layer  = 8   # L4 = World
	body.collision_mask   = 0
	add_child(body)

	const T := 3.0  # collision half-thickness
	var shape := ConvexPolygonShape2D.new()
	if dir == MapData.DIR_N:
		var pa   := pt_n - position
		var pb   := pt_e - position
		var perp := Vector2(-16.0, 32.0).normalized() * T
		shape.set_point_cloud(PackedVector2Array([pa - perp, pb - perp, pb + perp, pa + perp]))
	else:
		var pa   := pt_n - position
		var pb   := pt_w - position
		var perp := Vector2(-16.0, -32.0).normalized() * T
		shape.set_point_cloud(PackedVector2Array([pa - perp, pb - perp, pb + perp, pa + perp]))

	_coll       = CollisionShape2D.new()
	_coll.shape = shape
	body.add_child(_coll)

	# ── Interaction area ──────────────────────────────────────────────────
	_area = Area2D.new()
	_area.add_to_group("doors")
	_area.set_meta("edge_key", _edge_key)
	_area.collision_layer = 16   # L5 = Triggers
	_area.collision_mask  = 0
	add_child(_area)

	var azone    := CollisionShape2D.new()
	var circle   := CircleShape2D.new()
	circle.radius = 48.0
	azone.shape   = circle
	_area.add_child(azone)


## Opens or closes the door.  Starts the swing animation and toggles collision.
func set_open(v: bool) -> void:
	if is_open == v:
		return
	is_open    = v
	_swing_tgt = 1.0 if v else 0.0
	_coll.set_deferred(&"disabled", v)
	set_process(true)


# ── Animation ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_swing_t = move_toward(_swing_t, _swing_tgt, delta * SWING_SPEED)
	_update_visual()
	if absf(_swing_t - _swing_tgt) < 0.005:
		_swing_t = _swing_tgt
		set_process(false)


func _update_visual() -> void:
	var t        := _swing_t
	var open_tip := _da + _swing_dir * _panel_len

	# Interpolate the four corners from closed (wall-face) to open (floor-plane).
	var floor_thin := Vector2(0.0, -3.5)
	var p0         := _da
	var p1: Vector2 = lerp(_db,                   open_tip,              t)
	var p2: Vector2 = lerp(_db + _door_h_vec,      open_tip + floor_thin, t)
	var p3: Vector2 = lerp(_da + _door_h_vec,      _da      + floor_thin, t)

	var pts := PackedVector2Array([p0, p1, p2, p3])
	_panel.color   = Color(DOOR_COL.r, DOOR_COL.g, DOOR_COL.b, lerp(1.0, 0.75, t))
	_panel.polygon = pts
	_outline.points = pts
