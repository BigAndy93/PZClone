class_name Zombie
extends CharacterBody2D

# ── Zombie types ───────────────────────────────────────────────────────────────
enum ZombieType {
	REGULAR = 0,  # balanced — standard threat
	RUNNER  = 1,  # fast, fragile, hits light
	BRUTE   = 2,  # slow, tanky, hits hard
}

enum ZombieGender {
	MALE   = 0,
	FEMALE = 1,
}

@export var zombie_type:   int = ZombieType.REGULAR
@export var zombie_gender: int = ZombieGender.MALE   # overridden in _ready() for variety

# ── Tuning (overridden per type in _configure_for_type) ───────────────────────
@export var move_speed:         float = 36.0
@export var chase_speed:        float = 66.0
@export var attack_range:       float = 32.0
@export var attack_damage:      float = 15.0
@export var sight_range:        float = 200.0
@export var sight_fov_degrees:  float = 120.0
@export var hearing_radius:     float = 300.0
@export var horde_alert_radius: float = 150.0
@export var max_health:         float = 100.0

# Per-type attack cooldown — read by ZombieStateAttack.
var attack_cooldown: float = 0.8

# ── Runtime state ──────────────────────────────────────────────────────────────
var facing_direction: Vector2 = Vector2.RIGHT
var chase_target:     Node2D  = null
var health:           float   = 0.0
var _knockback:       Vector2 = Vector2.ZERO   # velocity impulse, decays quickly

var _base_move_speed:     float = 0.0
var _base_chase_speed:    float = 0.0
var _base_sight_range:    float = 0.0
var _base_hearing_radius: float = 0.0

# ── Sync ──────────────────────────────────────────────────────────────────────
var sync_position:       Vector2 = Vector2.ZERO
var sync_state_name:     String  = ""
var sync_target_peer_id: int     = 0
var sync_facing:         Vector2 = Vector2.RIGHT

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var state_machine: ZombieStateMachine = $ZombieStateMachine
@onready var sight_cone:    SightCone          = $SightCone
@onready var sprite:        AnimatedSprite2D   = $AnimatedSprite2D
@onready var horde_area:    Area2D             = $HordeAlertArea
@onready var nav_agent:     NavigationAgent2D  = $NavigationAgent2D

var _visual_root:       Node2D    = null  # procedural body — target for flash tween
var _visual_base_scale: float     = 1.0   # type scale (Runner=0.82, Brute=1.50) — const after build
var _zombie_torso:      Polygon2D = null  # torso shape — swapped per direction
var _zombie_head:       Polygon2D = null  # head circle — shifted per direction
var _walk_phase:        float     = 0.0   # drives limb bob
var _last_dir8:         int       = -1    # last facing octant

