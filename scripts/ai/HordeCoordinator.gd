class_name HordeCoordinator
extends Node

## Server-only horde management.
##
## Replaces the old timed wave placeholder with three interlocking systems:
##
##  1. Population management — maintains a target zombie count that ramps up
##     over the first DIFFICULTY_RAMP_TIME seconds, then stays at MAX_ZOMBIES.
##     Repopulation spawns typed packs (REGULAR / RUNNER / BRUTE) off-screen.
##
##  2. Pack composition — type mix shifts toward faster/tougher enemies as
##     the session ages (RUNNER and BRUTE chances increase over time).
##
##  3. Migration pulses — every MIGRATION_INTERVAL seconds, idle zombie
##     clusters near recent noise activity are nudged toward that position.
##     This creates the "you'll pull them if you sprint" effect: gunshots and
##     melee noise are remembered and draw wandering groups toward the action.


# ── Debug ──────────────────────────────────────────────────────────────────────
const DEBUG_NO_ZOMBIES := false  # set true to stop all zombie spawning

# ── Tuning ─────────────────────────────────────────────────────────────────────
const PROPAGATION_RADIUS: float = 350.0   # alert chain radius (unchanged)

# Population
const MIN_ZOMBIES:       int   = 4       # target at session start
const MAX_ZOMBIES:       int   = 20      # hard cap (server perf ceiling)
const DIFFICULTY_RAMP_TIME: float = 360.0  # seconds to reach full difficulty
const REPOP_INTERVAL:    float = 18.0    # seconds between population checks
const MAX_SPAWN_PER_TICK: int  = 3       # zombies spawned per repop tick

# Pack composition — chances at t=0 and t=1 (lerped by difficulty)
const RUNNER_CHANCE_MIN: float = 0.08
const RUNNER_CHANCE_MAX: float = 0.30
const BRUTE_CHANCE_MIN:  float = 0.02
const BRUTE_CHANCE_MAX:  float = 0.20

# Spawn positioning
const SPAWN_DIST_MIN: float = 480.0
const SPAWN_DIST_MAX: float = 680.0

# Migration
const MIGRATION_INTERVAL:  float = 50.0   # seconds between migration pulses
const MIGRATION_RADIUS:    float = 550.0  # zombies within this range may migrate
const NOISE_HISTORY_SIZE:  int   = 6      # positions kept in ring buffer


# ── State ──────────────────────────────────────────────────────────────────────
var _repop_timer:     float = 0.0
var _migration_timer: float = 0.0
var _elapsed_total:   float = 0.0

## Ring buffer of world positions where significant noise recently occurred.
## Fed by gunshots, melee hits, and sprinting — used to aim migration pulses.
var _noise_history: Array[Vector2] = []


# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("horde_coordinator")
	if not multiplayer.is_server():
		set_process(false)
		return
	SoundBus.noise_emitted.connect(_on_noise_emitted)


func _process(delta: float) -> void:
	_elapsed_total   += delta
	_repop_timer     += delta
	_migration_timer += delta

	if _repop_timer >= REPOP_INTERVAL:
		_repop_timer = 0.0
		_check_population()

	if _migration_timer >= MIGRATION_INTERVAL:
		_migration_timer = 0.0
		_trigger_migration()


# ── Population management ──────────────────────────────────────────────────────

func _check_population() -> void:
	if DEBUG_NO_ZOMBIES:
		return
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return

	var current_count := get_tree().get_nodes_in_group("zombies").size()
	var target        := _target_population()
	if current_count >= target:
		return

	var spawn_count := mini(target - current_count, MAX_SPAWN_PER_TICK)
	_spawn_pack(spawn_count, players)


func _target_population() -> int:
	var t := clampf(_elapsed_total / DIFFICULTY_RAMP_TIME, 0.0, 1.0)
	return int(lerpf(float(MIN_ZOMBIES), float(MAX_ZOMBIES), t))


func _spawn_pack(count: int, players: Array) -> void:
	var world := get_parent()
	if world == null or not world.has_method("spawn_zombie_at_typed"):
		return

	# Pick a random player as the anchor — zombies spawn off-screen around them.
	var anchor: Node2D = players[randi() % players.size()]

	for _i in count:
		var angle := randf() * TAU
		var dist  := randf_range(SPAWN_DIST_MIN, SPAWN_DIST_MAX)
		var pos   := anchor.global_position + Vector2(cos(angle), sin(angle)) * dist
		world.spawn_zombie_at_typed(pos, _pick_zombie_type())


func _pick_zombie_type() -> int:
	var t := clampf(_elapsed_total / DIFFICULTY_RAMP_TIME, 0.0, 1.0)
	var brute_chance  := lerpf(BRUTE_CHANCE_MIN,  BRUTE_CHANCE_MAX,  t)
	var runner_chance := lerpf(RUNNER_CHANCE_MIN, RUNNER_CHANCE_MAX, t)
	var r := randf()
	if r < brute_chance:
		return Zombie.ZombieType.BRUTE
	elif r < brute_chance + runner_chance:
		return Zombie.ZombieType.RUNNER
	return Zombie.ZombieType.REGULAR


# ── Migration pulses ───────────────────────────────────────────────────────────

## Every MIGRATION_INTERVAL seconds, idle/wandering zombies within
## MIGRATION_RADIUS of a recent noise position are alerted toward it.
## This makes clusters drift toward active play areas without scripting.
func _trigger_migration() -> void:
	if _noise_history.is_empty():
		return

	var target_pos := _noise_history[randi() % _noise_history.size()]

	for zombie in get_tree().get_nodes_in_group("zombies"):
		if zombie.global_position.distance_to(target_pos) > MIGRATION_RADIUS:
			continue
		var sm: ZombieStateMachine = zombie.get_node_or_null("ZombieStateMachine")
		if sm == null:
			continue
		var state := sm.get_current_state_name()
		if state == "ZombieStateIdle" or state == "ZombieStateWander":
			zombie.receive_horde_alert(target_pos)


# ── Horde alert propagation ────────────────────────────────────────────────────

## Called by a zombie that just became alerted; chains to nearby idle zombies.
func register_alert(source_zombie: Node, alert_position: Vector2) -> void:
	if not multiplayer.is_server():
		return

	for zombie in get_tree().get_nodes_in_group("zombies"):
		if zombie == source_zombie:
			continue
		if not zombie.has_method("receive_horde_alert"):
			continue
		if zombie.global_position.distance_to(alert_position) <= PROPAGATION_RADIUS:
			zombie.receive_horde_alert(alert_position)

	EventBus.zombie_alerted.emit(source_zombie, alert_position)
	EventBus.horde_alerted.emit()


## Alert all zombies within radius (e.g. from a loud noise burst).
func alert_area(alert_position: Vector2, radius: float) -> void:
	if not multiplayer.is_server():
		return

	for zombie in get_tree().get_nodes_in_group("zombies"):
		if not zombie.has_method("receive_horde_alert"):
			continue
		if zombie.global_position.distance_to(alert_position) <= radius:
			zombie.receive_horde_alert(alert_position)


# ── Noise listener ─────────────────────────────────────────────────────────────

func _on_noise_emitted(pos: Vector2, radius: float, _source: String) -> void:
	# Immediate alert propagation for melee-level noise and above.
	if radius >= SoundBus.RADIUS_MELEE_HIT:
		alert_area(pos, radius)

	# Record significant noise for migration targeting (run noise and louder).
	if radius >= SoundBus.RADIUS_RUN:
		_noise_history.append(pos)
		if _noise_history.size() > NOISE_HISTORY_SIZE:
			_noise_history.pop_front()
