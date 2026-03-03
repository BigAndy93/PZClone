## CharacterSpriteController — Multi-layer AnimatedSprite2D manager.
## Handles 6 overlay layers (base_body, clothing, pants, bag, damage, shadow)
## driven by SpriteSheet resources, with 8-direction walk/idle animations.
##
## Art bible §3.2: "All characters follow modular layering. No full baked characters."
## Sprite_Template_Bible.md §6: each layer uses identical sheet structure.
##
## To activate: assign SpriteSheet resources to @export `sheets[]` on the player.
## Layers with no sheet assigned are hidden; the existing procedural visual stays
## active if NO sheets are assigned at all (Player._build_visual() controls this).
##
## Direction mapping (§2 — NEVER change this order):
##   0=N  1=NE  2=E  3=SE  4=S  5=SW  6=W  7=NW

class_name CharacterSpriteController
extends Node2D

# ── Layer definitions ─────────────────────────────────────────────────────────

enum Layer {
	BASE_BODY  = 0,   # skin / underwear
	CLOTHING   = 1,   # shirt / jacket
	PANTS      = 2,   # lower body
	BAG        = 3,   # backpack / bag (optional)
	DAMAGE     = 4,   # blood / bandage overlay
	SHADOW     = 5,   # baked shadow below character
}

const LAYER_COUNT := 6

# ── Exports ───────────────────────────────────────────────────────────────────

## One SpriteSheet per Layer enum value.  May be null (layer hidden).
@export var sheets: Array[SpriteSheet] = []

# ── Internal state ────────────────────────────────────────────────────────────

var _sprites:    Array[AnimatedSprite2D] = []
var _is_moving:  bool                   = false
var _direction8: int                    = 4        # default facing South
var _anim_timer: float                  = 0.0
var _anim_frame: int                    = 0


func _ready() -> void:
	_build_layers()


## (Re)build all layer nodes — call after changing `sheets`.
func _build_layers() -> void:
	# Remove any previously built sprites.
	for spr in _sprites:
		if is_instance_valid(spr):
			spr.queue_free()
	_sprites.clear()

	for i in LAYER_COUNT:
		var spr := AnimatedSprite2D.new()
		spr.z_index   = i
		spr.centered  = false   # pivot is handled via foot_pivot offset
		add_child(spr)
		_sprites.append(spr)

		var sheet := _get_sheet(i)
		if sheet == null or (sheet.walk_texture == null and sheet.idle_texture == null):
			spr.visible = false
			continue

		_load_sheet_into_sprite(spr, sheet)

	# Apply current state.
	_apply_animation()


## Update the 8-direction index (0=N … 7=NW).
func set_direction(dir8: int) -> void:
	_direction8 = clampi(dir8, 0, 7)
	_apply_animation()


## Switch between moving and idle state.
func set_moving(moving: bool) -> void:
	if moving != _is_moving:
		_is_moving = moving
		_anim_frame = 0
		_anim_timer = 0.0
		_apply_animation()


## Show or hide a specific layer (only works if a sheet was assigned).
func set_layer_visible(layer: Layer, visible: bool) -> void:
	if layer < _sprites.size():
		var sheet := _get_sheet(int(layer))
		_sprites[layer].visible = visible and sheet != null


## Hot-swap a single layer's sheet at runtime (e.g. clothing tier change).
## Pass null to hide the layer.  Re-loads SpriteFrames and restores current state.
func swap_sheet(layer: Layer, new_sheet: SpriteSheet) -> void:
	var idx := int(layer)
	# Grow the sheets array if needed.
	while sheets.size() <= idx:
		sheets.append(null)
	sheets[idx] = new_sheet

	if idx >= _sprites.size():
		return
	var spr := _sprites[idx]

	if new_sheet == null or (new_sheet.walk_texture == null and new_sheet.idle_texture == null):
		spr.sprite_frames = null
		spr.visible = false
		return

	_load_sheet_into_sprite(spr, new_sheet)
	spr.position = -new_sheet.foot_pivot
	spr.visible  = true
	# Restore current animation state immediately.
	var state     := "walk" if _is_moving else "idle"
	var anim_name := "%s_%d" % [state, _direction8]
	if spr.sprite_frames.has_animation(anim_name):
		spr.stop()
		spr.animation = anim_name
		spr.frame     = _anim_frame


## Advance animation frame.  Call from Player._process() or connect to signal.
func tick(delta: float) -> void:
	var sheet := _get_sheet(Layer.BASE_BODY)
	if sheet == null:
		return

	var fps := float(sheet.fps_walk if _is_moving else sheet.fps_idle)
	var frame_count := sheet.walk_frame_count if _is_moving else sheet.idle_frame_count

	_anim_timer += delta
	if _anim_timer >= 1.0 / fps:
		_anim_timer -= 1.0 / fps
		_anim_frame = (_anim_frame + 1) % frame_count
		_apply_animation()


# ── Internal helpers ──────────────────────────────────────────────────────────

func _get_sheet(layer_idx: int) -> SpriteSheet:
	if layer_idx < sheets.size():
		return sheets[layer_idx]
	return null


func _load_sheet_into_sprite(spr: AnimatedSprite2D, sheet: SpriteSheet) -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	# Build one animation per direction × state combination.
	# Each "animation" holds the frames for one row.
	for dir8 in 8:
		for state in ["walk", "idle"]:
			var anim_name := "%s_%d" % [state, dir8]
			var tex       := sheet.walk_texture if state == "walk" else sheet.idle_texture
			var n_frames  := sheet.walk_frame_count if state == "walk" else sheet.idle_frame_count
			var fps       := sheet.fps_walk if state == "walk" else sheet.fps_idle

			if tex == null:
				continue

			frames.add_animation(anim_name)
			frames.set_animation_loop(anim_name, true)
			frames.set_animation_speed(anim_name, float(fps))

			for f in n_frames:
				var region := Rect2(
					f * sheet.frame_size.x,
					dir8 * sheet.frame_size.y,
					sheet.frame_size.x,
					sheet.frame_size.y
				)
				var atlas := AtlasTexture.new()
				atlas.atlas  = tex
				atlas.region = region
				frames.add_frame(anim_name, atlas)

	spr.sprite_frames = frames

	# Offset so that foot_pivot aligns with this node's origin (ground position).
	spr.position = -sheet.foot_pivot


func _apply_animation() -> void:
	var state := "walk" if _is_moving else "idle"
	var anim_name := "%s_%d" % [state, _direction8]

	for spr in _sprites:
		if not spr.visible or spr.sprite_frames == null:
			continue
		if spr.sprite_frames.has_animation(anim_name):
			if spr.animation != anim_name:
				spr.stop()
				spr.animation = anim_name
			spr.frame = _anim_frame
