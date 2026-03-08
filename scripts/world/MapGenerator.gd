class_name MapGenerator
extends RefCounted

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
const ZONE_SIZE   := 12
const ROAD_WIDTH  := 2
const ZONE_STRIDE := ZONE_SIZE + ROAD_WIDTH  # = 14

const MAP_W := ZONE_COLS * ZONE_SIZE + (ZONE_COLS - 1) * ROAD_WIDTH
const MAP_H := ZONE_ROWS * ZONE_SIZE + (ZONE_ROWS - 1) * ROAD_WIDTH

static var _rng := RandomNumberGenerator.new()


# ---------------------------------------------------------------------------
# Furniture footprint helpers
# ---------------------------------------------------------------------------

## Extra tile extents (fp_e, fp_n) beyond the anchor for multi-tile furniture.
static func _furn_fp(furn_type: int) -> Vector2i:
	match furn_type:
		MapData.FURN_COUNTER: return Vector2i(1, 0)
	return Vector2i.ZERO

## Returns true if the furniture type has a rot=1 baked texture.
static func _supports_rot1(furn_type: int) -> bool:
	return furn_type in [
		MapData.FURN_SOFA, MapData.FURN_SHELF, MapData.FURN_COUNTER,
		MapData.FURN_LOCKER, MapData.FURN_FRIDGE, MapData.FURN_DRESSER,
		MapData.FURN_BATHTUB, MapData.FURN_DESK,
	]

## Maps wall direction + furniture type to a visual rotation (0 or 1).
static func _wall_rot(wall_dir: int, furn_type: int) -> int:
	if (wall_dir == MapData.DIR_W or wall_dir == MapData.DIR_E) and _supports_rot1(furn_type):
		return 1
	return 0

## Returns the extra-tile unit direction in map space for a given rotation.
static func _rot_e_dir(rot: int) -> Vector2i:
	match rot:
		0: return Vector2i(1, 0)
		1: return Vector2i(0, 1)
		2: return Vector2i(-1, 0)
		_: return Vector2i(0, -1)

## Returns all map tiles occupied by a piece (anchor + footprint extensions).
static func _fp_cells(anchor: Vector2i, rot: int, fp: Vector2i) -> Array:
	if fp == Vector2i.ZERO:
		return [anchor]
	var e_dir := _rot_e_dir(rot)
	var cells  := [anchor]
	for i in range(1, fp.x + 1):
		cells.append(anchor + e_dir * i)
	return cells

## Returns true if every footprint cell is inside the room, unoccupied, and outside the door zone.
static func _fp_valid(data: MapData, room: BuildingBlueprint.RoomDef,
		cells: Array, dz: Dictionary) -> bool:
	for cell: Vector2i in cells:
		if cell not in room.floor_cells:
			return false
		if data.is_occupied(cell.x, cell.y):
			return false
		if dz.has(cell):
			return false
	return true


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
static func generate(seed_val: int) -> MapData:
	_rng.seed = seed_val

	var data              := MapData.new()
	data.seed_value        = seed_val
	data.origin_offset     = Vector2i(-MAP_W / 2, -MAP_H / 2)
	data.init_grids(MAP_W, MAP_H)

	var zones := _generate_zone_types()
	_paint_roads(data)
	_paint_zone_terrain(data, zones)
	_place_buildings(data, zones)
	_place_foliage(data, zones)
	_place_props(data, zones)
	_compute_spawns(data, zones)

	return data


# ---------------------------------------------------------------------------
# Zone assignment
# ---------------------------------------------------------------------------
static func _generate_zone_types() -> Array:
	var zones: Array = []
	for _gy in ZONE_ROWS:
		var row: Array = []
		for _gx in ZONE_COLS:
			row.append(ZoneType.EMPTY)
		zones.append(row)

	var cx := ZONE_COLS / 2
	var cy := ZONE_ROWS / 2
	zones[cy][cx] = ZoneType.EMPTY

	for gy in ZONE_ROWS:
		for gx in ZONE_COLS:
			if gx == cx and gy == cy:
				continue
			var dist := absi(gx - cx) + absi(gy - cy)
			zones[gy][gx] = _pick_zone_for_distance(dist)

	return zones


static func _pick_zone_for_distance(dist: int) -> int:
	var pool: Array
	match dist:
		1:
			pool = [ZoneType.COMMERCIAL, ZoneType.COMMERCIAL, ZoneType.COMMERCIAL, ZoneType.RESIDENTIAL]
		2:
			pool = [ZoneType.RESIDENTIAL, ZoneType.RESIDENTIAL, ZoneType.RESIDENTIAL, ZoneType.COMMERCIAL, ZoneType.FOREST]
		3:
			pool = [ZoneType.RESIDENTIAL, ZoneType.RESIDENTIAL, ZoneType.FOREST, ZoneType.FOREST, ZoneType.RURAL, ZoneType.INDUSTRIAL]
		4:
			pool = [ZoneType.RESIDENTIAL, ZoneType.FOREST, ZoneType.FOREST, ZoneType.RURAL, ZoneType.RURAL, ZoneType.INDUSTRIAL]
		5:
			pool = [ZoneType.INDUSTRIAL, ZoneType.INDUSTRIAL, ZoneType.FOREST, ZoneType.FOREST, ZoneType.RURAL]
		_:
			pool = [ZoneType.INDUSTRIAL, ZoneType.FOREST, ZoneType.FOREST, ZoneType.FOREST]
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
			var zone: int = zones[gy][gx]
			var rect      := _zone_tile_rect(gx, gy)
			match zone:
				ZoneType.FOREST:
					for dy in rect.size.y:
						for dx in rect.size.x:
							if _rng.randf() < 0.25:
								data.set_tile(rect.position.x + dx, rect.position.y + dy, MapData.TILE_DIRT)
				ZoneType.RURAL:
					for dy in rect.size.y:
						for dx in rect.size.x:
							if _rng.randf() < 0.65:
								data.set_tile(rect.position.x + dx, rect.position.y + dy, MapData.TILE_DIRT)
				ZoneType.INDUSTRIAL:
					for dy in rect.size.y:
						for dx in rect.size.x:
							data.set_tile(rect.position.x + dx, rect.position.y + dy, MapData.TILE_PAVEMENT)


