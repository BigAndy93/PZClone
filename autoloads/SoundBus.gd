extends Node

signal noise_emitted(world_position: Vector2, radius: float, source_type: String)

# Noise radius constants (pixels) — used by zombie AI hearing
const RADIUS_WALK:       float = 80.0
const RADIUS_RUN:        float = 180.0
const RADIUS_FALL:       float = 120.0
const RADIUS_NPC_SPEECH: float = 60.0
const RADIUS_GUNSHOT:    float = 500.0
const RADIUS_MELEE_HIT:  float = 100.0

# Audio settings
const POOL_SIZE:      int   = 8
const MAX_HEAR_DIST:  float = 700.0   # beyond this, sounds are inaudible
const SAMPLE_RATE:    int   = 22050

var _pool:           Array[AudioStreamPlayer] = []
var _sounds:         Dictionary               = {}   # name -> AudioStreamWAV
var _step_cooldown:  float                    = 0.0
const STEP_INTERVAL: float                    = 0.30


func _ready() -> void:
	_build_pool()
	_build_sounds()


func _process(delta: float) -> void:
	_step_cooldown = maxf(_step_cooldown - delta, 0.0)


# ── Public API ─────────────────────────────────────────────────────────────────

func emit_noise(position: Vector2, radius: float, source: String = "generic") -> void:
	noise_emitted.emit(position, radius, source)


## Play a sound with no positional attenuation (UI sounds, etc.)
func play_sound(name: String, volume_db: float = 0.0) -> void:
	var stream: AudioStreamWAV = _sounds.get(name)
	if stream == null:
		return
	var player := _get_free_player()
	if player == null:
		return
	player.stream    = stream
	player.volume_db = volume_db
	player.play()


## Play a positional sound; volume is attenuated by distance to the local player.
func play_sound_at(name: String, world_pos: Vector2, base_db: float = 0.0) -> void:
	var stream: AudioStreamWAV = _sounds.get(name)
	if stream == null:
		return
	var vol_db := _dist_to_volume_db(world_pos, base_db)
	if vol_db <= -58.0:
		return  # Too far; skip entirely
	var player := _get_free_player()
	if player == null:
		return
	player.stream    = stream
	player.volume_db = vol_db
	player.play()


## Footstep wrapper with built-in rate limiting.
func play_footstep(world_pos: Vector2) -> void:
	if _step_cooldown > 0.0:
		return
	_step_cooldown = STEP_INTERVAL
	play_sound_at("footstep", world_pos, -8.0)


# ── Internals ──────────────────────────────────────────────────────────────────

func _get_free_player() -> AudioStreamPlayer:
	for p: AudioStreamPlayer in _pool:
		if not p.playing:
			return p
	return null  # All channels busy; drop this sound


func _dist_to_volume_db(world_pos: Vector2, base_db: float) -> float:
	var lp := _find_local_player()
	if lp == null:
		return base_db
	var dist := lp.global_position.distance_to(world_pos)
	if dist >= MAX_HEAR_DIST:
		return -80.0
	# Linear attenuation: 0 px → +0 dB, MAX_HEAR_DIST → -40 dB
	return base_db - 40.0 * (dist / MAX_HEAR_DIST)


func _find_local_player() -> Node2D:
	var my_id := multiplayer.get_unique_id()
	for p in get_tree().get_nodes_in_group("players"):
		if p.get_multiplayer_authority() == my_id:
			return p as Node2D
	return null


func _build_pool() -> void:
	for _i in POOL_SIZE:
		var ap := AudioStreamPlayer.new()
		ap.bus = "Master"
		add_child(ap)
		_pool.append(ap)


func _build_sounds() -> void:
	# Short noise bursts
	_sounds["footstep"]     = _make_noise(0.04, 0.30)
	_sounds["zombie_hit"]   = _make_noise(0.07, 0.70)
	_sounds["zombie_die"]   = _make_noise(0.18, 0.55)

	# Tonal / sweep sounds
	_sounds["melee_swing"]  = _make_sweep(480.0, 190.0, 0.10, 0.50)
	_sounds["item_pickup"]  = _make_sweep(440.0, 880.0, 0.09, 0.45)
	_sounds["item_use"]     = _make_tone(520.0,  0.10, 0.40)
	_sounds["zombie_groan"] = _make_tone(115.0,  0.25, 0.35)

	# Gunshot: sharp bang + high-frequency ring decay
	_sounds["gunshot"]      = _make_gunshot()


# ── PCM generation ─────────────────────────────────────────────────────────────

func _make_wav(pcm: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format   = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SAMPLE_RATE
	w.stereo   = false
	w.data     = pcm
	return w


## Pure sine tone with linear fade-out.
func _make_tone(freq: float, dur: float, amp: float) -> AudioStreamWAV:
	var n   := int(dur * SAMPLE_RATE)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t   := float(i) / SAMPLE_RATE
		var env := 1.0 - float(i) / n
		var s   := sin(TAU * freq * t) * amp * env
		pcm.encode_s16(i * 2, int(clamp(s, -1.0, 1.0) * 32767))
	return _make_wav(pcm)


## Frequency sweep (linear chirp) with fade-out.
func _make_sweep(f0: float, f1: float, dur: float, amp: float) -> AudioStreamWAV:
	var n     := int(dur * SAMPLE_RATE)
	var pcm   := PackedByteArray()
	pcm.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t    := float(i) / n
		var freq := f0 + (f1 - f0) * t
		var env  := 1.0 - t
		var s    := sin(phase) * amp * env
		phase   += TAU * freq / SAMPLE_RATE
		pcm.encode_s16(i * 2, int(clamp(s, -1.0, 1.0) * 32767))
	return _make_wav(pcm)


## Gunshot: loud noise transient + high-frequency ring tail.
func _make_gunshot() -> AudioStreamWAV:
	var dur := 0.18
	var n   := int(dur * SAMPLE_RATE)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t        := float(i) / n
		var env_bang := exp(-t * 30.0)
		var env_ring := exp(-t * 9.0)
		var bang     := (randf() * 2.0 - 1.0) * 0.92 * env_bang
		var ring     := sin(TAU * 3600.0 * float(i) / SAMPLE_RATE) * 0.22 * env_ring
		pcm.encode_s16(i * 2, int(clamp(bang + ring, -1.0, 1.0) * 32767))
	return _make_wav(pcm)


## White-noise burst with fade-out.
func _make_noise(dur: float, amp: float) -> AudioStreamWAV:
	var n   := int(dur * SAMPLE_RATE)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var env := 1.0 - float(i) / n
		var s   := (randf() * 2.0 - 1.0) * amp * env
		pcm.encode_s16(i * 2, int(clamp(s, -1.0, 1.0) * 32767))
	return _make_wav(pcm)
