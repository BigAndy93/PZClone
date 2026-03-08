## FurnitureLibrary — canonical list of every unique furniture spec used by
## ProceduralBuilding across all 12 archetypes.
##
## Box spec format: Dictionary with keys:
##   sn       float   — north half-extent scale
##   se       float   — east  half-extent scale
##   h        float   — height in screen pixels
##   top_c    Color   — top face colour
##   side_c   Color   — side face colour
##   rots     Array   — (optional) rotations to pre-bake, default [0]
##   type     String  — (optional) per-type bake function key, default "generic"
##
## Flat spec format still uses Array [sn, se, col] for backward compatibility.
##
## Color constants mirror ProceduralBuilding's _F** palette (art bible §2.1).
## FurnitureBaker.warm_batch() uses these to pre-bake all textures before map gen.

extends Node

static func get_box_specs() -> Array:
	var FWD := Color(0.46, 0.34, 0.20)   # wood dark
	var FWS := Color(0.58, 0.46, 0.28)   # wood soft
	var FMT := Color(0.64, 0.60, 0.54)   # mattress top
	var FMS := Color(0.52, 0.48, 0.42)   # mattress side
	var FSF := Color(0.30, 0.25, 0.36)   # sofa fabric
	var FSH := Color(0.34, 0.26, 0.16)   # shelf board
	var FFB := Color(0.22, 0.20, 0.18)   # dark appliance / filing
	var FCT := Color(0.44, 0.38, 0.28)   # counter top
	var FCS := Color(0.32, 0.26, 0.18)   # counter side
	var FAP := Color(0.26, 0.28, 0.30)   # appliance grey
	var FPL := Color(0.44, 0.40, 0.30)   # pallet
	return [
		# ── small_house ─────────────────────────────────────────────────────────
		{"sn":0.88, "se":1.04, "h": 5.0, "top_c":FMT,                  "side_c":FMS,                  "type":"bed"     },  # small bed
		{"sn":0.28, "se":0.36, "h": 6.0, "top_c":FWS,                  "side_c":FWD,                  "type":"generic" },  # side table
		{"sn":0.48, "se":0.56, "h": 8.0, "top_c":FWS,                  "side_c":FWD,                  "type":"table"   },  # small table
		{"sn":0.36, "se":0.40, "h": 9.0, "top_c":FWD,                  "side_c":FWD.darkened(0.18),   "type":"chair"   },  # small chair
		# ── medium_house ────────────────────────────────────────────────────────
		{"sn":0.72, "se":0.88, "h": 5.0, "top_c":FMT,                  "side_c":FMS,                  "type":"bed",      "rots":[0]   },  # medium bed
		{"sn":0.40, "se":1.76, "h": 9.0, "top_c":FSF,                  "side_c":FSF.darkened(0.25),   "type":"sofa",     "rots":[0,1] },  # long sofa
		{"sn":0.56, "se":0.72, "h": 8.0, "top_c":FWS,                  "side_c":FWD,                  "type":"table"   },  # medium table
		{"sn":0.28, "se":0.96, "h":14.0, "top_c":FSH,                  "side_c":FSH.darkened(0.20),   "type":"shelf",    "rots":[0,1] },  # bookshelf
		# ── farmhouse ───────────────────────────────────────────────────────────
		{"sn":0.48, "se":0.64, "h": 8.0, "top_c":FWS,                  "side_c":FWD,                  "type":"table"   },  # kitchen table
		{"sn":0.48, "se":0.56, "h":10.0, "top_c":FAP.lightened(0.08),  "side_c":FAP,                  "type":"stove"   },  # stove
		{"sn":0.36, "se":0.40, "h": 9.0, "top_c":FWD,                  "side_c":FWD.darkened(0.18),   "type":"chair"   },  # chair (farmhouse)
		# ── duplex ──────────────────────────────────────────────────────────────
		{"sn":0.64, "se":0.72, "h": 5.0, "top_c":FMT,                  "side_c":FMS,                  "type":"bed"     },  # duplex bed
		{"sn":0.40, "se":1.40, "h": 9.0, "top_c":FSF,                  "side_c":FSF.darkened(0.25),   "type":"sofa",     "rots":[0,1] },  # short sofa
		# ── convenience_store ───────────────────────────────────────────────────
		{"sn":2.00, "se":0.36, "h":14.0, "top_c":FSH,                  "side_c":FSH.darkened(0.22),   "type":"shelf",    "rots":[0,1] },  # shelf aisle
		{"sn":0.48, "se":2.20, "h":10.0, "top_c":FCT,                  "side_c":FCS,                  "type":"counter",  "rots":[0,1] },  # service counter
		# ── pharmacy ────────────────────────────────────────────────────────────
		{"sn":0.44, "se":2.00, "h":10.0, "top_c":FCT,                  "side_c":FCS,                  "type":"counter",  "rots":[0,1] },  # pharmacy counter
		{"sn":0.24, "se":2.00, "h":18.0, "top_c":FFB,                  "side_c":FFB.lightened(0.10),  "type":"shelf",    "rots":[0,1] },  # back wall cabinet
		{"sn":0.32, "se":1.28, "h":16.0, "top_c":FSH,                  "side_c":FSH.darkened(0.20),   "type":"shelf",    "rots":[0,1] },  # pharmacy shelving
		{"sn":0.32, "se":0.36, "h": 9.0, "top_c":FWS,                  "side_c":FWD,                  "type":"chair"   },  # waiting chair
		# ── restaurant ──────────────────────────────────────────────────────────
		{"sn":0.40, "se":2.60, "h":10.0, "top_c":FAP.lightened(0.08),  "side_c":FAP,                  "type":"counter",  "rots":[0,1] },  # kitchen counter
		{"sn":0.44, "se":0.52, "h": 8.0, "top_c":FWS,                  "side_c":FWD,                  "type":"table"   },  # dining table
		# ── office ──────────────────────────────────────────────────────────────
		{"sn":0.56, "se":0.96, "h": 8.0, "top_c":FWS,                  "side_c":FWD,                  "type":"table",    "rots":[0,1] },  # desk
		{"sn":0.36, "se":0.48, "h":14.0, "top_c":FFB.lightened(0.08),  "side_c":FFB,                  "type":"filing",   "rots":[0,1] },  # filing cabinet
		# ── hardware_store ───────────────────────────────────────────────────────
		{"sn":2.08, "se":0.40, "h":18.0, "top_c":FSH,                  "side_c":FSH.darkened(0.24),   "type":"shelf",    "rots":[0,1] },  # rack
		{"sn":0.72, "se":1.68, "h": 8.0, "top_c":FPL,                  "side_c":FPL.darkened(0.20),   "type":"pallet"  },  # pallet stack
		{"sn":0.40, "se":2.08, "h":10.0, "top_c":FCT,                  "side_c":FCS,                  "type":"counter",  "rots":[0,1] },  # hardware counter
		# ── warehouse ────────────────────────────────────────────────────────────
		{"sn":0.72, "se":0.72, "h":10.0, "top_c":FPL,                  "side_c":FPL.darkened(0.22),   "type":"pallet"  },  # warehouse pallet
		{"sn":0.32, "se":2.40, "h":20.0, "top_c":FSH,                  "side_c":FSH.darkened(0.26),   "type":"shelf",    "rots":[0,1] },  # big shelving (also storage_yard)
		# ── garage ───────────────────────────────────────────────────────────────
		{"sn":0.36, "se":2.24, "h":10.0, "top_c":FWD,                  "side_c":FWD.darkened(0.20),   "type":"counter",  "rots":[0,1] },  # workbench
		{"sn":1.20, "se":0.24, "h":16.0, "top_c":FFB.lightened(0.10),  "side_c":FFB,                  "type":"shelf",    "rots":[0,1] },  # tool rack
		{"sn":0.36, "se":0.40, "h":12.0, "top_c":FAP,                  "side_c":FAP.darkened(0.20),   "type":"generic" },  # barrel cluster
		# ── storage_yard ─────────────────────────────────────────────────────────
		{"sn":0.64, "se":0.88, "h":12.0, "top_c":FPL,                  "side_c":FPL.darkened(0.22),   "type":"pallet",   "rots":[0,1] },  # storage pallet
		# ── residential additions ────────────────────────────────────────────────────────
		{"sn":0.24, "se":0.88, "h":18.0, "top_c":FWD,                  "side_c":FWD.darkened(0.18),   "type":"wardrobe", "rots":[0,1] },  # wardrobe
		{"sn":0.28, "se":0.60, "h":12.0, "top_c":FWD,                  "side_c":FWD.darkened(0.20),   "type":"wardrobe", "rots":[0,1] },  # dresser
		{"sn":0.28, "se":0.88, "h": 9.0, "top_c":FSF,                  "side_c":FSF.darkened(0.25),   "type":"sofa",     "rots":[0,1] },  # compact sofa
		{"sn":0.16, "se":0.72, "h": 4.0, "top_c":FWS,                  "side_c":FWD,                  "type":"table",    "rots":[0,1] },  # coffee table (wide)
		{"sn":0.16, "se":0.40, "h": 4.0, "top_c":FWS,                  "side_c":FWD,                  "type":"table"   },  # coffee table (narrow)
		{"sn":0.40, "se":1.12, "h":22.0, "top_c":FWD,                  "side_c":FWD.darkened(0.18),   "type":"wardrobe", "rots":[0,1] },  # wardrobe (medium_house NW)
		{"sn":0.36, "se":0.80, "h": 9.0, "top_c":FSF,                  "side_c":FSF.darkened(0.25),   "type":"sofa",     "rots":[0,1] },  # sofa (small_house / duplex)
		{"sn":0.24, "se":0.56, "h": 9.0, "top_c":FWS,                  "side_c":FWD,                  "type":"table",    "rots":[0,1] },  # small desk (medium_house NE)
		{"sn":0.28, "se":0.40, "h":12.0, "top_c":FWD,                  "side_c":FWD.darkened(0.20),   "type":"wardrobe" },  # dresser narrow (duplex)
		# ── new appliances / bathroom ─────────────────────────────────────────────
		{"sn":0.44, "se":0.52, "h":18.0, "top_c":FAP,                  "side_c":FAP.darkened(0.15),   "type":"fridge",   "rots":[0,1] },  # fridge
		{"sn":0.28, "se":0.60, "h":12.0, "top_c":FWS,                  "side_c":FWD,                  "type":"dresser",  "rots":[0,1] },  # dresser (new type)
		{"sn":0.52, "se":1.04, "h": 6.0, "top_c":Color(0.72,0.74,0.76),"side_c":Color(0.58,0.60,0.62),"type":"bathtub",  "rots":[0,1] },  # bathtub
	]


