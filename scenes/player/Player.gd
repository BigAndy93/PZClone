class_name Player
extends CharacterBody2D

# ── Tuning ────────────────────────────────────────────────────────────────────
@export var walk_speed:          float = 120.0
@export var sprint_speed:        float = 220.0
@export var sprint_fatigue_cost: float = 0.5   # per second
@export var base_melee_damage:   float = 25.0
@export var melee_range:         float = 50.0
## Assign SpriteSheet resources (one per CharacterSpriteController.Layer enum value)
## to replace the procedural visual with sprite-based rendering.
## Leave empty to keep the procedural fallback.
@export var sprite_sheets: Array[SpriteSheet] = []

# ── State ─────────────────────────────────────────────────────────────────────
var facing_direction: Vector2       = Vector2.DOWN
var is_sprinting:     bool          = false
var stats:            SurvivalStats = null
var inventory:        Inventory     = null
var melee_damage:     float         = 0.0   # = base + weapon bonus
var equipped_weapon:   ItemData      = null
var equipped_clothing: ItemData      = null   # torso slot (jacket, vest, etc.)
var equipped_back:     ItemData      = null   # back bag slot
var equipped_hand:     ItemData      = null   # hand bag slot
var selected_slot:     int           = 0
var _ranged_cooldown:     float = 0.0
var _ammo_loaded:         int   = 0    # rounds currently chambered
var _stamina_regen_pause: float = 0.0  # delay before stamina starts recovering
var is_resting:           bool  = false  # H-key rest mode (server-synced)
var is_sneaking:          bool  = false  # Z-key sneak mode
var is_aiming:            bool  = false  # RMB held — required to attack

# ── Procedural visual state ────────────────────────────────────────────────────
var _player_visual:  Node2D    = null   # root procedural body node
var _weapon_arm:     Node2D    = null   # rotates around right shoulder
var _weapon_icon:    Node2D    = null   # rebuilt when weapon changes
var _facing_dot:     Polygon2D = null   # orbits head perimeter
var _body_poly:      Polygon2D = null   # torso — color tracks equipped clothing
var _head_node:      Polygon2D = null   # head circle — shifts per direction
var _hat_poly:       Polygon2D = null   # hair/hat cap — recolored by clothing
var _clothing_layer: Node2D    = null   # clothing shapes, rebuilt on equip change
var _leg_l:          Line2D    = null   # left leg, animated
var _leg_r:          Line2D    = null   # right leg, animated
var _arm_l:          Line2D    = null   # passive left arm, animated
var _walk_phase:       float                    = 0.0   # walk cycle phase (drives limb bob)
var _team_color:       Color                    = Color.WHITE
var _last_vis:         int                      = -1   # cached equipped visual state to detect changes
var _last_dir8:        int                      = -1   # last 8-direction index (avoids redundant pose rebuilds)
var _sprite_controller: CharacterSpriteController = null  # non-null when sprite_sheets is populated

# ── 8-direction pose data ─────────────────────────────────────────────────────
# Canonical poses: 0=E, 1=SE, 2=S, 3=N, 4=NE.
# Mirrored directions (W/SW/NW) use scale.x = -1 on the matching canonical pose.
# Per-pose layout: [leg_l[p0,p1], leg_r[p0,p1], arm_l[p0,p1],
#                   body[4 pts], head_x_off (float), shoulder_r (Vector2)]
static var _PLAYER_POSES: Array = [
	# 0 = E  — right side profile; body narrow, arm_l pulled back, leg_r steps forward
	[[Vector2(-1.0, 2.0), Vector2(-2.0,13.0)],
	 [Vector2( 1.0, 2.0), Vector2( 3.5,13.0)],
	 [Vector2(-2.0,-9.0), Vector2(-5.5,-3.0)],
	 [Vector2(-2.5,-11.0),Vector2(2.5,-11.0),Vector2(2.5,3.0),Vector2(-2.5,3.0)],
	 1.5, Vector2(2.5,-9.0)],
	# 1 = SE — front-right 3/4; medium body width
	[[Vector2(-2.0, 2.0), Vector2(-3.5,13.0)],
	 [Vector2( 2.5, 2.0), Vector2( 4.5,13.0)],
	 [Vector2(-4.0,-9.0), Vector2(-12.0,-2.5)],
	 [Vector2(-4.0,-11.0),Vector2(5.5,-11.0),Vector2(6.0,3.0),Vector2(-3.5,3.0)],
	 0.5, Vector2(4.5,-9.0)],
	# 2 = S  — front view; widest body, both arms fully extended
	[[Vector2(-2.5, 2.0), Vector2(-4.5,13.0)],
	 [Vector2( 2.5, 2.0), Vector2( 4.5,13.0)],
	 [Vector2(-4.5,-9.0), Vector2(-13.5,-2.0)],
	 [Vector2(-4.5,-11.0),Vector2(6.0,-11.0),Vector2(6.0,3.0),Vector2(-4.0,3.0)],
	 0.0, Vector2(4.5,-9.0)],
	# 3 = N  — back view; medium body, arms tucked higher
	[[Vector2(-2.0, 2.0), Vector2(-3.0,13.0)],
	 [Vector2( 2.0, 2.0), Vector2( 3.0,13.0)],
	 [Vector2(-4.0,-9.0), Vector2(-11.0,-4.0)],
	 [Vector2(-4.0,-11.0),Vector2(5.0,-11.0),Vector2(5.0,3.0),Vector2(-3.5,3.0)],
	 0.0, Vector2(4.0,-9.0)],
	# 4 = NE — back-right 3/4; medium-slim body
	[[Vector2(-1.5, 2.0), Vector2(-2.5,13.0)],
	 [Vector2( 2.0, 2.0), Vector2( 4.0,13.0)],
	 [Vector2(-3.5,-9.0), Vector2(-10.0,-3.5)],
	 [Vector2(-3.0,-11.0),Vector2(5.0,-11.0),Vector2(5.5,3.0),Vector2(-2.5,3.0)],
	 0.5, Vector2(4.0,-9.0)],
]
# dir8 index → [canonical_pose_idx, flip_x].
# dir8: 0=E, 1=SE, 2=S, 3=SW, 4=W, 5=NW, 6=N, 7=NE
static var _DIR8_MAP: Array = [
	[0, false], [1, false], [2, false], [1, true],
	[0, true],  [4, true],  [3, false], [4, false],
]

## Convert a facing vector to a dir8 index (0=E clockwise to 7=NE).
static func _facing_to_dir8(v: Vector2) -> int:
	return int(fposmod(v.angle(), TAU) / (TAU / 8.0) + 0.5) % 8

