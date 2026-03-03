class_name StatTickSystem
extends Node

## Server-only node. Drives stat decay + cascading effects, then syncs to client.

const TICK_RATE: float = 5.0

# ── Debug ───────────────────────────────────────────────────────────────────────
const DEBUG_GOD_MODE := true    # set true to disable all incoming damage

# Decay per tick
const HUNGER_DECAY:  float = 1.5
const THIRST_DECAY:  float = 2.0
const FATIGUE_DECAY: float = 1.0

# Cascade damage per tick
const HUNGER_HEALTH_DAMAGE:    float = 3.0   # when hunger <= 20
const THIRST_HEALTH_DAMAGE:    float = 4.0   # when thirst <= 20
const BLEED_DAMAGE_PER_STACK:  float = 5.0
const INFECTION_HEALTH_DAMAGE: float = 2.5   # per tick while infected
const DEEP_WOUND_HEALTH_DAMAGE: float = 3.5  # per tick — requires suture kit
const FRACTURE_FATIGUE_DRAIN:  float = 1.5   # extra fatigue per tick while fractured

# Temperature
const HYPOTHERMIA_THRESHOLD: float = 34.5   # below this → health loss
const HEATSTROKE_THRESHOLD:  float = 39.5   # above this → thirst drain
const HYPOTHERMIA_DAMAGE:    float = 2.0    # health per tick while hypothermic
const HYPOTHERMIA_FATIGUE:   float = 0.8    # extra fatigue per tick
const HEATSTROKE_THIRST:     float = 2.0    # extra thirst drain per tick

# Rest
const REST_FATIGUE_REGEN:    float = 10.0   # base fatigue restored per tick while resting
const SLEEP_INTERRUPT_RANGE: float = 100.0  # zombie closer than this interrupts rest
const SLEEP_COMFORT_RANGE:   float = 200.0  # zombie closer than this degrades quality
const SLEEP_CHECK_INTERVAL:  float = 1.0    # seconds between proximity checks

# Downed state
const BLEED_OUT_TIME: float = 30.0  # seconds before death when downed

var is_downed:          bool  = false
var is_resting:         bool  = false   # set by Player.rpc_request_set_resting
var _bleed_out_timer:   float = 0.0
var _sleep_check_timer: float = 0.0

var _timer:          float = 0.0
var _owner_peer_id:  int   = 0
var stats:           SurvivalStats = null


func _ready() -> void:
	if not multiplayer.is_server():
		set_process(false)
		return


func setup(peer_id: int, survival_stats: SurvivalStats) -> void:
	_owner_peer_id = peer_id
	stats          = survival_stats


func _process(delta: float) -> void:
	if stats == null:
		return

	# Bleed-out countdown while downed — no normal ticking.
	if is_downed:
		_bleed_out_timer -= delta
		if _bleed_out_timer <= 0.0:
			is_downed       = false
			stats.is_downed = false
			# Clean up drag state before the node is freed.
			get_parent().server_clear_drag_state()
			GameManager.player_died.emit(_owner_peer_id)
		return

	# Check for sleep interruption every second while resting.
	if is_resting:
		_sleep_check_timer += delta
		if _sleep_check_timer >= SLEEP_CHECK_INTERVAL:
			_sleep_check_timer = 0.0
			_check_sleep_interrupt()
	else:
		_sleep_check_timer = 0.0

	_timer += delta
	if _timer >= TICK_RATE:
		_timer -= TICK_RATE
		_tick()


func _tick() -> void:
	# ── Decay ────────────────────────────────────────────────────────────────
	stats.hunger  = maxf(stats.hunger  - HUNGER_DECAY,  0.0)
	stats.thirst  = maxf(stats.thirst  - THIRST_DECAY,  0.0)
	stats.fatigue = maxf(stats.fatigue - FATIGUE_DECAY, 0.0)

	if stats.fracture:
		stats.fatigue = maxf(stats.fatigue - FRACTURE_FATIGUE_DRAIN, 0.0)

	# ── Cascade damage ────────────────────────────────────────────────────────
	if stats.hunger <= 20.0:
		stats.health = maxf(stats.health - HUNGER_HEALTH_DAMAGE, 0.0)
	if stats.thirst <= 20.0:
		stats.health = maxf(stats.health - THIRST_HEALTH_DAMAGE, 0.0)
	if stats.bleed_stacks > 0:
		stats.health = maxf(stats.health - BLEED_DAMAGE_PER_STACK * stats.bleed_stacks, 0.0)
	if stats.infection > 0:
		stats.health = maxf(stats.health - INFECTION_HEALTH_DAMAGE, 0.0)
	if stats.deep_wound > 0:
		stats.health = maxf(stats.health - DEEP_WOUND_HEALTH_DAMAGE * stats.deep_wound, 0.0)

	# ── Rest ──────────────────────────────────────────────────────────────────
	if is_resting:
		var quality := _compute_sleep_quality()
		stats.fatigue = minf(stats.fatigue + REST_FATIGUE_REGEN * quality, 100.0)

	# ── Temperature ───────────────────────────────────────────────────────────
	_tick_temperature()

	# ── Death / Down check ────────────────────────────────────────────────────
	if stats.health <= 0.0:
		if not is_downed:
			_go_downed()
		return

	# ── Replicate ─────────────────────────────────────────────────────────────
	get_parent().sync_health = stats.health
	_sync_to_client()


func _go_downed() -> void:
	is_downed             = true
	_bleed_out_timer      = BLEED_OUT_TIME
	stats.is_downed       = true
	stats.health          = 0.0
	get_parent().sync_health = 0.0
	_sync_to_client()
	GameManager.player_downed.emit(_owner_peer_id)


