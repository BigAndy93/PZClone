class_name MapGenerator
extends RefCounted

# Zone types — matches BuildingData.ZoneType exactly.
enum ZoneType {
	EMPTY       = 0,
	FOREST      = 1,
	RESIDENTIAL = 2,
	COMMERCIAL  = 3,
	INDUSTRIAL  = 4,
	RURAL       = 5,
}

# ---------------------------------------------------------------------------
# Map layout constants
# ---------------------------------------------------------------------------
const ZONE_COLS   := 7
const ZONE_ROWS   := 7
const ZONE_SIZE   := 12   # interior tiles per zone
const ROAD_WIDTH  := 2    # road tiles between zones
const ZONE_STRIDE := ZONE_SIZE + ROAD_WIDTH  # = 14

# Total map size:  7 zones × 12 tiles + 6 road gaps × 2 tiles = 96 per axis
const MAP_W := ZONE_COLS * ZONE_SIZE + (ZONE_COLS - 1) * ROAD_WIDTH
const MAP_H := ZONE_ROWS * ZONE_SIZE + (ZONE_ROWS - 1) * ROAD_WIDTH

# Isolated RNG so generation never interferes with other game RNG.
static var _rng := RandomNumberGenerator.new()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
static func generate(seed_val: int) -> MapData:
	_rng.seed = seed_val

	var data           := MapData.new()
	data.seed_value    = seed_val
	data.map_width     = MAP_W
	data.map_height    = MAP_H
	data.origin_offset = Vector2i(-MAP_W / 2, -MAP_H / 2)
	data.tile_grid     = PackedInt32Array()
	data.tile_grid.resize(MAP_W * MAP_H)
	data.tile_grid.fill(MapData.TILE_GRASS)

	# Generation passes — order is critical per design bible.
	var zones := _generate_zone_types()
	_paint_roads(data)
	_paint_zone_terrain(data, zones)  # biome ground pass
	_place_buildings(data, zones)     # building footprints + loot seeding
	_place_foliage(data, zones)       # foliage markers after buildings
	_place_props(data, zones)         # exterior props after foliage
	_compute_spawns(data, zones)

	return data


# ---------------------------------------------------------------------------
# Zone assignment — concentric distance rings give regional personality.
#
# Distance from center (3,3) via Manhattan metric:
#   dist 0 → center zone         (1 zone)    = EMPTY safe area
#   dist 1 → inner ring          (4 zones)   = commercial hub
#   dist 2 → mid ring            (8 zones)   = residential / commercial
#   dist 3 → outer suburbs       (12 zones)  = residential / rural / forest
#   dist 4 → far suburbs         (12 zones)  = residential / rural / industrial
#   dist 5 → industrial fringe   (8 zones)   = industrial / forest
#   dist 6 → far corners         (4 zones)   = industrial / deep forest
#
# This maps to the bible's region hierarchy:
#   Commercial strip (inner) → Residential suburb → Rural farmland →
#   Forest outskirts → Industrial zone
# ---------------------------------------------------------------------------
static func _generate_zone_types() -> Array:
	var zones: Array = []
	for _gy in ZONE_ROWS:
		var row: Array = []
		for _gx in ZONE_COLS:
			row.append(ZoneType.EMPTY)
		zones.append(row)

	var cx := ZONE_COLS / 2  # = 3
	var cy := ZONE_ROWS / 2  # = 3
	zones[cy][cx] = ZoneType.EMPTY  # center = player safe zone

	for gy in ZONE_ROWS:
		for gx in ZONE_COLS:
			if gx == cx and gy == cy:
				continue
			var dist := absi(gx - cx) + absi(gy - cy)
			zones[gy][gx] = _pick_zone_for_distance(dist)

	return zones


