class_name ContainerWindow
extends DraggableWindow

## Floating window that appears when a player searches a WorldContainer.
## Shows the container's item grid; items can be taken into the player inventory.

var _container:       WorldContainer = null
var _player_inv:      Inventory = null
var _container_grid:  InventoryGrid = null
var _panel:           GridPanel = null
var _take_all_btn:    Button   = null
var _info_lbl:        Label    = null


func _init() -> void:
	title    = "Container"
	min_size = Vector2(240.0, 180.0)


func _post_build() -> void:
	var ca := get_content_area()

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	vbox.offset_left  = 4.0
	vbox.offset_right = -4.0
	vbox.offset_top   = 4.0
	ca.add_child(vbox)

	_info_lbl = Label.new()
	_info_lbl.add_theme_font_size_override("font_size", 9)
	_info_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.60))
	vbox.add_child(_info_lbl)

	_panel = GridPanel.new()
	_panel.read_only = false
	_panel.item_right_clicked.connect(_on_right_click)
	_panel.item_shift_clicked.connect(_on_shift_click)
	_panel.drag_completed.connect(_on_drag_completed)
	vbox.add_child(_panel)

	_take_all_btn = Button.new()
	_take_all_btn.text = "Take All"
	_take_all_btn.pressed.connect(_take_all)
	vbox.add_child(_take_all_btn)


## Open the window for a WorldContainer + player inventory.
func open_container(container: WorldContainer, player_inventory: Inventory) -> void:
	_container   = container
	_player_inv  = player_inventory

	# Build a temporary InventoryGrid from the container's item list.
	var grid_size: Vector2i = container.get_grid_size()
	_container_grid = InventoryGrid.new()
	_container_grid.init(grid_size.x, grid_size.y, container.get_container_label())
	for item: ItemData in container.items:
		_container_grid.auto_place(item)

	_panel.set_grid(_container_grid)
	set_panel_title(container.get_container_label())
	_info_lbl.text = "%d / %d cells used" % [_container_grid.get_used_cells(), _container_grid.get_total_cells()]
	show()


func _take_all() -> void:
	if _container == null or _player_inv == null:
		return
	# Copy items list (taking modifies it mid-loop).
	var items_copy := _container.items.duplicate()
	for item: ItemData in items_copy:
		var idx := _container.items.find(item)
		if idx >= 0:
			_container.request_take_item(idx, _player_inv)
	_refresh_panel()


func _on_drag_completed() -> void:
	# When item is dragged out of container grid, notify container.
	if _container_grid == null:
		return
	# Determine which items are no longer in the grid.
	if _container != null:
		for i in range(_container.items.size() - 1, -1, -1):
			var item := _container.items[i]
			if not _container_grid.items.has(item):
				_container.request_take_item(i, _player_inv)
	_refresh_panel()


func _on_right_click(item: ItemData, _grid: InventoryGrid, _screen_pos: Vector2) -> void:
	# Right-click: auto-place into player inventory.
	if _container == null or _player_inv == null:
		return
	var idx := _container.items.find(item)
	if idx >= 0:
		_container.request_take_item(idx, _player_inv)
	_refresh_panel()


func _on_shift_click(item: ItemData, _grid: InventoryGrid) -> void:
	# Shift+click: quick-transfer to player inventory (same as right-click).
	if _container == null or _player_inv == null:
		return
	var idx := _container.items.find(item)
	if idx >= 0:
		_container.request_take_item(idx, _player_inv)
	_refresh_panel()


func _refresh_panel() -> void:
	if _container_grid == null or _container == null:
		return
	_container_grid.init(_container_grid.grid_w, _container_grid.grid_h, _container_grid.label)
	for item: ItemData in _container.items:
		_container_grid.auto_place(item)
	_panel.queue_redraw()
	_info_lbl.text = "%d / %d cells used" % [_container_grid.get_used_cells(), _container_grid.get_total_cells()]


func close_container() -> void:
	GridPanel.cancel_drag()
	_container      = null
	_player_inv     = null
	_container_grid = null
	hide()
