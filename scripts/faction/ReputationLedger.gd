class_name ReputationLedger
extends RefCounted

## Lightweight in-memory ledger — used internally by FactionManager.
## Stored as { faction_id: { peer_id: float } }

var _data: Dictionary = {}


func get_rep(faction_id: String, peer_id: int) -> float:
	return _data.get(faction_id, {}).get(peer_id, 0.0)


func set_rep(faction_id: String, peer_id: int, value: float) -> void:
	if not _data.has(faction_id):
		_data[faction_id] = {}
	_data[faction_id][peer_id] = clampf(value, -100.0, 100.0)


func modify_rep(faction_id: String, peer_id: int, delta: float) -> float:
	var new_val := clampf(get_rep(faction_id, peer_id) + delta, -100.0, 100.0)
	set_rep(faction_id, peer_id, new_val)
	return new_val


func serialize() -> Dictionary:
	return _data.duplicate(true)


func deserialize(data: Dictionary) -> void:
	_data = data.duplicate(true)
