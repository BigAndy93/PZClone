class_name ProceduralBuilding
extends Node2D

# Explicit preload so FurniturePiece is resolved without relying on the global class cache.
# (Global class cache may lag behind newly-created .gd files until the editor rescans.)
const _FurniturePieceCls := preload("res://scenes/world/FurniturePiece.gd")

const TILE_W         := 64.0
const TILE_H         := 32.0
const WALL_HEIGHT    := 30.0   # screen-pixel height of one storey
const WALL_THICKNESS := 4.0    # collision shape thickness
const TEX_WALL_H     := 32     # wall texture pixel height (matches generated PNGs)

# ── Fridge sprite sheet ────────────────────────────────────────────────────────
# Save your 2×2 sprite sheet to this path, then tune the constants below.
const FRIDGE_SHEET_PATH := "res://assets/furniture/fridge_sheet.png.png"
# Pixel size of ONE cell (total_width / 2, total_height / 2). ADJUST after import.
const FRIDGE_CELL_W     : int   = 128   # 256×256 total sheet ÷ 2 cols
const FRIDGE_CELL_H     : int   = 128   # 256×256 total sheet ÷ 2 rows
# Per-view pivot — pixel in the cell where the floor-contact point sits.
# Index = view.y * sheet_cols + view.x  (matches 2×2 sheet grid).
const FRIDGE_PIVOTS: Array = [
	Vector2(42.0, 92.0),   # South  (0,0)
	Vector2(41.0, 93.0),   # East   (1,0)
	Vector2(39.0, 90.0),   # North  (0,1)
	Vector2(41.0, 90.0),   # West   (1,1)
]
# Tile footprint definition (east_tiles × north_tiles); pivot = south/front tile.
const FRIDGE_FOOTPRINT          := Vector2i(1, 2)   # 1 tile E × 2 tiles N
const FRIDGE_PIVOT_IN_FOOTPRINT := Vector2i(0, 1)   # pivot at footprint cell (0,1)
# Per-axis scale — tune in FurnitureViewer after import.
const FRIDGE_SCALE_X : float = 0.19
const FRIDGE_SCALE_Y : float = 0.19
# Sheet layout — (col, row) in the 2×2 grid:
#   top-left  (0,0) = "South" view  |  top-right (1,0) = "East" view
#   bot-left  (0,1) = "North" view  |  bot-right (1,1) = "West" view
# Facing chosen by where in the building the fridge sits (nf/ef quadrant).
const FRIDGE_VIEW_S := Vector2i(0, 0)   # near south wall → show South face
const FRIDGE_VIEW_E := Vector2i(1, 0)   # near east wall  → show East face
const FRIDGE_VIEW_N := Vector2i(0, 1)   # near north wall → show North face
const FRIDGE_VIEW_W := Vector2i(1, 1)   # near west wall  → show West face

# ── Counter/cabinet sprite sheet ────────────────────────────────────────────────
# 2×2 sheet (256×256 total); each cell = 128×128 px.
# Layout identical to fridge: (0,0)=S, (1,0)=E, (0,1)=N, (1,1)=W.
const COUNTER_SHEET_PATH := "res://assets/furniture/counter_sheet.png"
const COUNTER_CELL_W     : int   = 128   # 256×256 total sheet ÷ 2 cols
const COUNTER_CELL_H     : int   = 128   # 256×256 total sheet ÷ 2 rows
# Per-view pivot — pixel inside the cell at the floor-contact point.
# Tune in FurnitureViewer after import.
const COUNTER_PIVOTS: Array = [
	Vector2(63.0, 91.0),   # South  (0,0)
	Vector2(61.0, 92.0),   # East   (1,0)
	Vector2(58.0, 90.0),   # North  (0,1)
	Vector2(64.0, 93.0),   # West   (1,1)
]
const COUNTER_SCALE_X : float = 0.19   # tune in FurnitureViewer
const COUNTER_SCALE_Y : float = 0.19
const COUNTER_VIEW_S := Vector2i(0, 0)
const COUNTER_VIEW_E := Vector2i(1, 0)
const COUNTER_VIEW_N := Vector2i(0, 1)
const COUNTER_VIEW_W := Vector2i(1, 1)

# ── Chair sprite sheet ────────────────────────────────────────────────────────
# 2×2 sheet (256×256 total); each cell = 128×128 px.
# Layout: (0,0)=S, (1,0)=E, (0,1)=N, (1,1)=W — chair back faces the labeled direction.
const CHAIR_SHEET_PATH := "res://assets/furniture/chair_sheet.png"
const CHAIR_CELL_W     : int   = 128
const CHAIR_CELL_H     : int   = 128
# Per-view pivot — pixel inside the cell at the floor-contact point. Tune in FurnitureViewer.
const CHAIR_PIVOTS: Array = [
	Vector2(64.0, 105.0),   # South  (0,0)
	Vector2(64.0, 105.0),   # East   (1,0)
	Vector2(64.0, 105.0),   # North  (0,1)
	Vector2(64.0, 105.0),   # West   (1,1)
]
const CHAIR_SCALE_X : float = 0.19   # tune in FurnitureViewer
const CHAIR_SCALE_Y : float = 0.19
const CHAIR_VIEW_S := Vector2i(0, 0)
const CHAIR_VIEW_E := Vector2i(1, 0)
const CHAIR_VIEW_N := Vector2i(0, 1)
const CHAIR_VIEW_W := Vector2i(1, 1)

# ── Bed sprite sheet ──────────────────────────────────────────────────────────
const BED_SHEET_PATH  := "res://assets/furniture/double_bed_sheet.png"
const BED_CELL_W      : int   = 128
const BED_CELL_H      : int   = 128
const BED_SCALE_X     : float = 0.19
const BED_SCALE_Y     : float = 0.19
const BED_PIVOTS: Array = [
	Vector2(64.0, 76.0),   # South  (0,0)
	Vector2(60.0, 78.0),   # East   (1,0)
	Vector2(64.0, 76.0),   # North  (0,1)
	Vector2(68.0, 78.0),   # West   (1,1)
]
const BED_VIEW_S := Vector2i(0, 0)
const BED_VIEW_E := Vector2i(1, 0)
const BED_VIEW_N := Vector2i(0, 1)
const BED_VIEW_W := Vector2i(1, 1)

# ── Sofa sprite sheet ─────────────────────────────────────────────────────────
const SOFA_SHEET_PATH  := "res://assets/furniture/sofa_sheet.png"
const SOFA_CELL_W      : int   = 128
const SOFA_CELL_H      : int   = 128
const SOFA_SCALE_X     : float = 0.19
const SOFA_SCALE_Y     : float = 0.19
const SOFA_PIVOTS: Array = [
	Vector2(64.0, 82.0),   # South  (0,0)
	Vector2(68.0, 72.0),   # East   (1,0)
	Vector2(64.0, 82.0),   # North  (0,1)
	Vector2(60.0, 72.0),   # West   (1,1)
]
const SOFA_VIEW_S := Vector2i(0, 0)
const SOFA_VIEW_E := Vector2i(1, 0)
const SOFA_VIEW_N := Vector2i(0, 1)
const SOFA_VIEW_W := Vector2i(1, 1)

# ── Nightstand sprite sheet ───────────────────────────────────────────────────
const NSTAND_SHEET_PATH := "res://assets/furniture/nightstand_sheet.png"
const NSTAND_CELL_W     : int   = 128
const NSTAND_CELL_H     : int   = 128
const NSTAND_SCALE_X    : float = 0.19
const NSTAND_SCALE_Y    : float = 0.19
const NSTAND_PIVOTS: Array = [
	Vector2(64.0, 80.0),   # South  (0,0)
	Vector2(64.0, 80.0),   # East   (1,0)
	Vector2(64.0, 80.0),   # North  (0,1)
	Vector2(64.0, 80.0),   # West   (1,1)
]
const NSTAND_VIEW_S := Vector2i(0, 0)
const NSTAND_VIEW_E := Vector2i(1, 0)
const NSTAND_VIEW_N := Vector2i(0, 1)
const NSTAND_VIEW_W := Vector2i(1, 1)

# ── Dining table sprite sheet ─────────────────────────────────────────────────
const DTABLE_SHEET_PATH := "res://assets/furniture/dining_table_sheet.png"
const DTABLE_CELL_W     : int   = 128
const DTABLE_CELL_H     : int   = 128
const DTABLE_SCALE_X    : float = 0.19
const DTABLE_SCALE_Y    : float = 0.19
const DTABLE_PIVOTS: Array = [
	Vector2(62.0, 84.0),   # South  (0,0)
	Vector2(64.0, 76.0),   # East   (1,0)
	Vector2(62.0, 84.0),   # North  (0,1)
	Vector2(64.0, 76.0),   # West   (1,1)
]
const DTABLE_VIEW_S := Vector2i(0, 0)
const DTABLE_VIEW_E := Vector2i(1, 0)
const DTABLE_VIEW_N := Vector2i(0, 1)
const DTABLE_VIEW_W := Vector2i(1, 1)

# ── Side table sprite sheet ───────────────────────────────────────────────────
const STABLE_SHEET_PATH := "res://assets/furniture/side_table_sheet.png"
const STABLE_CELL_W     : int   = 128
const STABLE_CELL_H     : int   = 128
const STABLE_SCALE_X    : float = 0.19
const STABLE_SCALE_Y    : float = 0.19
const STABLE_PIVOTS: Array = [
	Vector2(64.0, 80.0),   # South  (0,0)
	Vector2(64.0, 80.0),   # East   (1,0)
	Vector2(64.0, 80.0),   # North  (0,1)
	Vector2(64.0, 80.0),   # West   (1,1)
]
const STABLE_VIEW_S := Vector2i(0, 0)
const STABLE_VIEW_E := Vector2i(1, 0)
const STABLE_VIEW_N := Vector2i(0, 1)
const STABLE_VIEW_W := Vector2i(1, 1)

# ── Bookshelf sprite sheet ────────────────────────────────────────────────────
const BSHELF_SHEET_PATH := "res://assets/furniture/bookshelf_sheet.png"
const BSHELF_CELL_W     : int   = 128
const BSHELF_CELL_H     : int   = 128
const BSHELF_SCALE_X    : float = 0.19
const BSHELF_SCALE_Y    : float = 0.19
const BSHELF_PIVOTS: Array = [
	Vector2(62.0, 88.0),   # South  (0,0)
	Vector2(68.0, 82.0),   # East   (1,0)
	Vector2(62.0, 88.0),   # North  (0,1)
	Vector2(60.0, 82.0),   # West   (1,1)
]
const BSHELF_VIEW_S := Vector2i(0, 0)
const BSHELF_VIEW_E := Vector2i(1, 0)
const BSHELF_VIEW_N := Vector2i(0, 1)
const BSHELF_VIEW_W := Vector2i(1, 1)

# ── Stove sprite sheet ────────────────────────────────────────────────────────
const STOVE_SHEET_PATH := "res://assets/furniture/stove_sheet.png"
const STOVE_CELL_W     : int   = 128
const STOVE_CELL_H     : int   = 128
const STOVE_SCALE_X    : float = 0.19
const STOVE_SCALE_Y    : float = 0.19
const STOVE_PIVOTS: Array = [
	Vector2(64.0, 82.0),   # South  (0,0)
	Vector2(66.0, 78.0),   # East   (1,0)
	Vector2(64.0, 82.0),   # North  (0,1)
	Vector2(62.0, 78.0),   # West   (1,1)
]
const STOVE_VIEW_S := Vector2i(0, 0)
const STOVE_VIEW_E := Vector2i(1, 0)
const STOVE_VIEW_N := Vector2i(0, 1)
const STOVE_VIEW_W := Vector2i(1, 1)

# ── Wardrobe sprite sheet ─────────────────────────────────────────────────────
const WARDROBE_SHEET_PATH := "res://assets/furniture/wardrobe_sheet.png"
const WARDROBE_CELL_W     : int   = 128
const WARDROBE_CELL_H     : int   = 128
const WARDROBE_SCALE_X    : float = 0.19
const WARDROBE_SCALE_Y    : float = 0.19
const WARDROBE_PIVOTS: Array = [
	Vector2(62.0, 90.0),   # South  (0,0)
	Vector2(66.0, 82.0),   # East   (1,0)
	Vector2(62.0, 90.0),   # North  (0,1)
	Vector2(62.0, 82.0),   # West   (1,1)
]
const WARDROBE_VIEW_S := Vector2i(0, 0)
const WARDROBE_VIEW_E := Vector2i(1, 0)
const WARDROBE_VIEW_N := Vector2i(0, 1)
const WARDROBE_VIEW_W := Vector2i(1, 1)

# ── Dresser sprite sheet ──────────────────────────────────────────────────────
const DRESSER_SHEET_PATH := "res://assets/furniture/dresser_sheet.png"
const DRESSER_CELL_W     : int   = 128
const DRESSER_CELL_H     : int   = 128
const DRESSER_SCALE_X    : float = 0.19
const DRESSER_SCALE_Y    : float = 0.19
const DRESSER_PIVOTS: Array = [
	Vector2(63.0, 84.0),   # South  (0,0)
	Vector2(64.0, 80.0),   # East   (1,0)
	Vector2(63.0, 84.0),   # North  (0,1)
	Vector2(64.0, 80.0),   # West   (1,1)
]
const DRESSER_VIEW_S := Vector2i(0, 0)
const DRESSER_VIEW_E := Vector2i(1, 0)
const DRESSER_VIEW_N := Vector2i(0, 1)
const DRESSER_VIEW_W := Vector2i(1, 1)

# ── Medicine cabinet sprite sheet ─────────────────────────────────────────────
const MEDCAB_SHEET_PATH := "res://assets/furniture/medicine_cabinet_sheet.png"
const MEDCAB_CELL_W     : int   = 128
const MEDCAB_CELL_H     : int   = 128
const MEDCAB_SCALE_X    : float = 0.19
const MEDCAB_SCALE_Y    : float = 0.19
const MEDCAB_PIVOTS: Array = [
	Vector2(64.0, 82.0),   # South  (0,0)
	Vector2(64.0, 80.0),   # East   (1,0)
	Vector2(64.0, 82.0),   # North  (0,1)
	Vector2(64.0, 80.0),   # West   (1,1)
]
const MEDCAB_VIEW_S := Vector2i(0, 0)
const MEDCAB_VIEW_E := Vector2i(1, 0)
const MEDCAB_VIEW_N := Vector2i(0, 1)
const MEDCAB_VIEW_W := Vector2i(1, 1)

# ── Filing cabinet sprite sheet ───────────────────────────────────────────────
const FILECAB_SHEET_PATH := "res://assets/furniture/filing_cabinet_sheet.png"
const FILECAB_CELL_W     : int   = 128
const FILECAB_CELL_H     : int   = 128
const FILECAB_SCALE_X    : float = 0.19
const FILECAB_SCALE_Y    : float = 0.19
const FILECAB_PIVOTS: Array = [
	Vector2(64.0, 82.0),   # South  (0,0)
	Vector2(64.0, 80.0),   # East   (1,0)
	Vector2(64.0, 82.0),   # North  (0,1)
	Vector2(64.0, 80.0),   # West   (1,1)
]
const FILECAB_VIEW_S := Vector2i(0, 0)
const FILECAB_VIEW_E := Vector2i(1, 0)
const FILECAB_VIEW_N := Vector2i(0, 1)
const FILECAB_VIEW_W := Vector2i(1, 1)

# ── Locker sprite sheet ───────────────────────────────────────────────────────
const LOCKER_SHEET_PATH := "res://assets/furniture/locker_sheet.png"
const LOCKER_CELL_W     : int   = 128
const LOCKER_CELL_H     : int   = 128
const LOCKER_SCALE_X    : float = 0.19
const LOCKER_SCALE_Y    : float = 0.19
const LOCKER_PIVOTS: Array = [
	Vector2(64.0, 88.0),   # South  (0,0)
	Vector2(65.0, 84.0),   # East   (1,0)
	Vector2(64.0, 88.0),   # North  (0,1)
	Vector2(63.0, 84.0),   # West   (1,1)
]
const LOCKER_VIEW_S := Vector2i(0, 0)
const LOCKER_VIEW_E := Vector2i(1, 0)
const LOCKER_VIEW_N := Vector2i(0, 1)
const LOCKER_VIEW_W := Vector2i(1, 1)

# Interior wall visual constants.
const INTERIOR_WALL_COLOR       := Color(0.60, 0.54, 0.46)   # drywall / plaster
const INTERIOR_DOOR_HALF_GAP_PX := 14.0                       # screen-pixels per side of door opening

enum PlacementMode { WORLDGEN = 0, PLAYER = 1 }

