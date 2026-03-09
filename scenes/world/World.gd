class_name World
extends Node2D

@export var player_scene: PackedScene = preload("res://scenes/player/Player.tscn")
@export var zombie_scene: PackedScene = preload("res://scenes/zombie/Zombie.tscn")
@export var npc_scene:    PackedScene = preload("res://scenes/npc/NPC.tscn")
# Deterministic seed shared across all peers — change export in editor to get new map.
@export var map_seed: int = 1337

@onready var tilemap:             WorldTileMap       = $TileMapLayer
@onready var nav_region:          NavigationRegion2D = $NavigationRegion2D
@onready var entities_container:  Node               = $Entities  # flat y-sorted layer
@onready var horde_coordinator:   HordeCoordinator   = $HordeCoordinator
@onready var player_spawner:      MultiplayerSpawner  = $PlayerSpawner
@onready var zombie_spawner:      MultiplayerSpawner  = $ZombieSpawner
@onready var hud:                 CanvasLayer         = $HUD

# Aliases kept for internal use — all three collapse to the same flat container.
var players_container: Node:
	get: return entities_container
var zombies_container: Node:
	get: return entities_container
var npcs_container: Node:
	get: return entities_container

var _zombie_idx: int = 0

const RESPAWN_DELAY: float = 30.0

var _map_data:         MapData
var _pending_respawns: Dictionary = {}  # peer_id → true

# ── Building system ────────────────────────────────────────────────────────────
var _building_renderers:      Array[BuildingTileRenderer] = []
var _door_nodes:              Dictionary                   = {}  # Vector3i → DoorNode
var _window_nodes:            Dictionary                   = {}  # Vector3i → WindowNode
var _roof_nodes:              Array                        = []  # [{poly, bp}]
var _wall_collision_manager:  WallCollisionManager
var _chunk_manager:          ChunkManager
var _room_detection_service: RoomDetectionService

# Cutaway / visibility state
var _cutaway_timer:      float                = 0.0
var _current_interior:   BuildingTileRenderer = null
var _player_tile:        Vector2i             = Vector2i(-9999, -9999)
var _player_room_id:     int                  = -1
var _player_current_floor: int               = 0   # which storey the local player is on


func _ready() -> void:
	add_to_group("world_node")
	entities_container.add_to_group("players_container")  # legacy group for discovery

	# World foundation services.
	_chunk_manager = ChunkManager.new()
	_chunk_manager.name = "ChunkManager"
	add_child(_chunk_manager)

	_room_detection_service = RoomDetectionService.new()
	_room_detection_service.name = "RoomDetectionService"
	add_child(_room_detection_service)

	# Wall collision manager lives outside Entities so it isn't y-sorted.
	_wall_collision_manager = WallCollisionManager.new()
	_wall_collision_manager.name = "WallCollisionManager"
	add_child(_wall_collision_manager)

	# Pre-bake all building component sprites (wall/floor/door/window) and furniture
	# textures before map generation so BuildingTileRenderer.setup() can use them.
	await BuildingComponentBaker.warm(4)   # height_tiles can be 3 OR 4 (large buildings)
	await FurnitureBaker.warm_batch(
		FurnitureLibrary.get_box_specs(),
		FurnitureLibrary.get_flat_specs())

	# Generation is deterministic from the seed — runs on every peer independently.
	_generate_map()
	_spawn_npcs()

	# Weather system — server-authoritative, synced to clients via RPC.
	var weather := WeatherSystem.new()
	weather.name = "WeatherSystem"
	add_child(weather)

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
		_update_chunk_streaming()



func _update_chunk_streaming() -> void:
	if _map_data == null or _chunk_manager == null:
		return
	var my_id := multiplayer.get_unique_id()
	for p in get_tree().get_nodes_in_group("players"):
		if p.get_multiplayer_authority() != my_id:
			continue
		var tile := tilemap.local_to_map((p as Node2D).global_position) - _map_data.origin_offset
		_chunk_manager.update_streaming(tile)
		break

