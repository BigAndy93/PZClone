class_name Minimap
extends Control

## Overhead minimap rendered from MapData tile grid.
## One pixel per tile (68×68), scaled up to fill a 150×150 Control.
## Call initialize() once the world is ready.

const MAP_W := 68
const MAP_H := 68

var _static_img:  Image         = null   # baked tile colors, never changed
var _dynamic_img: Image         = null   # working copy, redrawn each frame
var _display:     TextureRect   = null
var _tilemap:     WorldTileMap  = null
var _origin:      Vector2i      = Vector2i.ZERO


func _ready() -> void:
	# Anchor to bottom-right, above the 58 px inventory strip.
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_right  = -6.0
	offset_bottom = -65.0
	offset_left   = -156.0   # → 150 px wide
	offset_top    = -215.0   # → 150 px tall

	var bg       := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color      = Color(0.0, 0.0, 0.0, 0.72)
	add_child(bg)

	_display = TextureRect.new()
	_display.set_anchors_preset(Control.PRESET_FULL_RECT)
	_display.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode  = TextureRect.STRETCH_SCALE
	add_child(_display)

	# Title label
	var title      := Label.new()
	title.text      = "MAP"
	title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title.offset_left   = 3.0
	title.offset_top    = 2.0
	title.offset_right  = 40.0
	title.offset_bottom = 16.0
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	add_child(title)


func initialize(tilemap: WorldTileMap, map_data: MapData) -> void:
	_tilemap = tilemap
	_origin  = map_data.origin_offset
	_bake_static(map_data)


# ── Static tile image (baked once) ────────────────────────────────────────────

func _bake_static(map_data: MapData) -> void:
	_static_img = Image.create(MAP_W, MAP_H, false, Image.FORMAT_RGBA8)

	for ty in MAP_H:
		for tx in MAP_W:
			_static_img.set_pixel(tx, ty, _tile_color(map_data.get_tile(tx, ty)))

	# Darken building footprints
	for bd in map_data.buildings:
		var r: Rect2i = bd.tile_rect
		for by in range(r.position.y, r.end.y):
			for bx in range(r.position.x, r.end.x):
				if bx >= 0 and bx < MAP_W and by >= 0 and by < MAP_H:
					_static_img.set_pixel(bx, by, Color(0.26, 0.20, 0.14))

	_dynamic_img = _static_img.duplicate()
	_display.texture = ImageTexture.create_from_image(_dynamic_img)


func _tile_color(t: int) -> Color:
	match t:
		MapData.TILE_GRASS:  return Color(0.15, 0.25, 0.12)
		MapData.TILE_ROAD:   return Color(0.36, 0.36, 0.34)
		MapData.TILE_DIRT:   return Color(0.28, 0.22, 0.16)
		MapData.TILE_FLOOR:  return Color(0.22, 0.18, 0.14)
	return Color(0.07, 0.07, 0.07)


# ── Per-frame dynamic layer ────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _static_img == null or _tilemap == null:
		return

	_dynamic_img.copy_from(_static_img)

	var my_id := multiplayer.get_unique_id()

	for zombie in get_tree().get_nodes_in_group("zombies"):
		_dot(zombie.global_position, Color(0.90, 0.12, 0.12))

	for npc in get_tree().get_nodes_in_group("npcs"):
		_dot(npc.global_position, Color(0.95, 0.85, 0.10))

	for player in get_tree().get_nodes_in_group("players"):
		var col := Color.WHITE if player.get_multiplayer_authority() == my_id \
				else Color(0.35, 0.55, 1.0)
		_dot(player.global_position, col, 2)

	(_display.texture as ImageTexture).update(_dynamic_img)


func _dot(world_pos: Vector2, color: Color, radius: int = 1) -> void:
	var mc := _tilemap.local_to_map(world_pos)
	var px := mc.x - _origin.x
	var py := mc.y - _origin.y
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var x := px + dx
			var y := py + dy
			if x >= 0 and x < MAP_W and y >= 0 and y < MAP_H:
				_dynamic_img.set_pixel(x, y, color)
