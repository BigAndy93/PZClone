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
	var bounds:      Rect2i                # tile rect of this room
	var floor_cells: Array = []            # Array[Vector2i] — interior tiles only

	static func make(p_id: int, p_purpose: int, p_bounds: Rect2i) -> RoomDef:
		var r        := RoomDef.new()
		r.id          = p_id
		r.purpose     = p_purpose
		r.bounds      = p_bounds
		return r


# ── Blueprint fields ──────────────────────────────────────────────────────────
var bounds:       Rect2i
var zone_type:    int = ZoneType.RESIDENTIAL
var archetype:    int = Archetype.SMALL_HOUSE
var height_tiles: int = 3                       # visual wall height tiers (>= 3)
var floor_cells:  Dictionary = {}               # Vector2i → true (all floor tiles)
var rooms:        Array       = []              # Array[RoomDef]
var entry_edges:  Array       = []             # Array[Vector3i] — exterior door edge keys

# Loot — forwarded from generation, consumed by World._spawn_loot().
var loot_cells: Array[Vector2i] = []
var loot_items: Array           = []            # Array[ItemData?]


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
