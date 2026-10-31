extends SceneTree
## Draws the sewer-water hazard tiles (ACID TOP 1-4 and ACID FILL 1-4 on the
## tile sheet) and a preview. The colours come from a PixelLab surface tile;
## drawing the rest in code keeps the tiles seamless and the 4 frames looping.
## Run from the project folder:
##   godot --headless --path . --script res://tools/make_sewer_tiles.gd

const TILE := 32
const FRAMES := 4
const SURFACE_Y := 8          # the liquid starts this far down the top tile (see SHEETS.md)
const SCROLL := TILE / FRAMES # the surface moves this far each frame, so frame 4 wraps to frame 1
const SHEET_PATH := "res://art/tiles/tileset.png"
const SHEET_SIZE := Vector2i(256, 224)
const TOP_CELL := Vector2i(0, 5)  # ACID TOP 1; the other frames follow to the right
const FILL_CELL := Vector2i(4, 5) # ACID FILL 1
const PREVIEW_PATH := "res://art/tiles/source/sewer_preview.png"
const PREVIEW_SCALE := 4

const FOAM := Color8(234, 251, 183)
const FOAM_WHITE := Color8(250, 246, 252)
const FOAM_DARK := Color8(147, 178, 0)
const SCUM := Color8(103, 125, 3)
const SHEEN := [Color8(157, 121, 240), Color8(130, 108, 239), Color8(231, 209, 9), Color8(187, 245, 252)]
# Water body, lightest (just under the surface) to darkest (deep).
const BODY := [Color8(89, 90, 0), Color8(76, 73, 0), Color8(60, 52, 1), Color8(45, 42, 16)]
const DEEP_SPECK := Color8(38, 26, 3)
const GLOW := [Color8(45, 42, 16), Color8(80, 120, 10), Color8(133, 231, 0), Color8(80, 120, 10)]


func _init() -> void:
	var sheet: Image = null
	if FileAccess.file_exists(SHEET_PATH):
		sheet = Image.load_from_file(ProjectSettings.globalize_path(SHEET_PATH))
	if sheet == null:
		sheet = Image.create(SHEET_SIZE.x, SHEET_SIZE.y, false, Image.FORMAT_RGBA8)
	sheet.convert(Image.FORMAT_RGBA8)

	var tops: Array[Image] = []
	var fills: Array[Image] = []
	for f in FRAMES:
		tops.append(_top(f))
		fills.append(_fill(f))
		_put(sheet, tops[f], TOP_CELL + Vector2i(f, 0))
		_put(sheet, fills[f], FILL_CELL + Vector2i(f, 0))
	sheet.save_png(ProjectSettings.globalize_path(SHEET_PATH))
	_save_preview(tops, fills)
	print("Wrote sewer tiles to %s and preview to %s" % [SHEET_PATH, PREVIEW_PATH])
	quit()


func _put(sheet: Image, tile: Image, cell: Vector2i) -> void:
	sheet.fill_rect(Rect2i(cell * TILE, Vector2i(TILE, TILE)), Color(0, 0, 0, 0))
	sheet.blit_rect(tile, Rect2i(0, 0, TILE, TILE), cell * TILE)


## Repeatable noise in 0..1, wrapped to the tile so neighbours join.
func _noise(x: int, y: int, salt: int) -> float:
	var h := hash(Vector3i(posmod(x, TILE), posmod(y, TILE), salt))
	return float(absi(h) % 1000) / 1000.0


## Water below the surface: banded by depth, dithered, with flickering glow specks.
func _body(x: int, y: int, f: int) -> Color:
	var n := _noise(x, y, 1)
	var band := clampi(int(y / 8.0 + n * 0.9 - 0.45), 0, BODY.size() - 1)
	var c: Color = BODY[band]
	if n > 0.97:
		c = DEEP_SPECK
	var g := _noise(x, y, 2)
	if g > 0.985:
		c = GLOW[(int(g * 1000) + f) % FRAMES]
	return c


func _top(f: int) -> Image:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	for x in TILE:
		# Everything on the surface reads from u, so the whole surface scrolls left.
		var u := posmod(x + f * SCROLL, TILE)
		var wave := int(round(sin(u * TAU * 2.0 / TILE)))  # two ripples per tile, +-1 px
		var surface := SURFACE_Y + wave
		for y in range(surface, TILE):
			var depth := y - surface
			var c: Color
			if depth == 0:
				c = FOAM_WHITE if _noise(u, 0, 3) > 0.7 else FOAM
			elif depth == 1:
				var s := _noise(u, 0, 4)
				c = SHEEN[int(s * 100) % SHEEN.size()] if s > 0.6 else FOAM_DARK
			elif depth == 2:
				c = SCUM if _noise(u, 0, 5) > 0.35 else BODY[0]
			else:
				c = _body(x, y, f)
			img.set_pixel(x, y, c)
	return img


func _fill(f: int) -> Image:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	for y in TILE:
		for x in TILE:
			# Same as the deepest band of the top tile, so the two meet without a line.
			var n := _noise(x, y, 6)
			var c: Color = BODY[3]
			if n > 0.93:
				c = DEEP_SPECK
			elif n < 0.06:
				c = BODY[2]
			var g := _noise(x, y, 7)
			if g > 0.988:
				c = GLOW[(int(g * 1000) + f) % FRAMES]
			img.set_pixel(x, y, c)
	return img


## Each frame as a 4x3 patch (surface row over two fill rows), side by side.
func _save_preview(tops: Array[Image], fills: Array[Image]) -> void:
	var patch := Vector2i(4, 3)
	var gap := 8
	var img := Image.create(FRAMES * (patch.x * TILE + gap), patch.y * TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color8(40, 44, 52))
	for f in FRAMES:
		var ox := f * (patch.x * TILE + gap)
		for x in patch.x:
			img.blend_rect(tops[f], Rect2i(0, 0, TILE, TILE), Vector2i(ox + x * TILE, 0))
			for y in range(1, patch.y):
				img.blend_rect(fills[f], Rect2i(0, 0, TILE, TILE), Vector2i(ox + x * TILE, y * TILE))
	img.resize(img.get_width() * PREVIEW_SCALE, img.get_height() * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(PREVIEW_PATH))
