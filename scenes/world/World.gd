class_name World
extends Node2D

@export var player_scene: PackedScene = preload("res://scenes/player/Player.tscn")
@export var zombie_scene: PackedScene = preload("res://scenes/zombie/Zombie.tscn")
@export var npc_scene:    PackedScene = preload("res://scenes/npc/NPC.tscn")
# Deterministic seed shared across all peers — change export in editor to get new map.
@export var map_seed: int = 1337

@onready var tilemap:           WorldTileMap       = $TileMapLayer
@onready var nav_region:        NavigationRegion2D = $NavigationRegion2D
@onready var entities_container: Node              = $Entities  # flat y-sorted layer
@onready var horde_coordinator: HordeCoordinator   = $HordeCoordinator
@onready var player_spawner:    MultiplayerSpawner  = $PlayerSpawner
@onready var zombie_spawner:    MultiplayerSpawner  = $ZombieSpawner
@onready var hud:               CanvasLayer         = $HUD

# Aliases kept for internal use — all three collapse to the same flat container.
var players_container: Node:
	get: return entities_container
var zombies_container: Node:
	get: return entities_container
var npcs_container: Node:
	get: return entities_container

var _zombie_idx: int = 0

const RESPAWN_DELAY: float = 30.0

var _map_data: MapData
var _pending_respawns: Dictionary = {}  # peer_id → true

# ── Building cutaway ──────────────────────────────────────────────────────────
var _buildings:               Array[ProceduralBuilding] = []
var _cutaway_timer:           float                     = 0.0
var _current_interior:        ProceduralBuilding        = null


func _ready() -> void:
	add_to_group("world_node")
	entities_container.add_to_group("players_container")  # legacy group for discovery

	# Pre-bake all furniture sprites before world generation so ProceduralBuilding
	# can use cached ImageTextures instead of spawning per-piece Polygon2D nodes.
	await FurnitureBaker.warm_batch(
			FurnitureLibrary.get_box_specs(),
			FurnitureLibrary.get_flat_specs())

	# Generation is deterministic from the seed — runs on every peer independently.
	_generate_map()
	_spawn_npcs()

	# Day/Night visual overlay — cosmetic, safe on all peers.
	var overlay := DayNightOverlay.new()
	add_child(overlay)

	# Post-process: grain, vignette, scanlines (analog horror aesthetic).
	var post := PostProcessLayer.new()
	add_child(post)

	if multiplayer.is_server():
		_spawn_players()
		_spawn_zombies()
		NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
		GameManager.player_downed.connect(_on_player_downed)

	GameManager.change_phase(GameManager.Phase.PLAYING)
	GameManager.player_died.connect(_on_player_died)


# ── Per-frame ─────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_cutaway_timer += delta
	if _cutaway_timer >= 0.12:
		_cutaway_timer = 0.0
		_update_building_cutaway()


func _update_building_cutaway() -> void:
	# Find the local player on this peer.
	var my_id := multiplayer.get_unique_id()
	var local_player: Node2D = null
	for p in get_tree().get_nodes_in_group("players"):
		if p.get_multiplayer_authority() == my_id:
			local_player = p as Node2D
			break
	if local_player == null:
		return

	var pos := local_player.global_position
	var new_interior: ProceduralBuilding = null
	for building in _buildings:
		if is_instance_valid(building) and building.contains_point_world(pos):
			new_interior = building
			break

	# Only call set_cutaway on transition to avoid redundant tweens every tick.
	if new_interior != _current_interior:
		if _current_interior and is_instance_valid(_current_interior):
			_current_interior.set_cutaway(false)
		if new_interior:
			new_interior.set_cutaway(true)
		_current_interior = new_interior


# ── Map generation ─────────────────────────────────────────────────────────────
func _generate_map() -> void:
	_map_data = MapGenerator.generate(map_seed)
	tilemap.setup_from_map_data(_map_data)
	_spawn_buildings()
	_spawn_props()   # individual prop nodes — y-sorted inside Entities
	_spawn_loot()
	# CanopyLayer: renders ABOVE entities (z_index = 1).
	# Tree canopies, bush tops, and lamppost heads all go here.
	var canopy := WorldCanopyLayer.new()
	canopy.name    = "CanopyLayer"
	canopy.z_index = 1
	add_child(canopy)
	canopy.setup_from_map_data(_map_data)
	# Defer nav bake one frame so all collision shapes are in the tree.
	call_deferred("_bake_navigation")