# ── 8-direction pose data ─────────────────────────────────────────────────────
# Canonical poses: 0=E, 1=SE, 2=S, 3=N, 4=NE.
# Per-pose layout: [leg_l[p0,p1], leg_r[p0,p1], arm_l[p0,p1], arm_r[p0,p1],
#                   torso_male[4pts], torso_female[4pts], head_x_off (float)]
static var _ZOMBIE_POSES: Array = [
	# 0 = E — side profile; torso narrow, arm_l back, arm_r lunges forward
	[[Vector2(-1.5,3.0),Vector2(-2.5,14.0)],
	 [Vector2( 1.5,3.0),Vector2( 3.5,14.0)],
	 [Vector2(-1.0,-9.0),Vector2(-6.0,-3.0)],
	 [Vector2( 1.0,-9.0),Vector2( 9.0,-1.0)],
	 [Vector2(-2.0,-11.0),Vector2(3.5,-11.0),Vector2(3.5,3.0),Vector2(-2.0,3.0)],
	 [Vector2(-1.5,-11.0),Vector2(3.0,-11.0),Vector2(3.0,3.0),Vector2(-1.5,3.0)],
	 1.5],
	# 1 = SE — front-right 3/4; both arms reaching forward-right
	[[Vector2(-2.0,3.0),Vector2(-4.0,14.0)],
	 [Vector2( 2.0,3.0),Vector2( 5.0,14.0)],
	 [Vector2(-1.0,-9.0),Vector2(-10.0,-1.0)],
	 [Vector2( 1.0,-9.0),Vector2( 11.0,-1.0)],
	 [Vector2(-5.0,-11.0),Vector2(6.0,-11.0),Vector2(7.0,3.0),Vector2(-4.0,3.0)],
	 [Vector2(-4.0,-11.0),Vector2(5.5,-11.0),Vector2(5.5,3.0),Vector2(-3.5,3.0)],
	 0.5],
	# 2 = S — full front view; widest torso, both arms outstretched
	[[Vector2(-2.0,3.0),Vector2(-5.0,14.0)],
	 [Vector2( 2.0,3.0),Vector2( 5.0,14.0)],
	 [Vector2(-1.0,-9.0),Vector2(-11.0,-1.0)],
	 [Vector2( 1.0,-9.0),Vector2( 11.0,-1.0)],
	 [Vector2(-5.0,-11.0),Vector2(6.0,-11.0),Vector2(7.0,3.0),Vector2(-4.0,3.0)],
	 [Vector2(-4.0,-11.0),Vector2(5.0,-11.0),Vector2(5.5,3.0),Vector2(-3.5,3.0)],
	 0.0],
	# 3 = N — back view; arms angled slightly away behind torso
	[[Vector2(-2.0,3.0),Vector2(-3.0,14.0)],
	 [Vector2( 2.0,3.0),Vector2( 3.0,14.0)],
	 [Vector2(-1.0,-9.0),Vector2(-10.0,-4.0)],
	 [Vector2( 1.0,-9.0),Vector2( 10.0,-4.0)],
	 [Vector2(-4.0,-11.0),Vector2(5.0,-11.0),Vector2(5.0,3.0),Vector2(-3.5,3.0)],
	 [Vector2(-3.5,-11.0),Vector2(4.5,-11.0),Vector2(4.5,3.0),Vector2(-3.0,3.0)],
	 0.0],
	# 4 = NE — back-right 3/4; medium-slim torso
	[[Vector2(-1.5,3.0),Vector2(-2.5,14.0)],
	 [Vector2( 2.0,3.0),Vector2( 4.0,14.0)],
	 [Vector2(-1.0,-9.0),Vector2(-9.0,-2.0)],
	 [Vector2( 1.0,-9.0),Vector2(10.0,-1.0)],
	 [Vector2(-3.0,-11.0),Vector2(5.0,-11.0),Vector2(5.5,3.0),Vector2(-2.5,3.0)],
	 [Vector2(-2.5,-11.0),Vector2(4.5,-11.0),Vector2(5.0,3.0),Vector2(-2.0,3.0)],
	 0.5],
]
# dir8: 0=E, 1=SE, 2=S, 3=SW, 4=W, 5=NW, 6=N, 7=NE → [canonical_idx, flip]
static var _DIR8_MAP: Array = [
	[0, false], [1, false], [2, false], [1, true],
	[0, true],  [4, true],  [3, false], [4, false],
]

static func _facing_to_dir8(v: Vector2) -> int:
	return int(fposmod(v.angle(), TAU) / (TAU / 8.0) + 0.5) % 8

func _apply_zombie_pose(dir8: int) -> void:
	var entry: Array = _DIR8_MAP[dir8]
	var pose:  Array = _ZOMBIE_POSES[entry[0]]
	var is_f:  bool  = zombie_gender == ZombieGender.FEMALE
	var leg_l: Line2D = _visual_root.get_node_or_null("LegL")
	var leg_r: Line2D = _visual_root.get_node_or_null("LegR")
	var arm_l: Line2D = _visual_root.get_node_or_null("ArmL")
	var arm_r: Line2D = _visual_root.get_node_or_null("ArmR")
	if leg_l: leg_l.set_point_position(0, pose[0][0]); leg_l.set_point_position(1, pose[0][1])
	if leg_r: leg_r.set_point_position(0, pose[1][0]); leg_r.set_point_position(1, pose[1][1])
	if arm_l: arm_l.set_point_position(0, pose[2][0]); arm_l.set_point_position(1, pose[2][1])
	if arm_r: arm_r.set_point_position(0, pose[3][0]); arm_r.set_point_position(1, pose[3][1])
	if _zombie_torso:
		_zombie_torso.polygon = PackedVector2Array(pose[5] if is_f else pose[4])
	if _zombie_head:
		_zombie_head.position = Vector2(float(pose[6]), 0.0)

var _sight_timer: float = 0.0
var _groan_timer: float = 0.0
const SIGHT_SCAN_INTERVAL: float = 0.1


