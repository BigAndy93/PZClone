class_name WeatherSystem
extends Node

## Server-authoritative weather state machine.
## Server ticks and broadcasts via RPC; clients receive and emit EventBus signal.

enum Weather { CLEAR = 0, OVERCAST = 1, RAIN = 2, HEAVY_RAIN = 3, FOG = 4 }

# Temperature offset in °C applied to ambient per weather type.
const TEMP_OFFSETS: Array[float] = [0.0, -0.5, -2.0, -4.0, -1.0]

# Weather label strings shown in HUD.
const WEATHER_LABELS: Array[String] = ["CLEAR", "OVERCAST", "RAIN", "HEAVY RAIN", "FOG"]

# Weighted random selection (must sum to 1.0).
const WEATHER_WEIGHTS: Array[float] = [0.40, 0.25, 0.20, 0.05, 0.10]

# Duration range per weather phase (seconds).
const DURATION_MIN: float = 180.0
const DURATION_MAX: float = 420.0

var current_weather: int = Weather.CLEAR
var _timer:          float = 0.0
var _duration:       float = 300.0


func _ready() -> void:
	add_to_group("weather_system")
	# Only server advances weather; clients receive via RPC.
	if not multiplayer.is_server():
		set_process(false)


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= _duration:
		_timer = 0.0
		_advance_weather()


func _advance_weather() -> void:
	var r := randf()
	var cumulative := 0.0
	var new_weather := current_weather
	for i in WEATHER_WEIGHTS.size():
		cumulative += WEATHER_WEIGHTS[i]
		if r < cumulative:
			new_weather = i
			break

	_duration = randf_range(DURATION_MIN, DURATION_MAX)

	if new_weather == current_weather:
		return  # No change — skip broadcast.

	_rpc_set_weather.rpc(new_weather)


@rpc("authority", "call_local", "reliable")
func _rpc_set_weather(weather: int) -> void:
	current_weather = weather
	EventBus.weather_changed.emit(weather)


## Returns the temperature offset (°C) for the current weather.
func get_temp_offset() -> float:
	if current_weather < 0 or current_weather >= TEMP_OFFSETS.size():
		return 0.0
	return TEMP_OFFSETS[current_weather]


## Returns the display label for the current weather.
func get_weather_label() -> String:
	if current_weather < 0 or current_weather >= WEATHER_LABELS.size():
		return "CLEAR"
	return WEATHER_LABELS[current_weather]