func _spawn_buildings() -> void:
	for bd: BuildingData in _map_data.buildings:
		var building := ProceduralBuilding.new()
		entities_container.add_child(building)
		building.setup(bd, tilemap, _map_data.origin_offset)
		_buildings.append(building)


func _spawn_props() -> void:
	# Props — each gets its own Node2D in Entities so y_sort handles depth.
	for entry: Dictionary in _map_data.prop_cells:
		var tpos  : Vector2i = entry["pos"]
		var ptype : int      = entry["type"]
		var cell             := tpos + _map_data.origin_offset
		var prop             := WorldProp.new()
		prop.prop_type        = ptype
		prop.tile_pos         = tpos
		prop.position         = tilemap.map_to_local(cell)
		entities_container.add_child(prop)

	# Foliage trunks/bases — same approach so trees depth-sort with the player.
	# Elevated canopies are still drawn by WorldCanopyLayer (z_index=1, always above).
	for entry: Dictionary in _map_data.foliage_cells:
		var tpos  : Vector2i = entry["pos"]
		var ft    : int      = entry["type"]
		var cell             := tpos + _map_data.origin_offset
		var fol              := WorldFoliage.new()
		fol.ftype             = ft
		fol.tile_pos          = tpos
		fol.position          = tilemap.map_to_local(cell)
		entities_container.add_child(fol)


# ── Navigation baking ──────────────────────────────────────────────────────────
func _bake_navigation() -> void:
	var nav_poly := NavigationPolygon.new()

	# Outer walkable boundary: axis-aligned rectangle around the entire map,
	# wound counter-clockwise (positive area) so it's treated as the boundary.
	var o        := _map_data.origin_offset
	var min_cell := o
	var max_cell := Vector2i(_map_data.map_width - 1, _map_data.map_height - 1) + o
	var margin   := 64.0

	var pt_north := tilemap.map_to_local(min_cell)              + Vector2(0.0,    -16.0)
	var pt_east  := tilemap.map_to_local(Vector2i(max_cell.x, min_cell.y)) + Vector2(32.0,  0.0)
	var pt_south := tilemap.map_to_local(max_cell)              + Vector2(0.0,     16.0)
	var pt_west  := tilemap.map_to_local(Vector2i(min_cell.x, max_cell.y)) + Vector2(-32.0, 0.0)

	var bx := pt_west.x  - margin
	var by := pt_north.y - margin
	var ex := pt_east.x  + margin
	var ey := pt_south.y + margin

	# TL→TR→BR→BL: counter-clockwise in Godot 2D (y-down) = positive signed area = boundary
	nav_poly.add_outline(PackedVector2Array([
		Vector2(bx, by), Vector2(ex, by), Vector2(ex, ey), Vector2(bx, ey),
	]))

	# Building footprints as holes: N→W→S→E = clockwise = negative signed area
	for bd: BuildingData in _map_data.buildings:
		nav_poly.add_outline(_building_nav_hole(bd))

	nav_poly.make_polygons_from_outlines()
	nav_region.navigation_polygon = nav_poly


# ── Loot spawning ─────────────────────────────────────────────────────────────
# Spawns on ALL peers (map is deterministic from seed).
# Pickup is currently local-only.  TODO: server-authoritative loot sync.
func _spawn_loot() -> void:
	var container           := Node2D.new()
	container.name           = "Loot"
	container.y_sort_enabled = true
	add_child(container)

	var loot_idx := 0
	for bd: BuildingData in _map_data.buildings:
		for i in bd.loot_cells.size():
			var item_data: ItemData = bd.loot_items[i] if i < bd.loot_items.size() else null
			if item_data == null:
				continue
			var tile   : Vector2i = bd.loot_cells[i]
			var cell   : Vector2i = tile + _map_data.origin_offset
			var pos    : Vector2  = tilemap.map_to_local(cell)
			var loot               := LootItem.new()
			loot.name               = "Loot_%d" % loot_idx
			loot.item_data          = item_data
			loot.global_position    = pos
			container.add_child(loot)
			loot_idx += 1


