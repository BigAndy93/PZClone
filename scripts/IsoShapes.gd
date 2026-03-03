class_name IsoShapes
## Shared isometric shape vertex generators.
##
## Use this as the single source of truth for all isometric drawing primitives.
## Both WorldProp (draw_* canvas calls) and ProceduralBuilding (Polygon2D nodes)
## consume these functions — only the rendering backend differs.
##
## ── Coordinate conventions ────────────────────────────────────────────────────
##
##   ctr     — screen-space centre of the shape
##   dn      — north half-vector  (Vector2(0, -hh*s) for WorldProp, nv*sn for buildings)
##   de      — east  half-vector  (Vector2( hw*s, 0) for WorldProp, ev*se for buildings)
##   h       — height in screen pixels (positive = upward: use Vector2(0,-h))
##
## ── WorldProp helper (tile-based) ────────────────────────────────────────────
##   dn = IsoShapes.dn_tile(hh, s)   →  Vector2(0, -hh * s)
##   de = IsoShapes.de_tile(hw, s)   →  Vector2(hw * s, 0)
##
## ── ProceduralBuilding helper (floor-relative) ────────────────────────────────
##   nv, ev  from _furn_axes()
##   dn = nv * sn,   de = ev * se
##
## ── Adding a new prop ─────────────────────────────────────────────────────────
##   1. Add PROP_* constant to MapData.gd
##   2. Add scatter logic in MapGenerator.gd (_place_props)
##   3. Add a match case in WorldProp._draw_prop() — use IsoShapes primitives
##   4. Run tools/PropPreview.tscn in the editor to preview without launching game
##
## ── Adding new furniture ──────────────────────────────────────────────────────
##   1. Add an archetype if needed (BuildingData.Archetype)
##   2. Add a _furn_<name>() function in ProceduralBuilding — use _fn / _fb helpers
##   3. Add match case in _build_furniture()


const TILE_W := 64.0
const TILE_H := 32.0


# ── WorldProp-style half-vectors (fixed tile grid) ────────────────────────────

## North half-vector for a prop at scale s. Points upward in screen space.
static func dn_tile(hh: float, s: float) -> Vector2:
	return Vector2(0.0, -hh * s)

## East half-vector for a prop at scale s. Points right in screen space.
static func de_tile(hw: float, s: float) -> Vector2:
	return Vector2(hw * s, 0.0)


# ── Flat shapes ───────────────────────────────────────────────────────────────

## Isometric rhombus (floor decal / rug / pit).
## Vertex order: N, E, S, W (top, right, bottom, left in screen space).
static func rhombus(ctr: Vector2, dn: Vector2, de: Vector2) -> PackedVector2Array:
	return PackedVector2Array([ctr + dn, ctr + de, ctr - dn, ctr - de])


# ── 3-D box ───────────────────────────────────────────────────────────────────

## Isometric box faces.
## Returns Array[PackedVector2Array] = [w_face, e_face, top_face].
## Draw order: W first (darkest), E second, top last (drawn on top).
## Matches the WorldProp _iso_box and ProceduralBuilding _fb conventions.
static func box_faces(ctr: Vector2, dn: Vector2, de: Vector2, h: float) -> Array:
	var up := Vector2(0.0, -h)
	var gN := ctr + dn
	var gE := ctr + de
	var gS := ctr - dn
	var gW := ctr - de
	return [
		PackedVector2Array([gW, gS, gS + up, gW + up]),            # W face (left / darker)
		PackedVector2Array([gE, gS, gS + up, gE + up]),            # E face (right)
		PackedVector2Array([gN + up, gE + up, gS + up, gW + up]),  # top face (elevated)
	]


## Convenience wrapper: iso box with a single side_c (auto-darkens W face).
## Returns the same [w_face, e_face, top_face] array.
static func box_faces_shaded(ctr: Vector2, dn: Vector2, de: Vector2, h: float) -> Array:
	return box_faces(ctr, dn, de, h)   # colours are caller's responsibility


# ── Approximate cylinder / pole ───────────────────────────────────────────────

## Ellipse vertex polygon (top of a cylinder or drum shape).
## r_x, r_y: screen-space radii. n: vertex count (8 is enough for small objects).
static func ellipse_pts(ctr: Vector2, r_x: float, r_y: float, n: int = 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in n:
		var a := TAU * i / float(n)
		pts.append(ctr + Vector2(cos(a) * r_x, sin(a) * r_y))
	return pts


# ── Colour helpers ────────────────────────────────────────────────────────────

## Shift all RGB channels by amt (positive = lighten, negative = darken).
## Preserves hue better than Color.lightened / darkened for muted palettes.
static func shift(col: Color, amt: float) -> Color:
	return Color(
		clampf(col.r + amt, 0.0, 1.0),
		clampf(col.g + amt, 0.0, 1.0),
		clampf(col.b + amt, 0.0, 1.0),
		col.a)
