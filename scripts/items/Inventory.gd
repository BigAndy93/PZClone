class_name Inventory
extends Resource

signal inventory_changed
signal grids_changed       # fires when grid layout or contents change

# Server-side flat capacity.  Generous to accommodate bags without
# requiring server-side tracking of equipped bag types.
const MAX_SLOTS := 30

# Default body pocket grid dimensions (4 wide × 2 tall = 8 cells).
const DEFAULT_BODY_GRID := Vector2i(4, 2)

# Flat item list — server-authoritative, synced over network.
var items: Array[ItemData] = []

# ── Client-local grid representations ─────────────────────────────────────────
# body_grid is always present; back_grid / hand_grid appear when bags are equipped.
var body_grid: InventoryGrid = null
var back_grid: InventoryGrid = null
var hand_grid: InventoryGrid = null
var grids:     Array[InventoryGrid] = []


func _init() -> void:
	_reset_grids(DEFAULT_BODY_GRID, Vector2i.ZERO, Vector2i.ZERO)


# ── Grid management ───────────────────────────────────────────────────────────

## Call when equipped clothing/bag state changes.
## pocket_size: body pocket grid dimensions (default 4×2).
## back_size:   back bag grid dimensions (Vector2i.ZERO = no back bag).
## hand_size:   hand bag grid dimensions (Vector2i.ZERO = no hand bag).
func rebuild_grids(
		pocket_size: Vector2i = DEFAULT_BODY_GRID,
		back_size:   Vector2i = Vector2i.ZERO,
		hand_size:   Vector2i = Vector2i.ZERO) -> void:
	_reset_grids(pocket_size, back_size, hand_size)
	sync_from_flat()


## Re-place all flat-list items into the active grids.
## Called after server pushes new item data or grids change.
func sync_from_flat() -> void:
	for g in grids:
		g.init(g.grid_w, g.grid_h, g.label)
	for item in items:
		var placed := false
		for g in grids:
			if g.auto_place(item):
				placed = true
				break
		if not placed:
			push_warning("Inventory: '%s' does not fit in any grid (overflow)" % item.item_name)
	grids_changed.emit()


# ── Item operations ───────────────────────────────────────────────────────────

func can_add() -> bool:
	return items.size() < MAX_SLOTS


func add_item(item: ItemData) -> bool:
	if not can_add():
		return false
	items.append(item)
	# Auto-place in the first grid that has space.
	for g in grids:
		if g.auto_place(item):
			break
	inventory_changed.emit()
	grids_changed.emit()
	return true


## Apply stat effects and remove the item.  Returns feedback message.
func use_item(idx: int, stats: SurvivalStats) -> String:
	if idx < 0 or idx >= items.size():
		return ""
	var item: ItemData = items[idx]
	for stat_name: String in item.stat_effects:
		var delta: float = item.stat_effects[stat_name]
		if stat_name == "bleed":
			stats.remove_bleed(int(-delta))
		elif stat_name == "infection":
			if delta < 0.0:
				stats.remove_infection()
		elif stat_name == "deep_wound":
			if delta < 0.0:
				stats.deep_wound = maxi(stats.deep_wound + int(delta), 0)
		elif stat_name == "fracture":
			if delta < 0.0:
				stats.fracture = false
		elif stat_name not in [
				"ammo_count", "projectile_damage", "fire_range", "melee_bonus",
				"pocket_grid", "back_grid", "hand_grid", "equip_slot", "insulation"]:
			stats.set_stat(stat_name, stats.get_stat(stat_name) + delta)
	_remove_from_grids(item)
	items.remove_at(idx)
	inventory_changed.emit()
	grids_changed.emit()
	return item.use_message if not item.use_message.is_empty() else ("Used " + item.item_name)


## Sort flat items by type priority then re-pack grids.
## Priority (design bible): Medical → Food → Water → Weapons → Ammo → Clothing → Misc
func sort_items() -> void:
	items.sort_custom(_sort_priority)
	sync_from_flat()


static func _sort_priority(a: ItemData, b: ItemData) -> bool:
	return _type_rank(a) < _type_rank(b)


static func _type_rank(item: ItemData) -> int:
	match item.item_type:
		ItemData.Type.BANDAGE: return 0
		ItemData.Type.FOOD:    return 1
		ItemData.Type.WATER:   return 2
		ItemData.Type.WEAPON:  return 3
		ItemData.Type.MISC:
			if item.stat_effects.has("ammo_count"): return 4
			return 5
		ItemData.Type.CLOTHING: return 6
	return 7


## Remove item by index without consuming it (drop / transfer).
## Returns the ItemData, or null on bad index.
func remove_at(idx: int) -> ItemData:
	if idx < 0 or idx >= items.size():
		return null
	var item := items[idx]
	_remove_from_grids(item)
	items.remove_at(idx)
	inventory_changed.emit()
	grids_changed.emit()
	return item


# ── Internal ──────────────────────────────────────────────────────────────────

func _reset_grids(pocket: Vector2i, back: Vector2i, hand: Vector2i) -> void:
	body_grid = _make_grid(pocket.x, pocket.y, "Body")
	back_grid = _make_grid(back.x, back.y, "Backpack") if back != Vector2i.ZERO else null
	hand_grid = _make_grid(hand.x, hand.y, "Hand Bag")  if hand != Vector2i.ZERO else null
	grids = []
	if body_grid != null:
		grids.append(body_grid)
	if back_grid != null:
		grids.append(back_grid)
	if hand_grid != null:
		grids.append(hand_grid)


func _make_grid(w: int, h: int, lbl: String) -> InventoryGrid:
	var g := InventoryGrid.new()
	g.init(w, h, lbl)
	return g


func _remove_from_grids(item: ItemData) -> void:
	for g in grids:
		for i in g.items.size():
			if g.items[i] == item:
				g.remove_item(i)
				return
