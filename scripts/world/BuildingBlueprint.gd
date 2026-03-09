class_name BuildingBlueprint
extends RefCounted

# ── Zone / archetype enums (mirrors MapGenerator.ZoneType / old BuildingData.Archetype) ──
enum ZoneType {
	EMPTY = 0, FOREST = 1, RESIDENTIAL = 2,
	COMMERCIAL = 3, INDUSTRIAL = 4, RURAL = 5,
}

enum Archetype {
	SMALL_HOUSE = 0, MEDIUM_HOUSE = 1, CONVENIENCE_STORE = 2, PHARMACY = 3,
	HARDWARE_STORE = 4, OFFICE = 5, WAREHOUSE = 6, GARAGE = 7,
	FARMHOUSE = 8, RESTAURANT = 9, DUPLEX = 10, STORAGE_YARD = 11,
}

static var RESIDENTIAL_ARCHETYPES: Array = [
	Archetype.SMALL_HOUSE, Archetype.MEDIUM_HOUSE,
	Archetype.FARMHOUSE,   Archetype.DUPLEX,
]

# ── Upper floor data ─────────────────────────────────────────────────────────
## Self-contained data for one upper floor (floor index 1, 2, …).
## Mirrors the relevant parts of BuildingBlueprint + MapData in a standalone
## structure so upper floors don't pollute the global MapData grids.
class FloorData:
	## Rooms on this floor — globally unique room IDs (start after ground-floor rooms).
	var rooms: Array = []              # Array[RoomDef]

	## Sparse wall / door / window edges, keyed exactly like MapData:
	##   edge_key = Vector3i(tx, ty, dir) — canonical (DIR_N or DIR_W only).
	var wall_edges:   Dictionary = {}  # Vector3i → true
	var door_edges:   Dictionary = {}  # Vector3i → int  (height_tiles)
	var window_edges: Dictionary = {}  # Vector3i → int  (WIN_* state)

	## Per-tile furniture — same coordinate space as ground floor.
	var furniture:     Dictionary = {}  # Vector2i → int  (FURN_*)
	var furniture_rot: Dictionary = {}  # Vector2i → int  (0-3)
	var occupied:      Dictionary = {}  # Vector2i → true

	## Tiles (same map coords as ground floor) that contain a stairwell on THIS floor.
	var stair_cells: Array[Vector2i] = []

	# ── Convenience accessors (duck-type compatible with MapData) ──────────────
	func has_wall_edge(tx: int, ty: int, dir: int) -> bool:
		return wall_edges.has(MapData.edge_key(tx, ty, dir))

	func is_occupied(tx: int, ty: int) -> bool:
		return occupied.has(Vector2i(tx, ty))

	func add_wall_edge(tx: int, ty: int, dir: int) -> void:
		wall_edges[MapData.edge_key(tx, ty, dir)] = true

	func remove_wall_edge(tx: int, ty: int, dir: int) -> void:
		wall_edges.erase(MapData.edge_key(tx, ty, dir))

	func get_furniture_at(tx: int, ty: int) -> int:
		return furniture.get(Vector2i(tx, ty), MapData.FURN_NONE)

	func set_furniture_at(tx: int, ty: int, furn: int) -> void:
		furniture[Vector2i(tx, ty)] = furn

	func get_furn_rot_at(tx: int, ty: int) -> int:
		return furniture_rot.get(Vector2i(tx, ty), 0)

	func set_furn_rot_at(tx: int, ty: int, rot: int) -> void:
		furniture_rot[Vector2i(tx, ty)] = rot

	func set_occupied_at(tx: int, ty: int) -> void:
		occupied[Vector2i(tx, ty)] = true


# ── Room subdivision ──────────────────────────────────────────────────────────
class RoomDef:
	enum Purpose {
		BEDROOM = 0, LIVING = 1, KITCHEN = 2, STORAGE = 3,
		HALLWAY = 4, BATHROOM = 5, COMMERCIAL = 6,
		OFFICE_FLOOR = 7,  # open workspace / cubicle area
		DINING = 8,        # restaurant seating area
	}
	var id:          int
	var purpose:     int = Purpose.LIVING
	var floor_index: int = 0
	var bounds:      Rect2i                # tile rect of this room
	var floor_cells: Array = []            # Array[Vector2i] — interior tiles only
	var connected_door_edges: Array = []   # Array[Vector3i]
	var connected_window_edges: Array = [] # Array[Vector3i]

	static func make(p_id: int, p_purpose: int, p_bounds: Rect2i, p_floor_index: int = 0) -> RoomDef:
		var r        := RoomDef.new()
		r.id          = p_id
		r.purpose     = p_purpose
		r.floor_index = p_floor_index
		r.bounds      = p_bounds
		return r


# ── Blueprint fields ──────────────────────────────────────────────────────────
var bounds:       Rect2i
var zone_type:    int = ZoneType.RESIDENTIAL
var archetype:    int = Archetype.SMALL_HOUSE
var height_tiles: int = 3                       # total visual wall height tiers (>= 3)
var floor_cells:  Dictionary = {}               # Vector2i → true (all floor tiles)
var rooms:        Array       = []              # Array[RoomDef] — ground floor rooms
var entry_edges:  Array       = []             # Array[Vector3i] — exterior door edge keys

# Loot — forwarded from generation, consumed by World._spawn_loot().
var loot_cells: Array[Vector2i] = []
var loot_items: Array           = []            # Array[ItemData?]

# ── Multi-story fields ────────────────────────────────────────────────────────
## Number of habitable floors (1 = single storey, 2 = two storeys, …).
var floor_count:   int = 1
## Wall height per storey in tiles.  story_h_tiles = height_tiles / floor_count (≥1).
var story_h_tiles: int = 3
## Per-upper-floor data, indexed 0 = 2nd floor, 1 = 3rd floor, etc.
var upper_floors:  Array = []          # Array[FloorData]
## Ground-floor tile positions that contain a stairwell leading upward.
var stair_cells:   Array[Vector2i] = []


# ── Footprint geometry ────────────────────────────────────────────────────────
## Returns the four-point isometric diamond covering this building's bounds,
## in world space.  Used for cutaway detection, roof baking, and nav holes.
##
## Each corner is the north-tip (ground-level wall-base point) of the
## corresponding corner tile of the building rect:
##   N = tile (bx,    by)    E = tile (bx+bw, by)
##   S = tile (bx+bw, by+bh) W = tile (bx,    by+bh)
func footprint_poly(tilemap: WorldTileMap, origin_offset: Vector2i) -> PackedVector2Array:
	var r  := bounds
	var o  := origin_offset
	var pN := tilemap.map_to_local(Vector2i(r.position.x,            r.position.y           ) + o) + Vector2( 0.0, -16.0)
	var pE := tilemap.map_to_local(Vector2i(r.position.x + r.size.x, r.position.y           ) + o) + Vector2( 0.0, -16.0)
	var pS := tilemap.map_to_local(Vector2i(r.position.x + r.size.x, r.position.y + r.size.y) + o) + Vector2( 0.0, -16.0)
	var pW := tilemap.map_to_local(Vector2i(r.position.x,            r.position.y + r.size.y) + o) + Vector2( 0.0, -16.0)
	return PackedVector2Array([pN, pE, pS, pW])

## Returns true if world_pos is inside the building's isometric footprint.
func contains_point_world(world_pos: Vector2, tilemap: WorldTileMap, origin_offset: Vector2i) -> bool:
	return Geometry2D.is_point_in_polygon(world_pos, footprint_poly(tilemap, origin_offset))
