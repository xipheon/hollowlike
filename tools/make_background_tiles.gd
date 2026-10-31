extends SceneTree
## Builds the background tile sheet (art/tiles/background.png): a dark brick
## warehouse wall drawn in code, with PixelLab pieces (windows, posters, light,
## graffiti) laid over it. Window panes stay transparent so a parallax layer
## behind shows through. Also writes a preview room. Run from the project folder:
##   godot --headless --path . --script res://tools/make_background_tiles.gd
##
## Every tile has wall behind it, so a background cell is always one tile.
## Brick colours don't depend on the variant, so any wall tiles sit side by side.

const TILE := 32
const SRC := "res://art/tiles/source/"
const SHEET_PATH := "res://art/tiles/background.png"
const SHEET_SIZE := Vector2i(8, 4)  # in tiles
const PREVIEW_PATH := "res://art/tiles/source/background_preview.png"
const PREVIEW_SCALE := 2
const SKYLINE_PATH := "res://art/backgrounds/skyline.png"
const SKYLINE_PREVIEW_Y := 115

const BRICK := Vector2i(16, 8)
# Dark and low-contrast, so the wall stays behind the gameplay.
const MORTAR := Color8(29, 26, 27)
const BRICKS := [Color8(45, 35, 34), Color8(49, 38, 36), Color8(42, 33, 32), Color8(47, 37, 34)]
const BRICK_LIGHT := 1.06  # top edge of each brick
const BRICK_DARK := 0.9    # bottom edge
const SPECKLE_DARK := 0.08
const SPECKLE_LIGHT := 0.04
const GRIME := 0.12        # how much darker grime makes a pixel
const STAIN := Color8(38, 40, 28)
const SOOT := Color8(22, 20, 22)
const STRIPE_YELLOW := Color8(196, 160, 40)
const STRIPE_BLACK := Color8(28, 26, 26)
const PIPE := [Color8(54, 58, 62), Color8(86, 92, 96), Color8(122, 128, 130), Color8(70, 76, 80), Color8(40, 42, 46)]
const RUST := Color8(120, 62, 30)
const STEEL := [Color8(36, 40, 46), Color8(58, 64, 72), Color8(84, 92, 100)]

# Generated pieces: [file, top-left cell, size in tiles, optional part of the
# file to use]. A part is trimmed to its pixels and centred across the cell.
# Missing files are skipped.
const PIECES := [
	["window_2x2_raw.png", Vector2i(0, 1), Vector2i(2, 2)],
	["window_3x2_raw.png", Vector2i(2, 1), Vector2i(3, 2)],
	["posters_raw.png", Vector2i(5, 1), Vector2i(2, 1)],
	["light_raw.png", Vector2i(7, 1), Vector2i(1, 1), Rect2i(16, 0, 16, 32)],  # lit bulb
	["light_raw.png", Vector2i(7, 2), Vector2i(1, 1), Rect2i(0, 0, 16, 32)],   # dead bulb
	["graffiti_raw.png", Vector2i(5, 2), Vector2i(2, 1)],
]
const JUNCTION_CELL := Vector2i(0, 3)

# Sample wall for the preview. Letters are sheet cells, see LEGEND.
const PREVIEW_ROWS := [
	"aaVacavaabaVavag",
	"abWXabLMNbaWXbag",
	"baYZbalmnaaYZbag",
	"hhhhhhhhhhhhhhhg",
	"abaPQcababTtabag",
	"bcabbadaaba|bcag",
	"-----------+---g",
	"aabadabacab|abag",
]
const LEGEND := {
	"a": Vector2i(0, 0), "b": Vector2i(1, 0), "c": Vector2i(2, 0), "d": Vector2i(3, 0),
	"h": Vector2i(4, 0), "-": Vector2i(5, 0), "|": Vector2i(6, 0), "g": Vector2i(7, 0),
	"W": Vector2i(0, 1), "X": Vector2i(1, 1), "Y": Vector2i(0, 2), "Z": Vector2i(1, 2),
	"L": Vector2i(2, 1), "M": Vector2i(3, 1), "N": Vector2i(4, 1),
	"l": Vector2i(2, 2), "m": Vector2i(3, 2), "n": Vector2i(4, 2),
	"P": Vector2i(5, 1), "Q": Vector2i(6, 1), "V": Vector2i(7, 1), "v": Vector2i(7, 2),
	"T": Vector2i(5, 2), "t": Vector2i(6, 2), "+": JUNCTION_CELL,
}


