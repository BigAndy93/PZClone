class_name FurniturePiece
extends Node2D

## Immediate-mode isometric furniture box renderer.
## Each instance draws one 3D iso box via _draw() — no SubViewport bake,
## no per-frame redraw cost once built (Godot caches CanvasItem draw calls
## until queue_redraw() is called or the node moves).
##
## Position the node at the tile-snapped centre (building-local space).
## Pass dn/de as standard iso tile-step half-extents scaled by sn/se.

var _dn:     Vector2 = Vector2.ZERO
var _de:     Vector2 = Vector2.ZERO
var _h:      float   = 8.0
var _top_c:  Color   = Color.WHITE
var _side_c: Color   = Color.GRAY


func set_draw_data(dn: Vector2, de: Vector2, h: float,
		top_c: Color, side_c: Color) -> void:
	_dn    = dn
	_de    = de
	_h     = h
	_top_c = top_c
	_side_c = side_c
	queue_redraw()


func _draw() -> void:
	# Contact shadow (drawn first — sits beneath all geometry).
	var sh_col := ArtPalette.cool_shadow(ArtPalette.SHADOW_BASE, 0.65)
	sh_col.a   = 0.28
	var sh_rh  := max(5.0, _de.length() * 0.55)
	var sh_rv  := max(2.5, _dn.length() * 0.28)
	draw_colored_polygon(
		IsoShapes.ellipse_pts(Vector2(3.0, 5.0), sh_rh, sh_rv, 10), sh_col)

	# Box faces (ctr = Vector2.ZERO since piece is positioned at c in building space).
	var faces := IsoShapes.box_faces(Vector2.ZERO, _dn, _de, _h)

	# W face — lit side (NW light, baseline value).
	draw_colored_polygon(faces[0], _side_c)

	# E face — dark side (cool shadow, away from NW light).
	draw_colored_polygon(faces[1],
		ArtPalette.cool_shadow(_side_c, 0.20).darkened(0.28))

	# Top face — warm highlight.
	draw_colored_polygon(faces[2],
		ArtPalette.warm_highlight(_top_c, 0.06).lightened(0.15))

	# Outlines — crisp dark border matching exterior wall style.
	var ol_c := ArtPalette.cool_shadow(_side_c, 0.55).darkened(0.35)
	ol_c.a   = 0.85
	_draw_outline(faces[0], ol_c, 1.2)
	_draw_outline(faces[1], ol_c, 1.2)
	_draw_outline(faces[2], ol_c, 1.0)


func _draw_outline(pts: PackedVector2Array, col: Color, width: float) -> void:
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])   # close the loop
	draw_polyline(closed, col, width)
