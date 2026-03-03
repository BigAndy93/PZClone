class_name WorldContainer
extends Area2D

## Interactive storage container placed inside buildings by ProceduralBuilding.
## Server generates seeded random loot.  Items are synced to clients on open.
## Interaction: player presses F near the container to open ContainerWindow.

enum ContainerType {
	NIGHTSTAND      = 0,
	WARDROBE        = 1,
	MEDICINE_CABINET = 2,
	FILING_CABINET  = 3,
	LOCKER          = 4,
	FRIDGE          = 5,
	DRESSER         = 6,
}

static var CONTAINER_GRIDS: Dictionary = {
	ContainerType.NIGHTSTAND:       Vector2i(3, 2),
	ContainerType.WARDROBE:         Vector2i(4, 5),
	ContainerType.DRESSER:          Vector2i(4, 3),
	ContainerType.MEDICINE_CABINET: Vector2i(3, 3),
	ContainerType.FILING_CABINET:   Vector2i(3, 4),
	ContainerType.LOCKER:           Vector2i(4, 6),
	ContainerType.FRIDGE:           Vector2i(3, 4),
}

static var CONTAINER_LABELS: Dictionary = {
	ContainerType.NIGHTSTAND:       "Nightstand Drawers",
	ContainerType.WARDROBE:         "Wardrobe",
	ContainerType.DRESSER:          "Dresser",
	ContainerType.MEDICINE_CABINET: "Medicine Cabinet",
	ContainerType.FILING_CABINET:   "Filing Cabinet",
	ContainerType.LOCKER:           "Locker",
	ContainerType.FRIDGE:           "Refrigerator",
}

@export var container_type: int = ContainerType.NIGHTSTAND
@export var zone_type:      int = 0
@export var loot_seed:      int = 0

# Items currently in this container (server-authoritative; replicated on open).
var items: Array[ItemData] = []

# True after the container has been opened at least once (loot already generated).
var _loot_ready: bool = false


func _ready() -> void:
	add_to_group("containers")
	collision_layer = 16   # trigger layer — picked up by player interact_area
	collision_mask  = 0
	# Generate loot on server only.
	if multiplayer.is_server():
		_generate_loot()
	queue_redraw()


# ── Visual indicator ───────────────────────────────────────────────────────────

func _draw() -> void:
	var label   := get_container_label()
	var dot_col := _get_type_color()

	# Glow dot at node origin (furniture position).
	draw_circle(Vector2.ZERO, 5.5, dot_col * Color(1, 1, 1, 0.25))
	draw_circle(Vector2.ZERO, 3.5, dot_col)

	# Name tag above the dot.
	const TAG_W  := 72.0
	const TAG_H  := 11.0
	const TAG_Y  := -22.0
	draw_rect(Rect2(-TAG_W * 0.5, TAG_Y, TAG_W, TAG_H), Color(0.06, 0.06, 0.06, 0.80))
	draw_string(ThemeDB.fallback_font,
		Vector2(-TAG_W * 0.5 + 2.0, TAG_Y + TAG_H - 2.0),
		label, HORIZONTAL_ALIGNMENT_LEFT, TAG_W - 4.0, 8,
		Color(0.90, 0.85, 0.60))

	# Small [F] prompt below name tag.
	draw_string(ThemeDB.fallback_font,
		Vector2(-8.0, TAG_Y + TAG_H + 9.0),
		"[F]", HORIZONTAL_ALIGNMENT_LEFT, 20.0, 7,
		Color(0.55, 0.85, 0.55, 0.80))


func _get_type_color() -> Color:
	match container_type:
		ContainerType.NIGHTSTAND:       return Color(0.75, 0.68, 0.50)   # warm wood
		ContainerType.WARDROBE:         return Color(0.50, 0.62, 0.80)   # steel blue
		ContainerType.MEDICINE_CABINET: return Color(0.38, 0.82, 0.60)   # medical teal
		ContainerType.FILING_CABINET:   return Color(0.62, 0.62, 0.70)   # cool grey
		ContainerType.LOCKER:           return Color(0.48, 0.68, 0.48)   # army green
		ContainerType.FRIDGE:           return Color(0.48, 0.78, 0.90)   # cool blue
		ContainerType.DRESSER:          return Color(0.72, 0.62, 0.45)   # wood brown
	return Color(0.70, 0.70, 0.70)