# ── NPC spawning ───────────────────────────────────────────────────────────────
# Runs on ALL peers (deterministic from map_seed). NPC wander logic is
# server-only; clients receive sync_position via MultiplayerSynchronizer.
func _spawn_npcs() -> void:
	var idx := 0
	for bd: BuildingData in _map_data.buildings:
		if bd.zone_type != BuildingData.ZoneType.COMMERCIAL:
			continue
		# Place NPC just outside the building entrance (south tip + small offset).
		var r        := bd.tile_rect
		var south_c  := Vector2i(r.position.x + r.size.x / 2, r.end.y - 1) + _map_data.origin_offset
		var pos      := tilemap.map_to_local(south_c) + Vector2(0.0, 24.0)
		var npc      := npc_scene.instantiate()
		npc.name      = "NPC_%d" % idx
		npc.global_position = pos
		npcs_container.add_child(npc)
		idx += 1
		if idx >= 3:   # cap at 3 NPCs for the skeleton
			break


func _building_nav_hole(bd: BuildingData) -> PackedVector2Array:
	var r   := bd.tile_rect
	var o   := _map_data.origin_offset
	var cnw := Vector2i(r.position.x, r.position.y)  + o
	var cne := Vector2i(r.end.x - 1,  r.position.y)  + o
	var cse := Vector2i(r.end.x - 1,  r.end.y - 1)   + o
	var csw := Vector2i(r.position.x, r.end.y - 1)   + o

	var pn := tilemap.map_to_local(cnw) + Vector2(0.0,    -16.0)
	var pe := tilemap.map_to_local(cne) + Vector2(32.0,    0.0)
	var ps := tilemap.map_to_local(cse) + Vector2(0.0,    16.0)
	var pw := tilemap.map_to_local(csw) + Vector2(-32.0,  0.0)

	# Shrink each vertex slightly toward the centroid so adjacent buildings
	# never share edges/vertices, which would cause make_polygons_from_outlines to fail.
	const INSET := 3.0
	var centroid := (pn + pe + ps + pw) * 0.25
	pn = centroid + (pn - centroid).normalized() * maxf((pn - centroid).length() - INSET, 1.0)
	pe = centroid + (pe - centroid).normalized() * maxf((pe - centroid).length() - INSET, 1.0)
	ps = centroid + (ps - centroid).normalized() * maxf((ps - centroid).length() - INSET, 1.0)
	pw = centroid + (pw - centroid).normalized() * maxf((pw - centroid).length() - INSET, 1.0)

	# Clockwise winding (N→W→S→E) = negative signed area = hole
	return PackedVector2Array([pn, pw, ps, pe])


# ── Entity spawning (server-only) ─────────────────────────────────────────────
func _spawn_players() -> void:
	var peer_ids := GameManager.get_all_peer_ids()
	for i in range(peer_ids.size()):
		var pid  : int      = peer_ids[i]
		var tile : Vector2i = _map_data.player_spawn_tiles[i % _map_data.player_spawn_tiles.size()]
		var pos  : Vector2  = tilemap.map_to_local(tile + _map_data.origin_offset)
		_spawn_player(pid, pos)

	# Spawn a couple of test zombies near the first player spawn for quick combat testing.
	var first_tile: Vector2i = _map_data.player_spawn_tiles[0]
	var first_pos:  Vector2  = tilemap.map_to_local(first_tile + _map_data.origin_offset)
	var test_types: Array    = [0, 0]  # 2 regular (reduced for testing)
	for i in test_types.size():
		var angle    := TAU * i / float(test_types.size())
		var z_pos    := first_pos + Vector2(cos(angle), sin(angle)) * 220.0
		var z        := zombie_scene.instantiate()
		z.name        = "TestZombie_%d" % i
		z.zombie_type = test_types[i]
		z.global_position = z_pos
		zombies_container.add_child(z, true)


func _spawn_player(peer_id: int, spawn_pos: Vector2) -> void:
	var player := player_scene.instantiate()
	player.name                    = "Player_%d" % peer_id
	player.global_position         = spawn_pos
	player.set_multiplayer_authority(peer_id)
	players_container.add_child(player, true)
	_give_starting_loadout.call_deferred(player, peer_id)


func _give_starting_loadout(player: Node, peer_id: int) -> void:
	if not is_instance_valid(player):
		return
	var loadout: Array = [
		["Pistol",     ItemData.Type.WEAPON,  {"projectile_damage": 45.0, "fire_range": 550.0}],
		["Pistol Mag", ItemData.Type.MISC,    {"ammo_count": 15}],
		["Pistol Mag", ItemData.Type.MISC,    {"ammo_count": 15}],
		["Bandage",    ItemData.Type.BANDAGE, {"health": 15.0, "bleed": -1.0}],
	]
	for entry: Array in loadout:
		if peer_id == multiplayer.get_unique_id():
			player.rpc_receive_item.call(entry[0], entry[1], entry[2])
		else:
			player.rpc_id(peer_id, "rpc_receive_item", entry[0], entry[1], entry[2])


