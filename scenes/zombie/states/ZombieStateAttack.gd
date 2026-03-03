class_name ZombieStateAttack
extends ZombieStateBase

var _cooldown: float = 0.0
var _has_attacked: bool = false


func enter(_msg: Dictionary = {}) -> void:
	_cooldown = 0.0
	_has_attacked = false
	zombie.velocity = Vector2.ZERO


func update(delta: float) -> void:
	_cooldown += delta

	if not _has_attacked and _cooldown >= 0.2:
		_do_attack()
		_has_attacked = true

	if _cooldown >= zombie.attack_cooldown:
		# Re-evaluate: if target still in range, attack again; else chase
		if zombie.chase_target and is_instance_valid(zombie.chase_target):
			var dist := zombie.global_position.distance_to(zombie.chase_target.global_position)
			if dist <= zombie.attack_range:
				state_machine.transition_to("ZombieStateAttack")
			else:
				state_machine.transition_to("ZombieStateChase")
		else:
			state_machine.transition_to("ZombieStateIdle")


func _do_attack() -> void:
	if zombie.chase_target == null or not is_instance_valid(zombie.chase_target):
		return
	var dist := zombie.global_position.distance_to(zombie.chase_target.global_position)
	if dist > zombie.attack_range:
		return

	# Occasionally add bleed, infection, deep wound, or fracture.
	if zombie.chase_target.stats:
		if randf() < 0.25:
			zombie.chase_target.stats.add_bleed()
		if randf() < 0.10:
			zombie.chase_target.stats.add_infection()
		if randf() < 0.08:
			# Deep wound — needs suture kit to clear (stacks up to 3).
			zombie.chase_target.stats.deep_wound = mini(
					zombie.chase_target.stats.deep_wound + 1, 3)
		if randf() < 0.05:
			# Fracture — rare, causes movement penalty until splinted.
			zombie.chase_target.stats.fracture = true

	# Apply damage — also triggers an immediate stat sync to the client.
	var tick_system: Node = zombie.chase_target.get_node_or_null("StatTickSystem")
	if tick_system and tick_system.has_method("apply_damage_immediate"):
		tick_system.apply_damage_immediate(zombie.attack_damage)

	SoundBus.emit_noise(zombie.global_position, SoundBus.RADIUS_MELEE_HIT, "zombie_attack")


func physics_update(_delta: float) -> void:
	zombie.move_and_slide()
