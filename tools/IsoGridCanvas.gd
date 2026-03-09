extends Control
class_name IsoGridCanvas

signal place_requested(cell: Vector2i)
signal select_requested(index: int)
signal move_requested(index: int, cell: Vector2i)
signal drag_finished(index: int)
signal drop_requested(cell: Vector2i, asset_path: String)

const IMAGE_EXTS := ["png", "webp"]

var placements: Array = []
var selected_index: int = -1
var tile_w: float = 64.0
var tile_h: float = 32.0
var grid_extent: int = 32
var origin: Vector2 = Vector2.ZERO

var drag_enabled: bool = true
var zoom: float = 1.0
var min_zoom: float = 0.4
var max_zoom: float = 3.0
var sprite_metadata: Dictionary = {}

var _hover_cell: Vector2i = Vector2i.ZERO
var _hover_valid: bool = false
var _dragging_index: int = -1
var _texture_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_update_origin()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_origin()
		queue_redraw()


func set_placements(values: Array, selected: int) -> void:
	placements = values
	selected_index = selected
	queue_redraw()


func set_drag_enabled(enabled: bool) -> void:
	drag_enabled = enabled


func set_zoom(value: float) -> void:
	zoom = clampf(value, min_zoom, max_zoom)
	queue_redraw()


func zoom_in(step: float = 0.1) -> void:
	set_zoom(zoom + step)


func zoom_out(step: float = 0.1) -> void:
	set_zoom(zoom - step)


func set_sprite_metadata(values: Dictionary) -> void:
	sprite_metadata = values
	queue_redraw()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = data
	return d.has("asset_path") and str(d.get("asset_path", "")) != ""


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return
	var cell := _screen_to_cell(at_position)
	if not _is_inside_grid(cell):
		return
	var d: Dictionary = data
	drop_requested.emit(cell, str(d.get("asset_path", "")))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := _screen_to_cell(event.position)
		_hover_cell = cell
		_hover_valid = _is_inside_grid(cell)
		if _dragging_index >= 0 and _hover_valid:
			move_requested.emit(_dragging_index, cell)
		queue_redraw()
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			var cell := _screen_to_cell(mb.position)
			var hit := _placement_index_at_cell(cell)
			if hit >= 0:
				if drag_enabled:
					_dragging_index = hit
				else:
					_dragging_index = -1
				select_requested.emit(hit)
			elif _is_inside_grid(cell):
				place_requested.emit(cell)
			queue_redraw()
		else:
			if _dragging_index >= 0:
				drag_finished.emit(_dragging_index)
			_dragging_index = -1


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.12, 1.0), true)
	_draw_grid()
	_draw_placements()
	if _hover_valid:
		_draw_cell_outline(_hover_cell, Color(0.3, 0.9, 1.0, 0.7), 2.0)


func _draw_grid() -> void:
	for y in range(-grid_extent, grid_extent + 1):
		for x in range(-grid_extent, grid_extent + 1):
			var c := Color(0.3, 0.3, 0.35, 0.22)
			if x == 0 or y == 0:
				c = Color(0.6, 0.6, 0.7, 0.35)
			_draw_cell_outline(Vector2i(x, y), c, 1.0)


func _draw_placements() -> void:
	var indices: Array = []
	for i in placements.size():
		indices.append(i)
	indices.sort_custom(func(a: int, b: int) -> bool:
		var pa: Dictionary = placements[a]
		var pb: Dictionary = placements[b]
		var ka := int(pa.get("x", 0)) + int(pa.get("y", 0)) + int(pa.get("z", 0))
		var kb := int(pb.get("x", 0)) + int(pb.get("y", 0)) + int(pb.get("z", 0))
		return ka < kb
	)

	for idx in indices:
		var p: Dictionary = placements[idx]
		var cx := int(p.get("x", 0))
		var cy := int(p.get("y", 0))
		var cz := int(p.get("z", 0))
		var screen := _cell_to_screen(Vector2i(cx, cy), cz)
		var asset := str(p.get("asset", ""))
		var layer := str(p.get("layer", "default"))

		var tex := _texture_for(asset)
		if tex != null:
			var state := int(p.get("sprite_state", 0))
			var frame_rect := _frame_rect_for(asset, tex.get_size(), state)
			var meta: Dictionary = sprite_metadata.get(asset, {})
			var placement_scale := float(p.get("scale", 1.0))
			var meta_scale := float(meta.get("scale", 1.0))
			var total_scale := maxf(0.01, placement_scale * meta_scale) * zoom
			var draw_size := frame_rect.size * total_scale
			var draw_pos := screen - Vector2(draw_size.x * 0.5, draw_size.y - _tile_height() * 0.5)
			var pivot_offset := Vector2(float(meta.get("pivot_x", 0)), float(meta.get("pivot_y", 0))) * total_scale
			draw_pos += pivot_offset
			draw_texture_rect_region(tex, Rect2(draw_pos, draw_size), frame_rect, false)
		else:
			var fill := _layer_color(layer)
			var hw := _tile_width() * 0.5
			var hh := _tile_height() * 0.5
			var poly := PackedVector2Array([
				screen + Vector2(0, -hh),
				screen + Vector2(hw, 0),
				screen + Vector2(0, hh),
				screen + Vector2(-hw, 0)
			])
			draw_colored_polygon(poly, fill)
			draw_polyline(poly + PackedVector2Array([poly[0]]), Color(0, 0, 0, 0.7), 1.5)

		if idx == selected_index:
			_draw_cell_outline(Vector2i(cx, cy), Color(1.0, 0.85, 0.3, 1.0), 2.0)


