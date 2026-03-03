class_name ZombieStateAlerted
extends ZombieStateBase

const ALERT_FILL_TIME: float = 1.5

var _alert_level: float = 0.0
var _alert_position: Vector2 = Vector2.ZERO


func enter(msg: Dictionary = {}) -> void:
	_alert_level = 0.0
	_alert_position = msg.get("position", zombie.global_position)
	# Face the noise/sight source
	var dir := (_alert_position - zombie.global_position).normalized()
	if dir != Vector2.ZERO:
		zombie.facing_direction = dir
	zombie.velocity = Vector2.ZERO

	# Register with horde coordinator immediately
	var coordinator: Node = zombie.get_tree().get_first_node_in_group("horde_coordinator")
	if coordinator:
		coordinator.register_alert(zombie, _alert_position)


func update(delta: float) -> void:
	_alert_level += delta / ALERT_FILL_TIME
	if _alert_level >= 1.0:
		# Sight-alerted: we already have a target — chase directly.
		# Noise-alerted only: no target yet, so move toward the noise position.
		# Skipping Chase avoids the 2s stand-still it produces with a null target.
		if zombie.chase_target and is_instance_valid(zombie.chase_target):
			state_machine.transition_to("ZombieStateChase")
		else:
			state_machine.transition_to("ZombieStateSearch", {"position": _alert_position})


func physics_update(_delta: float) -> void:
	zombie.move_and_slide()
