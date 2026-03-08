class_name MapData
extends Resource

# ── Tile type IDs ──────────────────────────────────────────────────────────────
const TILE_GRASS    := 0
const TILE_ROAD     := 1
const TILE_DIRT     := 2
const TILE_FLOOR    := 3  # indoor floor
const TILE_PAVEMENT := 4  # industrial concrete / asphalt
const TILE_COUNT    := 5

# ── Prop type IDs ─────────────────────────────────────────────────────────────
const PROP_TRASH_CAN    := 0
const PROP_DUMPSTER     := 1
const PROP_MAILBOX      := 2
const PROP_CAR          := 3
const PROP_LAMPPOST     := 4
const PROP_CRATE        := 5
const PROP_BARREL       := 6
const PROP_FIRE_HYDRANT := 7

# ── Wall edge direction constants ─────────────────────────────────────────────
# Canonical ownership: tile (tx,ty) owns its NORTH and WEST edges.
#   SOUTH edge of (tx,ty)   ==  NORTH edge of (tx, ty+1)
#   EAST  edge of (tx,ty)   ==  WEST  edge of (tx+1, ty)
const DIR_N := 0
const DIR_E := 1
const DIR_S := 2
const DIR_W := 3

# Per-tile wall grid bitflags (only N and W are canonical)
const WALL_N       := 1  # north edge → NE diamond face (right-leaning)
const WALL_W       := 2  # west  edge → NW diamond face (left-leaning)
const PLAYER_BUILT := 4  # marks player-constructed edges

# ── Furniture type constants ──────────────────────────────────────────────────
const FURN_NONE       := 0
const FURN_BED        := 1
const FURN_DESK       := 2
const FURN_CHAIR      := 3
const FURN_TABLE      := 4
const FURN_SOFA       := 5
const FURN_SHELF      := 6
const FURN_COUNTER    := 7
const FURN_STOVE      := 8
const FURN_LOCKER     := 9
const FURN_NIGHTSTAND := 10
const FURN_FRIDGE     := 11
const FURN_DRESSER    := 12
const FURN_BATHTUB    := 13

# ── Map dimensions ────────────────────────────────────────────────────────────
var seed_value:    int = 0
var map_width:     int = 0
var map_height:    int = 0
# Add this to any 0-based map tile coord to get the TileMapLayer cell coord.
var origin_offset: Vector2i

# ── Per-tile grids (all size = map_width × map_height) ───────────────────────
var tile_grid:          PackedInt32Array  # terrain type
var wall_grid:          PackedInt32Array  # WALL_N | WALL_W | PLAYER_BUILT per tile
var furniture_grid:     PackedInt32Array  # FURN_* type per tile
var occupied_grid:      PackedByteArray   # 1 = occupied by furniture
var furniture_rot_grid: PackedByteArray   # 0-3 rotation per tile (90° CW increments)

# ── Window states ─────────────────────────────────────────────────────────────
const WIN_INTACT  := 0   # glass unbroken,     passable = false
const WIN_CRACKED := 1   # glass cracked,      passable = false
const WIN_BROKEN  := 2   # glass destroyed,    passable = true
const WIN_OPEN    := 3   # sash pushed open,   passable = true

# ── Sparse edge dictionaries ──────────────────────────────────────────────────
# Key: Vector3i(tx, ty, dir) — always canonical (DIR_N or DIR_W).
var door_edges:   Dictionary = {}  # → int  (wall height in tiles)
var window_edges: Dictionary = {}  # → int  (WIN_* state)

# ── Building blueprints ───────────────────────────────────────────────────────
var building_blueprints: Array = []  # Array[BuildingBlueprint]

# ── Spawn / zone data ─────────────────────────────────────────────────────────
var player_spawn_tiles: Array[Vector2i] = []
var zombie_zone_data:   Array = []
var foliage_cells:      Array = []
var prop_cells:         Array = []


