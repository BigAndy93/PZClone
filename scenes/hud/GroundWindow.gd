class_name GroundWindow
extends DraggableWindow

## Floating window that lists loot items on the ground near the player.
## Opens alongside the InventoryWindow when Tab is pressed.
## Collapses to header-only when no items are nearby; expands when items are present.

const EXPANDED_H := 180.0

var _player:       Player         = null
var _list_box:     VBoxContainer  = null
var _empty_label:  Label          = null
var _collapse_btn: Button         = null
var _collapsed:    bool           = false


func _init() -> void:
	title    = "Ground"
	min_size = Vector2(220.0, DraggableWindow.TITLE_H)


func _post_build() -> void:
	# Allow the window to shrink to header-only height.
	custom_minimum_size = Vector2(220.0, DraggableWindow.TITLE_H)

	# Collapse / expand button on the left of the title bar.
	_collapse_btn = Button.new()
	_collapse_btn.text       = "−"
	_collapse_btn.flat       = true
	_collapse_btn.focus_mode = Control.FOCUS_NONE
	_collapse_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_collapse_btn.offset_left   = 2.0
	_collapse_btn.offset_top    = 2.0
	_collapse_btn.offset_right  = 20.0
	_collapse_btn.offset_bottom = DraggableWindow.TITLE_H - 2.0
	_collapse_btn.add_theme_font_size_override("font_size", 14)
	_collapse_btn.add_theme_color_override("font_color", Color(0.80, 0.80, 0.80))
	_collapse_btn.pressed.connect(_toggle_collapse)
	add_child(_collapse_btn)

	# Scrollable content area.
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	get_content_area().add_child(scroll)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 3)
	scroll.add_child(_list_box)

	_empty_label = Label.new()
	_empty_label.text = "(nothing nearby)"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	_empty_label.add_theme_font_size_override("font_size", 12)
	_empty_label.visible = false
	_list_box.add_child(_empty_label)


func setup(player: Player) -> void:
	_player = player


## Rescans the player's interact area and rebuilds the item list.
## Call when the window is shown (Tab press).
func refresh() -> void:
	_rebuild_list()
	var has_items := _list_box.get_child_count() > 1  # >1 because _empty_label is always there
	_set_collapsed(not has_items)


func _rebuild_list() -> void:
	# Remove all rows except _empty_label.
	for child in _list_box.get_children():
		if child == _empty_label:
			continue
		_list_box.remove_child(child)
		child.queue_free()

	if _player == null:
		_empty_label.visible = true
		return

	var found := 0
	for area: Area2D in _player.interact_area.get_overlapping_areas():
		if area.is_in_group("loot_items") and area is LootItem:
			_add_item_row(area as LootItem)
			found += 1

	_empty_label.visible = found == 0


func _add_item_row(loot: LootItem) -> void:
	var item_name := loot.item_data.item_name if loot.item_data != null else "Item"

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var lbl := Label.new()
	lbl.text                      = item_name
	lbl.size_flags_horizontal     = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90))
	row.add_child(lbl)

	var btn := Button.new()
	btn.text             = "Take"
	btn.focus_mode       = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(44.0, 0.0)
	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(func():
		if _player != null and is_instance_valid(loot):
			_player._try_pickup(loot)
		row.queue_free()
	)
	row.add_child(btn)

	_list_box.add_child(row)


func _set_collapsed(collapse: bool) -> void:
	_collapsed = collapse
	if collapse:
		custom_minimum_size.y     = DraggableWindow.TITLE_H
		size.y                    = DraggableWindow.TITLE_H
		get_content_area().visible = false
		_collapse_btn.text        = "+"
	else:
		custom_minimum_size.y     = EXPANDED_H
		if size.y < EXPANDED_H:
			size.y = EXPANDED_H
		get_content_area().visible = true
		_collapse_btn.text        = "−"


func _toggle_collapse() -> void:
	_set_collapsed(not _collapsed)
