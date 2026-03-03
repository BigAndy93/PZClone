class_name MathUtils
extends RefCounted

## Converts a flat (Cartesian) world vector to the isometric movement vector.
## For isometric projection rotated 45°, we rotate the input by -PI/4.
static func world_to_iso(v: Vector2) -> Vector2:
	return v.rotated(-PI / 4.0)


## Converts screen (isometric) direction back to world direction.
static func iso_to_world(v: Vector2) -> Vector2:
	return v.rotated(PI / 4.0)


## Returns the 8-direction index (0=N, 1=NE, 2=E, ... 7=NW) for a given vector.
static func direction_to_8way(dir: Vector2) -> int:
	if dir == Vector2.ZERO:
		return 2  # default: South
	var angle := dir.angle()  # radians, 0 = right
	# Convert to 0–360, then map to 8 sectors of 45°
	var deg := rad_to_deg(angle)
	deg = fmod(deg + 360.0 + 22.5, 360.0)
	return int(deg / 45.0)


## Direction names for animation lookup
const DIR_NAMES := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

static func direction_name(dir: Vector2) -> String:
	return DIR_NAMES[direction_to_8way(dir)]


## Clamps a value to [0, max_val].
static func clamp_stat(value: float, max_val: float = 100.0) -> float:
	return clampf(value, 0.0, max_val)
