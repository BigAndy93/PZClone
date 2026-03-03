## FurnitureViewer.gd — @tool Node2D
## Previews every procedural furniture piece and any sprite-sheet assets.
##
## Usage:
##   Open tools/FurnitureViewer.tscn in the editor OR run it directly as a game scene
##   (launch "Furniture Viewer" from the preview panel).
##   Adjust @export vars in the Inspector — preview updates live.
##   Tick "Refresh" to force a redraw at any time.

@tool
class_name FurnitureViewer
extends Node2D

# ── Layout ─────────────────────────────────────────────────────────────────────
const COLS   := 5
const CELL_W := 210.0
const CELL_H := 175.0

# Reference isometric axes for a 4×4-tile building footprint (matches FurnitureBaker).
const TILE_W  := 64.0
const TILE_H  := 32.0
const REF_NV  := Vector2(0.0,   -64.0)
const REF_EV  := Vector2(128.0,   0.0)

# ── Colour palette (mirrors ProceduralBuilding.gd) ─────────────────────────────
const _FWD := Color(0.46, 0.34, 0.20)
const _FWS := Color(0.58, 0.46, 0.28)
const _FMT := Color(0.64, 0.60, 0.54)
const _FMS := Color(0.52, 0.48, 0.42)
const _FSF := Color(0.30, 0.25, 0.36)
const _FSH := Color(0.34, 0.26, 0.16)
const _FFB := Color(0.22, 0.20, 0.18)
const _FCT := Color(0.44, 0.38, 0.28)
const _FCS := Color(0.32, 0.26, 0.18)
const _FAP := Color(0.26, 0.28, 0.30)
const _FPL := Color(0.44, 0.40, 0.30)
const _FRG := Color(0.38, 0.22, 0.14)

# ── Furniture definition tables ─────────────────────────────────────────────────
# Built in _ready() because GDScript const arrays cannot contain method-call results
# (.darkened() / .lightened() are not constant expressions).
#
# BOX_DEFS  entries: [label, sn, se, h, top_color, side_color]
# FLAT_DEFS entries: [label, sn, se, color]

var _box_defs:  Array = []
var _flat_defs: Array = []

# ── Inspector controls ──────────────────────────────────────────────────────────
@export var refresh: bool = false:
	set(_v):
		refresh = false
		queue_redraw()

@export_range(0.5, 2.5, 0.25) var preview_scale: float = 1.0:
	set(v): preview_scale = v; queue_redraw()

@export var show_floor_diamond: bool = true:
	set(v): show_floor_diamond = v; queue_redraw()

@export var show_grid_borders: bool = true:
	set(v): show_grid_borders = v; queue_redraw()

@export var show_contact_shadow: bool = true:
	set(v): show_contact_shadow = v; queue_redraw()

@export var show_dimensions: bool = false:
	set(v): show_dimensions = v; queue_redraw()

## Rotation preview (0–3, 90° CW increments).
## Mirrors FurnitureBaker's rot axis-permutation so the viewer shows exactly
## what will be baked into each pre-rotated texture.
##   0 = standard  1 = 90° CW  2 = 180°  3 = 270° CW
@export_range(0, 3, 1) var preview_rot: int = 0:
	set(v): preview_rot = clampi(v, 0, 3); queue_redraw()

@export_group("Sprite Sheet Preview")

@export var show_sprite_sheet: bool = false:
	set(v): show_sprite_sheet = v; queue_redraw()

@export_file("*.png", "*.webp") var sprite_sheet_path: String = \
		"res://assets/furniture/fridge_sheet.png":
	set(v): sprite_sheet_path = v; queue_redraw()

## Pixel size of ONE cell (sheet_total_width / sheet_cols, sheet_total_height / sheet_rows).
@export var sheet_cell_w: int = 660:
	set(v): sheet_cell_w = maxi(v, 1); queue_redraw()