## Rebuild leg/arm/body/head geometry for the given dir8 without touching scale.
func _apply_player_pose(dir8: int) -> void:
	var entry: Array = _DIR8_MAP[dir8]
	var pose:  Array = _PLAYER_POSES[entry[0]]
	if _leg_l:
		_leg_l.set_point_position(0, pose[0][0])
		_leg_l.set_point_position(1, pose[0][1])
	if _leg_r:
		_leg_r.set_point_position(0, pose[1][0])
		_leg_r.set_point_position(1, pose[1][1])
	if _arm_l:
		_arm_l.set_point_position(0, pose[2][0])
		_arm_l.set_point_position(1, pose[2][1])
	if _body_poly:
		_body_poly.polygon = PackedVector2Array(pose[3])
		_body_poly.scale   = Vector2.ONE
	if _head_node:
		_head_node.position = Vector2(float(pose[4]), 0.0)
	if _weapon_arm:
		_weapon_arm.position = pose[5] as Vector2

const RANGED_FIRE_RATE:    float = 0.75
const STAMINA_MELEE_COST:  float = 20.0
const STAMINA_MIN_ATTACK:  float = 10.0
const STAMINA_REGEN_RATE:  float = 22.0
const STAMINA_REGEN_DELAY: float = 1.5
const REVIVE_RANGE:        float = 90.0   # max distance to revive a downed teammate

# ── Drag / carry ──────────────────────────────────────────────────────────────
const DRAG_SPEED:   float   = 55.0           # carrier walk speed while dragging
const DRAG_RANGE:   float   = 80.0           # max range to initiate drag
const DRAG_OFFSET:  Vector2 = Vector2(0.0, 28.0)  # downed player offset behind carrier

# Synced — set by server via RPC so all clients know drag state.
var sync_drag_target_id:  int = 0  # carrier: peer_id of who we're dragging (0 = none)
var sync_drag_carrier_id: int = 0  # downed: peer_id of who's dragging us (0 = none)

# Server-only: mirrors of the above for validation / cleanup.
var _drag_target_peer:  int = 0
var _being_dragged_by:  int = 0

signal slot_changed(idx: int)

# ── Sync ──────────────────────────────────────────────────────────────────────
var sync_position:   Vector2 = Vector2.ZERO
var sync_facing:     Vector2 = Vector2.DOWN
var sync_velocity:   Vector2 = Vector2.ZERO
var sync_health:     float   = 100.0
var sync_is_downed:       bool    = false
var sync_equipped_visual: int     = 0    # clothing tier (bits 0-2) + weapon flags (bits 3-4)
var sync_sneak:           bool    = false

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var sprite:           AnimatedSprite2D = $AnimatedSprite2D
@onready var stat_tick_system: StatTickSystem   = $StatTickSystem
@onready var camera:           Camera2D         = $PlayerCamera
@onready var interact_area:    Area2D           = $InteractArea


func _ready() -> void:
	add_to_group("players")
	stats        = SurvivalStats.new()
	inventory    = Inventory.new()
	melee_damage = base_melee_damage
	_build_player_visual()
	_setup_multiplayer_sync()

	interact_area.collision_mask = 4 | 16

	var my_id     := multiplayer.get_unique_id()
	var authority := get_multiplayer_authority()

	camera.enabled = (authority == my_id)
	if multiplayer.is_server():
		stat_tick_system.setup(authority, stats)
	elif authority != my_id:
		$StatTickSystem.queue_free()

	if authority == my_id:
		stats.stat_critical.connect(_on_stat_critical)

	EventBus.player_spawned.emit(authority, self)


# ── Input ─────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: Key = (event as InputEventKey).physical_keycode
		if kc >= KEY_1 and kc <= KEY_8:
			_change_slot(kc - KEY_1)
		elif kc == KEY_Q:
			_try_drop_selected()
		elif kc == KEY_C:
			_toggle_crafting_menu()
		elif kc == KEY_TAB:
			_toggle_inventory_window()
		elif kc == KEY_G:
			_toggle_drag()
		elif kc == KEY_H:
			_toggle_rest()
		elif kc == KEY_Z:
			_toggle_sneak()


# ── Per-frame ─────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	# ── Remote player: interpolate toward authoritative position ──
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		if sync_drag_carrier_id != 0:
			# Being dragged — snap position to carrier's location.
			var carrier := GameManager.get_player_node(sync_drag_carrier_id)
			if carrier and is_instance_valid(carrier):
				global_position = carrier.global_position + DRAG_OFFSET
		else:
			global_position = global_position.lerp(sync_position, delta * 15.0)
		_update_animation(delta)
		return

	# ── Local player: downed state ──
	if stats and stats.is_downed:
		if sync_drag_carrier_id != 0:
			var carrier := GameManager.get_player_node(sync_drag_carrier_id)
			if carrier and is_instance_valid(carrier):
				global_position = carrier.global_position + DRAG_OFFSET
		velocity = Vector2.ZERO
		_update_animation()
		_update_sync_data()
		return

	# ── Local player: normal ──
	_ranged_cooldown = maxf(_ranged_cooldown - delta, 0.0)
	_handle_movement(delta)
	_handle_aim()
	_check_interact_input()
	_check_attack_input()
	_check_use_item_input()
	_update_stamina(delta)
	_update_animation(delta)
	_update_sync_data()


