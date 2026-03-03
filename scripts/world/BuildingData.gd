class_name BuildingData
extends RefCounted

# Matches MapGenerator.ZoneType (extended)
enum ZoneType {
	EMPTY       = 0,
	FOREST      = 1,
	RESIDENTIAL = 2,
	COMMERCIAL  = 3,
	INDUSTRIAL  = 4,
	RURAL       = 5,
}

# Building archetypes — determines footprint size range, loot density, visual palette.
enum Archetype {
	SMALL_HOUSE       = 0,   # 4-6 × 3-5 tiles
	MEDIUM_HOUSE      = 1,   # 5-8 × 4-6 tiles
	CONVENIENCE_STORE = 2,   # 5-8 × 4-6 tiles
	PHARMACY          = 3,   # 5-7 × 4-6 tiles
	HARDWARE_STORE    = 4,   # 6-9 × 5-7 tiles (heavy loot)
	OFFICE            = 5,   # 5-8 × 4-6 tiles
	WAREHOUSE         = 6,   # 7-11 × 6-9 tiles (heavy loot)
	GARAGE            = 7,   # 4-7 × 3-5 tiles
	FARMHOUSE         = 8,   # 4-7 × 3-6 tiles
	RESTAURANT        = 9,   # 5-8 × 4-6 tiles (commercial — food loot bias)
	DUPLEX            = 10,  # 6-10 × 4-6 tiles (residential — two-unit house)
	STORAGE_YARD      = 11,  # 8-12 × 6-9 tiles (industrial — open-sided shed)
}

# Tile rect in 0-based map tile coords (position = top-left, end = exclusive)
var tile_rect:  Rect2i
var zone_type:  int = ZoneType.RESIDENTIAL
var archetype:  int = Archetype.SMALL_HOUSE
var door_cell:  Vector2i        # tile coord of the door opening

# Parallel arrays.  loot_items[i] is the item (or null) at loot_cells[i].
var loot_cells: Array[Vector2i] = []
var loot_items: Array           = []  # Array[ItemData?]

var rooms:              Array = []   # Array[RoomDef]
var interior_wall_defs: Array = []   # Array[RoomDef.InteriorWallDef]


static func default_rooms(arch: int) -> Array:
	match arch:
		Archetype.SMALL_HOUSE:
			return [
				RoomDef.make(RoomDef.RoomPurpose.BEDROOM, -0.80, 0.80, -0.80, 0.00),
				RoomDef.make(RoomDef.RoomPurpose.LIVING,  -0.80, 0.80,  0.00, 0.80),
			]
		Archetype.FARMHOUSE:
			return [
				RoomDef.make(RoomDef.RoomPurpose.BEDROOM,  0.10, 0.80, -0.80, 0.80),
				RoomDef.make(RoomDef.RoomPurpose.KITCHEN, -0.80, 0.10, -0.80, 0.80),
			]
		Archetype.MEDIUM_HOUSE:
			return [
				RoomDef.make(RoomDef.RoomPurpose.BEDROOM,  0.05, 0.80, -0.80, 0.00),
				RoomDef.make(RoomDef.RoomPurpose.BEDROOM,  0.05, 0.80,  0.00, 0.80),
				RoomDef.make(RoomDef.RoomPurpose.LIVING,  -0.80, 0.05, -0.80, 0.80),
			]
		Archetype.DUPLEX:
			return [
				RoomDef.make(RoomDef.RoomPurpose.BEDROOM,  0.05, 0.80, -0.80, -0.05),
				RoomDef.make(RoomDef.RoomPurpose.LIVING,  -0.80, 0.05, -0.80, -0.05),
				RoomDef.make(RoomDef.RoomPurpose.BEDROOM,  0.05, 0.80,  0.05,  0.80),
				RoomDef.make(RoomDef.RoomPurpose.LIVING,  -0.80, 0.05,  0.05,  0.80),
			]
		_:  # all commercial/industrial archetypes
			return [RoomDef.make(RoomDef.RoomPurpose.COMMERCIAL, -0.80, 0.80, -0.80, 0.80)]


static func default_walls(arch: int) -> Array:
	var IWD := RoomDef.InteriorWallDef
	match arch:
		Archetype.SMALL_HOUSE:
			# EF wall at ef=0.00, full nf range, door at nf=0.00 (centre).
			return [IWD.make(IWD.Axis.EF, 0.00, -0.80, 0.80, 0.00)]
		Archetype.FARMHOUSE:
			# NF wall at nf=0.10, full ef range, door at ef=-0.15.
			return [IWD.make(IWD.Axis.NF, 0.10, -0.80, 0.80, -0.15)]
		Archetype.MEDIUM_HOUSE:
			# Wall 1: NF at 0.05, full ef, door at ef=-0.30.
			# Wall 2: EF at 0.00, only bedroom zone nf=[0.05,0.80], door at nf=0.38.
			return [
				IWD.make(IWD.Axis.NF, 0.05, -0.80,  0.80, -0.30),
				IWD.make(IWD.Axis.EF, 0.00,  0.05,  0.80,  0.38),
			]
		Archetype.DUPLEX:
			# Centre EF divider (no door — separate units).
			# NF walls for each unit's bedroom/living split.
			return [
				IWD.make(IWD.Axis.EF,  0.00, -0.80,  0.80),          # no door
				IWD.make(IWD.Axis.NF,  0.05, -0.80, -0.05, -0.40),
				IWD.make(IWD.Axis.NF,  0.05,  0.05,  0.80,  0.40),
			]
		_:
			return []