# ---------------------------------------------------------------------------
# Building placement
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
		_:                    return 0


static func _pick_archetype(zone: int) -> int:
	var pool: Array
	match zone:
		ZoneType.RESIDENTIAL:
			pool = [
				BuildingBlueprint.Archetype.SMALL_HOUSE,  BuildingBlueprint.Archetype.SMALL_HOUSE,
				BuildingBlueprint.Archetype.MEDIUM_HOUSE,
				BuildingBlueprint.Archetype.DUPLEX,
			]
		ZoneType.COMMERCIAL:
			pool = [
				BuildingBlueprint.Archetype.CONVENIENCE_STORE,
				BuildingBlueprint.Archetype.PHARMACY,
				BuildingBlueprint.Archetype.HARDWARE_STORE,
				BuildingBlueprint.Archetype.OFFICE,
				BuildingBlueprint.Archetype.RESTAURANT,
			]
		ZoneType.INDUSTRIAL:
			pool = [
				BuildingBlueprint.Archetype.WAREHOUSE,    BuildingBlueprint.Archetype.WAREHOUSE,
				BuildingBlueprint.Archetype.GARAGE,
				BuildingBlueprint.Archetype.STORAGE_YARD,
			]
		ZoneType.RURAL:
			pool = [BuildingBlueprint.Archetype.FARMHOUSE]
		_:
			return BuildingBlueprint.Archetype.SMALL_HOUSE
	return pool[_rng.randi() % pool.size()]


static func _archetype_size(arch: int) -> Array[int]:
	match arch:
		BuildingBlueprint.Archetype.SMALL_HOUSE:       return [4,  6,  3, 5]
		BuildingBlueprint.Archetype.MEDIUM_HOUSE:      return [5,  8,  4, 6]
		BuildingBlueprint.Archetype.CONVENIENCE_STORE: return [5,  8,  4, 6]
		BuildingBlueprint.Archetype.PHARMACY:          return [5,  7,  4, 6]
		BuildingBlueprint.Archetype.HARDWARE_STORE:    return [6,  9,  5, 7]
		BuildingBlueprint.Archetype.OFFICE:            return [5,  8,  4, 6]
		BuildingBlueprint.Archetype.WAREHOUSE:         return [7, 11,  6, 9]
		BuildingBlueprint.Archetype.GARAGE:            return [4,  7,  3, 5]
		BuildingBlueprint.Archetype.FARMHOUSE:         return [4,  7,  3, 6]
		BuildingBlueprint.Archetype.RESTAURANT:        return [5,  8,  4, 6]
		BuildingBlueprint.Archetype.DUPLEX:            return [6, 10,  4, 6]
		BuildingBlueprint.Archetype.STORAGE_YARD:      return [8, 11,  6, 9]
		_:                                              return [4,  7,  3, 5]


static func _try_place_building(data: MapData, zone_rect: Rect2i, zone_type: int, arch: int) -> void:
	const SETBACK := 1
	var sizes     := _archetype_size(arch)
	var min_w     := sizes[0];  var max_w := sizes[1]
	var min_h     := sizes[2];  var max_h := sizes[3]
	var usable_w  := zone_rect.size.x - SETBACK * 2
	var usable_h  := zone_rect.size.y - SETBACK * 2
	if usable_w < min_w or usable_h < min_h:
		return

	var bw := _rng.randi_range(min_w, mini(max_w, usable_w))
	var bh := _rng.randi_range(min_h, mini(max_h, usable_h))
	var ox  := _rng.randi_range(0, maxi(0, usable_w - bw))
	var oy  := _rng.randi_range(0, maxi(0, usable_h - bh))
	var bx  := zone_rect.position.x + SETBACK + ox
	var by  := zone_rect.position.y + SETBACK + oy

	# Overlap check.
	for dy in bh:
		for dx in bw:
			if data.get_tile(bx + dx, by + dy) == MapData.TILE_FLOOR:
				return

	# ── Paint floor + build blueprint shell ─────────────────────────────────
	var bp           := BuildingBlueprint.new()
	bp.bounds         = Rect2i(bx, by, bw, bh)
	bp.zone_type      = zone_type
	bp.archetype      = arch
	bp.height_tiles   = 4 if (bw >= 8 or bh >= 7) else 3

	for dy in bh:
		for dx in bw:
			data.set_tile(bx + dx, by + dy, MapData.TILE_FLOOR)
			bp.floor_cells[Vector2i(bx + dx, by + dy)] = true

	# Exterior wall edges — all four sides.
	for tx in range(bx, bx + bw):
		data.add_wall_edge(tx, by, MapData.DIR_N)
	for tx in range(bx, bx + bw):
		data.add_wall_edge(tx, by + bh, MapData.DIR_N)
	for ty in range(by, by + bh):
		data.add_wall_edge(bx, ty, MapData.DIR_W)
	for ty in range(by, by + bh):
		data.add_wall_edge(bx + bw, ty, MapData.DIR_W)

	# ── Room subdivision ─────────────────────────────────────────────────────
	if arch in BuildingBlueprint.RESIDENTIAL_ARCHETYPES:
		_layout_residential_rooms(data, bp, bx, by, bw, bh)
	else:
		_layout_commercial_rooms(data, bp, bx, by, bw, bh, arch)

	# ── Exterior entry door on south face ────────────────────────────────────
	var door_tx  := bx + _rng.randi_range(1, bw - 2)
	var entry_ek := MapData.edge_key(door_tx, by + bh, MapData.DIR_N)
	data.remove_wall_edge(door_tx, by + bh, MapData.DIR_N)
	data.door_edges[entry_ek] = bp.height_tiles
	bp.entry_edges.append(entry_ek)

	# ── Windows ──────────────────────────────────────────────────────────────
	_place_windows(data, bx, by, bw, bh, arch)

	# ── Furniture ────────────────────────────────────────────────────────────
	_place_furniture(data, bp)

	# ── Container-based loot ─────────────────────────────────────────────────
	var loot_count: int
	match arch:
		BuildingBlueprint.Archetype.WAREHOUSE, BuildingBlueprint.Archetype.HARDWARE_STORE, BuildingBlueprint.Archetype.STORAGE_YARD:
			loot_count = _rng.randi_range(4, 7)
		BuildingBlueprint.Archetype.MEDIUM_HOUSE, BuildingBlueprint.Archetype.FARMHOUSE, BuildingBlueprint.Archetype.DUPLEX, BuildingBlueprint.Archetype.RESTAURANT:
			loot_count = _rng.randi_range(3, 5)
		_:
			loot_count = _rng.randi_range(2, 4)
	_place_container_loot(data, bp, zone_type, loot_count)

	data.building_blueprints.append(bp)


# ---------------------------------------------------------------------------
# Residential room layout
# ---------------------------------------------------------------------------
## DUPLEX: vertical center wall → two units each BSP-split.
## All other residential: straight BSP.
static func _layout_residential_rooms(data: MapData, bp: BuildingBlueprint,
		bx: int, by: int, bw: int, bh: int) -> void:
	if bp.archetype == BuildingBlueprint.Archetype.DUPLEX and bw >= 8:
		var center_col := bx + bw / 2
		_add_vertical_interior_wall(data, bp, by, bh, center_col)
		_bsp_split(data, bp, Rect2i(bx,          by, center_col - bx,     bh), 0)
		_bsp_split(data, bp, Rect2i(center_col,  by, bx + bw - center_col, bh), 0)
	else:
		_bsp_split(data, bp, Rect2i(bx, by, bw, bh), 0)


# ---------------------------------------------------------------------------
# Commercial / industrial room subdivision
# ---------------------------------------------------------------------------
static func _layout_commercial_rooms(data: MapData, bp: BuildingBlueprint,
		bx: int, by: int, bw: int, bh: int, arch: int) -> void:
	match arch:
		BuildingBlueprint.Archetype.CONVENIENCE_STORE, BuildingBlueprint.Archetype.PHARMACY:
			# North = back storage (35%), south = front sales (65%)
			var split_h := maxi(2, int(float(bh) * 0.65))
			_add_horizontal_interior_wall(data, bp, bx, bw, by + split_h)
			_add_room(bp, BuildingBlueprint.RoomDef.Purpose.STORAGE,    Rect2i(bx, by,             bw, split_h))
			_add_room(bp, BuildingBlueprint.RoomDef.Purpose.COMMERCIAL, Rect2i(bx, by + split_h,   bw, bh - split_h))

		BuildingBlueprint.Archetype.RESTAURANT:
			# North = kitchen (45%), south = dining floor (55%)
			var split_h := maxi(2, int(float(bh) * 0.55))
			_add_horizontal_interior_wall(data, bp, bx, bw, by + split_h)
			_add_room(bp, BuildingBlueprint.RoomDef.Purpose.KITCHEN, Rect2i(bx, by,             bw, split_h))
			_add_room(bp, BuildingBlueprint.RoomDef.Purpose.DINING,  Rect2i(bx, by + split_h,   bw, bh - split_h))

		BuildingBlueprint.Archetype.OFFICE:
			if bw >= 7:
				# Main office floor (west ~70%) + private offices / storage (east ~30%)
				var split_w := bw - maxi(2, int(float(bw) * 0.30))
				_add_vertical_interior_wall(data, bp, by, bh, bx + split_w)
				_add_room(bp, BuildingBlueprint.RoomDef.Purpose.OFFICE_FLOOR, Rect2i(bx,          by, split_w,      bh))
				_add_room(bp, BuildingBlueprint.RoomDef.Purpose.STORAGE,      Rect2i(bx + split_w, by, bw - split_w, bh))
			else:
				_add_single_room(bp, BuildingBlueprint.RoomDef.Purpose.OFFICE_FLOOR, bx, by, bw, bh)

		BuildingBlueprint.Archetype.HARDWARE_STORE:
			# North = loading / storage (40%), south = sales floor (60%)
			var split_h := maxi(2, int(float(bh) * 0.60))
			_add_horizontal_interior_wall(data, bp, bx, bw, by + split_h)
			_add_room(bp, BuildingBlueprint.RoomDef.Purpose.STORAGE,    Rect2i(bx, by,           bw, split_h))
			_add_room(bp, BuildingBlueprint.RoomDef.Purpose.COMMERCIAL, Rect2i(bx, by + split_h, bw, bh - split_h))

		BuildingBlueprint.Archetype.WAREHOUSE:
			if bw >= 9:
				# West strip = small office (3 tiles wide), east = main warehouse floor
				var off_w := 3
				_add_vertical_interior_wall(data, bp, by, bh, bx + off_w)
				_add_room(bp, BuildingBlueprint.RoomDef.Purpose.OFFICE_FLOOR, Rect2i(bx,          by, off_w,      bh))
				_add_room(bp, BuildingBlueprint.RoomDef.Purpose.COMMERCIAL,   Rect2i(bx + off_w,  by, bw - off_w, bh))
			else:
				_add_single_room(bp, BuildingBlueprint.RoomDef.Purpose.COMMERCIAL, bx, by, bw, bh)

		BuildingBlueprint.Archetype.GARAGE:
			if bw >= 5:
				# East end = storage cell (2–3 tiles wide), rest = main bay
				var off_w := mini(3, bw - 2)
				_add_vertical_interior_wall(data, bp, by, bh, bx + bw - off_w)
				_add_room(bp, BuildingBlueprint.RoomDef.Purpose.COMMERCIAL, Rect2i(bx,              by, bw - off_w, bh))
				_add_room(bp, BuildingBlueprint.RoomDef.Purpose.STORAGE,    Rect2i(bx + bw - off_w, by, off_w,      bh))
			else:
				_add_single_room(bp, BuildingBlueprint.RoomDef.Purpose.COMMERCIAL, bx, by, bw, bh)

		_:
			# STORAGE_YARD and others: single open room
			_add_single_room(bp, BuildingBlueprint.RoomDef.Purpose.COMMERCIAL, bx, by, bw, bh)


