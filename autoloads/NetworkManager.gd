extends Node

signal server_created()
signal joined_server(peer_id: int)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal player_names_updated()

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func set_local_name(player_name: String) -> void:
	var my_id := multiplayer.get_unique_id() if multiplayer.multiplayer_peer else 1
	if GameManager._players.has(my_id):
		GameManager._players[my_id].player_name = player_name


func host_game(port: int = DEFAULT_PORT) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("NetworkManager: failed to create server on port %d (error %d)" % [port, err])
		return
	multiplayer.multiplayer_peer = peer
	print("NetworkManager: server started on port %d" % port)
	server_created.emit()
	# Server is also peer 1
	GameManager.register_player(1, PlayerSpawnData.new())


func join_game(address: String, port: int = DEFAULT_PORT) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("NetworkManager: failed to connect to %s:%d (error %d)" % [address, port, err])
		return
	multiplayer.multiplayer_peer = peer
	print("NetworkManager: connecting to %s:%d" % [address, port])


func disconnect_from_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null


func is_server() -> bool:
	return multiplayer.is_server()


func get_my_id() -> int:
	return multiplayer.get_unique_id()


# ── RPC ──────────────────────────────────────────────────────────────────────

@rpc("authority", "call_local", "reliable")
func rpc_start_game() -> void:
	GameManager.change_phase(GameManager.Phase.LOADING)
	get_tree().change_scene_to_file("res://scenes/world/World.tscn")


# ── Callbacks ────────────────────────────────────────────────────────────────

func _on_peer_connected(peer_id: int) -> void:
	print("NetworkManager: peer connected %d" % peer_id)
	if multiplayer.is_server():
		GameManager.register_player(peer_id, PlayerSpawnData.new())
		# Inform the new client of all currently connected peers.
		rpc_id(peer_id, "rpc_sync_peer_list", GameManager.get_all_peer_ids())
		# Broadcast updated name list to all (new client will send their name shortly).
		rpc_broadcast_player_names.rpc(GameManager.get_all_player_names())
	peer_connected.emit(peer_id)


## Server → new client: replay all existing peer IDs so their lobby UI is correct.
@rpc("authority", "call_remote", "reliable")
func rpc_sync_peer_list(peer_ids: Array) -> void:
	for pid: int in peer_ids:
		if pid != multiplayer.get_unique_id():
			peer_connected.emit(pid)


func _on_peer_disconnected(peer_id: int) -> void:
	print("NetworkManager: peer disconnected %d" % peer_id)
	GameManager.unregister_player(peer_id)
	peer_disconnected.emit(peer_id)


func _on_connected_to_server() -> void:
	var my_id := multiplayer.get_unique_id()
	print("NetworkManager: connected as peer %d" % my_id)
	joined_server.emit(my_id)
	GameManager.register_player(my_id, PlayerSpawnData.new())
	# Send our name to the server.
	rpc_id(1, "rpc_register_player_name", GameManager.get_player_name(my_id))


func _on_connection_failed() -> void:
	push_error("NetworkManager: connection failed")
	multiplayer.multiplayer_peer = null


func _on_server_disconnected() -> void:
	push_error("NetworkManager: server disconnected")
	multiplayer.multiplayer_peer = null
	GameManager.change_phase(GameManager.Phase.LOBBY)
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")


## Client → server: register a player name.
@rpc("any_peer", "call_remote", "reliable")
func rpc_register_player_name(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if GameManager._players.has(sender_id):
		GameManager._players[sender_id].player_name = player_name.strip_edges().left(16)
	rpc_broadcast_player_names.rpc(GameManager.get_all_player_names())


## Server → all peers: sync the full name map.
@rpc("authority", "call_local", "reliable")
func rpc_broadcast_player_names(names: Dictionary) -> void:
	for pid: int in names:
		if GameManager._players.has(pid):
			GameManager._players[pid].player_name = names[pid]
	player_names_updated.emit()
