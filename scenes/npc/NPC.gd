class_name NPC
extends CharacterBody2D

@export var faction_id:           String = "survivors"
@export var npc_name:             String = "Maya"
@export var dialogue_key_prefix:  String = "survivors"

## Items this NPC will sell. Each entry: { "name": String, "cost": int }
@export var trade_inventory: Array = [
	{"name": "Canned Food",  "cost": 5},
	{"name": "Water Bottle", "cost": 3},
	{"name": "Bandage",      "cost": 8},
	{"name": "Energy Drink", "cost": 6},
	{"name": "Coffee",       "cost": 4},
]

# ── Wander ─────────────────────────────────────────────────────────────────────
const WANDER_SPEED:     float = 28.0
const WANDER_RADIUS:    float = 110.0
const WANDER_PAUSE_MIN: float = 3.0
const WANDER_PAUSE_MAX: float = 7.5

var _home_position: Vector2 = Vector2.ZERO
var _wander_target: Vector2 = Vector2.ZERO
var _wander_timer:  float   = 0.0
var _npc_facing:    Vector2 = Vector2.DOWN

# ── Sync ───────────────────────────────────────────────────────────────────────
var sync_position: Vector2 = Vector2.ZERO
var sync_facing:   Vector2 = Vector2.DOWN

# ── Internal ───────────────────────────────────────────────────────────────────
var _dialogue: NPCDialogue = null

# ── Visual node refs (set in _build_visual) ────────────────────────────────────
var _npc_visual: Node2D    = null
var _npc_head:   Polygon2D = null
var _npc_arm_l:  Line2D    = null
var _npc_arm_r:  Line2D    = null
var _npc_leg_l:  Line2D    = null
var _npc_leg_r:  Line2D    = null
var _last_dir8:  int       = -1

# ── 8-direction pose data ──────────────────────────────────────────────────────
# Canonical poses: 0=E, 1=SE, 2=S, 3=N, 4=NE.
# Per-pose layout: [arm_l[p0,p1], arm_r[p0,p1], leg_l[p0,p1], leg_r[p0,p1], head_x_off]
static var _NPC_POSES: Array = [
	# 0 = E — side profile; arm_l back, arm_r reaches forward
	[[Vector2(-1,-9),Vector2(-5,-3)],  [Vector2(1,-9),Vector2(9,-1)],
	 [Vector2(-2,3), Vector2(-3,13)],  [Vector2(2,3), Vector2(4,13)],  1.0],
	# 1 = SE — front-right 3/4
	[[Vector2(-1,-9),Vector2(-9,-1)],  [Vector2(1,-9),Vector2(10,-1)],
	 [Vector2(-2,3), Vector2(-5,13)],  [Vector2(2,3), Vector2(6,13)],  0.5],
	# 2 = S — front view (original geometry)
	[[Vector2(-1,-9),Vector2(-10,-1)], [Vector2(1,-9),Vector2(10,-1)],
	 [Vector2(-2,3), Vector2(-6,13)],  [Vector2(2,3), Vector2(6,13)],  0.0],
	# 3 = N — back view; arms angled up and back
	[[Vector2(-1,-9),Vector2(-8,-4)],  [Vector2(1,-9),Vector2(8,-4)],
	 [Vector2(-2,3), Vector2(-4,13)],  [Vector2(2,3), Vector2(4,13)],  0.0],
	# 4 = NE — back-right 3/4
	[[Vector2(-1,-9),Vector2(-7,-3)],  [Vector2(1,-9),Vector2(9,-1)],
	 [Vector2(-2,3), Vector2(-4,13)],  [Vector2(2,3), Vector2(5,13)],  0.5],
]
# dir8: 0=E,1=SE,2=S,3=SW,4=W,5=NW,6=N,7=NE → [canonical_idx, flip]
static var _DIR8_MAP: Array = [
	[0, false], [1, false], [2, false], [1, true],
	[0, true],  [4, true],  [3, false], [4, false],
]

static func _facing_to_dir8(v: Vector2) -> int:
	return int(fposmod(v.angle(), TAU) / (TAU / 8.0) + 0.5) % 8