# ---------------------------------------------------------------------------
# Interior wall helpers
# ---------------------------------------------------------------------------
## Horizontal interior wall: N edge of tiles in row split_row, cols bx..bx+bw-1.
## Includes junction tiles with exterior walls to close the 1-tile corner gap.
## Adds a door gap.
static func _add_horizontal_interior_wall(data: MapData, bp: BuildingBlueprint,
		bx: int, bw: int, split_row: int) -> void:
	for tx in range(bx, bx + bw):
		data.add_wall_edge(tx, split_row, MapData.DIR_N)
	var door_tx := bx + _rng.randi_range(1, bw - 2)
	data.remove_wall_edge(door_tx, split_row, MapData.DIR_N)
	data.door_edges[MapData.edge_key(door_tx, split_row, MapData.DIR_N)] = bp.height_tiles


## Vertical interior wall: W edge of tiles in col split_col, rows by..by+bh-1.
## Includes junction tiles with exterior walls to close the 1-tile corner gap.
## Adds a door gap.
static func _add_vertical_interior_wall(data: MapData, bp: BuildingBlueprint,
		by: int, bh: int, split_col: int) -> void:
	for ty in range(by, by + bh):
		data.add_wall_edge(split_col, ty, MapData.DIR_W)
	var door_ty := by + _rng.randi_range(1, bh - 2)
	data.remove_wall_edge(split_col, door_ty, MapData.DIR_W)
	data.door_edges[MapData.edge_key(split_col, door_ty, MapData.DIR_W)] = bp.height_tiles


## Adds a RoomDef with floor_cells covering the FULL rect (outer ring included).
## Including the outer ring allows furniture to be placed against exterior/interior walls.
static func _add_room(bp: BuildingBlueprint, purpose: int, room_rect: Rect2i) -> void:
	var room := BuildingBlueprint.RoomDef.make(bp.rooms.size(), purpose, room_rect)
	for dy in room_rect.size.y:
		for dx in room_rect.size.x:
			room.floor_cells.append(Vector2i(room_rect.position.x + dx, room_rect.position.y + dy))
	bp.rooms.append(room)


static func _add_single_room(bp: BuildingBlueprint, purpose: int,
		bx: int, by: int, bw: int, bh: int) -> void:
	_add_room(bp, purpose, Rect2i(bx, by, bw, bh))


# ---------------------------------------------------------------------------
# BSP room subdivision — writes interior wall edges directly to MapData.
# floor_cells now include the full outer ring so _place_against_wall can detect
# exterior and interior walls correctly.
# ---------------------------------------------------------------------------
static func _bsp_split(data: MapData, bp: BuildingBlueprint, rect: Rect2i, depth: int) -> void:
	var can_vsplit := rect.size.x >= 6
	var can_hsplit := rect.size.y >= 6

	if depth >= 2 or (not can_vsplit and not can_hsplit):
		# Leaf: full outer ring included in floor_cells.
		var room := BuildingBlueprint.RoomDef.make(bp.rooms.size(), _bsp_purpose(bp.archetype, rect, bp.bounds), rect)
		for dy in rect.size.y:
			for dx in rect.size.x:
				room.floor_cells.append(Vector2i(rect.position.x + dx, rect.position.y + dy))
		bp.rooms.append(room)
		return

	if can_vsplit and (not can_hsplit or rect.size.x >= rect.size.y):
		var col := rect.position.x + _rng.randi_range(3, rect.size.x - 3)
		for ty in range(rect.position.y, rect.end.y):
			data.add_wall_edge(col, ty, MapData.DIR_W)
		var door_ty := rect.position.y + _rng.randi_range(1, rect.size.y - 2)
		data.remove_wall_edge(col, door_ty, MapData.DIR_W)
		data.door_edges[MapData.edge_key(col, door_ty, MapData.DIR_W)] = bp.height_tiles
		_bsp_split(data, bp, Rect2i(rect.position, Vector2i(col - rect.position.x, rect.size.y)), depth + 1)
		_bsp_split(data, bp, Rect2i(Vector2i(col, rect.position.y), Vector2i(rect.end.x - col, rect.size.y)), depth + 1)
	else:
		var row := rect.position.y + _rng.randi_range(3, rect.size.y - 3)
		for tx in range(rect.position.x, rect.end.x):
			data.add_wall_edge(tx, row, MapData.DIR_N)
		var door_tx := rect.position.x + _rng.randi_range(1, rect.size.x - 2)
		data.remove_wall_edge(door_tx, row, MapData.DIR_N)
		data.door_edges[MapData.edge_key(door_tx, row, MapData.DIR_N)] = bp.height_tiles
		_bsp_split(data, bp, Rect2i(rect.position, Vector2i(rect.size.x, row - rect.position.y)), depth + 1)
		_bsp_split(data, bp, Rect2i(Vector2i(rect.position.x, row), Vector2i(rect.size.x, rect.end.y - row)), depth + 1)


