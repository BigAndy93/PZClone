class_name DraggableWindow
extends Control

## Base class for all floating HUD panels.
## Provides: dark title bar, X-close button, bottom-right resize grip.
## Subclasses add content to get_content_area().

@export var title:    String  = "Window"
@export var min_size: Vector2 = Vector2(200.0, 150.0)

const TITLE_H  := 24.0
const GRIP_SZ  := 10.0

var _dragging:      bool    = false
var _drag_offset:   Vector2 = Vector2.ZERO
var _resizing:      bool    = false
var _resize_start:  Vector2 = Vector2.ZERO
var _size_at_start: Vector2 = Vector2.ZERO

var _title_label: Label   = null
var _content:     Control = null


func _ready() -> void:
	_build()
	_post_build()


## Override in subclass to populate _content.
func _post_build() -> void:
	pass


func _build() -> void:
	mouse_filter        = Control.MOUSE_FILTER_STOP
	custom_minimum_size = min_size.max(Vector2(100.0, 60.0))

	# Background
	var bg := ColorRect.new()
	bg.color        = Color(0.08, 0.08, 0.10, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Thin border line
	var border := ColorRect.new()
	border.color         = Color(0.38, 0.36, 0.32, 0.55)
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.offset_left   = 0.0
	border.offset_top    = 0.0
	border.offset_right  = 0.0
	border.offset_bottom = 0.0
	border.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(border)

	# Title bar
	var title_bar := ColorRect.new()
	title_bar.color              = Color(0.14, 0.13, 0.18, 1.0)
	title_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_bar.offset_bottom      = TITLE_H
	title_bar.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	add_child(title_bar)

	# Title label
	_title_label = Label.new()
	_title_label.text                 = title
	_title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_label.offset_right         = -24.0   # leave room for X button
	_title_label.add_theme_font_size_override("font_size", 11)
	_title_label.add_theme_color_override("font_color", Color(0.90, 0.85, 0.55))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_title_label.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	title_bar.add_child(_title_label)

	# Close (X) button
	var close_btn := Button.new()
	close_btn.text    = "X"
	close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_left   = -22.0
	close_btn.offset_top    =   2.0
	close_btn.offset_right  =  -2.0
	close_btn.offset_bottom = TITLE_H - 2.0
	close_btn.add_theme_font_size_override("font_size", 9)
	close_btn.pressed.connect(hide)
	title_bar.add_child(close_btn)

	# Content area (between title bar and bottom grip strip)
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.offset_top    = TITLE_H
	_content.offset_bottom = -GRIP_SZ
	_content.mouse_filter  = Control.MOUSE_FILTER_PASS
	add_child(_content)


func _draw() -> void:
	# Resize grip indicator at bottom-right corner (diagonal hash lines).
	var x := size.x
	var y := size.y
	var c := Color(0.65, 0.65, 0.65, 0.55)
	draw_line(Vector2(x - GRIP_SZ,      y), Vector2(x, y - GRIP_SZ),      c, 1.0)
	draw_line(Vector2(x - GRIP_SZ * 0.6, y), Vector2(x, y - GRIP_SZ * 0.6), c * Color(1,1,1,0.35), 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb    := event as InputEventMouseButton
		var local := get_local_mouse_position()
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# Resize grip gets priority (bottom-right corner).
				var grip := Rect2(size.x - GRIP_SZ * 2.0, size.y - GRIP_SZ * 2.0, GRIP_SZ * 2.0, GRIP_SZ * 2.0)
				if grip.has_point(local):
					_resizing      = true
					_resize_start  = get_global_mouse_position()
					_size_at_start = size
					get_viewport().set_input_as_handled()
				elif local.y <= TITLE_H:
					_dragging    = true
					_drag_offset = global_position - get_global_mouse_position()
					get_viewport().set_input_as_handled()
			else:
				_dragging = false
				_resizing = false

	elif event is InputEventMouseMotion:
		if _dragging:
			global_position = get_global_mouse_position() + _drag_offset
			_clamp_to_viewport()
			get_viewport().set_input_as_handled()
		elif _resizing:
			var delta    := get_global_mouse_position() - _resize_start
			var new_size := (_size_at_start + delta).max(min_size)
			size = new_size
			queue_redraw()
			_clamp_to_viewport()
			get_viewport().set_input_as_handled()


func _clamp_to_viewport() -> void:
	var vp := get_viewport_rect().size
	global_position.x = clampf(global_position.x, 0.0, maxf(0.0, vp.x - size.x))
	global_position.y = clampf(global_position.y, 0.0, maxf(0.0, vp.y - size.y))


func set_panel_title(t: String) -> void:
	title = t
	if _title_label:
		_title_label.text = t


## Returns the content area where subclasses add their children.
func get_content_area() -> Control:
	return _content
