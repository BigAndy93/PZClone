class_name HUD
extends CanvasLayer

## Local-only HUD.  Never synced over network.

# ── Scene-tree stat bars (kept in HUD.tscn for the stat-changed routing) ──────
@onready var health_bar:   StatBar         = $StatPanel/HealthBar
@onready var hunger_bar:   StatBar         = $StatPanel/HungerBar
@onready var thirst_bar:   StatBar         = $StatPanel/ThirstBar
@onready var fatigue_bar:  StatBar         = $StatPanel/FatigueBar
@onready var stamina_bar:  StatBar         = $StatPanel/StaminaBar
@onready var bleed_label:  Label           = $StatPanel/BleedLabel
@onready var dialogue_box: PanelContainer  = $DialogueBox
@onready var speaker_label: Label          = $DialogueBox/VBox/SpeakerLabel
@onready var line_label:   Label           = $DialogueBox/VBox/LineLabel
@onready var choices_box:  VBoxContainer   = $DialogueBox/VBox/ChoicesBox
@onready var trade_menu:   Control         = $TradeMenu

var _current_lines:    Array = []
var _current_line_idx: int   = 0
var _active_npc_id:    int   = 0

# ── Floating windows ───────────────────────────────────────────────────────────
var _inventory_window:  InventoryWindow  = null
var _stats_window:      StatsWindow      = null
var _container_window:  ContainerWindow  = null
var _crafting_menu:     CraftingMenu     = null
var _ground_window:     GroundWindow     = null

# ── Other HUD overlays (unchanged) ────────────────────────────────────────────
var _message_label:    Label            = null
var _clock_label:      Label            = null
var _stats_label:      Label            = null   # "Day X | Kills: Y" label
var _minimap:         Minimap          = null
var _local_player:    Player           = null
var _kill_count:      int              = 0
var _respawn_timer:   float            = -1.0
var _respawn_label:   Label            = null
var _death_overlay:   ColorRect        = null
var _coop_panel:      VBoxContainer    = null
var _coop_entries:    Dictionary       = {}   # peer_id → {row, hp_bar, name_label}
var _downed_overlay:  ColorRect        = null
var _downed_timer:    float            = -1.0
var _downed_label:    Label            = null

# ── Combat / world feedback ────────────────────────────────────────────────────
var _noise_label:       Label           = null   # noise level indicator
var _horde_alert_label: Label           = null   # "HORDE ALERTED" flash
var _horde_alert_timer: float           = -1.0
var _weather_label:     Label           = null   # current weather status
var _weather_overlay:   ColorRect       = null   # fog/rain visual tint


func _ready() -> void:
	add_to_group("hud")
	dialogue_box.hide()
	if trade_menu:
		trade_menu.hide()

	# Hide the legacy StatPanel — stats are now in StatsWindow.
	$StatPanel.visible = false

	_create_floating_windows()
	_create_message_label()
	_create_clock()
	_create_stats_label()
	_create_coop_panel()
	_minimap = Minimap.new()
	add_child(_minimap)

	EventBus.player_spawned.connect(_on_player_spawned)
	EventBus.player_stat_critical.connect(_on_stat_critical)
	EventBus.item_used.connect(_on_item_used)
	EventBus.zombie_killed.connect(_on_zombie_killed)
	EventBus.player_removed.connect(_on_player_removed)
	EventBus.player_respawn_pending.connect(_on_player_respawn_pending)
	EventBus.player_downed.connect(_on_player_downed)
	EventBus.player_revived.connect(_on_player_revived)
	EventBus.horde_alerted.connect(_on_horde_alerted)
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.player_hit.connect(_on_player_hit)
	DayNightCycle.hour_changed.connect(_update_clock)
	DayNightCycle.day_changed.connect(_on_day_changed)
	_update_clock(DayNightCycle.time_of_day)
	_create_noise_label()
	_create_horde_alert_label()
	_create_weather_ui()


