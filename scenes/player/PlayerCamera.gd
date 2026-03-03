class_name PlayerCamera
extends Camera2D

@export var follow_speed: float = 8.0
@export var zoom_level:   Vector2 = Vector2(2.0, 2.0)

const MIN_ZOOM:    float = 0.8
const MAX_ZOOM:    float = 5.0
const ZOOM_STEP:   float = 0.25
const ZOOM_SMOOTH: float = 12.0

var _target:      Node2D = null
var _zoom_target: float  = 2.0


func _ready() -> void:
	_zoom_target = zoom_level.x
	zoom = zoom_level
	position_smoothing_enabled = true
	position_smoothing_speed   = follow_speed
	make_current()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_target = clampf(_zoom_target + ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_target = clampf(_zoom_target - ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD:
			_zoom_target = clampf(_zoom_target + ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
		elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
			_zoom_target = clampf(_zoom_target - ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)


func _process(delta: float) -> void:
	if _target:
		global_position = _target.global_position
	# Smooth zoom towards target
	var cur := zoom.x
	if not is_equal_approx(cur, _zoom_target):
		zoom = Vector2.ONE * lerpf(cur, _zoom_target, ZOOM_SMOOTH * delta)