static func _bsp_purpose(arch: int, room_rect: Rect2i, building_bounds: Rect2i) -> int:
	if arch not in BuildingBlueprint.RESIDENTIAL_ARCHETYPES:
		return BuildingBlueprint.RoomDef.Purpose.COMMERCIAL
	var rcy := room_rect.get_center().y
	var rcx := room_rect.get_center().x
	var bcy := building_bounds.get_center().y
	var bcx := building_bounds.get_center().x
	if rcy < bcy:
		return BuildingBlueprint.RoomDef.Purpose.BEDROOM
	if rcx >= bcx:
		return BuildingBlueprint.RoomDef.Purpose.KITCHEN
	return BuildingBlueprint.RoomDef.Purpose.LIVING


# ---------------------------------------------------------------------------
# Windows — NE + NW faces (original) + SE + SW faces (new for larger buildings)
# ---------------------------------------------------------------------------
static func _place_windows(data: MapData, bx: int, by: int, bw: int, bh: int, arch: int) -> void:
	# NE face — N edge of row by (right-leaning in iso)
	var n_count := 1 if arch in [BuildingBlueprint.Archetype.SMALL_HOUSE, BuildingBlueprint.Archetype.FARMHOUSE, BuildingBlueprint.Archetype.GARAGE] else 2
	for i in n_count:
		var tx := bx + 1 + int(float(i) / float(n_count) * (bw - 2)) if n_count > 1 else bx + bw / 2
		if tx <= bx or tx >= bx + bw - 1:
			continue
		var ek := MapData.edge_key(tx, by, MapData.DIR_N)
		if data.has_wall_edge(tx, by, MapData.DIR_N) and not data.door_edges.has(ek):
			data.window_edges[ek] = MapData.WIN_INTACT

	# NW face — W edge of col bx (left-leaning in iso)
	var w_count := 1 if bh <= 5 else 2
	for i in w_count:
		var ty := by + 1 + int(float(i) / float(w_count) * (bh - 2)) if w_count > 1 else by + bh / 2
		if ty <= by or ty >= by + bh - 1:
			continue
		var ek := MapData.edge_key(bx, ty, MapData.DIR_W)
		if data.has_wall_edge(bx, ty, MapData.DIR_W) and not data.door_edges.has(ek):
			data.window_edges[ek] = MapData.WIN_INTACT

	# SE face — N edge of row by+bh (south-facing, camera-visible)
	var se_archs := [
		BuildingBlueprint.Archetype.MEDIUM_HOUSE, BuildingBlueprint.Archetype.DUPLEX,
		BuildingBlueprint.Archetype.OFFICE, BuildingBlueprint.Archetype.RESTAURANT,
		BuildingBlueprint.Archetype.FARMHOUSE,
	]
	if arch in se_archs:
		var se_count := 1 if bw <= 6 else 2
		for i in se_count:
			var tx := bx + 1 + int(float(i) / float(se_count) * (bw - 2)) if se_count > 1 else bx + bw / 2
			if tx <= bx or tx >= bx + bw - 1:
				continue
			var ek := MapData.edge_key(tx, by + bh, MapData.DIR_N)
			if data.has_wall_edge(tx, by + bh, MapData.DIR_N) and not data.door_edges.has(ek):
				data.window_edges[ek] = MapData.WIN_INTACT

	# SW face — W edge of col bx+bw (east-facing)
	var sw_archs := [
		BuildingBlueprint.Archetype.MEDIUM_HOUSE, BuildingBlueprint.Archetype.DUPLEX,
		BuildingBlueprint.Archetype.OFFICE,
	]
	if arch in sw_archs:
		var sw_count := 1 if bh <= 5 else 2
		for i in sw_count:
			var ty := by + 1 + int(float(i) / float(sw_count) * (bh - 2)) if sw_count > 1 else by + bh / 2
			if ty <= by or ty >= by + bh - 1:
				continue
			var ek := MapData.edge_key(bx + bw, ty, MapData.DIR_W)
			if data.has_wall_edge(bx + bw, ty, MapData.DIR_W) and not data.door_edges.has(ek):
				data.window_edges[ek] = MapData.WIN_INTACT


