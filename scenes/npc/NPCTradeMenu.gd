class_name NPCTradeMenu
extends Control

## Local HUD node shown to one player at a time. Populated by NPC RPC.

signal trade_closed()

@onready var item_list: VBoxContainer = $Panel/VBox/ItemList
@onready var close_btn: Button = $Panel/VBox/CloseButton

var _npc_id: int = 0
var _peer_id: int = 0
var _trade_items: Array = []


func _ready() -> void:
	hide()
	close_btn.pressed.connect(_on_close_pressed)


func open_for_peer(npc_id: int, peer_id: int, items: Array) -> void:
	_npc_id = npc_id
	_peer_id = peer_id
	_trade_items = items
	_populate_items()
	show()


func _populate_items() -> void:
	for child in item_list.get_children():
		child.queue_free()
	for item in _trade_items:
		var btn := Button.new()
		btn.text = "%s — %d caps" % [item.get("name", "?"), item.get("cost", 0)]
		btn.pressed.connect(_on_item_selected.bind(item))
		item_list.add_child(btn)


func _on_item_selected(item: Dictionary) -> void:
	var npc := instance_from_id(_npc_id)
	if npc and npc.has_method("rpc_execute_trade"):
		npc.rpc_id(1, "rpc_execute_trade", item.get("name", ""))
	hide()


func _on_close_pressed() -> void:
	trade_closed.emit()
	hide()
