extends Control
class_name AssetComposer

const ASSET_ROOT := "res://assets"
const LOCAL_SAVE_PATH := "user://asset_composer_structures.json"
const EXPORT_SAVE_PATH := "res://resources/map_templates/asset_composer_export.json"
const IMPORT_ASSET_ROOT := "res://assets/imported"
const SPRITE_META_EXPORT_PATH := "res://resources/map_templates/asset_composer_sprite_metadata.json"
const VALID_EXTENSIONS := ["png", "webp", "tscn", "tres", "res", "json", "ogg", "wav"]
const SPRITE_EXTENSIONS := ["png", "webp"]
const TYPE_BUILDING := "building_templates"
const TYPE_SCENE := "scenes"
const TYPE_CHUNK := "map_chunks"
const IsoGridCanvasScript := preload("res://tools/IsoGridCanvas.gd")
const SpriteSheetOverlayScript := preload("res://tools/SpriteSheetOverlay.gd")
const ASSET_CATEGORIES := ["all", "favorites", "floors", "walls", "props", "doors_windows", "roof", "spritesheets", "other"]
const PAINT_TOOLS := ["select/move", "brush", "rectangle", "line", "fill", "eraser"]
## Directory under user:// where baked building / furniture textures are cached as PNGs.
const BAKED_CACHE_ROOT := "user://asset_baker_cache"
## Wall height tiers to pre-bake (should match World.warm() call).
const BAKED_MAX_H      := 4

var _asset_paths: Array[String] = []
var _structures: Dictionary = {
	TYPE_BUILDING: [],
	TYPE_SCENE: [],
	TYPE_CHUNK: []
}
var _sprite_metadata: Dictionary = {}
var _asset_favorites: Dictionary = {}
var _asset_tags: Dictionary = {}

var _current_type: String = TYPE_BUILDING
var _current_structure_index: int = -1
var _current_placement_index: int = -1
var _current_room_index: int = -1
var _current_furniture_index: int = -1
var _current_sprite_meta_asset: String = ""
var _suspend_ui_updates: bool = false

var _asset_filter_input: LineEdit
var _asset_category_select: OptionButton
var _asset_tag_input: LineEdit
var _asset_list: ItemList
var _type_tabs: TabBar
var _structure_select: OptionButton
var _structure_name_input: LineEdit
var _structure_notes_input: LineEdit
var _structure_category_input: LineEdit
var _structure_spawn_weight_input: SpinBox
var _structure_tags_input: LineEdit
var _structure_width_input: SpinBox
var _structure_depth_input: SpinBox
var _structure_floors_input: SpinBox
var _placement_list: ItemList
var _placement_asset_label: Label
var _placement_layer_input: LineEdit
var _placement_unique_check: CheckBox
var _placement_x_input: SpinBox
var _placement_y_input: SpinBox
var _placement_z_input: SpinBox
var _placement_rotation_input: SpinBox
var _placement_scale_input: SpinBox

var _room_list: ItemList
var _room_name_input: LineEdit
var _room_type_input: LineEdit
var _room_lighting_input: LineEdit
var _room_spawn_points_input: LineEdit
var _room_loot_table_input: LineEdit
var _room_x_input: SpinBox
var _room_y_input: SpinBox
var _room_w_input: SpinBox
var _room_h_input: SpinBox

var _furniture_list: ItemList
var _furniture_asset_label: Label
var _furniture_room_select: OptionButton
var _furniture_x_input: SpinBox
var _furniture_y_input: SpinBox
var _furniture_z_input: SpinBox
var _furniture_rotation_input: SpinBox

var _meta_asset_label: Label
var _meta_frame_w_input: SpinBox
var _meta_frame_h_input: SpinBox
var _meta_columns_input: SpinBox
var _meta_rows_input: SpinBox
var _meta_pivot_x_input: SpinBox
var _meta_pivot_y_input: SpinBox
var _meta_margin_input: SpinBox
var _meta_separation_input: SpinBox
var _meta_default_scale_input: SpinBox
var _meta_footprint_w_input: SpinBox
var _meta_footprint_h_input: SpinBox
var _meta_footprint_off_x_input: SpinBox
var _meta_footprint_off_y_input: SpinBox

var _generation_wall_asset_input: LineEdit
var _generation_floor_asset_input: LineEdit
var _generation_door_asset_input: LineEdit
var _generation_auto_furnish_check: CheckBox
var _validation_label: Label
var _status_label: Label
var _tutorial_dialog: AcceptDialog
var _iso_canvas
var _visual_layer_select: OptionButton
var _template_view_canvas
var _viewport_layer_select: OptionButton
var _paint_tool_select: OptionButton
var _viewport_paint_tool_select: OptionButton
var _paint_anchor_active: bool = false
var _paint_anchor_cell: Vector2i = Vector2i.ZERO
var _sheet_viewer_dialog: AcceptDialog
var _sheet_viewer_texture_rect: TextureRect
var _sheet_viewer_asset_label: Label
var _sheet_overlay
var _import_png_dialog: FileDialog

func _ready() -> void:
	_build_ui()
	await _warm_and_export_baked_assets()
	_refresh_asset_library()
	_load_from_disk(LOCAL_SAVE_PATH, false)
	if _structures[_current_type].is_empty():
		_add_structure()
	else:
		_select_structure(0)
	_set_status("Tip: Click Tutorial for a guided walkthrough and use Load Example to learn fast.")


