class_name Lobby
extends Control

@onready var host_btn: Button = $VBox/HostButton
@onready var join_btn: Button = $VBox/JoinButton
@onready var address_field: LineEdit = $VBox/AddressField
@onready var port_field: LineEdit = $VBox/PortField
@onready var start_btn: Button = $VBox/StartButton
@onready var status_label: Label = $VBox/StatusLabel
@onready var players_list: VBoxContainer = $VBox/PlayersList

var _name_field: LineEdit


func _ready() -> void:
	start_btn.hide()

	# Name input — inserted at the top of the VBox programmatically.
	_name_field = LineEdit.new()
	_name_field.placeholder_text = "Enter your name…"
	_name_field.max_length = 16
	_name_field.text = "Survivor"
	$VBox.add_child(_name_field)
	$VBox.move_child(_name_field, 0)

	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	start_btn.pressed.connect(_on_start_pressed)

	NetworkManager.server_created.connect(_on_server_created)
	NetworkManager.joined_server.connect(_on_joined_server)
	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.player_names_updated.connect(_on_player_names_updated)


func _on_host_pressed() -> void:
	var port := int(port_field.text) if port_field.text.is_valid_int() else NetworkManager.DEFAULT_PORT
	NetworkManager.host_game(port)
	NetworkManager.set_local_name(_name_field.text.strip_edges().left(16))
	status_label.text = "Hosting on port %d..." % port


func _on_join_pressed() -> void:
	var addr := address_field.text if address_field.text != "" else "127.0.0.1"
	var port := int(port_field.text) if port_field.text.is_valid_int() else NetworkManager.DEFAULT_PORT
	# Store name locally so it's ready when _on_connected_to_server fires.
	var my_name := _name_field.text.strip_edges().left(16)
	if my_name.is_empty():
		my_name = "Survivor"
	# Pre-store so rpc_register_player_name can read it after registration.
	# (GameManager.register_player creates the entry; we patch the name immediately after.)
	NetworkManager.join_game(addr, port)
	status_label.text = "Connecting to %s:%d..." % [addr, port]
	# Cache name for use in _on_connected_to_server via a deferred property set.
	_name_field.text = my_name


func _on_server_created() -> void:
	status_label.text = "Server running. Waiting for players..."
	start_btn.show()
	_add_player_entry(1, GameManager.get_player_name(1))


func _on_joined_server(peer_id: int) -> void:
	# Patch our name into PlayerSpawnData now that we're registered, then send to server.
	var my_name := _name_field.text.strip_edges().left(16)
	if my_name.is_empty():
		my_name = "Survivor"
	GameManager._players[peer_id].player_name = my_name
	NetworkManager.rpc_id(1, "rpc_register_player_name", my_name)
	status_label.text = "Connected as %s (ID: %d)" % [my_name, peer_id]
	_add_player_entry(peer_id, my_name)


func _on_peer_connected(peer_id: int) -> void:
	_add_player_entry(peer_id, GameManager.get_player_name(peer_id))


func _on_peer_disconnected(peer_id: int) -> void:
	_remove_player_entry(peer_id)


func _on_player_names_updated() -> void:
	# Refresh all labels with the latest synced names.
	for pid: int in GameManager.get_all_peer_ids():
		var lbl: Label = players_list.get_node_or_null("Player_%d" % pid)
		if lbl:
			lbl.text = GameManager.get_player_name(pid)


func _on_start_pressed() -> void:
	if not multiplayer.is_server():
		return
	NetworkManager.rpc_start_game()


func _add_player_entry(peer_id: int, player_name: String) -> void:
	if players_list.get_node_or_null("Player_%d" % peer_id):
		return  # Already listed
	var lbl := Label.new()
	lbl.name = "Player_%d" % peer_id
	lbl.text = player_name
	players_list.add_child(lbl)


func _remove_player_entry(peer_id: int) -> void:
	var lbl: Node = players_list.get_node_or_null("Player_%d" % peer_id)
	if lbl:
		lbl.queue_free()
