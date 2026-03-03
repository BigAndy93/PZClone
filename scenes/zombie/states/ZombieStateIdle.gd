class_name ZombieStateIdle
extends ZombieStateBase

const IDLE_MIN: float = 3.0
const IDLE_MAX: float = 8.0

var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_timer = randf_range(IDLE_MIN, IDLE_MAX)
	zombie.velocity = Vector2.ZERO


func update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		state_machine.transition_to("ZombieStateWander")


func physics_update(_delta: float) -> void:
	zombie.move_and_slide()