# Weighted pool per distance ring — structured randomness, not scatter.
static func _pick_zone_for_distance(dist: int) -> int:
	var pool: Array
	match dist:
		1:  # inner ring — commercial core
			pool = [
				ZoneType.COMMERCIAL, ZoneType.COMMERCIAL, ZoneType.COMMERCIAL,
				ZoneType.RESIDENTIAL,
			]
		2:  # mid ring — residential with some commercial
			pool = [
				ZoneType.RESIDENTIAL, ZoneType.RESIDENTIAL, ZoneType.RESIDENTIAL,
				ZoneType.COMMERCIAL,
				ZoneType.FOREST,
			]
		3:  # outer suburbs — residential, rural, occasional forest/industrial
			pool = [
				ZoneType.RESIDENTIAL, ZoneType.RESIDENTIAL,
				ZoneType.FOREST, ZoneType.FOREST,
				ZoneType.RURAL,
				ZoneType.INDUSTRIAL,
			]
		4:  # far suburbs — residential fading into rural/industrial
			pool = [
				ZoneType.RESIDENTIAL,
				ZoneType.FOREST, ZoneType.FOREST,
				ZoneType.RURAL, ZoneType.RURAL,
				ZoneType.INDUSTRIAL,
			]
		5:  # industrial/forest fringe — outskirts
			pool = [
				ZoneType.INDUSTRIAL, ZoneType.INDUSTRIAL,
				ZoneType.FOREST, ZoneType.FOREST,
				ZoneType.RURAL,
			]
		_:  # dist 6 = far corners — deep industrial or forest
			pool = [
				ZoneType.INDUSTRIAL,
				ZoneType.FOREST, ZoneType.FOREST, ZoneType.FOREST,
			]
	return pool[_rng.randi() % pool.size()]


# ---------------------------------------------------------------------------
# Tile coordinate helpers
# ---------------------------------------------------------------------------
static func _zone_tile_rect(gz_x: int, gz_y: int) -> Rect2i:
	return Rect2i(gz_x * ZONE_STRIDE, gz_y * ZONE_STRIDE, ZONE_SIZE, ZONE_SIZE)


static func _is_road(tx: int, ty: int) -> bool:
	return (tx % ZONE_STRIDE) >= ZONE_SIZE or (ty % ZONE_STRIDE) >= ZONE_SIZE


# ---------------------------------------------------------------------------
# Terrain passes
# ---------------------------------------------------------------------------
static func _paint_roads(data: MapData) -> void:
	for ty in data.map_height:
		for tx in data.map_width:
			if _is_road(tx, ty):
				data.set_tile(tx, ty, MapData.TILE_ROAD)


static func _paint_zone_terrain(data: MapData, zones: Array) -> void:
	for gy in ZONE_ROWS:
		for gx in ZONE_COLS:
			var zone: int  = zones[gy][gx]
			var rect       := _zone_tile_rect(gx, gy)
			match zone:
				ZoneType.FOREST:
					# Scattered dirt clears — breaks up the green, makes pathfinding visible.
					for dy in rect.size.y:
						for dx in rect.size.x:
							if _rng.randf() < 0.25:
								data.set_tile(rect.position.x + dx, rect.position.y + dy, MapData.TILE_DIRT)
				ZoneType.RURAL:
					# Mostly dirt with sparse grass patches — farmland feel.
					for dy in rect.size.y:
						for dx in rect.size.x:
							if _rng.randf() < 0.65:
								data.set_tile(rect.position.x + dx, rect.position.y + dy, MapData.TILE_DIRT)
				ZoneType.INDUSTRIAL:
					# Solid pavement — concrete yards, asphalt lots.
					for dy in rect.size.y:
						for dx in rect.size.x:
							data.set_tile(rect.position.x + dx, rect.position.y + dy, MapData.TILE_PAVEMENT)
				# RESIDENTIAL, COMMERCIAL, EMPTY: default GRASS — no override needed.


# ---------------------------------------------------------------------------
# Building placement — archetype-driven per zone type
# ---------------------------------------------------------------------------
static func _place_buildings(data: MapData, zones: Array) -> void:
	for gy in ZONE_ROWS:
		for gx in ZONE_COLS:
			var zone: int = zones[gy][gx]
			var count     := _building_count_for_zone(zone)
			if count <= 0:
				continue
			var zone_rect := _zone_tile_rect(gx, gy)
			for _i in count:
				var arch := _pick_archetype(zone)
				_try_place_building(data, zone_rect, zone, arch)


static func _building_count_for_zone(zone: int) -> int:
	match zone:
		ZoneType.RESIDENTIAL: return 3
		ZoneType.COMMERCIAL:  return 2
		ZoneType.INDUSTRIAL:  return 2
		ZoneType.RURAL:       return 1
		_:                    return 0  # EMPTY, FOREST — open ground


