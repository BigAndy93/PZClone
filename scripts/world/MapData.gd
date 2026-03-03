class_name MapData
extends Resource

# Tile type IDs — index into WorldTileMap.TILE_COLORS
const TILE_GRASS    := 0
const TILE_ROAD     := 1
const TILE_DIRT     := 2
const TILE_FLOOR    := 3  # indoor floor
const TILE_PAVEMENT := 4  # industrial concrete / asphalt
const TILE_COUNT    := 5

# Prop type IDs — used in prop_cells entries.
const PROP_TRASH_CAN := 0  # small bin; commercial / residential
const PROP_DUMPSTER  := 1  # large container; commercial / industrial
const PROP_MAILBOX   := 2  # post box; residential
const PROP_CAR       := 3  # abandoned vehicle; any zone
const PROP_LAMPPOST  := 4  # street light; zone corners
const PROP_CRATE     := 5  # wooden box; industrial / commercial
const PROP_BARREL    := 6  # oil barrel; industrial
const PROP_FIRE_HYDRANT := 7  # fire hydrant; commercial / residential

var seed_value:    int = 0
var map_width:     int = 0  # total tile columns
var map_height:    int = 0  # total tile rows
# Add this to any 0-based map tile coord to get the TileMapLayer cell coord.
var origin_offset: Vector2i

# Flat row-major tile grid.  Access: tile_grid[ty * map_width + tx]
var tile_grid: PackedInt32Array

# Array[BuildingData]
var buildings: Array = []

# Player spawn positions in 0-based map tile coords
var player_spawn_tiles: Array[Vector2i] = []

# Array of Dictionaries:  { tile_pos: Vector2i, count: int, density: float }
var zombie_zone_data: Array = []

# Foliage placement markers for WorldTileMap rendering and gameplay.
# Array of Dictionaries: { pos: Vector2i (0-based map coords), type: int }
# type: 0 = large tree, 1 = medium tree, 2 = bush
var foliage_cells: Array = []

# Prop placement markers for WorldTileMap rendering.
# Array of Dictionaries: { pos: Vector2i (0-based map coords), type: int }
var prop_cells: Array = []


func get_tile(tx: int, ty: int) -> int:
	if tx < 0 or ty < 0 or tx >= map_width or ty >= map_height:
		return TILE_GRASS
	return tile_grid[ty * map_width + tx]


func set_tile(tx: int, ty: int, type: int) -> void:
	if tx < 0 or ty < 0 or tx >= map_width or ty >= map_height:
		return
	tile_grid[ty * map_width + tx] = type