func _ready() -> void:
	add_to_group("zombies")
	# Randomise gender for visual variety (Brutes are always male — heavier build).
	if zombie_type != ZombieType.BRUTE:
		zombie_gender = get_instance_id() % 2
	_configure_for_type()
	health                = max_health
	_base_move_speed      = move_speed
	_base_chase_speed     = chase_speed
	_base_sight_range     = sight_range
	_base_hearing_radius  = hearing_radius

	# Hide the scene's AnimatedSprite2D — we use a procedural visual.
	if sprite:
		sprite.visible = false
	_build_zombie_visual()
	_setup_multiplayer_sync()

	# All peers respond to day/night (cone size changes visually for everyone).
	DayNightCycle.phase_changed.connect(_on_day_phase_changed)

	if not multiplayer.is_server():
		state_machine.set_process(false)
		state_machine.set_physics_process(false)
		sight_cone.queue_free()
		if horde_area:
			horde_area.queue_free()
		return

	# Server-only setup
	state_machine.setup(self)
	state_machine.transition_to("ZombieStateIdle")

	sight_cone.owner_node = self
	sight_cone.sight_range = sight_range
	sight_cone.fov_degrees = sight_fov_degrees

	SoundBus.noise_emitted.connect(_on_noise_emitted)

	if horde_area:
		horde_area.body_entered.connect(_on_horde_area_body_entered)

	EventBus.zombie_spawned.emit(self)