func _build_ui() -> void:
	var safe_area := MarginContainer.new()
	safe_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe_area.add_theme_constant_override("margin_left", 8)
	safe_area.add_theme_constant_override("margin_top", 8)
	safe_area.add_theme_constant_override("margin_right", 8)
	safe_area.add_theme_constant_override("margin_bottom", 8)
	add_child(safe_area)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe_area.add_child(root)

	var header := Label.new()
	header.text = "Asset Composer - Sprite Metadata, Buildings, Rooms, and Furniture"
	header.add_theme_font_size_override("font_size", 20)
	root.add_child(header)

	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(360.0, 520.0)
	split.add_child(left)

	var asset_toolbar := HBoxContainer.new()
	left.add_child(asset_toolbar)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh Assets"
	refresh_btn.pressed.connect(_refresh_asset_library)
	asset_toolbar.add_child(refresh_btn)

	var import_png_btn := Button.new()
	import_png_btn.text = "Import PNG(s)"
	import_png_btn.pressed.connect(_open_import_png_dialog)
	asset_toolbar.add_child(import_png_btn)

	_asset_filter_input = LineEdit.new()
	_asset_filter_input.placeholder_text = "Filter assets..."
	_asset_filter_input.text_changed.connect(_apply_asset_filter)
	asset_toolbar.add_child(_asset_filter_input)

	_asset_category_select = OptionButton.new()
	for cat in ASSET_CATEGORIES:
		_asset_category_select.add_item(cat)
	_asset_category_select.item_selected.connect(_on_asset_category_changed)
	asset_toolbar.add_child(_asset_category_select)

	_asset_list = ItemList.new()
	_asset_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_asset_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_asset_list.gui_input.connect(_on_asset_list_gui_input)
	left.add_child(_asset_list)

	var asset_actions := HBoxContainer.new()
	left.add_child(asset_actions)

	var fav_btn := Button.new()
	fav_btn.text = "Toggle Favorite"
	fav_btn.pressed.connect(_toggle_selected_asset_favorite)
	asset_actions.add_child(fav_btn)

	_asset_tag_input = LineEdit.new()
	_asset_tag_input.placeholder_text = "Tag selected asset..."
	asset_actions.add_child(_asset_tag_input)

	var set_tag_btn := Button.new()
	set_tag_btn.text = "Set Tag"
	set_tag_btn.pressed.connect(_set_selected_asset_tag)
	asset_actions.add_child(set_tag_btn)

	var add_asset_btn := Button.new()
	add_asset_btn.text = "Add Selected Asset To Placements"
	add_asset_btn.pressed.connect(_add_selected_asset_to_structure)
	left.add_child(add_asset_btn)

	var meta_action_row := HBoxContainer.new()
	left.add_child(meta_action_row)

	var use_for_meta_btn := Button.new()
	use_for_meta_btn.text = "Use Selected For Sprite Metadata"
	use_for_meta_btn.pressed.connect(_select_asset_for_metadata)
	meta_action_row.add_child(use_for_meta_btn)

	var use_for_furniture_btn := Button.new()
	use_for_furniture_btn.text = "Use Selected For Furniture"
	use_for_furniture_btn.pressed.connect(_use_selected_asset_for_furniture)
	meta_action_row.add_child(use_for_furniture_btn)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(right_scroll)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size = Vector2(0.0, 1180.0)
	right_scroll.add_child(right)

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

	var action_row := HBoxContainer.new()
	right.add_child(action_row)

	var tutorial_btn := Button.new()
	tutorial_btn.text = "Tutorial"
	tutorial_btn.tooltip_text = "Open step-by-step instructions for building, rooms, furniture, and metadata."
	tutorial_btn.pressed.connect(_show_tutorial)
	action_row.add_child(tutorial_btn)

	var load_example_btn := Button.new()
	load_example_btn.text = "Load Example"
	load_example_btn.tooltip_text = "Create a sample building template with rooms and furniture so you can edit a working example."
	load_example_btn.pressed.connect(_load_example_template)
	action_row.add_child(load_example_btn)

	var save_local_btn := Button.new()
	save_local_btn.text = "Save Local"
	save_local_btn.pressed.connect(func(): _save_to_disk(LOCAL_SAVE_PATH))
	action_row.add_child(save_local_btn)

	var load_local_btn := Button.new()
	load_local_btn.text = "Load Local"
	load_local_btn.pressed.connect(func(): _load_from_disk(LOCAL_SAVE_PATH, true))
	action_row.add_child(load_local_btn)

	var export_btn := Button.new()
	export_btn.text = "Export For Map Generator"
	export_btn.pressed.connect(func(): _save_to_disk(EXPORT_SAVE_PATH))
	action_row.add_child(export_btn)

	var intro := Label.new()
	intro.text = "Quick start: Tutorial -> Load Example -> tweak rooms/furniture -> Save/Export"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(intro)

	_status_label = Label.new()
	_status_label.text = "Ready"
	right.add_child(_status_label)

	var right_tabs := TabContainer.new()
	right_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(right_tabs)

	var structure_tab := VBoxContainer.new()
	structure_tab.name = "Structure"
	right_tabs.add_child(structure_tab)

	var placement_root_tab := VBoxContainer.new()
	placement_root_tab.name = "Placement"
	right_tabs.add_child(placement_root_tab)

	var metadata_tab := VBoxContainer.new()
	metadata_tab.name = "Sprite Metadata"
	right_tabs.add_child(metadata_tab)

	var structure_meta := GridContainer.new()
	structure_meta.columns = 2
	structure_tab.add_child(structure_meta)

	structure_meta.add_child(_make_label("Name"))
	_structure_name_input = LineEdit.new()
	_structure_name_input.text_changed.connect(_on_structure_name_changed)
	structure_meta.add_child(_structure_name_input)

	structure_meta.add_child(_make_label("Notes"))
	_structure_notes_input = LineEdit.new()
	_structure_notes_input.text_changed.connect(_on_structure_notes_changed)
	structure_meta.add_child(_structure_notes_input)

	structure_meta.add_child(_make_label("Category"))
	_structure_category_input = LineEdit.new()
	_structure_category_input.text_changed.connect(_on_structure_category_changed)
	structure_meta.add_child(_structure_category_input)

	structure_meta.add_child(_make_label("Spawn Weight"))
	_structure_spawn_weight_input = SpinBox.new()
	_structure_spawn_weight_input.min_value = 0
	_structure_spawn_weight_input.max_value = 1000
	_structure_spawn_weight_input.step = 1
	_structure_spawn_weight_input.value_changed.connect(func(v: float): _on_structure_metadata_changed("spawn_weight", int(v)))
	structure_meta.add_child(_structure_spawn_weight_input)

	structure_meta.add_child(_make_label("Template Tags"))
	_structure_tags_input = LineEdit.new()
	_structure_tags_input.placeholder_text = "house, suburban"
	_structure_tags_input.text_changed.connect(func(v: String): _on_structure_metadata_changed("tags", v))
	structure_meta.add_child(_structure_tags_input)

	structure_meta.add_child(_make_label("Width (tiles)"))
	_structure_width_input = SpinBox.new()
	_structure_width_input.min_value = 2
	_structure_width_input.max_value = 256
	_structure_width_input.step = 1
	_structure_width_input.value_changed.connect(func(v: float): _on_structure_dimension_changed("width", int(v)))
	structure_meta.add_child(_structure_width_input)

	structure_meta.add_child(_make_label("Depth (tiles)"))
	_structure_depth_input = SpinBox.new()
	_structure_depth_input.min_value = 2
	_structure_depth_input.max_value = 256
	_structure_depth_input.step = 1
	_structure_depth_input.value_changed.connect(func(v: float): _on_structure_dimension_changed("depth", int(v)))
	structure_meta.add_child(_structure_depth_input)

	structure_meta.add_child(_make_label("Floors"))
	_structure_floors_input = SpinBox.new()
	_structure_floors_input.min_value = 1
	_structure_floors_input.max_value = 16
	_structure_floors_input.step = 1
	_structure_floors_input.value_changed.connect(func(v: float): _on_structure_dimension_changed("floors", int(v)))
	structure_meta.add_child(_structure_floors_input)

	var generation_group := VBoxContainer.new()
	structure_tab.add_child(generation_group)

	generation_group.add_child(_make_label("Procedural Generation Rules"))
	var generation_grid := GridContainer.new()
	generation_grid.columns = 2
	generation_group.add_child(generation_grid)

	generation_grid.add_child(_make_label("Wall Asset"))
	_generation_wall_asset_input = LineEdit.new()
	_generation_wall_asset_input.text_changed.connect(func(v: String): _on_generation_rule_changed("wall_asset", v))
	generation_grid.add_child(_generation_wall_asset_input)

	generation_grid.add_child(_make_label("Floor Asset"))
	_generation_floor_asset_input = LineEdit.new()
	_generation_floor_asset_input.text_changed.connect(func(v: String): _on_generation_rule_changed("floor_asset", v))
	generation_grid.add_child(_generation_floor_asset_input)

	generation_grid.add_child(_make_label("Door Asset"))
	_generation_door_asset_input = LineEdit.new()
	_generation_door_asset_input.text_changed.connect(func(v: String): _on_generation_rule_changed("door_asset", v))
	generation_grid.add_child(_generation_door_asset_input)

	generation_grid.add_child(_make_label("Auto Furnish"))
	_generation_auto_furnish_check = CheckBox.new()
	_generation_auto_furnish_check.toggled.connect(func(v: bool): _on_generation_rule_changed("auto_furnish", v))
	generation_grid.add_child(_generation_auto_furnish_check)

	var generation_actions := HBoxContainer.new()
	generation_group.add_child(generation_actions)

	var set_wall_btn := Button.new()
	set_wall_btn.text = "Set Wall = Selected"
	set_wall_btn.pressed.connect(func(): _assign_selected_asset_to_generation_field(_generation_wall_asset_input))
	generation_actions.add_child(set_wall_btn)

	var set_floor_btn := Button.new()
	set_floor_btn.text = "Set Floor = Selected"
	set_floor_btn.pressed.connect(func(): _assign_selected_asset_to_generation_field(_generation_floor_asset_input))
	generation_actions.add_child(set_floor_btn)

	var set_door_btn := Button.new()
	set_door_btn.text = "Set Door = Selected"
	set_door_btn.pressed.connect(func(): _assign_selected_asset_to_generation_field(_generation_door_asset_input))
	generation_actions.add_child(set_door_btn)

	var generate_btn := Button.new()
	generate_btn.text = "Generate / Regenerate Building Shell"
	generate_btn.pressed.connect(_generate_building_from_rules)
	generation_group.add_child(generate_btn)

	var validate_btn := Button.new()
	validate_btn.text = "Validate Template"
	validate_btn.pressed.connect(_validate_current_structure)
	generation_group.add_child(validate_btn)

	_validation_label = Label.new()
	_validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_validation_label.text = "Validation: not run"
	generation_group.add_child(_validation_label)

	var workspace_tabs := TabContainer.new()
	workspace_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	placement_root_tab.add_child(workspace_tabs)

	var placement_tab := VBoxContainer.new()
	placement_tab.name = "Canvas"
	workspace_tabs.add_child(placement_tab)

	var rooms_tab := VBoxContainer.new()
	rooms_tab.name = "Rooms & Furniture"
	workspace_tabs.add_child(rooms_tab)

	var viewport_tab := VBoxContainer.new()
	viewport_tab.name = "Viewport"
	workspace_tabs.add_child(viewport_tab)

	var placement_panel := VBoxContainer.new()
	placement_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	placement_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	placement_tab.add_child(placement_panel)

	placement_panel.add_child(_make_label("Visual Isometric Grid"))
	var visual_toolbar := HBoxContainer.new()
	placement_panel.add_child(visual_toolbar)

	var place_hint := Label.new()
	place_hint.text = "Tools: Select/Move, Brush, Rectangle, Line, Fill, Eraser"
	place_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visual_toolbar.add_child(place_hint)

	visual_toolbar.add_child(_make_label("Paint Layer"))
	_visual_layer_select = OptionButton.new()
	_visual_layer_select.add_item("floor")
	_visual_layer_select.add_item("wall")
	_visual_layer_select.add_item("prop")
	_visual_layer_select.add_item("roof")
	_visual_layer_select.add_item("collision")
	_visual_layer_select.add_item("metadata")
	_visual_layer_select.add_item("default")
	_visual_layer_select.item_selected.connect(_on_visual_layer_changed)
	visual_toolbar.add_child(_visual_layer_select)

	visual_toolbar.add_child(_make_label("Tool"))
	_paint_tool_select = OptionButton.new()
	for tool_name in PAINT_TOOLS:
		_paint_tool_select.add_item(tool_name)
	_paint_tool_select.item_selected.connect(_on_paint_tool_changed)
	visual_toolbar.add_child(_paint_tool_select)

	var zoom_out_btn := Button.new()
	zoom_out_btn.text = "Zoom -"
	zoom_out_btn.pressed.connect(_zoom_out_canvases)
	visual_toolbar.add_child(zoom_out_btn)
	var zoom_in_btn := Button.new()
	zoom_in_btn.text = "Zoom +"
	zoom_in_btn.pressed.connect(_zoom_in_canvases)
	visual_toolbar.add_child(zoom_in_btn)
	var zoom_reset_btn := Button.new()
	zoom_reset_btn.text = "1:1"
	zoom_reset_btn.pressed.connect(_zoom_reset_canvases)
	visual_toolbar.add_child(zoom_reset_btn)

	var set_layer_btn := Button.new()
	set_layer_btn.text = "Apply Layer"
	set_layer_btn.pressed.connect(_apply_visual_layer_to_selected)
	visual_toolbar.add_child(set_layer_btn)

	var open_sheet_btn := Button.new()
	open_sheet_btn.text = "Open SpriteSheet Viewer"
	open_sheet_btn.pressed.connect(_open_spritesheet_viewer)
	visual_toolbar.add_child(open_sheet_btn)

	var visual_frame := PanelContainer.new()
	visual_frame.custom_minimum_size = Vector2(500.0, 300.0)
	visual_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visual_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	placement_panel.add_child(visual_frame)

	_iso_canvas = IsoGridCanvasScript.new()
	_iso_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_iso_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_iso_canvas.place_requested.connect(_on_iso_place_requested)
	_iso_canvas.select_requested.connect(_on_iso_select_requested)
	_iso_canvas.move_requested.connect(_on_iso_move_requested)
	_iso_canvas.drag_finished.connect(_on_iso_drag_finished)
	_iso_canvas.drop_requested.connect(_on_iso_drop_requested)
	visual_frame.add_child(_iso_canvas)

	var viewport_help := Label.new()
	viewport_help.text = "Template Viewport: place, drag, and organize tiles/assets on a blank isometric grid."
	viewport_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	viewport_help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_tab.add_child(viewport_help)

	var viewport_toolbar := HBoxContainer.new()
	viewport_tab.add_child(viewport_toolbar)

	viewport_toolbar.add_child(_make_label("Layer"))
	_viewport_layer_select = OptionButton.new()
	_viewport_layer_select.add_item("floor")
	_viewport_layer_select.add_item("wall")
	_viewport_layer_select.add_item("prop")
	_viewport_layer_select.add_item("roof")
	_viewport_layer_select.add_item("collision")
	_viewport_layer_select.add_item("metadata")
	_viewport_layer_select.add_item("default")
	_viewport_layer_select.item_selected.connect(_on_viewport_layer_changed)
	viewport_toolbar.add_child(_viewport_layer_select)

	viewport_toolbar.add_child(_make_label("Tool"))
	_viewport_paint_tool_select = OptionButton.new()
	for tool_name in PAINT_TOOLS:
		_viewport_paint_tool_select.add_item(tool_name)
	_viewport_paint_tool_select.item_selected.connect(_on_viewport_paint_tool_changed)
	viewport_toolbar.add_child(_viewport_paint_tool_select)

	var viewport_zoom_out_btn := Button.new()
	viewport_zoom_out_btn.text = "Zoom -"
	viewport_zoom_out_btn.pressed.connect(_zoom_out_canvases)
	viewport_toolbar.add_child(viewport_zoom_out_btn)
	var viewport_zoom_in_btn := Button.new()
	viewport_zoom_in_btn.text = "Zoom +"
	viewport_zoom_in_btn.pressed.connect(_zoom_in_canvases)
	viewport_toolbar.add_child(viewport_zoom_in_btn)
	var viewport_zoom_reset_btn := Button.new()
	viewport_zoom_reset_btn.text = "1:1"
	viewport_zoom_reset_btn.pressed.connect(_zoom_reset_canvases)
	viewport_toolbar.add_child(viewport_zoom_reset_btn)

	if _paint_tool_select and _paint_tool_select.item_count > 1:
		_paint_tool_select.select(1)
	if _viewport_paint_tool_select and _viewport_paint_tool_select.item_count > 1:
		_viewport_paint_tool_select.select(1)

	var clear_placements_btn := Button.new()
	clear_placements_btn.text = "Clear Placements"
	clear_placements_btn.pressed.connect(_clear_current_placements)
	viewport_toolbar.add_child(clear_placements_btn)

	var viewport_validate_btn := Button.new()
	viewport_validate_btn.text = "Validate Template"
	viewport_validate_btn.pressed.connect(_validate_current_structure)
	viewport_toolbar.add_child(viewport_validate_btn)

	var viewport_sheet_btn := Button.new()
	viewport_sheet_btn.text = "Open SpriteSheet Viewer"
	viewport_sheet_btn.pressed.connect(_open_spritesheet_viewer)
	viewport_toolbar.add_child(viewport_sheet_btn)

	var viewport_frame := PanelContainer.new()
	viewport_frame.custom_minimum_size = Vector2(680.0, 420.0)
	viewport_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_tab.add_child(viewport_frame)

	_template_view_canvas = IsoGridCanvasScript.new()
	_template_view_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_template_view_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_template_view_canvas.place_requested.connect(_on_iso_place_requested)
	_template_view_canvas.select_requested.connect(_on_iso_select_requested)
	_template_view_canvas.move_requested.connect(_on_iso_move_requested)
	_template_view_canvas.drag_finished.connect(_on_iso_drag_finished)
	_template_view_canvas.drop_requested.connect(_on_iso_drop_requested)
	viewport_frame.add_child(_template_view_canvas)
	placement_panel.add_child(_make_label("Placements"))
	_placement_list = ItemList.new()
	_placement_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_placement_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_placement_list.item_selected.connect(_on_placement_selected)
	placement_panel.add_child(_placement_list)

	var placement_editor := VBoxContainer.new()
	placement_panel.add_child(placement_editor)
	_placement_asset_label = Label.new()
	_placement_asset_label.text = "Asset: (none)"
	_placement_asset_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	placement_editor.add_child(_placement_asset_label)

	var placement_grid := GridContainer.new()
	placement_grid.columns = 2
	placement_editor.add_child(placement_grid)

	_add_spin_row(placement_grid, "X", -1024, 1024, 1, func(v: float): _update_selected_placement_field("x", int(v)))
	_add_spin_row(placement_grid, "Y", -1024, 1024, 1, func(v: float): _update_selected_placement_field("y", int(v)))
	_add_spin_row(placement_grid, "Z", -32, 32, 1, func(v: float): _update_selected_placement_field("z", int(v)))
	_add_spin_row(placement_grid, "Rotation", -360, 360, 1, func(v: float): _update_selected_placement_field("rotation_deg", v))
	_add_spin_row(placement_grid, "Scale", 0.1, 8.0, 0.1, func(v: float): _update_selected_placement_field("scale", v))

	placement_grid.add_child(_make_label("Layer"))
	_placement_layer_input = LineEdit.new()
	_placement_layer_input.text_changed.connect(func(v: String): _update_selected_placement_field("layer", v))
	placement_grid.add_child(_placement_layer_input)

	placement_grid.add_child(_make_label("Unique"))
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

	var room_furn_panel := VBoxContainer.new()
	rooms_tab.add_child(room_furn_panel)

	room_furn_panel.add_child(_make_label("Rooms"))
	_room_list = ItemList.new()
	_room_list.custom_minimum_size = Vector2(300, 130)
	_room_list.item_selected.connect(_on_room_selected)
	room_furn_panel.add_child(_room_list)

	var room_actions := HBoxContainer.new()
	room_furn_panel.add_child(room_actions)
	var add_room_btn := Button.new()
	add_room_btn.text = "Add Room"
	add_room_btn.pressed.connect(_add_room)
	room_actions.add_child(add_room_btn)
	var remove_room_btn := Button.new()
	remove_room_btn.text = "Remove Room"
	remove_room_btn.pressed.connect(_remove_room)
	room_actions.add_child(remove_room_btn)

	var room_grid := GridContainer.new()
	room_grid.columns = 2
	room_furn_panel.add_child(room_grid)
	room_grid.add_child(_make_label("Room Name"))
	_room_name_input = LineEdit.new()
	_room_name_input.text_changed.connect(_on_room_name_changed)
	room_grid.add_child(_room_name_input)
	room_grid.add_child(_make_label("Room Type"))
	_room_type_input = LineEdit.new()
	_room_type_input.text_changed.connect(_on_room_type_changed)
	room_grid.add_child(_room_type_input)
	room_grid.add_child(_make_label("Lighting"))
	_room_lighting_input = LineEdit.new()
	_room_lighting_input.placeholder_text = "interior, dark"
	_room_lighting_input.text_changed.connect(func(v: String): _update_selected_room_field("lighting_type", v))
	room_grid.add_child(_room_lighting_input)
	room_grid.add_child(_make_label("Spawn Points"))
	_room_spawn_points_input = LineEdit.new()
	_room_spawn_points_input.placeholder_text = "zombie:2,npc:1"
	_room_spawn_points_input.text_changed.connect(func(v: String): _update_selected_room_field("spawn_points", v))
	room_grid.add_child(_room_spawn_points_input)
	room_grid.add_child(_make_label("Loot Table"))
	_room_loot_table_input = LineEdit.new()
	_room_loot_table_input.placeholder_text = "house_kitchen_basic"
	_room_loot_table_input.text_changed.connect(func(v: String): _update_selected_room_field("loot_table", v))
	room_grid.add_child(_room_loot_table_input)
	_add_room_spin_row(room_grid, "X", -1024, 1024, func(v: float): _update_selected_room_field("x", int(v)))
	_add_room_spin_row(room_grid, "Y", -1024, 1024, func(v: float): _update_selected_room_field("y", int(v)))
	_add_room_spin_row(room_grid, "W", 1, 256, func(v: float): _update_selected_room_field("w", int(v)))
	_add_room_spin_row(room_grid, "H", 1, 256, func(v: float): _update_selected_room_field("h", int(v)))

	room_furn_panel.add_child(_make_label("Furniture"))
	_furniture_list = ItemList.new()
	_furniture_list.custom_minimum_size = Vector2(300, 120)
	_furniture_list.item_selected.connect(_on_furniture_selected)
	room_furn_panel.add_child(_furniture_list)

	var furn_actions := HBoxContainer.new()
	room_furn_panel.add_child(furn_actions)
	var add_furn_btn := Button.new()
	add_furn_btn.text = "Add Furniture"
	add_furn_btn.pressed.connect(_add_furniture)
	furn_actions.add_child(add_furn_btn)
	var remove_furn_btn := Button.new()
	remove_furn_btn.text = "Remove Furniture"
	remove_furn_btn.pressed.connect(_remove_furniture)
	furn_actions.add_child(remove_furn_btn)

	_furniture_asset_label = Label.new()
	_furniture_asset_label.text = "Furniture Asset: (none)"
	_furniture_asset_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	room_furn_panel.add_child(_furniture_asset_label)

	var furniture_grid := GridContainer.new()
	furniture_grid.columns = 2
	room_furn_panel.add_child(furniture_grid)
	furniture_grid.add_child(_make_label("Room"))
	_furniture_room_select = OptionButton.new()
	_furniture_room_select.item_selected.connect(_on_furniture_room_selected)
	furniture_grid.add_child(_furniture_room_select)
	_add_furniture_spin_row(furniture_grid, "X", -1024, 1024, func(v: float): _update_selected_furniture_field("x", int(v)))
	_add_furniture_spin_row(furniture_grid, "Y", -1024, 1024, func(v: float): _update_selected_furniture_field("y", int(v)))
	_add_furniture_spin_row(furniture_grid, "Z", -32, 32, func(v: float): _update_selected_furniture_field("z", int(v)))
	_add_furniture_spin_row(furniture_grid, "Rotation", -360, 360, func(v: float): _update_selected_furniture_field("rotation_deg", v))

	var meta_group := VBoxContainer.new()
	metadata_tab.add_child(meta_group)
	meta_group.add_child(_make_label("Sprite-Sheet Metadata Editor"))
	_meta_asset_label = Label.new()
	_meta_asset_label.text = "Sprite Asset: (none selected)"
	_meta_asset_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta_group.add_child(_meta_asset_label)

	var meta_grid := GridContainer.new()
	meta_grid.columns = 4
	meta_group.add_child(meta_grid)
	_meta_frame_w_input = _make_meta_spin(meta_grid, "Frame W", 1, 2048, 1, func(v: float): _update_current_sprite_metadata("frame_w", int(v)))
	_meta_frame_h_input = _make_meta_spin(meta_grid, "Frame H", 1, 2048, 1, func(v: float): _update_current_sprite_metadata("frame_h", int(v)))
	_meta_columns_input = _make_meta_spin(meta_grid, "Columns", 1, 512, 1, func(v: float): _update_current_sprite_metadata("columns", int(v)))
	_meta_rows_input = _make_meta_spin(meta_grid, "Rows", 1, 512, 1, func(v: float): _update_current_sprite_metadata("rows", int(v)))
	_meta_pivot_x_input = _make_meta_spin(meta_grid, "Pivot X", -1024, 1024, 1, func(v: float): _update_current_sprite_metadata("pivot_x", int(v)))
	_meta_pivot_y_input = _make_meta_spin(meta_grid, "Pivot Y", -1024, 1024, 1, func(v: float): _update_current_sprite_metadata("pivot_y", int(v)))
	_meta_margin_input = _make_meta_spin(meta_grid, "Margin", 0, 256, 1, func(v: float): _update_current_sprite_metadata("margin", int(v)))
	_meta_separation_input = _make_meta_spin(meta_grid, "Separation", 0, 256, 1, func(v: float): _update_current_sprite_metadata("separation", int(v)))
	_meta_default_scale_input = _make_meta_spin(meta_grid, "Default Scale", 0.1, 8.0, 0.1, func(v: float): _update_current_sprite_metadata("scale", v))
	_meta_footprint_w_input = _make_meta_spin(meta_grid, "Footprint W (px)", 0, 512, 1, func(v: float): _update_current_sprite_metadata("footprint_w_px", int(v)))
	_meta_footprint_h_input = _make_meta_spin(meta_grid, "Footprint H (px)", 0, 512, 1, func(v: float): _update_current_sprite_metadata("footprint_h_px", int(v)))
	_meta_footprint_off_x_input = _make_meta_spin(meta_grid, "Footprint Off X", -512, 512, 1, func(v: float): _update_current_sprite_metadata("footprint_offset_x", int(v)))
	_meta_footprint_off_y_input = _make_meta_spin(meta_grid, "Footprint Off Y", -512, 512, 1, func(v: float): _update_current_sprite_metadata("footprint_offset_y", int(v)))

	var meta_actions := HBoxContainer.new()
	meta_group.add_child(meta_actions)

	var save_meta_btn := Button.new()
	save_meta_btn.text = "Save Sprite Metadata"
	save_meta_btn.pressed.connect(_save_sprite_metadata_export)
	meta_actions.add_child(save_meta_btn)

	var open_sheet_btn := Button.new()
	open_sheet_btn.text = "Open SpriteSheet Viewer"
	open_sheet_btn.pressed.connect(_open_spritesheet_viewer)
	meta_actions.add_child(open_sheet_btn)


	_build_tutorial_dialog()
	_build_spritesheet_viewer_dialog()
	_build_import_png_dialog()
	_apply_default_tooltips()
	_refresh_visual_canvas()
	_apply_paint_tool_mode()