func _update_building_cutaway() -> void:
	var my_id := multiplayer.get_unique_id()
	var local_player: Node2D = null
	for p in get_tree().get_nodes_in_group("players"):
		if p.get_multiplayer_authority() == my_id:
			local_player = p as Node2D
			break
	if local_player == null:
		return

	var pos        := local_player.global_position
	var tile_local := tilemap.local_to_map(pos)
	var tile_map   := tile_local - _map_data.origin_offset

	var new_interior: BuildingTileRenderer = null
	for renderer: BuildingTileRenderer in _building_renderers:
		if is_instance_valid(renderer) and renderer.contains_point_world(pos):
			new_interior = renderer
			break

	# Sync player z_index with the isometric depth scale used by building
	# element sprites ((tx+ty)*2 for furniture, (tx+ty)*2-1 for walls).
	# Inside a building the +1 ensures the player is visually in front of
	# furniture at the same depth; outside, z_index=0 defers to tree order.
	local_player.z_index = (tile_map.x + tile_map.y) * 2 + 1 \
		if new_interior != null else 0

	# Tile-change detection — only recompute when player moves to a new tile
	# or changes which building they are in.  (System 10 performance rule.)
	# Read the current floor from the player node (synced variable).
	var new_floor: int = local_player.get("sync_current_floor") if \
			local_player.get("sync_current_floor") != null else 0

	if tile_map == _player_tile and new_interior == _current_interior \
			and new_floor == _player_current_floor:
		return
	_player_tile          = tile_map
	_player_current_floor = new_floor

	# Handle building entry / exit transitions.
	if new_interior != _current_interior:
		if _current_interior and is_instance_valid(_current_interior):
			_current_interior.set_visibility_data(-1, [], false)
			_set_roof_visible(_current_interior._bp, true)
		if new_interior:
			_set_roof_visible(new_interior._bp, false)
		_current_interior = new_interior
		_player_room_id   = -1
		# Restore all entity visibility when leaving a building.
		if new_interior == null:
			_reset_all_entity_visibility()

	if _current_interior == null:
		return

	# Push the active floor to the renderer before room-lookup so sprites for
	# the right floor are visible.
	_current_interior.set_current_floor(new_floor)

	# Determine which room the player is standing in on their current floor.
	var new_room_id := _find_room_at_tile_on_floor(
			_current_interior._bp, tile_map, new_floor)
	_player_room_id  = new_room_id

	# Find adjacent rooms reachable through a door or window.
	var adjacent: Array = []
	if new_room_id >= 0:
		adjacent = _find_adjacent_rooms_on_floor(
				_current_interior._bp, new_room_id, new_floor)

	_current_interior.set_visibility_data(new_room_id, adjacent, true, tile_map)
	_update_entity_visibility(local_player)


## Returns the room_id of the RoomDef whose floor_cells contain tile,
## or -1 if no room claims that tile.  Kept for legacy callers.
func _find_room_at_tile(bp: BuildingBlueprint, tile: Vector2i) -> int:
	return _find_room_at_tile_on_floor(bp, tile, 0)


## Floor-aware version: searches only the rooms on the given floor index.
func _find_room_at_tile_on_floor(bp: BuildingBlueprint,
		tile: Vector2i, floor: int) -> int:
	var rooms: Array = bp.rooms if floor == 0 else \
			(bp.upper_floors[floor - 1].rooms if bp.upper_floors.size() >= floor else [])
	for room: BuildingBlueprint.RoomDef in rooms:
		if tile in room.floor_cells:
			return room.id
	return -1


## Returns a list of room_ids that are directly connected to player_room_id
## via at least one door or window opening.  Legacy (floor 0) shim.
func _find_adjacent_rooms(bp: BuildingBlueprint, room_id: int) -> Array:
	return _find_adjacent_rooms_on_floor(bp, room_id, 0)


## Floor-aware adjacent-room finder.
func _find_adjacent_rooms_on_floor(bp: BuildingBlueprint,
		room_id: int, floor: int) -> Array:
	# Pick the room list and edge dictionaries for this floor.
	var rooms: Array
	var door_dict: Dictionary
	var win_dict:  Dictionary
	if floor == 0:
		rooms      = bp.rooms
		door_dict  = _map_data.door_edges
		win_dict   = _map_data.window_edges
	elif bp.upper_floors.size() >= floor:
		var fd: BuildingBlueprint.FloorData = bp.upper_floors[floor - 1]
		rooms     = fd.rooms
		door_dict = fd.door_edges
		win_dict  = fd.window_edges
	else:
		return []

	var player_room: BuildingBlueprint.RoomDef = null
	for room: BuildingBlueprint.RoomDef in rooms:
		if room.id == room_id:
			player_room = room
			break
	if player_room == null:
		return []

	var adjacent: Array      = []
	var checked:  Dictionary = {}

	for cell_v in player_room.floor_cells:
		var cell := cell_v as Vector2i
		for dir: int in [MapData.DIR_N, MapData.DIR_S, MapData.DIR_E, MapData.DIR_W]:
			var ek := MapData.edge_key(cell.x, cell.y, dir)
			if checked.has(ek):
				continue
			checked[ek] = true
			if door_dict.has(ek) or win_dict.has(ek):
				var nx := cell.x
				var ny := cell.y
				match dir:
					MapData.DIR_N: ny -= 1
					MapData.DIR_S: ny += 1
					MapData.DIR_E: nx += 1
					MapData.DIR_W: nx -= 1
				var nrid := _find_room_at_tile_on_floor(bp, Vector2i(nx, ny), floor)
				if nrid >= 0 and nrid != room_id and nrid not in adjacent:
					adjacent.append(nrid)
	return adjacent


