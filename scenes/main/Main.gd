class_name Main
extends Node

@onready var lobby: Control = $Lobby


func _ready() -> void:
	GameManager.game_phase_changed.connect(_on_phase_changed)
	GameManager.change_phase(GameManager.Phase.LOBBY)


func _on_phase_changed(phase: GameManager.Phase) -> void:
	match phase:
		GameManager.Phase.LOBBY:
			if lobby:
				lobby.show()
		GameManager.Phase.LOADING, GameManager.Phase.PLAYING:
			if lobby:
				lobby.hide()
		GameManager.Phase.GAME_OVER:
			_show_game_over()


func _show_game_over() -> void:
	var overlay := _build_game_over_overlay()
	add_child(overlay)

	# Fade in the overlay panel
	var panel: PanelContainer = overlay.get_child(0)
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.8)
	tween.tween_interval(2.5)
	tween.tween_callback(func():
		NetworkManager.disconnect_from_game()
		get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
	)


func _build_game_over_overlay() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 128  # on top of everything

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel",
		_make_flat_stylebox(Color(0.0, 0.0, 0.0, 0.82)))

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)

	var title := Label.new()
	title.text = "YOU DIED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.85, 0.08, 0.08))

	var sub := Label.new()
	sub.text = "Returning to lobby..."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))

	vbox.add_child(title)
	vbox.add_child(sub)
	panel.add_child(vbox)
	layer.add_child(panel)
	return layer


func _make_flat_stylebox(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	return sb