func _spawn_zombies() -> void:
	var idx := 0
	for zone_info: Dictionary in _map_data.zombie_zone_data:
		var tile   : Vector2i = zone_info["tile_pos"]
		var count  : int      = zone_info["count"]
		var center : Vector2  = tilemap.map_to_local(tile + _map_data.origin_offset)
		for _i in count:
			var zombie             := zombie_scene.instantiate()
			zombie.name             = "Zombie_%d" % idx
			var angle               := randf() * TAU
			var dist                := randf_range(48.0, 200.0)
			zombie.global_position  = center + Vector2(cos(angle), sin(angle)) * dist
			zombies_container.add_child(zombie, true)
			idx += 1


# ── Downed / revive ────────────────────────────────────────────────────────────
func _on_player_downed(peer_id: int) -> void:
	rpc_notify_player_downed.rpc(peer_id)


## Server → all peers: a player entered the downed state.
@rpc("authority", "call_local", "reliable")
func rpc_notify_player_downed(peer_id: int) -> void:
	EventBus.player_downed.emit(peer_id)


## Server → all peers: a downed player was successfully revived.
@rpc("authority", "call_local", "reliable")
func rpc_notify_player_revived(peer_id: int) -> void:
	EventBus.player_revived.emit(peer_id)


# ── Event handlers ─────────────────────────────────────────────────────────────
func _on_peer_disconnected(peer_id: int) -> void:
	var player := GameManager.get_player_node(peer_id)
	if player and is_instance_valid(player):
		player.queue_free()
	EventBus.player_removed.emit(peer_id)


func _on_player_died(peer_id: int) -> void:
	var player := GameManager.get_player_node(peer_id)
	if player and is_instance_valid(player):
		player.queue_free()
	EventBus.player_removed.emit(peer_id)
	await get_tree().process_frame
	if get_tree().get_nodes_in_group("players").size() == 0 and _pending_respawns.is_empty():
		rpc_game_over.rpc()
	else:
		_schedule_respawn(peer_id)


## Server → all peers: trigger GAME_OVER phase on every client.
@rpc("authority", "call_local", "reliable")
func rpc_game_over() -> void:
	GameManager.change_phase(GameManager.Phase.GAME_OVER)


## Server → all peers: a player is pending respawn — drives HUD countdown.
@rpc("authority", "call_local", "reliable")
func rpc_respawn_pending(peer_id: int, delay: float) -> void:
	EventBus.player_respawn_pending.emit(peer_id, delay)


func _schedule_respawn(peer_id: int) -> void:
	_pending_respawns[peer_id] = true
	rpc_respawn_pending.rpc(peer_id, RESPAWN_DELAY)
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_do_respawn.bind(peer_id))


func _do_respawn(peer_id: int) -> void:
	_pending_respawns.erase(peer_id)
	# Pick spawn position (cycle through available tiles by peer index).
	var peer_ids  := GameManager.get_all_peer_ids()
	var tile_idx  := peer_ids.find(peer_id) % _map_data.player_spawn_tiles.size()
	var tile      : Vector2i = _map_data.player_spawn_tiles[tile_idx]
	var pos       : Vector2  = tilemap.map_to_local(tile + _map_data.origin_offset)
	_spawn_player(peer_id, pos)
	# If everything somehow died while this was ticking, end the game.
	if get_tree().get_nodes_in_group("players").size() == 0 and _pending_respawns.is_empty():
		rpc_game_over.rpc()


# ── Loot sync ──────────────────────────────────────────────────────────────────