# ── Multiplayer sync configuration ────────────────────────────────────────────
func _setup_multiplayer_sync() -> void:
	var syncer: MultiplayerSynchronizer = get_node_or_null("MultiplayerSynchronizer")
	if syncer == null or syncer.replication_config != null:
		return
	var config := SceneReplicationConfig.new()
	config.add_property(NodePath(".:sync_position"))
	config.add_property(NodePath(".:sync_state_name"))
	config.property_set_replication_mode(NodePath(".:sync_state_name"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	config.add_property(NodePath(".:sync_target_peer_id"))
	config.property_set_replication_mode(NodePath(".:sync_target_peer_id"), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	config.add_property(NodePath(".:sync_facing"))
	syncer.replication_config = config


# ── Per-type stat configuration ────────────────────────────────────────────────
func _configure_for_type() -> void:
	match zombie_type:
		ZombieType.RUNNER:
			move_speed      = 48.0
			chase_speed     = 111.0
			max_health      = 50.0
			attack_damage   = 8.0
			attack_range    = 28.0
			attack_cooldown = 0.50
			hearing_radius  = 350.0
		ZombieType.BRUTE:
			move_speed      = 22.0
			chase_speed     = 41.0
			max_health      = 280.0
			attack_damage   = 35.0
			attack_range    = 45.0
			attack_cooldown = 1.40
			sight_range     = 160.0
		_:  # REGULAR — defaults already set above
			attack_cooldown = 0.80


# ── Physics — knockback impulse (server-only) ─────────────────────────────────
func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if _knockback.length() > 2.0:
		_knockback = _knockback.lerp(Vector2.ZERO, delta * 9.0)
		velocity   = _knockback
		move_and_slide()


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		global_position = global_position.lerp(sync_position, delta * 10.0)
		_update_visual(delta)
		_update_groan(delta)
		return

	_sight_timer += delta
	if _sight_timer >= SIGHT_SCAN_INTERVAL:
		_sight_timer = 0.0
		_scan_sight()

	_update_visual(delta)
	_update_sync_data()
	_update_groan(delta)


func _update_groan(delta: float) -> void:
	if sync_state_name in ["ZombieStateChase", "ZombieStateAttack"]:
		_groan_timer -= delta
		if _groan_timer <= 0.0:
			_groan_timer = randf_range(2.5, 5.0)
			SoundBus.play_sound_at("zombie_groan", global_position)
	else:
		_groan_timer = randf_range(1.0, 3.0)


# ── Combat ────────────────────────────────────────────────────────────────────
func take_damage(amount: float, attacker_peer_id: int = 0, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if not multiplayer.is_server():
		return
	health -= amount
	if knockback_dir.length_squared() > 0.01:
		_knockback = knockback_dir.normalized() * 240.0
	flash_hit.rpc()
	if health <= 0.0:
		die(attacker_peer_id)


@rpc("authority", "call_local", "unreliable")
func flash_hit() -> void:
	SoundBus.play_sound_at("zombie_hit", global_position)
	if _visual_root == null:
		return
	var tween := create_tween()
	tween.tween_property(_visual_root, "modulate", Color(2.0, 0.3, 0.3, 1.0), 0.05)
	tween.tween_property(_visual_root, "modulate", Color.WHITE, 0.22)


@rpc("authority", "call_local", "unreliable")
func flash_die(killer_peer_id: int = 0) -> void:
	SoundBus.play_sound_at("zombie_die", global_position)
	EventBus.zombie_killed.emit(self, killer_peer_id)


func die(killer_peer_id: int = 0) -> void:
	if randf() < 0.40:
		var world := get_tree().get_first_node_in_group("world_node")
		if world and world.has_method("rpc_spawn_drop"):
			var drop := _pick_drop()
			world.rpc_spawn_drop.rpc(global_position, name + "_drop",
					drop[0], drop[1], drop[2])
	flash_die.rpc(killer_peer_id)
	queue_free()


static func _pick_drop() -> Array:
	var pool := [
		["Bandage",      ItemData.Type.BANDAGE, {"health": 15.0, "bleed": -1.0}],
		["Canned Food",  ItemData.Type.FOOD,    {"hunger": 35.0}],
		["Water Bottle", ItemData.Type.WATER,   {"thirst": 40.0}],
		["Pistol Mag",   ItemData.Type.MISC,    {"ammo_count": 15}],
	]
	return pool[randi() % pool.size()]


# ── Day / Night adjustment ────────────────────────────────────────────────────
func _on_day_phase_changed(phase: DayNightCycle.Phase) -> void:
	var night := phase == DayNightCycle.Phase.NIGHT
	# Vision cone resizes on all peers (visual feedback).
	sight_range = _base_sight_range * (0.65 if night else 1.0)
	# Speed / hearing changes are server-only.
	if not multiplayer.is_server():
		return
	var speed_mult := 1.4 if night else 1.0
	move_speed     = _base_move_speed     * speed_mult
	chase_speed    = _base_chase_speed    * speed_mult
	hearing_radius = _base_hearing_radius * (1.25 if night else 1.0)
	sight_cone.sight_range = sight_range


# ── AI (server-only) ──────────────────────────────────────────────────────────
func _scan_sight() -> void:
	sight_cone.facing_direction = facing_direction
	var detected: Array = sight_cone.scan()
	for player in detected:
		state_machine.receive_sight_alert(player)
		break


func _on_noise_emitted(world_position: Vector2, radius: float, _source: String) -> void:
	if not multiplayer.is_server():
		return
	var dist := global_position.distance_to(world_position)
	if dist <= hearing_radius and dist <= radius:
		state_machine.receive_noise_alert(world_position)


func receive_horde_alert(alert_position: Vector2) -> void:
	if not multiplayer.is_server():
		return
	state_machine.receive_noise_alert(alert_position)


func _on_horde_area_body_entered(body: Node) -> void:
	if not multiplayer.is_server():
		return
	if body.is_in_group("zombies") and body.has_method("receive_horde_alert"):
		var sm := state_machine.get_current_state_name()
		if sm == "ZombieStateAlerted" or sm == "ZombieStateChase":
			body.receive_horde_alert(global_position)


# ── Visual update (runs every frame on all peers) ─────────────────────────────
func _update_visual(delta: float) -> void:
	if _visual_root == null:
		return

	var state_name := state_machine.get_current_state_name() if multiplayer.is_server() else sync_state_name
	var is_moving  := state_name in ["ZombieStateChase", "ZombieStateWander", "ZombieStateSearch"]
	var is_attack  := state_name == "ZombieStateAttack"

	var fd := facing_direction if multiplayer.is_server() else sync_facing

	# ── 8-direction pose swap ─────────────────────────────────────────────
	var dir8 := _facing_to_dir8(fd)
	if dir8 != _last_dir8:
		_last_dir8 = dir8
		_apply_zombie_pose(dir8)
	var flip: bool = _DIR8_MAP[dir8][1]
	_visual_root.scale = Vector2(
		-_visual_base_scale if flip else _visual_base_scale,
		_visual_base_scale)

	# Advance walk/attack phase.
	if is_moving:
		_walk_phase += delta * 7.0
	elif is_attack:
		_walk_phase += delta * 14.0
	else:
		_walk_phase = 0.0

	var leg_l: Line2D = _visual_root.get_node_or_null("LegL")
	var leg_r: Line2D = _visual_root.get_node_or_null("LegR")
	var arm_l: Line2D = _visual_root.get_node_or_null("ArmL")
	var arm_r: Line2D = _visual_root.get_node_or_null("ArmR")

	if is_moving:
		var bob := sin(_walk_phase) * 3.0
		if leg_l: leg_l.position.y =  bob
		if leg_r: leg_r.position.y = -bob
		if arm_l: arm_l.position.y = -bob * 0.5
		if arm_r: arm_r.position.y =  bob * 0.5
	elif is_attack:
		# Arms lunge forward toward target.
		var lunge := maxf(sin(_walk_phase) * 6.0, 0.0)
		if arm_l: arm_l.position.x = lunge
		if arm_r: arm_r.position.x = lunge
	else:
		if leg_l: leg_l.position = Vector2.ZERO
		if leg_r: leg_r.position = Vector2.ZERO
		if arm_l: arm_l.position = Vector2.ZERO
		if arm_r: arm_r.position = Vector2.ZERO



# ── Procedural zombie body ─────────────────────────────────────────────────────
func _build_zombie_visual() -> void:
	var root    := Node2D.new()
	root.z_index = 1
	_visual_root = root
	add_child(root)

	const EYE := Color(0.85, 0.10, 0.10)
	var is_female := zombie_gender == ZombieGender.FEMALE

	var skin_col:   Color
	var shirt_col:  Color
	var pants_col:  Color
	var hair_col:   Color
	var base_scale: float = 1.0

	match zombie_type:
		ZombieType.RUNNER:
			if is_female:
				skin_col  = Color(0.78, 0.72, 0.74)   # paler pinkish-grey
				shirt_col = Color(0.48, 0.22, 0.28)   # dark burgundy tank
				pants_col = Color(0.26, 0.28, 0.32)   # dark slim pants
				hair_col  = Color(0.62, 0.42, 0.28)   # auburn
			else:
				skin_col  = Color(0.72, 0.76, 0.78)   # pale blue-grey
				shirt_col = Color(0.22, 0.28, 0.44)   # dark sporty top
				pants_col = Color(0.50, 0.52, 0.54)   # light grey bottoms
				hair_col  = Color(0.20, 0.15, 0.10)
			base_scale = 0.82
		ZombieType.BRUTE:
			# Brutes are always male (heavy build).
			skin_col  = Color(0.42, 0.35, 0.26)
			shirt_col = Color(0.16, 0.12, 0.10)
			pants_col = Color(0.22, 0.18, 0.14)
			hair_col  = Color(0.08, 0.06, 0.04)
			base_scale = 1.50
		_:  # REGULAR
			skin_col = Color(0.65, 0.70, 0.55)   # grey-green pallor
			if is_female:
				match get_instance_id() % 3:
					0:
						shirt_col = Color(0.44, 0.28, 0.30)  # dusty rose
						pants_col = Color(0.20, 0.18, 0.16)
						hair_col  = Color(0.55, 0.38, 0.22)  # light brown
					1:
						shirt_col = Color(0.32, 0.36, 0.28)  # sage green
						pants_col = Color(0.22, 0.20, 0.18)
						hair_col  = Color(0.18, 0.14, 0.10)
					_:
						shirt_col = Color(0.38, 0.32, 0.44)  # muted purple
						pants_col = Color(0.24, 0.22, 0.20)
						hair_col  = Color(0.60, 0.46, 0.28)  # dirty blonde
			else:
				match get_instance_id() % 3:
					0:
						shirt_col = Color(0.28, 0.34, 0.48)  # faded blue
						pants_col = Color(0.18, 0.16, 0.14)
						hair_col  = Color(0.28, 0.20, 0.12)
					1:
						shirt_col = Color(0.40, 0.38, 0.28)  # olive
						pants_col = Color(0.32, 0.26, 0.18)  # khaki
						hair_col  = Color(0.14, 0.10, 0.08)
					_:
						shirt_col = Color(0.34, 0.22, 0.18)  # rust-brown
						pants_col = Color(0.16, 0.14, 0.12)
						hair_col  = Color(0.52, 0.40, 0.24)  # blond

	root.scale          = Vector2(base_scale, base_scale)
	_visual_base_scale  = base_scale

	# ── Legs — drawn first so torso covers the tops ──────────────────────
	# Female: slightly narrower stance
	var leg_spread := 1.5 if is_female else 2.0
	var leg_l := _line2d([Vector2(-leg_spread, 3), Vector2(-5, 14)], pants_col, 2.5)
	leg_l.name = "LegL"
	root.add_child(leg_l)
	var leg_r := _line2d([Vector2(leg_spread, 3), Vector2(5, 14)], pants_col, 2.5)
	leg_r.name = "LegR"
	root.add_child(leg_r)

	# ── Shirt / torso ─────────────────────────────────────────────────────
	# Male: wider trapezoid (broad shoulders). Female: narrower, hourglass hint.
	# Stored as _zombie_torso so _apply_zombie_pose can swap vertices per direction.
	var torso_poly: Polygon2D
	if is_female and zombie_type != ZombieType.BRUTE:
		torso_poly = _poly([
			Vector2(-4,  -11), Vector2(5,  -11),  # narrower shoulders
			Vector2( 5.5,  3), Vector2(-3.5, 3),  # slight waist taper
		], shirt_col)
	else:
		torso_poly = _poly([
			Vector2(-5, -11), Vector2(6, -11),
			Vector2( 7,   3), Vector2(-4,  3),
		], shirt_col)
	torso_poly.name  = "Torso"
	_zombie_torso    = torso_poly
	root.add_child(torso_poly)

	# ── Arms ──────────────────────────────────────────────────────────────
	# Female: slightly shorter reach, thinner arms (2px narrower)
	var arm_w := 1.8 if is_female else 2.2
	var arm_l := _line2d([Vector2(-1, -9), Vector2(-11, -1)], skin_col, arm_w)
	arm_l.name = "ArmL"
	root.add_child(arm_l)
	var arm_r := _line2d([Vector2(1, -9), Vector2(11, -1)], skin_col, arm_w)
	arm_r.name = "ArmR"
	root.add_child(arm_r)

	# ── Head ──────────────────────────────────────────────────────────────
	# Female: slightly smaller head radius
	var head_r    := 5.2 if is_female else 6.0
	var head_poly := _circle_poly(Vector2(2, -17), head_r, 10, skin_col)
	head_poly.name = "Head"
	_zombie_head   = head_poly
	root.add_child(head_poly)

	# ── Hair ──────────────────────────────────────────────────────────────
	if is_female:
		# Longer hair silhouette (shoulder-length suggestion)
		root.add_child(_poly([
			Vector2(-4, -22), Vector2(5, -23), Vector2(8, -21),
			Vector2( 8, -12), Vector2(-4, -13),
		], hair_col))
	else:
		# Short tuft
		root.add_child(_poly([
			Vector2(-2, -23), Vector2(4, -24), Vector2(7, -22),
			Vector2( 5, -20), Vector2(-1, -20),
		], hair_col))

	# ── Eyes ──────────────────────────────────────────────────────────────
	root.add_child(_circle_poly(Vector2(-0.5, -18.5), 1.5, 6, EYE))
	root.add_child(_circle_poly(Vector2( 4.0, -18.5), 1.5, 6, EYE))

	# ── Blood stain (not on runners) ──────────────────────────────────────
	if zombie_type != ZombieType.RUNNER:
		root.add_child(_circle_poly(Vector2(2, -6), 2.5, 6, Color(0.50, 0.06, 0.06, 0.90)))

	# ── Brute extras ──────────────────────────────────────────────────────
	if zombie_type == ZombieType.BRUTE:
		root.add_child(_line2d([Vector2(-12, -10), Vector2(12, -10)], shirt_col, 5.0))
		root.add_child(_circle_poly(Vector2(3, -2), 5.5, 8, shirt_col.darkened(0.10)))


# ── Helpers (same interface as NPC) ───────────────────────────────────────────
func _circle_poly(center: Vector2, radius: float, segs: int, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	var pts  := PackedVector2Array()
	for i in segs:
		var a := TAU * i / segs
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	poly.polygon = pts
	poly.color   = color
	return poly


func _line2d(pts: Array, color: Color, width: float) -> Line2D:
	var line           := Line2D.new()
	line.default_color  = color
	line.width          = width
	for p: Vector2 in pts:
		line.add_point(p)
	return line


func _poly(pts: Array, color: Color) -> Polygon2D:
	var p    := Polygon2D.new()
	p.polygon = PackedVector2Array(pts)
	p.color   = color
	return p


# ── Sync ──────────────────────────────────────────────────────────────────────
func _update_sync_data() -> void:
	sync_position       = global_position
	sync_state_name     = state_machine.get_current_state_name()
	sync_target_peer_id = chase_target.get_multiplayer_authority() if chase_target else 0
	sync_facing         = facing_direction


# ── Legacy stub — no longer used ──────────────────────────────────────────────
func _create_placeholder_sprite() -> void:
	pass