# ── Floating window creation ───────────────────────────────────────────────────
func _create_floating_windows() -> void:
	# StatsWindow — top-left, default open.
	_stats_window = StatsWindow.new()
	_stats_window.position = Vector2(8.0, 8.0)
	_stats_window.size     = Vector2(220.0, 280.0)
	add_child(_stats_window)

	# InventoryWindow — centre-right, hidden until I pressed.
	_inventory_window = InventoryWindow.new()
	_inventory_window.position = Vector2(600.0, 120.0)
	_inventory_window.size     = Vector2(300.0, 260.0)
	_inventory_window.hide()
	add_child(_inventory_window)

	# ContainerWindow — beside InventoryWindow, hidden until F on container.
	_container_window = ContainerWindow.new()
	_container_window.position = Vector2(280.0, 120.0)
	_container_window.size     = Vector2(280.0, 260.0)
	_container_window.hide()
	_container_window.visibility_changed.connect(_on_container_visibility_changed)
	add_child(_container_window)

	# CraftingMenu (now a DraggableWindow subclass).
	_crafting_menu = CraftingMenu.new()
	_crafting_menu.hide()
	add_child(_crafting_menu)

	# GroundWindow — below InventoryWindow, hidden until Tab is pressed.
	_ground_window = GroundWindow.new()
	_ground_window.position = Vector2(600.0, 390.0)
	_ground_window.size     = Vector2(280.0, DraggableWindow.TITLE_H)
	_ground_window.hide()
	add_child(_ground_window)


# ── Player wiring ──────────────────────────────────────────────────────────────
func _on_player_spawned(peer_id: int, player_node: Node) -> void:
	if peer_id != multiplayer.get_unique_id():
		_coop_add_entry(peer_id)
		if _coop_entries.has(peer_id):
			var entry: Dictionary = _coop_entries[peer_id]
			entry["name_label"].add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		return

	_respawn_timer = -1.0
	if _death_overlay and is_instance_valid(_death_overlay):
		_death_overlay.queue_free()
		_death_overlay = null

	var stats: SurvivalStats = player_node.stats
	if stats:
		stats.stat_changed.connect(_on_stat_changed)

	if player_node is Player:
		_local_player = player_node
		_inventory_window.setup(player_node)
		if _crafting_menu:
			_crafting_menu._inventory = player_node.inventory
		if _ground_window:
			_ground_window.setup(player_node)

	var world := get_tree().get_first_node_in_group("world_node")
	if world and _minimap:
		var tilemap: WorldTileMap = world.get_node_or_null("TileMapLayer")
		var map_data              = world.get("_map_data")
		if tilemap and map_data:
			_minimap.initialize(tilemap, map_data)


# ── Stat bar routing ──────────────────────────────────────────────────────────
func _on_stat_changed(stat_name: String, value: float) -> void:
	# Forward to StatsWindow bars.
	if _stats_window:
		_stats_window.on_stat_changed(stat_name, value)


func _on_stat_critical(peer_id: int, stat_name: String) -> void:
	if peer_id != multiplayer.get_unique_id():
		return
	if _stats_window:
		_stats_window.flash_bar(stat_name)


func _get_bar(stat_name: String) -> StatBar:
	# Kept for backward compat with any external callers.
	match stat_name:
		"health":   return health_bar
		"hunger":   return hunger_bar
		"thirst":   return thirst_bar
		"fatigue":  return fatigue_bar
		"stamina":  return stamina_bar
	return null


# ── Container window ──────────────────────────────────────────────────────────
func open_container(container: WorldContainer) -> void:
	if _local_player == null:
		return
	_container_window.open_container(container, _local_player.inventory)
	# Show inventory window alongside so the player can drag items.
	_inventory_window.show()
	# Let InventoryWindow know which container is active (enables shift-click deposit).
	if _inventory_window:
		_inventory_window.set_open_container(container)


func _on_container_visibility_changed() -> void:
	# When the container window is hidden, clear the active container reference.
	if _container_window and not _container_window.visible:
		if _inventory_window:
			_inventory_window.clear_open_container()