# ── Movement ──────────────────────────────────────────────────────────────────
func _handle_movement(delta: float) -> void:
	var raw      := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Any movement cancels rest mode.
	if is_resting and raw != Vector2.ZERO:
		_set_resting(false)

	# While resting: no movement.
	if is_resting:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var fractured := stats != null and stats.fracture
	var exhausted := stats != null and stats.fatigue < 20.0
	is_sprinting  = Input.is_action_pressed("sprint") and raw != Vector2.ZERO

	# Fracture: no sprint, half walk speed.
	if fractured:
		is_sprinting = false

	# Exhaustion: no sprint.
	if exhausted:
		is_sprinting = false

	# Drag: overrides to slow crawl, no sprint.
	var dragging := sync_drag_target_id != 0
	if dragging:
		is_sprinting = false

	# Sneak: no sprint; cancel sneak on sprint attempt.
	if is_sneaking and is_sprinting:
		is_sneaking = false

	var base_speed: float
	if dragging:
		base_speed = DRAG_SPEED
	elif is_sprinting:
		base_speed = sprint_speed
	elif is_sneaking:
		base_speed = walk_speed * 0.55   # sneak is slower than normal walk
	else:
		base_speed = walk_speed

	# Apply movement penalties (stack multiplicatively).
	var speed := base_speed
	if fractured:
		speed *= 0.50
	if exhausted:
		speed *= 0.80
	velocity   = raw.rotated(-PI / 4.0) * speed

	if velocity != Vector2.ZERO:
		facing_direction = velocity.normalized()
		# Sneak cancels on movement if we somehow got here while resting.
		if is_resting: _set_resting(false)
		var noise_r: float
		if dragging:
			noise_r = SoundBus.RADIUS_RUN * 1.6   # dragging is loud
		elif is_sprinting:
			noise_r = SoundBus.RADIUS_RUN
		elif is_sneaking:
			noise_r = SoundBus.RADIUS_WALK * 0.30  # very quiet
		else:
			noise_r = SoundBus.RADIUS_WALK
		SoundBus.emit_noise(global_position, noise_r, "player_move")
		SoundBus.play_footstep(global_position)
		if multiplayer.is_server() and is_sprinting and stats:
			stats.fatigue = maxf(stats.fatigue - sprint_fatigue_cost * delta, 0.0)

	move_and_slide()


# ── Interact / pickup / revive ─────────────────────────────────────────────────
func _check_interact_input() -> void:
	if not Input.is_action_just_pressed("interact"):
		return

	# Priority 1: revive a downed teammate.
	for player_node in get_tree().get_nodes_in_group("players"):
		if player_node == self:
			continue
		if not player_node.get("sync_is_downed"):
			continue
		var d := global_position.distance_to(player_node.global_position)
		if d <= REVIVE_RANGE:
			rpc_request_revive.rpc_id(1, player_node.get_multiplayer_authority())
			return

	# Priority 2: containers (search furniture).
	for area in interact_area.get_overlapping_areas():
		if area.is_in_group("containers") and area is WorldContainer:
			_open_container(area as WorldContainer)
			return

	# Priority 3: loot items (Area2D overlaps).
	for area in interact_area.get_overlapping_areas():
		if area.is_in_group("loot_items") and area is LootItem:
			_try_pickup(area as LootItem)
			return

	# Priority 4: windows.
	for area in interact_area.get_overlapping_areas():
		if area.is_in_group("windows"):
			_try_interact_window(area)
			return

	# Priority 5: doors.
	for area in interact_area.get_overlapping_areas():
		if area.is_in_group("doors"):
			_try_interact_door(area)
			return

	# Priority 5: NPCs (body overlaps).
	for body in interact_area.get_overlapping_bodies():
		if body.is_in_group("npcs"):
			rpc_request_interact.rpc_id(1, body.get_path())
			return


func _try_pickup(item: LootItem) -> void:
	if item.item_data == null:
		return
	var world := get_tree().get_first_node_in_group("world_node")
	if world == null:
		return
	# Server validates, gives item, and removes from world for all peers.
	# Never mutate inventory locally — wait for server confirmation via rpc_receive_item.
	if multiplayer.is_server():
		world._server_do_loot_pickup(item.get_path(), get_multiplayer_authority())
	else:
		world.rpc_id(1, "rpc_request_loot_pickup", item.get_path())


func _try_interact_window(win_area: Area2D) -> void:
	var world := get_tree().get_first_node_in_group("world_node")
	if world == null:
		return
	var win_path := win_area.get_path()
	if multiplayer.is_server():
		world._server_toggle_window(win_path)
	else:
		world.rpc_id(1, "rpc_request_toggle_window", win_path)


func _try_interact_door(door_area: Area2D) -> void:
	var world := get_tree().get_first_node_in_group("world_node")
	if world == null:
		return
	var door_path := door_area.get_path()
	if multiplayer.is_server():
		world._server_toggle_door(door_path)
	else:
		world.rpc_id(1, "rpc_request_toggle_door", door_path)


