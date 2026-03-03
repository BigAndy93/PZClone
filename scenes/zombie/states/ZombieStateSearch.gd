class_name ZombieStateSearch
extends ZombieStateBase

## After losing a chase target, zombie moves to the last known position,
## scans the area for SEARCH_DURATION seconds, then disengages to wander.
## Mid-search noise or sight re-engage the appropriate alert pipeline.

const SEARCH_DURATION: float = 6.0  # total time before giving up
const ARRIVED_DIST:    float = 50.0  # pixels — considered "at" last known pos

var _search_timer:   float   = 0.0
var _last_known_pos: Vector2 = Vector2.ZERO
var _arrived:        bool    = false
var _nav_agent:      NavigationAgent2D = null


func enter(msg: Dictionary = {}) -> void:
	_search_timer   = 0.0
	_arrived        = false
	_last_known_pos = msg.get("position", zombie.global_position)
	_nav_agent      = zombie.get_node_or_null("NavigationAgent2D")
	if _nav_agent:
		_nav_agent.target_position = _last_known_pos


func update(delta: float) -> void:
	_search_timer += delta

	if not _arrived:
		var dist := zombie.global_position.distance_to(_last_known_pos)
		if dist <= ARRIVED_DIST:
			_arrived = true
			zombie.velocity = Vector2.ZERO

	if _search_timer >= SEARCH_DURATION:
		state_machine.transition_to("ZombieStateWander")


func physics_update(_delta: float) -> void:
	if _arrived:
		zombie.velocity = Vector2.ZERO
		zombie.move_and_slide()
		return

	var move_dir: Vector2
	if _nav_agent and not _nav_agent.is_navigation_finished():
		var next_pos := _nav_agent.get_next_path_position()
		move_dir = (next_pos - zombie.global_position).normalized()
	else:
		move_dir = (_last_known_pos - zombie.global_position).normalized()

	zombie.velocity = move_dir * zombie.move_speed
	if move_dir != Vector2.ZERO:
		zombie.facing_direction = move_dir
	zombie.move_and_slide()
