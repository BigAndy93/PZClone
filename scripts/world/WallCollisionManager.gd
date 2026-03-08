class_name WallCollisionManager
extends Node2D

## Builds StaticBody2D collision shapes for every canonical wall edge stored in
## MapData.wall_grid.  Door edges (stored in door_edges dict) are skipped here —
## DoorNode instances provide their own toggleable collision.

const WALL_HALF_THICK := 2.5  # physics polygon half-thickness in pixels

var _data:    MapData
var _tilemap: WorldTileMap
var _origin:  Vector2i

# Map from canonical edge key → StaticBody2D so individual tiles can be rebuilt.
var _bodies: Dictionary = {}  # Vector3i → StaticBody2D


func setup(data: MapData, tilemap: WorldTileMap, origin: Vector2i) -> void:
	_data    = data
	_tilemap = tilemap
	_origin  = origin


## Iterates the full wall_grid and creates one StaticBody2D per wall edge.
## Call once after MapData is fully populated.
func build_from_map() -> void:
	for child in get_children():
		child.queue_free()
	_bodies.clear()

	for ty in range(_data.map_height):
		for tx in range(_data.map_width):
			var flags := _data.get_wall(tx, ty)
			if flags & MapData.WALL_N:
				var ek := Vector3i(tx, ty, MapData.DIR_N)
				if not _data.door_edges.has(ek):
					_add_edge_body(tx, ty, MapData.DIR_N, ek)
			if flags & MapData.WALL_W:
				var ek := Vector3i(tx, ty, MapData.DIR_W)
				if not _data.door_edges.has(ek):
					_add_edge_body(tx, ty, MapData.DIR_W, ek)


## Removes and recreates collision bodies for the two canonical edges of (tx,ty).
## Call after wall_grid changes at a tile (e.g. player construction).
func rebuild_tile(tx: int, ty: int) -> void:
	for dir in [MapData.DIR_N, MapData.DIR_W]:
		var ek := Vector3i(tx, ty, dir)
		if _bodies.has(ek):
			_bodies[ek].queue_free()
			_bodies.erase(ek)

	var flags := _data.get_wall(tx, ty)
	if flags & MapData.WALL_N:
		var ek := Vector3i(tx, ty, MapData.DIR_N)
		if not _data.door_edges.has(ek):
			_add_edge_body(tx, ty, MapData.DIR_N, ek)
	if flags & MapData.WALL_W:
		var ek := Vector3i(tx, ty, MapData.DIR_W)
		if not _data.door_edges.has(ek):
			_add_edge_body(tx, ty, MapData.DIR_W, ek)


## Remove or restore the collision body for a single edge.
## Call when a window becomes passable (OPEN/BROKEN) or is closed/repaired.
func set_edge_passable(tx: int, ty: int, dir: int, passable: bool) -> void:
	var ek := MapData.edge_key(tx, ty, dir)
	if passable:
		if _bodies.has(ek):
			_bodies[ek].queue_free()
			_bodies.erase(ek)
	else:
		# Restore only if the wall edge still exists and isn't a door.
		if not _bodies.has(ek) \
				and _data.has_wall_edge(ek.x, ek.y, ek.z) \
				and not _data.door_edges.has(ek):
			_add_edge_body(ek.x, ek.y, ek.z, ek)


func _add_edge_body(tx: int, ty: int, dir: int, ek: Vector3i) -> void:
	var center := _tilemap.map_to_local(Vector2i(tx, ty) + _origin)
	var pt_n   := center + Vector2(  0.0, -16.0)
	var pt_e   := center + Vector2( 32.0,   0.0)
	var pt_w   := center + Vector2(-32.0,   0.0)

	var a:    Vector2
	var b:    Vector2
	var perp: Vector2

	if dir == MapData.DIR_N:
		# NE face: edge from pt_n to pt_e.  CCW perp of (32,16) = (-16,32).
		a    = pt_n
		b    = pt_e
		perp = Vector2(-16.0, 32.0).normalized() * WALL_HALF_THICK
	else:  # DIR_W
		# NW face: edge from pt_n to pt_w.  CCW perp of (-32,16) = (-16,-32).
		a    = pt_n
		b    = pt_w
		perp = Vector2(-16.0, -32.0).normalized() * WALL_HALF_THICK

	var body := StaticBody2D.new()
	body.collision_layer = 8   # L4 = World
	body.collision_mask  = 0
	add_child(body)

	var shape := ConvexPolygonShape2D.new()
	shape.set_point_cloud(PackedVector2Array([
		a - perp, b - perp, b + perp, a + perp,
	]))
	var coll       := CollisionShape2D.new()
	coll.shape      = shape
	body.add_child(coll)

	_bodies[ek] = body