# ── Grid initialisation ───────────────────────────────────────────────────────
## Allocate and zero-fill all per-tile grids. Call once per generation.
func init_grids(w: int, h: int) -> void:
	map_width  = w
	map_height = h
	var size   := w * h
	tile_grid = PackedInt32Array()
	tile_grid.resize(size)
	tile_grid.fill(TILE_GRASS)
	wall_grid = PackedInt32Array()
	wall_grid.resize(size)
	wall_grid.fill(0)
	furniture_grid = PackedInt32Array()
	furniture_grid.resize(size)
	furniture_grid.fill(0)
	occupied_grid = PackedByteArray()
	occupied_grid.resize(size)
	occupied_grid.fill(0)
	furniture_rot_grid = PackedByteArray()
	furniture_rot_grid.resize(size)
	furniture_rot_grid.fill(0)


# ── Tile accessors ────────────────────────────────────────────────────────────
func get_tile(tx: int, ty: int) -> int:
	if tx < 0 or ty < 0 or tx >= map_width or ty >= map_height:
		return TILE_GRASS
	return tile_grid[ty * map_width + tx]

func set_tile(tx: int, ty: int, type: int) -> void:
	if tx < 0 or ty < 0 or tx >= map_width or ty >= map_height:
		return
	tile_grid[ty * map_width + tx] = type


# ── Wall edge helpers ─────────────────────────────────────────────────────────
## Returns the canonical edge key (always DIR_N or DIR_W).
## S → north edge of (tx, ty+1); E → west edge of (tx+1, ty).
static func edge_key(tx: int, ty: int, dir: int) -> Vector3i:
	match dir:
		DIR_S: return Vector3i(tx,     ty + 1, DIR_N)
		DIR_E: return Vector3i(tx + 1, ty,     DIR_W)
		_:     return Vector3i(tx,     ty,     dir)

func get_wall(tx: int, ty: int) -> int:
	if tx < 0 or ty < 0 or tx >= map_width or ty >= map_height:
		return 0
	return wall_grid[ty * map_width + tx]

func has_wall_edge(tx: int, ty: int, dir: int) -> bool:
	var k := edge_key(tx, ty, dir)
	if k.x < 0 or k.y < 0 or k.x >= map_width or k.y >= map_height:
		return false
	var flags := wall_grid[k.y * map_width + k.x]
	return bool(flags & (WALL_N if k.z == DIR_N else WALL_W))

func add_wall_edge(tx: int, ty: int, dir: int) -> void:
	var k := edge_key(tx, ty, dir)
	if k.x < 0 or k.y < 0 or k.x >= map_width or k.y >= map_height:
		return
	var idx := k.y * map_width + k.x
	var bit := WALL_N if k.z == DIR_N else WALL_W
	wall_grid[idx] = wall_grid[idx] | bit

func remove_wall_edge(tx: int, ty: int, dir: int) -> void:
	var k := edge_key(tx, ty, dir)
	if k.x < 0 or k.y < 0 or k.x >= map_width or k.y >= map_height:
		return
	var idx := k.y * map_width + k.x
	var bit := WALL_N if k.z == DIR_N else WALL_W
	wall_grid[idx] = wall_grid[idx] & ~bit


# ── Furniture accessors ───────────────────────────────────────────────────────
func get_furniture(tx: int, ty: int) -> int:
	if tx < 0 or ty < 0 or tx >= map_width or ty >= map_height:
		return FURN_NONE
	return furniture_grid[ty * map_width + tx]

func set_furniture(tx: int, ty: int, furn_type: int) -> void:
	if tx < 0 or ty < 0 or tx >= map_width or ty >= map_height:
		return
	furniture_grid[ty * map_width + tx] = furn_type

func is_occupied(tx: int, ty: int) -> bool:
	if tx < 0 or ty < 0 or tx >= map_width or ty >= map_height:
		return true
	return occupied_grid[ty * map_width + tx] != 0

func set_occupied(tx: int, ty: int, val: bool) -> void:
	if tx < 0 or ty < 0 or tx >= map_width or ty >= map_height:
		return
	occupied_grid[ty * map_width + tx] = (1 if val else 0)


# ── Furniture rotation accessors ───────────────────────────────────────────────
func get_furn_rot(tx: int, ty: int) -> int:
	if tx < 0 or ty < 0 or tx >= map_width or ty >= map_height:
		return 0
	return furniture_rot_grid[ty * map_width + tx]

func set_furn_rot(tx: int, ty: int, rot: int) -> void:
	if tx < 0 or ty < 0 or tx >= map_width or ty >= map_height:
		return
	furniture_rot_grid[ty * map_width + tx] = clampi(rot, 0, 3)
