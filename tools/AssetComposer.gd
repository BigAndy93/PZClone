extends Control
class_name AssetComposer

const ASSET_ROOT := "res://assets"
const LOCAL_SAVE_PATH := "user://asset_composer_structures.json"
const EXPORT_SAVE_PATH := "res://resources/map_templates/asset_composer_export.json"
const VALID_EXTENSIONS := ["png", "webp", "tscn", "tres", "res", "json", "ogg", "wav"]
const TYPE_BUILDING := "building_templates"
const TYPE_SCENE := "scenes"
const TYPE_CHUNK := "map_chunks"

var _asset_paths: Array[String] = []
var _structures: Dictionary = {
	TYPE_BUILDING: [],
	TYPE_SCENE: [],
	TYPE_CHUNK: []
}

var _current_type: String = TYPE_BUILDING
var _current_structure_index: int = -1
var _current_placement_index: int = -1

var _asset_filter_input: LineEdit
var _asset_list: ItemList
var _type_tabs: TabBar
var _structure_select: OptionButton
var _structure_name_input: LineEdit
var _structure_notes_input: LineEdit
var _placement_list: ItemList
var _placement_asset_label: Label
var _placement_layer_input: LineEdit
var _placement_unique_check: CheckBox
var _placement_x_input: SpinBox
var _placement_y_input: SpinBox
var _placement_z_input: SpinBox
var _placement_rotation_input: SpinBox
var _placement_scale_input: SpinBox
var _status_label: Label

