class_name StatsWindow
extends DraggableWindow

## Floating stats panel: health/hunger/thirst/fatigue/stamina bars + status text.

const STAT_BAR_SCENE := "res://scenes/hud/StatBar.tscn"

var health_bar:  StatBar = null
var hunger_bar:  StatBar = null
var thirst_bar:  StatBar = null
var fatigue_bar: StatBar = null
var stamina_bar: StatBar = null

var _status_lbl: Label  = null
var _temp_lbl:   Label  = null
var _equip_lbl:  Label  = null

# Mirrors of stat state for status label.
var _bleed_stacks: int   = 0
var _infected:     bool  = false
var _deep_wound:   int   = 0
var _fractured:    bool  = false
var _temperature:  float = 37.0


func _init() -> void:
	title    = "Status"
	min_size = Vector2(220.0, 260.0)


func _post_build() -> void:
	var ca := get_content_area()

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 3)
	vbox.offset_left  = 6.0
	vbox.offset_right = -6.0
	vbox.offset_top   = 4.0
	ca.add_child(vbox)

	# Stat bars
	var bar_scene := load(STAT_BAR_SCENE) as PackedScene
	health_bar  = _add_bar(vbox, bar_scene, "HP",   Color(0.80, 0.10, 0.10))
	hunger_bar  = _add_bar(vbox, bar_scene, "Food", Color(0.90, 0.60, 0.10))
	thirst_bar  = _add_bar(vbox, bar_scene, "H2O",  Color(0.10, 0.50, 0.90))
	fatigue_bar = _add_bar(vbox, bar_scene, "Rest", Color(0.40, 0.40, 0.90))
	stamina_bar = _add_bar(vbox, bar_scene, "STM",  Color(0.20, 0.85, 0.45))

	# Separator
	var sep := ColorRect.new()
	sep.color               = Color(0.35, 0.35, 0.30, 0.55)
	sep.custom_minimum_size = Vector2(0.0, 1.0)
	vbox.add_child(sep)

	# Temperature label
	_temp_lbl = _add_label(vbox, "37.0 °C", 11, Color(0.85, 0.85, 0.85))

	# Status label (bleeding/infected/etc.)
	_status_lbl = _add_label(vbox, "", 10, Color(1.0, 0.4, 0.4))

	# Equipped slots label
	_equip_lbl = _add_label(vbox, "[Torso: —]  [Back: —]  [Hand: —]", 9, Color(0.65, 0.65, 0.60))


func _add_bar(parent: VBoxContainer, scene: PackedScene,
		label: String, col: Color) -> StatBar:
	var bar: StatBar = scene.instantiate()
	bar.stat_label_text = label
	bar.bar_color       = col
	parent.add_child(bar)
	return bar


func _add_label(parent: VBoxContainer, text: String, size: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text                    = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", col)
	lbl.autowrap_mode           = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(lbl)
	return lbl


# ── Stat updates ──────────────────────────────────────────────────────────────

func on_stat_changed(stat_name: String, value: float) -> void:
	match stat_name:
		"health":       if health_bar:  health_bar.set_value(value)
		"hunger":       if hunger_bar:  hunger_bar.set_value(value)
		"thirst":       if thirst_bar:  thirst_bar.set_value(value)
		"fatigue":      if fatigue_bar: fatigue_bar.set_value(value)
		"stamina":      if stamina_bar: stamina_bar.set_value(value)
		"bleed_stacks":
			_bleed_stacks = int(value)
			_refresh_status()
		"infection":
			_infected = value > 0.0
			_refresh_status()
		"deep_wound":
			_deep_wound = int(value)
			_refresh_status()
		"fracture":
			_fractured = value > 0.0
			_refresh_status()
		"temperature":
			_temperature = value
			_refresh_temp()


func _refresh_status() -> void:
	if _status_lbl == null:
		return
	var parts: Array[String] = []
	if _bleed_stacks > 0:
		parts.append("BLEEDING x%d" % _bleed_stacks)
	if _infected:
		parts.append("INFECTED")
	if _deep_wound > 0:
		parts.append("DEEP WOUND x%d" % _deep_wound)
	if _fractured:
		parts.append("FRACTURE")
	_status_lbl.text = "  ".join(parts)


func _refresh_temp() -> void:
	if _temp_lbl == null:
		return
	_temp_lbl.text = "%.1f °C" % _temperature
	if _temperature <= 34.5:
		_temp_lbl.add_theme_color_override("font_color", Color(0.45, 0.70, 1.00))
	elif _temperature >= 39.5:
		_temp_lbl.add_theme_color_override("font_color", Color(1.00, 0.45, 0.20))
	else:
		_temp_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))


## Update the equipped items slot label (called by HUD when equip state changes).
func update_equip_label(torso: String, back: String, hand: String) -> void:
	if _equip_lbl == null:
		return
	_equip_lbl.text = "[Torso: %s]  [Back: %s]  [Hand: %s]" % [torso, back, hand]


## Flash the bar for a given stat (critical alert visual).
func flash_bar(stat_name: String) -> void:
	var bar := _get_bar(stat_name)
	if bar == null:
		return
	var tw := create_tween().set_loops(3)
	tw.tween_property(bar, "modulate", Color.RED,   0.15)
	tw.tween_property(bar, "modulate", Color.WHITE, 0.15)


func _get_bar(stat_name: String) -> StatBar:
	match stat_name:
		"health":   return health_bar
		"hunger":   return hunger_bar
		"thirst":   return thirst_bar
		"fatigue":  return fatigue_bar
		"stamina":  return stamina_bar
	return null