# ---------------------------------------------------------------------------
# Furniture placement — per-room-purpose rules with door clearance
# ---------------------------------------------------------------------------
static func _place_furniture(data: MapData, bp: BuildingBlueprint) -> void:
	var dz := _build_door_zone(data, bp)
	for room: BuildingBlueprint.RoomDef in bp.rooms:
		match room.purpose:
			BuildingBlueprint.RoomDef.Purpose.BEDROOM:
				_wall(data, room, MapData.FURN_BED,        dz, [MapData.DIR_N, MapData.DIR_W, MapData.DIR_E, MapData.DIR_S])
				_wall(data, room, MapData.FURN_NIGHTSTAND, dz, [MapData.DIR_N, MapData.DIR_W, MapData.DIR_E, MapData.DIR_S])
				_wall(data, room, MapData.FURN_LOCKER,     dz, [MapData.DIR_E, MapData.DIR_S, MapData.DIR_W, MapData.DIR_N])

			BuildingBlueprint.RoomDef.Purpose.LIVING:
				_wall(data, room, MapData.FURN_SOFA,  dz, [MapData.DIR_S, MapData.DIR_E, MapData.DIR_W, MapData.DIR_N])
				_free(data, room, MapData.FURN_TABLE, dz)
				_free(data, room, MapData.FURN_CHAIR, dz)

			BuildingBlueprint.RoomDef.Purpose.KITCHEN:
				_wall(data, room, MapData.FURN_STOVE,   dz, [MapData.DIR_N, MapData.DIR_W, MapData.DIR_E, MapData.DIR_S])
				_wall(data, room, MapData.FURN_COUNTER, dz, [MapData.DIR_N, MapData.DIR_W, MapData.DIR_E, MapData.DIR_S])
				_wall(data, room, MapData.FURN_COUNTER, dz, [MapData.DIR_W, MapData.DIR_E, MapData.DIR_S, MapData.DIR_N])

			BuildingBlueprint.RoomDef.Purpose.STORAGE:
				_wall(data, room, MapData.FURN_SHELF,  dz, [MapData.DIR_N, MapData.DIR_W, MapData.DIR_E, MapData.DIR_S])
				_wall(data, room, MapData.FURN_SHELF,  dz, [MapData.DIR_W, MapData.DIR_E, MapData.DIR_S, MapData.DIR_N])
				_wall(data, room, MapData.FURN_SHELF,  dz, [MapData.DIR_E, MapData.DIR_S, MapData.DIR_N, MapData.DIR_W])
				_wall(data, room, MapData.FURN_LOCKER, dz, [MapData.DIR_N, MapData.DIR_W, MapData.DIR_E, MapData.DIR_S])

			BuildingBlueprint.RoomDef.Purpose.COMMERCIAL:
				# Shelf aisles against walls + checkout counter near south entry
				for _i in 3:
					_wall(data, room, MapData.FURN_SHELF, dz, [MapData.DIR_N, MapData.DIR_W, MapData.DIR_E, MapData.DIR_S])
				_wall(data, room, MapData.FURN_COUNTER, dz, [MapData.DIR_S, MapData.DIR_E, MapData.DIR_W, MapData.DIR_N])
				_wall(data, room, MapData.FURN_LOCKER,  dz, [MapData.DIR_N, MapData.DIR_W, MapData.DIR_E, MapData.DIR_S])

			BuildingBlueprint.RoomDef.Purpose.DINING:
				# Tables in interior, chairs flanking them
				var table_count := maxi(2, room.floor_cells.size() / 8)
				for _i in table_count:
					_free(data, room, MapData.FURN_TABLE, dz)
				for _i in table_count * 2:
					_free(data, room, MapData.FURN_CHAIR, dz)

			BuildingBlueprint.RoomDef.Purpose.OFFICE_FLOOR:
				# Desks in interior + filing cabinets (lockers) along walls
				var desk_count := maxi(1, room.floor_cells.size() / 6)
				for _i in desk_count:
					_free(data, room, MapData.FURN_DESK, dz)
				_wall(data, room, MapData.FURN_LOCKER, dz, [MapData.DIR_N, MapData.DIR_W, MapData.DIR_E, MapData.DIR_S])
				_wall(data, room, MapData.FURN_LOCKER, dz, [MapData.DIR_W, MapData.DIR_E, MapData.DIR_S, MapData.DIR_N])

			BuildingBlueprint.RoomDef.Purpose.HALLWAY:
				pass  # no furniture in hallways


## Returns a set of tiles that should be kept clear of furniture (door approach zones).
static func _build_door_zone(data: MapData, bp: BuildingBlueprint) -> Dictionary:
	var blocked: Dictionary = {}
	var b := bp.bounds
	for ek: Vector3i in data.door_edges:
		var tx := ek.x;  var ty := ek.y;  var dir := ek.z
		# Only consider doors within or adjacent to this building's bounds.
		if tx < b.position.x or tx > b.end.x or ty < b.position.y or ty > b.end.y:
			continue
		blocked[Vector2i(tx, ty)] = true
		# Block the tile on the interior side of the door gap.
		if dir == MapData.DIR_N:
			blocked[Vector2i(tx, ty - 1)] = true
		else:  # DIR_W
			blocked[Vector2i(tx - 1, ty)] = true
	return blocked