# Archetypes rendered with baked PNG textures (Option B).
const OPTION_B_ARCHETYPES := [
	BuildingData.Archetype.CONVENIENCE_STORE,
	BuildingData.Archetype.PHARMACY,
	BuildingData.Archetype.HARDWARE_STORE,
	BuildingData.Archetype.OFFICE,
	BuildingData.Archetype.WAREHOUSE,
	BuildingData.Archetype.GARAGE,
	BuildingData.Archetype.MEDIUM_HOUSE,
	BuildingData.Archetype.RESTAURANT,
	BuildingData.Archetype.DUPLEX,
	BuildingData.Archetype.STORAGE_YARD,
]

# [nw_wall_color, ne_wall_color, roof_color] — indexed by BuildingData.ZoneType.
# EMPTY=0, FOREST=1, RESIDENTIAL=2, COMMERCIAL=3, INDUSTRIAL=4, RURAL=5
# Values sourced from ArtPalette.ZONE_PAL (art bible §2.1 palette discipline).
const ZONE_PALETTES := [
	[Color(0.44, 0.44, 0.44), Color(0.54, 0.54, 0.54), Color(0.60, 0.60, 0.60)],  # EMPTY
	[Color(0.30, 0.24, 0.16), Color(0.38, 0.30, 0.20), Color(0.44, 0.37, 0.24)],  # FOREST
	[Color(0.48, 0.39, 0.28), Color(0.56, 0.47, 0.34), Color(0.64, 0.55, 0.40)],  # RESIDENTIAL
	[Color(0.28, 0.34, 0.44), Color(0.36, 0.44, 0.54), Color(0.46, 0.52, 0.62)],  # COMMERCIAL
	[Color(0.26, 0.26, 0.28), Color(0.33, 0.33, 0.36), Color(0.40, 0.40, 0.44)],  # INDUSTRIAL
	[Color(0.42, 0.35, 0.24), Color(0.50, 0.43, 0.30), Color(0.56, 0.48, 0.33)],  # RURAL
]

# Furniture colour palette — sourced from ArtPalette (art bible §2.1).
const _FWD := Color(0.46, 0.34, 0.20)   # wood dark
const _FWS := Color(0.58, 0.46, 0.28)   # wood soft
const _FMT := Color(0.64, 0.60, 0.54)   # mattress top
const _FMS := Color(0.52, 0.48, 0.42)   # mattress side
const _FSF := Color(0.30, 0.25, 0.36)   # sofa fabric
const _FSH := Color(0.34, 0.26, 0.16)   # shelf board
const _FFB := Color(0.22, 0.20, 0.18)   # dark appliance / filing
const _FCT := Color(0.44, 0.38, 0.28)   # counter top
const _FCS := Color(0.32, 0.26, 0.18)   # counter side
const _FAP := Color(0.26, 0.28, 0.30)   # appliance grey
const _FPL := Color(0.44, 0.40, 0.30)   # pallet
const _FRG := Color(0.38, 0.22, 0.14)   # rug

# Texture cache — shared across all instances to avoid redundant ResourceLoader calls.
static var _tex_cache: Dictionary = {}

# Roof polygon reference for get_footprint_world().
var _roof_poly: Polygon2D = null

# ── Cutaway state ──────────────────────────────────────────────────────────────
var _nw_polys:        Array[Polygon2D]   = []   # all NW wall/cap polys
var _ne_polys:        Array[Polygon2D]   = []   # all NE wall/cap polys
var _nw_wall_color:   Color              = Color(0.5, 0.4, 0.3)
var _ne_wall_color:   Color              = Color(0.6, 0.5, 0.4)
var _cutaway_active:  bool               = false
var _local_footprint: PackedVector2Array = PackedVector2Array()  # floor diamond, local space

# ── Door state ─────────────────────────────────────────────────────────────────
var _furniture_node: Node2D = null

var _door_open:          bool             = false
var _door_visual:        Polygon2D        = null
var _door_col:           CollisionShape2D = null
var _door_interact_area: Area2D           = null
var _door_tween:         Tween            = null
var _door_slide:         Vector2          = Vector2.ZERO  # built in _build_door

# ── Window state ───────────────────────────────────────────────────────────────
# Populated during _add_wall_windows / _add_house_details so _build_collision
# can leave matching gaps in the wall segments.
# Each entry: {wall_a, wall_b, t, half_gap_t}
var _window_gaps: Array = []

# Each entry: {body: StaticBody2D, col: CollisionShape2D, area: Area2D, is_open: bool}
var _window_panes: Array = []

# ── Tile-based furniture placement ────────────────────────────────────────────
const DEBUG_FURNITURE := false  # toggle to draw floor/footprint debug overlay
var _floor_cells: Dictionary = {}   # Vector2i → true (interior floor tile set)
var _occupied_cells: Array = []     # Array[Vector2i] — tiles occupied by furniture (debug)
var _pivot_positions: Array = []    # Array[Vector2]  — snapped local-space c per furniture (debug)
var _tilemap_ref: WorldTileMap = null
var _origin_offset: Vector2i = Vector2i.ZERO

var _bd_ref:   BuildingData = null
var _pt_n:     Vector2      = Vector2.ZERO   # stored for debug overlay
var _pt_e:     Vector2      = Vector2.ZERO
var _pt_w:     Vector2      = Vector2.ZERO
var _interior_door_centres: Array = []       # Array[Vector2] building-local screen pos


# Call after adding to scene tree.
func setup(bd: BuildingData, tilemap: WorldTileMap, origin_offset: Vector2i) -> void:
	_bd_ref = bd
	var r := bd.tile_rect

	var c_nw := Vector2i(r.position.x, r.position.y)  + origin_offset
	var c_ne := Vector2i(r.end.x - 1,  r.position.y)  + origin_offset
	var c_se := Vector2i(r.end.x - 1,  r.end.y - 1)   + origin_offset
	var c_sw := Vector2i(r.position.x, r.end.y - 1)   + origin_offset

	var pt_n := tilemap.map_to_local(c_nw) + Vector2(0.0,           -TILE_H * 0.5)
	var pt_e := tilemap.map_to_local(c_ne) + Vector2( TILE_W * 0.5,  0.0)
	var pt_s := tilemap.map_to_local(c_se) + Vector2(0.0,            TILE_H * 0.5)
	var pt_w := tilemap.map_to_local(c_sw) + Vector2(-TILE_W * 0.5,  0.0)

	# Place node at the south tip for correct y-sort depth.
	position = pt_s
	pt_n -= pt_s
	pt_e -= pt_s
	pt_w -= pt_s
	# pt_s is now Vector2.ZERO
	_pt_n = pt_n;  _pt_e = pt_e;  _pt_w = pt_w

	# Floor diamond in local space — used by contains_point_world().
	_local_footprint = PackedVector2Array([pt_n, pt_e, Vector2.ZERO, pt_w])

	# Store tilemap refs for tile-snapped furniture placement.
	_tilemap_ref = tilemap
	_origin_offset = origin_offset

	# Compute interior floor cells — walls occupy the outer ring of tiles.
	_floor_cells.clear()
	for row in range(r.position.y + 1, r.end.y - 1):
		for col in range(r.position.x + 1, r.end.x - 1):
			_floor_cells[Vector2i(col, row)] = true

	# Seeded RNG from tile position — deterministic variation per building.
	var rng := RandomNumberGenerator.new()
	rng.seed = bd.tile_rect.position.x * 7919 + bd.tile_rect.position.y * 1009

	# Ground shadow — added first so it renders behind everything.
	_add_building_shadow(pt_n, pt_e, pt_w)
	_add_interior_floor(pt_n, pt_e, pt_w)

	# Furniture must be added before walls so walls render on top (and fade away for cutaway).
	_furniture_node = Node2D.new()
	add_child(_furniture_node)
	var furn_rng := RandomNumberGenerator.new()
	furn_rng.seed = bd.tile_rect.position.x * 3571 + bd.tile_rect.position.y * 2017
	_build_furniture(pt_n, pt_e, pt_w, bd, furn_rng)

	# Interior walls added after furniture so they render on top of it.
	_build_interior_walls(bd, pt_n, pt_e, pt_w)

	_build_exterior_walls(pt_n, pt_e, pt_w, bd, rng)

	_build_collision(pt_n, pt_e, pt_w, bd)
	_build_door(pt_w, bd)
	# Containers spawn on ALL peers (loot generation is server-only inside WorldContainer._ready).
	_place_containers(pt_n, pt_e, pt_w, bd)

	if DEBUG_FURNITURE:
		_draw_debug_overlay()


# ── Unified exterior wall builder (fully procedural, all archetypes) ──────────
## Art bible §2.2: NW face = lit (pal[0]), NE face = cool-shadow + darkened,
## top cap = bright strip, outlines on all face edges.

func _build_exterior_walls(
		pt_n: Vector2, pt_e: Vector2, pt_w: Vector2,
		bd: BuildingData, rng: RandomNumberGenerator) -> void:
	var up  := Vector2(0.0, -WALL_HEIGHT)
	var pal: Array = ZONE_PALETTES[clampi(bd.zone_type, 0, ZONE_PALETTES.size() - 1)]

	var nw_c := _vary_color(pal[0], rng, 0.06)
	var ne_c := ArtPalette.cool_shadow(nw_c, 0.20).darkened(0.28)
	var cap_c := nw_c.lightened(0.15)
	var ol_c  := ArtPalette.cool_shadow(nw_c, 0.55).darkened(0.35)
	ol_c.a    = 0.85
	var grime_lvl  := rng.randf_range(0.0, 0.30)
	var damage_lvl := rng.randf_range(0.0, 0.70)

	# Store wall colors for window frame matching.
	_nw_wall_color = nw_c
	_ne_wall_color = ne_c

	# NW face + cap — lit side.
	_nw_polys.append_array(_add_wall_face(pt_n, pt_w, up, nw_c, cap_c, ol_c))
	# NE face + cap — dark side.
	_ne_polys.append_array(_add_wall_face(pt_n, pt_e, up, ne_c, cap_c, ol_c))

	# Roof diamond.
	_roof_poly = _make_poly([pt_n + up, pt_e + up, Vector2.ZERO + up, pt_w + up],
			_vary_color(pal[2], rng, 0.05))
	add_child(_roof_poly)

	# Archetype-specific details (siding lines, chimneys, etc.).
	match bd.archetype:
		BuildingData.Archetype.SMALL_HOUSE:
			_add_house_details(pt_n, pt_e, pt_w, up, nw_c, ne_c, rng)
		BuildingData.Archetype.FARMHOUSE:
			_add_farmhouse_details(pt_n, pt_e, pt_w, up, nw_c, ne_c, rng)

	# Windows (reads _nw_wall_color / _ne_wall_color for frame colour).
	_add_wall_windows(pt_n, pt_e, pt_w, up, bd, rng)

	# Grime / damage overlay.
	if grime_lvl > 0.06:
		_add_grime_overlay(pt_n, pt_e, pt_w, up, grime_lvl, damage_lvl)


## Draws one wall face with a top cap and outlines.
## Returns all Polygon2D nodes created so set_cutaway() can tween them.
func _add_wall_face(a: Vector2, b: Vector2, up: Vector2,
		face_c: Color, cap_c: Color, ol_c: Color) -> Array[Polygon2D]:
	var polys: Array[Polygon2D] = []
	var cap := up * 0.88   # bottom of top cap = 88 % up the wall height

	# Main face polygon (lower 88 % of wall).
	var main_poly := _make_poly([a, b, b + cap, a + cap], face_c)
	add_child(main_poly)
	polys.append(main_poly)

	# Top cap strip (upper 12 % — bright, implies wall thickness).
	var cap_poly := _make_poly([a + cap, b + cap, b + up, a + up], cap_c)
	add_child(cap_poly)
	polys.append(cap_poly)

	# Outlines on both sub-faces.
	_add_line_outline([a, b, b + cap, a + cap], ol_c, 1.2)
	_add_line_outline([a + cap, b + cap, b + up, a + up], ol_c, 1.0)

	return polys


## Closed Line2D outline around a polygon's perimeter.
func _add_line_outline(pts: Array, col: Color, width: float) -> void:
	var ol := Line2D.new()
	ol.default_color = col
	ol.width         = width
	ol.closed        = true
	for p: Vector2 in pts:
		ol.add_point(p)
	add_child(ol)


# ── Small house detail layer ───────────────────────────────────────────────────
# Horizontal siding lines + a window on each visible wall face.
func _add_house_details(
		pt_n: Vector2, pt_e: Vector2, pt_w: Vector2, up: Vector2,
		nw_col: Color, ne_col: Color, rng: RandomNumberGenerator) -> void:
	var line_col := nw_col.darkened(0.18)

	# Siding lines on NW wall — 3 horizontal bands.
	for i in range(1, 4):
		var t := float(i) / 4.0
		add_child(_line(
			pt_n.lerp(pt_w, t) + up * 0.08,
			pt_n.lerp(pt_w, t) + up * 0.92,
			line_col, 0.8))

	# Window on NW wall (offset slightly from centre to vary between buildings).
	var offset_nw := rng.randf_range(0.35, 0.55)
	_add_openable_window(pt_n, pt_w, offset_nw, 0.50, 8.0, 10.0, nw_col)

	# Window on NE wall.
	var offset_ne := rng.randf_range(0.35, 0.55)
	_add_openable_window(pt_n, pt_e, offset_ne, 0.50, 8.0, 10.0, ne_col)

	# Optional chimney on roof edge.
	if rng.randf() < 0.6:
		_add_chimney(pt_n, pt_w, pt_e, up, nw_col)


# ── Farmhouse detail layer ─────────────────────────────────────────────────────
# Vertical plank siding + a window on NW face.
func _add_farmhouse_details(
		pt_n: Vector2, pt_e: Vector2, pt_w: Vector2, up: Vector2,
		nw_col: Color, ne_col: Color, rng: RandomNumberGenerator) -> void:
	var line_col   := nw_col.darkened(0.22)
	var nw_len     := pt_n.distance_to(pt_w)
	var plank_cnt  := int(nw_len / 9.0) + 1

	# Vertical planks on NW wall.
	for i in range(1, plank_cnt):
		var t := float(i) / float(plank_cnt)
		add_child(_line(
			pt_n.lerp(pt_w, t) + up * 0.05,
			pt_n.lerp(pt_w, t) + up * 0.95,
			line_col, 0.7))

	# Window on NW wall.
	_add_openable_window(pt_n, pt_w, rng.randf_range(0.35, 0.55), 0.52, 8.0, 10.0, nw_col)

	# Window on NE wall.
	_add_openable_window(pt_n, pt_e, 0.50, 0.50, 8.0, 10.0, ne_col)

	# Farmhouses often have a porch step (small rectangle at bottom SW edge).
	if rng.randf() < 0.5:
		var porch_l := pt_n.lerp(pt_w, 0.55)
		var porch_r := pt_n.lerp(pt_w, 0.70)
		add_child(_make_poly([porch_l, porch_r, porch_r + up * 0.06, porch_l + up * 0.06],
			nw_col.lightened(0.12)))


# ── Window helper ──────────────────────────────────────────────────────────────
func _add_window(center: Vector2, w: float, h: float, wall_col: Color) -> void:
	var hw    := w * 0.5
	var hh    := h * 0.5
	var frame := wall_col.darkened(0.38)
	var glass := Color(0.54, 0.72, 0.86, 0.88)
	# Frame
	add_child(_make_poly([
		center + Vector2(-hw, -hh), center + Vector2(hw, -hh),
		center + Vector2(hw,  hh),  center + Vector2(-hw, hh),
	], frame))
	# Glass pane (inset 1.2 px)
	var ins := 1.2
	add_child(_make_poly([
		center + Vector2(-hw + ins, -hh + ins),
		center + Vector2(hw  - ins, -hh + ins),
		center + Vector2(hw  - ins,  hh - ins),
		center + Vector2(-hw + ins,  hh - ins),
	], glass))


