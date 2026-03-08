class_name WindowNode
extends Node2D

## One node per window edge.
## Provides an Area2D in the "windows" group so Player._check_interact_input()
## can detect it.  Holds no visual geometry — BuildingTileRenderer draws the
## glass/frame based on the WIN_* state stored in MapData.window_edges.

var _edge_key: Vector3i
var _data:     MapData
var _area:     Area2D


func setup(edge_key: Vector3i, data: MapData,
		tilemap: WorldTileMap) -> void:
	_edge_key = edge_key
	_data     = data

	var tx  := edge_key.x
	var ty  := edge_key.y
	var dir := edge_key.z

	# Position at the mid-point of the window edge (same logic as DoorNode).
	var center := tilemap.map_to_local(Vector2i(tx, ty) + data.origin_offset)
	var pt_n   := center + Vector2(  0.0, -16.0)
	var pt_e   := center + Vector2( 32.0,   0.0)
	var pt_w   := center + Vector2(-32.0,   0.0)

	position = (pt_n + pt_e) * 0.5 if dir == MapData.DIR_N else (pt_n + pt_w) * 0.5

	# Interaction area — detected by Player interact_area.
	_area = Area2D.new()
	_area.add_to_group("windows")
	_area.set_meta("edge_key", edge_key)
	_area.collision_layer = 16   # L5 = Triggers
	_area.collision_mask  = 0
	add_child(_area)

	var circle        := CircleShape2D.new()
	circle.radius      = 36.0
	var coll          := CollisionShape2D.new()
	coll.shape         = circle
	_area.add_child(coll)


## Returns true when the window state allows passage (BROKEN or OPEN).
func is_passable() -> bool:
	var state: int = _data.window_edges.get(_edge_key, MapData.WIN_INTACT)
	return state == MapData.WIN_BROKEN or state == MapData.WIN_OPEN