func _build_tutorial_dialog() -> void:
	_tutorial_dialog = AcceptDialog.new()
	_tutorial_dialog.title = "Asset Composer Tutorial"
	_tutorial_dialog.dialog_text = ""
	_tutorial_dialog.min_size = Vector2i(760, 520)
	var body := RichTextLabel.new()
	body.fit_content = true
	body.scroll_active = true
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = _tutorial_text()
	_tutorial_dialog.add_child(body)
	add_child(_tutorial_dialog)


func _tutorial_text() -> String:
	return "".join([
		"Asset Composer Quick Tutorial\n\n",
		"1) Pick a structure type and create/select a template\n",
		"   - Use tabs: Building Templates, Scenes, Map Chunks.\n",
		"   - Give it a name, width/depth, and optional notes.\n\n",
		"2) Generate a shell (optional but recommended)\n",
		"   - Select assets on the left, then click Set Wall/Floor/Door = Selected.\n",
		"   - Click Generate / Regenerate Building Shell.\n",
		"   - You can still edit or add placements manually afterward.\n\n",
		"3) Define rooms\n",
		"   - Click Add Room.\n",
		"   - Set Room Name/Type and rectangle bounds (X/Y/W/H).\n",
		"   - Example rooms: kitchen, bedroom, bathroom, storage.\n\n",
		"4) Place furniture\n",
		"   - Click Add Furniture.\n",
		"   - Select a furniture asset on the left and click Use Selected For Furniture.\n",
		"   - Assign the furniture to a room from the Room dropdown.\n\n",
		"5) Import and edit sprite-sheet metadata\n",
		"   - Click Import PNG(s) to copy PNG/WEBP files into res://assets/imported (sidecar JSON auto-detected).\n",
		"   - Select a PNG/WEBP on the left and click Use Selected For Sprite Metadata.\n",
		"   - Fill frame size, rows/columns, pivot, margin, separation, and default scale.\n",
		"   - Click Save Sprite Metadata to export JSON for runtime/procedural systems.\n\n",
		"6) Save and export\n",
		"   - Save Local keeps your work in user://asset_composer_structures.json\n",
		"   - Export For Map Generator writes res://resources/map_templates/asset_composer_export.json\n\n",
		"Example workflow:\n",
		"Tutorial -> Load Example -> change room bounds -> reassign furniture -> Save Local -> Export\n"
	])


func _show_tutorial() -> void:
	if _tutorial_dialog:
		_tutorial_dialog.popup_centered_ratio(0.78)


func _load_example_template() -> void:
	var structure := _current_structure()
	if structure.is_empty():
		_add_structure()
		structure = _current_structure()
	if structure.is_empty():
		return

	var wall_asset := _find_first_asset_fragment("counter_sheet")
	if wall_asset == "":
		wall_asset = _find_first_asset_fragment("bookshelf_sheet")
	var floor_asset := _find_first_asset_fragment("chair_sheet")
	if floor_asset == "":
		floor_asset = _find_first_asset_fragment("side_table_sheet")
	var door_asset := _find_first_asset_fragment("locker_sheet")

	structure["name"] = "Example House Template"
	structure["notes"] = "Loaded from tutorial example. Edit rooms, furniture, and placements."
	structure["width"] = 12
	structure["depth"] = 10
	structure["floors"] = 1
	structure["template_metadata"] = {"category": "residential", "spawn_weight": 15, "tags": "example,house,tutorial"}
	structure["generation"] = {
		"wall_asset": wall_asset,
		"floor_asset": floor_asset,
		"door_asset": door_asset,
		"auto_furnish": false
	}
	structure["rooms"] = [
		{"id": "room_001", "name": "Kitchen", "type": "kitchen", "x": 1, "y": 1, "w": 4, "h": 4},
		{"id": "room_002", "name": "Living Room", "type": "living", "x": 5, "y": 1, "w": 6, "h": 4},
		{"id": "room_003", "name": "Bedroom", "type": "bedroom", "x": 1, "y": 5, "w": 6, "h": 4}
	]
	structure["furniture"] = [
		{"asset": _find_first_asset_fragment("dining_table_sheet"), "x": 2, "y": 2, "z": 0, "rotation_deg": 0.0, "room_id": "room_001"},
		{"asset": _find_first_asset_fragment("sofa_sheet"), "x": 7, "y": 2, "z": 0, "rotation_deg": 0.0, "room_id": "room_002"},
		{"asset": _find_first_asset_fragment("double_bed_sheet"), "x": 3, "y": 6, "z": 0, "rotation_deg": 0.0, "room_id": "room_003"}
	]
	_set_current_structure(structure)
	_generate_building_from_rules()
	_update_structure_fields()
	_refresh_room_list()
	_refresh_furniture_list()
	_set_status("Loaded tutorial example template. Start editing rooms/furniture now.")


func _find_first_asset_fragment(fragment: String) -> String:
	var needle := fragment.to_lower()
	for path in _asset_paths:
		if path.to_lower().contains(needle):
			return path
	return ""


func _apply_default_tooltips() -> void:
	_asset_filter_input.tooltip_text = "Filter the asset library list by filename/path."
	_asset_category_select.tooltip_text = "Category filter including Favorites."
	_asset_tag_input.tooltip_text = "Optional tag for selected asset."
	_asset_list.tooltip_text = "Select an asset, drag it onto the isometric grid, or use it for generation/furniture/metadata."
	_structure_select.tooltip_text = "Select which structure/template you are editing."
	_structure_name_input.tooltip_text = "Human-readable template name used in exports."
	_structure_notes_input.tooltip_text = "Freeform notes for design intent or generator hints."
	_structure_category_input.tooltip_text = "Template category, e.g. residential/commercial."
	_structure_spawn_weight_input.tooltip_text = "Spawn weighting used by procedural generation."
	_structure_tags_input.tooltip_text = "Comma-separated template tags."
	_structure_width_input.tooltip_text = "Structure width in tiles. Used by procedural shell generation."
	_structure_depth_input.tooltip_text = "Structure depth in tiles. Used by procedural shell generation."
	_structure_floors_input.tooltip_text = "Number of floors for this structure blueprint."
	_generation_wall_asset_input.tooltip_text = "Asset path used for perimeter walls when generating shell."
	_generation_floor_asset_input.tooltip_text = "Asset path used for interior floor tiles when generating shell."
	_generation_door_asset_input.tooltip_text = "Optional door asset placed at the front center."
	_generation_auto_furnish_check.tooltip_text = "If enabled, generator creates placeholder furniture anchors from rooms."
	_placement_list.tooltip_text = "All individual placements for this structure. Select one to edit coordinates/layer/scale."
	if _iso_canvas:
		_iso_canvas.tooltip_text = "Isometric viewport: drag assets from left list onto grid, use paint tools, zoom buttons, and press R to cycle sprite state."
	if _template_view_canvas:
		_template_view_canvas.tooltip_text = "Dedicated template viewport: drag/drop assets, zoom, and build templates on an empty isometric grid."
	if _viewport_layer_select:
		_viewport_layer_select.tooltip_text = "Paint layer for the Viewport tab (synced with Composer layer)."
	if _paint_tool_select:
		_paint_tool_select.tooltip_text = "Choose Select/Move, Brush, Rectangle, Line, Fill, or Eraser."
	if _viewport_paint_tool_select:
		_viewport_paint_tool_select.tooltip_text = "Same paint tool selector for the Viewport tab."
	_room_list.tooltip_text = "Room regions used for semantic layout and furniture grouping."
	_furniture_list.tooltip_text = "Furniture items with room assignment and transform."
	_furniture_room_select.tooltip_text = "Assign selected furniture item to a room."
	_meta_asset_label.tooltip_text = "Select a sprite on the left then click Use Selected For Sprite Metadata."
	_meta_frame_w_input.tooltip_text = "Frame width in pixels for spritesheet slicing."
	_meta_frame_h_input.tooltip_text = "Frame height in pixels for spritesheet slicing."
	_meta_columns_input.tooltip_text = "Number of sprite columns in the sheet."
	_meta_rows_input.tooltip_text = "Number of sprite rows in the sheet."
	_meta_pivot_x_input.tooltip_text = "Pivot X offset in pixels from frame origin."
	_meta_pivot_y_input.tooltip_text = "Pivot Y offset in pixels from frame origin."
	_meta_margin_input.tooltip_text = "Outer padding around the spritesheet in pixels."
	_meta_separation_input.tooltip_text = "Spacing between frames in pixels."
	_meta_default_scale_input.tooltip_text = "Default draw scale for this sprite (used by runtime/generator)."
	_meta_footprint_w_input.tooltip_text = "Imported isometric footprint width in pixels (from sidecar JSON diamond.w)."
	_meta_footprint_h_input.tooltip_text = "Imported isometric footprint height in pixels (from sidecar JSON diamond.h)."
	_meta_footprint_off_x_input.tooltip_text = "Footprint X offset in pixels from sidecar JSON."
	_meta_footprint_off_y_input.tooltip_text = "Footprint Y offset in pixels from sidecar JSON."

	var button_tips := {
		"Refresh Assets": "Rescan res://assets and refresh the library.",
		"Import PNG(s)": "Import PNG/WEBP files into res://assets/imported and auto-apply sidecar JSON metadata when found.",
		"Add Selected Asset To Placements": "Create a placement entry in the current structure using selected asset.",
		"Use Selected For Sprite Metadata": "Set selected PNG/WEBP as metadata target.",
		"Use Selected For Furniture": "Assign selected asset to currently selected furniture entry.",
		"Set Wall = Selected": "Assign selected asset as wall tile for generation.",
		"Set Floor = Selected": "Assign selected asset as floor tile for generation.",
		"Set Door = Selected": "Assign selected asset as door tile for generation.",
		"Generate / Regenerate Building Shell": "Replace placements with generated wall/floor/door shell based on rules.",
		"Duplicate": "Duplicate the selected placement as unique.",
		"Remove": "Remove the selected placement.",
		"Add Room": "Add a new room rectangle to this structure.",
		"Remove Room": "Delete selected room and unassign linked furniture.",
		"Add Furniture": "Add a furniture entry you can assign to room + asset.",
		"Remove Furniture": "Delete selected furniture entry.",
		"Tutorial": "Open step-by-step tutorial and examples.",
		"Load Example": "Populate current structure with a ready-to-edit example template.",
		"Save Local": "Save all data to user://asset_composer_structures.json",
		"Load Local": "Load data from user://asset_composer_structures.json",
		"Save Sprite Metadata": "Export sprite metadata JSON for runtime/procedural systems.",
		"Export For Map Generator": "Export JSON to res://resources/map_templates/asset_composer_export.json",
		"Apply Layer": "Apply current paint layer to selected placement or brush.",
		"Zoom -": "Zoom out in placement viewports.",
		"Zoom +": "Zoom in placement viewports.",
		"1:1": "Reset viewport zoom to default scale.",
		"Open SpriteSheet Viewer": "Open visual spritesheet viewer with frame grid overlay.",
		"Toggle Favorite": "Mark or unmark selected asset as favorite.",
		"Set Tag": "Apply tag text to selected asset for quick organization.",
		"Validate Template": "Run structural checks before saving/exporting.",
		"Clear Placements": "Reset the current template to an empty isometric grid."
	}
	_apply_button_tooltips(self, button_tips)