# ── Openable window (visual + collision pane + interact area) ─────────────────
## Creates visual via _add_window, stores gap data for _build_collision,
## and builds a toggleable StaticBody2D pane + interaction Area2D.
## wall_a/wall_b: wall endpoints in local space.
## t: lerp parameter along the wall for the window centre.
## v_frac: vertical fraction up the wall (0=base, 1=top).
func _add_openable_window(
		wall_a: Vector2, wall_b: Vector2,
		t: float, v_frac: float,
		w: float, h: float, wall_col: Color) -> void:
	var up      := Vector2(0.0, -WALL_HEIGHT)
	var center  := wall_a.lerp(wall_b, t) + up * v_frac
	_add_window(center, w, h, wall_col)   # draw visual

	var wall_len := wall_a.distance_to(wall_b)
	if wall_len < 1.0:
		return

	# Physical gap = 90 % of visual width, expressed as normalised t-fraction.
	var half_gap_w := w * 0.45
	var half_gap_t := half_gap_w / wall_len
	_window_gaps.append({
		"wall_a":    wall_a,
		"wall_b":    wall_b,
		"t":         t,
		"half_gap_t": half_gap_t,
	})

	# Window pane — fills the gap in the wall; same layer/thickness as regular walls.
	var pane_a  := wall_a.lerp(wall_b, clampf(t - half_gap_t, 0.0, 1.0))
	var pane_b  := wall_a.lerp(wall_b, clampf(t + half_gap_t, 0.0, 1.0))
	var pane_body := StaticBody2D.new()
	pane_body.collision_layer = 8
	pane_body.collision_mask  = 0
	add_child(pane_body)
	var perp  := (pane_b - pane_a).normalized().rotated(PI * 0.5) * WALL_THICKNESS * 0.5
	var shape := ConvexPolygonShape2D.new()
	shape.points = PackedVector2Array([pane_a - perp, pane_b - perp, pane_b + perp, pane_a + perp])
	var pcol  := CollisionShape2D.new()
	pcol.shape = shape
	pane_body.add_child(pcol)

	# Interaction Area2D — detectable by player's interact_area (mask 4|16 = NPCs|Triggers).
	var interact := Area2D.new()
	interact.collision_layer = 16
	interact.collision_mask  = 0
	interact.position        = center
	interact.add_to_group("windows")
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	var ics := CollisionShape2D.new()
	ics.shape = circle
	interact.add_child(ics)
	add_child(interact)

	_window_panes.append({
		"body":    pane_body,
		"col":     pcol,
		"area":    interact,
		"is_open": false,
	})


## Returns the index in _window_panes for the given Area2D, or -1.
func get_window_index(area: Area2D) -> int:
	for i in _window_panes.size():
		if _window_panes[i]["area"] == area:
			return i
	return -1


## Toggle one window's open/closed state (called on ALL peers via World RPC).
func set_window_open(win_idx: int, open: bool) -> void:
	if win_idx < 0 or win_idx >= _window_panes.size():
		return
	var w: Dictionary = _window_panes[win_idx]
	w["is_open"]  = open
	w["col"].disabled = open   # disable pane collision when open


# ── Chimney helper ─────────────────────────────────────────────────────────────
func _add_chimney(pt_n: Vector2, pt_w: Vector2, _pt_e: Vector2,
		up: Vector2, wall_col: Color) -> void:
	var chimney_base := pt_n.lerp(pt_w, 0.2) + up * 0.95
	var ch_col       := wall_col.darkened(0.30)
	var cw           := 3.5
	var ch           := 7.0
	add_child(_make_poly([
		chimney_base + Vector2(-cw, 0.0), chimney_base + Vector2(cw, 0.0),
		chimney_base + Vector2(cw, -ch),  chimney_base + Vector2(-cw, -ch),
	], ch_col))


# ── Grime / damage overlay ────────────────────────────────────────────────────
# Multi-pass: base band → streak overlays → damage scorch/cracks/floor stain.
# Art bible §4.1 pipeline: apply grime mask → apply damage mask.
func _add_grime_overlay(
		pt_n: Vector2, pt_e: Vector2, pt_w: Vector2, up: Vector2,
		grime: float, damage: float) -> void:
	var grime_frac := clampf(grime * 1.4, 0.10, 0.75)
	var grime_col  := ArtPalette.cool_shadow(Color(0.14, 0.10, 0.07, grime * 0.42), 0.08)
	var grime_up   := up * grime_frac

	# Pass 1 — base grime band (bottom portion of each wall face).
	add_child(_make_poly([pt_n, pt_w, pt_w + grime_up, pt_n + grime_up], grime_col))
	add_child(_make_poly([pt_n, pt_e, pt_e + grime_up, pt_n + grime_up], grime_col))

	# Pass 2 — vertical grime streaks running from roof edge downward (seeded).
	var streak_rng := RandomNumberGenerator.new()
	streak_rng.seed = int(pt_n.x * 31.0) * 1009 + int(pt_n.y * 31.0) * 7919
	var n_streaks := streak_rng.randi_range(2, 3)
	var streak_col := ArtPalette.cool_shadow(Color(0.10, 0.07, 0.05, grime * 0.24), 0.10)
	for _i in n_streaks:
		var t        := streak_rng.randf_range(0.12, 0.88)
		var sw       := streak_rng.randf_range(2.0, 5.0)   # streak half-width in t-space
		var sw_t     := sw / maxf(pt_n.distance_to(pt_w), 1.0) * 0.5
		var st       := streak_rng.randf_range(0.45, 0.90)  # streak starts at this height frac
		var a_pt     := pt_n.lerp(pt_w, clampf(t - sw_t, 0.0, 1.0))
		var b_pt     := pt_n.lerp(pt_w, clampf(t + sw_t, 0.0, 1.0))
		add_child(_make_poly([
			a_pt + up * st, b_pt + up * st,
			b_pt + up,      a_pt + up,
		], streak_col))

	# Pass 3 — window sill drip (thin vertical line just below each window gap).
	for gap: Dictionary in _window_gaps:
		var mid_t: float = gap["t"]
		var wa: Vector2 = gap["wall_a"]
		var wb: Vector2 = gap["wall_b"]
		var sill_pt := wa.lerp(wb, mid_t)
		var drip_col := Color(streak_col.r, streak_col.g, streak_col.b, grime * 0.32)
		add_child(_line(sill_pt, sill_pt + Vector2(0.0, 8.0), drip_col, 1.0))

	# ── Damage scorch + cracks + floor stain ────────────────────────────────
	if damage > 0.62:
		var dmg_col  := ArtPalette.cool_shadow(Color(0.07, 0.05, 0.04, damage * 0.26), 0.06)
		var scorch_b := up * 0.50
		var scorch_t := up * 0.90
		add_child(_make_poly([
			pt_n.lerp(pt_w, 0.10) + scorch_b, pt_n.lerp(pt_w, 0.38) + scorch_b,
			pt_n.lerp(pt_w, 0.38) + scorch_t, pt_n.lerp(pt_w, 0.10) + scorch_t,
		], dmg_col))

		# Crack lines on NW wall face.
		var crack_rng := RandomNumberGenerator.new()
		crack_rng.seed = int(pt_w.x * 41.0 + pt_w.y * 37.0)
		var n_cracks := crack_rng.randi_range(2, 3)
		var crack_col := ArtPalette.cool_shadow(Color(0.08, 0.06, 0.04, damage * 0.55), 0.08)
		for _i in n_cracks:
			var ct  := crack_rng.randf_range(0.15, 0.70)
			var cvf := crack_rng.randf_range(0.20, 0.60)
			var cx  := pt_n.lerp(pt_w, ct)
			var start_pt := cx + up * cvf
			# Two-branch crack
			var off1 := Vector2(crack_rng.randf_range(-4.0, 4.0), crack_rng.randf_range(-6.0, -2.0))
			var off2 := Vector2(crack_rng.randf_range(-4.0, 4.0), crack_rng.randf_range(2.0, 6.0))
			add_child(_line(start_pt, start_pt + off1, crack_col, 1.0))
			add_child(_line(start_pt, start_pt + off2, crack_col, 1.0))

	# Broken window (damage > 0.80).
	if damage > 0.80:
		for gap: Dictionary in _window_gaps:
			var wa: Vector2 = gap["wall_a"]
			var wb: Vector2 = gap["wall_b"]
			var mid_t:  float = gap["t"]
			var half_t: float = gap.get("half_gap_t", 0.06)
			var bot_frac: float = gap.get("bottom_frac", 0.30)
			var top_frac: float = gap.get("top_frac", 0.75)
			var mid_pt: Vector2 = wa.lerp(wb, mid_t)
			var bot_pt: Vector2 = wa.lerp(wb, mid_t) + up * bot_frac
			var top_pt: Vector2 = wa.lerp(wb, mid_t) + up * top_frac
			# Dark shattered glass
			add_child(_make_poly([
				wa.lerp(wb, mid_t - half_t) + up * bot_frac,
				wa.lerp(wb, mid_t + half_t) + up * bot_frac,
				wa.lerp(wb, mid_t + half_t) + up * top_frac,
				wa.lerp(wb, mid_t - half_t) + up * top_frac,
			], Color(0.08, 0.08, 0.10, 0.70)))
			# Crossed crack lines in window
			var crack_col2 := Color(0.24, 0.22, 0.22, 0.75)
			add_child(_line(bot_pt + Vector2(-4.0, 0.0), top_pt + Vector2(4.0, 0.0), crack_col2, 1.0))
			add_child(_line(bot_pt + Vector2( 4.0, 0.0), top_pt + Vector2(-4.0, 0.0), crack_col2, 1.0))
			break  # Only break one window per building

	# Floor stain (20% chance for damaged buildings).
	if damage > 0.45:
		var stain_rng := RandomNumberGenerator.new()
		stain_rng.seed = int(pt_n.x * 53.0 + pt_n.y * 47.0)
		if stain_rng.randf() < 0.20:
			var fc  := (pt_n + pt_e + Vector2.ZERO + pt_w) * 0.25
			var stx := stain_rng.randf_range(-1.0, 1.0) * (pt_n - pt_e).length() * 0.25
			var sty := stain_rng.randf_range(-1.0, 1.0) * (pt_n - pt_w).length() * 0.15
			var sctr := fc + Vector2(stx, sty)
			var stain_pts: Array[Vector2] = []
			for i in 7:
				var a := TAU * float(i) / 7.0
				var r := stain_rng.randf_range(5.0, 11.0)
				stain_pts.append(sctr + Vector2(cos(a) * r * 1.6, sin(a) * r * 0.65))
			add_child(_make_poly(stain_pts,
					Color(0.10, 0.07, 0.05, stain_rng.randf_range(0.18, 0.30))))


# ── Wall ledge (thickness illusion) ──────────────────────────────────────────
## Adds a top-lit strip and inner shadow strip to each wall face.
## Creates the illusion of 3D wall thickness without extra geometry above WALL_HEIGHT.
## Art bible §2.2: top edges lighter, bottom/right darker.
func _add_wall_ledge(
		pt_n: Vector2, pt_e: Vector2, pt_w: Vector2, up: Vector2,
		wall_col: Color, ne_col: Color) -> void:
	# Ledge = top 28% of wall height, inner shadow = next 14%.
	var ledge_frac  := up * 0.72   # bottom of ledge strip (28% from top)
	var shadow_frac := up * 0.58   # bottom of inner shadow (42% from top)

	# NW wall — top ledge (lighter, catches moonlight)
	add_child(_make_poly([
		pt_n + ledge_frac, pt_w + ledge_frac, pt_w + up, pt_n + up,
	], ArtPalette.warm_highlight(wall_col, 0.04).lightened(0.12)))

	# NW wall — inner shadow strip (cool-tinted)
	add_child(_make_poly([
		pt_n + shadow_frac, pt_w + shadow_frac, pt_w + ledge_frac, pt_n + ledge_frac,
	], ArtPalette.cool_shadow(wall_col, 0.12)))

	# NE wall — top ledge
	add_child(_make_poly([
		pt_n + ledge_frac, pt_e + ledge_frac, pt_e + up, pt_n + up,
	], ArtPalette.warm_highlight(ne_col, 0.04).lightened(0.12)))

	# NE wall — inner shadow strip
	add_child(_make_poly([
		pt_n + shadow_frac, pt_e + shadow_frac, pt_e + ledge_frac, pt_n + ledge_frac,
	], ArtPalette.cool_shadow(ne_col, 0.12)))


# ── Building ground shadow ────────────────────────────────────────────────────
## SE-offset shadow polygon beneath the building, per art bible top-left light.
func _add_building_shadow(pt_n: Vector2, pt_e: Vector2, pt_w: Vector2) -> void:
	var offset     := Vector2(6.0, 10.0)   # SE shift
	var shadow_col := ArtPalette.cool_shadow(ArtPalette.SHADOW_BASE, 0.55)
	shadow_col.a   = 0.32
	var shadow     := _make_poly([
		pt_n + offset, pt_e + offset, Vector2(offset.x, offset.y), pt_w + offset,
	], shadow_col)
	shadow.z_index = -2   # behind furniture and walls
	add_child(shadow)


# ── Interior floor overlay ───────────────────────────────────────────────────────────────────────
## Semi-transparent warm-dark tint over the interior floor footprint.
## Lighting Bible §3: interiors must be darker than exterior during day.
func _add_interior_floor(pt_n: Vector2, pt_e: Vector2, pt_w: Vector2) -> void:
	var floor_poly := _make_poly(
			[pt_n, pt_e, Vector2.ZERO, pt_w],
			Color(0.16, 0.12, 0.08, 0.14))
	floor_poly.z_index = -1   # above ground shadow, below furniture
	add_child(floor_poly)


# ── Ceiling fixture visual stub ───────────────────────────────────────────────────────────
## Warm dot at ceiling height — Lighting Bible §3 ceiling fixtures.
## No Light2D: performance constraint for 4-player co-op (bible §12).
func _add_ceiling_fixture(fc: Vector2, nv: Vector2, ev: Vector2, archetype: int) -> void:
	var dot_pos := fc + Vector2(0.0, -WALL_HEIGHT * 0.82)
	var is_residential := archetype in [
		BuildingData.Archetype.SMALL_HOUSE,
		BuildingData.Archetype.MEDIUM_HOUSE,
		BuildingData.Archetype.FARMHOUSE,
		BuildingData.Archetype.DUPLEX,
	]
	var positions: Array[Vector2] = []
	if is_residential:
		positions.append(dot_pos)
	else:
		positions.append(dot_pos + ev * 0.30)
		positions.append(dot_pos - ev * 0.30)
	for pos: Vector2 in positions:
		var glow := Polygon2D.new()
		glow.polygon = IsoShapes.ellipse_pts(pos, 4.5, 2.0, 8)
		glow.color   = Color(0.98, 0.92, 0.70, 0.18)
		_furniture_node.add_child(glow)
		var dot := Polygon2D.new()
		dot.polygon = IsoShapes.ellipse_pts(pos, 2.5, 1.0, 6)
		dot.color   = Color(0.98, 0.92, 0.70, 0.45)
		_furniture_node.add_child(dot)


# ── Debug overlay ──────────────────────────────────────────────────────────────────────
## Draws floor tiles (green diamonds) and occupied tiles (orange) when DEBUG_FURNITURE is on.
func _draw_debug_overlay() -> void:
	if _tilemap_ref == null:
		return
	var debug_node := Node2D.new()
	debug_node.z_index = 10   # render above everything

	var dn_tile := Vector2(0.0, -TILE_H * 0.5)
	var de_tile := Vector2(TILE_W * 0.5, 0.0)

	# A) Floor tile diamonds — semi-transparent green.
	for cell: Vector2i in _floor_cells:
		# map-data coords → tilemap world → building-local (to_local handles parent transforms).
		var local_pos := to_local(_tilemap_ref.map_to_local(cell + _origin_offset))
		var poly := Polygon2D.new()
		poly.polygon = IsoShapes.rhombus(local_pos, dn_tile, de_tile)
		poly.color = Color(0.2, 0.8, 0.2, 0.15)
		debug_node.add_child(poly)

	# B) Occupied tiles (furniture footprints) — semi-transparent orange outline.
	for cell: Vector2i in _occupied_cells:
		var local_pos := to_local(_tilemap_ref.map_to_local(cell + _origin_offset))
		var poly := Polygon2D.new()
		poly.polygon = IsoShapes.rhombus(local_pos, dn_tile, de_tile)
		poly.color = Color(0.9, 0.5, 0.1, 0.30)
		debug_node.add_child(poly)

	# C) Furniture pivot dots — magenta circle at each snapped tile-centre position.
	# Verifies that Cramer's rule placed c exactly on the tile centre.
	for pivot: Vector2 in _pivot_positions:
		var dot := Polygon2D.new()
		var pts: PackedVector2Array = PackedVector2Array()
		for i in 8:
			var a := TAU * float(i) / 8.0
			pts.append(pivot + Vector2(cos(a), sin(a)) * 3.5)
		dot.polygon = pts
		dot.color = Color(1.0, 0.0, 1.0, 0.90)   # magenta
		debug_node.add_child(dot)

	# D) Interior wall door gap centres — yellow diamonds.
	var diam_n := Vector2(0.0, -6.0);  var diam_e := Vector2(6.0, 0.0)
	for door_pt: Vector2 in _interior_door_centres:
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([door_pt + diam_n, door_pt + diam_e, door_pt - diam_n, door_pt - diam_e])
		poly.color = Color(1.0, 0.9, 0.0, 0.95)   # yellow
		debug_node.add_child(poly)

	# E) Interior wall centrelines — teal Line2D.
	if _bd_ref != null and not _bd_ref.interior_wall_defs.is_empty():
		var axes_d := _furn_axes(_pt_n, _pt_e, _pt_w)
		var fc_d: Vector2 = axes_d[0]
		var nv_d: Vector2 = axes_d[1]
		var ev_d: Vector2 = axes_d[2]
		for wd: RoomDef.InteriorWallDef in _bd_ref.interior_wall_defs:
			var ea: Vector2
			var eb: Vector2
			if wd.axis == RoomDef.InteriorWallDef.Axis.NF:
				ea = fc_d + nv_d * wd.value + ev_d * wd.lo
				eb = fc_d + nv_d * wd.value + ev_d * wd.hi
			else:
				ea = fc_d + nv_d * wd.lo + ev_d * wd.value
				eb = fc_d + nv_d * wd.hi + ev_d * wd.value
			var ln := Line2D.new()
			ln.add_point(ea);  ln.add_point(eb)
			ln.default_color = Color(0.0, 0.85, 0.80, 0.90)
			ln.width = 1.5
			debug_node.add_child(ln)

	# F) Wall-adjacent floor tiles — light blue tint.
	if _tilemap_ref != null:
		for mc: Vector2i in _floor_cells:
			if count_wall_neighbors(mc) >= 1:
				var lp := to_local(_tilemap_ref.map_to_local(mc + _origin_offset))
				var poly := Polygon2D.new()
				poly.polygon = IsoShapes.rhombus(lp, dn_tile, de_tile)
				poly.color = Color(0.3, 0.6, 1.0, 0.18)   # light blue
				debug_node.add_child(poly)

	add_child(debug_node)