func update_equip_label(torso: String, back: String, hand: String) -> void:
	if _stats_window:
		_stats_window.update_equip_label(torso, back, hand)


# ── Clock ──────────────────────────────────────────────────────────────────────
func _create_clock() -> void:
	_clock_label = Label.new()
	_clock_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_clock_label.offset_left   = -120.0
	_clock_label.offset_top    = 4.0
	_clock_label.offset_right  = -4.0
	_clock_label.offset_bottom = 28.0
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_label.add_theme_font_size_override("font_size", 13)
	_clock_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7))
	add_child(_clock_label)


func _create_stats_label() -> void:
	_stats_label = Label.new()
	_stats_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_stats_label.offset_left   = -120.0
	_stats_label.offset_top    = 30.0
	_stats_label.offset_right  = -4.0
	_stats_label.offset_bottom = 50.0
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats_label.add_theme_font_size_override("font_size", 11)
	_stats_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.75))
	_update_stats_label()
	add_child(_stats_label)


func _update_stats_label() -> void:
	if _stats_label == null:
		return
	_stats_label.text = "Day %d  |  Kills: %d" % [DayNightCycle.day_count, _kill_count]


func _update_clock(_hour: float = 0.0) -> void:
	if _clock_label == null:
		return
	var phase_icon := ""
	match DayNightCycle.current_phase:
		DayNightCycle.Phase.DAY:   phase_icon = "DAY"
		DayNightCycle.Phase.DUSK:  phase_icon = "DUSK"
		DayNightCycle.Phase.NIGHT: phase_icon = "NIGHT"
		DayNightCycle.Phase.DAWN:  phase_icon = "DAWN"
	_clock_label.text = "%s  %s" % [DayNightCycle.get_hour_string(), phase_icon]


# ── Message toast ──────────────────────────────────────────────────────────────
func _create_message_label() -> void:
	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message_label.offset_top    = 140.0
	_message_label.offset_bottom = 170.0
	_message_label.offset_left   = -200.0
	_message_label.offset_right  = 200.0
	_message_label.add_theme_font_size_override("font_size", 14)
	_message_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	_message_label.visible = false
	add_child(_message_label)


func _on_item_used(peer_id: int, message: String) -> void:
	if peer_id != multiplayer.get_unique_id():
		return
	show_message(message)


func show_message(text: String) -> void:
	_message_label.text     = text
	_message_label.modulate = Color.WHITE
	_message_label.visible  = true
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(_message_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_message_label.hide)


# ── Dialogue ───────────────────────────────────────────────────────────────────
func show_dialogue(speaker: String, lines: Array, choices: Array, npc_id: int) -> void:
	_active_npc_id    = npc_id
	_current_lines    = lines
	_current_line_idx = 0
	speaker_label.text = speaker
	_show_next_line(choices)
	dialogue_box.show()


func _show_next_line(choices: Array) -> void:
	if _current_line_idx < _current_lines.size():
		line_label.text = _current_lines[_current_line_idx]
		_current_line_idx += 1
		_build_choices([{"text": "...", "action": "_next"}])
	else:
		_build_choices(choices)


func _build_choices(choices: Array) -> void:
	for child in choices_box.get_children():
		child.queue_free()
	for choice in choices:
		var btn  := Button.new()
		btn.text  = choice.get("text", "")
		btn.pressed.connect(_on_choice_selected.bind(choice))
		choices_box.add_child(btn)


func _on_choice_selected(choice: Dictionary) -> void:
	var action: String = choice.get("action", "close")
	match action:
		"_next":
			_show_next_line([])
		"close":
			dialogue_box.hide()
		"open_trade":
			dialogue_box.hide()
			var npc := instance_from_id(_active_npc_id)
			if npc and npc.has_method("rpc_request_trade"):
				npc.rpc_request_trade.rpc_id(1, multiplayer.get_unique_id())
		"offer_help", "offer_quest":
			dialogue_box.hide()