## Client → server: request picking up a loot item.
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_loot_pickup(loot_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	_server_do_loot_pickup(loot_path, multiplayer.get_remote_sender_id())


## Server-authoritative pickup: validate → give item → remove from world.
## Called directly for the server-host player, or via RPC for clients.
func _server_do_loot_pickup(loot_path: NodePath, peer_id: int) -> void:
	var loot := get_tree().root.get_node_or_null(loot_path) as LootItem
	if loot == null or not loot.is_in_group("loot_items"):
		return  # Already taken by someone else
	if loot.item_data == null:
		return

	var player := GameManager.get_player_node(peer_id)
	if player == null or not is_instance_valid(player):
		return

	# Deliver item to the requesting player.
	var d := loot.item_data
	if peer_id == multiplayer.get_unique_id():
		# Server-host player: call locally (rpc_id can't self-deliver with call_remote).
		player.rpc_receive_item.call(d.item_name, d.item_type, d.stat_effects)
	else:
		player.rpc_id(peer_id, "rpc_receive_item", d.item_name, d.item_type, d.stat_effects)

	# Remove from every peer's world.
	rpc_remove_loot.rpc(loot_path)


## Server → all peers: remove a loot item from the scene.
@rpc("authority", "call_local", "reliable")
func rpc_remove_loot(loot_path: NodePath) -> void:
	var node := get_tree().root.get_node_or_null(loot_path)
	if node and is_instance_valid(node):
		node.queue_free()


# ── Door interaction ───────────────────────────────────────────────────────────

## Client → server: request toggling a building door.
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_toggle_door(door_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	_server_toggle_door(door_path)


## Server-authoritative door toggle — broadcasts new state to all peers.
func _server_toggle_door(door_path: NodePath) -> void:
	var door_area := get_tree().root.get_node_or_null(door_path) as Area2D
	if door_area == null or not door_area.is_in_group("doors"):
		return
	var building := door_area.get_parent() as ProceduralBuilding
	if building == null:
		return
	var new_state := not building._door_open
	rpc_sync_door_state.rpc(door_path, new_state)


## Server → all peers: synchronise a door's open/closed state.
@rpc("authority", "call_local", "reliable")
func rpc_sync_door_state(door_path: NodePath, is_open: bool) -> void:
	var door_area := get_tree().root.get_node_or_null(door_path) as Area2D
	if door_area == null:
		return
	var building := door_area.get_parent() as ProceduralBuilding
	if building == null:
		return
	building.set_door_open(is_open)


# ── Window interaction ─────────────────────────────────────────────────────────

## Client → server: request toggling a building window.
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_toggle_window(win_area_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	_server_toggle_window(win_area_path)


## Server-authoritative window toggle — broadcasts new state to all peers.
func _server_toggle_window(win_area_path: NodePath) -> void:
	var win_area := get_tree().root.get_node_or_null(win_area_path) as Area2D
	if win_area == null or not win_area.is_in_group("windows"):
		return
	var building := win_area.get_parent() as ProceduralBuilding
	if building == null:
		return
	var win_idx := building.get_window_index(win_area)
	if win_idx < 0:
		return
	var new_state: bool = not bool(building._window_panes[win_idx]["is_open"])
	rpc_sync_window_state.rpc(win_area_path, new_state)


## Server → all peers: synchronise a window's open/closed state.
@rpc("authority", "call_local", "reliable")
func rpc_sync_window_state(win_area_path: NodePath, is_open: bool) -> void:
	var win_area := get_tree().root.get_node_or_null(win_area_path) as Area2D
	if win_area == null:
		return
	var building := win_area.get_parent() as ProceduralBuilding
	if building == null:
		return
	var win_idx := building.get_window_index(win_area)
	if win_idx >= 0:
		building.set_window_open(win_idx, is_open)


# ── Dynamic zombie spawning ────────────────────────────────────────────────────

## Called by HordeCoordinator to add a zombie mid-game (server-only).
func spawn_zombie_at(pos: Vector2) -> void:
	spawn_zombie_at_typed(pos, 0)


## Typed variant — allows HordeCoordinator to specify REGULAR / RUNNER / BRUTE.
func spawn_zombie_at_typed(pos: Vector2, zombie_type: int) -> void:
	if not multiplayer.is_server():
		return
	var zombie             := zombie_scene.instantiate()
	zombie.name             = "Zombie_%d" % _zombie_idx
	_zombie_idx            += 1
	zombie.global_position  = pos
	zombie.zombie_type      = zombie_type
	zombies_container.add_child(zombie, true)


# ── Drop spawning ───────────────────────────────────────────────────────────────

## Client → server: request spawning a player-dropped item.
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_item_drop(world_pos: Vector2, node_name: String, item_name: String, item_type: int, effects: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	rpc_spawn_drop.rpc(world_pos, node_name, item_name, item_type, effects)


## Server → all peers: spawn a loot item at world_pos (zombie drops, etc.)
@rpc("authority", "call_local", "reliable")
func rpc_spawn_drop(world_pos: Vector2, node_name: String, item_name: String, item_type: int, effects: Dictionary) -> void:
	var loot_container := get_node_or_null("Loot")
	if loot_container == null:
		return
	var loot              := LootItem.new()
	loot.name              = node_name
	loot.item_data         = ItemData.make(item_name, item_type, effects)
	loot.global_position   = world_pos
	loot_container.add_child(loot)