# Pick a building archetype appropriate for the zone.
# Matches the building archetype list in the World Generation Bible (section 7).
static func _pick_archetype(zone: int) -> int:
	var pool: Array
	match zone:
		ZoneType.RESIDENTIAL:
			pool = [
				BuildingData.Archetype.SMALL_HOUSE,  BuildingData.Archetype.SMALL_HOUSE,
				BuildingData.Archetype.MEDIUM_HOUSE,
				BuildingData.Archetype.DUPLEX,
			]
		ZoneType.COMMERCIAL:
			pool = [
				BuildingData.Archetype.CONVENIENCE_STORE,
				BuildingData.Archetype.PHARMACY,
				BuildingData.Archetype.HARDWARE_STORE,
				BuildingData.Archetype.OFFICE,
				BuildingData.Archetype.RESTAURANT,
			]
		ZoneType.INDUSTRIAL:
			pool = [
				BuildingData.Archetype.WAREHOUSE,     BuildingData.Archetype.WAREHOUSE,
				BuildingData.Archetype.GARAGE,
				BuildingData.Archetype.STORAGE_YARD,
			]
		ZoneType.RURAL:
			pool = [BuildingData.Archetype.FARMHOUSE]
		_:
			return BuildingData.Archetype.SMALL_HOUSE
	return pool[_rng.randi() % pool.size()]


# Returns [min_w, max_w, min_h, max_h] for a given archetype.
static func _archetype_size(arch: int) -> Array:
	match arch:
		BuildingData.Archetype.SMALL_HOUSE:       return [4,  6,  3, 5]
		BuildingData.Archetype.MEDIUM_HOUSE:      return [5,  8,  4, 6]
		BuildingData.Archetype.CONVENIENCE_STORE: return [5,  8,  4, 6]
		BuildingData.Archetype.PHARMACY:          return [5,  7,  4, 6]
		BuildingData.Archetype.HARDWARE_STORE:    return [6,  9,  5, 7]
		BuildingData.Archetype.OFFICE:            return [5,  8,  4, 6]
		BuildingData.Archetype.WAREHOUSE:         return [7, 11,  6, 9]
		BuildingData.Archetype.GARAGE:            return [4,  7,  3, 5]
		BuildingData.Archetype.FARMHOUSE:         return [4,  7,  3, 6]
		BuildingData.Archetype.RESTAURANT:        return [5,  8,  4, 6]
		BuildingData.Archetype.DUPLEX:            return [6, 10,  4, 6]
		BuildingData.Archetype.STORAGE_YARD:      return [8, 11,  6, 9]
		_:                                         return [4,  7,  3, 5]


static func _try_place_building(data: MapData, zone_rect: Rect2i, zone_type: int, arch: int) -> void:
	const SETBACK := 1  # min tiles between building edge and zone boundary (road setback)
	var sizes      := _archetype_size(arch)
	var min_w: int  = sizes[0]
	var max_w: int  = sizes[1]
	var min_h: int  = sizes[2]
	var max_h: int  = sizes[3]

	var usable_w := zone_rect.size.x - SETBACK * 2
	var usable_h := zone_rect.size.y - SETBACK * 2
	if usable_w < min_w or usable_h < min_h:
		return

	var bw := _rng.randi_range(min_w, mini(max_w, usable_w))
	var bh := _rng.randi_range(min_h, mini(max_h, usable_h))
	var ox  := _rng.randi_range(0, maxi(0, usable_w - bw))
	var oy  := _rng.randi_range(0, maxi(0, usable_h - bh))
	var bx  := zone_rect.position.x + SETBACK + ox
	var by  := zone_rect.position.y + SETBACK + oy

	# Overlap check — abort if any proposed cell is already a floor tile.
	for dy in bh:
		for dx in bw:
			if data.get_tile(bx + dx, by + dy) == MapData.TILE_FLOOR:
				return

	# Paint floor footprint.
	for dy in bh:
		for dx in bw:
			data.set_tile(bx + dx, by + dy, MapData.TILE_FLOOR)

	var bd       := BuildingData.new()
	bd.tile_rect = Rect2i(bx, by, bw, bh)
	bd.zone_type = zone_type
	bd.archetype = arch
	# Door on south edge, away from corners.
	bd.door_cell          = Vector2i(bx + _rng.randi_range(1, bw - 2), by + bh - 1)
	var _bsp_result       = BuildingData.generate_bsp(bd.tile_rect, bd.archetype, _rng)
	bd.rooms              = _bsp_result["rooms"]
	bd.interior_wall_defs = _bsp_result["walls"]

	# Loot spots — density varies by archetype.
	var loot_count: int
	match arch:
		BuildingData.Archetype.WAREHOUSE, BuildingData.Archetype.HARDWARE_STORE, BuildingData.Archetype.STORAGE_YARD:
			loot_count = _rng.randi_range(4, 7)
		BuildingData.Archetype.MEDIUM_HOUSE, BuildingData.Archetype.FARMHOUSE, BuildingData.Archetype.DUPLEX, BuildingData.Archetype.RESTAURANT:
			loot_count = _rng.randi_range(3, 5)
		_:
			loot_count = _rng.randi_range(2, 4)

	for _l in loot_count:
		bd.loot_cells.append(Vector2i(
			_rng.randi_range(bx + 1, bx + bw - 2),
			_rng.randi_range(by + 1, by + bh - 2)
		))
	for _cell in bd.loot_cells:
		bd.loot_items.append(LootTable.get_item_for_zone(zone_type, _rng))

	data.buildings.append(bd)


