class_name LootTable
extends RefCounted

# ── Grid size table ────────────────────────────────────────────────────────────
# Maps item name → [grid_w, grid_h].  All items not listed default to 1×1.
static func _gs(name_str: String) -> Array:
	match name_str:
		# 1×2 — tall
		"Water Bottle", "Soda", "Energy Drink", "T-Shirt", "Muddy Water":
			return [1, 2]
		# 2×1 — wide
		"Canned Food", "Suture Kit", "Splint", "Antibiotics", "Pistol", "Pistol Mag", "Field Dressing":
			return [2, 1]
		# 3×1 — long
		"Kitchen Knife", "Crowbar", "Metal Pipe":
			return [3, 1]
		# 4×1 — very long
		"Rifle", "Rifle Clip":
			return [4, 1]
		# 2×2 — bulky
		"First Aid Kit", "Jacket", "Work Jacket", "Winter Coat", "Backpack", "Work Vest", "Tactical Vest", "Cargo Pants", "Small Backpack", "Satchel", "Field Medkit", "Hearty Meal":
			return [2, 2]
		# 2×3 — large backpack
		"Hiking Pack":
			return [2, 3]
		# 3×2 — duffel bag (hand slot)
		"Duffel Bag":
			return [3, 2]
		# Default 1×1
		_:
			return [1, 1]


static func _make(name_str: String, type: int, effects: Dictionary, msg: String = "") -> ItemData:
	var gs := _gs(name_str)
	return ItemData.make(name_str, type, effects, msg, gs[0], gs[1])