# ── Texture loading ────────────────────────────────────────────────────────────

func _load_wall_tex(arch: int) -> Texture2D:
	var path: String
	match arch:
		BuildingData.Archetype.CONVENIENCE_STORE, \
		BuildingData.Archetype.PHARMACY, \
		BuildingData.Archetype.OFFICE, \
		BuildingData.Archetype.RESTAURANT:
			path = "res://assets/buildings/commercial_wall.png"
		BuildingData.Archetype.HARDWARE_STORE, \
		BuildingData.Archetype.WAREHOUSE, \
		BuildingData.Archetype.GARAGE, \
		BuildingData.Archetype.STORAGE_YARD:
			path = "res://assets/buildings/industrial_wall.png"
		BuildingData.Archetype.MEDIUM_HOUSE, \
		BuildingData.Archetype.DUPLEX:
			path = "res://assets/buildings/residential_large_wall.png"
		_:
			return null
	return _load_tex_cached(path)


func _load_roof_tex(arch: int) -> Texture2D:
	var path: String
	match arch:
		BuildingData.Archetype.CONVENIENCE_STORE, \
		BuildingData.Archetype.PHARMACY, \
		BuildingData.Archetype.OFFICE, \
		BuildingData.Archetype.RESTAURANT:
			path = "res://assets/buildings/commercial_roof.png"
		BuildingData.Archetype.HARDWARE_STORE, \
		BuildingData.Archetype.WAREHOUSE, \
		BuildingData.Archetype.GARAGE, \
		BuildingData.Archetype.STORAGE_YARD:
			path = "res://assets/buildings/industrial_roof.png"
		BuildingData.Archetype.MEDIUM_HOUSE, \
		BuildingData.Archetype.DUPLEX:
			path = "res://assets/buildings/residential_large_roof.png"
		_:
			return null
	return _load_tex_cached(path)