## Restore all entities to visible — called when the local player exits a building.
func _reset_all_entity_visibility() -> void:
	for g: String in ["zombies", "npcs", "loot_items"]:
		for e: Node in get_tree().get_nodes_in_group(g):
			if e.has_method("set_occlusion_visible"):
				e.set_occlusion_visible(true)
	for p: Node in get_tree().get_nodes_in_group("players"):
		if p.has_method("set_occlusion_visible"):
			p.set_occlusion_visible(true)


## Returns true if the given entity should be rendered from the local player's perspective.
## Entities outside the current building are always visible.
## Entities in explored rooms are visible.  Entities in unexplored rooms:
##   - Zombies: visible if making chase/attack noise AND within hearing range.
##   - Everything else: hidden.
func _entity_occlusion_visible(entity: Node2D, player_pos: Vector2, is_zombie: bool) -> bool:
	if not _current_interior.contains_point_world(entity.global_position):
		return true   # outside this building footprint — always visible
	var etile  := tilemap.local_to_map(entity.global_position) - _map_data.origin_offset
	var eroom  : int = _current_interior.tile_to_room.get(etile, -1)
	if _current_interior.is_room_explored(eroom):
		return true   # explored room — always visible
	# Unexplored room.
	if is_zombie:
		var zombie         := entity as Zombie
		var noisy  : bool   = zombie.sync_state_name in ["ZombieStateChase", "ZombieStateAttack"]
		var dist   : float  = player_pos.distance_to(entity.global_position)
		return noisy and dist <= zombie.hearing_radius
	return false


## Apply per-entity visibility based on room exploration state.  Runs on the
## 0.12 s cutaway timer — client-side only, display purpose only.
func _update_entity_visibility(local_player: Node2D) -> void:
	var ppos := local_player.global_position
	var my_id := local_player.get_multiplayer_authority()

	for z: Node in get_tree().get_nodes_in_group("zombies"):
		if z.has_method("set_occlusion_visible"):
			z.set_occlusion_visible(_entity_occlusion_visible(z as Node2D, ppos, true))
	for n: Node in get_tree().get_nodes_in_group("npcs"):
		if n.has_method("set_occlusion_visible"):
			n.set_occlusion_visible(_entity_occlusion_visible(n as Node2D, ppos, false))
	for l: Node in get_tree().get_nodes_in_group("loot_items"):
		if l.has_method("set_occlusion_visible"):
			l.set_occlusion_visible(_entity_occlusion_visible(l as Node2D, ppos, false))
	for p: Node in get_tree().get_nodes_in_group("players"):
		if p.get_multiplayer_authority() == my_id:
			continue   # local player is always visible
		if p.has_method("set_occlusion_visible"):
			p.set_occlusion_visible(_entity_occlusion_visible(p as Node2D, ppos, false))


## Smoothly fade a building's roof polygon in or out (0.3 s tween).
func _set_roof_visible(bp: BuildingBlueprint, v: bool) -> void:
	for entry: Dictionary in _roof_nodes:
		if entry["bp"] == bp:
			var tw := create_tween()
			tw.tween_property(entry["poly"], "modulate:a", 1.0 if v else 0.0, 0.30)
			break


