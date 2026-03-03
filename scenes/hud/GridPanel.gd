class_name GridPanel
extends Control

## Draws one InventoryGrid as an interactive cell matrix.
## Items are shown as colored rectangles sized to their grid footprint.
## Click-to-select, then click-to-move.  Right-click = context menu.

const CELL := 32.0    # pixels per cell
const PAD  :=  2.0    # gap between cells

# The grid this panel represents.
var inv_grid: InventoryGrid = null

# If true the user can only view; no drag/drop.
var read_only: bool = false

# ── Shared drag state (across all GridPanels in the same scene) ───────────────
static var _held_item:   ItemData     = null   # item being dragged
static var _held_grid:   InventoryGrid = null  # grid the item was taken from
static var _held_rotated: bool        = false

# Signals emitted to parent windows.
signal item_right_clicked(item: ItemData, grid: InventoryGrid, screen_pos: Vector2)
signal item_shift_clicked(item: ItemData, grid: InventoryGrid)   # shift+left = quick transfer
signal drag_completed     # fired when a held item is placed

# ── Local state ───────────────────────────────────────────────────────────────
var _hover_cell: Vector2i = Vector2i(-1, -1)   # cell under cursor (-1,-1 = none)
var _ctx_popup:  PopupMenu = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): set_process(true))
	mouse_exited.connect(func():
		_hover_cell = Vector2i(-1, -1)
		queue_redraw())
	set_process(false)


func set_grid(g: InventoryGrid) -> void:
	inv_grid = g
	_update_size()
	queue_redraw()


func _update_size() -> void:
	if inv_grid == null:
		return
	custom_minimum_size = Vector2(
		inv_grid.grid_w * CELL + PAD,
		inv_grid.grid_h * CELL + PAD)
	size = custom_minimum_size


# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	if inv_grid == null:
		return

	var gw := inv_grid.grid_w
	var gh := inv_grid.grid_h

	# ── Background cells ──────────────────────────────────────────────────────
	var cell_bg  := Color(0.15, 0.15, 0.17, 1.0)
	var cell_bdr := Color(0.28, 0.28, 0.30, 0.8)
	for row in gh:
		for col in gw:
			var r := Rect2(col * CELL + PAD * 0.5, row * CELL + PAD * 0.5,
						   CELL - PAD, CELL - PAD)
			draw_rect(r, cell_bg)
			draw_rect(r, cell_bdr, false, 0.5)

	# ── Hover highlight (empty cells only) ───────────────────────────────────
	if _hover_cell != Vector2i(-1, -1) and _held_item != null:
		var iw := _held_item.grid_h if _held_rotated else _held_item.grid_w
		var ih := _held_item.grid_w if _held_rotated else _held_item.grid_h
		var ok := inv_grid.can_place(_held_item, _hover_cell.x, _hover_cell.y, _held_rotated)
		var hcol := Color(0.3, 0.8, 0.3, 0.35) if ok else Color(0.8, 0.2, 0.2, 0.35)
		for r in ih:
			for c in iw:
				var cx := _hover_cell.x + c
				var cy := _hover_cell.y + r
				if cx >= 0 and cy >= 0 and cx < gw and cy < gh:
					draw_rect(Rect2(cx * CELL + PAD * 0.5, cy * CELL + PAD * 0.5,
								   CELL - PAD, CELL - PAD), hcol)

	# ── Item blocks ───────────────────────────────────────────────────────────
	for i in inv_grid.items.size():
		var item    := inv_grid.items[i]
		var origin  := inv_grid.item_origins[i]
		var rotated := inv_grid.item_rotated[i]
		var iw      := item.grid_h if rotated else item.grid_w
		var ih      := item.grid_w if rotated else item.grid_h

		# Skip if this is the item being dragged.
		if _held_item == item and _held_grid == inv_grid:
			continue

		var type_idx := clampi(item.item_type, 0, ItemData.TYPE_COLORS.size() - 1)
		var base_col := ItemData.TYPE_COLORS[type_idx].darkened(0.30)
		var top_col  := base_col.lightened(0.15)

		var r := Rect2(
			origin.x * CELL + PAD,
			origin.y * CELL + PAD,
			iw * CELL - PAD * 2.0,
			ih * CELL - PAD * 2.0)

		draw_rect(r, base_col)
		draw_rect(r, top_col, false, 1.0)

		# Item name (truncated to fit)
		var max_chars := int(r.size.x / 6.0)
		var lbl := item.item_name.left(max_chars)
		draw_string(ThemeDB.fallback_font, r.position + Vector2(3.0, 11.0),
					lbl, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 4.0, 9,
					Color(0.95, 0.95, 0.95, 0.9))

	# ── Ghost (held item preview at hover) ───────────────────────────────────
	if _held_item != null and _hover_cell != Vector2i(-1, -1) and _held_grid != inv_grid:
		var iw := _held_item.grid_h if _held_rotated else _held_item.grid_w
		var ih := _held_item.grid_w if _held_rotated else _held_item.grid_h
		var ok := inv_grid.can_place(_held_item, _hover_cell.x, _hover_cell.y, _held_rotated)
		var ghost_c := Color(0.6, 0.9, 0.6, 0.45) if ok else Color(0.9, 0.4, 0.4, 0.35)
		draw_rect(Rect2(
			_hover_cell.x * CELL + PAD,
			_hover_cell.y * CELL + PAD,
			iw * CELL - PAD * 2.0,
			ih * CELL - PAD * 2.0), ghost_c)