# ── Zone loot ──────────────────────────────────────────────────────────────────
# Returns a randomly chosen ItemData for the zone, or null for sparse zones.
static func get_item_for_zone(zone_type: int, rng: RandomNumberGenerator) -> ItemData:
	# Each entry: [name, type, stat_effects, weight]
	var pool: Array = []

	match zone_type:
		BuildingData.ZoneType.RESIDENTIAL:
			pool = [
				["Canned Food",   ItemData.Type.FOOD,     {"hunger":  35.0},                                                              4],
				["Water Bottle",  ItemData.Type.WATER,    {"thirst":  40.0},                                                              4],
				["Bandage",       ItemData.Type.BANDAGE,  {"health":  15.0, "bleed": -1.0},                                               3],
				["Kitchen Knife", ItemData.Type.WEAPON,   {"melee_bonus": 20.0},                                                          2],
				["Painkillers",   ItemData.Type.MISC,     {"health":  10.0},                                                              2],
				["Coffee",        ItemData.Type.MISC,     {"fatigue": 20.0},                                                              2],
				["Pistol",        ItemData.Type.WEAPON,   {"projectile_damage": 45.0, "fire_range": 550.0},                               1],
				["Pistol Mag",    ItemData.Type.MISC,     {"ammo_count": 15},                                                             2],
				["T-Shirt",       ItemData.Type.CLOTHING, {"insulation": 0.10},                                                           2],
				["Jacket",        ItemData.Type.CLOTHING, {"insulation": 0.40, "pocket_grid": "3x2"},                                     1],
				["Cargo Pants",   ItemData.Type.CLOTHING, {"insulation": 0.10, "pocket_grid": "3x1"},                                     1],
				["Satchel",       ItemData.Type.CLOTHING, {"insulation": 0.00, "hand_grid": "3x2", "equip_slot": "hand"},                 1],
			]
		BuildingData.ZoneType.COMMERCIAL:
			pool = [
				["Protein Bar",   ItemData.Type.FOOD,     {"hunger":  20.0},                                                              3],
				["Soda",          ItemData.Type.WATER,    {"thirst":  25.0},                                                              3],
				["Energy Drink",  ItemData.Type.MISC,     {"fatigue": 30.0, "thirst": -5.0},                                              2],
				["Coffee",        ItemData.Type.MISC,     {"fatigue": 20.0},                                                              2],
				["First Aid Kit", ItemData.Type.BANDAGE,  {"health":  40.0, "bleed": -2.0},                                               3],
				["Crowbar",       ItemData.Type.WEAPON,   {"melee_bonus": 35.0},                                                          3],
				["Antibiotics",   ItemData.Type.MISC,     {"health":  20.0, "infection": -1.0},                                          1],
				["Suture Kit",    ItemData.Type.BANDAGE,  {"health":   5.0, "deep_wound": -1},                                            1],
				["Splint",        ItemData.Type.MISC,     {"fracture": -1},                                                               1],
				["Pistol",        ItemData.Type.WEAPON,   {"projectile_damage": 45.0, "fire_range": 550.0},                               2],
				["Pistol Mag",    ItemData.Type.MISC,     {"ammo_count": 15},                                                             3],
				["Rifle",         ItemData.Type.WEAPON,   {"projectile_damage": 75.0, "fire_range": 800.0},                               1],
				["Rifle Clip",    ItemData.Type.MISC,     {"ammo_count": 8},                                                              2],
				["Jacket",        ItemData.Type.CLOTHING, {"insulation": 0.40, "pocket_grid": "3x2"},                                     1],
				["Work Vest",     ItemData.Type.CLOTHING, {"insulation": 0.25, "pocket_grid": "3x2"},                                     1],
			]
		BuildingData.ZoneType.INDUSTRIAL:
			pool = [
				["Crowbar",       ItemData.Type.WEAPON,   {"melee_bonus": 35.0},                                                          4],
				["Metal Pipe",    ItemData.Type.WEAPON,   {"melee_bonus": 25.0},                                                          3],
				["Canned Food",   ItemData.Type.FOOD,     {"hunger":  30.0},                                                              2],
				["Water Bottle",  ItemData.Type.WATER,    {"thirst":  35.0},                                                              2],
				["Bandage",       ItemData.Type.BANDAGE,  {"health":  15.0, "bleed": -1.0},                                               2],
				["Rifle",         ItemData.Type.WEAPON,   {"projectile_damage": 75.0, "fire_range": 800.0},                               1],
				["Rifle Clip",    ItemData.Type.MISC,     {"ammo_count": 8},                                                              3],
				["Tactical Vest", ItemData.Type.CLOTHING, {"insulation": 0.20, "pocket_grid": "4x3"},                                     1],
				["Small Backpack",ItemData.Type.CLOTHING, {"insulation": 0.05, "back_grid": "4x3", "equip_slot": "back"},                 1],
			]
		BuildingData.ZoneType.RURAL:
			pool = [
				["Canned Food",   ItemData.Type.FOOD,     {"hunger":  40.0},                                                              4],
				["Wild Berries",  ItemData.Type.FOOD,     {"hunger":  12.0},                                                              3],
				["Water Bottle",  ItemData.Type.WATER,    {"thirst":  40.0},                                                              3],
				["Bandage",       ItemData.Type.BANDAGE,  {"health":  15.0, "bleed": -1.0},                                               2],
				["Kitchen Knife", ItemData.Type.WEAPON,   {"melee_bonus": 20.0},                                                          2],
				["Pistol",        ItemData.Type.WEAPON,   {"projectile_damage": 45.0, "fire_range": 550.0},                               1],
				["Pistol Mag",    ItemData.Type.MISC,     {"ammo_count": 15},                                                             1],
				["T-Shirt",       ItemData.Type.CLOTHING, {"insulation": 0.10},                                                           2],
				["Work Jacket",   ItemData.Type.CLOTHING, {"insulation": 0.45, "pocket_grid": "4x2"},                                     1],
				["Winter Coat",   ItemData.Type.CLOTHING, {"insulation": 0.70, "pocket_grid": "3x2"},                                     1],
				["Backpack",      ItemData.Type.CLOTHING, {"insulation": 0.05, "back_grid": "5x4", "equip_slot": "back"},                 1],
			]
		_:  # FOREST, EMPTY — scarce, foraged only
			if rng.randf() > 0.40:
				return null   # 60% chance of empty spot
			pool = [
				["Wild Berries",  ItemData.Type.FOOD,    {"hunger":  12.0},                   3],
				["Muddy Water",   ItemData.Type.WATER,   {"thirst":  18.0, "health": -5.0},   2],
			]

	if pool.is_empty():
		return null

	# Build weighted flat list then pick.
	var flat: Array = []
	for entry in pool:
		for _i in entry[3]:
			flat.append(entry)

	var chosen: Array = flat[rng.randi() % flat.size()]
	return _make(chosen[0], chosen[1], chosen[2])


# ── Container loot ─────────────────────────────────────────────────────────────
## Returns 0–3 items appropriate for the given container type and zone.
## 25% chance of empty (already looted look) for scarcity.
static func get_container_loot(
		container_type: int,
		_zone_type: int,
		rng: RandomNumberGenerator) -> Array[ItemData]:

	if rng.randf() < 0.25:
		return []   # empty container

	# Pool format: [name, type, effects, rarity_weight]
	var pool: Array = []

	match container_type:
		0:  # NIGHTSTAND
			pool = [
				["Bandage",      ItemData.Type.BANDAGE,  {"health": 15.0, "bleed": -1.0},                           4],
				["Painkillers",  ItemData.Type.MISC,     {"health": 10.0},                                          3],
				["T-Shirt",      ItemData.Type.CLOTHING, {"insulation": 0.10},                                      2],
				["Pistol Mag",   ItemData.Type.MISC,     {"ammo_count": 15},                                        2],
				["Pistol",       ItemData.Type.WEAPON,   {"projectile_damage": 45.0, "fire_range": 550.0},           1],
			]
		1:  # WARDROBE
			pool = [
				["T-Shirt",      ItemData.Type.CLOTHING, {"insulation": 0.10},                                      4],
				["Jacket",       ItemData.Type.CLOTHING, {"insulation": 0.40, "pocket_grid": "3x2"},                2],
				["Work Jacket",  ItemData.Type.CLOTHING, {"insulation": 0.45, "pocket_grid": "4x2"},                2],
				["Satchel",      ItemData.Type.CLOTHING, {"insulation": 0.00, "hand_grid": "3x2", "equip_slot": "hand"}, 2],
				["Backpack",     ItemData.Type.CLOTHING, {"insulation": 0.05, "back_grid": "5x4", "equip_slot": "back"}, 1],
				["Winter Coat",  ItemData.Type.CLOTHING, {"insulation": 0.70, "pocket_grid": "3x2"},                1],
			]
		2:  # MEDICINE_CABINET
			pool = [
				["Bandage",      ItemData.Type.BANDAGE,  {"health": 15.0, "bleed": -1.0},                           4],
				["Painkillers",  ItemData.Type.MISC,     {"health": 10.0},                                          4],
				["Antibiotics",  ItemData.Type.MISC,     {"health": 20.0, "infection": -1.0},                       2],
				["Suture Kit",   ItemData.Type.BANDAGE,  {"health":  5.0, "deep_wound": -1},                        2],
				["First Aid Kit",ItemData.Type.BANDAGE,  {"health": 40.0, "bleed": -2.0},                           1],
			]
		3:  # FILING_CABINET
			pool = [
				["Bandage",      ItemData.Type.BANDAGE,  {"health": 15.0, "bleed": -1.0},                           3],
				["Protein Bar",  ItemData.Type.FOOD,     {"hunger": 20.0},                                          3],
				["Pistol Mag",   ItemData.Type.MISC,     {"ammo_count": 15},                                        2],
				["Crowbar",      ItemData.Type.WEAPON,   {"melee_bonus": 35.0},                                     2],
				["Pistol",       ItemData.Type.WEAPON,   {"projectile_damage": 45.0, "fire_range": 550.0},           1],
			]
		4:  # LOCKER
			pool = [
				["Crowbar",      ItemData.Type.WEAPON,   {"melee_bonus": 35.0},                                     4],
				["Metal Pipe",   ItemData.Type.WEAPON,   {"melee_bonus": 25.0},                                     3],
				["Rifle Clip",   ItemData.Type.MISC,     {"ammo_count": 8},                                         3],
				["Tactical Vest",ItemData.Type.CLOTHING, {"insulation": 0.20, "pocket_grid": "4x3"},                2],
				["Rifle",        ItemData.Type.WEAPON,   {"projectile_damage": 75.0, "fire_range": 800.0},           1],
			]
		5:  # FRIDGE
			pool = [
				["Canned Food",  ItemData.Type.FOOD,     {"hunger": 35.0},                                          4],
				["Water Bottle", ItemData.Type.WATER,    {"thirst": 40.0},                                          4],
				["Soda",         ItemData.Type.WATER,    {"thirst": 25.0},                                          3],
				["Energy Drink", ItemData.Type.MISC,     {"fatigue": 30.0, "thirst": -5.0},                         2],
			]
		6:  # DRESSER
			pool = [
				["T-Shirt",      ItemData.Type.CLOTHING, {"insulation": 0.10},                                      4],
				["Jacket",       ItemData.Type.CLOTHING, {"insulation": 0.40, "pocket_grid": "3x2"},                2],
				["Cargo Pants",  ItemData.Type.CLOTHING, {"insulation": 0.10, "pocket_grid": "3x1"},                2],
				["Bandage",      ItemData.Type.BANDAGE,  {"health": 15.0, "bleed": -1.0},                           2],
			]
		_:
			return []

	if pool.is_empty():
		return []

	# Build weighted flat list.
	var flat: Array = []
	for entry in pool:
		for _i in entry[3]:
			flat.append(entry)

	# Pick 1–3 unique items.
	var count  := rng.randi_range(1, 3)
	var result : Array[ItemData] = []
	var used   := {}
	var tries  := 0
	while result.size() < count and tries < 30:
		tries += 1
		var chosen: Array = flat[rng.randi() % flat.size()]
		var key: String   = chosen[0]
		if not used.has(key):
			used[key] = true
			result.append(_make(chosen[0], chosen[1], chosen[2]))

	return result