# ── Map generation ─────────────────────────────────────────────────────────────
func _generate_map() -> void:
	_map_data = MapGenerator.generate(map_seed)
	_room_detection_service.rebuild_all(_map_data)
	tilemap.setup_from_map_data(_map_data)
	_wall_collision_manager.setup(_map_data, tilemap, _map_data.origin_offset)

	_spawn_building_renderers()
	_spawn_doors()
	_spawn_windows()
	_wall_collision_manager.build_from_map()
	# Windows that start passable (WIN_OPEN / WIN_BROKEN) need their collision
	# removed after the initial build.
	_sync_window_collisions()

	_spawn_props()
	_spawn_loot()

	var canopy := WorldCanopyLayer.new()
	canopy.name    = "CanopyLayer"
	canopy.z_index = 1
	add_child(canopy)
	canopy.setup_from_map_data(_map_data)

	_spawn_roofs(canopy)

	# Debug overlay — toggled with F3 at runtime.
	var dbg := BuildingDebugOverlay.new()
	dbg.name = "BuildingDebugOverlay"
	add_child(dbg)
	dbg.setup(_map_data, tilemap, _map_data.origin_offset, _chunk_manager)

	# Defer nav bake one frame so all collision shapes are in the tree.
	call_deferred("_bake_navigation")


func _spawn_building_renderers() -> void:
	for bp: BuildingBlueprint in _map_data.building_blueprints:
		var renderer := BuildingTileRenderer.new()
		entities_container.add_child(renderer)
		renderer.setup(bp, _map_data, tilemap, _map_data.origin_offset)
		_building_renderers.append(renderer)


func _spawn_doors() -> void:
	for ek: Vector3i in _map_data.door_edges:
		var door    := DoorNode.new()
		entities_container.add_child(door)
		var h_tiles : int   = _map_data.door_edges[ek]
		var wall_h  : float = BuildingTileRenderer.WALL_H_PER_TILE * float(h_tiles)
		door.setup(ek, _map_data, tilemap, wall_h)
		_door_nodes[ek] = door


func _spawn_windows() -> void:
	for ek: Vector3i in _map_data.window_edges:
		var win := WindowNode.new()
		entities_container.add_child(win)
		win.setup(ek, _map_data, tilemap)
		_window_nodes[ek] = win


## All window states (intact, open, broken) keep wall collision.
## Players must hold F to crawl through open or broken windows.
func _sync_window_collisions() -> void:
	pass  # no window state removes collision; crawl mechanic handles passage


func _spawn_roofs(canopy: Node) -> void:
	var wall_h_per := BuildingTileRenderer.WALL_H_PER_TILE
	for bp: BuildingBlueprint in _map_data.building_blueprints:
		var pts    := bp.footprint_poly(tilemap, _map_data.origin_offset)
		var wall_h := wall_h_per * float(bp.height_tiles)
		var up     := Vector2(0.0, -wall_h)
		var lifted := PackedVector2Array()
		for p: Vector2 in pts:
			lifted.append(p + up)
		var poly         := Polygon2D.new()
		poly.polygon      = lifted
		poly.color        = Color(0.30, 0.28, 0.24, 0.92)
		canopy.add_child(poly)
		_roof_nodes.append({poly = poly, bp = bp})


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
	var o        := _map_data.origin_offset
	var min_cell := o
	var max_cell := Vector2i(_map_data.map_width - 1, _map_data.map_height - 1) + o
	var margin   := 64.0

	var pt_north := tilemap.map_to_local(min_cell)                              + Vector2(  0.0, -16.0)
	var pt_east  := tilemap.map_to_local(Vector2i(max_cell.x, min_cell.y))      + Vector2( 32.0,   0.0)
	var pt_south := tilemap.map_to_local(max_cell)                              + Vector2(  0.0,  16.0)
	var pt_west  := tilemap.map_to_local(Vector2i(min_cell.x, max_cell.y))      + Vector2(-32.0,   0.0)

	var bx := pt_west.x  - margin
	var by := pt_north.y - margin
	var ex := pt_east.x  + margin
	var ey := pt_south.y + margin

	var source := NavigationMeshSourceGeometryData2D.new()
	source.add_traversable_outline(PackedVector2Array([
		Vector2(bx, by), Vector2(ex, by), Vector2(ex, ey), Vector2(bx, ey),
	]))
	# Building footprints as obstruction outlines.
	for bp: BuildingBlueprint in _map_data.building_blueprints:
		source.add_obstruction_outline(_building_nav_hole(bp))

	var nav_poly := NavigationPolygon.new()
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, source,
			_on_nav_baked.bind(nav_poly))


func _on_nav_baked(nav_poly: NavigationPolygon) -> void:
	if is_instance_valid(nav_region):
		nav_region.navigation_polygon = nav_poly