# ── Co-op panel ───────────────────────────────────────────────────────────────
func _create_coop_panel() -> void:
	_coop_panel = VBoxContainer.new()
	_coop_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_coop_panel.offset_left   = 4.0
	_coop_panel.offset_top    = 290.0   # below StatsWindow (~280px tall)
	_coop_panel.offset_right  = 200.0
	_coop_panel.offset_bottom = 500.0
	_coop_panel.add_theme_constant_override("separation", 4)
	add_child(_coop_panel)


func _coop_add_entry(peer_id: int) -> void:
	if _coop_entries.has(peer_id):
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var name_lbl := Label.new()
	name_lbl.text = GameManager.get_player_name(peer_id).left(10)
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	name_lbl.custom_minimum_size = Vector2(72.0, 0.0)
	row.add_child(name_lbl)

	var hp_bar := ProgressBar.new()
	hp_bar.min_value = 0.0
	hp_bar.max_value = 100.0
	hp_bar.value     = 100.0
	hp_bar.custom_minimum_size = Vector2(80.0, 10.0)
	hp_bar.show_percentage = false
	row.add_child(hp_bar)

	_coop_panel.add_child(row)
	_coop_entries[peer_id] = {"row": row, "hp_bar": hp_bar, "name_label": name_lbl}


func _coop_remove_entry(peer_id: int) -> void:
	if not _coop_entries.has(peer_id):
		return
	var entry: Dictionary = _coop_entries[peer_id]
	if entry["row"] and is_instance_valid(entry["row"]):
		entry["row"].queue_free()
	_coop_entries.erase(peer_id)


# ── Kill / day tracking ────────────────────────────────────────────────────────
func _on_zombie_killed(zombie_node: Node, killer_peer_id: int) -> void:
	if killer_peer_id != multiplayer.get_unique_id():
		return
	_kill_count += 1
	_update_stats_label()


func _on_day_changed(_day: int) -> void:
	_update_stats_label()


# ── Death overlay ──────────────────────────────────────────────────────────────
func _on_player_removed(peer_id: int) -> void:
	_coop_remove_entry(peer_id)
	if peer_id != multiplayer.get_unique_id():
		return
	_respawn_timer = -1.0
	if _death_overlay and is_instance_valid(_death_overlay):
		_death_overlay.queue_free()
		_death_overlay = null


func _on_player_respawn_pending(peer_id: int, delay: float) -> void:
	if _coop_entries.has(peer_id):
		var entry: Dictionary = _coop_entries[peer_id]
		entry["name_label"].add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
		entry["hp_bar"].value = 0.0
	if peer_id != multiplayer.get_unique_id():
		return
	_respawn_timer = delay
	_show_death_overlay(delay)


func _show_death_overlay(respawn_delay: float = -1.0) -> void:
	if _death_overlay and is_instance_valid(_death_overlay):
		_death_overlay.queue_free()

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate.a = 0.0
	add_child(bg)
	_death_overlay = bg

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left   = -160.0
	vbox.offset_right  =  160.0
	vbox.offset_top    = -70.0
	vbox.offset_bottom =  70.0
	vbox.alignment     = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	bg.add_child(vbox)

	var title := Label.new()
	title.text = "YOU DIED"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.82, 0.08, 0.08))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := Label.new()
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.80, 0.80, 0.80))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	_respawn_label = sub

	if respawn_delay > 0.0:
		sub.text = "Respawning in %ds..." % int(respawn_delay)
	else:
		sub.text = "Day %d  |  Kills: %d" % [DayNightCycle.day_count, _kill_count]

	var tween := create_tween()
	tween.tween_property(bg, "modulate:a", 1.0, 0.9)