func _apply_button_tooltips(node: Node, tips: Dictionary) -> void:
	if node is Button:
		var btn := node as Button
		if tips.has(btn.text):
			btn.tooltip_text = str(tips[btn.text])
	for child in node.get_children():
		_apply_button_tooltips(child, tips)


func _selected_asset_path() -> String:
	var selected := _asset_list.get_selected_items()
	if selected.is_empty():
		return ""
	var idx := selected[0]
	var meta := _asset_list.get_item_metadata(idx)
	if meta == null:
		return ""
	return str(meta)


func _select_asset_in_list(asset_path: String) -> void:
	if _asset_list == null:
		return
	for i in _asset_list.item_count:
		var meta := _asset_list.get_item_metadata(i)
		if meta != null and str(meta) == asset_path:
			_asset_list.select(i)
			if _asset_list.has_method("ensure_current_is_visible"):
				_asset_list.ensure_current_is_visible()
			return

func _on_asset_list_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var idx := _asset_list.get_item_at_position(mb.position, true)
	if idx < 0:
		return
	_asset_list.select(idx)
	var meta := _asset_list.get_item_metadata(idx)
	if meta == null:
		return
	var asset_path := str(meta)
	if asset_path == "":
		return
	var preview := _make_asset_drag_preview(asset_path)
	_asset_list.force_drag({"asset_path": asset_path}, preview)


func _make_asset_drag_preview(asset_path: String) -> Control:
	var panel := PanelContainer.new()
	var label := Label.new()
	label.text = "Drop: %s" % asset_path.get_file()
	panel.add_child(label)
	return panel


func _zoom_in_canvases() -> void:
	if _iso_canvas and _iso_canvas.has_method("zoom_in"):
		_iso_canvas.zoom_in(0.15)
	if _template_view_canvas and _template_view_canvas.has_method("zoom_in"):
		_template_view_canvas.zoom_in(0.15)


func _zoom_out_canvases() -> void:
	if _iso_canvas and _iso_canvas.has_method("zoom_out"):
		_iso_canvas.zoom_out(0.15)
	if _template_view_canvas and _template_view_canvas.has_method("zoom_out"):
		_template_view_canvas.zoom_out(0.15)


func _zoom_reset_canvases() -> void:
	if _iso_canvas and _iso_canvas.has_method("set_zoom"):
		_iso_canvas.set_zoom(1.0)
	if _template_view_canvas and _template_view_canvas.has_method("set_zoom"):
		_template_view_canvas.set_zoom(1.0)


func _on_iso_drop_requested(cell: Vector2i, asset_path: String) -> void:
	if asset_path == "":
		return
	var layer := _current_paint_layer()
	_add_asset_at_cell(asset_path, cell.x, cell.y, layer)


func _state_count_for_asset(asset_path: String) -> int:
	var meta: Dictionary = _sprite_metadata.get(asset_path, {})
	if meta.is_empty():
		return 1
	var columns := max(1, int(meta.get("columns", 1)))
	var rows := max(1, int(meta.get("rows", 1)))
	return max(1, columns * rows)


func _state_label_for_asset(asset_path: String, state_index: int) -> String:
	var meta: Dictionary = _sprite_metadata.get(asset_path, {})
	if not meta.has("state_labels") or not (meta["state_labels"] is Array):
		return ""
	var labels: Array = meta["state_labels"]
	if state_index < 0 or state_index >= labels.size():
		return ""
	return str(labels[state_index])

func _cycle_selected_placement_state() -> bool:
	var structure := _current_structure()
	if structure.is_empty():
		return false
	var placements: Array = structure.get("placements", [])
	if _current_placement_index < 0 or _current_placement_index >= placements.size():
		return false
	var p: Dictionary = placements[_current_placement_index]
	var asset := str(p.get("asset", ""))
	var state_count := _state_count_for_asset(asset)
	if state_count <= 1:
		_set_status("Selected asset has no additional sprite states.")
		return false
	var current_state := int(p.get("sprite_state", 0))
	var next_state := posmod(current_state + 1, state_count)
	p["sprite_state"] = next_state
	placements[_current_placement_index] = p
	structure["placements"] = placements
	_set_current_structure(structure)
	_refresh_placement_list()
	_placement_list.select(_current_placement_index)
	_on_placement_selected(_current_placement_index)
	_refresh_visual_canvas()
	var state_label := _state_label_for_asset(asset, next_state)
	if state_label != "":
		_set_status("Sprite state: %d / %d (%s)" % [next_state + 1, state_count, state_label])
	else:
		_set_status("Sprite state: %d / %d" % [next_state + 1, state_count])
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_R:
		if _cycle_selected_placement_state():
			get_viewport().set_input_as_handled()


func _on_asset_category_changed(_index: int) -> void:
	_apply_asset_filter(_asset_filter_input.text)


func _toggle_selected_asset_favorite() -> void:
	var path := _selected_asset_path()
	if path == "":
		_set_status("Select an asset first")
		return
	if _asset_favorites.get(path, false):
		_asset_favorites.erase(path)
		_set_status("Removed favorite: %s" % path.get_file())
	else:
		_asset_favorites[path] = true
		_set_status("Marked favorite: %s" % path.get_file())
	_apply_asset_filter(_asset_filter_input.text)


func _set_selected_asset_tag() -> void:
	var path := _selected_asset_path()
	if path == "":
		_set_status("Select an asset first")
		return
	if _asset_tag_input == null:
		return
	var tag := _asset_tag_input.text.strip_edges()
	if tag == "":
		_asset_tags.erase(path)
		_set_status("Cleared tag on %s" % path.get_file())
	else:
		_asset_tags[path] = tag
		_set_status("Tagged %s as '%s'" % [path.get_file(), tag])
	_apply_asset_filter(_asset_filter_input.text)


func _asset_category(path: String) -> String:
	var p := path.to_lower()
	if p.contains("/floors/"):
		return "floors"
	if p.contains("/walls/"):
		return "walls"
	if p.contains("/door") or p.contains("/window"):
		return "doors_windows"
	if p.contains("/roof"):
		return "roof"
	if SPRITE_EXTENSIONS.has(path.get_extension().to_lower()):
		if p.contains("sheet") or p.contains("spritesheet"):
			return "spritesheets"
	if p.contains("/furniture/") or p.contains("/props/"):
		return "props"
	return "other"


func _asset_matches_category(path: String) -> bool:
	if _asset_category_select == null or _asset_category_select.selected < 0:
		return true
	var selected_category := _asset_category_select.get_item_text(_asset_category_select.selected)
	if selected_category == "all":
		return true
	if selected_category == "favorites":
		return bool(_asset_favorites.get(path, false))
	return _asset_category(path) == selected_category

func _on_visual_layer_changed(index: int) -> void:
	if _placement_layer_input == null or _visual_layer_select == null:
		return
	var layer_name := _visual_layer_select.get_item_text(index)
	_placement_layer_input.text = layer_name
	if _viewport_layer_select:
		for i in range(_viewport_layer_select.item_count):
			if _viewport_layer_select.get_item_text(i) == layer_name:
				_viewport_layer_select.select(i)
				break


func _on_viewport_layer_changed(index: int) -> void:
	if _viewport_layer_select == null:
		return
	var layer_name := _viewport_layer_select.get_item_text(index)
	if _visual_layer_select:
		for i in range(_visual_layer_select.item_count):
			if _visual_layer_select.get_item_text(i) == layer_name:
				_visual_layer_select.select(i)
				break
	if _placement_layer_input:
		_placement_layer_input.text = layer_name


func _on_paint_tool_changed(index: int) -> void:
	if _paint_tool_select == null:
		return
	var tool_name := _paint_tool_select.get_item_text(index)
	if _viewport_paint_tool_select:
		for i in range(_viewport_paint_tool_select.item_count):
			if _viewport_paint_tool_select.get_item_text(i) == tool_name:
				_viewport_paint_tool_select.select(i)
				break
	_apply_paint_tool_mode()
	_set_status("Paint tool: %s" % tool_name)


func _on_viewport_paint_tool_changed(index: int) -> void:
	if _viewport_paint_tool_select == null:
		return
	var tool_name := _viewport_paint_tool_select.get_item_text(index)
	if _paint_tool_select:
		for i in range(_paint_tool_select.item_count):
			if _paint_tool_select.get_item_text(i) == tool_name:
				_paint_tool_select.select(i)
				break
	_apply_paint_tool_mode()
	_set_status("Paint tool: %s" % tool_name)


func _current_paint_tool() -> String:
	if _paint_tool_select and _paint_tool_select.selected >= 0:
		return _paint_tool_select.get_item_text(_paint_tool_select.selected)
	return "select/move"


func _apply_paint_tool_mode() -> void:
	var allow_drag := _current_paint_tool() == "select/move"
	if _iso_canvas and _iso_canvas.has_method("set_drag_enabled"):
		_iso_canvas.set_drag_enabled(allow_drag)
	if _template_view_canvas and _template_view_canvas.has_method("set_drag_enabled"):
		_template_view_canvas.set_drag_enabled(allow_drag)
	if allow_drag:
		_paint_anchor_active = false


func _apply_visual_layer_to_selected() -> void:
	if _visual_layer_select == null:
		return
	var layer := _visual_layer_select.get_item_text(_visual_layer_select.selected)
	if _current_placement_index >= 0:
		_update_selected_placement_field("layer", layer)
	else:
		_placement_layer_input.text = layer
		_set_status("Layer brush set to %s" % layer)


func _clear_current_placements() -> void:
	var structure := _current_structure()
	if structure.is_empty():
		return
	structure["placements"] = []
	_set_current_structure(structure)
	_refresh_placement_list()
	_refresh_visual_canvas()
	_set_status("Cleared all placements in current template")

func _refresh_visual_canvas() -> void:
	var structure := _current_structure()
	if structure.is_empty():
		if _iso_canvas:
			_iso_canvas.set_placements([], -1)
		if _template_view_canvas:
			_template_view_canvas.set_placements([], -1)
		return
	var placements: Array = structure.get("placements", [])
	if _iso_canvas:
		_iso_canvas.set_placements(placements, _current_placement_index)
		_iso_canvas.set_sprite_metadata(_sprite_metadata)
	if _template_view_canvas:
		_template_view_canvas.set_placements(placements, _current_placement_index)
		_template_view_canvas.set_sprite_metadata(_sprite_metadata)


func _on_iso_place_requested(cell: Vector2i) -> void:
	_handle_paint_click(cell)


func _add_asset_at_cell(asset_path: String, x: int, y: int, layer: String) -> void:
	var structure := _current_structure()
	if structure.is_empty():
		return
	var placement: Dictionary = {
		"asset": asset_path,
		"x": x,
		"y": y,
		"z": 0,
		"rotation_deg": 0.0,
		"scale": 1.0,
		"layer": layer,
		"unique": false,
		"sprite_state": 0
	}
	var placements: Array = structure.get("placements", [])
	placements.append(placement)
	structure["placements"] = placements
	_set_current_structure(structure)
	_refresh_placement_list()
	_on_placement_selected(placements.size() - 1)
	_refresh_visual_canvas()
	_set_status("Placed asset at (%d,%d)" % [x, y])