func _building_nav_hole(bp: BuildingBlueprint) -> PackedVector2Array:
	var r   := bp.bounds
	var o   := _map_data.origin_offset
	var cnw := Vector2i(r.position.x,     r.position.y    ) + o
	var cne := Vector2i(r.end.x - 1,      r.position.y    ) + o
	var cse := Vector2i(r.end.x - 1,      r.end.y - 1     ) + o
	var csw := Vector2i(r.position.x,     r.end.y - 1     ) + o

	var pn := tilemap.map_to_local(cnw) + Vector2(  0.0, -16.0)
	var pe := tilemap.map_to_local(cne) + Vector2( 32.0,   0.0)
	var ps := tilemap.map_to_local(cse) + Vector2(  0.0,  16.0)
	var pw := tilemap.map_to_local(csw) + Vector2(-32.0,   0.0)

	# Shrink slightly toward centroid so adjacent buildings never share edges.
	const INSET := 3.0
	var centroid := (pn + pe + ps + pw) * 0.25
	pn = centroid + (pn - centroid).normalized() * maxf((pn - centroid).length() - INSET, 1.0)
	pe = centroid + (pe - centroid).normalized() * maxf((pe - centroid).length() - INSET, 1.0)
	ps = centroid + (ps - centroid).normalized() * maxf((ps - centroid).length() - INSET, 1.0)
	pw = centroid + (pw - centroid).normalized() * maxf((pw - centroid).length() - INSET, 1.0)

	# Clockwise winding (N→W→S→E) = negative signed area = hole.
	return PackedVector2Array([pn, pw, ps, pe])


# ── Loot spawning ─────────────────────────────────────────────────────────────
func _spawn_loot() -> void:
	var container            := Node2D.new()
	container.name            = "Loot"
	container.y_sort_enabled  = true
	add_child(container)

	var loot_idx := 0
	for bp: BuildingBlueprint in _map_data.building_blueprints:
		for i in bp.loot_cells.size():
			var item_data: ItemData = bp.loot_items[i] if i < bp.loot_items.size() else null
			if item_data == null:
				continue
			var tile : Vector2i = bp.loot_cells[i]
			var cell : Vector2i = tile + _map_data.origin_offset
			var pos  : Vector2  = tilemap.map_to_local(cell)
			var loot             := LootItem.new()
			loot.name             = "Loot_%d" % loot_idx
			loot.item_data        = item_data
			loot.global_position  = pos
			container.add_child(loot)
			loot_idx += 1


# ── NPC spawning ───────────────────────────────────────────────────────────────
func _spawn_npcs() -> void:
	var idx := 0
	for bp: BuildingBlueprint in _map_data.building_blueprints:
		if bp.zone_type != BuildingBlueprint.ZoneType.COMMERCIAL:
			continue
		var r       := bp.bounds
		var south_c := Vector2i(r.position.x + r.size.x / 2, r.end.y - 1) + _map_data.origin_offset
		var pos     := tilemap.map_to_local(south_c) + Vector2(0.0, 24.0)
		var npc     := npc_scene.instantiate()
		npc.name     = "NPC_%d" % idx
		npc.global_position = pos
		npcs_container.add_child(npc)
		idx += 1
		if idx >= 3:
			break


# ── Entity spawning (server-only) ─────────────────────────────────────────────
func _spawn_players() -> void:
	var peer_ids := GameManager.get_all_peer_ids()
	for i in range(peer_ids.size()):
		var pid  : int      = peer_ids[i]
		var tile : Vector2i = _map_data.player_spawn_tiles[i % _map_data.player_spawn_tiles.size()]
		var pos  : Vector2  = tilemap.map_to_local(tile + _map_data.origin_offset)
		_spawn_player(pid, pos)

	var first_tile: Vector2i = _map_data.player_spawn_tiles[0]
	var first_pos:  Vector2  = tilemap.map_to_local(first_tile + _map_data.origin_offset)
	var test_types: Array    = [0, 0]
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


@rpc("authority", "call_local", "reliable")
func rpc_notify_player_downed(peer_id: int) -> void:
	EventBus.player_downed.emit(peer_id)


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


@rpc("authority", "call_local", "reliable")
func rpc_game_over() -> void:
	GameManager.change_phase(GameManager.Phase.GAME_OVER)


@rpc("authority", "call_local", "reliable")
func rpc_respawn_pending(peer_id: int, delay: float) -> void:
	EventBus.player_respawn_pending.emit(peer_id, delay)


