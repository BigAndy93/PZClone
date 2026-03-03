## PostProcessLayer — Full-screen analog horror post-processing.
## Applies film grain, vignette, scanlines, and micro chromatic aberration
## via analog_horror.gdshader on a CanvasLayer above everything.
##
## Added in World._ready():
##   var post := PostProcessLayer.new()
##   add_child(post)

class_name PostProcessLayer
extends CanvasLayer

func _ready() -> void:
	layer = 128   # above HUD (typically layer 1–10) and DayNightOverlay
	# follow_viewport_enabled must be FALSE for a full-screen post-process.
	# When true the CanvasLayer's coordinate space follows the camera, so the
	# ColorRect moves with the world and only partially covers the screen.
	follow_viewport_enabled = false

	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# PRESET_FULL_RECT anchors to 0,0 → 1,1 with zero offsets, matching the
	# CanvasLayer's viewport rect regardless of window size or stretch mode.
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/analog_horror.gdshader")
	rect.material = mat

	add_child(rect)
