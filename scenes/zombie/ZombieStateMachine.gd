class_name ZombieStateMachine
extends StateMachine

## Extends the generic StateMachine with zombie-specific alert wiring.

var zombie: CharacterBody2D = null


func setup(zombie_node: CharacterBody2D) -> void:
	zombie = zombie_node
	for state in states.values():
		state.zombie = zombie_node


func receive_noise_alert(world_position: Vector2) -> void:
	var current := get_current_state_name()
	# Noise can interrupt idle wandering and searching — not an active chase/attack.
	if current in ["ZombieStateIdle", "ZombieStateWander", "ZombieStateSearch"]:
		transition_to("ZombieStateAlerted", {"position": world_position})


func receive_sight_alert(target: Node2D) -> void:
	zombie.chase_target = target
	var current := get_current_state_name()
	# Re-engage from Search; don't restart Chase/Attack (would reset their state).
	if current not in ["ZombieStateAttack", "ZombieStateChase"]:
		transition_to("ZombieStateChase")