@export var sheet_cell_h: int = 440:
	set(v): sheet_cell_h = maxi(v, 1); queue_redraw()

@export var sheet_cols: int = 2:
	set(v): sheet_cols = maxi(v, 1); queue_redraw()

@export var sheet_rows: int = 2:
	set(v): sheet_rows = maxi(v, 1); queue_redraw()

@export_range(0.02, 0.50, 0.01) var sheet_preview_scale: float = 0.15:
	set(v): sheet_preview_scale = v; queue_redraw()

## Labels for each cell, left-to-right then top-to-bottom.
@export var sheet_cell_labels: PackedStringArray = ["South", "East", "North", "West"]:
	set(v): sheet_cell_labels = v; queue_redraw()

## The pixel within each cell that corresponds to the floor-contact point (red crosshair).
@export var sheet_pivot_x: float = 330.0:
	set(v): sheet_pivot_x = v; queue_redraw()

@export var sheet_pivot_y: float = 340.0:
	set(v): sheet_pivot_y = v; queue_redraw()

@export var show_pivot_crosshair: bool = true:
	set(v): show_pivot_crosshair = v; queue_redraw()


# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_defs()
	queue_redraw()


func _build_defs() -> void:
	_box_defs = [
		# [label,               sn,    se,    h,    top_color,                      side_color                    ]
		["Bed",              0.22,  0.30,   5.0, _FMT,                            _FMS                           ],
		["Nightstand",       0.07,  0.10,   9.0, _FWS,                            _FWD                           ],
		["Wardrobe",         0.10,  0.28,  22.0, _FWD,                            _FWD.darkened(0.20)            ],
		["Dresser",          0.08,  0.20,  14.0, _FWS,                            _FWD                           ],
		["Sofa",             0.10,  0.22,   9.0, _FSF,                            _FSF.darkened(0.25)            ],
		["Coffee Table",     0.04,  0.10,   4.0, _FWS,                            _FWD                           ],
		["Dining Table",     0.14,  0.18,   8.0, _FWS,                            _FWD                           ],
		["Chair",            0.10,  0.12,   9.0, _FWD,                            _FWD.darkened(0.18)            ],
		["Shelf (low)",      0.50,  0.09,  14.0, _FSH,                            _FSH.darkened(0.22)            ],
		["Shelf (tall)",     0.50,  0.09,  18.0, _FSH,                            _FSH.darkened(0.22)            ],
		["Counter",          0.10,  0.55,  10.0, _FCT,                            _FCS                           ],
		["Back Wall",        0.06,  0.50,  18.0, _FFB,                            _FFB.lightened(0.10)           ],
		["Kitchen Counter",  0.10,  0.65,  10.0, _FAP.lightened(0.08),           _FAP                           ],
		["Stove",            0.12,  0.14,  10.0, _FAP.lightened(0.08),           _FAP                           ],
		["Medicine Cabinet", 0.06,  0.12,  12.0, Color(0.84, 0.88, 0.84),        Color(0.68, 0.74, 0.68)        ],
		["Filing Cabinet",   0.08,  0.11,  14.0, _FFB.lightened(0.08),           _FFB                           ],
		["Locker",           0.07,  0.10,  20.0, Color(0.26, 0.30, 0.26),        Color(0.20, 0.24, 0.20)        ],
		["Fridge",           0.09,  0.12,  22.0, Color(0.84, 0.90, 0.92),        Color(0.66, 0.76, 0.80)        ],
		["Pallet",           0.18,  0.18,  10.0, _FPL,                            _FPL.darkened(0.22)            ],
		["Workbench",        0.09,  0.56,  10.0, _FWD,                            _FWD.darkened(0.20)            ],
		["Tool Rack",        0.30,  0.06,  16.0, _FFB.lightened(0.10),           _FFB                           ],
		["Barrel Cluster",   0.09,  0.10,  12.0, _FAP,                            _FAP.darkened(0.20)            ],
	]
	_flat_defs = [
		# [label,             sn,    se,   color                                   ]
		["Rug (room)",     0.35,  0.45,  Color(_FRG, 0.65)                        ],
		["Rug (table)",    0.13,  0.16,  Color(_FRG, 0.55)                        ],
		["Car Pit",        0.36,  0.46,  Color(0.10, 0.10, 0.10, 0.50)           ],
		["Forklift Path",  0.26,  0.16,  Color(0.08, 0.08, 0.08, 0.35)           ],
	]