func _process(delta: float) -> void:
	if _respawn_timer > 0.0:
		_respawn_timer -= delta
		if _respawn_label and is_instance_valid(_respawn_label):
			_respawn_label.text = "Respawning in %ds..." % maxi(int(_respawn_timer), 0)
		if _respawn_timer <= 0.0:
			_respawn_timer = -1.0

	if _downed_timer > 0.0:
		_downed_timer -= delta
		if _downed_label and is_instance_valid(_downed_label):
			var being_dragged: bool = _local_player != null and _local_player.get("sync_drag_carrier_id") != 0
			if being_dragged:
				_downed_label.text = "BEING DRAGGED — bleed out in %ds" % maxi(int(_downed_timer), 0)
			else:
				_downed_label.text = "DOWNED — bleed out in %ds\nTeammate: [G] drag  [F] revive" % maxi(int(_downed_timer), 0)
		if _downed_timer <= 0.0:
			_downed_timer = -1.0

	# ── Noise indicator ──────────────────────────────────────────────────────
	if _noise_label and _local_player and is_instance_valid(_local_player):
		var noise_text := "SILENT"
		var noise_col  := Color(0.50, 0.80, 0.50)
		if _local_player.is_sprinting or (_local_player.velocity.length() > 5.0 and not _local_player.is_sneaking):
			noise_text = "LOUD"
			noise_col  = Color(1.0, 0.35, 0.35)
		elif _local_player.velocity.length() > 5.0 and _local_player.is_sneaking:
			noise_text = "QUIET"
			noise_col  = Color(0.70, 0.90, 0.55)
		elif _local_player.velocity.length() > 5.0:
			noise_text = "QUIET"
			noise_col  = Color(0.90, 0.85, 0.45)
		_noise_label.text = "[ %s ]" % noise_text
		_noise_label.add_theme_color_override("font_color", noise_col)

	# ── Horde alert flash countdown ──────────────────────────────────────────
	if _horde_alert_timer > 0.0:
		_horde_alert_timer -= delta
		if _horde_alert_label and is_instance_valid(_horde_alert_label):
			var alpha := clampf(_horde_alert_timer, 0.0, 1.0)
			_horde_alert_label.modulate.a = alpha
		if _horde_alert_timer <= 0.0:
			_horde_alert_timer = -1.0
			if _horde_alert_label and is_instance_valid(_horde_alert_label):
				_horde_alert_label.visible = false

	for pid: int in _coop_entries:
		var player_node := GameManager.get_player_node(pid)
		if player_node and is_instance_valid(player_node):
			var entry: Dictionary = _coop_entries[pid]
			entry["hp_bar"].value = player_node.sync_health


# ── Downed / revive ────────────────────────────────────────────────────────────
func _on_player_downed(peer_id: int) -> void:
	if peer_id != multiplayer.get_unique_id():
		if _coop_entries.has(peer_id):
			_coop_entries[peer_id]["hp_bar"].modulate = Color(0.8, 0.2, 0.2)
		return
	_downed_timer = StatTickSystem.BLEED_OUT_TIME
	_show_downed_overlay()


func _on_player_revived(peer_id: int) -> void:
	if peer_id != multiplayer.get_unique_id():
		if _coop_entries.has(peer_id):
			_coop_entries[peer_id]["hp_bar"].modulate = Color.WHITE
		return
	_downed_timer = -1.0
	if _downed_overlay and is_instance_valid(_downed_overlay):
		_downed_overlay.queue_free()
		_downed_overlay = null
	_downed_label = null


func _show_downed_overlay() -> void:
	if _downed_overlay and is_instance_valid(_downed_overlay):
		_downed_overlay.queue_free()

	var bg := ColorRect.new()
	bg.color = Color(0.45, 0.0, 0.0, 0.65)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate.a = 0.0
	add_child(bg)
	_downed_overlay = bg

	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.offset_left   = -220.0
	lbl.offset_right  =  220.0
	lbl.offset_top    = -40.0
	lbl.offset_bottom =  40.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
	bg.add_child(lbl)
	_downed_label = lbl

	var tween := create_tween()
	tween.tween_property(bg, "modulate:a", 1.0, 0.4)


# ── Trade ──────────────────────────────────────────────────────────────────────
func show_trade(npc_id: int, peer_id: int, items: Array) -> void:
	if trade_menu and trade_menu.has_method("open_for_peer"):
		trade_menu.open_for_peer(npc_id, peer_id, items)


