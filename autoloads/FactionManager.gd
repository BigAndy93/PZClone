extends Node

signal reputation_changed(faction_id: String, peer_id: int, new_value: float)

# Structure: { faction_id: { peer_id: float } }
var _reputations: Dictionary = {}

# Cached faction resources: { faction_id: FactionData }
var _factions: Dictionary = {}


func _ready() -> void:
	_load_factions()


func _load_factions() -> void:
	var survivors_data: FactionData = load("res://resources/factions/faction_survivors.tres")
	if survivors_data:
		_factions[survivors_data.faction_id] = survivors_data
		_reputations[survivors_data.faction_id] = {}
		print("FactionManager: loaded faction '%s'" % survivors_data.faction_id)


func get_reputation(faction_id: String, peer_id: int) -> float:
	if not _reputations.has(faction_id):
		return 0.0
	return _reputations[faction_id].get(peer_id, 0.0)


func modify_reputation(faction_id: String, peer_id: int, delta: float) -> void:
	if not multiplayer.is_server():
		push_warning("FactionManager.modify_reputation called on client — use RPC")
		return
	if not _reputations.has(faction_id):
		_reputations[faction_id] = {}
	var old_val: float = _reputations[faction_id].get(peer_id, 0.0)
	var new_val: float = clampf(old_val + delta, -100.0, 100.0)
	_reputations[faction_id][peer_id] = new_val
	reputation_changed.emit(faction_id, peer_id, new_val)
	# Sync to owning client
	rpc_id(peer_id, "rpc_receive_reputation", faction_id, new_val)


func get_disposition(faction_id: String, peer_id: int) -> String:
	var rep := get_reputation(faction_id, peer_id)
	var faction: FactionData = _factions.get(faction_id, null)
	if faction == null:
		return "neutral"
	if rep <= faction.hostile_threshold:
		return "hostile"
	elif rep < faction.friendly_threshold:
		return "neutral"
	elif rep < faction.allied_threshold:
		return "friendly"
	else:
		return "allied"


func apply_reputation_event(faction_id: String, peer_id: int, event_key: String) -> void:
	var faction: FactionData = _factions.get(faction_id, null)
	if faction == null:
		return
	var delta: float = faction.reputation_events.get(event_key, 0.0)
	if delta != 0.0:
		modify_reputation(faction_id, peer_id, delta)
		EventBus.reputation_event.emit(faction_id, peer_id, event_key, delta)


@rpc("authority", "call_remote", "reliable")
func rpc_receive_reputation(faction_id: String, new_value: float) -> void:
	# Called on a specific client to update their local rep display
	var peer_id := multiplayer.get_unique_id()
	if not _reputations.has(faction_id):
		_reputations[faction_id] = {}
	_reputations[faction_id][peer_id] = new_value
	reputation_changed.emit(faction_id, peer_id, new_value)