# ── Drawing ────────────────────────────────────────────────────────────────────

func _draw() -> void:
	if _box_defs.is_empty():
		return   # _ready() not yet called (shouldn't happen, but guard anyway)

	var sc := preview_scale
	var nv := REF_NV * sc
	var ev := REF_EV * sc

	var total := _box_defs.size() + _flat_defs.size()
	var rows  := int(ceil(float(total) / COLS))

	# Background
	draw_rect(Rect2(Vector2.ZERO, Vector2(COLS * CELL_W * sc, rows * CELL_H * sc)),
		Color(0.07, 0.07, 0.09))

	# Header
	var rot_names := ["rot 0 — standard", "rot 1 — 90° CW", "rot 2 — 180°", "rot 3 — 270° CW"]
	draw_string(ThemeDB.fallback_font, Vector2(4.0, 14.0),
		"Procedural Furniture  (scale %.2f ×  %d pieces  %s)" \
			% [sc, _box_defs.size() + _flat_defs.size(), rot_names[preview_rot]],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.80, 0.60))

	# ── Box furniture ───────────────────────────────────────────────────────────
	for idx in _box_defs.size():
		var def: Array = _box_defs[idx]
		var col_i := idx % COLS
		var row_i := idx / COLS
		var origin := Vector2(col_i * CELL_W * sc, row_i * CELL_H * sc)
		var c      := origin + Vector2(CELL_W * 0.5, CELL_H * 0.58) * sc

		_draw_cell_bg(origin, sc)
		_draw_box(c, nv, ev,
			def[1], def[2], def[3] * sc,
			def[4] as Color, def[5] as Color, preview_rot)
		_draw_cell_label(origin, sc, def[0] as String,
			_dim_str(def[1], def[2], def[3]) if show_dimensions else "")

	# ── Flat furniture ──────────────────────────────────────────────────────────
	var offset := _box_defs.size()
	for idx in _flat_defs.size():
		var def: Array = _flat_defs[idx]
		var gidx  := offset + idx
		var col_i := gidx % COLS
		var row_i := gidx / COLS
		var origin := Vector2(col_i * CELL_W * sc, row_i * CELL_H * sc)
		var c      := origin + Vector2(CELL_W * 0.5, CELL_H * 0.58) * sc
		var dn     := nv * (def[1] as float)
		var de     := ev * (def[2] as float)

		_draw_cell_bg(origin, sc)
		draw_colored_polygon(PackedVector2Array([c + dn, c + de, c - dn, c - de]),
			def[3] as Color)
		_draw_cell_label(origin, sc, def[0] as String,
			"flat  sn=%.2f  se=%.2f" % [def[1], def[2]] if show_dimensions else "")

	# ── Sprite sheet preview ────────────────────────────────────────────────────
	if show_sprite_sheet:
		_draw_sprite_sheet_section(Vector2(0.0, rows * CELL_H * sc + 16.0))


