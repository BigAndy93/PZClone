class_name ChunkManager
extends Node

signal chunk_loaded(chunk_id: String, chunk_coord: Vector2i)
signal chunk_activated(chunk_id: String, chunk_coord: Vector2i)
signal chunk_deactivated(chunk_id: String, chunk_coord: Vector2i)
signal chunk_unloaded(chunk_id: String, chunk_coord: Vector2i)

enum ChunkState {
	UNLOADED = 0,
	LOADED = 1,
	ACTIVE = 2,
}

@export var chunk_size_tiles: int = 32
@export var active_radius: int = 1
@export var loaded_radius: int = 2

var _chunks: Dictionary = {}
var _recent_events: Array[String] = []
const MAX_EVENTS := 12


static func chunk_id_for(coord: Vector2i) -> String:
	return "%s:%s" % [coord.x, coord.y]


func world_tile_to_chunk(tile: Vector2i) -> Vector2i:
	return Vector2i(
		int(floor(float(tile.x) / float(chunk_size_tiles))),
		int(floor(float(tile.y) / float(chunk_size_tiles)))
	)


func update_streaming(player_tile: Vector2i) -> void:
	var center := world_tile_to_chunk(player_tile)
	var should_load: Dictionary = {}
	var should_activate: Dictionary = {}

	for cy in range(center.y - loaded_radius, center.y + loaded_radius + 1):
		for cx in range(center.x - loaded_radius, center.x + loaded_radius + 1):
			var coord := Vector2i(cx, cy)
			var chunk_id := chunk_id_for(coord)
			should_load[chunk_id] = coord
			var in_active: bool = abs(cx - center.x) <= active_radius and abs(cy - center.y) <= active_radius
			if in_active:
				should_activate[chunk_id] = coord

	for chunk_id: String in should_load:
		if not _chunks.has(chunk_id):
			_chunks[chunk_id] = {"coord": should_load[chunk_id], "state": ChunkState.LOADED}
			emit_signal("chunk_loaded", chunk_id, should_load[chunk_id])
			_record_event("load", chunk_id)

	for chunk_id: String in _chunks.keys():
		var state: int = _chunks[chunk_id]["state"]
		if should_activate.has(chunk_id):
			if state != ChunkState.ACTIVE:
				_chunks[chunk_id]["state"] = ChunkState.ACTIVE
				emit_signal("chunk_activated", chunk_id, _chunks[chunk_id]["coord"])
				_record_event("activate", chunk_id)
		elif should_load.has(chunk_id):
			if state == ChunkState.ACTIVE:
				_chunks[chunk_id]["state"] = ChunkState.LOADED
				emit_signal("chunk_deactivated", chunk_id, _chunks[chunk_id]["coord"])
				_record_event("deactivate", chunk_id)

	var to_unload: Array[String] = []
	for chunk_id: String in _chunks.keys():
		if not should_load.has(chunk_id):
			to_unload.append(chunk_id)

	for chunk_id: String in to_unload:
		if _chunks[chunk_id]["state"] == ChunkState.ACTIVE:
			emit_signal("chunk_deactivated", chunk_id, _chunks[chunk_id]["coord"])
			_record_event("deactivate", chunk_id)
		emit_signal("chunk_unloaded", chunk_id, _chunks[chunk_id]["coord"])
		_record_event("unload", chunk_id)
		_chunks.erase(chunk_id)


func _record_event(kind: String, chunk_id: String) -> void:
	_recent_events.append("%s %s" % [kind, chunk_id])
	if _recent_events.size() > MAX_EVENTS:
		_recent_events.remove_at(0)


func get_debug_snapshot() -> Dictionary:
	var active := 0
	var loaded := 0
	for chunk_id: String in _chunks:
		var st: int = _chunks[chunk_id]["state"]
		if st == ChunkState.ACTIVE:
			active += 1
		elif st == ChunkState.LOADED:
			loaded += 1
	return {
		"active_count": active,
		"loaded_count": loaded,
		"total_count": _chunks.size(),
		"recent_events": _recent_events.duplicate(),
	}
