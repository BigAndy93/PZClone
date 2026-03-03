class_name DayNightOverlay
extends CanvasLayer

# Dark-blue tint used at full night.
const NIGHT_COLOR := Color(0.04, 0.04, 0.18, 0.72)

var _rect: ColorRect


func _ready() -> void:
	layer = 10   # above world, below HUD (CanvasLayer default is 1)

	_rect                = ColorRect.new()
	_rect.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	_rect.color          = Color.TRANSPARENT
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func _process(_delta: float) -> void:
	var d := DayNightCycle.get_darkness()
	_rect.color = Color(NIGHT_COLOR.r, NIGHT_COLOR.g, NIGHT_COLOR.b, NIGHT_COLOR.a * d)