## Place furn_type on a wall-adjacent tile inside room (preferred_dirs prioritised).
## Validates the full footprint before placing; sets rotation derived from wall direction.
static func _wall(data: MapData, room: BuildingBlueprint.RoomDef,
		furn_type: int, dz: Dictionary, preferred_dirs: Array) -> bool:
	# Collect (cell, matched_dir) pairs for wall-adjacent, unoccupied, non-doorway tiles.
	var candidates: Array = []
	for cell: Vector2i in room.floor_cells:
		if data.is_occupied(cell.x, cell.y) or dz.has(cell):
			continue
		for dir in preferred_dirs:
			if data.has_wall_edge(cell.x, cell.y, dir):
				var ek := MapData.edge_key(cell.x, cell.y, dir)
				if not data.door_edges.has(ek):
					candidates.append([cell, dir])
					break
	if candidates.is_empty():
		return false
	# Filter candidates by footprint validity.
	var fp := _furn_fp(furn_type)
	var valid: Array = []
	for cand: Array in candidates:
		var cell: Vector2i = cand[0]
		var dir: int       = cand[1]
		var rot: int       = _wall_rot(dir, furn_type)
		var cells: Array   = _fp_cells(cell, rot, fp)
		if _fp_valid(data, room, cells, dz):
			valid.append([cell, rot, cells])
	if valid.is_empty():
		return false
	# Pick a random valid candidate and place.
	var pick: Array     = valid[_rng.randi() % valid.size()]
	var anchor: Vector2i = pick[0]
	var rot: int         = pick[1]
	var fp_cells: Array  = pick[2]
	data.set_furniture(anchor.x, anchor.y, furn_type)
	data.set_furn_rot(anchor.x, anchor.y, rot)
	data.set_occupied(anchor.x, anchor.y, true)
	# Mark extra footprint tiles as occupied (no furniture type stored).
	for cell: Vector2i in fp_cells:
		if cell != anchor:
			data.set_occupied(cell.x, cell.y, true)
	return true


## Place furn_type on an interior (non-wall-adjacent) tile; falls back to any open tile.
## Assigns a random valid rotation and validates the full footprint.
static func _free(data: MapData, room: BuildingBlueprint.RoomDef,
		furn_type: int, dz: Dictionary) -> bool:
	# Determine which rotations are available for this type.
	var rots: Array = [0, 1] if _supports_rot1(furn_type) else [0]
	var fp := _furn_fp(furn_type)
	var inner: Array = []
	var any_open: Array = []
	for cell: Vector2i in room.floor_cells:
		if data.is_occupied(cell.x, cell.y) or dz.has(cell):
			continue
		# Check whether cell is free of wall edges on all sides.
		var has_wall := false
		for dir in [MapData.DIR_N, MapData.DIR_W, MapData.DIR_E, MapData.DIR_S]:
			if data.has_wall_edge(cell.x, cell.y, dir):
				has_wall = true
				break
		# For each candidate cell try each rotation and validate footprint.
		for rot: int in rots:
			var cells := _fp_cells(cell, rot, fp)
			if _fp_valid(data, room, cells, dz):
				var entry := [cell, rot, cells]
				if not has_wall:
					inner.append(entry)
				any_open.append(entry)
				break  # First valid rotation per cell is enough for candidacy.
	var pool := inner if not inner.is_empty() else any_open
	if pool.is_empty():
		return false
	var pick: Array      = pool[_rng.randi() % pool.size()]
	var anchor: Vector2i = pick[0]
	var rot: int         = pick[1]
	var fp_cells: Array  = pick[2]
	data.set_furniture(anchor.x, anchor.y, furn_type)
	data.set_furn_rot(anchor.x, anchor.y, rot)
	data.set_occupied(anchor.x, anchor.y, true)
	for cell: Vector2i in fp_cells:
		if cell != anchor:
			data.set_occupied(cell.x, cell.y, true)
	return true


