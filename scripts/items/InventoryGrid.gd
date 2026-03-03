class_name InventoryGrid
extends Resource

## Single rectangular grid for inventory management.
## Items occupy W×H cell regions.  Handles placement, removal, and auto-fit.

var grid_w:       int    = 4
var grid_h:       int    = 2
var label:        String = "Body"

# Flat cell array (row-major).  0 = empty; (item_index + 1) = occupied by that item.
var _cells:       PackedInt32Array

# Items stored in this grid and their placement metadata.
var items:        Array[ItemData]  = []
var item_origins: Array[Vector2i]  = []   # top-left cell of each item
var item_rotated: Array[bool]      = []   # whether the item is rotated 90°


## Initialise (or reinitialise) the grid.  Clears all existing contents.
func init(w: int, h: int, lbl: String) -> void:
	grid_w = w
	grid_h = h
	label  = lbl
	_cells = PackedInt32Array()
	_cells.resize(w * h)
	_cells.fill(0)
	items        = []
	item_origins = []
	item_rotated = []


func get_total_cells() -> int:
	return grid_w * grid_h


func get_used_cells() -> int:
	var count := 0
	for i in items.size():
		var item := items[i]
		var w    := item.grid_h if item_rotated[i] else item.grid_w
		var h    := item.grid_w if item_rotated[i] else item.grid_h
		count   += w * h
	return count


## Returns the effective width/height of item i (accounting for rotation).
func item_w(i: int) -> int:
	return items[i].grid_h if item_rotated[i] else items[i].grid_w


func item_h(i: int) -> int:
	return items[i].grid_w if item_rotated[i] else items[i].grid_h


## True if item fits at (x, y) with the given rotation.
func can_place(item: ItemData, x: int, y: int, rotated: bool = false) -> bool:
	var iw := item.grid_h if rotated else item.grid_w
	var ih := item.grid_w if rotated else item.grid_h
	if x < 0 or y < 0 or x + iw > grid_w or y + ih > grid_h:
		return false
	for row in ih:
		for col in iw:
			if _cells[(y + row) * grid_w + (x + col)] != 0:
				return false
	return true


## Place item at (x, y).  Returns false if placement fails.
func place_item(item: ItemData, x: int, y: int, rotated: bool = false) -> bool:
	if not can_place(item, x, y, rotated):
		return false
	var idx := items.size()
	items.append(item)
	item_origins.append(Vector2i(x, y))
	item_rotated.append(rotated)
	_stamp(idx)
	return true


## Remove item by index.  Returns the removed ItemData, or null.
func remove_item(idx: int) -> ItemData:
	if idx < 0 or idx >= items.size():
		return null
	var item := items[idx]
	items.remove_at(idx)
	item_origins.remove_at(idx)
	item_rotated.remove_at(idx)
	# Rebuild cell map from scratch (indices shifted after removal).
	_cells.fill(0)
	for i in items.size():
		_stamp(i)
	return item


## Find which item occupies cell (x, y).  Returns -1 if empty.
func get_item_at_cell(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= grid_w or y >= grid_h:
		return -1
	var v := _cells[y * grid_w + x]
	return v - 1   # 0 → -1 (empty); N → N-1 (item index)


## Try to auto-place item (first-fit left→right, top→bottom).
## Returns true on success.
func auto_place(item: ItemData) -> bool:
	for y in grid_h:
		for x in grid_w:
			if can_place(item, x, y, false):
				return place_item(item, x, y, false)
	# Try rotated orientation if the item isn't square.
	if item.grid_w != item.grid_h:
		for y in grid_h:
			for x in grid_w:
				if can_place(item, x, y, true):
					return place_item(item, x, y, true)
	return false


## Move an item to a new position within this grid.
## Temporarily clears old cells, validates new position, reverts on failure.
func move_item(idx: int, new_x: int, new_y: int, new_rotated: bool = false) -> bool:
	if idx < 0 or idx >= items.size():
		return false
	# Temporarily clear this item's cells.
	var origin  := item_origins[idx]
	var rotated := item_rotated[idx]
	var iw2     := items[idx].grid_h if rotated else items[idx].grid_w
	var ih2     := items[idx].grid_w if rotated else items[idx].grid_h
	for r in ih2:
		for c in iw2:
			_cells[(origin.y + r) * grid_w + (origin.x + c)] = 0
	# Test new position.
	if can_place(items[idx], new_x, new_y, new_rotated):
		item_origins[idx] = Vector2i(new_x, new_y)
		item_rotated[idx] = new_rotated
		_stamp(idx)
		return true
	else:
		# Restore old position.
		_stamp(idx)
		return false


# ── Internal ──────────────────────────────────────────────────────────────────

func _stamp(idx: int) -> void:
	var origin  := item_origins[idx]
	var rotated := item_rotated[idx]
	var iw      := items[idx].grid_h if rotated else items[idx].grid_w
	var ih      := items[idx].grid_w if rotated else items[idx].grid_h
	for r in ih:
		for c in iw:
			_cells[(origin.y + r) * grid_w + (origin.x + c)] = idx + 1
