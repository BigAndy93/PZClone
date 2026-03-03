## FurnitureLibrary — canonical list of every unique furniture spec used by
## ProceduralBuilding across all 12 archetypes.
##
## Box spec format:  [sn, se, h, top_c, side_c]
##               OR  [sn, se, h, top_c, side_c, [rot0, rot1, ...]]
## If a rots array is provided (element 5), FurnitureBaker pre-bakes all listed rotations.
## Directional pieces (counters, shelves, racks) include [0, 1] so both E-W and N-S
## orientations are available without runtime pixel rotation (no distortion).
##
## Flat spec format: [sn, se, col]
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
		[0.88, 1.04,  5.0, FMT,                 FMS                 ],  # small bed
		[0.28, 0.36,  6.0, FWS,                 FWD                 ],  # side table
		[0.48, 0.56,  8.0, FWS,                 FWD                 ],  # small table
		[0.36, 0.40,  9.0, FWD,                 FWD.darkened(0.18)  ],  # small chair
		# ── medium_house ────────────────────────────────────────────────────────
		[0.72, 0.88,  5.0, FMT,                 FMS                 ],  # medium bed
		[0.40, 1.76,  9.0, FSF,                 FSF.darkened(0.25), [0, 1]],  # long sofa
		[0.56, 0.72,  8.0, FWS,                 FWD                 ],  # medium table
		[0.28, 0.96, 14.0, FSH,                 FSH.darkened(0.20), [0, 1]],  # bookshelf
		# ── farmhouse ───────────────────────────────────────────────────────────
		[0.48, 0.64,  8.0, FWS,                 FWD                 ],  # kitchen table
		[0.48, 0.56, 10.0, FAP.lightened(0.08), FAP                 ],  # stove
		[0.36, 0.40,  9.0, FWD,                 FWD.darkened(0.18)  ],  # chair (farmhouse)
		# ── duplex ──────────────────────────────────────────────────────────────
		[0.64, 0.72,  5.0, FMT,                 FMS                 ],  # duplex bed
		[0.40, 1.40,  9.0, FSF,                 FSF.darkened(0.25), [0, 1]],  # short sofa
		# ── convenience_store ───────────────────────────────────────────────────
		[2.00, 0.36, 14.0, FSH,                 FSH.darkened(0.22), [0, 1]],  # shelf aisle
		[0.48, 2.20, 10.0, FCT,                 FCS,                [0, 1]],  # service counter
		# ── pharmacy ────────────────────────────────────────────────────────────
		[0.44, 2.00, 10.0, FCT,                 FCS,                [0, 1]],  # pharmacy counter
		[0.24, 2.00, 18.0, FFB,                 FFB.lightened(0.10),[0, 1]],  # back wall cabinet
		[0.32, 1.28, 16.0, FSH,                 FSH.darkened(0.20), [0, 1]],  # pharmacy shelving
		[0.32, 0.36,  9.0, FWS,                 FWD                 ],  # waiting chair
		# ── restaurant ──────────────────────────────────────────────────────────
		[0.40, 2.60, 10.0, FAP.lightened(0.08), FAP,                [0, 1]],  # kitchen counter
		[0.44, 0.52,  8.0, FWS,                 FWD                 ],  # dining table
		# ── office ──────────────────────────────────────────────────────────────
		[0.56, 0.96,  8.0, FWS,                 FWD,                [0, 1]],  # desk
		[0.36, 0.48, 14.0, FFB.lightened(0.08), FFB,                [0, 1]],  # filing cabinet
		# ── hardware_store ───────────────────────────────────────────────────────
		[2.08, 0.40, 18.0, FSH,                 FSH.darkened(0.24), [0, 1]],  # rack
		[0.72, 1.68,  8.0, FPL,                 FPL.darkened(0.20)  ],  # pallet stack
		[0.40, 2.08, 10.0, FCT,                 FCS,                [0, 1]],  # hardware counter
		# ── warehouse ────────────────────────────────────────────────────────────
		[0.72, 0.72, 10.0, FPL,                 FPL.darkened(0.22)  ],  # warehouse pallet
		[0.32, 2.40, 20.0, FSH,                 FSH.darkened(0.26), [0, 1]],  # big shelving (also storage_yard)
		# ── garage ───────────────────────────────────────────────────────────────
		[0.36, 2.24, 10.0, FWD,                 FWD.darkened(0.20), [0, 1]],  # workbench
		[1.20, 0.24, 16.0, FFB.lightened(0.10), FFB,                [0, 1]],  # tool rack
		[0.36, 0.40, 12.0, FAP,                 FAP.darkened(0.20)  ],  # barrel cluster
		# ── storage_yard ─────────────────────────────────────────────────────────
		[0.64, 0.88, 12.0, FPL,                 FPL.darkened(0.22), [0, 1]],  # storage pallet
		# ── residential additions ────────────────────────────────────────────────────────
		[0.24, 0.88, 18.0, FWD,                 FWD.darkened(0.18), [0, 1]],  # wardrobe
		[0.28, 0.60, 12.0, FWD,                 FWD.darkened(0.20), [0, 1]],  # dresser
		[0.28, 0.88,  9.0, FSF,                 FSF.darkened(0.25), [0, 1]],  # compact sofa
		[0.16, 0.72,  4.0, FWS,                 FWD,                [0, 1]],  # coffee table (wide)
		[0.16, 0.40,  4.0, FWS,                 FWD                 ],  # coffee table (narrow)
		[0.40, 1.12, 22.0, FWD,                 FWD.darkened(0.18), [0, 1]],  # wardrobe (medium_house NW)
		[0.36, 0.80,  9.0, FSF,                 FSF.darkened(0.25), [0, 1]],  # sofa (small_house / duplex)
		[0.24, 0.56,  9.0, FWS,                 FWD,                [0, 1]],  # small desk (medium_house NE)
		[0.28, 0.40, 12.0, FWD,                 FWD.darkened(0.20)  ],  # dresser narrow (duplex)
	]


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