func _apply_npc_pose(dir8: int) -> void:
	var entry: Array = _DIR8_MAP[dir8]
	var pose:  Array = _NPC_POSES[entry[0]]
	if _npc_arm_l: _npc_arm_l.set_point_position(0, pose[0][0]); _npc_arm_l.set_point_position(1, pose[0][1])
	if _npc_arm_r: _npc_arm_r.set_point_position(0, pose[1][0]); _npc_arm_r.set_point_position(1, pose[1][1])
	if _npc_leg_l: _npc_leg_l.set_point_position(0, pose[2][0]); _npc_leg_l.set_point_position(1, pose[2][1])
	if _npc_leg_r: _npc_leg_r.set_point_position(0, pose[3][0]); _npc_leg_r.set_point_position(1, pose[3][1])
	if _npc_head:  _npc_head.position = Vector2(float(pose[4]), 0.0)

func _update_npc_visual() -> void:
	if _npc_visual == null:
		return
	var facing := sync_facing
	var dir8   := _facing_to_dir8(facing)
	if dir8 != _last_dir8:
		_last_dir8 = dir8
		_apply_npc_pose(dir8)
	var flip: bool = _DIR8_MAP[dir8][1]
	_npc_visual.scale.x = -1.0 if flip else 1.0

@onready var interact_label:    Label  = $InteractLabel
@onready var dialogue_trigger:  Area2D = $DialogueTriggerArea


func _ready() -> void:
	add_to_group("npcs")
	_dialogue = NPCDialogue.new()

	_build_visual()
	_setup_sync()

	if dialogue_trigger:
		dialogue_trigger.body_entered.connect(_on_trigger_entered)
		dialogue_trigger.body_exited.connect(_on_trigger_exited)

	interact_label.hide()

	if multiplayer.is_server():
		_home_position = global_position
		_wander_target = global_position
		_wander_timer  = randf_range(WANDER_PAUSE_MIN, WANDER_PAUSE_MAX)


# ── Physics ────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		global_position = global_position.lerp(sync_position, delta * 10.0)
		return

	_update_wander(delta)
	sync_position = global_position


func _process(_delta: float) -> void:
	_update_npc_visual()


func _update_wander(delta: float) -> void:
	if global_position.distance_to(_wander_target) > 5.0:
		velocity = global_position.direction_to(_wander_target) * WANDER_SPEED
		_npc_facing  = velocity.normalized()
		sync_facing  = _npc_facing
	else:
		velocity = Vector2.ZERO
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			var angle       := randf() * TAU
			var r           := randf_range(16.0, WANDER_RADIUS)
			_wander_target   = _home_position + Vector2(cos(angle), sin(angle)) * r
			_wander_timer    = randf_range(WANDER_PAUSE_MIN, WANDER_PAUSE_MAX)
	move_and_slide()


# ── Multiplayer sync setup ─────────────────────────────────────────────────────

