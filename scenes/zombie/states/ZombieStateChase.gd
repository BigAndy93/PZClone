class_name ZombieStateChase
extends ZombieStateBase

# Brief grace period before switching to Search — handles momentary occlusion.
# Kept short because ZombieStateSearch provides the extended last-known-position behavior.
const LOST_TARGET_TIMEOUT: float = 2.0

var _lost_timer:     float   = 0.0
var _last_known_pos: Vector2 = Vector2.ZERO  # fed into Search on timeout
var _nav_agent:      NavigationAgent2D = null


func enter(_msg: Dictionary = {}) -> void:
	_lost_timer = 0.0
	_nav_agent  = zombie.get_node_or_null("NavigationAgent2D")
	# Seed last_known_pos immediately so Search has a valid position even if
	# the target vanishes on the very first frame.
	if zombie.chase_target and is_instance_valid(zombie.chase_target):
		_last_known_pos = zombie.chase_target.global_position
	else:
		_last_known_pos = zombie.global_position


func update(_delta: float) -> void:
	if zombie.chase_target == null or not is_instance_valid(zombie.chase_target):
		_lost_timer += get_process_delta_time()
		if _lost_timer >= LOST_TARGET_TIMEOUT:
			state_machine.transition_to("ZombieStateSearch", {"position": _last_known_pos})
		return

	# Target visible — keep last known position current and reset the timer.
	_last_known_pos = zombie.chase_target.global_position
	_lost_timer = 0.0

	var dist := zombie.global_position.distance_to(zombie.chase_target.global_position)
	if dist <= zombie.attack_range:
		state_machine.transition_to("ZombieStateAttack")
		return

	if _nav_agent:
		_nav_agent.target_position = zombie.chase_target.global_position


func physics_update(_delta: float) -> void:
	if zombie.chase_target == null or not is_instance_valid(zombie.chase_target):
		zombie.velocity = Vector2.ZERO
		zombie.move_and_slide()
		return

	var move_dir: Vector2
	if _nav_agent and not _nav_agent.is_navigation_finished():
		var next_pos := _nav_agent.get_next_path_position()
		var to_next  := next_pos - zombie.global_position
		if to_next.length_squared() > 4.0:
			# Nav has a valid next waypoint — follow it.
			move_dir = to_next.normalized()
		else:
			# Nav returned our current position (path stalled) — move directly.
			move_dir = (zombie.chase_target.global_position - zombie.global_position).normalized()
	else:
		move_dir = (zombie.chase_target.global_position - zombie.global_position).normalized()

	zombie.velocity = move_dir * zombie.chase_speed
	if move_dir != Vector2.ZERO:
		zombie.facing_direction = move_dir
	zombie.move_and_slide()

	SoundBus.emit_noise(zombie.global_position, SoundBus.RADIUS_RUN, "zombie_run")