static func _load_tex_cached(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var tex := ResourceLoader.load(path) as Texture2D
	_tex_cache[path] = tex
	return tex


# ── Colour variation ───────────────────────────────────────────────────────────
# Applies a uniform value shift to all channels so the hue stays consistent.
static func _vary_color(base: Color, rng: RandomNumberGenerator, range_v: float) -> Color:
	var v := rng.randf_range(-range_v, range_v)
	return Color(
		clampf(base.r + v, 0.0, 1.0),
		clampf(base.g + v, 0.0, 1.0),
		clampf(base.b + v, 0.0, 1.0),
		1.0
	)


# ── Polygon / Line helpers ─────────────────────────────────────────────────────

func _make_poly(pts: Array, color: Color) -> Polygon2D:
	var poly     := Polygon2D.new()
	poly.polygon  = PackedVector2Array(pts)
	poly.color    = color
	return poly


func _line(a: Vector2, b: Vector2, color: Color, width: float) -> Line2D:
	var l           := Line2D.new()
	l.default_color  = color
	l.width          = width
	l.add_point(a)
	l.add_point(b)
	return l


# ── Collision ──────────────────────────────────────────────────────────────────

func _build_collision(pt_n: Vector2, pt_e: Vector2, pt_w: Vector2, bd: BuildingData) -> void:
	var body := StaticBody2D.new()
	# Layer 4 = "World" (value 8).  Player collision_mask = 14 (layers 2|3|4).
	body.collision_layer = 8
	body.collision_mask  = 0
	add_child(body)

	# NW and NE walls — leave gaps where openable windows sit.
	_add_wall_segs_gapped(body, pt_n, pt_w)
	_add_wall_segs_gapped(body, pt_n, pt_e)
	# SE wall — no windows.
	_add_wall_seg(body, pt_e, Vector2.ZERO)

	# SW wall with door gap.
	var bw     := bd.tile_rect.size.x
	var door_t := float(bd.door_cell.x - bd.tile_rect.position.x) / float(maxi(bw - 1, 1))
	var door_c := pt_w.lerp(Vector2.ZERO, door_t)
	var step   := (Vector2.ZERO - pt_w) / float(maxi(bw - 1, 1)) * 0.65
	_add_wall_seg(body, pt_w, door_c - step)           # left of door
	_add_wall_seg(body, door_c + step, Vector2.ZERO)   # right of door


## Build wall segment from a→b, cutting gaps wherever a window pane sits.
func _add_wall_segs_gapped(body: StaticBody2D, a: Vector2, b: Vector2) -> void:
	# Collect normalised [t_start, t_end] intervals for windows on this wall.
	var gaps: Array = []
	for wg: Dictionary in _window_gaps:
		var da: float = (wg["wall_a"] as Vector2).distance_squared_to(a)
		var db: float = (wg["wall_b"] as Vector2).distance_squared_to(b)
		if da < 1.0 and db < 1.0:
			gaps.append([
				clampf(wg["t"] - wg["half_gap_t"], 0.0, 1.0),
				clampf(wg["t"] + wg["half_gap_t"], 0.0, 1.0)])

	if gaps.is_empty():
		_add_wall_seg(body, a, b)
		return

	gaps.sort_custom(func(x, y): return x[0] < y[0])
	var prev := 0.0
	for gap: Array in gaps:
		if gap[0] > prev + 0.01:
			_add_wall_seg(body, a.lerp(b, prev), a.lerp(b, gap[0]))
		prev = gap[1]
	if prev < 0.99:
		_add_wall_seg(body, a.lerp(b, prev), b)


func _add_wall_seg(body: StaticBody2D, a: Vector2, b: Vector2) -> void:
	if a.distance_squared_to(b) < 4.0:
		return
	var diff  := b - a
	var perp  := diff.normalized().rotated(PI * 0.5) * WALL_THICKNESS * 0.5
	var shape := ConvexPolygonShape2D.new()
	shape.points = PackedVector2Array([a - perp, b - perp, b + perp, a + perp])
	var col      := CollisionShape2D.new()
	col.shape     = shape
	body.add_child(col)


# ── Door ──────────────────────────────────────────────────────────────────────

## Builds the door visual, collision blocker, and interaction area on the SW wall.
func _build_door(pt_w: Vector2, bd: BuildingData) -> void:
	var up     := Vector2(0.0, -WALL_HEIGHT)
	var bw     := bd.tile_rect.size.x
	var door_t := float(bd.door_cell.x - bd.tile_rect.position.x) / float(maxi(bw - 1, 1))
	var door_c := pt_w.lerp(Vector2.ZERO, door_t)
	var step   := (Vector2.ZERO - pt_w) / float(maxi(bw - 1, 1)) * 0.65
	var door_a := door_c - step
	var door_b := door_c + step

	# Visual door panel — wood-brown, covers the gap in the SW wall.
	_door_visual = _make_poly([door_a, door_b, door_b + up, door_a + up],
			Color(0.42, 0.28, 0.14))
	add_child(_door_visual)

	# Door collision — separate StaticBody2D so it can be toggled independently.
	var door_body := StaticBody2D.new()
	door_body.collision_layer = 8
	door_body.collision_mask  = 0
	add_child(door_body)
	_add_wall_seg(door_body, door_a, door_b)
	if door_body.get_child_count() > 0:
		_door_col = door_body.get_child(0) as CollisionShape2D

	# Slide offset — door panel translates along the wall toward the south tip when opened.
	_door_slide = (Vector2.ZERO - pt_w).normalized() * step.length() * 2.5

	# Interaction Area2D — sits at door centre, detectable by player's interact_area.
	_door_interact_area          = Area2D.new()
	_door_interact_area.collision_layer = 16   # layer 5 = Triggers
	_door_interact_area.collision_mask  = 0
	_door_interact_area.position = door_c
	_door_interact_area.add_to_group("doors")
	var circle       := CircleShape2D.new()
	circle.radius     = 28.0
	var col_shape    := CollisionShape2D.new()
	col_shape.shape   = circle
	_door_interact_area.add_child(col_shape)
	add_child(_door_interact_area)


## Server calls this; World.rpc_sync_door_state broadcasts it to all peers.
func toggle_door() -> void:
	set_door_open(not _door_open)


## Called on every peer via RPC so state is always consistent.
## Animates the door panel sliding along the SW wall (0.28 s).
## Collision toggles at the animation midpoint so the gap opens / closes
## exactly when the panel clears / re-enters the doorway.
func set_door_open(open: bool) -> void:
	_door_open = open
	if _door_visual == null:
		return

	# Kill any in-progress animation and start a new one from the current position.
	if _door_tween:
		_door_tween.kill()
	_door_tween = create_tween()

	const DURATION := 0.28
	var from_pos := _door_visual.position
	var to_pos   := _door_slide if open else Vector2.ZERO

	# Continuous slide.
	_door_tween.tween_property(_door_visual, "position", to_pos, DURATION).from(from_pos)
	# Collision flips at the midpoint: door clears the frame before blocking stops.
	_door_tween.parallel().tween_callback(
			func(): if _door_col: _door_col.disabled = open
	).set_delay(DURATION * 0.5)


# ── Windows ───────────────────────────────────────────────────────────────────
## Adds windows appropriate for each archetype.
## Called from _build_exterior_walls() after walls and roof are added.
func _add_wall_windows(
		pt_n: Vector2, pt_e: Vector2, pt_w: Vector2, up: Vector2,
		bd: BuildingData, rng: RandomNumberGenerator) -> void:
	var nw_col: Color = _nw_wall_color
	var ne_col: Color = _ne_wall_color
	match bd.archetype:
		BuildingData.Archetype.MEDIUM_HOUSE:
			_add_openable_window(pt_n, pt_w, rng.randf_range(0.25, 0.55), 0.50, 8.0, 10.0, nw_col)
			_add_openable_window(pt_n, pt_e, rng.randf_range(0.35, 0.60), 0.50, 8.0, 10.0, ne_col)
		BuildingData.Archetype.DUPLEX:
			_add_openable_window(pt_n, pt_w, 0.22, 0.50, 8.0, 10.0, nw_col)
			_add_openable_window(pt_n, pt_w, 0.68, 0.50, 8.0, 10.0, nw_col)
			_add_openable_window(pt_n, pt_e, 0.25, 0.50, 8.0, 10.0, ne_col)
			_add_openable_window(pt_n, pt_e, 0.65, 0.50, 8.0, 10.0, ne_col)
		BuildingData.Archetype.CONVENIENCE_STORE, BuildingData.Archetype.RESTAURANT:
			# Large storefront windows — NE is the street-facing side.
			_add_openable_window(pt_n, pt_e, 0.28, 0.42, 12.0, 14.0, ne_col)
			_add_openable_window(pt_n, pt_e, 0.68, 0.42, 12.0, 14.0, ne_col)
			_add_openable_window(pt_n, pt_w, rng.randf_range(0.35, 0.55), 0.50, 9.0, 10.0, nw_col)
		BuildingData.Archetype.PHARMACY, BuildingData.Archetype.OFFICE:
			_add_openable_window(pt_n, pt_w, rng.randf_range(0.30, 0.55), 0.55, 9.0, 10.0, nw_col)
			_add_openable_window(pt_n, pt_e, rng.randf_range(0.30, 0.55), 0.55, 9.0, 10.0, ne_col)
		BuildingData.Archetype.HARDWARE_STORE:
			_add_openable_window(pt_n, pt_w, 0.35, 0.65, 10.0, 8.0, nw_col)
			_add_openable_window(pt_n, pt_e, 0.50, 0.65, 10.0, 8.0, ne_col)
		BuildingData.Archetype.WAREHOUSE, BuildingData.Archetype.STORAGE_YARD:
			# High industrial strip windows.
			_add_openable_window(pt_n, pt_w, 0.38, 0.78, 8.0, 6.0, nw_col)
			_add_openable_window(pt_n, pt_e, 0.55, 0.78, 8.0, 6.0, ne_col)
		BuildingData.Archetype.GARAGE:
			_add_openable_window(pt_n, pt_w, 0.75, 0.60, 7.0, 8.0, nw_col)
		# SMALL_HOUSE and FARMHOUSE: windows added by their dedicated detail functions.


# ── Cutaway (called by World when local player enters / exits) ─────────────────

## Returns true if world_pos is inside this building's floor footprint.
func contains_point_world(world_pos: Vector2) -> bool:
	if _local_footprint.is_empty():
		return false
	return Geometry2D.is_point_in_polygon(to_local(world_pos), _local_footprint)


## Fades or restores the southern walls and roof.
## Walls → 15 % alpha (faint silhouette) so the player knows they're indoors.
## Roof  → 0 % (fully hidden so the player is visible).
func set_cutaway(inside: bool) -> void:
	if inside == _cutaway_active:
		return
	_cutaway_active = inside
	const DUR := 0.25
	var wall_a := 0.15 if inside else 1.0
	var roof_a := 0.0  if inside else 1.0
	for p: Polygon2D in _nw_polys + _ne_polys:
		if p == null or not p.visible:
			continue
		create_tween().tween_property(p, "modulate:a", wall_a, DUR)
	if _roof_poly != null and _roof_poly.visible:
		create_tween().tween_property(_roof_poly, "modulate:a", roof_a, DUR)
	if _door_visual != null and _door_visual.visible:
		create_tween().tween_property(_door_visual, "modulate:a", wall_a, DUR)


# ── Footprint (used by navigation baker) ──────────────────────────────────────

func get_footprint_world() -> PackedVector2Array:
	if _roof_poly == null:
		return PackedVector2Array()
	var result := PackedVector2Array()
	var down   := Vector2(0.0, WALL_HEIGHT)
	for pt in _roof_poly.polygon:
		result.append(global_position + pt + down)
	return result


# ── Furniture system ───────────────────────────────────────────────────────────
# Coordinate system:
#   fc  = floor centre (local space)
#   nv  = vector from fc to north tip  (points up-left on screen)
#   ev  = vector from fc to east tip   (points up-right on screen)
#   nf  = north fraction  -1=south edge … +1=north edge
#   ef  = east  fraction  -1=west edge  … +1=east edge
#   sn/se = half-size as fraction of nv/ev magnitude


func _furn_axes(pt_n: Vector2, pt_e: Vector2, pt_w: Vector2) -> Array:
	var fc := (pt_n + pt_e + Vector2.ZERO + pt_w) * 0.25
	return [fc, pt_n - fc, pt_e - fc]


## Tile-snapped flat placement — snaps nf/ef to nearest tile centre, validates floor.
func _place_furn_flat(fc: Vector2, nv: Vector2, ev: Vector2,
		nf: float, ef: float, sn: float, se: float, col: Color) -> void:
	var snapped := _snap_to_tile(fc, nv, ev, nf, ef)
	if snapped.is_empty():
		return
	_fn(fc, nv, ev, snapped[0], snapped[1], sn, se, col)


## Tile-snapped box placement — snaps nf/ef to nearest tile centre, validates floor.
func _place_furn_box(fc: Vector2, nv: Vector2, ev: Vector2,
		nf: float, ef: float, foot_n: int, foot_e: int,
		sn: float, se: float, h: float, top_c: Color, side_c: Color) -> void:
	var snapped := _snap_to_tile(fc, nv, ev, nf, ef, foot_n, foot_e)
	if snapped.is_empty():
		return
	_fb(fc, nv, ev, snapped[0], snapped[1], sn, se, h, top_c, side_c)


## Convert (nf, ef) → world → tile cell → snap to nearest interior floor tile.
## Returns [snapped_nf, snapped_ef].  Never rejects: clamps to nearest valid cell
## so furniture near walls always appears rather than being silently dropped.
func _snap_to_tile(fc: Vector2, nv: Vector2, ev: Vector2,
		nf: float, ef: float, foot_n: int = 1, foot_e: int = 1) -> Array:
	if _tilemap_ref == null:
		return [nf, ef]

	# Convert building-local fractional position → global world position,
	# then find nearest tile cell.  to_global() handles any parent transforms.
	var world_pos := to_global(fc + nv * nf + ev * ef)
	var tc := _tilemap_ref.local_to_map(world_pos)   # tilemap coords
	var mc := tc - _origin_offset                      # map-data coords (0-based)

	# Clamp to interior floor: if the exact tile isn't a floor cell, snap to the
	# nearest one.  This handles furniture placed near walls (nf/ef ≈ 0.5–0.8)
	# where the exact tile is the outer wall ring.
	if not _floor_cells.has(mc) and not _floor_cells.is_empty():
		mc = _nearest_floor_cell(mc)
		tc = mc + _origin_offset

	# Record occupied cells for debug overlay (map-data coords).
	if DEBUG_FURNITURE:
		var half_n := foot_n / 2
		var half_e := foot_e / 2
		for dn_tile: int in foot_n:
			for de_tile: int in foot_e:
				_occupied_cells.append(mc + Vector2i(dn_tile - half_n, de_tile - half_e))

	# Snap visual to tile centre — convert global tile-centre back to building-local.
	var snapped_local := to_local(_tilemap_ref.map_to_local(tc))

	# Solve for (snapped_nf, snapped_ef) such that:
	#   fc + nv*snapped_nf + ev*snapped_ef == snapped_local
	# Use Cramer's rule — correct for any nv/ev basis, including non-square
	# buildings where nv and ev are NOT orthogonal.
	var delta := snapped_local - fc
	var det   := nv.x * ev.y - nv.y * ev.x
	if abs(det) < 0.1:
		return [nf, ef]   # degenerate axes — use original (building too small)
	var snapped_nf := (delta.x * ev.y - delta.y * ev.x) / det
	var snapped_ef := (nv.x * delta.y - nv.y * delta.x) / det

	if DEBUG_FURNITURE:
		_pivot_positions.append(snapped_local)

	return [snapped_nf, snapped_ef]


## Returns the floor cell (map-data coords) closest to mc in tile-grid distance.
func _nearest_floor_cell(mc: Vector2i) -> Vector2i:
	var best     := mc
	var best_dsq := 2147483647
	for cell: Vector2i in _floor_cells:
		var d   := cell - mc
		var dsq := d.x * d.x + d.y * d.y
		if dsq < best_dsq:
			best_dsq = dsq
			best     = cell
	return best


## Flat isometric rhombus — floor decal, rug, pit marker.
func _fn(fc: Vector2, nv: Vector2, ev: Vector2,
		nf: float, ef: float, sn: float, se: float, col: Color) -> void:
	# Tile-snap if tilemap is available.
	if _tilemap_ref != null:
		var snapped := _snap_to_tile(fc, nv, ev, nf, ef)
		if snapped.is_empty():
			return
		nf = snapped[0]
		ef = snapped[1]
	var local_c := fc + nv * nf + ev * ef
	# ── Baked sprite path ──────────────────────────────────────────────────────
	var bake_key := FurnitureBaker.flat_key(sn, se, col)
	if FurnitureBaker.has_texture(bake_key):
		_furniture_node.add_child(FurnitureBaker.make_sprite(bake_key, nv, ev, local_c))
		return
	# ── Procedural fallback ────────────────────────────────────────────────────
	var dn := Vector2(0.0,            -sn * TILE_H * 0.5)   # N half-extent (straight up)
	var de := Vector2(se * TILE_W * 0.5, se * TILE_H * 0.5)  # E half-extent (iso SE diagonal)
	var fn_N := local_c + dn;  var fn_E := local_c + de
	var fn_S := local_c - dn;  var fn_W := local_c - de
	_furniture_node.add_child(_make_poly([fn_N, fn_E, fn_S, fn_W], col))
	# Inner border (rug hem / edge trim).
	var fn_hem := Line2D.new()
	fn_hem.closed        = true
	fn_hem.default_color = Color(col.lightened(0.14), col.a * 0.55)
	fn_hem.width         = 1.0
	fn_hem.add_point(lerp(local_c, fn_N, 0.88))
	fn_hem.add_point(lerp(local_c, fn_E, 0.88))
	fn_hem.add_point(lerp(local_c, fn_S, 0.88))
	fn_hem.add_point(lerp(local_c, fn_W, 0.88))
	_furniture_node.add_child(fn_hem)


## Isometric box — contact shadow + W face + E face + lit top + bevel highlight.
## Art bible §4.1 pipeline: base shape → top face → side face → vertical gradient
##   → grime → bottom shadow → edge highlight.
func _fb(fc: Vector2, nv: Vector2, ev: Vector2,
		nf: float, ef: float, sn: float, se: float,
		h: float, top_c: Color, side_c: Color, rot: int = 0) -> void:
	# Tile-snap if tilemap is available.
	if _tilemap_ref != null:
		var snapped := _snap_to_tile(fc, nv, ev, nf, ef)
		if snapped.is_empty():
			return
		nf = snapped[0]
		ef = snapped[1]
	# Pre-compute footprint — shared by both visual paths and collision.
	var c  := fc + nv * nf + ev * ef
	var dn := Vector2(0.0,            -sn * TILE_H * 0.5)   # N half-extent (straight up)
	var de := Vector2(se * TILE_W * 0.5, se * TILE_H * 0.5)  # E half-extent (iso SE diagonal)
	var gN := c + dn
	var gE := c + de
	var gS := c - dn
	var gW := c - de

	# Wall-hug: shift visual vertices toward the nearest wall (WORLDGEN only).
	# Grid position (c, gN/E/S/W for collision) stays unchanged.
	var _whug := Vector2.ZERO
	if _tilemap_ref != null:
		var _mc_raw := _tilemap_ref.local_to_map(to_global(c))
		var _mc     := _mc_raw - _origin_offset
		var _wd     := primary_wall_dir(_mc, nv, ev)
		if _wd != Vector2i.ZERO:
			_whug = wall_hug_offset(_wd)
	var vN := gN + _whug
	var vE := gE + _whug
	var vS := gS + _whug
	var vW := gW + _whug

	# ── Visual — FurniturePiece immediate-mode iso box ──────────────────────────
	# Standard iso tile-step half-extents (matches floor grid perspective exactly).
	var dn_base := Vector2(0.0,           -TILE_H * 0.5)   # (0, -16)
	var de_base := Vector2(TILE_W * 0.5,   TILE_H * 0.5)   # (32,  16)
	var piece_dn: Vector2
	var piece_de: Vector2
	match rot:
		1: piece_dn = de_base * sn;  piece_de = Vector2(0.0, -dn_base.y) * se
		2: piece_dn = -dn_base * sn; piece_de = -de_base * se
		3: piece_dn = -de_base * sn; piece_de = Vector2(0.0,  dn_base.y) * se
		_: piece_dn = dn_base * sn;  piece_de = de_base * se
	var piece := _FurniturePieceCls.new()
	piece.position = c + _whug
	piece.set_draw_data(piece_dn, piece_de, h, top_c, side_c)
	_furniture_node.add_child(piece)

	# ── Furniture collision (hard-blocking items) ────────────────────────────
	# h >= 8: counters, shelves, beds, appliances — solid obstacles.
	# h <  8: low decorative pieces (side tables, etc.) — passable.
	if h >= 8.0:
		var body := StaticBody2D.new()
		body.collision_layer = 8   # World layer — players + zombies + NPCs collide
		body.collision_mask  = 0
		var shape := ConvexPolygonShape2D.new()
		shape.points = PackedVector2Array([gN, gE, gS, gW])
		var col := CollisionShape2D.new()
		col.shape = shape
		body.add_child(col)
		add_child(body)   # child of ProceduralBuilding, not _furniture_node


func _build_furniture(pt_n: Vector2, pt_e: Vector2, pt_w: Vector2,
		bd: BuildingData, _rng: RandomNumberGenerator) -> void:
	var axes := _furn_axes(pt_n, pt_e, pt_w)
	var fc: Vector2 = axes[0]
	var nv: Vector2 = axes[1]
	var ev: Vector2 = axes[2]
	match bd.archetype:
		BuildingData.Archetype.SMALL_HOUSE, \
		BuildingData.Archetype.MEDIUM_HOUSE, \
		BuildingData.Archetype.FARMHOUSE, \
		BuildingData.Archetype.DUPLEX:
			_furn_rooms(fc, nv, ev, bd)
		BuildingData.Archetype.CONVENIENCE_STORE: _furn_convenience(fc, nv, ev)
		BuildingData.Archetype.PHARMACY:          _furn_pharmacy(fc, nv, ev)
		BuildingData.Archetype.RESTAURANT:        _furn_restaurant(fc, nv, ev)
		BuildingData.Archetype.OFFICE:            _furn_office(fc, nv, ev)
		BuildingData.Archetype.HARDWARE_STORE:    _furn_hardware(fc, nv, ev)
		BuildingData.Archetype.WAREHOUSE:         _furn_warehouse(fc, nv, ev)
		BuildingData.Archetype.GARAGE:            _furn_garage(fc, nv, ev)
		BuildingData.Archetype.STORAGE_YARD:      _furn_storage_yard(fc, nv, ev)
	_add_ceiling_fixture(fc, nv, ev, bd.archetype)


func _furn_small_house(fc: Vector2, nv: Vector2, ev: Vector2) -> void:
	# BEDROOM (ef < -0.08)
	_fn(fc, nv, ev,  0.20, -0.40, 0.88, 1.12, Color(_FRG, 0.65))                # bedroom rug
	_fb(fc, nv, ev,  0.52, -0.45, 0.88, 1.04, 5.0, _FMT, _FMS)                  # bed
	_fb(fc, nv, ev,  0.52, -0.64, 0.28, 0.36, 6.0, _FWS, _FWD)                  # nightstand
	# LIVING (ef > 0.08)
	_fn(fc, nv, ev, -0.05,  0.38, 0.88, 1.12, Color(_FRG, 0.55))                # living rug
	_fb(fc, nv, ev, -0.22,  0.28, 0.36, 0.80, 9.0, _FSF, _FSF.darkened(0.25))   # sofa
	_fb(fc, nv, ev,  0.02,  0.22, 0.16, 0.40, 4.0, _FWS, _FWD)                  # coffee table
	_fb(fc, nv, ev, -0.08,  0.58, 0.48, 0.56, 8.0, _FWS, _FWD)                  # dining table
	_place_chair_sprite(fc + nv * -0.30 + ev * 0.44, nv, ev, -0.30, 0.44)       # chair


func _furn_medium_house(fc: Vector2, nv: Vector2, ev: Vector2) -> void:
	# BEDROOM_1 (nf > 0.08, ef < -0.08)
	_fb(fc, nv, ev,  0.52, -0.42, 0.72, 0.88, 5.0, _FMT, _FMS)                   # bed west
	_fb(fc, nv, ev,  0.75, -0.22, 0.40, 1.12, 22.0, _FWD, _FWD.darkened(0.18))   # wardrobe NW
	# BEDROOM_2 (nf > 0.08, ef > 0.08)
	_fb(fc, nv, ev,  0.52,  0.42, 0.72, 0.88, 5.0, _FMT, _FMS)                   # bed east
	_fb(fc, nv, ev,  0.75,  0.22, 0.24, 0.56, 9.0, _FWS, _FWD)                   # desk NE
	# LIVING (nf < -0.08)
	_fb(fc, nv, ev, -0.10,  0.00, 0.40, 1.76, 9.0, _FSF, _FSF.darkened(0.25))    # sofa
	_fb(fc, nv, ev, -0.28,  0.00, 0.16, 0.72, 4.0, _FWS, _FWD)                   # coffee table
	_fn(fc, nv, ev, -0.52,  0.30, 0.64, 0.88, Color(_FRG, 0.55))                  # dining rug
	_fb(fc, nv, ev, -0.52,  0.30, 0.56, 0.72, 8.0, _FWS, _FWD)                   # dining table
	_place_chair_sprite(fc + nv * -0.40 + ev * 0.48, nv, ev, -0.40, 0.48)        # chair


func _furn_farmhouse(fc: Vector2, nv: Vector2, ev: Vector2) -> void:
	# BEDROOM (nf > 0.18)
	_fb(fc, nv, ev,  0.50, -0.30, 0.72, 0.88, 5.0, _FMT, _FMS)                   # bed
	_fb(fc, nv, ev,  0.58, -0.55, 0.28, 0.60, 12.0, _FWD, _FWD.darkened(0.20))   # dresser
	# KITCHEN (nf < -0.02)
	_fn(fc, nv, ev, -0.20,  0.24, 0.52, 0.72, Color(_FRG, 0.50))                  # table rug
	_fb(fc, nv, ev, -0.20,  0.24, 0.48, 0.64, 8.0, _FWS, _FWD)                   # kitchen table
	_fb(fc, nv, ev, -0.62,  0.30, 0.48, 0.56, 10.0, _FAP.lightened(0.08), _FAP)  # stove
	_place_chair_sprite(fc + nv * -0.08 + ev * 0.10, nv, ev, -0.08, 0.10)         # chair
	_place_chair_sprite(fc + nv * -0.38 + ev * 0.38, nv, ev, -0.38, 0.38)        # chair


func _furn_duplex(fc: Vector2, nv: Vector2, ev: Vector2) -> void:
	# WEST BEDROOM (nf > 0.08, ef < -0.08)
	_fb(fc, nv, ev,  0.48, -0.50, 0.64, 0.72, 5.0, _FMT, _FMS)
	_fb(fc, nv, ev,  0.62, -0.62, 0.28, 0.40, 12.0, _FWD, _FWD.darkened(0.20))
	# WEST LIVING (nf < -0.08, ef < -0.08)
	_fb(fc, nv, ev, -0.22, -0.48, 0.48, 0.64, 8.0, _FWS, _FWD)
	_fb(fc, nv, ev, -0.38, -0.35, 0.36, 0.80, 9.0, _FSF, _FSF.darkened(0.25))
	# EAST BEDROOM (nf > 0.08, ef > 0.08)
	_fb(fc, nv, ev,  0.48,  0.50, 0.64, 0.72, 5.0, _FMT, _FMS)
	_fb(fc, nv, ev,  0.62,  0.62, 0.28, 0.40, 12.0, _FWD, _FWD.darkened(0.20))
	# EAST LIVING (nf < -0.08, ef > 0.08)
	_fb(fc, nv, ev, -0.22,  0.48, 0.48, 0.64, 8.0, _FWS, _FWD)
	_fb(fc, nv, ev, -0.38,  0.35, 0.36, 0.80, 9.0, _FSF, _FSF.darkened(0.25))


func _furn_convenience(fc: Vector2, nv: Vector2, ev: Vector2) -> void:
	for ef: float in [-0.36, 0.0, 0.36]:
		_fb(fc, nv, ev,  0.18, ef, 2.00, 0.36, 14.0, _FSH, _FSH.darkened(0.22))  # shelf aisle
	_fb(fc, nv, ev, -0.70, 0.00, 0.48, 2.20, 10.0, _FCT, _FCS)   # service counter


func _furn_pharmacy(fc: Vector2, nv: Vector2, ev: Vector2) -> void:
	_fb(fc, nv, ev, -0.62,  0.00, 0.44, 2.00, 10.0, _FCT, _FCS)                 # counter
	_fb(fc, nv, ev, -0.50,  0.00, 0.24, 2.00, 18.0, _FFB, _FFB.lightened(0.10)) # back wall
	_fb(fc, nv, ev,  0.55, -0.28, 0.32, 1.28, 16.0, _FSH, _FSH.darkened(0.20))  # shelving W
	_fb(fc, nv, ev,  0.55,  0.28, 0.32, 1.28, 16.0, _FSH, _FSH.darkened(0.20))  # shelving E
	_place_chair_sprite(fc + nv * -0.32 + ev * -0.44, nv, ev, -0.32, -0.44)  # waiting chair
	_place_chair_sprite(fc + nv * -0.32 + ev * -0.55, nv, ev, -0.32, -0.55)  # waiting chair


func _furn_restaurant(fc: Vector2, nv: Vector2, ev: Vector2) -> void:
	_fb(fc, nv, ev,  0.75, 0.00, 0.40, 2.60, 10.0, _FAP.lightened(0.08), _FAP)  # kitchen counter
	for nf: float in [0.38, -0.05, -0.48]:
		for ef: float in [-0.36, 0.34]:
			_fn(fc, nv, ev, nf, ef, 0.52, 0.64, Color(_FRG, 0.45))
			_fb(fc, nv, ev, nf, ef, 0.44, 0.52, 8.0, _FWS, _FWD)  # dining table
			# Chairs flanking each table along the N/S axis.
			_place_chair_sprite(fc + nv * (nf + 0.26) + ev * ef, nv, ev, nf + 0.26, ef)
			_place_chair_sprite(fc + nv * (nf - 0.26) + ev * ef, nv, ev, nf - 0.26, ef)


func _furn_office(fc: Vector2, nv: Vector2, ev: Vector2) -> void:
	_fb(fc, nv, ev,  0.46, -0.36, 0.56, 0.96, 8.0, _FWS, _FWD)   # desk NW
	_fb(fc, nv, ev,  0.46,  0.26, 0.56, 0.96, 8.0, _FWS, _FWD)   # desk NE
	_fb(fc, nv, ev, -0.08, -0.36, 0.56, 0.96, 8.0, _FWS, _FWD)   # desk SW
	_fb(fc, nv, ev, -0.08,  0.26, 0.56, 0.96, 8.0, _FWS, _FWD)   # desk SE
	_fb(fc, nv, ev,  0.70, -0.18, 0.36, 0.48, 14.0, _FFB.lightened(0.08), _FFB)  # filing
	_fb(fc, nv, ev,  0.70,  0.04, 0.36, 0.48, 14.0, _FFB.lightened(0.08), _FFB)  # filing
	_fb(fc, nv, ev,  0.70,  0.22, 0.36, 0.48, 14.0, _FFB.lightened(0.08), _FFB)  # filing


func _furn_hardware(fc: Vector2, nv: Vector2, ev: Vector2) -> void:
	_fb(fc, nv, ev,  0.22, -0.32, 2.08, 0.40, 18.0, _FSH, _FSH.darkened(0.24))  # rack W
	_fb(fc, nv, ev,  0.22,  0.32, 2.08, 0.40, 18.0, _FSH, _FSH.darkened(0.24))  # rack E
	_fb(fc, nv, ev,  0.68,  0.00, 0.72, 1.68, 8.0, _FPL, _FPL.darkened(0.20))   # pallet stack
	_fb(fc, nv, ev, -0.70,  0.00, 0.40, 2.08, 10.0, _FCT, _FCS)                  # counter


func _furn_warehouse(fc: Vector2, nv: Vector2, ev: Vector2) -> void:
	for nf: float in [0.46, 0.06]:
		for ef: float in [-0.40, 0.0, 0.40]:
			_fb(fc, nv, ev, nf, ef, 0.72, 0.72, 10.0, _FPL, _FPL.darkened(0.22))  # pallet
	_fb(fc, nv, ev,  0.76, 0.00, 0.32, 2.40, 20.0, _FSH, _FSH.darkened(0.26))   # north shelving
	_fn(fc, nv, ev, -0.32, 0.00, 1.04, 0.64, Color(0.08, 0.08, 0.08, 0.35))     # forklift path


func _furn_garage(fc: Vector2, nv: Vector2, ev: Vector2) -> void:
	_fn(fc, nv, ev,  0.14,  0.00, 1.44, 1.84, Color(0.10, 0.10, 0.10, 0.50))   # car pit
	_fb(fc, nv, ev,  0.72,  0.00, 0.36, 2.24, 10.0, _FWD, _FWD.darkened(0.20)) # workbench
	_fb(fc, nv, ev,  0.22,  0.64, 1.20, 0.24, 16.0, _FFB.lightened(0.10), _FFB) # tool rack
	_fb(fc, nv, ev, -0.44, -0.44, 0.36, 0.40, 12.0, _FAP, _FAP.darkened(0.20)) # barrel cluster


func _furn_storage_yard(fc: Vector2, nv: Vector2, ev: Vector2) -> void:
	for nf: float in [0.50, 0.10, -0.32]:
		_fb(fc, nv, ev, nf, -0.36, 0.64, 0.88, 12.0, _FPL, _FPL.darkened(0.22))  # pallet W
		_fb(fc, nv, ev, nf,  0.36, 0.64, 0.88, 12.0, _FPL, _FPL.darkened(0.22))  # pallet E
	_fb(fc, nv, ev,  0.76, 0.00, 0.32, 2.40, 20.0, _FSH, _FSH.darkened(0.26))   # north shelving


# ── Room-aware furniture placement ────────────────────────────────────────────

func _furn_rooms(fc: Vector2, nv: Vector2, ev: Vector2, bd: BuildingData) -> void:
	# Pass 1 — per-room floor tint (added before furniture so it renders under it).
	for room: RoomDef in bd.rooms:
		var floor_col: Color
		match room.purpose:
			RoomDef.RoomPurpose.BEDROOM: floor_col = Color(0.72, 0.62, 0.50, 0.50)  # warm carpet
			RoomDef.RoomPurpose.LIVING:  floor_col = Color(0.52, 0.38, 0.24, 0.50)  # hardwood
			RoomDef.RoomPurpose.KITCHEN: floor_col = Color(0.82, 0.80, 0.76, 0.50)  # light tile
			RoomDef.RoomPurpose.STORAGE: floor_col = Color(0.48, 0.50, 0.54, 0.45)  # grey concrete
			_: continue
		# Build room diamond from nf/ef corners.
		var rN := fc + nv * room.nf_max + ev * room.ef_centre()
		var rE := fc + nv * room.nf_centre() + ev * room.ef_max
		var rS := fc + nv * room.nf_min + ev * room.ef_centre()
		var rW := fc + nv * room.nf_centre() + ev * room.ef_min
		_furniture_node.add_child(_make_poly([rN, rE, rS, rW], floor_col))
	# Pass 2 — furniture per room.
	for room: RoomDef in bd.rooms:
		match room.purpose:
			RoomDef.RoomPurpose.BEDROOM:  _furn_room_bedroom(fc, nv, ev, room)
			RoomDef.RoomPurpose.LIVING:   _furn_room_living(fc, nv, ev, room)
			RoomDef.RoomPurpose.KITCHEN:  _furn_room_kitchen(fc, nv, ev, room)
			RoomDef.RoomPurpose.STORAGE:  _furn_room_storage(fc, nv, ev, room)


func _furn_room_bedroom(fc: Vector2, nv: Vector2, ev: Vector2, room: RoomDef) -> void:
	var nc := room.nf_centre();  var ec := room.ef_centre()
	var nh := (room.nf_max - room.nf_min) * 0.5
	var eh := (room.ef_max - room.ef_min) * 0.5
	var rn := nh * 2.0;  var re := eh * 2.0
	var k  := clampf(minf(rn, re) / 1.60, 0.4, 1.0)
	var _bed_nf := room.nf_max - nh * 0.30
	_place_sprite_generic("FurnitureInstance_Bed",
		fc + nv * _bed_nf + ev * ec, nv, ev, _bed_nf, ec,
		BED_SHEET_PATH, BED_CELL_W, BED_CELL_H, BED_SCALE_X, BED_SCALE_Y, BED_PIVOTS,
		rn * 0.44, re * 0.54, 5.0 * k, _FMT, _FMS)
	_fn(fc, nv, ev, nc, ec, rn * 0.42, re * 0.52, Color(_FRG, 0.55))
	if re >= 0.32:
		var _ns_nf := room.nf_max - nh * 0.30
		var _ns_ef := ec + eh * 0.62
		_place_sprite_generic("FurnitureInstance_Nightstand",
			fc + nv * _ns_nf + ev * _ns_ef, nv, ev, _ns_nf, _ns_ef,
			NSTAND_SHEET_PATH, NSTAND_CELL_W, NSTAND_CELL_H, NSTAND_SCALE_X, NSTAND_SCALE_Y, NSTAND_PIVOTS,
			rn * 0.14, re * 0.20, 6.0 * k, _FWS, _FWD)


func _furn_room_living(fc: Vector2, nv: Vector2, ev: Vector2, room: RoomDef) -> void:
	var nc := room.nf_centre();  var ec := room.ef_centre()
	var nh := (room.nf_max - room.nf_min) * 0.5
	var eh := (room.ef_max - room.ef_min) * 0.5
	var rn := nh * 2.0;  var re := eh * 2.0
	var k  := clampf(minf(rn, re) / 1.60, 0.4, 1.0)
	_fn(fc, nv, ev, nc, ec, rn * 0.58, re * 0.70, Color(_FRG, 0.55))
	var _sofa_nf := room.nf_min + nh * 0.28
	_place_sprite_generic("FurnitureInstance_Sofa",
		fc + nv * _sofa_nf + ev * ec, nv, ev, _sofa_nf, ec,
		SOFA_SHEET_PATH, SOFA_CELL_W, SOFA_CELL_H, SOFA_SCALE_X, SOFA_SCALE_Y, SOFA_PIVOTS,
		rn * 0.22, re * 0.54, 9.0 * k, _FSF, _FSF.darkened(0.25))
	var _st_nf := room.nf_min + nh * 0.60
	_place_sprite_generic("FurnitureInstance_SideTable",
		fc + nv * _st_nf + ev * ec, nv, ev, _st_nf, ec,
		STABLE_SHEET_PATH, STABLE_CELL_W, STABLE_CELL_H, STABLE_SCALE_X, STABLE_SCALE_Y, STABLE_PIVOTS,
		rn * 0.10, re * 0.28, 4.0 * k, _FWS, _FWD)
	if rn >= 0.70:
		var tnf := nc + nh * 0.40
		var tef := ec + eh * 0.20
		_place_sprite_generic("FurnitureInstance_DiningTable",
			fc + nv * tnf + ev * tef, nv, ev, tnf, tef,
			DTABLE_SHEET_PATH, DTABLE_CELL_W, DTABLE_CELL_H, DTABLE_SCALE_X, DTABLE_SCALE_Y, DTABLE_PIVOTS,
			rn * 0.30, re * 0.38, 8.0 * k, _FWS, _FWD)
		# Chairs north and south of the table.
		_place_chair_sprite(fc + nv * (tnf + rn * 0.20) + ev * tef, nv, ev, tnf + rn * 0.20, tef)
		_place_chair_sprite(fc + nv * (tnf - rn * 0.20) + ev * tef, nv, ev, tnf - rn * 0.20, tef)


func _furn_room_kitchen(fc: Vector2, nv: Vector2, ev: Vector2, room: RoomDef) -> void:
	var nc := room.nf_centre();  var ec := room.ef_centre()
	var nh := (room.nf_max - room.nf_min) * 0.5
	var eh := (room.ef_max - room.ef_min) * 0.5
	var rn := nh * 2.0;  var re := eh * 2.0
	var k  := clampf(minf(rn, re) / 1.60, 0.4, 1.0)
	# Stove/appliance block near north wall.
	var _stv_nf := room.nf_max - nh * 0.22
	var _stv_ef := ec + eh * 0.40
	_place_sprite_generic("FurnitureInstance_Stove",
		fc + nv * _stv_nf + ev * _stv_ef, nv, ev, _stv_nf, _stv_ef,
		STOVE_SHEET_PATH, STOVE_CELL_W, STOVE_CELL_H, STOVE_SCALE_X, STOVE_SCALE_Y, STOVE_PIVOTS,
		rn * 0.28, re * 0.35, 10.0 * k, _FAP.lightened(0.08), _FAP)
	# Rug/mat in room centre.
	_fn(fc, nv, ev, nc - nh * 0.12, ec, rn * 0.34, re * 0.48, Color(_FRG, 0.50))
	# Counter sprite along the south wall.
	var cnf := nc - nh * 0.12
	var cef := ec
	_place_counter_sprite(fc + nv * cnf + ev * cef, nv, ev, cnf, cef)


func _furn_room_storage(fc: Vector2, nv: Vector2, ev: Vector2, room: RoomDef) -> void:
	var ec := room.ef_centre()
	var rn := room.nf_max - room.nf_min
	var re := room.ef_max - room.ef_min
	var k  := clampf(minf(rn, re) / 1.60, 0.4, 1.0)
	var _bsn_nf := room.nf_max - rn * 0.09
	_place_sprite_generic("FurnitureInstance_Bookshelf",
		fc + nv * _bsn_nf + ev * ec, nv, ev, _bsn_nf, ec,
		BSHELF_SHEET_PATH, BSHELF_CELL_W, BSHELF_CELL_H, BSHELF_SCALE_X, BSHELF_SCALE_Y, BSHELF_PIVOTS,
		rn * 0.16, re * 0.62, 14.0 * k, _FSH, _FSH.darkened(0.20))


# ── Interior wall generation ──────────────────────────────────────────────────

func _build_interior_walls(
		bd: BuildingData, pt_n: Vector2, pt_e: Vector2, pt_w: Vector2) -> void:
	if bd.interior_wall_defs.is_empty():
		return

	var body := StaticBody2D.new()
	body.collision_layer = 8;  body.collision_mask = 0
	add_child(body)

	# Tile rect in local tilemap coords (same space BuildingData._tile_to_ef/nf use).
	var r    := bd.tile_rect
	var bx_f := float(r.position.x)
	var by_f := float(r.position.y)
	var bw_f := float(r.size.x)
	var bh_f := float(r.size.y)
	var have_tiles := _tilemap_ref != null and bw_f > 1.0 and bh_f > 1.0

	# Fallback nf/ef axes (used when tilemap not available).
	var axes := _furn_axes(pt_n, pt_e, pt_w)
	var fc := axes[0] as Vector2;  var nv := axes[1] as Vector2;  var ev := axes[2] as Vector2

	for wd: RoomDef.InteriorWallDef in bd.interior_wall_defs:
		var is_nf := wd.axis == RoomDef.InteriorWallDef.Axis.NF
		var end_a := Vector2.ZERO
		var end_b := Vector2.ZERO
		var door_pt := Vector2.ZERO

		if have_tiles:
			if is_nf:
				# NF wall: boundary between tile rows (row-1) and row.
				var row    := roundi((0.80 - wd.value) * (bh_f - 1.0) / 1.60 + by_f)
				var col_lo := roundi((wd.lo  + 0.80)  * (bw_f - 1.0) / 1.60 + bx_f)
				var col_hi := roundi((wd.hi  + 0.80)  * (bw_f - 1.0) / 1.60 + bx_f)
				end_a = _tile_row_edge_mid(col_lo, row)
				end_b = _tile_row_edge_mid(col_hi, row)
				if wd.door_fraction != -INF:
					var dcol := roundi((wd.door_fraction + 0.80) * (bw_f - 1.0) / 1.60 + bx_f)
					door_pt = _tile_row_edge_mid(dcol, row)
			else:
				# EF wall: boundary between tile cols (col-1) and col.
				var col    := roundi((wd.value  + 0.80) * (bw_f - 1.0) / 1.60 + bx_f)
				var row_lo := roundi((0.80 - wd.hi) * (bh_f - 1.0) / 1.60 + by_f)
				var row_hi := roundi((0.80 - wd.lo) * (bh_f - 1.0) / 1.60 + by_f)
				end_a = _tile_col_edge_mid(col, row_lo)
				end_b = _tile_col_edge_mid(col, row_hi)
				if wd.door_fraction != -INF:
					var drow := roundi((0.80 - wd.door_fraction) * (bh_f - 1.0) / 1.60 + by_f)
					door_pt = _tile_col_edge_mid(col, drow)
		else:
			# Fallback: compute from nf/ef coordinate system.
			if is_nf:
				end_a = fc + nv * wd.value + ev * wd.lo
				end_b = fc + nv * wd.value + ev * wd.hi
				if wd.door_fraction != -INF:
					door_pt = fc + nv * wd.value + ev * wd.door_fraction
			else:
				end_a = fc + nv * wd.lo  + ev * wd.value
				end_b = fc + nv * wd.hi  + ev * wd.value
				if wd.door_fraction != -INF:
					door_pt = fc + nv * wd.door_fraction + ev * wd.value

		var diff     := end_b - end_a
		var wall_dir := diff.normalized()
		var wall_len := diff.length()

		# ── 3D interior wall visual ────────────────────────────────────────────
		const IW_H  := 20.0
		var up_iw   := Vector2(0.0, -IW_H)
		var iw_base := Color(0.50, 0.44, 0.35)
		var iw_dark := ArtPalette.cool_shadow(iw_base, 0.20).darkened(0.22)
		var iw_cap  := iw_base.lightened(0.15)
		var iw_ol   := ArtPalette.cool_shadow(iw_base, 0.55).darkened(0.35)
		iw_ol.a     = 0.85
		# Viewer-facing (screen-south) side gets the lit front face.
		var perp      := wall_dir.rotated(PI * 0.5)
		var face_side := perp if perp.y >= 0.0 else -perp
		var offs      := face_side * 3.0   # 3px offset gives slight 3D thickness

		if wd.door_fraction == -INF:
			# Back plane (darker).
			add_child(_make_poly([end_a, end_b, end_b + up_iw, end_a + up_iw], iw_dark))
			# Front face + cap (lit side with outlines).
			_add_wall_face(end_a + offs, end_b + offs, up_iw, iw_base, iw_cap, iw_ol)
			_add_wall_seg(body, end_a, end_b)
		else:
			var gap_a := door_pt - wall_dir * INTERIOR_DOOR_HALF_GAP_PX
			var gap_b := door_pt + wall_dir * INTERIOR_DOOR_HALF_GAP_PX
			var t_ga  := clampf((gap_a - end_a).dot(wall_dir) / wall_len, 0.02, 0.98)
			var t_gb  := clampf((gap_b - end_a).dot(wall_dir) / wall_len, 0.02, 0.98)
			gap_a = end_a + wall_dir * (t_ga * wall_len)
			gap_b = end_a + wall_dir * (t_gb * wall_len)

			if t_ga > 0.02:
				add_child(_make_poly([end_a, gap_a, gap_a + up_iw, end_a + up_iw], iw_dark))
				_add_wall_face(end_a + offs, gap_a + offs, up_iw, iw_base, iw_cap, iw_ol)
				_add_wall_seg(body, end_a, gap_a)
			if t_gb < 0.98:
				add_child(_make_poly([gap_b, end_b, end_b + up_iw, gap_b + up_iw], iw_dark))
				_add_wall_face(gap_b + offs, end_b + offs, up_iw, iw_base, iw_cap, iw_ol)
				_add_wall_seg(body, gap_b, end_b)

			# Door opening — translucent fill.
			add_child(_make_poly([
				gap_a + offs, gap_b + offs,
				gap_b + offs + up_iw, gap_a + offs + up_iw,
			], Color(0.55, 0.48, 0.38, 0.30)))

			_interior_door_centres.append(door_pt)


## Midpoint of the tile-row boundary between (col, row-1) and (col, row).
## Used for NF walls (running in the tile-column direction).
func _tile_row_edge_mid(col: int, row: int) -> Vector2:
	var p0 := to_local(_tilemap_ref.map_to_local(_origin_offset + Vector2i(col, row - 1)))
	var p1 := to_local(_tilemap_ref.map_to_local(_origin_offset + Vector2i(col, row)))
	return (p0 + p1) * 0.5


## Midpoint of the tile-col boundary between (col-1, row) and (col, row).
## Used for EF walls (running in the tile-row direction).
func _tile_col_edge_mid(col: int, row: int) -> Vector2:
	var p0 := to_local(_tilemap_ref.map_to_local(_origin_offset + Vector2i(col - 1, row)))
	var p1 := to_local(_tilemap_ref.map_to_local(_origin_offset + Vector2i(col, row)))
	return (p0 + p1) * 0.5


# ── Wall-adjacency helpers (furniture placement) ──────────────────────────────

## Count how many of mc's 4 orthogonal tilemap neighbors are non-floor (wall/exterior).
func count_wall_neighbors(mc: Vector2i) -> int:
	var n := 0
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not _floor_cells.has(mc + d):
			n += 1
	return n


## Returns the tilemap-delta of the primary wall neighbor (most aligned with building
## nv/ev axes).  Returns Vector2i.ZERO if no wall neighbor exists.
func primary_wall_dir(mc: Vector2i, nv: Vector2, ev: Vector2) -> Vector2i:
	var best_dir := Vector2i.ZERO
	var best_dot := -INF
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not _floor_cells.has(mc + d):
			var screen_dir := Vector2(
				float(d.x - d.y) * TILE_W * 0.5,
				float(d.x + d.y) * TILE_H * 0.5
			).normalized()
			var dot := maxf(
				screen_dir.dot( nv.normalized()),
				maxf(screen_dir.dot(-nv.normalized()),
				maxf(screen_dir.dot( ev.normalized()),
					 screen_dir.dot(-ev.normalized()))))
			if dot > best_dot:
				best_dot = dot
				best_dir = d
	return best_dir


## Visual-only screen-space offset for pushing furniture against the wall at tile_dir.
## Offset is 15% of one isometric tile step in that direction.  Grid data unchanged.
func wall_hug_offset(tile_dir: Vector2i) -> Vector2:
	return Vector2(
		float(tile_dir.x - tile_dir.y) * TILE_W * 0.5,
		float(tile_dir.x + tile_dir.y) * TILE_H * 0.5
	) * 0.40


## Maps a tilemap wall direction to the FRIDGE_VIEW_* index.
func fridge_view_for_wall(wall_tile_dir: Vector2i, nv: Vector2, ev: Vector2) -> Vector2i:
	var screen_wall := Vector2(
		float(wall_tile_dir.x - wall_tile_dir.y) * TILE_W * 0.5,
		float(wall_tile_dir.x + wall_tile_dir.y) * TILE_H * 0.5
	).normalized()
	var dot_nv := screen_wall.dot(nv.normalized())
	var dot_ev := screen_wall.dot(ev.normalized())
	if abs(dot_nv) >= abs(dot_ev):
		return FRIDGE_VIEW_S if dot_nv > 0.0 else FRIDGE_VIEW_N   # door faces away from wall
	else:
		return FRIDGE_VIEW_W if dot_ev > 0.0 else FRIDGE_VIEW_E   # door faces away from wall


## Maps a wall direction to the COUNTER_VIEW_* that faces away from that wall.
func counter_view_for_wall(wall_tile_dir: Vector2i, nv: Vector2, ev: Vector2) -> Vector2i:
	var screen_wall := Vector2(
		float(wall_tile_dir.x - wall_tile_dir.y) * TILE_W * 0.5,
		float(wall_tile_dir.x + wall_tile_dir.y) * TILE_H * 0.5
	).normalized()
	var dot_nv := screen_wall.dot(nv.normalized())
	var dot_ev := screen_wall.dot(ev.normalized())
	if abs(dot_nv) >= abs(dot_ev):
		return COUNTER_VIEW_S if dot_nv > 0.0 else COUNTER_VIEW_N
	else:
		return COUNTER_VIEW_W if dot_ev > 0.0 else COUNTER_VIEW_E


## Selects the best floor tile for fridge placement in WORLDGEN mode.
## Prefers tiles with >= 2 wall neighbors (corner), then >= 1.
## Returns [snapped_nf, snapped_ef, mc] where mc is the chosen map-data tile cell.
func _worldgen_pick_wall_tile(fc: Vector2, nv: Vector2, ev: Vector2,
		nf_hint: float, ef_hint: float) -> Array:
	if _tilemap_ref == null or _floor_cells.is_empty():
		var snapped := _snap_to_tile(fc, nv, ev, nf_hint, ef_hint)
		return [snapped[0], snapped[1], Vector2i.ZERO]

	var hint_world := to_global(fc + nv * nf_hint + ev * ef_hint)
	var best_score := -1
	var best_dist2 := INF
	var best_mc    := Vector2i.ZERO

	for mc: Vector2i in _floor_cells:
		var walls := count_wall_neighbors(mc)
		if walls == 0:
			continue
		var cell_world := _tilemap_ref.map_to_local(mc + _origin_offset)
		var dist2 := cell_world.distance_squared_to(hint_world)
		if walls > best_score or (walls == best_score and dist2 < best_dist2):
			best_score = walls
			best_dist2 = dist2
			best_mc    = mc

	if best_score < 1:
		var snapped := _snap_to_tile(fc, nv, ev, nf_hint, ef_hint)
		return [snapped[0], snapped[1], Vector2i.ZERO]

	# Convert best_mc back to snapped_nf/snapped_ef via Cramer's rule.
	var tc          := best_mc + _origin_offset
	var snapped_loc := to_local(_tilemap_ref.map_to_local(tc))
	var delta := snapped_loc - fc
	var det   := nv.x * ev.y - nv.y * ev.x
	if abs(det) < 0.1:
		return [nf_hint, ef_hint, best_mc]
	var snapped_nf := (delta.x * ev.y - delta.y * ev.x) / det
	var snapped_ef := (nv.x * delta.y - nv.y * delta.x) / det
	return [snapped_nf, snapped_ef, best_mc]


## Worldgen fridge placement: picks best wall-adjacent tile, orients sprite to face the wall.
func _place_fridge_sprite_worldgen(
		local_c: Vector2, mc: Vector2i, nv: Vector2, ev: Vector2) -> void:
	var wall_dir := primary_wall_dir(mc, nv, ev)
	var view     := FRIDGE_VIEW_S   # fallback
	var hug_off  := Vector2.ZERO
	if wall_dir != Vector2i.ZERO:
		view    = fridge_view_for_wall(wall_dir, nv, ev)
		hug_off = wall_hug_offset(wall_dir)
	_place_fridge_sprite_with_view(local_c, local_c + hug_off, view, nv, ev)


## Core fridge placement with explicit collision_c (grid-true) and visual_c (hug-shifted).
func _place_fridge_sprite_with_view(
		collision_c: Vector2, visual_c: Vector2, view: Vector2i,
		nv: Vector2, ev: Vector2) -> void:
	var inst := Node2D.new()
	inst.name     = "FurnitureInstance_Fridge"
	inst.position = collision_c   # grid truth

	var body := StaticBody2D.new()
	body.collision_layer = 8;  body.collision_mask = 0
	var fdn := nv.normalized() * (0.36 * TILE_H * 0.5)   # SN=0.36 (tile-unit, was 0.09 × 4)
	var fde := ev.normalized() * (0.48 * TILE_W * 0.5)   # SE=0.48 (tile-unit, was 0.12 × 4)
	var cshape := CollisionShape2D.new()
	cshape.shape = ConvexPolygonShape2D.new()
	cshape.shape.points = PackedVector2Array([fdn, fde, -fdn, -fde])
	body.add_child(cshape);  inst.add_child(body)

	var sprite_extra_offset := visual_c - collision_c

	var sheet: Texture2D = null
	if ResourceLoader.exists(FRIDGE_SHEET_PATH):
		sheet = ResourceLoader.load(FRIDGE_SHEET_PATH)
	if sheet == null:
		const H_FB := 22.0
		var top_c  := Color(0.84, 0.90, 0.92)
		var side_c := Color(0.66, 0.76, 0.80)
		var dn := fdn;  var de := fde
		var up  := Vector2(0.0, -H_FB)
		var o   := sprite_extra_offset
		inst.add_child(_make_poly([-de + o, -dn + o, -dn + up + o, -de + up + o], side_c.darkened(0.08)))
		inst.add_child(_make_poly([ de + o, -dn + o, -dn + up + o,  de + up + o], side_c.darkened(0.28)))
		inst.add_child(_make_poly([ dn + up + o, de + up + o, -dn + up + o, -de + up + o], top_c.lightened(0.12)))
		_furniture_node.add_child(inst)
		_fridge_record_north_tile(collision_c, nv)
		return

	var atlas := AtlasTexture.new()
	atlas.atlas  = sheet
	atlas.region = Rect2(view.x * FRIDGE_CELL_W, view.y * FRIDGE_CELL_H, FRIDGE_CELL_W, FRIDGE_CELL_H)
	atlas.filter_clip = true

	var spr := Sprite2D.new()
	spr.texture        = atlas
	spr.centered       = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var scale_vec      := Vector2(FRIDGE_SCALE_X, FRIDGE_SCALE_Y)
	spr.scale          = scale_vec
	var flat_idx := view.y * 2 + view.x
	var pivot    := FRIDGE_PIVOTS[flat_idx] as Vector2
	spr.position = -(pivot * scale_vec) + sprite_extra_offset

	inst.add_child(spr)
	_furniture_node.add_child(inst)
	_fridge_record_north_tile(collision_c, nv)


# ── Container placement (server only) ─────────────────────────────────────────
## Places the fridge sprite + collision at local_c using the sprite sheet.
## Falls back to a procedural _fb() box if the texture file isn't found.
func _place_fridge_sprite(local_c: Vector2, nv: Vector2, ev: Vector2,
		nf: float, ef: float) -> void:
	# ── FurnitureInstance root — positioned at the pivot tile centre. ──────────
	# inst.position = map_to_local(pivot_cell) expressed in building-local space.
	var inst := Node2D.new()
	inst.name     = "FurnitureInstance_Fridge"
	inst.position = local_c

	# ── Collision body at (0,0) of inst ────────────────────────────────────────
	var body := StaticBody2D.new()
	body.collision_layer = 8
	body.collision_mask  = 0
	const SN := 0.09
	const SE := 0.12
	var cshape := CollisionShape2D.new()
	cshape.shape = ConvexPolygonShape2D.new()
	# Points relative to inst (0,0) — floor-contact point is the parent origin.
	cshape.shape.points = PackedVector2Array([
		nv * SN, ev * SE, -nv * SN, -ev * SE
	])
	body.add_child(cshape)
	inst.add_child(body)

	# ── Sprite visual ──────────────────────────────────────────────────────────
	var sheet: Texture2D = null
	if ResourceLoader.exists(FRIDGE_SHEET_PATH):
		sheet = ResourceLoader.load(FRIDGE_SHEET_PATH)
	if sheet == null:
		# Procedural fallback — box drawn relative to (0,0) of inst.
		const H_FB := 22.0
		var top_c  := Color(0.84, 0.90, 0.92)
		var side_c := Color(0.66, 0.76, 0.80)
		var dn := nv * SN;  var de := ev * SE
		var up  := Vector2(0.0, -H_FB)
		inst.add_child(_make_poly([-de, -dn, -dn + up, -de + up], side_c.darkened(0.08)))
		inst.add_child(_make_poly([ de, -dn, -dn + up,  de + up], side_c.darkened(0.28)))
		inst.add_child(_make_poly([ dn + up,  de + up, -dn + up, -de + up], top_c.lightened(0.12)))
		_furniture_node.add_child(inst)
		_fridge_record_north_tile(local_c, nv)
		return

	# Choose which cell of the 2×2 grid based on where the fridge sits.
	var view: Vector2i
	if nf >= 0.0:
		view = FRIDGE_VIEW_N if ef <= 0.0 else FRIDGE_VIEW_E
	else:
		view = FRIDGE_VIEW_S if ef <= 0.0 else FRIDGE_VIEW_W

	var atlas := AtlasTexture.new()
	atlas.atlas  = sheet
	atlas.region = Rect2(view.x * FRIDGE_CELL_W, view.y * FRIDGE_CELL_H,
						  FRIDGE_CELL_W, FRIDGE_CELL_H)
	atlas.filter_clip = true

	var spr := Sprite2D.new()
	spr.texture        = atlas
	spr.centered       = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var scale_vec      := Vector2(FRIDGE_SCALE_X, FRIDGE_SCALE_Y)
	spr.scale          = scale_vec
	# Offset so the per-view floor-contact pixel lands at (0,0) of inst.
	var flat_idx := view.y * 2 + view.x
	var pivot    := FRIDGE_PIVOTS[flat_idx] as Vector2
	spr.position = -(pivot * scale_vec)

	inst.add_child(spr)
	_furniture_node.add_child(inst)
	_fridge_record_north_tile(local_c, nv)


## Records the tile one step north of local_c into _occupied_cells for debug rendering.
## Finds the 4-adjacent tilemap cell whose screen direction best aligns with building-north (nv).
func _fridge_record_north_tile(local_c: Vector2, nv: Vector2) -> void:
	if not DEBUG_FURNITURE or _tilemap_ref == null:
		return
	var world_pivot := to_global(local_c)
	var tc          := _tilemap_ref.local_to_map(world_pivot)
	var best_tc     := tc
	var best_dot    := -INF
	for delta: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var candidate_dir := (_tilemap_ref.map_to_local(tc + delta) - world_pivot).normalized()
		var d := candidate_dir.dot(nv.normalized())
		if d > best_dot:
			best_dot = d
			best_tc  = tc + delta
	_occupied_cells.append(best_tc - _origin_offset)


## Places a kitchen counter sprite at local_c, oriented toward the nearest wall.
## view is chosen from COUNTER_VIEW_* based on nf/ef position in the room.
func _place_counter_sprite(local_c: Vector2, nv: Vector2, ev: Vector2,
		nf: float, ef: float) -> void:
	var inst := Node2D.new()
	inst.name     = "FurnitureInstance_Counter"
	inst.position = local_c

	# Collision — thin diamond matching one tile footprint.
	var body := StaticBody2D.new()
	body.collision_layer = 8
	body.collision_mask  = 0
	const SN := 0.12
	const SE := 0.14
	var cshape := CollisionShape2D.new()
	cshape.shape = ConvexPolygonShape2D.new()
	cshape.shape.points = PackedVector2Array([nv * SN, ev * SE, -nv * SN, -ev * SE])
	body.add_child(cshape)
	inst.add_child(body)

	# Choose view based on room quadrant (same logic as fridge).
	var view: Vector2i
	if nf >= 0.0:
		view = COUNTER_VIEW_N if ef <= 0.0 else COUNTER_VIEW_E
	else:
		view = COUNTER_VIEW_S if ef <= 0.0 else COUNTER_VIEW_W

	var sheet: Texture2D = null
	if ResourceLoader.exists(COUNTER_SHEET_PATH):
		sheet = ResourceLoader.load(COUNTER_SHEET_PATH)
	if sheet == null:
		# Procedural fallback — plain box.
		var dn := nv * SN;  var de := ev * SE
		const H_CT := 18.0
		var up := Vector2(0.0, -H_CT)
		inst.add_child(_make_poly([-de, -dn, -dn + up, -de + up], _FCS))
		inst.add_child(_make_poly([ de, -dn, -dn + up,  de + up], _FCS.darkened(0.20)))
		inst.add_child(_make_poly([ dn + up,  de + up, -dn + up, -de + up], _FCT))
		_furniture_node.add_child(inst)
		return

	var atlas := AtlasTexture.new()
	atlas.atlas  = sheet
	atlas.region = Rect2(view.x * COUNTER_CELL_W, view.y * COUNTER_CELL_H,
						  COUNTER_CELL_W, COUNTER_CELL_H)
	atlas.filter_clip = true

	var spr := Sprite2D.new()
	spr.texture        = atlas
	spr.centered       = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var scale_vec := Vector2(COUNTER_SCALE_X, COUNTER_SCALE_Y)
	spr.scale     = scale_vec
	var flat_idx  := view.y * 2 + view.x
	var pivot     := COUNTER_PIVOTS[flat_idx] as Vector2
	spr.position  = -(pivot * scale_vec)

	inst.add_child(spr)
	_furniture_node.add_child(inst)


## Places a chair sprite at local_c, oriented so the backrest faces away from the table.
## view is chosen from CHAIR_VIEW_* by the (nf, ef) quadrant of the chair's position.
func _place_chair_sprite(local_c: Vector2, nv: Vector2, ev: Vector2,
		nf: float, ef: float) -> void:
	var inst := Node2D.new()
	inst.name     = "FurnitureInstance_Chair"
	inst.position = local_c

	# Thin collision diamond — chairs are small obstacles.
	var body := StaticBody2D.new()
	body.collision_layer = 8
	body.collision_mask  = 0
	const SN := 0.08
	const SE := 0.08
	var cshape := CollisionShape2D.new()
	cshape.shape = ConvexPolygonShape2D.new()
	cshape.shape.points = PackedVector2Array([nv * SN, ev * SE, -nv * SN, -ev * SE])
	body.add_child(cshape)
	inst.add_child(body)

	# Chair back faces outward: chair south of table → S view (back toward south wall).
	var view: Vector2i
	if nf >= 0.0:
		view = CHAIR_VIEW_N if ef <= 0.0 else CHAIR_VIEW_E
	else:
		view = CHAIR_VIEW_S if ef <= 0.0 else CHAIR_VIEW_W

	var sheet: Texture2D = null
	if ResourceLoader.exists(CHAIR_SHEET_PATH):
		sheet = ResourceLoader.load(CHAIR_SHEET_PATH)
	if sheet == null:
		# Procedural fallback — small wooden box.
		var dn := nv * SN;  var de := ev * SE
		const H_CH := 10.0
		var up := Vector2(0.0, -H_CH)
		inst.add_child(_make_poly([-de, -dn, -dn + up, -de + up], _FWD))
		inst.add_child(_make_poly([ de, -dn, -dn + up,  de + up], _FWD.darkened(0.20)))
		inst.add_child(_make_poly([ dn + up,  de + up, -dn + up, -de + up], _FWS))
		_furniture_node.add_child(inst)
		return

	var atlas := AtlasTexture.new()
	atlas.atlas  = sheet
	atlas.region = Rect2(view.x * CHAIR_CELL_W, view.y * CHAIR_CELL_H,
						  CHAIR_CELL_W, CHAIR_CELL_H)
	atlas.filter_clip = true

	var spr := Sprite2D.new()
	spr.texture        = atlas
	spr.centered       = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var scale_vec := Vector2(CHAIR_SCALE_X, CHAIR_SCALE_Y)
	spr.scale     = scale_vec
	var flat_idx  := view.y * 2 + view.x
	var pivot     := CHAIR_PIVOTS[flat_idx] as Vector2
	spr.position  = -(pivot * scale_vec)

	inst.add_child(spr)
	_furniture_node.add_child(inst)


## Returns [path, cell_w, cell_h, scale_x, scale_y, pivots] for a container type,
## or an empty array if no sprite sheet exists for that type.
func _container_sprite_params(ct: int) -> Array:
	match ct:
		WorldContainer.ContainerType.NIGHTSTAND:
			return [NSTAND_SHEET_PATH,  NSTAND_CELL_W,  NSTAND_CELL_H,  NSTAND_SCALE_X,  NSTAND_SCALE_Y,  NSTAND_PIVOTS]
		WorldContainer.ContainerType.WARDROBE:
			return [WARDROBE_SHEET_PATH, WARDROBE_CELL_W, WARDROBE_CELL_H, WARDROBE_SCALE_X, WARDROBE_SCALE_Y, WARDROBE_PIVOTS]
		WorldContainer.ContainerType.DRESSER:
			return [DRESSER_SHEET_PATH, DRESSER_CELL_W, DRESSER_CELL_H, DRESSER_SCALE_X, DRESSER_SCALE_Y, DRESSER_PIVOTS]
		WorldContainer.ContainerType.MEDICINE_CABINET:
			return [MEDCAB_SHEET_PATH,  MEDCAB_CELL_W,  MEDCAB_CELL_H,  MEDCAB_SCALE_X,  MEDCAB_SCALE_Y,  MEDCAB_PIVOTS]
		WorldContainer.ContainerType.FILING_CABINET:
			return [FILECAB_SHEET_PATH, FILECAB_CELL_W, FILECAB_CELL_H, FILECAB_SCALE_X, FILECAB_SCALE_Y, FILECAB_PIVOTS]
		WorldContainer.ContainerType.LOCKER:
			return [LOCKER_SHEET_PATH,  LOCKER_CELL_W,  LOCKER_CELL_H,  LOCKER_SCALE_X,  LOCKER_SCALE_Y,  LOCKER_PIVOTS]
	return []


## Generic sprite-sheet furniture placement.
## Handles collision, view selection, sprite crop, scale, and pivot.
## Fallback: draws a procedural iso-box if the sheet file is missing.
func _place_sprite_generic(
		inst_name: String, local_c: Vector2, nv: Vector2, ev: Vector2,
		nf: float, ef: float,
		sheet_path: String, cell_w: int, cell_h: int,
		scale_x: float, scale_y: float, pivots: Array,
		coll_sn: float, coll_se: float,
		fallback_h: float, fallback_top: Color, fallback_side: Color) -> void:
	var inst := Node2D.new()
	inst.name     = inst_name
	inst.position = local_c

	var body := StaticBody2D.new()
	body.collision_layer = 8
	body.collision_mask  = 0
	var cshape := CollisionShape2D.new()
	cshape.shape = ConvexPolygonShape2D.new()
	cshape.shape.points = PackedVector2Array([nv * coll_sn, ev * coll_se, -nv * coll_sn, -ev * coll_se])
	body.add_child(cshape)
	inst.add_child(body)

	# Standard 4-quadrant view selection.
	var view: Vector2i
	if nf >= 0.0:
		view = Vector2i(0, 1) if ef <= 0.0 else Vector2i(1, 0)   # N or E
	else:
		view = Vector2i(0, 0) if ef <= 0.0 else Vector2i(1, 1)   # S or W

	var sheet: Texture2D = null
	if ResourceLoader.exists(sheet_path):
		sheet = ResourceLoader.load(sheet_path)
	if sheet == null:
		var dn := nv * coll_sn;  var de := ev * coll_se
		var up := Vector2(0.0, -fallback_h)
		inst.add_child(_make_poly([-de, -dn, -dn + up, -de + up], fallback_side.darkened(0.08)))
		inst.add_child(_make_poly([ de, -dn, -dn + up,  de + up], fallback_side.darkened(0.28)))
		inst.add_child(_make_poly([ dn + up,  de + up, -dn + up, -de + up], fallback_top.lightened(0.12)))
		_furniture_node.add_child(inst)
		return

	var atlas := AtlasTexture.new()
	atlas.atlas  = sheet
	atlas.region = Rect2(view.x * cell_w, view.y * cell_h, cell_w, cell_h)
	atlas.filter_clip = true

	var spr := Sprite2D.new()
	spr.texture        = atlas
	spr.centered       = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var scale_vec      := Vector2(scale_x, scale_y)
	spr.scale          = scale_vec
	var flat_idx       := view.y * 2 + view.x
	var pivot          := pivots[flat_idx] as Vector2
	spr.position       = -(pivot * scale_vec)

	inst.add_child(spr)
	_furniture_node.add_child(inst)


## Spawns WorldContainer Area2D nodes at furniture positions for each archetype.
## Called from setup() on the server.

func _place_containers(
		pt_n: Vector2, pt_e: Vector2, pt_w: Vector2,
		bd: BuildingData) -> void:
	var axes := _furn_axes(pt_n, pt_e, pt_w)
	var fc: Vector2 = axes[0]
	var nv: Vector2 = axes[1]
	var ev: Vector2 = axes[2]

	# [ContainerType, nf, ef]
	var to_place: Array = []
	match bd.archetype:
		BuildingData.Archetype.SMALL_HOUSE:
			to_place = [
				[WorldContainer.ContainerType.NIGHTSTAND, 0.56,  0.22],
				[WorldContainer.ContainerType.FRIDGE,    -0.56,  0.25],
			]
		BuildingData.Archetype.MEDIUM_HOUSE:
			to_place = [
				[WorldContainer.ContainerType.NIGHTSTAND, 0.48, -0.05],
				[WorldContainer.ContainerType.NIGHTSTAND, 0.48,  0.05],
				[WorldContainer.ContainerType.WARDROBE,   0.70,  0.00],
				[WorldContainer.ContainerType.FRIDGE,    -0.55,  0.30],
			]
		BuildingData.Archetype.FARMHOUSE:
			to_place = [
				[WorldContainer.ContainerType.DRESSER,   0.58, -0.40],
				[WorldContainer.ContainerType.FRIDGE,   -0.58,  0.28],
			]
		BuildingData.Archetype.DUPLEX:
			to_place = [
				[WorldContainer.ContainerType.NIGHTSTAND, 0.42, -0.40],
				[WorldContainer.ContainerType.NIGHTSTAND, 0.42,  0.40],
				[WorldContainer.ContainerType.DRESSER,    0.60, -0.42],
				[WorldContainer.ContainerType.DRESSER,    0.60,  0.42],
				[WorldContainer.ContainerType.FRIDGE,    -0.44, -0.28],
				[WorldContainer.ContainerType.FRIDGE,    -0.44,  0.28],
			]
		BuildingData.Archetype.PHARMACY:
			to_place = [
				[WorldContainer.ContainerType.MEDICINE_CABINET, 0.55, -0.28],
				[WorldContainer.ContainerType.MEDICINE_CABINET, 0.55,  0.28],
			]
		BuildingData.Archetype.OFFICE:
			to_place = [
				[WorldContainer.ContainerType.FILING_CABINET, 0.70, -0.10],
				[WorldContainer.ContainerType.FILING_CABINET, 0.70,  0.16],
			]
		BuildingData.Archetype.WAREHOUSE:
			to_place = [
				[WorldContainer.ContainerType.LOCKER, 0.72,  0.36],
				[WorldContainer.ContainerType.LOCKER, 0.72, -0.36],
			]
		BuildingData.Archetype.GARAGE:
			to_place = [[WorldContainer.ContainerType.LOCKER, 0.70,  0.42]]
		BuildingData.Archetype.CONVENIENCE_STORE:
			to_place = [[WorldContainer.ContainerType.LOCKER, 0.18,  0.62]]
		BuildingData.Archetype.HARDWARE_STORE:
			to_place = [[WorldContainer.ContainerType.LOCKER, 0.68,  0.50]]
		BuildingData.Archetype.STORAGE_YARD:
			to_place = [[WorldContainer.ContainerType.LOCKER, 0.76,  0.28]]
		BuildingData.Archetype.RESTAURANT:
			to_place = [[WorldContainer.ContainerType.FRIDGE, 0.78, -0.30]]

	# Visual specs per container type: [sn, se, h, top_color, side_color]
	# sn/se are half-extents in nv/ev fractions; h is box height in pixels.
	var CONTAINER_VIS := {
		WorldContainer.ContainerType.NIGHTSTAND:
			[0.28, 0.40,  9.0, _FWS, _FWD],
		WorldContainer.ContainerType.WARDROBE:
			[0.40, 1.12, 22.0, _FWD, _FWD.darkened(0.20)],
		WorldContainer.ContainerType.DRESSER:
			[0.32, 0.80, 14.0, _FWS, _FWD],
		WorldContainer.ContainerType.MEDICINE_CABINET:
			[0.24, 0.48, 12.0, Color(0.84, 0.88, 0.84), Color(0.68, 0.74, 0.68)],
		WorldContainer.ContainerType.FILING_CABINET:
			[0.32, 0.44, 14.0, _FFB.lightened(0.08), _FFB],
		WorldContainer.ContainerType.LOCKER:
			[0.28, 0.40, 32.0, Color(0.26, 0.30, 0.26), Color(0.20, 0.24, 0.20)],
		# FRIDGE is handled separately below — uses sprite sheet instead of _fb().
	}

	for entry: Array in to_place:
		var ct: int    = entry[0]
		var nf: float  = entry[1]
		var ef: float  = entry[2]

		var local_c:  Vector2
		var world_pos: Vector2

		if ct == WorldContainer.ContainerType.FRIDGE:
			# FRIDGE — wall-aware placement: pick best corner tile, orient to wall.
			var picked   := _worldgen_pick_wall_tile(fc, nv, ev, nf, ef)
			nf = picked[0];  ef = picked[1]
			var picked_mc: Vector2i = picked[2]
			local_c   = fc + nv * nf + ev * ef
			world_pos = to_global(local_c)
			_place_fridge_sprite_worldgen(local_c, picked_mc, nv, ev)
		else:
			# All other containers — standard tile snap.
			if _tilemap_ref != null:
				var snapped := _snap_to_tile(fc, nv, ev, nf, ef)
				nf = snapped[0];  ef = snapped[1]
			local_c   = fc + nv * nf + ev * ef
			world_pos = to_global(local_c)
			if CONTAINER_VIS.has(ct):
				var vis: Array = CONTAINER_VIS[ct]
				# Map container type to sprite sheet constants.
				var _sp := _container_sprite_params(ct)
				if _sp.size() > 0:
					_place_sprite_generic(
						"FurnitureInstance_Container",
						local_c, nv, ev, nf, ef,
						_sp[0], _sp[1], _sp[2], _sp[3], _sp[4], _sp[5],
						vis[0], vis[1], vis[2], vis[3], vis[4])
				else:
					_fb(fc, nv, ev, nf, ef, vis[0], vis[1], vis[2], vis[3], vis[4])

		var c := WorldContainer.new()
		c.container_type = ct
		c.zone_type      = bd.zone_type
		# Unique seed per container position + type.
		c.loot_seed = (bd.tile_rect.position.x * 7919 + bd.tile_rect.position.y * 1009
					   + ct * 97 + int(nf * 1000) * 13 + int(ef * 1000) * 31)
		c.position  = world_pos

		# Small interaction circle (24px radius).
		var shape   := CircleShape2D.new()
		shape.radius = 24.0
		var cshape  := CollisionShape2D.new()
		cshape.shape = shape
		c.add_child(cshape)

		get_parent().add_child(c)