## Generates rooms and interior walls via BSP for residential archetypes.
## Commercial/industrial archetypes return one COMMERCIAL room + no walls.
static func generate_bsp(tile_rect: Rect2i, arch: int, rng: RandomNumberGenerator) -> Dictionary:
	const RESIDENTIAL := [
		Archetype.SMALL_HOUSE, Archetype.MEDIUM_HOUSE,
		Archetype.FARMHOUSE,   Archetype.DUPLEX,
	]
	if arch not in RESIDENTIAL:
		return {
			"rooms": [RoomDef.make(RoomDef.RoomPurpose.COMMERCIAL, -0.80, 0.80, -0.80, 0.80)],
			"walls": [],
		}

	var rooms : Array = []
	var walls : Array = []
	var bx    := tile_rect.position.x
	var by    := tile_rect.position.y
	var bw    := tile_rect.size.x
	var bh    := tile_rect.size.y

	_bsp_recurse(rooms, walls, rng, arch, bx, by, bw, bh,
	             bx + 1, bx + bw - 2,
	             by + 1, by + bh - 2,
	             -0.80, 0.80, -0.80, 0.80, 2)

	return { "rooms": rooms, "walls": walls }


static func _bsp_recurse(
		rooms: Array, walls: Array,
		rng: RandomNumberGenerator, arch: int,
		bx: int, by: int, bw: int, bh: int,
		ix0: int, ix1: int, iy0: int, iy1: int,
		nf_lo: float, nf_hi: float,
		ef_lo: float, ef_hi: float, depth: int) -> void:
	const MIN_TILES := 2
	var w := ix1 - ix0 + 1
	var h := iy1 - iy0 + 1
	var can_col := w >= MIN_TILES * 2
	var can_row := h >= MIN_TILES * 2

	if depth <= 0 or (not can_col and not can_row):
		rooms.append(RoomDef.make(
			_bsp_purpose(arch, nf_lo, nf_hi, ef_lo, ef_hi),
			nf_lo, nf_hi, ef_lo, ef_hi))
		return

	var split_col: bool
	if can_col and can_row:
		split_col = (w >= h)
		if w == h:
			split_col = rng.randi() % 2 == 0
	elif can_col:
		split_col = true
	else:
		split_col = false

	if split_col:
		var c       := rng.randi_range(ix0 + MIN_TILES - 1, ix1 - MIN_TILES + 1)
		var ef_wall := _tile_to_ef(c, bx, bw)
		var door_nf := _tile_to_nf(rng.randi_range(iy0, iy1), by, bh)
		walls.append(RoomDef.InteriorWallDef.make(
			RoomDef.InteriorWallDef.Axis.EF, ef_wall, nf_lo, nf_hi, door_nf))
		_bsp_recurse(rooms, walls, rng, arch, bx, by, bw, bh,
		             ix0, c - 1, iy0, iy1, nf_lo, nf_hi, ef_lo, ef_wall, depth - 1)
		_bsp_recurse(rooms, walls, rng, arch, bx, by, bw, bh,
		             c, ix1, iy0, iy1, nf_lo, nf_hi, ef_wall, ef_hi, depth - 1)
	else:
		var r       := rng.randi_range(iy0 + MIN_TILES - 1, iy1 - MIN_TILES + 1)
		var nf_wall := _tile_to_nf(r, by, bh)
		var door_ef := _tile_to_ef(rng.randi_range(ix0, ix1), bx, bw)
		walls.append(RoomDef.InteriorWallDef.make(
			RoomDef.InteriorWallDef.Axis.NF, nf_wall, ef_lo, ef_hi, door_ef))
		_bsp_recurse(rooms, walls, rng, arch, bx, by, bw, bh,
		             ix0, ix1, iy0, r - 1, nf_wall, nf_hi, ef_lo, ef_hi, depth - 1)
		_bsp_recurse(rooms, walls, rng, arch, bx, by, bw, bh,
		             ix0, ix1, r, iy1, nf_lo, nf_wall, ef_lo, ef_hi, depth - 1)


static func _tile_to_ef(col: int, bx: int, bw: int) -> float:
	if bw <= 1: return 0.0
	return (float(col - bx) / float(bw - 1)) * 1.60 - 0.80


static func _tile_to_nf(row: int, by: int, bh: int) -> float:
	if bh <= 1: return 0.0
	return 0.80 - (float(row - by) / float(bh - 1)) * 1.60


static func _bsp_purpose(arch: int,
		nf_lo: float, nf_hi: float, ef_lo: float, ef_hi: float) -> int:
	var nf_c := (nf_lo + nf_hi) * 0.5
	var ef_c := (ef_lo + ef_hi) * 0.5
	match arch:
		Archetype.FARMHOUSE:
			return RoomDef.RoomPurpose.BEDROOM if nf_c >= 0.0 else RoomDef.RoomPurpose.KITCHEN
		_:   # SMALL_HOUSE, MEDIUM_HOUSE, DUPLEX
			if nf_c > 0.0:
				return RoomDef.RoomPurpose.BEDROOM   # north rooms = bedrooms
			elif ef_c > 0.0:
				return RoomDef.RoomPurpose.KITCHEN   # south-east = kitchen
			else:
				return RoomDef.RoomPurpose.LIVING    # south-west = living room
