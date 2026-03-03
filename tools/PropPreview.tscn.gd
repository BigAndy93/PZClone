## PropPreview.gd — @tool Node2D
## Shows every prop type and furniture archetype in a grid inside the editor.
##
## Usage:
##   1. Open (or create) any 2D scene.
##   2. Add a Node2D, attach this script.
##   3. The grid appears immediately in the editor viewport — no play required.
##   4. After adding a new PROP_* constant + WorldProp match case, re-run by
##      toggling the node's visible property or reopening the scene.
##
## The preview is read-only; edit WorldProp.gd / ProceduralBuilding.gd directly.

@tool
class_name PropPreview
extends Node2D

const CELL_W   := 130.0   # horizontal spacing between prop cells
const CELL_H   := 100.0   # vertical spacing
const COLS     := 5       # cells per row
const LABEL_DY := 32.0    # label offset below cell centre

## All known prop type names in MapData constant order (0, 1, 2 …).
const PROP_NAMES := [
	"TRASH_CAN",   # 0
	"DUMPSTER",    # 1
	"MAILBOX",     # 2
	"CAR",         # 3
	"LAMPPOST",    # 4
	"CRATE",       # 5
	"BARREL",      # 6
]


func _ready() -> void:
	_rebuild()


## Call this (or toggle visible) after adding new prop types.
func _rebuild() -> void:
	for ch in get_children():
		ch.queue_free()

	# ── Section header ──────────────────────────────────────────────────────
	_add_label("── World Props ──", Vector2(0.0, -40.0), 14, Color(0.9, 0.85, 0.6))

	# ── Prop grid ───────────────────────────────────────────────────────────
	for i in PROP_NAMES.size():
		var cell_ctr := _cell_pos(i)

		# WorldProp node — drives its own _draw() from prop_type + tile_pos.
		var wp       := WorldProp.new()
		wp.prop_type  = i
		wp.tile_pos   = Vector2i(i * 3, i * 7)   # deterministic tile hash input
		wp.position   = cell_ctr
		add_child(wp)

		# Name label below the prop.
		_add_label(PROP_NAMES[i], cell_ctr + Vector2(0.0, LABEL_DY), 11, Color(0.85, 0.85, 0.85))

	# ── Cell border dots ─────────────────────────────────────────────────────
	# (drawn in _draw — triggers automatically)
	queue_redraw()


func _draw() -> void:
	# Light grid lines to show cell boundaries.
	for i in PROP_NAMES.size():
		var c := _cell_pos(i)
		draw_rect(
			Rect2(c - Vector2(CELL_W * 0.5, CELL_H * 0.45), Vector2(CELL_W, CELL_H * 0.9)),
			Color(0.3, 0.3, 0.3, 0.4), false, 1.0)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _cell_pos(index: int) -> Vector2:
	var col := index % COLS
	var row := index / COLS
	return Vector2(col * CELL_W, row * CELL_H)


func _add_label(text: String, pos: Vector2, size: int, col: Color) -> void:
	var lbl          := Label.new()
	lbl.text          = text
	lbl.position      = pos + Vector2(-50.0, 0.0)   # rough centre offset
	lbl.custom_minimum_size = Vector2(100.0, 20.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var settings      := LabelSettings.new()
	settings.font_size = size
	settings.font_color = col
	lbl.label_settings = settings
	add_child(lbl)