## Client → server: request reviving a downed teammate.
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_revive(target_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var target := GameManager.get_player_node(target_peer_id)
	if target == null or not is_instance_valid(target):
		return
	if sync_position.distance_to(target.sync_position) > REVIVE_RANGE * 1.5:
		return
	var ts: StatTickSystem = target.get_node_or_null("StatTickSystem")
	if ts == null or not ts.is_downed:
		return
	ts.revive()
	# Clear any drag state targeting this player.
	target.server_clear_drag_state()
	var world := get_tree().get_first_node_in_group("world_node")
	if world and world.has_method("rpc_notify_player_revived"):
		world.rpc_notify_player_revived.rpc(target_peer_id)


@rpc("any_peer", "call_remote", "reliable")
func rpc_request_interact(npc_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var npc: Node = get_node_or_null(npc_path)
	if npc and npc.has_method("handle_player_interact"):
		npc.handle_player_interact(get_multiplayer_authority())


# ── Drag / carry ──────────────────────────────────────────────────────────────

func _toggle_drag() -> void:
	if sync_drag_target_id != 0:
		# Already dragging — stop.
		rpc_request_stop_drag.rpc_id(1)
	else:
		# Find nearest downed teammate within range.
		for player_node in get_tree().get_nodes_in_group("players"):
			if player_node == self:
				continue
			if not player_node.get("sync_is_downed"):
				continue
			var d := global_position.distance_to(player_node.global_position)
			if d <= DRAG_RANGE:
				rpc_request_start_drag.rpc_id(1, player_node.get_multiplayer_authority())
				return


## Client → server: start dragging a downed teammate.
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_start_drag(target_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var target := GameManager.get_player_node(target_peer_id)
	if target == null or not is_instance_valid(target):
		return
	# Validate: target must be downed and not already being dragged.
	if not target.sync_is_downed or target._being_dragged_by != 0:
		return
	# Validate distance on server.
	if sync_position.distance_to(target.sync_position) > DRAG_RANGE * 1.5:
		return

	_drag_target_peer      = target_peer_id
	target._being_dragged_by = get_multiplayer_authority()

	# Notify carrier client.
	var carrier_id := multiplayer.get_remote_sender_id()
	rpc_notify_drag_state.rpc_id(carrier_id, target_peer_id)

	# Notify downed player's client.
	target.rpc_notify_drag_carrier.rpc_id(target_peer_id, carrier_id)

	EventBus.item_used.emit(carrier_id, "Dragging teammate!")


## Client → server: stop dragging.
@rpc("any_peer", "call_remote", "reliable")
func rpc_request_stop_drag() -> void:
	if not multiplayer.is_server():
		return
	var old_target_id := _drag_target_peer
	_drag_target_peer = 0

	var carrier_id := multiplayer.get_remote_sender_id()
	rpc_notify_drag_state.rpc_id(carrier_id, 0)

	if old_target_id != 0:
		var target := GameManager.get_player_node(old_target_id)
		if target and is_instance_valid(target):
			target._being_dragged_by = 0
			target.rpc_notify_drag_carrier.rpc_id(old_target_id, 0)


## Server → carrier client: update who we're dragging.
@rpc("any_peer", "call_remote", "reliable")
func rpc_notify_drag_state(target_peer_id: int) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	sync_drag_target_id = target_peer_id


## Server → downed player client: update who's dragging us.
@rpc("any_peer", "call_remote", "reliable")
func rpc_notify_drag_carrier(carrier_peer_id: int) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	sync_drag_carrier_id = carrier_peer_id


## Z key: toggle sneak mode. Client-local; affects speed and noise emission.
func _toggle_sneak() -> void:
	is_sneaking = not is_sneaking
	if is_sneaking and is_resting:
		_set_resting(false)   # rest cancels on sneak toggle
	var msg := "Sneaking... [Z] to stand" if is_sneaking else "Standing up"
	EventBus.item_used.emit(get_multiplayer_authority(), msg)


## H key: toggle rest mode. Server authoritative — fatigue is synced.
func _toggle_rest() -> void:
	_set_resting(not is_resting)


func _set_resting(value: bool) -> void:
	is_resting = value
	rpc_request_set_resting.rpc_id(1, value)
	var msg := "Resting... [H] to stop" if value else "Stopped resting"
	EventBus.item_used.emit(get_multiplayer_authority(), msg)


@rpc("any_peer", "call_remote", "reliable")
func rpc_request_set_resting(resting: bool) -> void:
	if not multiplayer.is_server():
		return
	var ts: StatTickSystem = get_node_or_null("StatTickSystem")
	if ts:
		ts.is_resting = resting


## Server → client: a zombie came too close and interrupted rest.
@rpc("any_peer", "call_remote", "reliable")
func rpc_interrupt_rest() -> void:
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	if not is_resting:
		return
	is_resting = false
	EventBus.item_used.emit(get_multiplayer_authority(), "Something woke you up!")


## Called by StatTickSystem or rpc_request_revive on server to clean up drag.
func server_clear_drag_state() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := get_multiplayer_authority()

	# If we're the downed player: notify carrier to stop.
	if _being_dragged_by != 0:
		var carrier := GameManager.get_player_node(_being_dragged_by)
		if carrier and is_instance_valid(carrier):
			carrier._drag_target_peer = 0
			carrier.rpc_notify_drag_state.rpc_id(_being_dragged_by, 0)
		_being_dragged_by = 0
	rpc_notify_drag_carrier.rpc_id(peer_id, 0)

	# If we're the carrier: notify the downed player.
	if _drag_target_peer != 0:
		var target := GameManager.get_player_node(_drag_target_peer)
		if target and is_instance_valid(target):
			target._being_dragged_by = 0
			target.rpc_notify_drag_carrier.rpc_id(_drag_target_peer, 0)
		_drag_target_peer = 0
	rpc_notify_drag_state.rpc_id(peer_id, 0)


# ── Aim (RMB held) ────────────────────────────────────────────────────────────
func _handle_aim() -> void:
	is_aiming = Input.is_action_pressed("aim")
	if is_aiming:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length_squared() > 1.0:
			facing_direction = to_mouse.normalized()


# ── Attack (E / LMB — requires aim) ──────────────────────────────────────────
func _check_attack_input() -> void:
	if not is_aiming:
		return
	if Input.is_action_just_pressed("attack"):
		if equipped_weapon != null and equipped_weapon.stat_effects.has("projectile_damage"):
			_perform_ranged_attack()
		else:
			_perform_melee_attack()


# ── Stamina (includes pain cap from injuries) ─────────────────────────────────
func _update_stamina(delta: float) -> void:
	if stats == null:
		return
	if _stamina_regen_pause > 0.0:
		_stamina_regen_pause -= delta
	elif stats.stamina < _pain_stamina_cap():
		# Exhaustion halves stamina regen rate.
		var regen := STAMINA_REGEN_RATE * (0.5 if stats.fatigue < 20.0 else 1.0)
		stats.stamina = minf(stats.stamina + regen * delta, _pain_stamina_cap())


## Injuries impose a pain penalty that reduces the effective stamina ceiling.
## Bleed: 8/stack, deep wound: 12/wound, fracture: 15. Floor at 20.
func _pain_stamina_cap() -> float:
	if stats == null:
		return 100.0
	var pain: float = stats.bleed_stacks * 8.0 + stats.deep_wound * 12.0
	if stats.fracture:
		pain += 15.0
	return maxf(100.0 - pain, 20.0)


func _perform_melee_attack() -> void:
	if stats and stats.stamina < STAMINA_MIN_ATTACK:
		EventBus.item_used.emit(get_multiplayer_authority(), "Too tired!")
		return
	if stats:
		stats.stamina        = maxf(stats.stamina - STAMINA_MELEE_COST, 0.0)
		_stamina_regen_pause = STAMINA_REGEN_DELAY
	SoundBus.play_sound_at("melee_swing", global_position)
	var closest:  Node2D = null
	var min_dist: float  = melee_range

	for zombie in get_tree().get_nodes_in_group("zombies"):
		if not is_instance_valid(zombie):
			continue
		var d := global_position.distance_to(zombie.global_position)
		if d < min_dist:
			min_dist = d
			closest  = zombie

	if closest:
		if multiplayer.is_server():
			rpc_melee_attack(closest.get_path(), melee_damage)
		else:
			rpc_melee_attack.rpc_id(1, closest.get_path(), melee_damage)


@rpc("any_peer", "call_remote", "reliable")
func rpc_melee_attack(zombie_path: NodePath, damage: float) -> void:
	if not multiplayer.is_server():
		return
	var zombie := get_node_or_null(zombie_path)
	if zombie and zombie.has_method("take_damage"):
		var kb_dir: Vector2 = ((zombie as Node2D).global_position - sync_position).normalized()
		zombie.take_damage(damage, get_multiplayer_authority(), kb_dir)


# ── Ranged attack ─────────────────────────────────────────────────────────────
func _perform_ranged_attack() -> void:
	if _ranged_cooldown > 0.0:
		return
	if _ammo_loaded <= 0:
		if not _try_reload():
			EventBus.item_used.emit(get_multiplayer_authority(), "No ammo!")
			return
	_ammo_loaded -= 1
	_ranged_cooldown = RANGED_FIRE_RATE
	EventBus.item_used.emit(get_multiplayer_authority(), "Ammo: %d" % _ammo_loaded)
	var proj_dmg:   float = equipped_weapon.stat_effects.get("projectile_damage", 0.0)
	var fire_range: float = equipped_weapon.stat_effects.get("fire_range", 550.0)
	SoundBus.play_sound_at("gunshot", global_position, 4.0)
	SoundBus.emit_noise(global_position, SoundBus.RADIUS_GUNSHOT, "gunshot")
	if multiplayer.is_server():
		rpc_request_ranged_attack(facing_direction, proj_dmg, fire_range)
	else:
		rpc_request_ranged_attack.rpc_id(1, facing_direction, proj_dmg, fire_range)


func _try_reload() -> bool:
	for i in inventory.items.size():
		var item: ItemData = inventory.items[i]
		if item.stat_effects.has("ammo_count"):
			_ammo_loaded = int(item.stat_effects.get("ammo_count", 0))
			inventory.items.remove_at(i)
			inventory.inventory_changed.emit()
			EventBus.item_used.emit(get_multiplayer_authority(),
					"Reloaded! (%d)" % _ammo_loaded)
			return true
	return false


@rpc("any_peer", "call_remote", "reliable")
func rpc_request_ranged_attack(direction: Vector2, proj_dmg: float, fire_range: float) -> void:
	if not multiplayer.is_server():
		return
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
			sync_position,
			sync_position + direction.normalized() * fire_range,
			2 | 8)  # layer 2 = Zombies, layer 8 = World/Walls
	query.exclude = [self]
	var hit := space.intersect_ray(query)
	# Only deal damage if the first thing hit is a zombie — walls stop the bullet.
	if hit and hit["collider"].has_method("take_damage"):
		hit["collider"].take_damage(proj_dmg, get_multiplayer_authority())


# ── Item use / equip (R) ──────────────────────────────────────────────────────
func _check_use_item_input() -> void:
	if Input.is_action_just_pressed("use_item"):
		_use_selected_slot()


func _use_selected_slot() -> void:
	if selected_slot >= inventory.items.size():
		return
	var item: ItemData = inventory.items[selected_slot]
	if item.item_type == ItemData.Type.WEAPON:
		_toggle_equip_weapon(item)
	elif item.item_type == ItemData.Type.CLOTHING:
		_toggle_equip_clothing(item)
	else:
		_use_item_at_slot(selected_slot)


func _toggle_equip_weapon(item: ItemData) -> void:
	if equipped_weapon == item:
		equipped_weapon = null
		melee_damage    = base_melee_damage
		EventBus.item_used.emit(get_multiplayer_authority(), "Unequipped " + item.item_name)
	else:
		equipped_weapon = item
		melee_damage    = base_melee_damage + item.stat_effects.get("melee_bonus", 0.0)
		EventBus.item_used.emit(get_multiplayer_authority(), "Equipped " + item.item_name)
	slot_changed.emit(selected_slot)


func _toggle_equip_clothing(item: ItemData) -> void:
	var equip_slot := item.stat_effects.get("equip_slot", "torso") as String
	match equip_slot:
		"back":
			if equipped_back == item:
				equipped_back = null
				EventBus.item_used.emit(get_multiplayer_authority(), "Removed " + item.item_name)
			else:
				equipped_back = item
				EventBus.item_used.emit(get_multiplayer_authority(), "Equipped " + item.item_name + " on back")
		"hand":
			if equipped_hand == item:
				equipped_hand = null
				EventBus.item_used.emit(get_multiplayer_authority(), "Removed " + item.item_name)
			else:
				equipped_hand = item
				EventBus.item_used.emit(get_multiplayer_authority(), "Holding " + item.item_name)
		_:  # torso
			if equipped_clothing == item:
				equipped_clothing = null
				EventBus.item_used.emit(get_multiplayer_authority(), "Removed " + item.item_name)
			else:
				equipped_clothing = item
				EventBus.item_used.emit(get_multiplayer_authority(), "Wearing " + item.item_name)
	_update_inventory_grids()
	slot_changed.emit(selected_slot)


## Type-aware item activation by flat-inventory index.
## Routes weapons and clothing to equip/toggle; consumables to use.
## Called by InventoryWindow right-click menu so it works for all item types.
func activate_item(idx: int) -> void:
	if idx < 0 or idx >= inventory.items.size():
		return
	var item: ItemData = inventory.items[idx]
	if item.item_type == ItemData.Type.WEAPON:
		_toggle_equip_weapon(item)
	elif item.item_type == ItemData.Type.CLOTHING:
		_toggle_equip_clothing(item)
	else:
		_use_item_at_slot(idx)


func _use_item_at_slot(idx: int) -> void:
	var item: ItemData = inventory.items[idx] if idx < inventory.items.size() else null
	if item and equipped_weapon == item:
		equipped_weapon = null
		melee_damage    = base_melee_damage
	if item and equipped_clothing == item:
		equipped_clothing = null
	if item and equipped_back == item:
		equipped_back = null
	if item and equipped_hand == item:
		equipped_hand = null

	var msg := inventory.use_item(idx, stats)
	if not msg.is_empty():
		EventBus.item_used.emit(get_multiplayer_authority(), msg)
		SoundBus.play_sound_at("item_use", global_position)

	selected_slot = mini(selected_slot, maxi(0, inventory.items.size() - 1))
	slot_changed.emit(selected_slot)


func _change_slot(idx: int) -> void:
	selected_slot = clampi(idx, 0, Inventory.MAX_SLOTS - 1)
	slot_changed.emit(selected_slot)


# ── Inventory grid rebuild ────────────────────────────────────────────────────
## Recompute pocket/back/hand grid sizes from equipped items and rebuild grids.
func _update_inventory_grids() -> void:
	var pocket := _parse_grid_size(
		equipped_clothing.stat_effects.get("pocket_grid", "") if equipped_clothing else "",
		Inventory.DEFAULT_BODY_GRID)
	var back   := _parse_grid_size(
		equipped_back.stat_effects.get("back_grid",   "") if equipped_back   else "",
		Vector2i.ZERO)
	var hand   := _parse_grid_size(
		equipped_hand.stat_effects.get("hand_grid",   "") if equipped_hand   else "",
		Vector2i.ZERO)
	inventory.rebuild_grids(pocket, back, hand)
	# Update StatsWindow equip label.
	var hud_nodes := get_tree().get_nodes_in_group("hud")
	if not hud_nodes.is_empty():
		var hud = hud_nodes[0]
		if hud.has_method("update_equip_label"):
			hud.update_equip_label(
				equipped_clothing.item_name if equipped_clothing else "—",
				equipped_back.item_name     if equipped_back     else "—",
				equipped_hand.item_name     if equipped_hand     else "—")


func _parse_grid_size(s: String, default_val: Vector2i) -> Vector2i:
	if s.is_empty():
		return default_val
	var parts := s.split("x")
	if parts.size() == 2:
		return Vector2i(int(parts[0]), int(parts[1]))
	return default_val


## Open a storage container for this player.
func _open_container(container: WorldContainer) -> void:
	# Server-side: tell the container to send its items to us.
	var peer_id := get_multiplayer_authority()
	if multiplayer.is_server():
		container.interact(peer_id)
	else:
		container.rpc_id(1, "interact", peer_id)


## Toggle the InventoryWindow visibility (I key).
func _toggle_inventory_window() -> void:
	var hud_nodes := get_tree().get_nodes_in_group("hud")
	if hud_nodes.is_empty():
		return
	var hud = hud_nodes[0]
	var win = hud.get("_inventory_window")
	if win == null:
		return
	if win.visible:
		win.hide()
	else:
		win.show()


# ── Item drop (Q) / crafting (C) ──────────────────────────────────────────────
func _toggle_crafting_menu() -> void:
	var hud_nodes := get_tree().get_nodes_in_group("hud")
	if hud_nodes.is_empty():
		return
	var hud = hud_nodes[0]
	var menu = hud.get("_crafting_menu")
	if menu == null:
		return
	if menu.visible:
		menu.close()
	else:
		menu.open(inventory)


func _try_drop_selected() -> void:
	if selected_slot >= inventory.items.size():
		return
	_try_drop_item_at(selected_slot)


## Drop item at a specific flat-list index (called by InventoryWindow context menu too).
func _try_drop_item_at(idx: int) -> void:
	if idx < 0 or idx >= inventory.items.size():
		return
	var item: ItemData = inventory.items[idx]
	if equipped_weapon == item:
		equipped_weapon = null
		melee_damage    = base_melee_damage
	if equipped_clothing == item:
		equipped_clothing = null
	if equipped_back == item:
		equipped_back = null
	if equipped_hand == item:
		equipped_hand = null
	inventory.remove_at(idx)
	selected_slot = mini(selected_slot, maxi(0, inventory.items.size() - 1))
	slot_changed.emit(selected_slot)
	var world := get_tree().get_first_node_in_group("world_node")
	if world:
		var drop_name := "Drop_%d_%d" % [get_multiplayer_authority(), Time.get_ticks_msec()]
		if multiplayer.is_server():
			world.rpc_spawn_drop.rpc(global_position, drop_name, item.item_name, item.item_type, item.stat_effects)
		else:
			world.rpc_id(1, "rpc_request_item_drop", global_position, drop_name,
					item.item_name, item.item_type, item.stat_effects)


# ── Animation ─────────────────────────────────────────────────────────────────
func _update_animation(delta: float = 0.0) -> void:
	if _player_visual == null:
		return

	var is_local := get_multiplayer_authority() == multiplayer.get_unique_id()
	var facing   := facing_direction if is_local else sync_facing
	var moving   := velocity.length() > 5.0 if is_local else sync_velocity.length() > 5.0
	var sneaking := is_sneaking if is_local else sync_sneak

	# ── Downed pose ────────────────────────────────────────────────────────
	var downed := sync_is_downed or (stats != null and stats.is_downed)
	if downed:
		_walk_phase = 0.0
		_player_visual.modulate = Color(0.65, 0.15, 0.15) \
			if sync_drag_carrier_id != 0 else Color(0.55, 0.10, 0.10)
		_player_visual.rotation = 1.45   # lying on side
		_player_visual.scale    = Vector2(1.0, 1.0)
		return

	_player_visual.modulate  = Color.WHITE
	_player_visual.rotation  = 0.0

	# ── 8-direction pose swap ─────────────────────────────────────────────
	# Recompute geometry only when the facing octant changes.
	var dir8 := _facing_to_dir8(facing)
	if dir8 != _last_dir8:
		_last_dir8 = dir8
		_apply_player_pose(dir8)

	# ── Sprite controller updates (when active) ───────────────────────────
	# Player dir8: 0=E,1=SE,2=S,3=SW,4=W,5=NW,6=N,7=NE
	# Sprite dir8: 0=N,1=NE,2=E,3=SE,4=S,5=SW,6=W,7=NW → offset +2 mod 8
	if _sprite_controller != null:
		_sprite_controller.set_direction((dir8 + 2) % 8)
		_sprite_controller.set_moving(moving)
		_sprite_controller.tick(delta)

	var flip:    bool = _DIR8_MAP[dir8][1]
	# ── Scale: horizontal flip for W-facing octants, vertical squash for sneak ──
	var sneak_sy := 0.72 if sneaking else 1.0
	_player_visual.scale = Vector2(-1.0 if flip else 1.0, sneak_sy)

	# ── Weapon arm: correct rotation for parent flip ───────────────────────
	if _weapon_arm:
		# When scale.x = -1 the child's local x-axis is inverted.
		# Compensate so the arm always points toward the world facing direction.
		_weapon_arm.rotation = (PI - facing.angle()) if flip else facing.angle()

	# ── Facing dot orbits head perimeter ──────────────────────────────────
	if _facing_dot:
		# Compensate dot x for parent scale flip so it stays on the correct side.
		var fd_x := -facing.x if flip else facing.x
		_facing_dot.position = Vector2(fd_x * 6.5, -17.0 + facing.y * 6.5)

	# ── Walk / sneak bob ──────────────────────────────────────────────────
	var bob_speed := 6.0 if sneaking else 8.0
	var bob_amp   := 2.0 if sneaking else 3.5
	var arm_amp   := 1.5 if sneaking else 2.5

	if moving:
		_walk_phase += delta * bob_speed
	else:
		_walk_phase = 0.0

	if _leg_l and _leg_r:
		var bob := sin(_walk_phase) * bob_amp
		_leg_l.position.y =  bob
		_leg_r.position.y = -bob

	if _arm_l:
		_arm_l.position.y = sin(_walk_phase) * arm_amp

	# ── Clothing + weapon icon — rebuild when equip state changes ──────────
	var vis := _compute_equipped_visual() if is_local else sync_equipped_visual
	if vis != _last_vis:
		_last_vis = vis
		_update_weapon_icon()
		_update_clothing_visual()


# ── Sync ──────────────────────────────────────────────────────────────────────
func _update_sync_data() -> void:
	sync_position        = global_position
	sync_facing          = facing_direction
	sync_velocity        = velocity
	sync_is_downed       = (stats != null and stats.is_downed)
	sync_equipped_visual = _compute_equipped_visual()
	sync_sneak           = is_sneaking


func _setup_multiplayer_sync() -> void:
	var sync: MultiplayerSynchronizer = $MultiplayerSynchronizer
	if sync == null or sync.replication_config != null:
		return
	var config := SceneReplicationConfig.new()
	config.add_property(NodePath(".:sync_position"))
	config.add_property(NodePath(".:sync_facing"))
	config.add_property(NodePath(".:sync_velocity"))
	config.add_property(NodePath(".:sync_health"))
	config.add_property(NodePath(".:sync_is_downed"))
	config.add_property(NodePath(".:sync_drag_target_id"))
	config.add_property(NodePath(".:sync_drag_carrier_id"))
	config.add_property(NodePath(".:sync_equipped_visual"))
	config.property_set_replication_mode(NodePath(".:sync_equipped_visual"),
			SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	config.add_property(NodePath(".:sync_sneak"))
	config.property_set_replication_mode(NodePath(".:sync_sneak"),
			SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = config


# ── Procedural player visual ──────────────────────────────────────────────────
func _build_player_visual() -> void:
	if sprite:
		sprite.visible = false

	var peer_ids: Array = GameManager.get_all_peer_ids().duplicate()
	peer_ids.sort()
	var pidx: int = maxi(peer_ids.find(get_multiplayer_authority()), 0)
	const PLAYER_COLORS := [
		Color(0.40, 0.65, 1.00),  # blue
		Color(1.00, 0.60, 0.20),  # orange
		Color(0.35, 0.90, 0.35),  # green
		Color(0.90, 0.35, 0.90),  # purple
	]
	var col: Color = PLAYER_COLORS[pidx % PLAYER_COLORS.size()]
	_team_color = col
	const SKIN := Color(0.92, 0.78, 0.62)

	var root := Node2D.new()
	_player_visual = root
	add_child(root)

	# ── Legs (drawn first — behind body) ─────────────────────────────────────
	var ll := _pv_line([Vector2(-2.5, 2.0), Vector2(-4.5, 13.0)], col.darkened(0.35), 2.5)
	ll.name = "LegL"
	_leg_l  = ll
	root.add_child(ll)

	var lr := _pv_line([Vector2(2.5, 2.0), Vector2(4.5, 13.0)], col.darkened(0.35), 2.5)
	lr.name = "LegR"
	_leg_r  = lr
	root.add_child(lr)

	# ── Torso body (team-color base, covered by clothing layer) ───────────────
	var body := _pv_rect(Vector2(-4.5, -11.0), Vector2(9.0, 13.0), col)
	body.name = "Body"
	_body_poly = body
	root.add_child(body)

	# ── Passive left arm ─────────────────────────────────────────────────────
	var al := _pv_line([Vector2(-4.5, -9.0), Vector2(-13.5, -2.0)], SKIN, 2.0)
	al.name = "ArmL"
	_arm_l  = al
	root.add_child(al)

	# ── Head ─────────────────────────────────────────────────────────────────
	var head_circ := _pv_circle(Vector2(0.0, -17.0), 5.5, 12, SKIN)
	head_circ.name = "Head"
	_head_node = head_circ
	root.add_child(head_circ)

	# Hair cap — signals team identity even under heavy coat
	var hat := _pv_circle(Vector2(0.0, -21.0), 3.2, 8, col.darkened(0.15))
	hat.name  = "Hat"
	_hat_poly = hat
	root.add_child(hat)

	# Facing dot — orbits head perimeter, updated each frame
	var dot := _pv_circle(Vector2(0.0, -23.5), 1.8, 6, Color.WHITE)
	dot.name    = "FacingDot"
	_facing_dot = dot
	root.add_child(dot)

	# ── Weapon arm (pivots from right shoulder) ───────────────────────────────
	var arm := Node2D.new()
	arm.name     = "WeaponArm"
	arm.position = Vector2(4.5, -9.0)   # right shoulder
	_weapon_arm  = arm
	root.add_child(arm)

	# Skin-coloured arm from shoulder → hand
	arm.add_child(_pv_line([Vector2(0.0, 0.0), Vector2(10.0, 0.0)], SKIN, 2.0))

	# Weapon icon at hand position (rebuilt by _update_weapon_icon)
	var icon := Node2D.new()
	icon.name    = "WeaponIcon"
	icon.visible = false
	_weapon_icon = icon
	arm.add_child(icon)

	# ── Clothing layer (rebuilt when equipped clothing changes) ───────────────
	var cl := Node2D.new()
	cl.name         = "ClothingLayer"
	_clothing_layer = cl
	root.add_child(cl)

	# ── Sprite controller — overrides procedural visual when sheets assigned ──
	if sprite_sheets.size() > 0:
		_sprite_controller      = CharacterSpriteController.new()
		_sprite_controller.name = "SpriteController"
		_sprite_controller.sheets = sprite_sheets
		add_child(_sprite_controller)
		# Hide procedural visual; sprite controller takes over appearance.
		_player_visual.visible = false


func _update_weapon_icon() -> void:
	if _weapon_icon == null:
		return
	for child in _weapon_icon.get_children():
		child.queue_free()
	# vis bits: 3 = has weapon, 4 = ranged. WeaponArm is at shoulder (4.5,-9),
	# arm extends 10px → hand at x=10 in WeaponArm space.
	var has_weapon := (_last_vis >> 3) & 1
	var is_ranged  := (_last_vis >> 4) & 1
	if has_weapon == 0:
		_weapon_icon.visible = false
		return
	_weapon_icon.visible = true
	if is_ranged == 1:
		# Gun body + barrel tip, starting at hand (x=10 from shoulder).
		_weapon_icon.add_child(_pv_rect(Vector2(10.0, -2.5), Vector2(10.0, 5.0),
				Color(0.50, 0.50, 0.55)))
		_weapon_icon.add_child(_pv_rect(Vector2(18.0, -1.5), Vector2(6.0,  3.0),
				Color(0.38, 0.38, 0.42)))
	else:
		# Melee weapon: short warm bar.
		_weapon_icon.add_child(_pv_rect(Vector2(10.0, -2.0), Vector2(9.0, 4.0),
				Color(0.70, 0.38, 0.12)))


## Returns a packed integer encoding the player's current equip state for
## both local reads and network sync.  Bit layout:
##   bits 0-2: clothing tier (0=none 1=tshirt 2=jacket 3=work_jacket 4=winter_coat)
##   bit  3:   weapon equipped
##   bit  4:   weapon is ranged
func _compute_equipped_visual() -> int:
	var vis := 0
	if equipped_clothing != null:
		var name := equipped_clothing.item_name
		if "Winter" in name or "Coat" in name:
			vis |= 4
		elif "Work" in name:
			vis |= 3
		elif "Jacket" in name:
			vis |= 2
		else:
			vis |= 1   # T-Shirt / any light clothing
	if equipped_weapon != null:
		vis |= 8
		if equipped_weapon.stat_effects.has("projectile_damage"):
			vis |= 16
	return vis


## Rebuilds the clothing layer and updates body/hat colours based on the
## clothing tier encoded in _last_vis bits 0-2.
func _update_clothing_visual() -> void:
	if _clothing_layer == null or _body_poly == null:
		return
	for child in _clothing_layer.get_children():
		child.queue_free()

	var tier := _last_vis & 7
	var col   := _team_color

	match tier:
		0:  # No clothing — plain team-colour torso
			_body_poly.color = col
			if _hat_poly: _hat_poly.color = col.darkened(0.15)

		1:  # T-Shirt — team colour, V-neck collar
			_body_poly.color = col
			if _hat_poly: _hat_poly.color = col.darkened(0.15)
			_clothing_layer.add_child(_pv_line(
					[Vector2(-2.0, -11.0), Vector2(0.0, -9.0)],
					col.darkened(0.45), 1.2))
			_clothing_layer.add_child(_pv_line(
					[Vector2( 2.0, -11.0), Vector2(0.0, -9.0)],
					col.darkened(0.45), 1.2))

		2:  # Jacket — dark team colour, wide shoulders, lapels
			var coat := col.darkened(0.35)
			_body_poly.color = coat
			if _hat_poly: _hat_poly.color = col.darkened(0.15)
			# Shoulder pads
			_clothing_layer.add_child(_pv_rect(Vector2(-7.0, -12.0), Vector2(2.5, 4.0), coat.lightened(0.12)))
			_clothing_layer.add_child(_pv_rect(Vector2( 4.5, -12.0), Vector2(2.5, 4.0), coat.lightened(0.12)))
			# Lapels
			_clothing_layer.add_child(_pv_line(
					[Vector2(-3.0, -11.0), Vector2(0.0, -8.0)],
					coat.lightened(0.30), 1.5))
			_clothing_layer.add_child(_pv_line(
					[Vector2( 3.0, -11.0), Vector2(0.0, -8.0)],
					coat.lightened(0.30), 1.5))

		3:  # Work Jacket — earthy brown, same shape as jacket
			var coat := Color(0.52, 0.38, 0.20)
			var dark  := Color(0.44, 0.32, 0.18)
			_body_poly.color = coat
			if _hat_poly: _hat_poly.color = col.darkened(0.15)
			_clothing_layer.add_child(_pv_rect(Vector2(-7.0, -12.0), Vector2(2.5, 4.0), dark))
			_clothing_layer.add_child(_pv_rect(Vector2( 4.5, -12.0), Vector2(2.5, 4.0), dark))
			_clothing_layer.add_child(_pv_line(
					[Vector2(-3.0, -11.0), Vector2(0.0, -8.0)],
					Color(0.62, 0.48, 0.28), 1.5))
			_clothing_layer.add_child(_pv_line(
					[Vector2( 3.0, -11.0), Vector2(0.0, -8.0)],
					Color(0.62, 0.48, 0.28), 1.5))

		4:  # Winter Coat — off-white, puffy silhouette, thick collar
			var coat := Color(0.84, 0.84, 0.86)
			_body_poly.color = coat
			# Hat turns white to convey hood look
			if _hat_poly: _hat_poly.color = coat.darkened(0.06)
			# Puffy over-rect (wider + taller than base torso)
			_clothing_layer.add_child(_pv_rect(Vector2(-6.0, -12.0), Vector2(12.0, 15.0), coat))
			# Wide shoulder pads
			_clothing_layer.add_child(_pv_rect(Vector2(-8.0, -12.5), Vector2(3.0, 5.0), coat.darkened(0.08)))
			_clothing_layer.add_child(_pv_rect(Vector2( 5.0, -12.5), Vector2(3.0, 5.0), coat.darkened(0.08)))
			# Thick collar
			_clothing_layer.add_child(_pv_line(
					[Vector2(-4.0, -11.5), Vector2(0.0, -7.5)],
					Color(0.70, 0.70, 0.72), 2.5))
			_clothing_layer.add_child(_pv_line(
					[Vector2( 4.0, -11.5), Vector2(0.0, -7.5)],
					Color(0.70, 0.70, 0.72), 2.5))


func _pv_circle(center: Vector2, radius: float, segs: int, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	var pts  := PackedVector2Array()
	for i in segs:
		var a := TAU * float(i) / float(segs)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	poly.polygon = pts
	poly.color   = color
	return poly


func _pv_line(pts: Array, color: Color, width: float) -> Line2D:
	var line           := Line2D.new()
	line.default_color  = color
	line.width          = width
	for p: Vector2 in pts:
		line.add_point(p)
	return line


func _pv_rect(origin: Vector2, size: Vector2, color: Color) -> Polygon2D:
	var poly    := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		origin,
		origin + Vector2(size.x, 0.0),
		origin + size,
		origin + Vector2(0.0, size.y),
	])
	poly.color = color
	return poly


# ── Item receive (from trade) ─────────────────────────────────────────────────
@rpc("any_peer", "call_remote", "reliable")
func rpc_receive_item(item_name: String, item_type: int, effects: Dictionary) -> void:
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	var item := ItemData.make(item_name, item_type, effects)
	if inventory.add_item(item):
		SoundBus.play_sound_at("item_pickup", global_position)
		EventBus.item_picked_up.emit(get_multiplayer_authority(), item)
		# Auto-equip first weapon received if nothing is equipped yet.
		if equipped_weapon == null and item.item_type == ItemData.Type.WEAPON:
			_toggle_equip_weapon(item)


# ── Stat callbacks ────────────────────────────────────────────────────────────
func _on_stat_critical(stat_name: String) -> void:
	EventBus.player_stat_critical.emit(multiplayer.get_unique_id(), stat_name)
