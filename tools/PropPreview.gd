## PropPreview.gd — @tool Node2D
## Shows every prop type in a grid inside the editor.
##
## Usage:
##   1. Open (or create) any 2D scene.
##   2. Add a Node2D, attach this script.
##   3. The grid appears immediately in the editor viewport.
##   4. After adding a new PROP_* constant + WorldProp match case:
##        - add the name to PROP_NAMES below
##        - tick the Refresh checkbox in the Inspector

@tool
class_name PropPreview
extends Node2D

const CELL_W   := 130.0
const CELL_H   := 100.0
const COLS     := 5
const LABEL_DY := 32.0

## All known prop type names in MapData constant order (0, 1, 2 …).
const PROP_NAMES := [
	"TRASH_CAN",      # 0
	"DUMPSTER",       # 1
	"MAILBOX",        # 2
	"CAR",            # 3
	"LAMPPOST",       # 4
	"CRATE",          # 5
	"BARREL",         # 6
	"FIRE_HYDRANT",   # 7
]


## Tick in the Inspector to rebuild without reopening the scene.
@export var refresh: bool = false:
	set(v):
		refresh = false
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	# queue_free all existing children, then defer the actual build so the
	# editor's scene-tree dock has a frame to flush the removals cleanly.
	for ch in get_children():
		ch.queue_free()
	call_deferred("_do_build")


func _do_build() -> void:
	_add_label("── World Props ──", Vector2(0.0, -40.0), 14, Color(0.9, 0.85, 0.6))

	for i in PROP_NAMES.size():
		var cell_ctr := _cell_pos(i)

		# WorldProp is @tool so its _draw() fires in the editor.
		var wp          := WorldProp.new()
		wp.prop_type     = i
		wp.tile_pos      = Vector2i(i * 3, i * 7)
		wp.position      = cell_ctr
		add_child(wp)

		_add_label(PROP_NAMES[i], cell_ctr + Vector2(0.0, LABEL_DY), 11, Color(0.85, 0.85, 0.85))

	queue_redraw()


func _draw() -> void:
	for i in PROP_NAMES.size():
		var c := _cell_pos(i)
		draw_rect(
			Rect2(c - Vector2(CELL_W * 0.5, CELL_H * 0.45), Vector2(CELL_W, CELL_H * 0.9)),
			Color(0.3, 0.3, 0.3, 0.4), false, 1.0)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _cell_pos(index: int) -> Vector2:
	return Vector2((index % COLS) * CELL_W, (index / COLS) * CELL_H)


func _add_label(text: String, pos: Vector2, size: int, col: Color) -> void:
	var lbl                       := Label.new()
	lbl.text                       = text
	lbl.position                   = pos + Vector2(-50.0, 0.0)
	lbl.custom_minimum_size        = Vector2(100.0, 20.0)
	lbl.horizontal_alignment       = HORIZONTAL_ALIGNMENT_CENTER
	var settings                  := LabelSettings.new()
	settings.font_size             = size
	settings.font_color            = col
	lbl.label_settings             = settings
	add_child(lbl)
