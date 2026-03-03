class_name CraftingMenu
extends DraggableWindow

## Crafting panel — press C to toggle.
## Entirely client-side; inventory is client-authoritative so no RPC needed.

# ── Recipes ────────────────────────────────────────────────────────────────────
# Each entry: [inputs: Array[String], output_name, output_type, output_effects, description, gw, gh]
const RECIPES: Array = [
	[["Bandage", "Bandage"],         "Field Dressing",  ItemData.Type.BANDAGE,   {"health": 35.0, "bleed": -2.0},                         "2 Bandages → stronger patch",          2, 1],
	[["Bandage", "Painkillers"],     "Field Medkit",    ItemData.Type.BANDAGE,   {"health": 30.0, "bleed": -1.0},                         "Bandage + Painkillers → field kit",    2, 2],
	[["Canned Food", "Protein Bar"], "Hearty Meal",     ItemData.Type.FOOD,      {"hunger": 60.0, "health":  5.0},                        "Two rations → full meal",              2, 2],
	[["Pistol Mag", "Pistol Mag"],   "Extended Mag",    ItemData.Type.MISC,      {"ammo_count": 30},                                      "2 pistol mags → extended mag",         2, 1],
	[["Wild Berries", "Wild Berries"],"Berry Bundle",   ItemData.Type.FOOD,      {"hunger": 28.0},                                        "2 handfuls of berries → bundle",       1, 1],
	[["Water Bottle", "Water Bottle"],"Water Reserve",  ItemData.Type.WATER,     {"thirst": 80.0},                                        "2 water bottles → combined reserve",   1, 2],
	[["T-Shirt", "T-Shirt"],         "Makeshift Bag",   ItemData.Type.CLOTHING,  {"hand_grid": "3x2", "equip_slot": "hand"},              "2 T-Shirts → improvised hand bag",     2, 2],
	[["Bandage", "Bandage"],         "Med Pouch",       ItemData.Type.CLOTHING,  {"pocket_grid": "2x1"},                                  "2 Bandages → small medical pouch",     2, 2],
]

var _inventory: Inventory = null
var _scroll_box: VBoxContainer = null


func _init() -> void:
	title    = "Crafting"
	min_size = Vector2(320.0, 280.0)


func _post_build() -> void:
	var ca := get_content_area()

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	vbox.offset_left  = 6.0
	vbox.offset_right = -6.0
	vbox.offset_top   = 4.0
	ca.add_child(vbox)

	var hint := Label.new()
	hint.text = "Press C to close"
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.50))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	var sep := ColorRect.new()
	sep.color               = Color(0.35, 0.35, 0.30, 0.50)
	sep.custom_minimum_size = Vector2(0.0, 1.0)
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_scroll_box = VBoxContainer.new()
	_scroll_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_box.add_theme_constant_override("separation", 4)
	scroll.add_child(_scroll_box)


func open(inventory: Inventory) -> void:
	_inventory = inventory
	_refresh()
	show()


func close() -> void:
	hide()
	_inventory = null


# ── Refresh recipe list ────────────────────────────────────────────────────────
func _refresh() -> void:
	if _scroll_box == null:
		return
	for child in _scroll_box.get_children():
		child.queue_free()

	for recipe in RECIPES:
		_add_recipe_row(recipe)


func _add_recipe_row(recipe: Array) -> void:
	var inputs: Array[String] = []
	for s: String in recipe[0]:
		inputs.append(s)
	var can_craft := _has_ingredients(inputs)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_scroll_box.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = recipe[1]
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color",
			Color(0.95, 0.95, 0.95) if can_craft else Color(0.50, 0.50, 0.50))
	info.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = recipe[4] as String
	desc_lbl.add_theme_font_size_override("font_size", 9)
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.60))
	info.add_child(desc_lbl)

	var btn := Button.new()
	btn.text      = "Craft"
	btn.disabled  = not can_craft
	btn.custom_minimum_size = Vector2(52.0, 0.0)
	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(_on_craft.bind(recipe))
	row.add_child(btn)


# ── Crafting logic ─────────────────────────────────────────────────────────────
func _has_ingredients(inputs: Array[String]) -> bool:
	if _inventory == null:
		return false
	var needed := {}
	for name in inputs:
		needed[name] = needed.get(name, 0) + 1
	for name: String in needed:
		var count := 0
		for item: ItemData in _inventory.items:
			if item.item_name == name:
				count += 1
		if count < needed[name]:
			return false
	return true


func _on_craft(recipe: Array) -> void:
	if _inventory == null:
		return
	var inputs: Array[String] = []
	for s: String in recipe[0]:
		inputs.append(s)
	if not _has_ingredients(inputs):
		return

	# Remove ingredient items one by one via remove_at() so grids stay in sync.
	var to_remove := inputs.duplicate()
	var i := 0
	while i < _inventory.items.size() and not to_remove.is_empty():
		var item: ItemData = _inventory.items[i]
		var ri := to_remove.find(item.item_name)
		if ri >= 0:
			_inventory.remove_at(i)
			to_remove.remove_at(ri)
			# Don't increment i — list shifted left.
		else:
			i += 1

	# Add crafted item (uses grid size columns 5 & 6 if present, else 1×1).
	var gw: int = recipe[5] if recipe.size() > 5 else 1
	var gh: int = recipe[6] if recipe.size() > 6 else 1
	var output := ItemData.make(recipe[1], recipe[2] as int, recipe[3], "", gw, gh)
	_inventory.add_item(output)
	_inventory.inventory_changed.emit()

	# Toast notification.
	EventBus.item_used.emit(multiplayer.get_unique_id(), "Crafted: " + recipe[1])

	# Refresh the panel.
	_refresh()
