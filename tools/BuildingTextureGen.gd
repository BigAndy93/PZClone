## BuildingTextureGen.gd
## @tool EditorScript — run from Script menu ▶ Run to generate all building PNGs.
## Outputs to res://assets/buildings/ (creates directory if missing).
##
## Usage: open this script in the Godot editor, then Script → Run.
@tool
extends EditorScript

const OUT_DIR    := "res://assets/buildings/"
const WALL_W     := 64
const WALL_H     := 32
const ROOF_W     := 64
const ROOF_H     := 32


func _run() -> void:
	var abs_dir := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)

	_gen_commercial_wall()
	_gen_industrial_wall()
	_gen_residential_large_wall()
	_gen_commercial_roof()
	_gen_industrial_roof()
	_gen_residential_large_roof()

	print("[BuildingTextureGen] All textures written to ", OUT_DIR)


# ── Commercial wall ──────────────────────────────────────────────────────────
# Horizontal alternating bands: concrete + glass window strip.
# Mullions every 16 px, 2-px pane border left/right.
func _gen_commercial_wall() -> void:
	var img := Image.create(WALL_W, WALL_H, false, Image.FORMAT_RGBA8)
	for y in WALL_H:
		var band := y / 8          # 4 bands of 8 px
		for x in WALL_W:
			if band % 2 == 0:
				# Concrete band — slight highlight at top edge
				var shade := 0.44 if y % 8 == 0 else 0.40
				img.set_pixel(x, y, Color(shade, shade + 0.06, shade + 0.12, 1.0))
			else:
				# Window strip
				var px := x % 16
				if px <= 1 or px >= 14:
					# Mullion (structural vertical)
					img.set_pixel(x, y, Color(0.26, 0.28, 0.32, 1.0))
				else:
					# Glass — tinted blue-grey, slight gradient top-to-bottom
					var t := float(y % 8) / 7.0
					img.set_pixel(x, y, Color(0.50 + t * 0.06, 0.70 + t * 0.04, 0.88 + t * 0.02, 1.0))
	img.save_png(OUT_DIR + "commercial_wall.png")


# ── Industrial wall ──────────────────────────────────────────────────────────
# Vertical corrugated metal panels (8-px stripes), horizontal seams at mid.
func _gen_industrial_wall() -> void:
	var img := Image.create(WALL_W, WALL_H, false, Image.FORMAT_RGBA8)
	for y in WALL_H:
		for x in WALL_W:
			# Horizontal seam
			if y == 0 or y == WALL_H / 2:
				img.set_pixel(x, y, Color(0.18, 0.18, 0.20, 1.0))
				continue
			# Corrugated stripe (light / dark alternating)
			var stripe := x / 8
			var base   := 0.35 if stripe % 2 == 0 else 0.27
			# Highlight at left edge of each stripe
			var edge   := 0.04 if (x % 8 == 1) else 0.0
			# Rivet dots
			var is_rivet := (x % 8 == 0 or x % 8 == 7) and (y == 6 or y == WALL_H - 7)
			if is_rivet:
				img.set_pixel(x, y, Color(0.55, 0.55, 0.60, 1.0))
			else:
				var c := base + edge
				img.set_pixel(x, y, Color(c, c, c + 0.03, 1.0))
	img.save_png(OUT_DIR + "industrial_wall.png")