func _init() -> void:
	var sheet := Image.create(SHEET_SIZE.x * TILE, SHEET_SIZE.y * TILE, false, Image.FORMAT_RGBA8)
	# Plain wall everywhere first, so every piece has brick behind it.
	for cy in SHEET_SIZE.y:
		for cx in SHEET_SIZE.x:
			_wall(sheet, Vector2i(cx, cy) * TILE)
	_stain(sheet, Vector2i(2, 0) * TILE)
	_damage(sheet, Vector2i(3, 0) * TILE)
	_stripes(sheet, Vector2i(4, 0) * TILE)
	_pipe(sheet, Vector2i(5, 0) * TILE, false)
	_pipe(sheet, Vector2i(6, 0) * TILE, true)
	_girder(sheet, Vector2i(7, 0) * TILE)
	_pipe(sheet, JUNCTION_CELL * TILE, false)
	_pipe(sheet, JUNCTION_CELL * TILE, true)
	_fitting(sheet, JUNCTION_CELL * TILE)
	for p in PIECES:
		var path: String = SRC + p[0]
		if not FileAccess.file_exists(path):
			continue
		var piece := Image.load_from_file(ProjectSettings.globalize_path(path))
		if p.size() > 3:
			piece = _trim_sides(piece.get_region(p[3]))
		_place(sheet, piece, p[1] * TILE, p[2] * TILE)
	sheet.save_png(ProjectSettings.globalize_path(SHEET_PATH))
	_save_preview(sheet)
	print("Wrote %s and %s" % [SHEET_PATH, PREVIEW_PATH])
	quit()


func _noise(x: int, y: int, salt: int) -> float:
	return float(absi(hash(Vector3i(x, y, salt))) % 1000) / 1000.0


## Running-bond brick. Positions are wrapped to the tile, so bricks that cross a
## tile edge get the same colour on both sides.
func _wall(img: Image, o: Vector2i) -> void:
	for y in TILE:
		var row := y / BRICK.y
		var shift := (BRICK.x / 2) * (row % 2)
		var by := y % BRICK.y
		for x in TILE:
			var bx := (x + shift) % BRICK.x
			var c := MORTAR
			if by != BRICK.y - 1 and bx != BRICK.x - 1:
				var id := posmod((x + shift) / BRICK.x, TILE / BRICK.x)
				c = BRICKS[int(_noise(id, row, 1) * BRICKS.size())]
				if by == 0:
					c = c * BRICK_LIGHT
				elif by == BRICK.y - 2:
					c = c * BRICK_DARK
				var n := _noise(x, y, 2)
				if n > 0.9:
					c = c.darkened(SPECKLE_DARK)
				elif n < 0.05:
					c = c.lightened(SPECKLE_LIGHT)
			# Grime gathers lower down the tile.
			if _noise(x, y, 3) < float(y) / TILE * 0.18:
				c = c.darkened(GRIME)
			img.set_pixel(o.x + x, o.y + y, Color(c, 1.0))


## A water stain running down from a leak, kept away from the tile edges.
func _stain(img: Image, o: Vector2i) -> void:
	for y in range(2, TILE - 2):
		var half := 3 + y / 5
		for x in range(16 - half, 16 + half):
			var edge := absi(x - 16) / float(half)
			if _noise(x, y, 4) > edge * 0.9 + 0.1:
				var c := img.get_pixel(o.x + x, o.y + y)
				img.set_pixel(o.x + x, o.y + y, c.lerp(STAIN, 0.45))