func _draw_cell_outline(cell: Vector2i, color: Color, width: float) -> void:
	var c := _cell_to_screen(cell, 0)
	var hw := _tile_width() * 0.5
	var hh := _tile_height() * 0.5
	var poly := PackedVector2Array([
		c + Vector2(0, -hh),
		c + Vector2(hw, 0),
		c + Vector2(0, hh),
		c + Vector2(-hw, 0),
		c + Vector2(0, -hh)
	])
	draw_polyline(poly, color, width)


func _frame_rect_for(asset_path: String, tex_size: Vector2, sprite_state: int) -> Rect2:
	var full := Rect2(Vector2.ZERO, tex_size)
	if not sprite_metadata.has(asset_path):
		return full
	var meta: Dictionary = sprite_metadata.get(asset_path, {})
	var frame_w := max(1, int(meta.get("frame_w", int(tex_size.x))))
	var frame_h := max(1, int(meta.get("frame_h", int(tex_size.y))))
	var columns := max(1, int(meta.get("columns", 1)))
	var rows := max(1, int(meta.get("rows", 1)))
	var margin := max(0, int(meta.get("margin", 0)))
	var separation := max(0, int(meta.get("separation", 0)))
	var state_count := max(1, columns * rows)
	var state := posmod(sprite_state, state_count)
	var col := state % columns
	var row: int = int(state / columns)
	var x := margin + col * (frame_w + separation)
	var y := margin + row * (frame_h + separation)
	if x + frame_w > int(tex_size.x) or y + frame_h > int(tex_size.y):
		return full
	return Rect2(Vector2(x, y), Vector2(frame_w, frame_h))


func _placement_index_at_cell(cell: Vector2i) -> int:
	for i in range(placements.size() - 1, -1, -1):
		var p: Dictionary = placements[i]
		if int(p.get("x", 0)) == cell.x and int(p.get("y", 0)) == cell.y:
			return i
	return -1


func _tile_width() -> float:
	return tile_w * zoom


func _tile_height() -> float:
	return tile_h * zoom


func _cell_to_screen(cell: Vector2i, z: int) -> Vector2:
	var tw := _tile_width()
	var th := _tile_height()
	var sx := (float(cell.x) - float(cell.y)) * tw * 0.5 + origin.x
	var sy := (float(cell.x) + float(cell.y)) * th * 0.5 + origin.y - float(z) * th * 0.5
	return Vector2(sx, sy)


func _screen_to_cell(pos: Vector2) -> Vector2i:
	var tw := _tile_width()
	var th := _tile_height()
	if tw <= 0.0 or th <= 0.0:
		return Vector2i.ZERO
	var lx := (pos.x - origin.x) / (tw * 0.5)
	var ly := (pos.y - origin.y) / (th * 0.5)
	var gx := int(floor((ly + lx) * 0.5))
	var gy := int(floor((ly - lx) * 0.5))
	return Vector2i(gx, gy)


func _is_inside_grid(cell: Vector2i) -> bool:
	return abs(cell.x) <= grid_extent and abs(cell.y) <= grid_extent


func _update_origin() -> void:
	origin = Vector2(size.x * 0.5, size.y * 0.22)


func _texture_for(asset_path: String) -> Texture2D:
	if asset_path == "":
		return null
	if _texture_cache.has(asset_path):
		return _texture_cache[asset_path]
	var ext := asset_path.get_extension().to_lower()
	if not IMAGE_EXTS.has(ext):
		_texture_cache[asset_path] = null
		return null
	if not ResourceLoader.exists(asset_path):
		_texture_cache[asset_path] = null
		return null
	var tex := load(asset_path) as Texture2D
	_texture_cache[asset_path] = tex
	return tex


func _layer_color(layer: String) -> Color:
	match layer.to_lower():
		"floor":
			return Color(0.2, 0.65, 0.35, 0.75)
		"wall":
			return Color(0.65, 0.45, 0.2, 0.8)
		"door":
			return Color(0.75, 0.7, 0.3, 0.85)
		"prop":
			return Color(0.35, 0.55, 0.8, 0.8)
		_:
			return Color(0.5, 0.5, 0.55, 0.75)