## Called by server when a teammate successfully revives this player.
func revive() -> void:
	if not is_downed:
		return
	is_downed            = false
	_bleed_out_timer     = 0.0
	stats.is_downed      = false
	stats.health         = 30.0
	get_parent().sync_health = stats.health
	_sync_to_client()


func _sync_to_client() -> void:
	if _owner_peer_id == 0:
		return
	var data := stats.to_dict()
	if _owner_peer_id == multiplayer.get_unique_id():
		_rpc_sync_stats.call(data)
	else:
		rpc_id(_owner_peer_id, "_rpc_sync_stats", data)


# "any_peer" so the server (which may not be the node's authority) can push updates.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_sync_stats(data: Dictionary) -> void:
	if stats == null:
		return
	stats.from_dict(data)


## Adjust body temperature toward ambient and apply hot/cold effects.
## Ambient follows a sinusoidal curve keyed to the in-game hour:
##   - Hour 3  (pre-dawn) → 34.5 °C  (cold, borderline hypothermia)
##   - Hour 12 (noon)     → 39.5 °C  (hot, borderline heatstroke)
func _tick_temperature() -> void:
	var hour:    float = DayNightCycle.time_of_day
	# sin peaks at hour 9, troughs at hour 21 — shifted by 0.125 of TAU.
	var ambient: float = 37.0 + 2.5 * sin(TAU * (hour / 24.0 - 0.125))

	# Indoors: temperature is insulated — ambient clamps to a narrower band.
	if _is_player_sheltered():
		ambient = clampf(ambient, 35.5, 38.5)  # buildings keep you ~comfortable

	# Clothing insulation reduces temperature drift (0.0 = none, 1.0 = full).
	var clothing: ItemData = get_parent().get("equipped_clothing")
	var insulation: float  = clothing.stat_effects.get("insulation", 0.0) if clothing != null else 0.0

	# Drift toward ambient (slower indoors — 0.1, faster outdoors — 0.4).
	# Insulation reduces drift by up to 75% (a winter coat almost stops drift).
	var drift_base := 0.10 if _is_player_sheltered() else 0.40
	var drift      := drift_base * (1.0 - insulation * 0.75)
	stats.temperature = lerpf(stats.temperature, ambient, drift)

	if stats.temperature <= HYPOTHERMIA_THRESHOLD:
		stats.health  = maxf(stats.health  - HYPOTHERMIA_DAMAGE,  0.0)
		stats.fatigue = maxf(stats.fatigue - HYPOTHERMIA_FATIGUE, 0.0)
	elif stats.temperature >= HEATSTROKE_THRESHOLD:
		stats.thirst  = maxf(stats.thirst  - HEATSTROKE_THIRST,   0.0)

	# God mode: undo all tick-based health damage.
	if DEBUG_GOD_MODE:
		stats.health = 100.0


## Returns true if the player is standing on a building floor tile (sheltered).
func _is_player_sheltered() -> bool:
	var world := get_tree().get_first_node_in_group("world_node")
	if world == null:
		return false
	var map_data = world.get("_map_data")
	var tilemap := world.get_node_or_null("TileMapLayer") as WorldTileMap
	if map_data == null or tilemap == null:
		return false
	var player_pos: Vector2  = get_parent().sync_position
	var tile_local: Vector2i = tilemap.local_to_map(player_pos)
	var origin: Vector2i     = map_data.origin_offset
	var tile_map: Vector2i   = tile_local - origin
	return map_data.get_tile(tile_map.x, tile_map.y) == MapData.TILE_FLOOR


## Returns a sleep quality multiplier (0.3–1.8) based on safety and shelter.
## Called each rest tick so quality adjusts dynamically.
func _compute_sleep_quality() -> float:
	var quality := 1.0
	if _is_player_sheltered():
		quality += 0.4   # indoors is more restful
	var player_pos: Vector2 = get_parent().sync_position
	for zombie in get_tree().get_nodes_in_group("zombies"):
		if not is_instance_valid(zombie):
			continue
		var dist := player_pos.distance_to(zombie.global_position)
		if dist < SLEEP_COMFORT_RANGE:
			quality -= 0.3   # nearby zombie degrades rest quality
	return clampf(quality, 0.3, 1.8)


## Checked every second while resting — interrupts rest if a zombie is too close.
func _check_sleep_interrupt() -> void:
	var player_pos: Vector2 = get_parent().sync_position
	for zombie in get_tree().get_nodes_in_group("zombies"):
		if not is_instance_valid(zombie):
			continue
		if player_pos.distance_to(zombie.global_position) < SLEEP_INTERRUPT_RANGE:
			_interrupt_sleep()
			return


func _interrupt_sleep() -> void:
	is_resting = false
	var player := get_parent()
	if _owner_peer_id == multiplayer.get_unique_id():
		# Server is also the local player — set directly.
		player.is_resting = false
		EventBus.item_used.emit(_owner_peer_id, "Something woke you up!")
	else:
		player.rpc_interrupt_rest.rpc_id(_owner_peer_id)


## Called immediately when damage is applied (no waiting for tick).
func apply_damage_immediate(amount: float) -> void:
	if not multiplayer.is_server():
		return
	if is_downed:
		return
	if DEBUG_GOD_MODE:
		return
	stats.apply_damage(amount)
	if stats.health <= 0.0:
		_go_downed()
	else:
		get_parent().sync_health = stats.health
		_sync_to_client()