## Returns the canonical box spec for a MapData FURN_* type at a given rotation (0-3).
## Used by BuildingTileRenderer to look up FurnitureBaker keys for spawning sprites.
## Returns an empty Dictionary if the type is unknown or FURN_NONE.
static func spec_for_furn(furn_type: int, rot: int = 0) -> Dictionary:
	var FWD := Color(0.46, 0.34, 0.20)
	var FWS := Color(0.58, 0.46, 0.28)
	var FMT := Color(0.64, 0.60, 0.54)
	var FMS := Color(0.52, 0.48, 0.42)
	var FSF := Color(0.30, 0.25, 0.36)
	var FSH := Color(0.34, 0.26, 0.16)
	var FFB := Color(0.22, 0.20, 0.18)
	var FCT := Color(0.44, 0.38, 0.28)
	var FCS := Color(0.32, 0.26, 0.18)
	var FAP := Color(0.26, 0.28, 0.30)
	match furn_type:
		MapData.FURN_BED:
			return {"sn":0.88, "se":1.04, "h": 5.0, "top_c":FMT, "side_c":FMS, "type":"bed",     "rot":rot}
		MapData.FURN_DESK:
			return {"sn":0.56, "se":0.96, "h": 8.0, "top_c":FWS, "side_c":FWD, "type":"table",   "rot":rot}
		MapData.FURN_CHAIR:
			return {"sn":0.36, "se":0.40, "h": 9.0, "top_c":FWD, "side_c":FWD.darkened(0.18), "type":"chair", "rot":rot}
		MapData.FURN_TABLE:
			return {"sn":0.48, "se":0.56, "h": 8.0, "top_c":FWS, "side_c":FWD, "type":"table",   "rot":rot}
		MapData.FURN_SOFA:
			return {"sn":0.40, "se":1.40, "h": 9.0, "top_c":FSF, "side_c":FSF.darkened(0.25), "type":"sofa", "rot":rot}
		MapData.FURN_SHELF:
			return {"sn":0.28, "se":0.96, "h":14.0, "top_c":FSH, "side_c":FSH.darkened(0.20), "type":"shelf", "rot":rot}
		MapData.FURN_COUNTER:
			return {"sn":0.48, "se":2.20, "h":10.0, "top_c":FCT, "side_c":FCS, "type":"counter", "rot":rot}
		MapData.FURN_STOVE:
			return {"sn":0.48, "se":0.56, "h":10.0, "top_c":FAP.lightened(0.08), "side_c":FAP, "type":"stove", "rot":rot}
		MapData.FURN_LOCKER:
			return {"sn":0.36, "se":0.48, "h":14.0, "top_c":FFB.lightened(0.08), "side_c":FFB, "type":"filing", "rot":rot}
		MapData.FURN_NIGHTSTAND:
			return {"sn":0.28, "se":0.36, "h": 6.0, "top_c":FWS, "side_c":FWD, "type":"generic", "rot":rot}
		MapData.FURN_FRIDGE:
			return {"sn":0.44, "se":0.52, "h":18.0, "top_c":FAP, "side_c":FAP.darkened(0.15), "type":"fridge", "rot":rot}
		MapData.FURN_DRESSER:
			return {"sn":0.28, "se":0.60, "h":12.0, "top_c":FWS, "side_c":FWD, "type":"dresser", "rot":rot}
		MapData.FURN_BATHTUB:
			return {"sn":0.52, "se":1.04, "h": 6.0, "top_c":Color(0.72,0.74,0.76), "side_c":Color(0.58,0.60,0.62), "type":"bathtub", "rot":rot}
	return {}