# ---------------------------------------------------------------------------
# Foliage placement — runs AFTER buildings so we can skip TILE_FLOOR cells.
#
# Foliage data drives two systems:
#   1. WorldTileMap visual rendering (ground-level shapes)
#   2. Future: SightCone occlusion, stealth modifiers (bible section 9)
# ---------------------------------------------------------------------------
static func _place_foliage(data: MapData, zones: Array) -> void:
	for gy in ZONE_ROWS:
		for gx in ZONE_COLS:
			var zone: int = zones[gy][gx]
			var rect      := _zone_tile_rect(gx, gy)
			match zone:
				ZoneType.FOREST:
					# Dense canopy — primary line-of-sight breakers.
					_scatter_foliage(data, rect, 0.12, 0.10, 0.08)
				ZoneType.RURAL:
					# Sparse trees and shrubs along field edges.
					_scatter_foliage(data, rect, 0.03, 0.04, 0.06)
				ZoneType.RESIDENTIAL:
					# Yard trees and garden bushes.
					_scatter_foliage(data, rect, 0.02, 0.02, 0.03)
				# COMMERCIAL, INDUSTRIAL, EMPTY: minimal to no foliage.


static func _scatter_foliage(data: MapData, rect: Rect2i,
		large_chance: float, medium_chance: float, bush_chance: float) -> void:
	for dy in rect.size.y:
		for dx in rect.size.x:
			var tx := rect.position.x + dx
			var ty := rect.position.y + dy
			var tile := data.get_tile(tx, ty)
			# Never place foliage inside buildings or on roads.
			if tile == MapData.TILE_FLOOR or tile == MapData.TILE_ROAD:
				continue
			var r := _rng.randf()
			if r < large_chance:
				data.foliage_cells.append({"pos": Vector2i(tx, ty), "type": 0})
			elif r < large_chance + medium_chance:
				data.foliage_cells.append({"pos": Vector2i(tx, ty), "type": 1})
			elif r < large_chance + medium_chance + bush_chance:
				data.foliage_cells.append({"pos": Vector2i(tx, ty), "type": 2})


# ---------------------------------------------------------------------------
# Prop placement — runs AFTER foliage.
#
# Prop types (MapData.PROP_*):
#   0 TRASH_CAN     — commercial / residential exteriors
#   1 DUMPSTER      — commercial / industrial backlots
#   2 MAILBOX       — residential near building doors
#   3 CAR           — abandoned vehicles in any open area
#   4 LAMPPOST      — zone corners, near road edges
#   5 CRATE         — industrial / commercial lots
#   6 BARREL        — industrial yards
#   7 FIRE_HYDRANT  — commercial / residential sidewalks
# ---------------------------------------------------------------------------
static func _place_props(data: MapData, zones: Array) -> void:
	# Pass A: lampposts at zone corners (non-EMPTY, non-FOREST zones).
	_place_lampposts(data, zones)

	# Pass B: zone-specific scatter props.
	for gy in ZONE_ROWS:
		for gx in ZONE_COLS:
			var zone: int = zones[gy][gx]
			var rect      := _zone_tile_rect(gx, gy)
			match zone:
				ZoneType.INDUSTRIAL:
					_scatter_props(data, rect, [
						[MapData.PROP_BARREL,   0.040],
						[MapData.PROP_CRATE,    0.035],
						[MapData.PROP_DUMPSTER, 0.012],
						[MapData.PROP_CAR,      0.010],
					])
				ZoneType.COMMERCIAL:
					_scatter_props(data, rect, [
						[MapData.PROP_TRASH_CAN,    0.030],
						[MapData.PROP_DUMPSTER,     0.010],
						[MapData.PROP_CAR,          0.018],
						[MapData.PROP_FIRE_HYDRANT, 0.008],
					])
				ZoneType.RESIDENTIAL:
					_scatter_props(data, rect, [
						[MapData.PROP_TRASH_CAN,    0.020],
						[MapData.PROP_MAILBOX,      0.020],
						[MapData.PROP_CAR,          0.010],
						[MapData.PROP_FIRE_HYDRANT, 0.006],
					])
				ZoneType.RURAL:
					_scatter_props(data, rect, [
						[MapData.PROP_BARREL,    0.015],
						[MapData.PROP_CRATE,     0.012],
					])


