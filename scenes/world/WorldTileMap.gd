class_name WorldTileMap
extends Node2D

const TILE_W: float = 64.0
const TILE_H: float = 32.0

# Ground tile colours — index matches MapData.TILE_* constants.
# Sourced from ArtPalette (art bible §2.1 palette discipline).
static var TILE_COLORS: Array[Color] = [
	ArtPalette.TILE_GRASS,    # GRASS
	ArtPalette.TILE_ROAD,     # ROAD
	ArtPalette.TILE_DIRT,     # DIRT
	ArtPalette.TILE_FLOOR,    # FLOOR
	ArtPalette.TILE_PAVEMENT, # PAVEMENT (industrial concrete — cool grey)
]

var _map_data: MapData = null


func setup_from_map_data(data: MapData) -> void:
	_map_data = data
	queue_redraw()


## Isometric diamond-down conversion: cell → local 2D position (tile centre).
func map_to_local(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x - cell.y) * TILE_W * 0.5,
		(cell.x + cell.y) * TILE_H * 0.5
	)


## Inverse: local 2D position → nearest tile cell.
func local_to_map(local_pos: Vector2) -> Vector2i:
	var fx := local_pos.x / (TILE_W * 0.5)
	var fy := local_pos.y / (TILE_H * 0.5)
	return Vector2i(int(round((fx + fy) * 0.5)), int(round((fy - fx) * 0.5)))


## Draw a diamond-footprint isometric box centred at `ctr`.
func _draw_iso_box(ctr: Vector2, s: float, h: float,
				   top_c: Color, left_c: Color, right_c: Color,
				   hw: float, hh: float) -> void:
	var gN := ctr + Vector2(  0.0,  -hh * s)
	var gE := ctr + Vector2( hw * s,   0.0)
	var gS := ctr + Vector2(  0.0,   hh * s)
	var gW := ctr + Vector2(-hw * s,   0.0)
	var up  := Vector2(0.0, -h)
	draw_colored_polygon(PackedVector2Array([gW, gS, gS + up, gW + up]), left_c)
	draw_colored_polygon(PackedVector2Array([gE, gS, gS + up, gE + up]), right_c)
	draw_colored_polygon(PackedVector2Array([gN + up, gE + up, gS + up, gW + up]), top_c)


func _draw() -> void:
	if _map_data == null:
		return
	var hw := TILE_W * 0.5
	var hh := TILE_H * 0.5

	# Pass 1 — ground terrain tiles with per-vertex gradient and seeded variation.
	for ty in _map_data.map_height:
		for tx in _map_data.map_width:
			var cell  := Vector2i(tx, ty) + _map_data.origin_offset
			var ctr   := map_to_local(cell)
			var t_idx := _map_data.get_tile(tx, ty)
			var base_col: Color = TILE_COLORS[clampi(t_idx, 0, TILE_COLORS.size() - 1)]

			# Seeded per-tile hue variation (±4%) — prevents uniform carpet look.
			var tile_seed := tx * 7919 + ty * 1009
			base_col = ArtPalette.vary(base_col, tile_seed, 0.04)

			# Per-vertex gradient: top lit, bottom cooled and darkened.
			var verts := PackedVector2Array([
				ctr + Vector2(  0.0,  -hh),
				ctr + Vector2(  hw,    0.0),
				ctr + Vector2(  0.0,   hh),
				ctr + Vector2( -hw,    0.0),
			])
			draw_polygon(verts, ArtPalette.tile_gradient(base_col))

	# Pass 1.5 — road centre-line dashes.
	var stride  := MapGenerator.ZONE_STRIDE
	var zsize   := MapGenerator.ZONE_SIZE
	# Art bible: bone-white at low alpha for worn markings.
	var dash_color := Color(ArtPalette.BONE_WHITE.r, ArtPalette.BONE_WHITE.g,
							ArtPalette.BONE_WHITE.b, 0.22)
	var dash_hw    := hw * 0.12
	var dash_hh    := hh * 0.12
	for ty in _map_data.map_height:
		for tx in _map_data.map_width:
			var rx := tx % stride
			var ry := ty % stride
			var in_vroad := rx >= zsize
			var in_hroad := ry >= zsize
			if not (in_vroad or in_hroad):
				continue
			if in_vroad and in_hroad:
				continue
			var cell := Vector2i(tx, ty) + _map_data.origin_offset
			var ctr  := map_to_local(cell)
			var dash_period := false
			if in_hroad:
				dash_period = (tx % 3 == 1) and (ry == zsize)
			else:
				dash_period = (ty % 3 == 1) and (rx == zsize)
			if dash_period:
				draw_colored_polygon(PackedVector2Array([
					ctr + Vector2(  0.0,     -dash_hh),
					ctr + Vector2( dash_hw,   0.0),
					ctr + Vector2(  0.0,      dash_hh),
					ctr + Vector2(-dash_hw,   0.0),
				]), dash_color)
			# Alternate faded secondary mark (every 5 tiles — subtle road texture)
			elif in_hroad and (tx % 5 == 3) and (ry == zsize):
				var faded := Color(dash_color.r, dash_color.g, dash_color.b, 0.10)
				draw_colored_polygon(PackedVector2Array([
					ctr + Vector2(  0.0,     -dash_hh * 0.7),
					ctr + Vector2( dash_hw * 0.7,   0.0),
					ctr + Vector2(  0.0,      dash_hh * 0.7),
					ctr + Vector2(-dash_hw * 0.7,   0.0),
				]), faded)
			elif (not in_hroad) and (ty % 5 == 3) and (rx == zsize):
				var faded := Color(dash_color.r, dash_color.g, dash_color.b, 0.10)
				draw_colored_polygon(PackedVector2Array([
					ctr + Vector2(  0.0,     -dash_hh * 0.7),
					ctr + Vector2( dash_hw * 0.7,   0.0),
					ctr + Vector2(  0.0,      dash_hh * 0.7),
					ctr + Vector2(-dash_hw * 0.7,   0.0),
				]), faded)

	# Pass 2 — foliage omitted: individual WorldFoliage nodes live in Entities
	# and are y-sorted together with players/zombies for correct depth.

	# Pass 3 — props omitted: individual WorldProp nodes live in Entities
	# and are y-sorted together with players/zombies for correct depth.