func _ready() -> void:
	_build_ui()
	_refresh_asset_library()
	_load_from_disk(LOCAL_SAVE_PATH, false)
	if _structures[_current_type].is_empty():
		_add_structure()
	else:
		_select_structure(0)


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	var header := Label.new()
	header.text = "Asset Composer — Build Templates, Scenes, and Map Chunks"
	header.add_theme_font_size_override("font_size", 20)
	root.add_child(header)

	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330.0, 460.0)
	split.add_child(left)

	var asset_toolbar := HBoxContainer.new()
	left.add_child(asset_toolbar)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh Assets"
	refresh_btn.pressed.connect(_refresh_asset_library)
	asset_toolbar.add_child(refresh_btn)

	_asset_filter_input = LineEdit.new()
	_asset_filter_input.placeholder_text = "Filter assets..."
	_asset_filter_input.text_changed.connect(_apply_asset_filter)
	asset_toolbar.add_child(_asset_filter_input)

	_asset_list = ItemList.new()
	_asset_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_asset_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_asset_list)

	var add_asset_btn := Button.new()
	add_asset_btn.text = "Add Selected Asset To Structure"
	add_asset_btn.pressed.connect(_add_selected_asset_to_structure)
	left.add_child(add_asset_btn)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right)

	var top_row := HBoxContainer.new()
	right.add_child(top_row)

	_type_tabs = TabBar.new()
	_type_tabs.add_tab("Building Templates")
	_type_tabs.add_tab("Scenes")
	_type_tabs.add_tab("Map Chunks")
	_type_tabs.tab_changed.connect(_on_type_tab_changed)
	top_row.add_child(_type_tabs)

	_structure_select = OptionButton.new()
	_structure_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_structure_select.item_selected.connect(_select_structure)
	top_row.add_child(_structure_select)

	var add_structure_btn := Button.new()
	add_structure_btn.text = "+"
	add_structure_btn.tooltip_text = "Create structure"
	add_structure_btn.pressed.connect(_add_structure)
	top_row.add_child(add_structure_btn)

	var remove_structure_btn := Button.new()
	remove_structure_btn.text = "-"
	remove_structure_btn.tooltip_text = "Delete structure"
	remove_structure_btn.pressed.connect(_remove_structure)
	top_row.add_child(remove_structure_btn)

	var structure_meta := GridContainer.new()
	structure_meta.columns = 2
	right.add_child(structure_meta)

	structure_meta.add_child(Label.new())
	structure_meta.get_child(structure_meta.get_child_count() - 1).text = "Name"
	_structure_name_input = LineEdit.new()
	_structure_name_input.text_changed.connect(_on_structure_name_changed)
	structure_meta.add_child(_structure_name_input)

	structure_meta.add_child(Label.new())
	structure_meta.get_child(structure_meta.get_child_count() - 1).text = "Notes"
	_structure_notes_input = LineEdit.new()
	_structure_notes_input.text_changed.connect(_on_structure_notes_changed)
	structure_meta.add_child(_structure_notes_input)

	var center_split := HSplitContainer.new()
	center_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(center_split)

	_placement_list = ItemList.new()
	_placement_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_placement_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_placement_list.item_selected.connect(_on_placement_selected)
	center_split.add_child(_placement_list)

	var placement_editor := VBoxContainer.new()
	placement_editor.custom_minimum_size = Vector2(360.0, 320.0)
	center_split.add_child(placement_editor)

	_placement_asset_label = Label.new()
	_placement_asset_label.text = "Asset: (none)"
	_placement_asset_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	placement_editor.add_child(_placement_asset_label)

	var placement_grid := GridContainer.new()
	placement_grid.columns = 2
	placement_editor.add_child(placement_grid)

	_add_spin_row(placement_grid, "X", -512, 512, 1, func(v: float): _update_selected_placement_field("x", int(v)))
	_add_spin_row(placement_grid, "Y", -512, 512, 1, func(v: float): _update_selected_placement_field("y", int(v)))
	_add_spin_row(placement_grid, "Z", -32, 32, 1, func(v: float): _update_selected_placement_field("z", int(v)))
	_add_spin_row(placement_grid, "Rotation", -360, 360, 1, func(v: float): _update_selected_placement_field("rotation_deg", v))
	_add_spin_row(placement_grid, "Scale", 0.1, 8.0, 0.1, func(v: float): _update_selected_placement_field("scale", v))

	placement_grid.add_child(Label.new())
	placement_grid.get_child(placement_grid.get_child_count() - 1).text = "Layer"
	_placement_layer_input = LineEdit.new()
	_placement_layer_input.text_changed.connect(func(v: String): _update_selected_placement_field("layer", v))
	placement_grid.add_child(_placement_layer_input)

	placement_grid.add_child(Label.new())
	placement_grid.get_child(placement_grid.get_child_count() - 1).text = "Unique"
	_placement_unique_check = CheckBox.new()
	_placement_unique_check.toggled.connect(func(v: bool): _update_selected_placement_field("unique", v))
	placement_grid.add_child(_placement_unique_check)

	var placement_actions := HBoxContainer.new()
	placement_editor.add_child(placement_actions)

	var duplicate_btn := Button.new()
	duplicate_btn.text = "Duplicate"
	duplicate_btn.pressed.connect(_duplicate_selected_placement)
	placement_actions.add_child(duplicate_btn)

	var remove_btn := Button.new()
	remove_btn.text = "Remove"
	remove_btn.pressed.connect(_remove_selected_placement)
	placement_actions.add_child(remove_btn)

	var save_row := HBoxContainer.new()
	right.add_child(save_row)

	var save_local_btn := Button.new()
	save_local_btn.text = "Save Local"
	save_local_btn.pressed.connect(func(): _save_to_disk(LOCAL_SAVE_PATH))
	save_row.add_child(save_local_btn)

	var load_local_btn := Button.new()
	load_local_btn.text = "Load Local"
	load_local_btn.pressed.connect(func(): _load_from_disk(LOCAL_SAVE_PATH, true))
	save_row.add_child(load_local_btn)

	var export_btn := Button.new()
	export_btn.text = "Export For Map Generator"
	export_btn.pressed.connect(func(): _save_to_disk(EXPORT_SAVE_PATH))
	save_row.add_child(export_btn)

	_status_label = Label.new()
	_status_label.text = "Ready"
	right.add_child(_status_label)


func _add_spin_row(grid: GridContainer, title: String, min_v: float, max_v: float, step_v: float, callback: Callable) -> void:
	var label := Label.new()
	label.text = title
	grid.add_child(label)

	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step_v
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.value_changed.connect(callback)
	grid.add_child(spin)

	match title:
		"X": _placement_x_input = spin
		"Y": _placement_y_input = spin
		"Z": _placement_z_input = spin
		"Rotation": _placement_rotation_input = spin
		"Scale": _placement_scale_input = spin


func _refresh_asset_library() -> void:
	_asset_paths.clear()
	_scan_assets(ASSET_ROOT)
	_asset_paths.sort()
	_apply_asset_filter(_asset_filter_input.text if _asset_filter_input else "")
	_set_status("Loaded %d assets from %s" % [_asset_paths.size(), ASSET_ROOT])


func _scan_assets(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if entry.begins_with("."):
			continue
		var full_path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			_scan_assets(full_path)
			continue
		var ext := entry.get_extension().to_lower()
		if VALID_EXTENSIONS.has(ext):
			_asset_paths.append(full_path)
	dir.list_dir_end()


func _apply_asset_filter(filter_text: String) -> void:
	if _asset_list == null:
		return
	_asset_list.clear()
	var filter := filter_text.strip_edges().to_lower()
	for path in _asset_paths:
		if filter == "" or path.to_lower().contains(filter):
			_asset_list.add_item(path)


func _on_type_tab_changed(tab_index: int) -> void:
	match tab_index:
		0: _current_type = TYPE_BUILDING
		1: _current_type = TYPE_SCENE
		2: _current_type = TYPE_CHUNK
	_refresh_structure_selector()
	if _structures[_current_type].is_empty():
		_add_structure()
	else:
		_select_structure(0)


func _refresh_structure_selector() -> void:
	_structure_select.clear()
	var list: Array = _structures[_current_type]
	for i in list.size():
		var entry: Dictionary = list[i]
		_structure_select.add_item(entry.get("name", "Untitled"), i)


func _add_structure() -> void:
	var list: Array = _structures[_current_type]
	var new_index := list.size() + 1
	list.append({
		"id": "%s_%03d" % [_current_type, new_index],
		"name": "%s %d" % [_current_type.capitalize(), new_index],
		"notes": "",
		"placements": []
	})
	_structures[_current_type] = list
	_refresh_structure_selector()
	_select_structure(list.size() - 1)
	_set_status("Created structure")


func _remove_structure() -> void:
	var list: Array = _structures[_current_type]
	if list.is_empty() or _current_structure_index < 0 or _current_structure_index >= list.size():
		return
	list.remove_at(_current_structure_index)
	_structures[_current_type] = list
	_refresh_structure_selector()
	if list.is_empty():
		_current_structure_index = -1
		_update_structure_fields()
		_refresh_placement_list()
		_clear_placement_editor()
	else:
		_select_structure(clampi(_current_structure_index, 0, list.size() - 1))
	_set_status("Removed structure")


func _select_structure(index: int) -> void:
	_current_structure_index = index
	_structure_select.select(index)
	_update_structure_fields()
	_refresh_placement_list()
	_set_status("Selected structure %d" % index)


func _update_structure_fields() -> void:
	var structure := _current_structure()
	if structure.is_empty():
		_structure_name_input.text = ""
		_structure_notes_input.text = ""
		return
	_structure_name_input.text = structure.get("name", "")
	_structure_notes_input.text = structure.get("notes", "")


func _on_structure_name_changed(new_name: String) -> void:
	var structure := _current_structure()
	if structure.is_empty():
		return
	structure["name"] = new_name
	_set_current_structure(structure)
	_refresh_structure_selector()
	if _current_structure_index >= 0:
		_structure_select.select(_current_structure_index)


func _on_structure_notes_changed(new_notes: String) -> void:
	var structure := _current_structure()
	if structure.is_empty():
		return
	structure["notes"] = new_notes
	_set_current_structure(structure)


func _add_selected_asset_to_structure() -> void:
	var selected := _asset_list.get_selected_items()
	if selected.is_empty():
		_set_status("Select an asset first")
		return
	var structure := _current_structure()
	if structure.is_empty():
		_set_status("No structure selected")
		return
	var placement: Dictionary = {
		"asset": _asset_list.get_item_text(selected[0]),
		"x": 0,
		"y": 0,
		"z": 0,
		"rotation_deg": 0.0,
		"scale": 1.0,
		"layer": "default",
		"unique": false
	}
	var placements: Array = structure.get("placements", [])
	placements.append(placement)
	structure["placements"] = placements
	_set_current_structure(structure)
	_refresh_placement_list()
	_on_placement_selected(placements.size() - 1)
	_set_status("Added asset placement")


func _refresh_placement_list() -> void:
	_placement_list.clear()
	_current_placement_index = -1
	var structure := _current_structure()
	if structure.is_empty():
		return
	var placements: Array = structure.get("placements", [])
	for i in placements.size():
		var placement: Dictionary = placements[i]
		var asset := placement.get("asset", "")
		var leaf := asset.get_file()
		var coords := "(%d,%d,%d)" % [placement.get("x", 0), placement.get("y", 0), placement.get("z", 0)]
		_placement_list.add_item("%02d  %s  %s" % [i, leaf, coords])
	_clear_placement_editor()


func _on_placement_selected(index: int) -> void:
	_current_placement_index = index
	var placement := _current_placement()
	if placement.is_empty():
		_clear_placement_editor()
		return
	_placement_asset_label.text = "Asset: %s" % placement.get("asset", "")
	_placement_x_input.set_value_no_signal(float(placement.get("x", 0)))
	_placement_y_input.set_value_no_signal(float(placement.get("y", 0)))
	_placement_z_input.set_value_no_signal(float(placement.get("z", 0)))
	_placement_rotation_input.set_value_no_signal(float(placement.get("rotation_deg", 0.0)))
	_placement_scale_input.set_value_no_signal(float(placement.get("scale", 1.0)))
	_placement_layer_input.text = placement.get("layer", "default")
	_placement_unique_check.set_pressed_no_signal(bool(placement.get("unique", false)))


func _update_selected_placement_field(field: String, value: Variant) -> void:
	var structure := _current_structure()
	if structure.is_empty():
		return
	var placements: Array = structure.get("placements", [])
	if _current_placement_index < 0 or _current_placement_index >= placements.size():
		return
	var placement: Dictionary = placements[_current_placement_index]
	placement[field] = value
	placements[_current_placement_index] = placement
	structure["placements"] = placements
	_set_current_structure(structure)
	_refresh_placement_list()
	_placement_list.select(_current_placement_index)


func _duplicate_selected_placement() -> void:
	var structure := _current_structure()
	if structure.is_empty():
		return
	var placements: Array = structure.get("placements", [])
	if _current_placement_index < 0 or _current_placement_index >= placements.size():
		return
	var copy: Dictionary = (placements[_current_placement_index] as Dictionary).duplicate(true)
	copy["unique"] = true
	placements.append(copy)
	structure["placements"] = placements
	_set_current_structure(structure)
	_refresh_placement_list()
	_on_placement_selected(placements.size() - 1)
	_set_status("Duplicated placement as unique")


func _remove_selected_placement() -> void:
	var structure := _current_structure()
	if structure.is_empty():
		return
	var placements: Array = structure.get("placements", [])
	if _current_placement_index < 0 or _current_placement_index >= placements.size():
		return
	placements.remove_at(_current_placement_index)
	structure["placements"] = placements
	_set_current_structure(structure)
	_refresh_placement_list()
	_set_status("Removed placement")


func _clear_placement_editor() -> void:
	_placement_asset_label.text = "Asset: (none)"
	_placement_x_input.set_value_no_signal(0)
	_placement_y_input.set_value_no_signal(0)
	_placement_z_input.set_value_no_signal(0)
	_placement_rotation_input.set_value_no_signal(0)
	_placement_scale_input.set_value_no_signal(1)
	_placement_layer_input.text = ""
	_placement_unique_check.set_pressed_no_signal(false)


func _current_structure() -> Dictionary:
	var list: Array = _structures[_current_type]
	if _current_structure_index < 0 or _current_structure_index >= list.size():
		return {}
	return list[_current_structure_index]


func _set_current_structure(structure: Dictionary) -> void:
	var list: Array = _structures[_current_type]
	if _current_structure_index < 0 or _current_structure_index >= list.size():
		return
	list[_current_structure_index] = structure
	_structures[_current_type] = list


func _current_placement() -> Dictionary:
	var structure := _current_structure()
	if structure.is_empty():
		return {}
	var placements: Array = structure.get("placements", [])
	if _current_placement_index < 0 or _current_placement_index >= placements.size():
		return {}
	return placements[_current_placement_index]


func _save_to_disk(path: String) -> void:
	var payload := {
		"version": 1,
		"exported_at_unix": Time.get_unix_time_from_system(),
		"types": _structures
	}
	var json := JSON.stringify(payload, "\t", false)
	_ensure_parent_dir(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_set_status("Failed to write %s" % path)
		return
	file.store_string(json)
	_set_status("Saved %s" % path)


func _ensure_parent_dir(path: String) -> void:
	var parent := path.get_base_dir()
	if parent.is_empty():
		return
	if parent.begins_with("res://"):
		var d := DirAccess.open("res://")
		if d:
			d.make_dir_recursive(parent.trim_prefix("res://"))
		return
	if parent.begins_with("user://"):
		var u := DirAccess.open("user://")
		if u:
			u.make_dir_recursive(parent.trim_prefix("user://"))
		return
	DirAccess.make_dir_recursive_absolute(parent)


func _load_from_disk(path: String, show_status: bool) -> void:
	if not FileAccess.file_exists(path):
		if show_status:
			_set_status("File not found: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_set_status("Unable to open %s" % path)
		return
	var parsed := JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_set_status("Invalid JSON in %s" % path)
		return
	var incoming: Dictionary = parsed
	var incoming_types: Dictionary = incoming.get("types", {})
	for key in [TYPE_BUILDING, TYPE_SCENE, TYPE_CHUNK]:
		if incoming_types.has(key) and incoming_types[key] is Array:
			_structures[key] = incoming_types[key]
	_refresh_structure_selector()
	if _structures[_current_type].is_empty():
		_add_structure()
	else:
		_select_structure(0)
	if show_status:
		_set_status("Loaded %s" % path)


func _set_status(message: String) -> void:
	if _status_label:
		_status_label.text = message
	print("[AssetComposer] %s" % message)