# Lampposts at the 4 corner tiles of each non-EMPTY non-FOREST zone.
# Corners are 1 tile inside the zone — right at the road setback line.
static func _place_lampposts(data: MapData, zones: Array) -> void:
	for gy in ZONE_ROWS:
		for gx in ZONE_COLS:
			var zone: int = zones[gy][gx]
			if zone == ZoneType.EMPTY or zone == ZoneType.FOREST:
				continue
			var rect := _zone_tile_rect(gx, gy)
			var corners: Array[Vector2i] = [
				rect.position,
				Vector2i(rect.end.x - 1, rect.position.y),
				Vector2i(rect.position.x, rect.end.y - 1),
				rect.end - Vector2i(1, 1),
			]
			for corner: Vector2i in corners:
				if data.get_tile(corner.x, corner.y) != MapData.TILE_FLOOR:
					data.prop_cells.append({"pos": corner, "type": MapData.PROP_LAMPPOST})


# Scatter props within a rect, skipping floor and road tiles.
# prop_chances: Array of [type: int, chance: float] — probabilities are checked
# sequentially (first match wins; values are per-tile chances, not cumulative).
static func _scatter_props(data: MapData, rect: Rect2i, prop_chances: Array) -> void:
	for dy in rect.size.y:
		for dx in rect.size.x:
			var tx   := rect.position.x + dx
			var ty   := rect.position.y + dy
			var tile := data.get_tile(tx, ty)
			if tile == MapData.TILE_FLOOR or tile == MapData.TILE_ROAD:
				continue
			for entry in prop_chances:
				if _rng.randf() < entry[1]:
					data.prop_cells.append({"pos": Vector2i(tx, ty), "type": entry[0]})
					break  # one prop per tile


# ---------------------------------------------------------------------------
# Spawn computation
# ---------------------------------------------------------------------------
static func _compute_spawns(data: MapData, zones: Array) -> void:
	var cx     := ZONE_COLS / 2
	var cy     := ZONE_ROWS / 2
	var c_rect := _zone_tile_rect(cx, cy)
	var ctr    := c_rect.get_center()

	# 4 player spawns symmetrically placed inside the center EMPTY zone.
	data.player_spawn_tiles.clear()
	var offsets: Array[Vector2i] = [
		Vector2i( 2,  1), Vector2i(-2,  1),
		Vector2i( 1, -2), Vector2i(-1, -2),
	]
	for off in offsets:
		data.player_spawn_tiles.append(Vector2i(ctr.x + off.x, ctr.y + off.y))

	# Zombie clusters per zone — density follows the bible's hierarchy:
	# Urban (commercial) > industrial > residential > rural > forest.
	data.zombie_zone_data.clear()
	for gy in ZONE_ROWS:
		for gx in ZONE_COLS:
			var zone: int = zones[gy][gx]
			var density   := _zombie_density_for_zone(zone)
			if density < 0.05:
				continue
			var zr := _zone_tile_rect(gx, gy)
			data.zombie_zone_data.append({
				"tile_pos": Vector2i(zr.get_center()),
				"count":    int(density * 10.0) + _rng.randi_range(0, 1),
				"density":  density,
			})


static func _zombie_density_for_zone(zone: int) -> float:
	# Reduced ~70% for testing; restore original values when tuning horde balance.
	match zone:
		ZoneType.COMMERCIAL:  return 0.30
		ZoneType.INDUSTRIAL:  return 0.24
		ZoneType.RESIDENTIAL: return 0.15
		ZoneType.RURAL:       return 0.06
		ZoneType.FOREST:      return 0.05
		_:                    return 0.0   # EMPTY — safe spawn zone
