class_name ZombieStateWander
extends ZombieStateBase

const WANDER_RADIUS: float = 150.0
const ARRIVE_THRESHOLD: float = 10.0
const STUCK_TIMEOUT: float = 4.0

var _target: Vector2 = Vector2.ZERO
var _stuck_timer: float = 0.0
var _nav_agent: NavigationAgent2D = null


func enter(_msg: Dictionary = {}) -> void:
	_nav_agent = zombie.get_node_or_null("NavigationAgent2D")
	_pick_wander_target()
	_stuck_timer = 0.0


func _pick_wander_target() -> void:
	var angle := randf() * TAU
	var dist := randf_range(50.0, WANDER_RADIUS)
	_target = zombie.global_position + Vector2(cos(angle), sin(angle)) * dist
	if _nav_agent:
		_nav_agent.target_position = _target


func physics_update(delta: float) -> void:
	_stuck_timer += delta

	# Stuck: pick a fresh target rather than going idle (keeps zombie moving).
	if _stuck_timer >= STUCK_TIMEOUT:
		_pick_wander_target()
		_stuck_timer = 0.0
		return

	var to_target := _target - zombie.global_position
	if to_target.length() < ARRIVE_THRESHOLD:
		state_machine.transition_to("ZombieStateIdle")
		return

	var move_dir: Vector2

	if _nav_agent and not _nav_agent.is_navigation_finished():
		var next_pos := _nav_agent.get_next_path_position()
		var to_next  := next_pos - zombie.global_position
		move_dir = to_next.normalized() if to_next.length_squared() > 4.0 else to_target.normalized()
	else:
		# No navmesh or nav finished — move directly toward target.
		move_dir = to_target.normalized()

	zombie.velocity         = move_dir * zombie.move_speed
	zombie.facing_direction = move_dir
	zombie.move_and_slide()

	# Reset stuck timer whenever the zombie is actually making progress.
	if zombie.get_real_velocity().length_squared() > 25.0:
		_stuck_timer = 0.0

	# Colliding with a player — pick a new target to avoid sticking.
	for i in zombie.get_slide_collision_count():
		var col := zombie.get_slide_collision(i)
		if col and col.get_collider() and (col.get_collider() as Node).is_in_group("players"):
			_pick_wander_target()
			_stuck_timer = 0.0
			break

	if Engine.get_process_frames() % 6 == 0:
		SoundBus.emit_noise(zombie.global_position, SoundBus.RADIUS_WALK, "zombie_walk")
