class_name ZombieStateBase
extends Node

## Base class for all zombie states. Subclasses override enter/exit/update/physics_update.

var state_machine: StateMachine = null
var zombie: CharacterBody2D = null  # set by ZombieStateMachine after instancing


func enter(_msg: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass
