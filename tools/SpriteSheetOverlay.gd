extends Control
class_name SpriteSheetOverlay

signal frame_selected(index: int, col: int, row: int)

var texture: Texture2D
var frame_w: int = 32
var frame_h: int = 32
var columns: int = 1
var rows: int = 1
var margin: int = 0
var separation: int = 0
var pivot_x: int = 0
var pivot_y: int = 0
var selected_frame: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func configure(meta: Dictionary) -> void:
	frame_w = int(meta.get("frame_w", 32))
	frame_h = int(meta.get("frame_h", 32))
	columns = max(1, int(meta.get("columns", 1)))
	rows = max(1, int(meta.get("rows", 1)))
	margin = max(0, int(meta.get("margin", 0)))
	separation = max(0, int(meta.get("separation", 0)))
	pivot_x = int(meta.get("pivot_x", 0))
	pivot_y = int(meta.get("pivot_y", 0))
	queue_redraw()


func set_texture(tex: Texture2D) -> void:
	texture = tex
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if texture == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var data := _frame_from_pos(mb.position)
			if data["valid"]:
				selected_frame = int(data["index"])
				frame_selected.emit(selected_frame, int(data["col"]), int(data["row"]))
				queue_redraw()


func _draw() -> void:
	if texture == null:
		return
	var tr := _texture_draw_rect()
	if tr.size.x <= 0 or tr.size.y <= 0:
		return
	for row in rows:
		for col in columns:
			var r := _frame_rect_screen(col, row, tr)
			var color := Color(0.2, 0.9, 1.0, 0.4)
			if row * columns + col == selected_frame:
				color = Color(1.0, 0.85, 0.2, 0.9)
			draw_rect(r, color, false, 2.0)
			if row * columns + col == selected_frame:
				var pivot := r.position + Vector2(float(pivot_x), float(pivot_y)) * _scale_factor(tr)
				draw_line(pivot + Vector2(-6, 0), pivot + Vector2(6, 0), Color(1, 0.3, 0.2, 0.95), 2.0)
				draw_line(pivot + Vector2(0, -6), pivot + Vector2(0, 6), Color(1, 0.3, 0.2, 0.95), 2.0)


func _frame_from_pos(pos: Vector2) -> Dictionary:
	var tr := _texture_draw_rect()
	if not tr.has_point(pos):
		return {"valid": false}
	var scale := _scale_factor(tr)
	if scale <= 0:
		return {"valid": false}
	var local := (pos - tr.position) / scale
	local -= Vector2(margin, margin)
	if local.x < 0 or local.y < 0:
		return {"valid": false}
	var cell_w := frame_w + separation
	var cell_h := frame_h + separation
	if cell_w <= 0 or cell_h <= 0:
		return {"valid": false}
	var col := int(floor(local.x / float(cell_w)))
	var row := int(floor(local.y / float(cell_h)))
	if col < 0 or col >= columns or row < 0 or row >= rows:
		return {"valid": false}
	return {"valid": true, "index": row * columns + col, "col": col, "row": row}


func _frame_rect_screen(col: int, row: int, tr: Rect2) -> Rect2:
	var scale := _scale_factor(tr)
	var pos_px := Vector2(margin + col * (frame_w + separation), margin + row * (frame_h + separation))
	var size_px := Vector2(frame_w, frame_h)
	return Rect2(tr.position + pos_px * scale, size_px * scale)


func _texture_draw_rect() -> Rect2:
	if texture == null:
		return Rect2()
	var tex_size := texture.get_size()
	if tex_size.x <= 0 or tex_size.y <= 0:
		return Rect2()
	var scale: float = minf(size.x / tex_size.x, size.y / tex_size.y)
	var draw_size: Vector2 = tex_size * scale
	var draw_pos: Vector2 = (size - draw_size) * 0.5
	return Rect2(draw_pos, draw_size)


func _scale_factor(tr: Rect2) -> float:
	if texture == null:
		return 1.0
	var tex_size := texture.get_size()
	if tex_size.x <= 0:
		return 1.0
	return tr.size.x / tex_size.x