## Draws one furniture box.  rot (0–3) applies the same axis permutation as
## FurnitureBaker, so the viewer matches what is actually baked.
func _draw_box(c: Vector2, nv: Vector2, ev: Vector2,
		sn: float, se: float, h: float, top_c: Color, side_c: Color,
		rot: int = 0) -> void:
	# ── Apply rotation (same permutation as FurnitureBaker._bake_box_into) ──
	var dn: Vector2
	var de: Vector2
	match rot:
		1:   # 90° CW
			dn = ev * sn
			de = Vector2(0.0, -REF_NV.y) * preview_scale * se
		2:   # 180°
			dn = -nv * sn
			de = -ev * se
		3:   # 270° CW
			dn = -ev * sn
			de = Vector2(0.0, REF_NV.y) * preview_scale * se
		_:   # rot=0 — standard
			dn = nv * sn
			de = ev * se

	var gN := c + dn;    var gE := c + de
	var gS := c - dn;    var gW := c - de
	var up  := Vector2(0.0, -h)

	# Outline colour — mirrors baker's deep-navy tint
	var outline_col := side_c.lerp(Color(0.10, 0.11, 0.16), 0.55).darkened(0.35)
	outline_col.a   = 0.85

	if show_contact_shadow:
		var sh_pts := PackedVector2Array()
		var sh_rh  := de.length() * 0.55
		var sh_rv  := dn.length() * 0.28
		for i in 10:
			var a := TAU * float(i) / 10.0
			sh_pts.append(c + Vector2(2.0, 4.0) + Vector2(cos(a) * sh_rh, sin(a) * sh_rv))
		draw_colored_polygon(sh_pts, Color(0.04, 0.06, 0.10, 0.22))

	if show_floor_diamond:
		draw_colored_polygon(PackedVector2Array([gN, gE, gS, gW]),
			Color(top_c.r, top_c.g, top_c.b, 0.10))

	# W face — lit baseline
	draw_colored_polygon(PackedVector2Array([gW, gS, gS + up, gW + up]), side_c)
	draw_polyline(PackedVector2Array([gW, gS, gS + up, gW + up, gW]),
		outline_col, 1.2)

	# E face — cool-shadow dark (~30% separation, matches hand-drawn sprites)
	draw_colored_polygon(PackedVector2Array([gE, gS, gS + up, gE + up]),
		side_c.lerp(Color(0.32, 0.36, 0.50), 0.20).darkened(0.28))
	draw_polyline(PackedVector2Array([gE, gS, gS + up, gE + up, gE]),
		outline_col, 1.2)

	# Top face — warm, brightened
	var lit_top := top_c.lerp(Color(0.92, 0.82, 0.52), 0.06).lightened(0.15)
	draw_colored_polygon(PackedVector2Array([gN + up, gE + up, gS + up, gW + up]), lit_top)
	# Top outline
	var top_ol := top_c.lerp(Color(0.32, 0.36, 0.50), 0.40).darkened(0.25)
	top_ol.a = 0.70
	draw_polyline(PackedVector2Array([gN + up, gE + up, gS + up, gW + up, gN + up]),
		top_ol, 1.0)

	# Rim highlights (NW/NE edges + SW bevel)
	draw_line(gN + up, gW + up, top_c.lerp(Color(0.92, 0.82, 0.52), 0.10).lightened(0.28), 1.0)
	draw_line(gN + up, gE + up, top_c.lerp(Color(0.92, 0.82, 0.52), 0.06).lightened(0.18), 1.0)
	draw_line(gS + up, gW + up, top_c.lerp(Color(0.92, 0.82, 0.52), 0.08).lightened(0.24), 1.0)


func _draw_cell_bg(origin: Vector2, sc: float) -> void:
	if show_grid_borders:
		draw_rect(Rect2(origin + Vector2(1, 1),
				Vector2(CELL_W * sc - 2.0, CELL_H * sc - 2.0)),
			Color(0.22, 0.22, 0.26), false, 1.0)


func _draw_cell_label(origin: Vector2, sc: float,
		name_str: String, dim_str: String) -> void:
	var cw := CELL_W * sc
	var ch := CELL_H * sc
	draw_string(ThemeDB.fallback_font,
		origin + Vector2(4.0, ch - 18.0),
		name_str, HORIZONTAL_ALIGNMENT_LEFT, cw - 8.0, 10,
		Color(0.85, 0.85, 0.72))
	if dim_str != "":
		draw_string(ThemeDB.fallback_font,
			origin + Vector2(4.0, ch - 6.0),
			dim_str, HORIZONTAL_ALIGNMENT_LEFT, cw - 8.0, 8,
			Color(0.55, 0.70, 0.85, 0.80))


