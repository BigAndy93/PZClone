extends Node

enum Phase { DAY, DUSK, NIGHT, DAWN }

# Real seconds for one full in-game day (default 8 minutes).
@export var day_duration: float = 480.0

signal phase_changed(new_phase: Phase)
# Fires approximately every in-game minute.
signal hour_changed(hour: float)
# Fires each time the clock passes midnight.
signal day_changed(day: int)

# Start at 9 AM so the first play session begins in daylight.
var time_of_day:    float = 9.0
var current_phase:  Phase = Phase.DAY
var day_count:      int   = 1

var _prev_minute: int = -1


func _process(delta: float) -> void:
	var prev_hour := time_of_day
	time_of_day = fmod(time_of_day + (24.0 / day_duration) * delta, 24.0)

	# Detect midnight wrap → new day.
	if prev_hour > time_of_day:
		day_count += 1
		day_changed.emit(day_count)

	# Emit hour_changed roughly every in-game minute.
	var curr_min := int(time_of_day * 60.0) % 1440
	if curr_min != _prev_minute:
		_prev_minute = curr_min
		hour_changed.emit(time_of_day)

	var new_phase := _phase_for(time_of_day)
	if new_phase != current_phase:
		current_phase = new_phase
		phase_changed.emit(current_phase)


# Returns 0.0 (full day) → 1.0 (full night) for overlay alpha.
func get_darkness() -> float:
	match current_phase:
		Phase.DAY:
			return 0.0
		Phase.DUSK:
			var t := (time_of_day - 19.0) / 2.0
			return t * t           # ease-in
		Phase.NIGHT:
			return 1.0
		Phase.DAWN:
			var t := (time_of_day - 5.0) / 2.0
			return (1.0 - t) * (1.0 - t)   # ease-out
	return 0.0


func get_hour_string() -> String:
	var h := int(time_of_day)
	var m := int((time_of_day - h) * 60.0)
	return "%02d:%02d" % [h, m]


func _phase_for(h: float) -> Phase:
	if h >= 5.0 and h < 7.0:
		return Phase.DAWN
	elif h >= 7.0 and h < 19.0:
		return Phase.DAY
	elif h >= 19.0 and h < 21.0:
		return Phase.DUSK
	else:
		return Phase.NIGHT