func _schedule_respawn(peer_id: int) -> void:
	_pending_respawns[peer_id] = true
	rpc_respawn_pending.rpc(peer_id, RESPAWN_DELAY)
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_do_respawn.bind(peer_id))


func _do_respawn(peer_id: int) -> void:
	_pending_respawns.erase(peer_id)
	var peer_ids  := GameManager.get_all_peer_ids()
	var tile_idx  := peer_ids.find(peer_id) % _map_data.player_spawn_tiles.size()
	var tile      : Vector2i = _map_data.player_spawn_tiles[tile_idx]
	var pos       : Vector2  = tilemap.map_to_local(tile + _map_data.origin_offset)
	_spawn_player(peer_id, pos)
	if get_tree().get_nodes_in_group("players").size() == 0 and _pending_respawns.is_empty():
		rpc_game_over.rpc()


# ── Loot sync ──────────────────────────────────────────────────────────────────

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_loot_pickup(loot_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	_server_do_loot_pickup(loot_path, multiplayer.get_remote_sender_id())


func _server_do_loot_pickup(loot_path: NodePath, peer_id: int) -> void:
	var loot := get_tree().root.get_node_or_null(loot_path) as LootItem
	if loot == null or not loot.is_in_group("loot_items"):
		return
	if loot.item_data == null:
		return
	var player := GameManager.get_player_node(peer_id)
	if player == null or not is_instance_valid(player):
		return
	var d := loot.item_data
	if peer_id == multiplayer.get_unique_id():
		player.rpc_receive_item.call(d.item_name, d.item_type, d.stat_effects)
	else:
		player.rpc_id(peer_id, "rpc_receive_item", d.item_name, d.item_type, d.stat_effects)
	rpc_remove_loot.rpc(loot_path)


@rpc("authority", "call_local", "reliable")
func rpc_remove_loot(loot_path: NodePath) -> void:
	var node := get_tree().root.get_node_or_null(loot_path)
	if node and is_instance_valid(node):
		node.queue_free()


# ── Door interaction ───────────────────────────────────────────────────────────

## Client → server: request toggling a door identified by its canonical edge key.
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_toggle_door(edge_key: Vector3i) -> void:
	if not multiplayer.is_server():
		return
	_server_toggle_door(edge_key)


func _server_toggle_door(edge_key: Vector3i) -> void:
	if not _door_nodes.has(edge_key):
		return
	var door: DoorNode = _door_nodes[edge_key]
	if not is_instance_valid(door):
		return
	rpc_sync_door_state.rpc(edge_key, not door.is_open)


## Server → all peers: synchronise a door's open/closed state.
@rpc("authority", "call_local", "reliable")
func rpc_sync_door_state(edge_key: Vector3i, is_open: bool) -> void:
	if not _door_nodes.has(edge_key):
		return
	var door: DoorNode = _door_nodes[edge_key]
	if not is_instance_valid(door):
		return
	door.set_open(is_open)
	# Invalidate tile cache so the next cutaway tick recomputes room adjacency
	# (the opened/closed door may create or break a connection between rooms).
	_player_tile = Vector2i(-9999, -9999)
	# Trigger visual refresh on all building renderers that might own this edge.
	for renderer: BuildingTileRenderer in _building_renderers:
		if is_instance_valid(renderer):
			renderer.queue_redraw()


# ── Window interaction ─────────────────────────────────────────────────────────

## Client → server: request toggling a window (open ↔ closed).
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_interact_window(edge_key: Vector3i) -> void:
	if not multiplayer.is_server():
		return
	_server_interact_window(edge_key)


func _server_interact_window(edge_key: Vector3i) -> void:
	if not _map_data.window_edges.has(edge_key):
		return
	var cur_state: int = _map_data.window_edges[edge_key]
	# BROKEN windows cannot be restored this way.
	if cur_state == MapData.WIN_BROKEN:
		return
	var new_state: int = MapData.WIN_OPEN if cur_state != MapData.WIN_OPEN \
						 else MapData.WIN_INTACT
	rpc_sync_window_state.rpc(edge_key, new_state)


## Server → all peers: apply the new window state and update collision.
@rpc("authority", "call_local", "reliable")
func rpc_sync_window_state(edge_key: Vector3i, new_state: int) -> void:
	_map_data.window_edges[edge_key] = new_state
	# Invalidate tile cache — window state change may affect room adjacency.
	_player_tile = Vector2i(-9999, -9999)
	# No window state removes wall collision — all windows require hold-F crawl.
	for renderer: BuildingTileRenderer in _building_renderers:
		if is_instance_valid(renderer):
			renderer.queue_redraw()


# ── Dynamic zombie spawning ────────────────────────────────────────────────────

func spawn_zombie_at(pos: Vector2) -> void:
	spawn_zombie_at_typed(pos, 0)


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

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_item_drop(world_pos: Vector2, node_name: String, item_name: String, item_type: int, effects: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	rpc_spawn_drop.rpc(world_pos, node_name, item_name, item_type, effects)


@rpc("authority", "call_local", "reliable")
func rpc_spawn_drop(world_pos: Vector2, node_name: String, item_name: String, item_type: int, effects: Dictionary) -> void:
	var loot_container := get_node_or_null("Loot")
	if loot_container == null:
		return
	var loot             := LootItem.new()
	loot.name             = node_name
	loot.item_data        = ItemData.make(item_name, item_type, effects)
	loot.global_position  = world_pos
	loot_container.add_child(loot)


# ── Player wall placement (build mode) ────────────────────────────────────────

## Client → server: place one or more wall edges (B-key build mode).
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_place_wall(edges: Array) -> void:
	if not multiplayer.is_server():
		return
	var changed_tiles: Dictionary = {}
	for ek_arr: Array in edges:
		if ek_arr.size() < 3:
			continue
		var tx  : int = ek_arr[0]
		var ty  : int = ek_arr[1]
		var dir : int = ek_arr[2]
		_map_data.add_wall_edge(tx, ty, dir)
		# Mark canonical tile for collision rebuild.
		var ck := MapData.edge_key(tx, ty, dir)
		changed_tiles[Vector2i(ck.x, ck.y)] = true
	# Rebuild collision for affected tiles.
	for tile: Vector2i in changed_tiles:
		_wall_collision_manager.rebuild_tile(tile.x, tile.y)
	# Broadcast to all peers including server.
	rpc_sync_wall_batch.rpc(edges)


## Server → all peers: apply wall batch and redraw renderers.
@rpc("authority", "call_local", "reliable")
func rpc_sync_wall_batch(edges: Array) -> void:
	if multiplayer.is_server():
		return  # Server already applied in rpc_request_place_wall.
	for ek_arr: Array in edges:
		if ek_arr.size() < 3:
			continue
		_map_data.add_wall_edge(ek_arr[0], ek_arr[1], ek_arr[2])
	for renderer: BuildingTileRenderer in _building_renderers:
		if is_instance_valid(renderer):
			renderer.queue_redraw()


# ── Debug editor RPCs (debug builds only) ─────────────────────────────────────
# Client → Server request functions validate is_server(), apply changes, then
# broadcast via the matching rpc_debug_sync_* RPC (call_local, skips server).

@rpc("any_peer", "call_remote", "reliable")
func rpc_debug_set_tile(tx: int, ty: int, tile_type: int) -> void:
	if not multiplayer.is_server():
		return
	_map_data.set_tile(tx, ty, tile_type)
	rpc_debug_sync_tile.rpc(tx, ty, tile_type)


@rpc("authority", "call_local", "reliable")
func rpc_debug_sync_tile(tx: int, ty: int, tile_type: int) -> void:
	if multiplayer.is_server():
		return
	_map_data.set_tile(tx, ty, tile_type)
	tilemap.queue_redraw()


@rpc("any_peer", "call_remote", "reliable")
func rpc_debug_set_furniture(tx: int, ty: int, furn_type: int, rot: int) -> void:
	if not multiplayer.is_server():
		return
	_map_data.set_furniture(tx, ty, furn_type)
	_map_data.set_furn_rot(tx, ty, rot)
	_map_data.set_occupied(tx, ty, furn_type != MapData.FURN_NONE)
	rpc_debug_sync_furniture.rpc(tx, ty, furn_type, rot)


@rpc("authority", "call_local", "reliable")
func rpc_debug_sync_furniture(tx: int, ty: int, furn_type: int, rot: int) -> void:
	if multiplayer.is_server():
		return
	_map_data.set_furniture(tx, ty, furn_type)
	_map_data.set_furn_rot(tx, ty, rot)
	_map_data.set_occupied(tx, ty, furn_type != MapData.FURN_NONE)
	for renderer: BuildingTileRenderer in _building_renderers:
		if is_instance_valid(renderer):
			renderer.refresh_furniture()


@rpc("any_peer", "call_remote", "reliable")
func rpc_debug_set_wall(tx: int, ty: int, dir: int, place: bool) -> void:
	if not multiplayer.is_server():
		return
	if place:
		_map_data.add_wall_edge(tx, ty, dir)
	else:
		_map_data.remove_wall_edge(tx, ty, dir)
	var ck := MapData.edge_key(tx, ty, dir)
	_wall_collision_manager.rebuild_tile(ck.x, ck.y)
	rpc_debug_sync_wall.rpc(tx, ty, dir, place)


@rpc("authority", "call_local", "reliable")
func rpc_debug_sync_wall(tx: int, ty: int, dir: int, place: bool) -> void:
	if multiplayer.is_server():
		return
	if place:
		_map_data.add_wall_edge(tx, ty, dir)
	else:
		_map_data.remove_wall_edge(tx, ty, dir)
	for renderer: BuildingTileRenderer in _building_renderers:
		if is_instance_valid(renderer):
			renderer.refresh_walls()


## edge_mode: 0=plain_wall  1=door  2=window
## state: window WIN_* state (0-3); -1 = remove the edge
@rpc("any_peer", "call_remote", "reliable")
func rpc_debug_set_edge(tx: int, ty: int, dir: int, edge_mode: int, state: int) -> void:
	if not multiplayer.is_server():
		return
	var ek := MapData.edge_key(tx, ty, dir)
	match edge_mode:
		1:   # door
			if state < 0:
				_map_data.door_edges.erase(ek)
			else:
				_map_data.door_edges[ek] = _bp_story_h(tx, ty)
		2:   # window
			if state < 0:
				_map_data.window_edges.erase(ek)
			else:
				_map_data.window_edges[ek] = state
	rpc_debug_sync_edge.rpc(tx, ty, dir, edge_mode, state)


@rpc("authority", "call_local", "reliable")
func rpc_debug_sync_edge(tx: int, ty: int, dir: int, edge_mode: int, state: int) -> void:
	if multiplayer.is_server():
		return
	var ek := MapData.edge_key(tx, ty, dir)
	match edge_mode:
		1:
			if state < 0:
				_map_data.door_edges.erase(ek)
			else:
				_map_data.door_edges[ek] = _bp_story_h(tx, ty)
		2:
			if state < 0:
				_map_data.window_edges.erase(ek)
			else:
				_map_data.window_edges[ek] = state
	for renderer: BuildingTileRenderer in _building_renderers:
		if is_instance_valid(renderer):
			renderer.refresh_walls()


## prop_type = -1 removes the prop at tile_pos; otherwise spawns a new WorldProp.
@rpc("any_peer", "call_remote", "reliable")
func rpc_debug_set_prop(tile_pos: Vector2i, prop_type: int) -> void:
	if not multiplayer.is_server():
		return
	rpc_debug_sync_prop.rpc(tile_pos, prop_type)


@rpc("authority", "call_local", "reliable")
func rpc_debug_sync_prop(tile_pos: Vector2i, prop_type: int) -> void:
	if prop_type < 0:
		# Remove existing prop at this tile.
		for child in entities_container.get_children():
			if child is WorldProp and child.tile_pos == tile_pos:
				child.queue_free()
				break
	else:
		# Remove any existing prop first (prevent duplicates).
		for child in entities_container.get_children():
			if child is WorldProp and child.tile_pos == tile_pos:
				child.queue_free()
				break
		var cell := tile_pos + _map_data.origin_offset
		var prop             := WorldProp.new()
		prop.prop_type        = prop_type
		prop.tile_pos         = tile_pos
		prop.position         = tilemap.map_to_local(cell)
		entities_container.add_child(prop)


@rpc("any_peer", "call_remote", "reliable")
func rpc_debug_spawn_zombie(world_pos: Vector2, zombie_type: int) -> void:
	spawn_zombie_at_typed(world_pos, zombie_type)


# ── Debug helper ──────────────────────────────────────────────────────────────
## Returns the story height (in tiles) of the building that covers this tile,
## or 3 as a sensible fallback for debug-placed doors.
func _bp_story_h(tx: int, ty: int) -> int:
	for bp: BuildingBlueprint in _map_data.building_blueprints:
		if bp.bounds.has_point(Vector2i(tx, ty)):
			return bp.story_h_tiles
	return 3
