class_name SightCone
extends Node

## Server-only. Performs raycasts in a 120° arc to detect players.
## Uses PhysicsDirectSpaceState2D directly — no RayCast2D nodes needed.

const RAY_COUNT: int = 9
const LAYER_PLAYERS: int = 1  # physics layer 1 = "Players"
const LAYER_WORLD:   int = 8  # physics layer 4 = "World" (walls/floors)

@export var sight_range: float = 200.0
@export var fov_degrees: float = 120.0

## Set by Zombie.gd each frame before calling scan().
var facing_direction: Vector2 = Vector2.RIGHT
var owner_node: Node2D = null  # the Zombie


func _ready() -> void:
	if not multiplayer.is_server():
		set_process(false)


## Returns an array of detected player nodes (CharacterBody2D in group "players").
func scan() -> Array:
	if owner_node == null:
		return []

	var space_state: PhysicsDirectSpaceState2D = owner_node.get_world_2d().direct_space_state
	var origin := owner_node.global_position
	var half_fov := deg_to_rad(fov_degrees / 2.0)
	var base_angle := facing_direction.angle()
	var detected: Array = []

	for i in range(RAY_COUNT):
		var t := float(i) / float(RAY_COUNT - 1)  # 0..1
		var ray_angle: float = base_angle + lerp(-half_fov, half_fov, t)
		var ray_dir := Vector2(cos(ray_angle), sin(ray_angle))
		var target := origin + ray_dir * sight_range

		var query := PhysicsRayQueryParameters2D.create(origin, target)
		query.collision_mask = LAYER_PLAYERS | LAYER_WORLD  # walls now occlude sight
		query.exclude = [owner_node.get_rid()]

		var result: Dictionary = space_state.intersect_ray(query)
		if result and result.collider and result.collider.is_in_group("players"):
			if not detected.has(result.collider):
				detected.append(result.collider)

	return detected


## Returns true if a specific target is visible.
func can_see(target: Node2D) -> bool:
	if owner_node == null:
		return false
	var to_target := target.global_position - owner_node.global_position
	if to_target.length() > sight_range:
		return false
	var angle_diff := abs(to_target.angle_to(facing_direction))
	if angle_diff > deg_to_rad(fov_degrees / 2.0):
		return false

	var space_state: PhysicsDirectSpaceState2D = owner_node.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		owner_node.global_position,
		target.global_position
	)
	query.collision_mask = LAYER_PLAYERS | 8  # also check world layer
	query.exclude = [owner_node.get_rid()]

	var result: Dictionary = space_state.intersect_ray(query)
	return result and result.collider == target
