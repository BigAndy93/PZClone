class_name ItemData
extends Resource

enum Type { FOOD = 0, WATER = 1, BANDAGE = 2, WEAPON = 3, MISC = 4, CLOTHING = 5 }

# Placeholder slot colors per type — used by LootItem visuals and HUD slots.
const TYPE_COLORS: Array[Color] = [
	Color(0.90, 0.60, 0.20),  # FOOD     — orange
	Color(0.25, 0.55, 0.90),  # WATER    — blue
	Color(0.85, 0.25, 0.25),  # BANDAGE  — red
	Color(0.55, 0.55, 0.55),  # WEAPON   — gray
	Color(0.70, 0.65, 0.45),  # MISC     — tan
	Color(0.35, 0.55, 0.75),  # CLOTHING — steel blue
]

@export var item_name:   String     = "Item"
@export var item_type:   int        = Type.MISC
@export var weight:      float      = 0.5
@export var grid_w:      int        = 1   # cells wide in inventory grid
@export var grid_h:      int        = 1   # cells tall in inventory grid
# Stat deltas applied when used.
# Special key "bleed": negative value = call remove_bleed(abs(v)).
@export var stat_effects: Dictionary = {}
@export var use_message: String     = ""


static func make(
		name_str: String,
		type: int,
		effects: Dictionary,
		msg: String = "",
		gw: int = 1,
		gh: int = 1) -> ItemData:
	var d            := ItemData.new()
	d.item_name      = name_str
	d.item_type      = type
	d.stat_effects   = effects
	d.use_message    = msg
	d.grid_w         = gw
	d.grid_h         = gh
	return d


## Serialise to a plain Dictionary for RPC transport.
func to_dict() -> Dictionary:
	return {
		"item_name":    item_name,
		"item_type":    item_type,
		"stat_effects": stat_effects.duplicate(),
		"use_message":  use_message,
		"grid_w":       grid_w,
		"grid_h":       grid_h,
	}


## Reconstruct an ItemData from a serialised Dictionary.
static func from_dict(d: Dictionary) -> ItemData:
	return ItemData.make(
		d.get("item_name",   "Unknown"),
		d.get("item_type",   Type.MISC),
		d.get("stat_effects", {}),
		d.get("use_message", ""),
		d.get("grid_w",      1),
		d.get("grid_h",      1))