# ---------------------------------------------------------------------------
# Container-based loot — attaches items to shelf / counter / nightstand / locker
# ---------------------------------------------------------------------------
static func _place_container_loot(data: MapData, bp: BuildingBlueprint,
		zone_type: int, loot_count: int) -> void:
	var container_types := [
		MapData.FURN_SHELF, MapData.FURN_NIGHTSTAND,
		MapData.FURN_LOCKER, MapData.FURN_COUNTER,
	]
	# Collect container tiles from bp.floor_cells (Dictionary).
	var containers: Array[Vector2i] = []
	for cell: Vector2i in bp.floor_cells:
		if data.get_furniture(cell.x, cell.y) in container_types:
			containers.append(cell)

	# Fisher-Yates shuffle.
	for i in range(containers.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := containers[i];  containers[i] = containers[j];  containers[j] = tmp

	var placed := 0
	for container in containers:
		if placed >= loot_count:
			break
		bp.loot_cells.append(container)
		bp.loot_items.append(LootTable.get_item_for_zone(zone_type, _rng))
		placed += 1
		# Chance of a second item in the same container.
		if placed < loot_count and _rng.randf() < 0.35:
			bp.loot_cells.append(container)
			bp.loot_items.append(LootTable.get_item_for_zone(zone_type, _rng))
			placed += 1

	# Fallback: rooms with no containers (e.g. empty garage bay) use floor tiles.
	while placed < loot_count:
		var b := bp.bounds
		bp.loot_cells.append(Vector2i(
			_rng.randi_range(b.position.x + 1, b.end.x - 2),
			_rng.randi_range(b.position.y + 1, b.end.y - 2)
		))
		bp.loot_items.append(LootTable.get_item_for_zone(zone_type, _rng))
		placed += 1


# ---------------------------------------------------------------------------
# Foliage — Phase A: 1-tile clearance buffer around any building floor tile
# ---------------------------------------------------------------------------
static func _place_foliage(data: MapData, zones: Array) -> void:
	for gy in ZONE_ROWS:
		for gx in ZONE_COLS:
			var zone: int = zones[gy][gx]
			var rect      := _zone_tile_rect(gx, gy)
			match zone:
				ZoneType.FOREST:
					_scatter_foliage(data, rect, 0.12, 0.10, 0.08)
				ZoneType.RURAL:
					_scatter_foliage(data, rect, 0.03, 0.04, 0.06)
				ZoneType.RESIDENTIAL:
					_scatter_foliage(data, rect, 0.02, 0.02, 0.03)


static func _scatter_foliage(data: MapData, rect: Rect2i,
		large_chance: float, medium_chance: float, bush_chance: float) -> void:
	for dy in rect.size.y:
		for dx in rect.size.x:
			var tx   := rect.position.x + dx
			var ty   := rect.position.y + dy
			var tile := data.get_tile(tx, ty)
			if tile == MapData.TILE_FLOOR or tile == MapData.TILE_ROAD:
				continue
			# Skip tiles adjacent to any building floor tile (1-tile clearance buffer).
			var near_floor := false
			for off: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				if data.get_tile(tx + off.x, ty + off.y) == MapData.TILE_FLOOR:
					near_floor = true
					break
			if near_floor:
				continue
			var r := _rng.randf()
			if r < large_chance:
				data.foliage_cells.append({"pos": Vector2i(tx, ty), "type": 0})
			elif r < large_chance + medium_chance:
				data.foliage_cells.append({"pos": Vector2i(tx, ty), "type": 1})
			elif r < large_chance + medium_chance + bush_chance:
				data.foliage_cells.append({"pos": Vector2i(tx, ty), "type": 2})


# ---------------------------------------------------------------------------
# Props — Phase A: same 1-tile clearance buffer as foliage
# ---------------------------------------------------------------------------
static func _place_props(data: MapData, zones: Array) -> void:
	_place_lampposts(data, zones)
	for gy in ZONE_ROWS:
		for gx in ZONE_COLS:
			var zone: int = zones[gy][gx]
			var rect      := _zone_tile_rect(gx, gy)
			match zone:
				ZoneType.INDUSTRIAL:
					_scatter_props(data, rect, [[MapData.PROP_BARREL, 0.040], [MapData.PROP_CRATE, 0.035], [MapData.PROP_DUMPSTER, 0.012], [MapData.PROP_CAR, 0.010]])
				ZoneType.COMMERCIAL:
					_scatter_props(data, rect, [[MapData.PROP_TRASH_CAN, 0.030], [MapData.PROP_DUMPSTER, 0.010], [MapData.PROP_CAR, 0.018], [MapData.PROP_FIRE_HYDRANT, 0.008]])
				ZoneType.RESIDENTIAL:
					_scatter_props(data, rect, [[MapData.PROP_TRASH_CAN, 0.020], [MapData.PROP_MAILBOX, 0.020], [MapData.PROP_CAR, 0.010], [MapData.PROP_FIRE_HYDRANT, 0.006]])
				ZoneType.RURAL:
					_scatter_props(data, rect, [[MapData.PROP_BARREL, 0.015], [MapData.PROP_CRATE, 0.012]])


static func _place_lampposts(data: MapData, zones: Array) -> void:
	for gy in ZONE_ROWS:
		for gx in ZONE_COLS:
			var zone: int = zones[gy][gx]
			if zone == ZoneType.EMPTY or zone == ZoneType.FOREST:
				continue
			var rect    := _zone_tile_rect(gx, gy)
			var corners: Array[Vector2i] = [
				rect.position,
				Vector2i(rect.end.x - 1, rect.position.y),
				Vector2i(rect.position.x, rect.end.y - 1),
				rect.end - Vector2i(1, 1),
			]
			for corner: Vector2i in corners:
				if data.get_tile(corner.x, corner.y) != MapData.TILE_FLOOR:
					data.prop_cells.append({"pos": corner, "type": MapData.PROP_LAMPPOST})


static func _scatter_props(data: MapData, rect: Rect2i, prop_chances: Array) -> void:
	for dy in rect.size.y:
		for dx in rect.size.x:
			var tx   := rect.position.x + dx
			var ty   := rect.position.y + dy
			var tile := data.get_tile(tx, ty)
			if tile == MapData.TILE_FLOOR or tile == MapData.TILE_ROAD:
				continue
			# Skip tiles adjacent to any building floor tile.
			var near_floor := false
			for off: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				if data.get_tile(tx + off.x, ty + off.y) == MapData.TILE_FLOOR:
					near_floor = true
					break
			if near_floor:
				continue
			for entry in prop_chances:
				if _rng.randf() < entry[1]:
					data.prop_cells.append({"pos": Vector2i(tx, ty), "type": entry[0]})
					break


# ---------------------------------------------------------------------------
# Spawn computation
# ---------------------------------------------------------------------------
static func _compute_spawns(data: MapData, zones: Array) -> void:
	var cx     := ZONE_COLS / 2
	var cy     := ZONE_ROWS / 2
	var c_rect := _zone_tile_rect(cx, cy)
	var ctr    := c_rect.get_center()

	data.player_spawn_tiles.clear()
	var offsets: Array[Vector2i] = [
		Vector2i( 2,  1), Vector2i(-2,  1),
		Vector2i( 1, -2), Vector2i(-1, -2),
	]
	for off in offsets:
		data.player_spawn_tiles.append(Vector2i(ctr.x + off.x, ctr.y + off.y))

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
	match zone:
		ZoneType.COMMERCIAL:  return 0.30
		ZoneType.INDUSTRIAL:  return 0.24
		ZoneType.RESIDENTIAL: return 0.15
		ZoneType.RURAL:       return 0.06
		ZoneType.FOREST:      return 0.05
		_:                    return 0.0