func _on_iso_select_requested(index: int) -> void:
	var structure := _current_structure()
	if structure.is_empty():
		return
	var placements: Array = structure.get("placements", [])
	if index < 0 or index >= placements.size():
		return
	var p: Dictionary = placements[index]
	var cell := Vector2i(int(p.get("x", 0)), int(p.get("y", 0)))
	if _handle_paint_click(cell):
		return
	_on_placement_selected(index)
	_placement_list.select(index)
	_refresh_visual_canvas()


func _on_iso_move_requested(index: int, cell: Vector2i) -> void:
	if _current_paint_tool() != "select/move":
		return
	var structure := _current_structure()
	if structure.is_empty():
		return
	var placements: Array = structure.get("placements", [])
	if index < 0 or index >= placements.size():
		return
	var p: Dictionary = placements[index]
	if int(p.get("x", 0)) == cell.x and int(p.get("y", 0)) == cell.y:
		return
	p["x"] = cell.x
	p["y"] = cell.y
	placements[index] = p
	structure["placements"] = placements
	_set_current_structure(structure)
	_current_placement_index = index
	_placement_x_input.set_value_no_signal(cell.x)
	_placement_y_input.set_value_no_signal(cell.y)
	_refresh_visual_canvas()


func _on_iso_drag_finished(index: int) -> void:
	if _current_paint_tool() != "select/move":
		return
	var structure := _current_structure()
	if structure.is_empty():
		return
	var placements: Array = structure.get("placements", [])
	if index < 0 or index >= placements.size():
		return
	_refresh_placement_list()
	_placement_list.select(index)
	_on_placement_selected(index)
	_set_status("Moved placement to (%d,%d)" % [placements[index].get("x", 0), placements[index].get("y", 0)])

func _handle_paint_click(cell: Vector2i) -> bool:
	var tool := _current_paint_tool().to_lower()
	match tool:
		"select/move":
			return false
		"brush":
			return _paint_cells([cell])
		"eraser":
			return _erase_cells([cell])
		"rectangle":
			return _shape_paint_click(cell, true)
		"line":
			return _shape_paint_click(cell, false)
		"fill":
			return _fill_from_cell(cell)
		_:
			return false


func _shape_paint_click(cell: Vector2i, is_rectangle: bool) -> bool:
	if not _paint_anchor_active:
		_paint_anchor_active = true
		_paint_anchor_cell = cell
		_set_status("%s start at (%d,%d). Click end cell." % [("Rectangle" if is_rectangle else "Line"), cell.x, cell.y])
		return true
	var start := _paint_anchor_cell
	_paint_anchor_active = false
	var cells := (_rectangle_cells(start, cell) if is_rectangle else _line_cells(start, cell))
	return _paint_cells(cells)


func _current_paint_layer() -> String:
	if _visual_layer_select and _visual_layer_select.selected >= 0:
		return _visual_layer_select.get_item_text(_visual_layer_select.selected)
	if _placement_layer_input and _placement_layer_input.text.strip_edges() != "":
		return _placement_layer_input.text.strip_edges()
	return "default"


func _paint_cells(cells: Array) -> bool:
	var asset_path := _selected_asset_path()
	if asset_path == "":
		_set_status("Select an asset in the library first.")
		return true
	var structure := _current_structure()
	if structure.is_empty():
		return true
	var layer := _current_paint_layer()
	var placements: Array = structure.get("placements", [])
	var changed := 0
	for cell_v in cells:
		var cell: Vector2i = cell_v
		var found := -1
		for i in range(placements.size() - 1, -1, -1):
			var p: Dictionary = placements[i]
			if int(p.get("x", 0)) == cell.x and int(p.get("y", 0)) == cell.y and str(p.get("layer", "default")) == layer:
				found = i
				break
		if found >= 0:
			var existing: Dictionary = placements[found]
			existing["asset"] = asset_path
			placements[found] = existing
		else:
			placements.append({
				"asset": asset_path,
				"x": cell.x,
				"y": cell.y,
				"z": 0,
				"rotation_deg": 0.0,
				"scale": 1.0,
				"layer": layer,
				"unique": false,
				"sprite_state": 0
			})
		changed += 1
	structure["placements"] = placements
	_set_current_structure(structure)
	_refresh_placement_list()
	_refresh_visual_canvas()
	_set_status("Painted %d tile(s) on %s layer" % [changed, layer])
	return true


func _erase_cells(cells: Array) -> bool:
	var structure := _current_structure()
	if structure.is_empty():
		return true
	var layer := _current_paint_layer()
	var placements: Array = structure.get("placements", [])
	var remove_indices: Array[int] = []
	for cell_v in cells:
		var cell: Vector2i = cell_v
		var found_layer := false
		for i in range(placements.size() - 1, -1, -1):
			var p: Dictionary = placements[i]
			if int(p.get("x", 0)) == cell.x and int(p.get("y", 0)) == cell.y and str(p.get("layer", "default")) == layer:
				if not remove_indices.has(i):
					remove_indices.append(i)
				found_layer = true
		if not found_layer:
			for i in range(placements.size() - 1, -1, -1):
				var p_any: Dictionary = placements[i]
				if int(p_any.get("x", 0)) == cell.x and int(p_any.get("y", 0)) == cell.y:
					if not remove_indices.has(i):
						remove_indices.append(i)
					break
	if remove_indices.is_empty():
		_set_status("No placement found to erase at clicked cell.")
		return true
	remove_indices.sort()
	for j in range(remove_indices.size() - 1, -1, -1):
		placements.remove_at(remove_indices[j])
	structure["placements"] = placements
	_set_current_structure(structure)
	_refresh_placement_list()
	_refresh_visual_canvas()
	_set_status("Erased %d tile(s)" % remove_indices.size())
	return true


func _fill_from_cell(start_cell: Vector2i) -> bool:
	var structure := _current_structure()
	if structure.is_empty():
		return true
	var fill_asset := _selected_asset_path()
	if fill_asset == "":
		_set_status("Select an asset in the library first.")
		return true
	var layer := _current_paint_layer()
	var placements: Array = structure.get("placements", [])
	var layer_assets: Dictionary = {}
	for p_v in placements:
		var p: Dictionary = p_v
		if str(p.get("layer", "default")) != layer:
			continue
		var key := _cell_key(Vector2i(int(p.get("x", 0)), int(p.get("y", 0))))
		layer_assets[key] = str(p.get("asset", ""))
	var start_key := _cell_key(start_cell)
	if not layer_assets.has(start_key):
		_set_status("Fill starts on an existing tile in the current layer.")
		return true
	var target_asset := str(layer_assets[start_key])
	if target_asset == fill_asset:
		_set_status("Fill skipped: target region already uses selected asset.")
		return true
	var queue: Array = [start_cell]
	var visited: Dictionary = {}
	var fill_cells: Array = []
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var current_key := _cell_key(current)
		if visited.has(current_key):
			continue
		visited[current_key] = true
		if str(layer_assets.get(current_key, "")) != target_asset:
			continue
		fill_cells.append(current)
		queue.append(current + Vector2i(1, 0))
		queue.append(current + Vector2i(-1, 0))
		queue.append(current + Vector2i(0, 1))
		queue.append(current + Vector2i(0, -1))
	if fill_cells.is_empty():
		_set_status("Nothing to fill from selected start tile.")
		return true
	return _paint_cells(fill_cells)


func _rectangle_cells(a: Vector2i, b: Vector2i) -> Array:
	var out: Array = []
	for y in range(min(a.y, b.y), max(a.y, b.y) + 1):
		for x in range(min(a.x, b.x), max(a.x, b.x) + 1):
			out.append(Vector2i(x, y))
	return out


func _line_cells(a: Vector2i, b: Vector2i) -> Array:
	var out: Array = []
	var x0: int = a.x
	var y0: int = a.y
	var x1: int = b.x
	var y1: int = b.y
	var dx: int = abs(x1 - x0)
	var sx: int = 1 if x0 < x1 else -1
	var dy: int = -abs(y1 - y0)
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	while true:
		out.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return out


func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _build_spritesheet_viewer_dialog() -> void:
	_sheet_viewer_dialog = AcceptDialog.new()
	_sheet_viewer_dialog.title = "SpriteSheet Viewer"
	_sheet_viewer_dialog.min_size = Vector2i(980, 720)

	var root := VBoxContainer.new()
	_sheet_viewer_dialog.add_child(root)

	_sheet_viewer_asset_label = Label.new()
	_sheet_viewer_asset_label.text = "Asset: (none)"
	_sheet_viewer_asset_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_sheet_viewer_asset_label)

	var stack := Control.new()
	stack.custom_minimum_size = Vector2(920, 620)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(stack)

	_sheet_viewer_texture_rect = TextureRect.new()
	_sheet_viewer_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sheet_viewer_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sheet_viewer_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_sheet_viewer_texture_rect)

	_sheet_overlay = SpriteSheetOverlayScript.new()
	_sheet_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet_overlay.frame_selected.connect(_on_sheet_frame_selected)
	stack.add_child(_sheet_overlay)

	add_child(_sheet_viewer_dialog)


func _build_import_png_dialog() -> void:
	_import_png_dialog = FileDialog.new()
	_import_png_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_import_png_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	_import_png_dialog.title = "Import PNG/WEBP Sprite Assets (auto sidecar JSON metadata)"
	_import_png_dialog.filters = PackedStringArray(["*.png ; PNG Images", "*.webp ; WEBP Images"])
	_import_png_dialog.files_selected.connect(_on_import_png_files)
	add_child(_import_png_dialog)


func _open_import_png_dialog() -> void:
	if _import_png_dialog:
		_import_png_dialog.popup_centered_ratio(0.72)


func _on_import_png_files(paths: PackedStringArray) -> void:
	var imported_paths: Array[String] = []
	var metadata_applied := 0
	for src in paths:
		var source_path := str(src)
		var imported := _import_png_file(source_path)
		if imported != "":
			imported_paths.append(imported)
			_ensure_sprite_metadata_defaults(imported, true)
			if _apply_external_spritesheet_metadata(source_path, imported):
				metadata_applied += 1
	if imported_paths.is_empty():
		_set_status("No files imported.")
		return
	_refresh_asset_library()
	var first_imported := imported_paths[0]
	_select_asset_in_list(first_imported)
	_current_sprite_meta_asset = first_imported
	_refresh_sprite_metadata_editor()
	if metadata_applied > 0:
		_set_status("Imported %d file(s). Applied sidecar metadata for %d file(s)." % [imported_paths.size(), metadata_applied])
	else:
		_set_status("Imported %d file(s) into %s" % [imported_paths.size(), IMPORT_ASSET_ROOT])


func _import_png_file(source_path: String) -> String:
	if source_path == "" or not FileAccess.file_exists(source_path):
		return ""
	var file_name := source_path.get_file()
	if file_name == "":
		return ""
	var ext := file_name.get_extension().to_lower()
	if not SPRITE_EXTENSIONS.has(ext):
		return ""
	var base_name := file_name.get_basename().replace(" ", "_")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(IMPORT_ASSET_ROOT))
	var out_path := "%s/%s.%s" % [IMPORT_ASSET_ROOT, base_name, ext]
	var counter := 1
	while FileAccess.file_exists(out_path):
		out_path = "%s/%s_%d.%s" % [IMPORT_ASSET_ROOT, base_name, counter, ext]
		counter += 1
	var source_file := FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		return ""
	var bytes := source_file.get_buffer(source_file.get_length())
	source_file.close()
	var out_file := FileAccess.open(out_path, FileAccess.WRITE)
	if out_file == null:
		return ""
	out_file.store_buffer(bytes)
	out_file.close()
	return out_path


func _find_sidecar_spritesheet_json(source_image_path: String) -> String:
	var dir_path := source_image_path.get_base_dir()
	var base_no_ext := source_image_path.get_basename()
	var candidates: Array[String] = [
		"%s.json" % base_no_ext,
		"%s/spritesheet.json" % dir_path,
		"%s/sprite_sheet.json" % dir_path,
		"%s/metadata.json" % dir_path
	]
	for candidate in candidates:
		if FileAccess.file_exists(candidate):
			return candidate

	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if dir.current_is_dir() or entry.begins_with("."):
			continue
		if entry.get_extension().to_lower() != "json":
			continue
		var candidate_path := "%s/%s" % [dir_path, entry]
		var parsed := _read_json_dictionary(candidate_path)
		if _looks_like_external_spritesheet_json(parsed):
			dir.list_dir_end()
			return candidate_path
	dir.list_dir_end()
	return ""


