class_name InventoryWindow
extends DraggableWindow

## Floating inventory window.  Shows one GridPanel per active InventoryGrid.
## Refreshes automatically when Inventory.grids_changed fires.

var _inventory:  Inventory     = null
var _scroll:     ScrollContainer = null
var _vbox:       VBoxContainer  = null
var _count_lbl:  Label          = null
var _panels:     Array[GridPanel] = []
var _ctx_popup:  PopupMenu       = null
var _ctx_item:   ItemData        = null
var _ctx_grid:   InventoryGrid   = null

# Reference to the local Player for use-item / equip actions.
var _player: Node = null

# Active WorldContainer (set by HUD when a container is open, cleared on close).
var _open_container: WorldContainer = null


func _init() -> void:
	title    = "Inventory"
	min_size = Vector2(240.0, 180.0)


func _post_build() -> void:
	var ca := get_content_area()

	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 4)
	outer.offset_left  = 4.0
	outer.offset_right = -4.0
	outer.offset_top   = 4.0
	ca.add_child(outer)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(_scroll)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 8)
	_scroll.add_child(_vbox)

	# Cell count label at bottom.
	_count_lbl = Label.new()
	_count_lbl.add_theme_font_size_override("font_size", 9)
	_count_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	outer.add_child(_count_lbl)

	# Auto-sort button.
	var sort_btn := Button.new()
	sort_btn.text = "Auto-Sort"
	sort_btn.pressed.connect(_do_auto_sort)
	outer.add_child(sort_btn)

	# Context popup.
	_ctx_popup = PopupMenu.new()
	_ctx_popup.add_item("Use",  0)
	_ctx_popup.add_item("Drop", 1)
	_ctx_popup.id_pressed.connect(_on_ctx_selected)
	add_child(_ctx_popup)


## Called by HUD when the local player is available.
func setup(player: Node) -> void:
	_player    = player
	_inventory = player.inventory
	_inventory.grids_changed.connect(refresh)
	refresh()


## Rebuild the grid panels from current Inventory.grids.
func refresh() -> void:
	if _inventory == null or _vbox == null:
		return

	# Clear existing panels.
	for p in _panels:
		p.queue_free()
	_panels.clear()
	for ch in _vbox.get_children():
		ch.queue_free()

	# Build one section per active grid.
	for g in _inventory.grids:
		_add_grid_section(g)

	_update_count_label()


func _add_grid_section(g: InventoryGrid) -> void:
	# Section label.
	var lbl := Label.new()
	lbl.text = g.label
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.65))
	_vbox.add_child(lbl)

	# Grid panel.
	var panel := GridPanel.new()
	panel.set_grid(g)
	panel.item_right_clicked.connect(_on_right_click)
	panel.item_shift_clicked.connect(_on_inv_shift_click)
	panel.drag_completed.connect(_on_drag_completed)
	_vbox.add_child(panel)
	_panels.append(panel)


func _update_count_label() -> void:
	if _inventory == null or _count_lbl == null:
		return
	var total := 0
	var used  := 0
	for g in _inventory.grids:
		total += g.get_total_cells()
		used  += g.get_used_cells()
	_count_lbl.text = "Used: %d / %d cells  |  Items: %d" % [used, total, _inventory.items.size()]


func _on_drag_completed() -> void:
	_update_count_label()
	# Redraw all panels.
	for p in _panels:
		p.queue_redraw()


func _on_right_click(item: ItemData, grid: InventoryGrid, screen_pos: Vector2) -> void:
	_ctx_item = item
	_ctx_grid = grid
	# Label item 0 contextually: "Equip/Unequip" for gear, "Use" for consumables.
	var equippable := item.item_type in [ItemData.Type.WEAPON, ItemData.Type.CLOTHING]
	var equipped   := _player != null and _player_has_equipped(item)
	_ctx_popup.set_item_text(0, "Unequip" if equipped else ("Equip" if equippable else "Use"))
	_ctx_popup.set_item_disabled(0, false)
	_ctx_popup.position = Vector2i(int(screen_pos.x), int(screen_pos.y))
	_ctx_popup.popup()


func _player_has_equipped(item: ItemData) -> bool:
	if _player == null: return false
	return (_player.get("equipped_weapon")  == item or
			_player.get("equipped_clothing") == item or
			_player.get("equipped_back")     == item or
			_player.get("equipped_hand")     == item)


func _on_ctx_selected(id: int) -> void:
	if _ctx_item == null:
		return
	var idx := _inventory.items.find(_ctx_item)
	if idx < 0:
		return
	match id:
		0:  # Use / Equip / Unequip
			if _player != null:
				_player.activate_item(idx)
		1:  # Drop
			if _player != null:
				_player._try_drop_item_at(idx)
	_ctx_item = null
	_ctx_grid = null
	refresh()


## Auto-sort inventory by type priority (medical → food → water → weapons → ammo → misc → clothing).
func _do_auto_sort() -> void:
	if _inventory == null:
		return
	_inventory.sort_items()


## Shift+click an inventory item — transfer to the open container if one is available.
func _on_inv_shift_click(item: ItemData, _grid: InventoryGrid) -> void:
	if _inventory == null or _open_container == null:
		return
	var idx := _inventory.items.find(item)
	if idx < 0:
		return
	if multiplayer.is_server():
		# Server: directly transfer the item.
		var item_data := _inventory.remove_at(idx)
		if item_data != null:
			_open_container.items.append(item_data)
	else:
		# Client: ask server to move the item.
		_open_container.rpc_id(1, "rpc_request_deposit_item", idx)


## Called by HUD when a container is opened alongside this window.
func set_open_container(c: WorldContainer) -> void:
	_open_container = c


## Called by HUD when the container window is closed.
func clear_open_container() -> void:
	_open_container = null