# ── Input ─────────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	var new_cell := _local_to_cell(get_local_mouse_position())
	if new_cell != _hover_cell:
		_hover_cell = new_cell
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if inv_grid == null:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			var cell := _local_to_cell(mb.position)

			if mb.button_index == MOUSE_BUTTON_LEFT:
				_handle_left_click(cell)
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_handle_right_click(cell, mb.global_position)

	get_viewport().set_input_as_handled()


func _handle_left_click(cell: Vector2i) -> void:
	if _held_item != null:
		# Attempt drop.
		if inv_grid.can_place(_held_item, cell.x, cell.y, _held_rotated):
			inv_grid.place_item(_held_item, cell.x, cell.y, _held_rotated)
			_held_item   = null
			_held_grid   = null
			_held_rotated = false
			drag_completed.emit()
		# else: invalid drop — keep holding
		queue_redraw()
	else:
		# Pick up item at cell (if not read-only).
		if read_only:
			return
		var idx := inv_grid.get_item_at_cell(cell.x, cell.y)
		if idx >= 0:
			# Shift+click = quick transfer to the other inventory.
			if Input.is_key_pressed(KEY_SHIFT):
				item_shift_clicked.emit(inv_grid.items[idx], inv_grid)
				return
			_held_item    = inv_grid.items[idx]
			_held_grid    = inv_grid
			_held_rotated = inv_grid.item_rotated[idx]
			inv_grid.remove_item(idx)
			queue_redraw()


func _handle_right_click(cell: Vector2i, screen_pos: Vector2) -> void:
	if _held_item != null:
		# Cancel drag — return item to source grid.
		if _held_grid != null:
			_held_grid.auto_place(_held_item)
		_held_item    = null
		_held_grid    = null
		_held_rotated = false
		queue_redraw()
		return

	var idx := inv_grid.get_item_at_cell(cell.x, cell.y)
	if idx < 0:
		return
	item_right_clicked.emit(inv_grid.items[idx], inv_grid, screen_pos)


# ── Key input (R = rotate held item) ─────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if _held_item == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_R:
			_held_rotated = not _held_rotated
			queue_redraw()
			get_viewport().set_input_as_handled()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _local_to_cell(local_pos: Vector2) -> Vector2i:
	if inv_grid == null:
		return Vector2i(-1, -1)
	var col := int(local_pos.x / CELL)
	var row := int(local_pos.y / CELL)
	if col < 0 or row < 0 or col >= inv_grid.grid_w or row >= inv_grid.grid_h:
		return Vector2i(-1, -1)
	return Vector2i(col, row)


## Cancel any in-progress drag (called by parent window on close).
static func cancel_drag() -> void:
	if _held_item != null and _held_grid != null:
		_held_grid.auto_place(_held_item)
	_held_item    = null
	_held_grid    = null
	_held_rotated = false
