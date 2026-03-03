class_name SurvivalStats
extends Resource

signal stat_changed(stat_name: String, value: float)
signal stat_critical(stat_name: String)
signal stat_depleted(stat_name: String)

const CRITICAL_THRESHOLD: float = 0.20  # 20% of max = critical
const MAX_VALUE: float = 100.0

@export var hunger: float = 100.0:
	set(v): hunger = _set_stat("hunger", v)
@export var thirst: float = 100.0:
	set(v): thirst = _set_stat("thirst", v)
@export var fatigue: float = 100.0:
	set(v): fatigue = _set_stat("fatigue", v)
@export var health: float = 100.0:
	set(v): health = _set_stat("health", v)
@export var stamina:      float = 100.0:
	set(v): stamina = _set_stat("stamina", v)
# Body temperature in °C. Normal range 35.5–38.5.  Clamped [30, 45].
@export var temperature:  float = 37.0:
	set(v):
		temperature = clampf(v, 30.0, 45.0)
		stat_changed.emit("temperature", temperature)
@export var bleed_stacks: int  = 0
@export var infection:    int  = 0   # 0 = clean, 1+ = infected (max 1 for now)
@export var fracture:     bool = false  # movement speed penalty
@export var deep_wound:   int  = 0     # requires suture kit to clear
var is_downed:            bool = false  # set by StatTickSystem; not a tracked stat


func _set_stat(stat_name: String, value: float) -> float:
	var clamped := clampf(value, 0.0, MAX_VALUE)
	stat_changed.emit(stat_name, clamped)
	if clamped <= MAX_VALUE * CRITICAL_THRESHOLD and clamped > 0.0:
		stat_critical.emit(stat_name)
	if clamped <= 0.0:
		stat_depleted.emit(stat_name)
	return clamped


func get_stat(stat_name: String) -> float:
	match stat_name:
		"hunger": return hunger
		"thirst": return thirst
		"fatigue": return fatigue
		"health": return health
	return 0.0


func set_stat(stat_name: String, value: float) -> void:
	match stat_name:
		"hunger": hunger = value
		"thirst": thirst = value
		"fatigue": fatigue = value
		"health": health = value


func apply_damage(amount: float) -> void:
	health -= amount


func add_bleed() -> void:
	bleed_stacks = mini(bleed_stacks + 1, 5)
	stat_changed.emit("bleed_stacks", float(bleed_stacks))


func remove_bleed(count: int = 1) -> void:
	bleed_stacks = maxi(bleed_stacks - count, 0)
	stat_changed.emit("bleed_stacks", float(bleed_stacks))


func add_infection() -> void:
	if infection > 0:
		return  # Already infected
	infection = 1
	stat_changed.emit("infection", float(infection))


func remove_infection() -> void:
	infection = 0
	stat_changed.emit("infection", float(infection))


func to_dict() -> Dictionary:
	return {
		"hunger":       hunger,
		"thirst":       thirst,
		"fatigue":      fatigue,
		"health":       health,
		"bleed_stacks": bleed_stacks,
		"infection":    infection,
		"fracture":     fracture,
		"deep_wound":   deep_wound,
		"is_downed":    is_downed,
		"temperature":  temperature,
	}


func from_dict(data: Dictionary) -> void:
	hunger       = data.get("hunger",      100.0)
	thirst       = data.get("thirst",      100.0)
	fatigue      = data.get("fatigue",     100.0)
	health       = data.get("health",      100.0)
	bleed_stacks = data.get("bleed_stacks", 0)
	infection    = data.get("infection",   0)
	fracture     = data.get("fracture",    false)
	deep_wound   = data.get("deep_wound",  0)
	is_downed    = data.get("is_downed",   false)
	temperature  = data.get("temperature", 37.0)
	stat_changed.emit("infection",   float(infection))
	stat_changed.emit("fracture",    1.0 if fracture else 0.0)
	stat_changed.emit("deep_wound",  float(deep_wound))
