class_name InteractMenu
extends CanvasLayer

## Right-click context menu for interactable world objects.
## Appears at cursor position; lists available actions for the nearest object.
## Ctrl cycles through multiple nearby objects.

const C_BG     := Color(0.08, 0.09, 0.11, 0.94)
const C_BORDER := Color(0.45, 0.45, 0.50, 0.85)
const C_TITLE  := Color(0.92, 0.78, 0.42, 1.0)
const C_TEXT   := Color(0.90, 0.90, 0.90, 1.0)
const C_HINT   := Color(0.55, 0.55, 0.55, 1.0)
const C_HOVER  := Color(0.22, 0.48, 0.82, 0.75)
const MIN_W    := 155.0

var _panel:      PanelContainer
var _title:      Label
var _action_box: VBoxContainer
var _hint:       Label

var _objects: Array = []   # [{label, actions:[{label, callable}], …}]
var _obj_idx: int   = 0


func _ready() -> void:
	layer   = 200
	visible = false

	_panel = PanelContainer.new()
	_panel.custom_minimum_size.x = MIN_W

	var sb := StyleBoxFlat.new()
	sb.bg_color            = C_BG
	sb.border_width_left   = 1
	sb.border_width_right  = 1
	sb.border_width_top    = 1
	sb.border_width_bottom = 1
	sb.border_color                  = C_BORDER
	sb.corner_radius_top_left        = 4
	sb.corner_radius_top_right       = 4
	sb.corner_radius_bottom_left     = 4
	sb.corner_radius_bottom_right    = 4
	sb.content_margin_left   = 7
	sb.content_margin_right  = 7
	sb.content_margin_top    = 5
	sb.content_margin_bottom = 5
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	_panel.add_child(outer)

	_title = Label.new()
	_title.add_theme_color_override("font_color", C_TITLE)
	_title.add_theme_font_size_override("font_size", 13)
	outer.add_child(_title)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	outer.add_child(sep)

	_action_box = VBoxContainer.new()
	_action_box.add_theme_constant_override("separation", 2)
	outer.add_child(_action_box)

	_hint = Label.new()
	_hint.add_theme_color_override("font_color", C_HINT)
	_hint.add_theme_font_size_override("font_size", 11)
	outer.add_child(_hint)


func show_at(screen_pos: Vector2, objects: Array) -> void:
	if objects.is_empty():
		return
	_objects = objects
	_obj_idx = 0
	_rebuild()
	visible          = true
	_panel.position  = screen_pos
	_clamp_position.call_deferred()


func close() -> void:
	visible = false
	_objects.clear()


func _rebuild() -> void:
	# Remove previous action buttons.
	for child in _action_box.get_children():
		_action_box.remove_child(child)
		child.queue_free()

	var obj: Dictionary = _objects[_obj_idx]
	var count := _objects.size()

	_title.text = ("%s  [%d/%d]" % [obj["label"], _obj_idx + 1, count]) \
		if count > 1 else (obj["label"] as String)

	var hover_sb := StyleBoxFlat.new()
	hover_sb.bg_color    = C_HOVER
	hover_sb.corner_radius_top_left     = 3
	hover_sb.corner_radius_top_right    = 3
	hover_sb.corner_radius_bottom_left  = 3
	hover_sb.corner_radius_bottom_right = 3
	hover_sb.content_margin_left   = 5
	hover_sb.content_margin_right  = 5
	hover_sb.content_margin_top    = 1
	hover_sb.content_margin_bottom = 1
	var empty_sb := StyleBoxEmpty.new()

	for action: Dictionary in obj["actions"]:
		var btn := Button.new()
		btn.text       = action["label"]
		btn.alignment  = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_NONE
		btn.flat       = true
		btn.add_theme_color_override("font_color",       C_TEXT)
		btn.add_theme_color_override("font_hover_color", C_TEXT)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_stylebox_override("normal",  empty_sb)
		btn.add_theme_stylebox_override("hover",   hover_sb)
		btn.add_theme_stylebox_override("pressed", hover_sb)
		var cb: Callable = action["callable"]
		btn.pressed.connect(func(): close(); cb.call())
		_action_box.add_child(btn)

	_hint.visible = count > 1
	_hint.text    = "Ctrl: next object" if count > 1 else ""


func _clamp_position() -> void:
	var vp := get_viewport().get_visible_rect().size
	var sz := _panel.size
	_panel.position.x = clampf(_panel.position.x, 4.0, maxf(4.0, vp.x - sz.x - 4.0))
	_panel.position.y = clampf(_panel.position.y, 4.0, maxf(4.0, vp.y - sz.y - 4.0))


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if not _panel.get_global_rect().has_point(mb.global_position):
				close()
				get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			close()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var kc := (event as InputEventKey).physical_keycode
		if kc == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		elif kc == KEY_CTRL and _objects.size() > 1:
			_obj_idx = (_obj_idx + 1) % _objects.size()
			_rebuild()
			get_viewport().set_input_as_handled()