## Returns sprite-sheet furniture specs keyed by MapData.FURN_* type.
##
## SPRITE SHEET ROTATION STANDARD (all future sheets must follow this layout):
##
##   rot=0  NE-facing  → top-left  frame (col 0, row 0)
##   rot=1  SE-facing  → top-right frame (col 1, row 0)
##   rot=2  SW-facing  → bot-left  frame (col 0, row 1)
##   rot=3  NW-facing  → bot-right frame (col 1, row 1)
##
##   Placement mapping: N-wall → rot=0, E-wall → rot=1, S-wall → rot=2, W-wall → rot=3.
##
## Per-entry keys:
##   path        : String   — resource path to the PNG sprite sheet
##   frame_cols  : int      — columns in the sheet grid
##   frame_rows  : int      — rows in the sheet grid
##   rot_frames  : Dict     — rot (0-3) → Vector2i(col, row) in the sheet
##   anchor_frac : Vector2  — floor-contact point as fraction of frame size
##   scale       : float    — uniform display scale to fit game tiles
static func get_sprite_sheet_specs() -> Dictionary:
	return {
		MapData.FURN_COUCH: {
			"path":       "res://assets/furniture/couch_sheet.png",
			"frame_cols": 2,
			"frame_rows": 2,
			# Standard NE/SE/SW/NW layout:
			"rot_frames": {
				0: Vector2i(0, 0),   # NE-facing (N-wall placement)
				1: Vector2i(1, 0),   # SE-facing (E-wall placement)
				2: Vector2i(0, 1),   # SW-facing (S-wall placement)
				3: Vector2i(1, 1),   # NW-facing (W-wall placement)
			},
			# Pixel in each frame that aligns with the tile's isometric floor center.
			# (0.5 = horizontally centered, 0.82 = ~82% down the frame height)
			"anchor_frac": Vector2(0.50, 0.82),
			# Scale to match game tile size. Increase/decrease to resize the sprite.
			"scale": 0.20,
		},
	}


## Cached sheet textures — loaded once per path, reused across all buildings.
static var _sheet_tex_cache: Dictionary = {}

static func load_sheet_texture(path: String) -> Texture2D:
	if not _sheet_tex_cache.has(path):
		_sheet_tex_cache[path] = load(path)
	return _sheet_tex_cache[path]


static func get_flat_specs() -> Array:
	var FRG := Color(0.38, 0.22, 0.14)   # rug
	return [
		[1.40, 1.80, Color(FRG, 0.65)],  # large rug          (unused — kept for future)
		[0.88, 1.12, Color(FRG, 0.65)],  # bedroom rug        (small_house bedroom)
		[0.88, 1.12, Color(FRG, 0.55)],  # living rug         (small_house living)
		[0.64, 0.88, Color(FRG, 0.55)],  # medium dining rug  (medium_house)
		[0.52, 0.72, Color(FRG, 0.50)],  # table rug          (farmhouse)
		[0.52, 0.64, Color(FRG, 0.45)],  # dining rug         (restaurant)
		[1.04, 0.64, Color(0.08, 0.08, 0.08, 0.35)],  # forklift path (warehouse)
		[1.44, 1.84, Color(0.10, 0.10, 0.10, 0.50)],  # car pit       (garage)
	]