func _setup_sync() -> void:
	var ms     := MultiplayerSynchronizer.new()
	ms.name     = "MultiplayerSynchronizer"
	var config := SceneReplicationConfig.new()
	config.add_property(NodePath(".:sync_position"))
	config.add_property(NodePath(".:sync_facing"))
	config.property_set_replication_mode(NodePath(".:sync_facing"),
			SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	ms.replication_config = config
	add_child(ms)


# ── Trigger ────────────────────────────────────────────────────────────────────

func _on_trigger_entered(body: Node) -> void:
	if body.is_in_group("players") and body.get_multiplayer_authority() == multiplayer.get_unique_id():
		interact_label.show()


func _on_trigger_exited(body: Node) -> void:
	if body.is_in_group("players") and body.get_multiplayer_authority() == multiplayer.get_unique_id():
		interact_label.hide()


# ── Interaction (server-side) ──────────────────────────────────────────────────

## Called on server by Player.rpc_request_interact
func handle_player_interact(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	var disposition := FactionManager.get_disposition(faction_id, peer_id)

	if disposition == "hostile":
		rpc_bark.rpc_id(peer_id, "Get out of here.")
		return

	var key := _dialogue.get_dialogue_key(dialogue_key_prefix, disposition)
	var rep := FactionManager.get_reputation(faction_id, peer_id)
	rpc_open_dialogue.rpc_id(peer_id, key, rep)


@rpc("authority", "call_remote", "reliable")
func rpc_open_dialogue(dialogue_key: String, rep: float) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_dialogue"):
		var lines   := _dialogue.get_lines(dialogue_key)
		var choices := _dialogue.get_choices(dialogue_key, rep)
		var speaker := _dialogue.get_speaker(dialogue_key)
		if lines.is_empty():
			lines = ["..."]
		hud.show_dialogue(speaker, lines, choices, get_instance_id())


@rpc("authority", "call_remote", "reliable")
func rpc_open_trade(peer_id: int) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_trade"):
		hud.show_trade(get_instance_id(), peer_id, trade_inventory)


@rpc("authority", "call_remote", "reliable")
func rpc_bark(text: String) -> void:
	interact_label.text = text
	interact_label.show()
	await get_tree().create_timer(2.0).timeout
	interact_label.hide()
	interact_label.text = "[F] Talk"


## Called from client when player picks "open_trade" choice
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_trade(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var disposition := FactionManager.get_disposition(faction_id, peer_id)
	if disposition == "hostile":
		return
	rpc_open_trade.rpc_id(peer_id, peer_id)


## Called from NPCTradeMenu when the player selects an item to buy.
@rpc("any_peer", "call_remote", "reliable")
func rpc_execute_trade(item_name: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()

	for entry: Dictionary in trade_inventory:
		if entry.get("name", "") != item_name:
			continue
		var item := _item_data_for_name(item_name)
		if item == null:
			return
		var player := GameManager.get_player_node(peer_id)
		if player:
			if peer_id == multiplayer.get_unique_id():
				player.rpc_receive_item.call(item.item_name, item.item_type, item.stat_effects)
			else:
				player.rpc_id(peer_id, "rpc_receive_item", item.item_name, item.item_type, item.stat_effects)
		complete_trade(peer_id)
		return


## Called on server when trade completes — applies reputation gain.
func complete_trade(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	FactionManager.apply_reputation_event(faction_id, peer_id, "traded")
	EventBus.trade_completed.emit(peer_id, faction_id)


# ── Item lookup (matches trade_inventory names to ItemData) ───────────────────
# Replace when a proper item registry exists.

static func _item_data_for_name(item_name: String) -> ItemData:
	match item_name:
		"Canned Food":   return ItemData.make("Canned Food",   ItemData.Type.FOOD,    {"hunger":  35.0})
		"Protein Bar":   return ItemData.make("Protein Bar",   ItemData.Type.FOOD,    {"hunger":  20.0})
		"Wild Berries":  return ItemData.make("Wild Berries",  ItemData.Type.FOOD,    {"hunger":  12.0})
		"Water Bottle":  return ItemData.make("Water Bottle",  ItemData.Type.WATER,   {"thirst":  40.0})
		"Soda":          return ItemData.make("Soda",          ItemData.Type.WATER,   {"thirst":  25.0})
		"Muddy Water":   return ItemData.make("Muddy Water",   ItemData.Type.WATER,   {"thirst":  18.0, "health": -5.0})
		"Bandage":       return ItemData.make("Bandage",       ItemData.Type.BANDAGE, {"health":  15.0, "bleed": -1.0})
		"First Aid Kit": return ItemData.make("First Aid Kit", ItemData.Type.BANDAGE, {"health":  40.0, "bleed": -2.0})
		"Painkillers":   return ItemData.make("Painkillers",   ItemData.Type.MISC,    {"health":  10.0})
		"Antibiotics":   return ItemData.make("Antibiotics",   ItemData.Type.MISC,    {"health":  20.0, "infection": -1.0})
		"Suture Kit":    return ItemData.make("Suture Kit",    ItemData.Type.BANDAGE, {"health":   5.0, "deep_wound": -1})
		"Splint":        return ItemData.make("Splint",        ItemData.Type.MISC,    {"fracture": -1})
		"Energy Drink":  return ItemData.make("Energy Drink",  ItemData.Type.MISC,    {"fatigue":  30.0, "thirst": -5.0})
		"Coffee":        return ItemData.make("Coffee",        ItemData.Type.MISC,    {"fatigue":  20.0})
		"Metal Pipe":    return ItemData.make("Metal Pipe",    ItemData.Type.WEAPON,  {"melee_bonus": 25.0})
		"Kitchen Knife": return ItemData.make("Kitchen Knife", ItemData.Type.WEAPON,  {"melee_bonus": 20.0})
		"Crowbar":       return ItemData.make("Crowbar",       ItemData.Type.WEAPON,  {"melee_bonus": 35.0})
		"Pistol":        return ItemData.make("Pistol",        ItemData.Type.WEAPON,  {"projectile_damage": 45.0, "fire_range": 550.0})
		"Rifle":         return ItemData.make("Rifle",         ItemData.Type.WEAPON,  {"projectile_damage": 75.0, "fire_range": 800.0})
		"Pistol Mag":    return ItemData.make("Pistol Mag",    ItemData.Type.MISC,    {"ammo_count": 15})
		"Rifle Clip":    return ItemData.make("Rifle Clip",    ItemData.Type.MISC,    {"ammo_count": 8})
	return null


## Show or hide this NPC's visual for client-side room occlusion.
func set_occlusion_visible(v: bool) -> void:
	if _npc_visual:
		_npc_visual.visible = v


# ── Stick-man + top-hat visual ─────────────────────────────────────────────────
# All coordinates relative to CharacterBody2D origin (capsule centre ≈ mid-torso).

func _build_visual() -> void:
	var root    := Node2D.new()
	root.z_index = 1
	_npc_visual  = root
	add_child(root)

	# Hat crown (drawn first so brim renders on top)
	root.add_child(_rect_poly(Vector2(-4, -37), Vector2(4, -23), Color(0.08, 0.06, 0.06)))
	# Hat brim
	root.add_child(_rect_poly(Vector2(-8, -25), Vector2(8, -22), Color(0.08, 0.06, 0.06)))

	# Head — stored so position can shift per direction
	var head := _circle_poly(Vector2(0, -17), 6.0, 10, Color(1.0, 0.82, 0.68))
	head.name = "Head"
	_npc_head  = head
	root.add_child(head)

	# Torso (always vertical, no pose change needed)
	root.add_child(_line2d([Vector2(0, -11), Vector2(0, 3)], Color(0.30, 0.55, 0.35), 2.5))

	# Arms — stored for pose swap
	var al := _line2d([Vector2(-1, -9), Vector2(-10, -1)], Color(0.30, 0.55, 0.35), 2.0)
	al.name   = "ArmL"; _npc_arm_l = al; root.add_child(al)
	var ar := _line2d([Vector2( 1, -9), Vector2( 10, -1)], Color(0.30, 0.55, 0.35), 2.0)
	ar.name   = "ArmR"; _npc_arm_r = ar; root.add_child(ar)

	# Legs — stored for pose swap
	var ll := _line2d([Vector2(-2,  3), Vector2(-6, 13)], Color(0.20, 0.20, 0.28), 2.0)
	ll.name   = "LegL"; _npc_leg_l = ll; root.add_child(ll)
	var lr := _line2d([Vector2( 2,  3), Vector2( 6, 13)], Color(0.20, 0.20, 0.28), 2.0)
	lr.name   = "LegR"; _npc_leg_r = lr; root.add_child(lr)


func _circle_poly(center: Vector2, radius: float, segs: int, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	var pts  := PackedVector2Array()
	for i in segs:
		var a := TAU * i / segs
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	poly.polygon = pts
	poly.color   = color
	return poly


func _rect_poly(tl: Vector2, br: Vector2, color: Color) -> Polygon2D:
	var poly    := Polygon2D.new()
	poly.polygon = PackedVector2Array([tl, Vector2(br.x, tl.y), br, Vector2(tl.x, br.y)])
	poly.color   = color
	return poly


func _line2d(pts: Array, color: Color, width: float) -> Line2D:
	var line           := Line2D.new()
	line.default_color  = color
	line.width          = width
	for p: Vector2 in pts:
		line.add_point(p)
	return line