# ── Large residential wall ───────────────────────────────────────────────────
# Brick pattern with one centred window.
func _gen_residential_large_wall() -> void:
	var img := Image.create(WALL_W, WALL_H, false, Image.FORMAT_RGBA8)
	for y in WALL_H:
		for x in WALL_W:
			var row    := y / 4
			var offset := (row % 2) * 8   # stagger alternate rows
			var bx     := (x + offset) % 16

			# Window region (centred 20×18 px at x=22, y=4)
			var in_win := x >= 22 and x <= 41 and y >= 4 and y <= 21
			if in_win:
				var wx := x - 22
				var wy := y - 4
				if wx == 0 or wx == 19 or wy == 0 or wy == 17:
					img.set_pixel(x, y, Color(0.28, 0.18, 0.10, 1.0))  # frame
				elif wx == 9:
					img.set_pixel(x, y, Color(0.28, 0.18, 0.10, 1.0))  # centre mullion
				else:
					# Glass — slight reflection gradient
					var gx := float(wx) / 19.0
					img.set_pixel(x, y, Color(0.52 + gx * 0.10, 0.70, 0.84, 1.0))
				continue

			# Mortar (seam)
			if bx == 0 or y % 4 == 0:
				img.set_pixel(x, y, Color(0.52, 0.50, 0.46, 1.0))
			else:
				# Brick body — subtle value variation per brick
				var brick_id := (row * 7 + (x + offset) / 16) % 4
				var shade    := 0.60 + brick_id * 0.03
				img.set_pixel(x, y, Color(shade, shade * 0.55, shade * 0.34, 1.0))
	img.save_png(OUT_DIR + "residential_large_wall.png")


# ── Commercial roof ──────────────────────────────────────────────────────────
# Flat roof: subtle 4-px checker, AC box, vent pipe.
func _gen_commercial_roof() -> void:
	var img := Image.create(ROOF_W, ROOF_H, false, Image.FORMAT_RGBA8)
	for y in ROOF_H:
		for x in ROOF_W:
			var checker := ((x / 4) + (y / 4)) % 2
			var c       := 0.35 if checker == 0 else 0.38
			img.set_pixel(x, y, Color(c, c + 0.01, c + 0.02, 1.0))

	# AC housing block (8×5 px at top-left quadrant)
	for y in range(4, 9):
		for x in range(5, 18):
			img.set_pixel(x, y, Color(0.44, 0.45, 0.48, 1.0))
	img.set_pixel(10, 4, Color(0.25, 0.25, 0.28, 1.0))  # vent cap outline
	img.set_pixel(11, 4, Color(0.25, 0.25, 0.28, 1.0))

	# Vent pipe (3 wide, 4 tall)
	for y in range(1, 5):
		for x in range(8, 11):
			img.set_pixel(x, y, Color(0.24, 0.24, 0.27, 1.0))

	img.save_png(OUT_DIR + "commercial_roof.png")


# ── Industrial roof ──────────────────────────────────────────────────────────
# Metal panels — horizontal stripes, dark seams.
func _gen_industrial_roof() -> void:
	var img := Image.create(ROOF_W, ROOF_H, false, Image.FORMAT_RGBA8)
	for y in ROOF_H:
		var panel := y / 6
		var base  := 0.36 if panel % 2 == 0 else 0.29
		var seam  := (y % 6 == 0)
		for x in ROOF_W:
			if seam:
				img.set_pixel(x, y, Color(0.18, 0.18, 0.20, 1.0))
			else:
				img.set_pixel(x, y, Color(base, base, base + 0.03, 1.0))
	img.save_png(OUT_DIR + "industrial_roof.png")


# ── Residential (large) roof ─────────────────────────────────────────────────
# Shingle rows — staggered 16-px shingles, 4-px rows.
func _gen_residential_large_roof() -> void:
	var img := Image.create(ROOF_W, ROOF_H, false, Image.FORMAT_RGBA8)
	for y in ROOF_H:
		var row    := y / 4
		var offset := (row % 2) * 8
		for x in ROOF_W:
			var sx := (x + offset) % 16
			if sx == 0 or y % 4 == 0:
				# Shingle edge / row seam
				img.set_pixel(x, y, Color(0.22, 0.12, 0.06, 1.0))
			else:
				# Shingle body — slight per-shingle hue variation
				var sid := ((row * 5 + (x + offset) / 16) % 3)
				var r   := 0.46 + sid * 0.04
				img.set_pixel(x, y, Color(r, r * 0.60, r * 0.36, 1.0))
	img.save_png(OUT_DIR + "residential_large_roof.png")