# ── Noise level indicator ──────────────────────────────────────────────────────
func _create_noise_label() -> void:
	_noise_label = Label.new()
	_noise_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_noise_label.offset_left   = -120.0
	_noise_label.offset_top    = 52.0
	_noise_label.offset_right  = -4.0
	_noise_label.offset_bottom = 72.0
	_noise_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_noise_label.add_theme_font_size_override("font_size", 11)
	_noise_label.add_theme_color_override("font_color", Color(0.70, 0.85, 0.70))
	add_child(_noise_label)


# ── Horde alert flash ─────────────────────────────────────────────────────────
func _create_horde_alert_label() -> void:
	_horde_alert_label = Label.new()
	_horde_alert_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_horde_alert_label.offset_left   = -160.0
	_horde_alert_label.offset_right  =  160.0
	_horde_alert_label.offset_top    =  110.0
	_horde_alert_label.offset_bottom =  132.0
	_horde_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_horde_alert_label.add_theme_font_size_override("font_size", 15)
	_horde_alert_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	_horde_alert_label.text    = "!! HORDE ALERTED !!"
	_horde_alert_label.visible = false
	add_child(_horde_alert_label)


func _on_horde_alerted() -> void:
	if _horde_alert_label == null:
		return
	_horde_alert_label.modulate = Color.WHITE
	_horde_alert_label.visible  = true
	_horde_alert_timer = 3.0


# ── Weather UI ────────────────────────────────────────────────────────────────
func _create_weather_ui() -> void:
	# Full-screen tint for fog/rain.
	_weather_overlay = ColorRect.new()
	_weather_overlay.color = Color(0.60, 0.65, 0.70, 0.0)
	_weather_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_weather_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weather_overlay.z_index = -10
	add_child(_weather_overlay)

	# Weather status label — top-right below the stats row.
	_weather_label = Label.new()
	_weather_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_weather_label.offset_left   = -120.0
	_weather_label.offset_top    = 70.0
	_weather_label.offset_right  = -4.0
	_weather_label.offset_bottom = 90.0
	_weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weather_label.add_theme_font_size_override("font_size", 11)
	_weather_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	_weather_label.text = "CLEAR"
	add_child(_weather_label)


func _on_weather_changed(weather_type: int) -> void:
	if _weather_label:
		var labels: Array[String] = ["CLEAR", "OVERCAST", "RAIN", "HEAVY RAIN", "FOG"]
		if weather_type >= 0 and weather_type < labels.size():
			_weather_label.text = labels[weather_type]

	if _weather_overlay == null:
		return
	# Opacity per weather type: clear=0, overcast=0.06, rain=0.15, heavy=0.30, fog=0.25
	var targets: Array[float] = [0.0, 0.06, 0.15, 0.30, 0.25]
	var target_a := 0.0
	if weather_type >= 0 and weather_type < targets.size():
		target_a = targets[weather_type]
	var tween := create_tween()
	tween.tween_property(_weather_overlay, "color:a", target_a, 2.0)


# ── Damage popup ──────────────────────────────────────────────────────────────
func _on_player_hit(peer_id: int, damage: float) -> void:
	if peer_id != multiplayer.get_unique_id():
		return
	# Spawn a floating damage number that drifts upward and fades out.
	var lbl := Label.new()
	lbl.text = "-%d" % int(damage)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.offset_left   = randf_range(-30.0, 30.0)
	lbl.offset_top    = randf_range(-60.0, -30.0)
	lbl.offset_right  = lbl.offset_left  + 60.0
	lbl.offset_bottom = lbl.offset_top   + 24.0
	add_child(lbl)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "offset_top",    lbl.offset_top    - 24.0, 0.6)
	tween.tween_property(lbl, "offset_bottom", lbl.offset_bottom - 24.0, 0.6)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.6)
	tween.tween_callback(lbl.queue_free).set_delay(0.65)