func _dim_str(sn: float, se: float, h: float) -> String:
	return "sn=%.2f  se=%.2f  h=%.0f" % [sn, se, h]


func _draw_sprite_sheet_section(origin: Vector2) -> void:
	var sheet: Texture2D = null
	if sprite_sheet_path != "" and ResourceLoader.exists(sprite_sheet_path):
		sheet = ResourceLoader.load(sprite_sheet_path)

	var cw     := sheet_cell_w * sheet_preview_scale
	var ch     := sheet_cell_h * sheet_preview_scale
	var pad    := 8.0
	var hdr_h  := 22.0
	var total_w := pad + sheet_cols * (cw + pad)
	var total_h := hdr_h + pad + sheet_rows * (ch + pad)

	draw_rect(Rect2(origin, Vector2(total_w, total_h)), Color(0.06, 0.06, 0.08))

	var hdr_col := Color(0.55, 0.90, 0.55) if sheet != null else Color(0.90, 0.55, 0.28)
	var status  := "LOADED" if sheet != null else \
		"not found — save to:  " + sprite_sheet_path
	draw_string(ThemeDB.fallback_font, origin + Vector2(6.0, 15.0),
		"Sprite Sheet — " + status,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, hdr_col)

	for row in sheet_rows:
		for col_i in sheet_cols:
			var flat_idx  := row * sheet_cols + col_i
			var cell_orig := origin + Vector2(
				pad + col_i * (cw + pad),
				hdr_h + pad + row * (ch + pad))

			if sheet != null:
				var atlas     := AtlasTexture.new()
				atlas.atlas   = sheet
				atlas.region  = Rect2(
					col_i * sheet_cell_w, row * sheet_cell_h,
					sheet_cell_w,         sheet_cell_h)
				draw_texture_rect(atlas, Rect2(cell_orig, Vector2(cw, ch)), false)
			else:
				draw_rect(Rect2(cell_orig, Vector2(cw, ch)), Color(0.12, 0.12, 0.16))
				draw_line(cell_orig, cell_orig + Vector2(cw, ch),
					Color(0.40, 0.20, 0.20, 0.50), 1.0)
				draw_line(cell_orig + Vector2(cw, 0), cell_orig + Vector2(0, ch),
					Color(0.40, 0.20, 0.20, 0.50), 1.0)

			draw_rect(Rect2(cell_orig, Vector2(cw, ch)),
				Color(0.42, 0.42, 0.55), false, 1.0)

			if show_pivot_crosshair:
				var px  := cell_orig + Vector2(
					sheet_pivot_x * sheet_preview_scale,
					sheet_pivot_y * sheet_preview_scale)
				var arm := 6.0
				draw_line(px - Vector2(arm, 0), px + Vector2(arm, 0),
					Color(1.0, 0.30, 0.30, 0.90), 1.5)
				draw_line(px - Vector2(0, arm), px + Vector2(0, arm),
					Color(1.0, 0.30, 0.30, 0.90), 1.5)
				draw_circle(px, 2.0, Color(1.0, 0.30, 0.30, 0.90))

			var lbl := ""
			if flat_idx < sheet_cell_labels.size():
				lbl = sheet_cell_labels[flat_idx]
			if lbl == "":
				lbl = "col=%d  row=%d" % [col_i, row]
			draw_string(ThemeDB.fallback_font,
				cell_orig + Vector2(4.0, ch - 5.0),
				lbl, HORIZONTAL_ALIGNMENT_LEFT, cw - 8.0, 9,
				Color(1.0, 1.0, 0.55, 0.95))
