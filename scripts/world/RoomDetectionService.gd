class_name RoomDetectionService
extends Node

signal rooms_rebuilt(building_index: int, room_count: int)
signal room_detection_completed(total_buildings: int, total_rooms: int)


func rebuild_all(data: MapData) -> void:
	var total_rooms := 0
	for i in data.building_blueprints.size():
		var bp := data.building_blueprints[i] as BuildingBlueprint
		total_rooms += rebuild_for_building(data, bp)
		emit_signal("rooms_rebuilt", i, bp.rooms.size())
	emit_signal("room_detection_completed", data.building_blueprints.size(), total_rooms)


func rebuild_for_building(data: MapData, bp: BuildingBlueprint) -> int:
	var floor_lookup: Dictionary = bp.floor_cells
	var visited: Dictionary = {}
	var old_rooms: Array = bp.rooms.duplicate()
	var next_rooms: Array = []

	for cell in floor_lookup.keys():
		if visited.has(cell):
			continue
		var component := _flood_room_component(data, floor_lookup, cell as Vector2i, visited)
		if component["leaks"]:
			continue
		var cells: Array = component["cells"]
		var purpose := _pick_purpose_from_overlap(cells, old_rooms)
		var room := _build_room_def(next_rooms.size(), purpose, cells)
		_collect_opening_metadata(data, floor_lookup, room)
		next_rooms.append(room)

	bp.rooms = next_rooms
	return next_rooms.size()


func _flood_room_component(data: MapData, floor_lookup: Dictionary,
		start: Vector2i, visited: Dictionary) -> Dictionary:
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	var cells: Array = []
	var leaks := false

	while not queue.is_empty():
		var cell := queue.pop_front()
		cells.append(cell)
		for dir in [MapData.DIR_N, MapData.DIR_E, MapData.DIR_S, MapData.DIR_W]:
			var n := _neighbor(cell, dir)
			var blocked := _is_blocked_by_opening_or_wall(data, cell, dir)
			if floor_lookup.has(n):
				if blocked or visited.has(n):
					continue
				visited[n] = true
				queue.append(n)
			elif not blocked:
				leaks = true

	return {"cells": cells, "leaks": leaks}


func _build_room_def(room_id: int, purpose: int, cells: Array) -> BuildingBlueprint.RoomDef:
	var min_x := 1 << 30
	var min_y := 1 << 30
	var max_x := -(1 << 30)
	var max_y := -(1 << 30)
	for c_v in cells:
		var c := c_v as Vector2i
		min_x = mini(min_x, c.x)
		min_y = mini(min_y, c.y)
		max_x = maxi(max_x, c.x)
		max_y = maxi(max_y, c.y)
	var bounds := Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	var room := BuildingBlueprint.RoomDef.make(room_id, purpose, bounds, 0)
	room.floor_cells = cells
	return room


func _collect_opening_metadata(data: MapData, floor_lookup: Dictionary, room: BuildingBlueprint.RoomDef) -> void:
	var room_lookup: Dictionary = {}
	for c_v in room.floor_cells:
		room_lookup[c_v] = true
	for c_v in room.floor_cells:
		var c := c_v as Vector2i
		for dir in [MapData.DIR_N, MapData.DIR_E, MapData.DIR_S, MapData.DIR_W]:
			var n := _neighbor(c, dir)
			if not floor_lookup.has(n) or room_lookup.has(n):
				continue
			var ek := MapData.edge_key(c.x, c.y, dir)
			if data.door_edges.has(ek) and ek not in room.connected_door_edges:
				room.connected_door_edges.append(ek)
			if data.window_edges.has(ek) and ek not in room.connected_window_edges:
				room.connected_window_edges.append(ek)


func _pick_purpose_from_overlap(cells: Array, old_rooms: Array) -> int:
	if old_rooms.is_empty():
		return BuildingBlueprint.RoomDef.Purpose.LIVING
	var best_score := -1
	var best_purpose := BuildingBlueprint.RoomDef.Purpose.LIVING
	var lookup := {}
	for c_v in cells:
		lookup[c_v] = true
	for old_v in old_rooms:
		var old_room := old_v as BuildingBlueprint.RoomDef
		var score := 0
		for oc_v in old_room.floor_cells:
			if lookup.has(oc_v):
				score += 1
		if score > best_score:
			best_score = score
			best_purpose = old_room.purpose
	return best_purpose


func _is_blocked_by_opening_or_wall(data: MapData, from: Vector2i, dir: int) -> bool:
	var ek := MapData.edge_key(from.x, from.y, dir)
	if data.door_edges.has(ek) or data.window_edges.has(ek):
		return true
	return data.has_wall_edge(from.x, from.y, dir)


func _neighbor(cell: Vector2i, dir: int) -> Vector2i:
	match dir:
		MapData.DIR_N: return cell + Vector2i(0, -1)
		MapData.DIR_E: return cell + Vector2i(1, 0)
		MapData.DIR_S: return cell + Vector2i(0, 1)
		_: return cell + Vector2i(-1, 0)