## A couple of bricks knocked out, showing the dark cavity behind, with soot.
func _damage(img: Image, o: Vector2i) -> void:
	var holes := [Rect2i(4, 9, 15, 7), Rect2i(12, 17, 15, 7)]
	for r in holes:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var top: bool = y == r.position.y
				img.set_pixel(o.x + x, o.y + y, SOOT.lightened(0.05) if top else SOOT)
	for y in range(4, 28):
		for x in range(2, 30):
			if _noise(x, y, 5) < 0.12 and img.get_pixel(o.x + x, o.y + y) != SOOT:
				img.set_pixel(o.x + x, o.y + y, img.get_pixel(o.x + x, o.y + y).darkened(0.3))


## A chipped hazard-stripe band painted across the wall. Period 8, so it tiles.
func _stripes(img: Image, o: Vector2i) -> void:
	for y in range(12, 20):
		for x in TILE:
			if _noise(x, y, 6) < 0.12:
				continue  # paint chipped off
			var c := STRIPE_YELLOW if posmod(x + y, 8) < 4 else STRIPE_BLACK
			if y == 12 or y == 19:
				c = c.darkened(0.2)
			img.set_pixel(o.x + x, o.y + y, c)


## An 8px rusty pipe across (or down) the tile, with a flange in the middle.
func _pipe(img: Image, o: Vector2i, vertical: bool) -> void:
	for a in TILE:
		var flange := a >= 14 and a <= 17
		var lo := 11 if flange else 12
		var hi := 21 if flange else 20
		for b in range(lo, hi):
			var shade := clampi(int((b - lo) * PIPE.size() / float(hi - lo)), 0, PIPE.size() - 1)
			var c: Color = PIPE[shade]
			if flange:
				c = c.lightened(0.1) if a == 14 else c.darkened(0.1)
			if _noise(a, b, 7 + int(vertical)) < 0.1:
				c = RUST
			var p := Vector2i(b, a) if vertical else Vector2i(a, b)
			img.set_pixel(o.x + p.x, o.y + p.y, c)
	# Shadow on the wall below or right of the pipe.
	for a in TILE:
		var p := Vector2i(20, a) if vertical else Vector2i(a, 20)
		img.set_pixel(o.x + p.x, o.y + p.y, img.get_pixel(o.x + p.x, o.y + p.y).darkened(0.4))


## The cross fitting where a horizontal and a vertical pipe meet: a square
## collar over both, with a bolt in each corner.
func _fitting(img: Image, o: Vector2i) -> void:
	var lo := 10
	var hi := 22
	for y in range(lo, hi):
		for x in range(lo, hi):
			var c: Color = PIPE[2]
			if x == lo or y == lo:
				c = PIPE[2].lightened(0.15)
			elif x == hi - 1 or y == hi - 1:
				c = PIPE[4]
			elif x == lo + 1 or y == lo + 1 or x == hi - 2 or y == hi - 2:
				c = PIPE[1]
			if (x == lo + 2 or x == hi - 3) and (y == lo + 2 or y == hi - 3):
				c = PIPE[4]  # bolts
			if _noise(x, y, 10) < 0.08:
				c = RUST
			img.set_pixel(o.x + x, o.y + y, c)
	# Shadow down and right of the collar.
	for a in range(lo + 1, hi + 1):
		img.set_pixel(o.x + hi, o.y + a, img.get_pixel(o.x + hi, o.y + a).darkened(0.4))
		img.set_pixel(o.x + a, o.y + hi, img.get_pixel(o.x + a, o.y + hi).darkened(0.4))


