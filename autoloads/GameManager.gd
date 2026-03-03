extends Node

enum Phase { LOBBY, LOADING, PLAYING, PAUSED, GAME_OVER }

signal game_phase_changed(new_phase: Phase)
signal player_died(peer_id: int)
signal player_downed(peer_id: int)

var current_phase: Phase = Phase.LOBBY
var _players: Dictionary = {}  # peer_id -> Player node


func change_phase(new_phase: Phase) -> void:
	if current_phase == new_phase:
		return
	current_phase = new_phase
	game_phase_changed.emit(new_phase)


func register_player(peer_id: int, data: PlayerSpawnData) -> void:
	_players[peer_id] = data
	print("GameManager: registered player %d" % peer_id)


func unregister_player(peer_id: int) -> void:
	_players.erase(peer_id)


func get_player_node(peer_id: int) -> Node:
	var players_container: Node = get_tree().get_first_node_in_group("players_container")
	if players_container == null:
		return null
	for child in players_container.get_children():
		if child.is_in_group("players") and child.get_multiplayer_authority() == peer_id:
			return child
	return null


func get_all_peer_ids() -> Array:
	return _players.keys()


func get_player_name(peer_id: int) -> String:
	if _players.has(peer_id):
		return _players[peer_id].player_name
	return "Survivor"


func get_all_player_names() -> Dictionary:
	var result: Dictionary = {}
	for pid: int in _players:
		result[pid] = _players[pid].player_name
	return result
