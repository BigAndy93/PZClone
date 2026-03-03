class_name StateMachine
extends Node

signal state_changed(from: String, to: String)

var current_state: Node = null
var states: Dictionary = {}  # state_name -> Node


func _ready() -> void:
	# Collect all child states — entry is handled by the owning node via transition_to()
	for child in get_children():
		if child.has_method("enter"):
			states[child.name] = child
			child.state_machine = self


func _process(delta: float) -> void:
	if current_state and current_state.has_method("update"):
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state and current_state.has_method("physics_update"):
		current_state.physics_update(delta)


func transition_to(state_name: String, msg: Dictionary = {}) -> void:
	if not states.has(state_name):
		push_error("StateMachine: unknown state '%s'" % state_name)
		return
	var prev_name: String = current_state.name if current_state else ""	
	if current_state and current_state.has_method("exit"):
		current_state.exit()
	current_state = states[state_name]
	if current_state.has_method("enter"):
		current_state.enter(msg)
	state_changed.emit(prev_name, state_name)


func get_current_state_name() -> String:
	return current_state.name if current_state else ""