func _read_json_dictionary(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var raw_text := file.get_as_text()
	file.close()
	var parsed := JSON.parse_string(raw_text)
	if parsed is Dictionary:
		return parsed
	return {}


func _looks_like_external_spritesheet_json(payload: Dictionary) -> bool:
	if payload.is_empty():
		return false
	if not payload.has("tiles") or not (payload["tiles"] is Array):
		return false
	return payload.has("tileW") or payload.has("tileH") or payload.has("cols") or payload.has("rows")


func _apply_external_spritesheet_metadata(source_image_path: String, imported_asset_path: String) -> bool:
	var json_path := _find_sidecar_spritesheet_json(source_image_path)
	if json_path == "":
		return false
	var payload := _read_json_dictionary(json_path)
	if not _looks_like_external_spritesheet_json(payload):
		return false

	_ensure_sprite_metadata_defaults(imported_asset_path, true)
	var meta: Dictionary = _sprite_metadata.get(imported_asset_path, {})
	var tiles: Array = payload.get("tiles", [])
	var frame_w := max(1, int(payload.get("tileW", meta.get("frame_w", 32))))
	var frame_h := max(1, int(payload.get("tileH", meta.get("frame_h", 32))))
	var columns := max(1, int(payload.get("cols", payload.get("columns", meta.get("columns", 1)))))
	var rows := max(1, int(payload.get("rows", meta.get("rows", 1))) )

	meta["frame_w"] = frame_w
	meta["frame_h"] = frame_h
	meta["columns"] = columns
	meta["rows"] = rows
	meta["margin"] = _infer_sheet_margin(tiles)
	meta["separation"] = _infer_sheet_separation(tiles, frame_w, frame_h)

	if not tiles.is_empty() and tiles[0] is Dictionary:
		var first_tile: Dictionary = tiles[0]
		if first_tile.has("pivot") and first_tile["pivot"] is Dictionary:
			var pivot_data: Dictionary = first_tile["pivot"]
			var pivot_x_px := int(pivot_data.get("x", int(frame_w * 0.5)))
			var pivot_y_px := int(pivot_data.get("y", frame_h))
			meta["pivot_x"] = pivot_x_px - int(frame_w * 0.5)
			meta["pivot_y"] = pivot_y_px - frame_h

	if payload.has("diamond") and payload["diamond"] is Dictionary:
		var diamond: Dictionary = payload["diamond"]
		meta["diamond_enabled"] = bool(diamond.get("enabled", false))
		meta["footprint_w_px"] = max(0, int(diamond.get("w", 0)))
		meta["footprint_h_px"] = max(0, int(diamond.get("h", 0)))
		meta["footprint_offset_x"] = int(diamond.get("offsetX", 0))
		meta["footprint_offset_y"] = int(diamond.get("offsetY", 0))
		if int(meta.get("footprint_w_px", 0)) > 0:
			meta["footprint_tiles_w"] = float(meta.get("footprint_w_px", 0)) / 64.0
		if int(meta.get("footprint_h_px", 0)) > 0:
			meta["footprint_tiles_h"] = float(meta.get("footprint_h_px", 0)) / 32.0

	if payload.has("template"):
		meta["source_template"] = str(payload.get("template", ""))
	meta["source_metadata_json"] = json_path

	var state_labels: Array[String] = []
	var state_count := max(1, columns * rows)
	state_labels.resize(state_count)
	for i in state_labels.size():
		state_labels[i] = ""
	for tile_data in tiles:
		if tile_data is Dictionary:
			var tile: Dictionary = tile_data
			var idx := int(tile.get("index", -1))
			if idx >= 0 and idx < state_labels.size():
				state_labels[idx] = str(tile.get("label", ""))
	var has_labels := false
	for label in state_labels:
		if label != "":
			has_labels = true
			break
	if has_labels:
		meta["state_labels"] = state_labels

	_sprite_metadata[imported_asset_path] = meta
	return true


func _infer_sheet_margin(tiles: Array) -> int:
	if tiles.is_empty():
		return 0
	var min_x := 2147483647
	var min_y := 2147483647
	for tile_data in tiles:
		if tile_data is Dictionary:
			var tile: Dictionary = tile_data
			min_x = min(min_x, int(tile.get("x", 0)))
			min_y = min(min_y, int(tile.get("y", 0)))
	if min_x == 2147483647 or min_y == 2147483647:
		return 0
	return max(0, min(min_x, min_y))


func _infer_sheet_separation(tiles: Array, frame_w: int, frame_h: int) -> int:
	if tiles.size() < 2:
		return 0
	var xs: Array[int] = []
	var ys: Array[int] = []
	for tile_data in tiles:
		if tile_data is Dictionary:
			var tile: Dictionary = tile_data
			var x := int(tile.get("x", 0))
			var y := int(tile.get("y", 0))
			if not xs.has(x):
				xs.append(x)
			if not ys.has(y):
				ys.append(y)
	xs.sort()
	ys.sort()
	var sep_x := 0
	var sep_y := 0
	if xs.size() >= 2:
		sep_x = max(0, xs[1] - xs[0] - frame_w)
	if ys.size() >= 2:
		sep_y = max(0, ys[1] - ys[0] - frame_h)
	return max(sep_x, sep_y)


func _ensure_sprite_metadata_defaults(asset_path: String, use_image_size: bool = false) -> void:
	var defaults := {
		"frame_w": 32,
		"frame_h": 32,
		"columns": 1,
		"rows": 1,
		"pivot_x": 0,
		"pivot_y": 0,
		"margin": 0,
		"separation": 0,
		"scale": 1.0,
		"diamond_enabled": false,
		"footprint_w_px": 0,
		"footprint_h_px": 0,
		"footprint_offset_x": 0,
		"footprint_offset_y": 0,
		"footprint_tiles_w": 0.0,
		"footprint_tiles_h": 0.0
	}
	if use_image_size:
		var img := Image.new()
		var err := img.load(ProjectSettings.globalize_path(asset_path))
		if err == OK and img.get_width() > 0 and img.get_height() > 0:
			defaults["frame_w"] = img.get_width()
			defaults["frame_h"] = img.get_height()
	if not _sprite_metadata.has(asset_path):
		_sprite_metadata[asset_path] = defaults
		return
	var meta: Dictionary = _sprite_metadata.get(asset_path, {})
	for key in defaults.keys():
		if not meta.has(key):
			meta[key] = defaults[key]
	_sprite_metadata[asset_path] = meta


func _save_sprite_metadata_export() -> void:
	var payload := {
		"version": 1,
		"exported_at_unix": Time.get_unix_time_from_system(),
		"sprite_metadata": _sprite_metadata
	}
	var parent_dir := SPRITE_META_EXPORT_PATH.get_base_dir()
	if parent_dir != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(parent_dir))
	var file := FileAccess.open(SPRITE_META_EXPORT_PATH, FileAccess.WRITE)
	if file == null:
		_set_status("Failed to write %s" % SPRITE_META_EXPORT_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t", false))
	file.close()
	_set_status("Saved %s" % SPRITE_META_EXPORT_PATH)

func _open_spritesheet_viewer() -> void:
	var selected := _asset_list.get_selected_items()
	if not selected.is_empty():
		var path := _selected_asset_path()
		if SPRITE_EXTENSIONS.has(path.get_extension().to_lower()):
			_current_sprite_meta_asset = path
	if _current_sprite_meta_asset == "":
		_set_status("Select a PNG/WEBP asset first or choose one for sprite metadata.")
		return
	_refresh_sprite_metadata_editor()
	_refresh_spritesheet_viewer()
	if _sheet_viewer_dialog:
		_sheet_viewer_dialog.popup_centered_ratio(0.9)


func _refresh_spritesheet_viewer() -> void:
	if _sheet_viewer_dialog == null or _sheet_overlay == null:
		return
	if _current_sprite_meta_asset == "":
		_sheet_viewer_asset_label.text = "Asset: (none)"
		_sheet_viewer_texture_rect.texture = null
		_sheet_overlay.set_texture(null)
		return
	var tex: Texture2D = null
	if ResourceLoader.exists(_current_sprite_meta_asset):
		tex = load(_current_sprite_meta_asset) as Texture2D
	_sheet_viewer_asset_label.text = "Asset: %s" % _current_sprite_meta_asset
	_sheet_viewer_texture_rect.texture = tex
	_sheet_overlay.set_texture(tex)
	_sheet_overlay.configure(_sprite_metadata.get(_current_sprite_meta_asset, {}))


func _on_sheet_frame_selected(index: int, col: int, row: int) -> void:
	_set_status("Sprite frame selected: index %d (col %d, row %d)" % [index, col, row])

func _make_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	return label


func _add_spin_row(grid: GridContainer, title: String, min_v: float, max_v: float, step_v: float, callback: Callable) -> void:
	grid.add_child(_make_label(title))
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


func _add_room_spin_row(grid: GridContainer, title: String, min_v: float, max_v: float, callback: Callable) -> void:
	grid.add_child(_make_label(title))
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = 1
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.value_changed.connect(callback)
	grid.add_child(spin)

	match title:
		"X": _room_x_input = spin
		"Y": _room_y_input = spin
		"W": _room_w_input = spin
		"H": _room_h_input = spin


func _add_furniture_spin_row(grid: GridContainer, title: String, min_v: float, max_v: float, callback: Callable) -> void:
	grid.add_child(_make_label(title))
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = 1
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.value_changed.connect(callback)
	grid.add_child(spin)

	match title:
		"X": _furniture_x_input = spin
		"Y": _furniture_y_input = spin
		"Z": _furniture_z_input = spin
		"Rotation": _furniture_rotation_input = spin


func _make_meta_spin(grid: GridContainer, title: String, min_v: float, max_v: float, step_v: float, callback: Callable) -> SpinBox:
	grid.add_child(_make_label(title))
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step_v
	spin.value_changed.connect(callback)
	grid.add_child(spin)
	return spin


## Warms baker systems and ensures baked-cache directories exist before scanning assets.
func _warm_and_export_baked_assets() -> void:
	if BuildingComponentBaker != null and BuildingComponentBaker.has_method("warm"):
		await BuildingComponentBaker.warm(BAKED_MAX_H)
	if FurnitureBaker != null and FurnitureBaker.has_method("warm_batch") and FurnitureLibrary != null:
		await FurnitureBaker.warm_batch(FurnitureLibrary.get_box_specs(), FurnitureLibrary.get_flat_specs())

	for subdir: String in ["floors", "walls", "doors", "windows", "furniture"]:
		DirAccess.make_dir_recursive_absolute(BAKED_CACHE_ROOT + "/" + subdir)


func _refresh_asset_library() -> void:
	_asset_paths.clear()
	_scan_assets(ASSET_ROOT)
	_scan_assets(BAKED_CACHE_ROOT)
	_asset_paths.sort()
	if _asset_category_select and _asset_category_select.item_count == 0:
		for cat in ASSET_CATEGORIES:
			_asset_category_select.add_item(cat)
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
		if filter != "" and not path.to_lower().contains(filter):
			continue
		if not _asset_matches_category(path):
			continue
		var label := path
		if bool(_asset_favorites.get(path, false)):
			label = "[fav] %s" % label
		var tag := str(_asset_tags.get(path, "")).strip_edges()
		if tag != "":
			label = "%s  [tag:%s]" % [label, tag]
		_asset_list.add_item(label)
		_asset_list.set_item_metadata(_asset_list.item_count - 1, path)


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


func _default_structure(new_index: int) -> Dictionary:
	return {
		"id": "%s_%03d" % [_current_type, new_index],
		"name": "%s %d" % [_current_type.capitalize(), new_index],
		"notes": "",
		"width": 10,
		"depth": 10,
		"floors": 1,
		"template_metadata": {
			"category": "residential",
			"spawn_weight": 10,
			"tags": ""
		},
		"generation": {
			"wall_asset": "",
			"floor_asset": "",
			"door_asset": "",
			"auto_furnish": false
		},
		"rooms": [],
		"furniture": [],
		"placements": []
	}


func _normalize_structure(structure: Dictionary, fallback_index: int) -> Dictionary:
	var out := structure.duplicate(true)
	if not out.has("id"):
		out["id"] = "%s_%03d" % [_current_type, fallback_index]
	if not out.has("name"):
		out["name"] = "Structure %d" % fallback_index
	if not out.has("notes"):
		out["notes"] = ""
	if not out.has("width"):
		out["width"] = 10
	if not out.has("depth"):
		out["depth"] = 10
	if not out.has("floors"):
		out["floors"] = 1
	if not out.has("placements") or not (out["placements"] is Array):
		out["placements"] = []
	var normalized_placements: Array = []
	for placement_variant in out["placements"]:
		var placement_dict: Dictionary = placement_variant
		if not placement_dict.has("sprite_state"):
			placement_dict["sprite_state"] = 0
		normalized_placements.append(placement_dict)
	out["placements"] = normalized_placements
	if not out.has("rooms") or not (out["rooms"] is Array):
		out["rooms"] = []
	var normalized_rooms: Array = []
	for room_variant in out["rooms"]:
		var room_dict: Dictionary = room_variant
		if not room_dict.has("lighting_type"):
			room_dict["lighting_type"] = "interior"
		if not room_dict.has("spawn_points"):
			room_dict["spawn_points"] = ""
		if not room_dict.has("loot_table"):
			room_dict["loot_table"] = ""
		normalized_rooms.append(room_dict)
	out["rooms"] = normalized_rooms
	if not out.has("furniture") or not (out["furniture"] is Array):
		out["furniture"] = []
	if not out.has("template_metadata") or not (out["template_metadata"] is Dictionary):
		out["template_metadata"] = {}
	var template_meta: Dictionary = out["template_metadata"]
	if not template_meta.has("category"):
		template_meta["category"] = "residential"
	if not template_meta.has("spawn_weight"):
		template_meta["spawn_weight"] = 10
	if not template_meta.has("tags"):
		template_meta["tags"] = ""
	template_meta["size"] = "%dx%d" % [int(out.get("width", 0)), int(out.get("depth", 0))]
	template_meta["room_count"] = (out.get("rooms", []) as Array).size()
	out["template_metadata"] = template_meta
	if not out.has("generation") or not (out["generation"] is Dictionary):
		out["generation"] = {}
	var generation: Dictionary = out["generation"]
	if not generation.has("wall_asset"):
		generation["wall_asset"] = ""
	if not generation.has("floor_asset"):
		generation["floor_asset"] = ""
	if not generation.has("door_asset"):
		generation["door_asset"] = ""
	if not generation.has("auto_furnish"):
		generation["auto_furnish"] = false
	out["generation"] = generation
	return out

func _add_structure() -> void:
	var list: Array = _structures[_current_type]
	var new_index := list.size() + 1
	list.append(_default_structure(new_index))
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
		_refresh_room_list()
		_refresh_furniture_list()
		_clear_placement_editor()
		_clear_room_editor()
		_clear_furniture_editor()
	else:
		_select_structure(clampi(_current_structure_index, 0, list.size() - 1))
	_set_status("Removed structure")


func _select_structure(index: int) -> void:
	var list: Array = _structures[_current_type]
	if index < 0 or index >= list.size():
		return
	_current_structure_index = index
	_structure_select.select(index)
	_update_structure_fields()
	_refresh_placement_list()
	_refresh_room_list()
	_refresh_furniture_list()
	_set_status("Selected structure %d" % index)


func _update_structure_fields() -> void:
	var structure := _current_structure()
	_suppress_ui(true)
	if structure.is_empty():
		_structure_name_input.text = ""
		_structure_notes_input.text = ""
		_structure_category_input.text = ""
		_structure_spawn_weight_input.set_value_no_signal(10)
		_structure_tags_input.text = ""
		_structure_width_input.set_value_no_signal(10)
		_structure_depth_input.set_value_no_signal(10)
		_structure_floors_input.set_value_no_signal(1)
		_generation_wall_asset_input.text = ""
		_generation_floor_asset_input.text = ""
		_generation_door_asset_input.text = ""
		_generation_auto_furnish_check.set_pressed_no_signal(false)
		_suppress_ui(false)
		return
	_structure_name_input.text = structure.get("name", "")
	_structure_notes_input.text = structure.get("notes", "")
	var template_meta: Dictionary = structure.get("template_metadata", {})
	_structure_category_input.text = template_meta.get("category", "residential")
	_structure_spawn_weight_input.set_value_no_signal(float(template_meta.get("spawn_weight", 10)))
	_structure_tags_input.text = template_meta.get("tags", "")
	_structure_width_input.set_value_no_signal(float(structure.get("width", 10)))
	_structure_depth_input.set_value_no_signal(float(structure.get("depth", 10)))
	_structure_floors_input.set_value_no_signal(float(structure.get("floors", 1)))
	var generation: Dictionary = structure.get("generation", {})
	_generation_wall_asset_input.text = generation.get("wall_asset", "")
	_generation_floor_asset_input.text = generation.get("floor_asset", "")
	_generation_door_asset_input.text = generation.get("door_asset", "")
	_generation_auto_furnish_check.set_pressed_no_signal(bool(generation.get("auto_furnish", false)))
	_suppress_ui(false)


func _on_structure_name_changed(new_name: String) -> void:
	if _suspend_ui_updates:
		return
	var structure := _current_structure()
	if structure.is_empty():
		return
	structure["name"] = new_name
	_set_current_structure(structure)
	_refresh_structure_selector()
	if _current_structure_index >= 0:
		_structure_select.select(_current_structure_index)


func _on_structure_notes_changed(new_notes: String) -> void:
	if _suspend_ui_updates:
		return
	var structure := _current_structure()
	if structure.is_empty():
		return
	structure["notes"] = new_notes
	_set_current_structure(structure)


func _on_structure_category_changed(value: String) -> void:
	_on_structure_metadata_changed("category", value)


func _on_structure_metadata_changed(field: String, value: Variant) -> void:
	if _suspend_ui_updates:
		return
	var structure := _current_structure()
	if structure.is_empty():
		return
	var template_meta: Dictionary = structure.get("template_metadata", {})
	template_meta[field] = value
	structure["template_metadata"] = template_meta
	_set_current_structure(structure)

func _on_structure_dimension_changed(field: String, value: int) -> void:
	if _suspend_ui_updates:
		return
	var structure := _current_structure()
	if structure.is_empty():
		return
	structure[field] = value
	_set_current_structure(structure)


func _on_generation_rule_changed(field: String, value: Variant) -> void:
	if _suspend_ui_updates:
		return
	var structure := _current_structure()
	if structure.is_empty():
		return
	var generation: Dictionary = structure.get("generation", {})
	generation[field] = value
	structure["generation"] = generation
	_set_current_structure(structure)


func _assign_selected_asset_to_generation_field(target: LineEdit) -> void:
	var selected := _asset_list.get_selected_items()
	if selected.is_empty():
		_set_status("Select an asset first")
		return
	var p := _selected_asset_path()
	if p == "":
		_set_status("Select an asset first")
		return
	target.text = p

func _add_selected_asset_to_structure() -> void:
	var selected := _asset_list.get_selected_items()
	if selected.is_empty():
		_set_status("Select an asset first")
		return
	var structure := _current_structure()
	if structure.is_empty():
		_set_status("No structure selected")
		return
	var asset_path := _selected_asset_path()
	if asset_path == "":
		_set_status("Select an asset first")
		return
	var placement: Dictionary = {
		"asset": asset_path,
		"x": 0,
		"y": 0,
		"z": 0,
		"rotation_deg": 0.0,
		"scale": 1.0,
		"layer": (_visual_layer_select.get_item_text(_visual_layer_select.selected) if _visual_layer_select and _visual_layer_select.selected >= 0 else "default"),
		"unique": false,
		"sprite_state": 0
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
		_refresh_visual_canvas()
		return
	var placements: Array = structure.get("placements", [])
	for i in placements.size():
		var placement: Dictionary = placements[i]
		var asset := placement.get("asset", "")
		var leaf: String = asset.get_file()
		var coords := "(%d,%d,%d)" % [placement.get("x", 0), placement.get("y", 0), placement.get("z", 0)]
		_placement_list.add_item("%02d  %s  %s" % [i, leaf, coords])
	_clear_placement_editor()
	_refresh_visual_canvas()


func _on_placement_selected(index: int) -> void:
	_current_placement_index = index
	var placement := _current_placement()
	if placement.is_empty():
		_clear_placement_editor()
		return
	_suppress_ui(true)
	_placement_asset_label.text = "Asset: %s" % placement.get("asset", "")
	_placement_x_input.set_value_no_signal(float(placement.get("x", 0)))
	_placement_y_input.set_value_no_signal(float(placement.get("y", 0)))
	_placement_z_input.set_value_no_signal(float(placement.get("z", 0)))
	_placement_rotation_input.set_value_no_signal(float(placement.get("rotation_deg", 0.0)))
	_placement_scale_input.set_value_no_signal(float(placement.get("scale", 1.0)))
	_placement_layer_input.text = placement.get("layer", "default")
	_placement_unique_check.set_pressed_no_signal(bool(placement.get("unique", false)))
	if _visual_layer_select:
		var layer_name := str(placement.get("layer", "default"))
		for i in range(_visual_layer_select.item_count):
			if _visual_layer_select.get_item_text(i) == layer_name:
				_visual_layer_select.select(i)
				break
	_suppress_ui(false)
	_refresh_visual_canvas()


func _update_selected_placement_field(field: String, value: Variant) -> void:
	if _suspend_ui_updates:
		return
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
	_on_placement_selected(_current_placement_index)


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
	_suppress_ui(true)
	_placement_asset_label.text = "Asset: (none)"
	_placement_x_input.set_value_no_signal(0)
	_placement_y_input.set_value_no_signal(0)
	_placement_z_input.set_value_no_signal(0)
	_placement_rotation_input.set_value_no_signal(0)
	_placement_scale_input.set_value_no_signal(1)
	_placement_layer_input.text = ""
	_placement_unique_check.set_pressed_no_signal(false)
	_suppress_ui(false)


func _add_room() -> void:
	var structure := _current_structure()
	if structure.is_empty():
		return
	var rooms: Array = structure.get("rooms", [])
	var room_id := "room_%03d" % [rooms.size() + 1]
	rooms.append({
		"id": room_id,
		"name": "Room %d" % [rooms.size() + 1],
		"type": "generic",
		"lighting_type": "interior",
		"spawn_points": "",
		"loot_table": "",
		"x": 1,
		"y": 1,
		"w": 4,
		"h": 4
	})
	structure["rooms"] = rooms
	_set_current_structure(structure)
	_refresh_room_list()
	_on_room_selected(rooms.size() - 1)

func _remove_room() -> void:
	var structure := _current_structure()
	if structure.is_empty():
		return
	var rooms: Array = structure.get("rooms", [])
	if _current_room_index < 0 or _current_room_index >= rooms.size():
		return
	var room: Dictionary = rooms[_current_room_index]
	var room_id: String = room.get("id", "")
	rooms.remove_at(_current_room_index)
	structure["rooms"] = rooms
	var furniture: Array = structure.get("furniture", [])
	for i in furniture.size():
		var furn: Dictionary = furniture[i]
		if furn.get("room_id", "") == room_id:
			furn["room_id"] = ""
			furniture[i] = furn
	structure["furniture"] = furniture
	_set_current_structure(structure)
	_refresh_room_list()
	_refresh_furniture_list()
	_set_status("Removed room")


func _refresh_room_list() -> void:
	_room_list.clear()
	_current_room_index = -1
	var structure := _current_structure()
	if structure.is_empty():
		_clear_room_editor()
		return
	var rooms: Array = structure.get("rooms", [])
	for i in rooms.size():
		var room: Dictionary = rooms[i]
		_room_list.add_item("%02d  %s [%s] (%d,%d %dx%d)" % [
			i,
			room.get("name", "Room"),
			room.get("type", "generic"),
			room.get("x", 0),
			room.get("y", 0),
			room.get("w", 1),
			room.get("h", 1)
		])
	_refresh_furniture_room_options()
	_clear_room_editor()


func _on_room_selected(index: int) -> void:
	_current_room_index = index
	var room := _current_room()
	if room.is_empty():
		_clear_room_editor()
		return
	_suppress_ui(true)
	_room_name_input.text = room.get("name", "")
	_room_type_input.text = room.get("type", "generic")
	_room_lighting_input.text = room.get("lighting_type", "interior")
	_room_spawn_points_input.text = room.get("spawn_points", "")
	_room_loot_table_input.text = room.get("loot_table", "")
	_room_x_input.set_value_no_signal(float(room.get("x", 0)))
	_room_y_input.set_value_no_signal(float(room.get("y", 0)))
	_room_w_input.set_value_no_signal(float(room.get("w", 1)))
	_room_h_input.set_value_no_signal(float(room.get("h", 1)))
	_suppress_ui(false)

func _on_room_name_changed(value: String) -> void:
	if _suspend_ui_updates:
		return
	_update_selected_room_field("name", value)


func _on_room_type_changed(value: String) -> void:
	if _suspend_ui_updates:
		return
	_update_selected_room_field("type", value)


func _update_selected_room_field(field: String, value: Variant) -> void:
	if _suspend_ui_updates:
		return
	var structure := _current_structure()
	if structure.is_empty():
		return
	var rooms: Array = structure.get("rooms", [])
	if _current_room_index < 0 or _current_room_index >= rooms.size():
		return
	var room: Dictionary = rooms[_current_room_index]
	room[field] = value
	rooms[_current_room_index] = room
	structure["rooms"] = rooms
	_set_current_structure(structure)
	_refresh_room_list()
	_room_list.select(_current_room_index)
	_refresh_furniture_room_options()


func _clear_room_editor() -> void:
	_suppress_ui(true)
	_room_name_input.text = ""
	_room_type_input.text = ""
	_room_lighting_input.text = ""
	_room_spawn_points_input.text = ""
	_room_loot_table_input.text = ""
	_room_x_input.set_value_no_signal(0)
	_room_y_input.set_value_no_signal(0)
	_room_w_input.set_value_no_signal(1)
	_room_h_input.set_value_no_signal(1)
	_suppress_ui(false)

func _add_furniture() -> void:
	var structure := _current_structure()
	if structure.is_empty():
		return
	var furniture: Array = structure.get("furniture", [])
	furniture.append({
		"asset": "",
		"x": 0,
		"y": 0,
		"z": 0,
		"rotation_deg": 0.0,
		"room_id": ""
	})
	structure["furniture"] = furniture
	_set_current_structure(structure)
	_refresh_furniture_list()
	_on_furniture_selected(furniture.size() - 1)


func _remove_furniture() -> void:
	var structure := _current_structure()
	if structure.is_empty():
		return
	var furniture: Array = structure.get("furniture", [])
	if _current_furniture_index < 0 or _current_furniture_index >= furniture.size():
		return
	furniture.remove_at(_current_furniture_index)
	structure["furniture"] = furniture
	_set_current_structure(structure)
	_refresh_furniture_list()
	_set_status("Removed furniture")


func _use_selected_asset_for_furniture() -> void:
	var selected := _asset_list.get_selected_items()
	if selected.is_empty():
		_set_status("Select an asset first")
		return
	if _current_furniture_index < 0:
		_set_status("Select or add a furniture item first")
		return
	var p := _selected_asset_path()
	if p == "":
		_set_status("Select an asset first")
		return
	_update_selected_furniture_field("asset", p)

func _refresh_furniture_list() -> void:
	_furniture_list.clear()
	_current_furniture_index = -1
	var structure := _current_structure()
	if structure.is_empty():
		_clear_furniture_editor()
		return
	var furniture: Array = structure.get("furniture", [])
	for i in furniture.size():
		var furn: Dictionary = furniture[i]
		var room_name := _room_name_for_id(furn.get("room_id", ""))
		_furniture_list.add_item("%02d  %s  (%d,%d,%d)  room:%s" % [
			i,
			furn.get("asset", "(unset)").get_file(),
			furn.get("x", 0),
			furn.get("y", 0),
			furn.get("z", 0),
			room_name
		])
	_refresh_furniture_room_options()
	_clear_furniture_editor()


func _on_furniture_selected(index: int) -> void:
	_current_furniture_index = index
	var furniture := _current_furniture()
	if furniture.is_empty():
		_clear_furniture_editor()
		return
	_suppress_ui(true)
	_furniture_asset_label.text = "Furniture Asset: %s" % furniture.get("asset", "(none)")
	_furniture_x_input.set_value_no_signal(float(furniture.get("x", 0)))
	_furniture_y_input.set_value_no_signal(float(furniture.get("y", 0)))
	_furniture_z_input.set_value_no_signal(float(furniture.get("z", 0)))
	_furniture_rotation_input.set_value_no_signal(float(furniture.get("rotation_deg", 0.0)))
	var rid := furniture.get("room_id", "")
	_select_furniture_room_by_id(rid)
	_suppress_ui(false)


func _on_furniture_room_selected(index: int) -> void:
	if _suspend_ui_updates:
		return
	if index < 0:
		_update_selected_furniture_field("room_id", "")
		return
	var room_id := ""
	if _furniture_room_select.get_item_metadata(index) != null:
		room_id = str(_furniture_room_select.get_item_metadata(index))
	_update_selected_furniture_field("room_id", room_id)


func _update_selected_furniture_field(field: String, value: Variant) -> void:
	if _suspend_ui_updates:
		return
	var structure := _current_structure()
	if structure.is_empty():
		return
	var furniture: Array = structure.get("furniture", [])
	if _current_furniture_index < 0 or _current_furniture_index >= furniture.size():
		return
	var furn: Dictionary = furniture[_current_furniture_index]
	furn[field] = value
	furniture[_current_furniture_index] = furn
	structure["furniture"] = furniture
	_set_current_structure(structure)
	_refresh_furniture_list()
	_furniture_list.select(_current_furniture_index)


func _refresh_furniture_room_options() -> void:
	_furniture_room_select.clear()
	_furniture_room_select.add_item("(Unassigned)")
	_furniture_room_select.set_item_metadata(0, "")
	var structure := _current_structure()
	if structure.is_empty():
		return
	var rooms: Array = structure.get("rooms", [])
	for room in rooms:
		var room_dict: Dictionary = room
		var label := "%s [%s]" % [room_dict.get("name", "Room"), room_dict.get("type", "generic")]
		_furniture_room_select.add_item(label)
		_furniture_room_select.set_item_metadata(_furniture_room_select.item_count - 1, room_dict.get("id", ""))


func _select_furniture_room_by_id(room_id: String) -> void:
	for i in _furniture_room_select.item_count:
		if str(_furniture_room_select.get_item_metadata(i)) == room_id:
			_furniture_room_select.select(i)
			return
	_furniture_room_select.select(0)


func _room_name_for_id(room_id: String) -> String:
	if room_id == "":
		return "(none)"
	var structure := _current_structure()
	if structure.is_empty():
		return "(none)"
	var rooms: Array = structure.get("rooms", [])
	for room in rooms:
		var room_dict: Dictionary = room
		if room_dict.get("id", "") == room_id:
			return room_dict.get("name", "(unknown)")
	return "(none)"


func _clear_furniture_editor() -> void:
	_suppress_ui(true)
	_furniture_asset_label.text = "Furniture Asset: (none)"
	_furniture_x_input.set_value_no_signal(0)
	_furniture_y_input.set_value_no_signal(0)
	_furniture_z_input.set_value_no_signal(0)
	_furniture_rotation_input.set_value_no_signal(0)
	if _furniture_room_select.item_count > 0:
		_furniture_room_select.select(0)
	_suppress_ui(false)

func _select_asset_for_metadata() -> void:
	var selected := _asset_list.get_selected_items()
	if selected.is_empty():
		_set_status("Select a sprite asset first")
		return
	var path := _selected_asset_path()
	if not SPRITE_EXTENSIONS.has(path.get_extension().to_lower()):
		_set_status("Sprite metadata supports .png or .webp assets")
		return
	_current_sprite_meta_asset = path
	_ensure_sprite_metadata_defaults(path, true)
	_refresh_sprite_metadata_editor()
	_set_status("Selected sprite for metadata")


func _refresh_sprite_metadata_editor() -> void:
	_suppress_ui(true)
	if _current_sprite_meta_asset == "":
		_meta_asset_label.text = "Sprite Asset: (none selected)"
		_meta_frame_w_input.set_value_no_signal(32)
		_meta_frame_h_input.set_value_no_signal(32)
		_meta_columns_input.set_value_no_signal(1)
		_meta_rows_input.set_value_no_signal(1)
		_meta_pivot_x_input.set_value_no_signal(0)
		_meta_pivot_y_input.set_value_no_signal(0)
		_meta_margin_input.set_value_no_signal(0)
		_meta_separation_input.set_value_no_signal(0)
		_meta_default_scale_input.set_value_no_signal(1.0)
		_meta_footprint_w_input.set_value_no_signal(0)
		_meta_footprint_h_input.set_value_no_signal(0)
		_meta_footprint_off_x_input.set_value_no_signal(0)
		_meta_footprint_off_y_input.set_value_no_signal(0)
		_suppress_ui(false)
		_refresh_spritesheet_viewer()
		return
	_ensure_sprite_metadata_defaults(_current_sprite_meta_asset)
	var meta: Dictionary = _sprite_metadata.get(_current_sprite_meta_asset, {})
	_meta_asset_label.text = "Sprite Asset: %s" % _current_sprite_meta_asset
	_meta_frame_w_input.set_value_no_signal(float(meta.get("frame_w", 32)))
	_meta_frame_h_input.set_value_no_signal(float(meta.get("frame_h", 32)))
	_meta_columns_input.set_value_no_signal(float(meta.get("columns", 1)))
	_meta_rows_input.set_value_no_signal(float(meta.get("rows", 1)))
	_meta_pivot_x_input.set_value_no_signal(float(meta.get("pivot_x", 0)))
	_meta_pivot_y_input.set_value_no_signal(float(meta.get("pivot_y", 0)))
	_meta_margin_input.set_value_no_signal(float(meta.get("margin", 0)))
	_meta_separation_input.set_value_no_signal(float(meta.get("separation", 0)))
	_meta_default_scale_input.set_value_no_signal(float(meta.get("scale", 1.0)))
	_meta_footprint_w_input.set_value_no_signal(float(meta.get("footprint_w_px", 0)))
	_meta_footprint_h_input.set_value_no_signal(float(meta.get("footprint_h_px", 0)))
	_meta_footprint_off_x_input.set_value_no_signal(float(meta.get("footprint_offset_x", 0)))
	_meta_footprint_off_y_input.set_value_no_signal(float(meta.get("footprint_offset_y", 0)))
	_suppress_ui(false)
	_refresh_spritesheet_viewer()


func _update_current_sprite_metadata(field: String, value: Variant) -> void:
	if _suspend_ui_updates or _current_sprite_meta_asset == "":
		return
	var meta: Dictionary = _sprite_metadata.get(_current_sprite_meta_asset, {})
	meta[field] = value
	if field == "footprint_w_px":
		meta["footprint_tiles_w"] = maxf(0.0, float(value) / 64.0)
	elif field == "footprint_h_px":
		meta["footprint_tiles_h"] = maxf(0.0, float(value) / 32.0)
	_sprite_metadata[_current_sprite_meta_asset] = meta
	_refresh_spritesheet_viewer()
	_refresh_visual_canvas()


func _generate_building_from_rules() -> void:
	var structure := _current_structure()
	if structure.is_empty():
		return
	var width: int = max(2, int(structure.get("width", 10)))
	var depth: int = max(2, int(structure.get("depth", 10)))
	var generation: Dictionary = structure.get("generation", {})
	var wall_asset: String = generation.get("wall_asset", "")
	var floor_asset: String = generation.get("floor_asset", "")
	var door_asset: String = generation.get("door_asset", "")

	var generated: Array = []
	for y in depth:
		for x in width:
			var edge := x == 0 or y == 0 or x == width - 1 or y == depth - 1
			if edge:
				if wall_asset != "":
					generated.append({
						"asset": wall_asset,
						"x": x,
						"y": y,
						"z": 0,
						"rotation_deg": 0.0,
						"scale": 1.0,
						"layer": "wall",
						"unique": false,
						"sprite_state": 0
					})
			elif floor_asset != "":
				generated.append({
					"asset": floor_asset,
					"x": x,
					"y": y,
					"z": 0,
					"rotation_deg": 0.0,
					"scale": 1.0,
					"layer": "floor",
					"unique": false,
					"sprite_state": 0
				})

	if door_asset != "":
		var door_x := width / 2
		generated.append({
			"asset": door_asset,
			"x": int(door_x),
			"y": 0,
			"z": 0,
			"rotation_deg": 0.0,
			"scale": 1.0,
			"layer": "door",
			"unique": true
		})

	structure["placements"] = generated
	if bool(generation.get("auto_furnish", false)):
		_auto_furnish_from_rooms(structure)
	_set_current_structure(structure)
	_refresh_placement_list()
	_refresh_furniture_list()
	_set_status("Generated building shell (%d placements)" % generated.size())


func _auto_furnish_from_rooms(structure: Dictionary) -> void:
	var rooms: Array = structure.get("rooms", [])
	var furniture: Array = []
	for room in rooms:
		var room_dict: Dictionary = room
		if room_dict.get("w", 0) < 2 or room_dict.get("h", 0) < 2:
			continue
		furniture.append({
			"asset": "",
			"x": int(room_dict.get("x", 0)) + 1,
			"y": int(room_dict.get("y", 0)) + 1,
			"z": 0,
			"rotation_deg": 0.0,
			"room_id": room_dict.get("id", "")
		})
	structure["furniture"] = furniture


func _validate_current_structure() -> void:
	var structure := _current_structure()
	if structure.is_empty():
		if _validation_label:
			_validation_label.text = "Validation: no structure selected"
		return
	var issues: Array[String] = []
	var placements: Array = structure.get("placements", [])
	var rooms: Array = structure.get("rooms", [])
	var width := int(structure.get("width", 0))
	var depth := int(structure.get("depth", 0))

	if placements.is_empty():
		issues.append("No placements found.")

	var has_floor := false
	var has_wall := false
	var has_door := false
	var seen: Dictionary = {}
	for p in placements:
		var placement: Dictionary = p
		var layer := str(placement.get("layer", "default")).to_lower()
		if layer == "floor":
			has_floor = true
		if layer == "wall":
			has_wall = true
		if layer == "door":
			has_door = true
		var key := "%s|%s|%s|%s" % [placement.get("x", 0), placement.get("y", 0), placement.get("z", 0), layer]
		if seen.has(key):
			issues.append("Overlap on same layer at %s." % key)
		else:
			seen[key] = true

	if not has_floor:
		issues.append("No floor layer placements.")
	if not has_wall:
		issues.append("No wall layer placements.")
	if not has_door:
		issues.append("No door placement detected.")

	if width > 1 and depth > 1 and has_wall:
		var expected_perimeter := max(1, 2 * (width + depth) - 4)
		var wall_count := 0
		for p in placements:
			var placement: Dictionary = p
			if str(placement.get("layer", "")).to_lower() == "wall":
				wall_count += 1
		if wall_count < int(expected_perimeter * 0.6):
			issues.append("Wall coverage looks incomplete (" + str(wall_count) + "/~" + str(expected_perimeter) + ").")

	for room_variant in rooms:
		var room: Dictionary = room_variant
		var rx := int(room.get("x", 0))
		var ry := int(room.get("y", 0))
		var rw := int(room.get("w", 1))
		var rh := int(room.get("h", 1))
		if rw <= 0 or rh <= 0:
			issues.append("Room '%s' has invalid size." % room.get("name", "unnamed"))
		if rx < 0 or ry < 0 or rx + rw > width or ry + rh > depth:
			issues.append("Room '%s' extends outside template bounds." % room.get("name", "unnamed"))

	if _validation_label:
		if issues.is_empty():
			_validation_label.text = "Validation: PASS"
		else:
			_validation_label.text = "Validation: " + " | ".join(issues)
	if issues.is_empty():
		_set_status("Validation passed")
	else:
		_set_status("Validation found %d issue(s)" % issues.size())

func _current_structure() -> Dictionary:
	var list: Array = _structures[_current_type]
	if _current_structure_index < 0 or _current_structure_index >= list.size():
		return {}
	var structure: Dictionary = list[_current_structure_index]
	structure = _normalize_structure(structure, _current_structure_index + 1)
	list[_current_structure_index] = structure
	_structures[_current_type] = list
	return structure


func _set_current_structure(structure: Dictionary) -> void:
	var list: Array = _structures[_current_type]
	if _current_structure_index < 0 or _current_structure_index >= list.size():
		return
	list[_current_structure_index] = _normalize_structure(structure, _current_structure_index + 1)
	_structures[_current_type] = list


func _current_placement() -> Dictionary:
	var structure := _current_structure()
	if structure.is_empty():
		return {}
	var placements: Array = structure.get("placements", [])
	if _current_placement_index < 0 or _current_placement_index >= placements.size():
		return {}
	return placements[_current_placement_index]


func _current_room() -> Dictionary:
	var structure := _current_structure()
	if structure.is_empty():
		return {}
	var rooms: Array = structure.get("rooms", [])
	if _current_room_index < 0 or _current_room_index >= rooms.size():
		return {}
	return rooms[_current_room_index]


func _current_furniture() -> Dictionary:
	var structure := _current_structure()
	if structure.is_empty():
		return {}
	var furniture: Array = structure.get("furniture", [])
	if _current_furniture_index < 0 or _current_furniture_index >= furniture.size():
		return {}
	return furniture[_current_furniture_index]


func _save_to_disk(path: String) -> void:
	var payload := {
		"version": 3,
		"exported_at_unix": Time.get_unix_time_from_system(),
		"sprite_metadata": _sprite_metadata,
		"asset_browser": {
			"favorites": _asset_favorites,
			"tags": _asset_tags
		},
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
	var raw_text := file.get_as_text()
	file.close()
	var parsed := JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_set_status("Invalid JSON in %s" % path)
		return
	var incoming: Dictionary = parsed
	var incoming_types: Dictionary = incoming.get("types", {})
	for key in [TYPE_BUILDING, TYPE_SCENE, TYPE_CHUNK]:
		if incoming_types.has(key) and incoming_types[key] is Array:
			var normalized: Array = []
			for i in incoming_types[key].size():
				var raw: Dictionary = incoming_types[key][i]
				normalized.append(_normalize_structure(raw, i + 1))
			_structures[key] = normalized
	if incoming.has("sprite_metadata") and incoming["sprite_metadata"] is Dictionary:
		_sprite_metadata = incoming["sprite_metadata"]
	if incoming.has("asset_browser") and incoming["asset_browser"] is Dictionary:
		var browser: Dictionary = incoming["asset_browser"]
		if browser.has("favorites") and browser["favorites"] is Dictionary:
			_asset_favorites = browser["favorites"]
		if browser.has("tags") and browser["tags"] is Dictionary:
			_asset_tags = browser["tags"]
	_refresh_structure_selector()
	if _structures[_current_type].is_empty():
		_add_structure()
	else:
		_select_structure(0)
	_refresh_sprite_metadata_editor()
	_apply_asset_filter(_asset_filter_input.text if _asset_filter_input else "")
	if show_status:
		_set_status("Loaded %s" % path)

func _suppress_ui(value: bool) -> void:
	_suspend_ui_updates = value


func _set_status(message: String) -> void:
	if _status_label:
		_status_label.text = message
	print("[AssetComposer] %s" % message)













