## Crops away empty columns on either side, keeping the full height so a
## hanging piece still reaches the top of its tile.
func _trim_sides(piece: Image) -> Image:
	piece.convert(Image.FORMAT_RGBA8)
	var used := piece.get_used_rect()
	return piece.get_region(Rect2i(used.position.x, 0, used.size.x, piece.get_height()))


## A steel I-beam column, tiling vertically, with a rivet plate every 16 px.
func _girder(img: Image, o: Vector2i) -> void:
	for y in TILE:
		for x in range(6, 26):
			var flange := x < 10 or x >= 22
			var c: Color = STEEL[1] if flange else STEEL[0]
			if x == 6 or x == 22:
				c = STEEL[2]
			if x == 9 or x == 25:
				c = STEEL[0].darkened(0.3)
			if not flange and (y % 16 == 3 or y % 16 == 4) and (x == 13 or x == 18):
				c = STEEL[2]  # rivets
			if _noise(x, y, 9) < 0.08:
				c = RUST.darkened(0.2)
			img.set_pixel(o.x + x, o.y + y, c)
	for y in TILE:
		img.set_pixel(o.x + 26, o.y + y, img.get_pixel(o.x + 26, o.y + y).darkened(0.4))


## Lays a generated piece, centred, over the wall. For windows, transparent
## pixels enclosed by the frame (the panes) are cut out of the wall too.
func _place(img: Image, piece: Image, o: Vector2i, area: Vector2i) -> void:
	piece.convert(Image.FORMAT_RGBA8)
	var off := o + (area - piece.get_size()) / 2
	var outside := _outside(piece)
	for y in piece.get_height():
		for x in piece.get_width():
			var p := Vector2i(x, y)
			var c := piece.get_pixelv(p)
			var at := off + p
			if not Rect2i(o, area).has_point(at):
				continue
			if c.a > 0.5:
				img.set_pixelv(at, Color(c, 1.0))
			elif not outside.has(p):
				img.set_pixelv(at, Color(0, 0, 0, 0))


## Transparent pixels reachable from the piece's border.
func _outside(piece: Image) -> Dictionary:
	var size := piece.get_size()
	var seen := {}
	var stack: Array[Vector2i] = []
	for x in size.x:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, size.y - 1))
	for y in size.y:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(size.x - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if seen.has(p) or not Rect2i(Vector2i.ZERO, size).has_point(p) or piece.get_pixelv(p).a > 0.5:
			continue
		seen[p] = true
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			stack.append(p + d)
	return seen


func _save_preview(sheet: Image) -> void:
	var rows := PREVIEW_ROWS.size()
	var cols: int = PREVIEW_ROWS[0].length()
	var img := Image.create(cols * TILE, rows * TILE, false, Image.FORMAT_RGBA8)
	# The far background behind: the skyline if it's been made, else a night-sky gradient.
	if FileAccess.file_exists(SKYLINE_PATH):
		var sky := Image.load_from_file(ProjectSettings.globalize_path(SKYLINE_PATH))
		sky.convert(Image.FORMAT_RGBA8)
		# Lined up so the top windows look out on the towers and the glow.
		img.fill(sky.get_pixel(0, sky.get_height() - 1))
		img.blit_rect(sky, Rect2i(Vector2i(0, SKYLINE_PREVIEW_Y), img.get_size()), Vector2i.ZERO)
	else:
		for y in img.get_height():
			var t := float(y) / img.get_height()
			img.fill_rect(Rect2i(0, y, img.get_width(), 1), Color8(20, 18, 48).lerp(Color8(120, 60, 90), t))
	for y in rows:
		for x in cols:
			var cell: Vector2i = LEGEND[PREVIEW_ROWS[y][x]]
			img.blend_rect(sheet, Rect2i(cell * TILE, Vector2i(TILE, TILE)), Vector2i(x, y) * TILE)
	img.resize(img.get_width() * PREVIEW_SCALE, img.get_height() * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(PREVIEW_PATH))