# ── Loot generation ───────────────────────────────────────────────────────────

func _generate_loot() -> void:
	if _loot_ready:
		return
	_loot_ready = true
	var rng := RandomNumberGenerator.new()
	rng.seed = loot_seed
	var loot := LootTable.get_container_loot(container_type, zone_type, rng)
	for item in loot:
		items.append(item)


# ── Interaction ───────────────────────────────────────────────────────────────

## Called by Player when F is pressed near this container.
## Must have @rpc so clients can invoke it via rpc_id().
@rpc("any_peer", "call_remote", "reliable")
func interact(caller_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	# Serialise items list and send to the requesting client.
	var serialised: Array = []
	for item: ItemData in items:
		serialised.append(item.to_dict())
	if caller_peer_id == 1:
		# Server is the local player — skip the network loopback and open directly.
		_apply_container_open(serialised)
	else:
		rpc_id(caller_peer_id, "rpc_open", serialised)


## Server → client: deliver the item list for display.
@rpc("any_peer", "call_remote", "reliable")
func rpc_open(serialised_items: Array) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	_apply_container_open(serialised_items)


func _apply_container_open(serialised_items: Array) -> void:
	items.clear()
	for d: Dictionary in serialised_items:
		items.append(ItemData.from_dict(d))
	# Tell HUD to open the container window.
	var hud_nodes := get_tree().get_nodes_in_group("hud")
	if not hud_nodes.is_empty():
		var hud = hud_nodes[0]
		if hud.has_method("open_container"):
			hud.open_container(self)


## Client → server: request to take one item by index.
func request_take_item(idx: int, player_inv: Inventory) -> void:
	if idx < 0 or idx >= items.size():
		return
	if multiplayer.is_server():
		_server_take_item(idx, player_inv)
	else:
		rpc_id(1, "rpc_request_take_item", idx)


@rpc("any_peer", "call_remote", "reliable")
func rpc_request_take_item(idx: int) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	# Find the player's inventory.
	var player := GameManager.get_player_node(peer_id)
	if player == null or not is_instance_valid(player):
		return
	_server_take_item(idx, player.inventory)
	# Notify the client of removal.
	rpc_id(peer_id, "rpc_remove_item", idx)


func _server_take_item(idx: int, inv: Inventory) -> void:
	if idx < 0 or idx >= items.size():
		return
	var item := items[idx]
	if inv.add_item(item):
		items.remove_at(idx)


## Server → all clients: remove item at index from local copy.
@rpc("any_peer", "call_local", "reliable")
func rpc_remove_item(idx: int) -> void:
	if idx >= 0 and idx < items.size():
		items.remove_at(idx)


## Client → server: deposit item at flat inventory index into this container.
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_deposit_item(flat_inv_idx: int) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var player := GameManager.get_player_node(peer_id)
	if player == null or not is_instance_valid(player):
		return
	var item: ItemData = (player.inventory as Inventory).remove_at(flat_inv_idx)
	if item == null:
		return
	items.append(item)
	# Refresh the depositing client's container window.
	var serialised: Array = []
	for it: ItemData in items:
		serialised.append(it.to_dict())
	if peer_id == 1:
		_apply_container_open(serialised)
	else:
		rpc_id(peer_id, "rpc_open", serialised)


# ── Helpers for ContainerWindow ───────────────────────────────────────────────

func get_grid_size() -> Vector2i:
	return CONTAINER_GRIDS.get(container_type, Vector2i(3, 2))


func get_container_label() -> String:
	return CONTAINER_LABELS.get(container_type, "Container")
