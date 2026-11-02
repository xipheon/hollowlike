extends SceneTree
## Builds the background tile sheet (art/tiles/background.png): a dark brick
## warehouse wall drawn in code (plain, stained, knocked-through, and crumbled
## edges), with PixelLab windows laid over it. Window panes stay transparent so
## a parallax layer behind shows through. Things on the wall (lights, posters,
## graffiti, pipes, girders) are on the Props layer's sheets instead
## (tools/make_prop_tiles.gd, tools/make_pipe_tiles.gd); their old cells here
## are left empty. Also writes a preview room, with the props over the wall.
## Run from the project folder:
##   godot --headless --path . --script res://tools/make_background_tiles.gd
##
## Every tile has wall behind it, so a background cell is always one tile.
## Rerunning it redraws the crumbled edges a little differently from the sheet
## in the project (Godot's hash() has changed since it was drawn); the rest
## comes out the same.
## Brick colours don't depend on the variant, so any wall tiles sit side by side.

const TILE := 32
const SRC := "res://art/tiles/source/"
const SHEET_PATH := "res://art/tiles/background.png"
const SHEET_SIZE := Vector2i(8, 6)  # in tiles
const PREVIEW_PATH := "res://art/tiles/source/background_preview.png"
const PREVIEW_SCALE := 2
const SKYLINE_PATH := "res://art/backgrounds/skyline.png"
const SKYLINE_PREVIEW_Y := 115
const PROPS_SHEET := "res://art/tiles/props.png"
const PIPES_SHEET := "res://art/tiles/pipes.png"

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
# Generated pieces: [file, top-left cell, size in tiles], each centred across
# its cells. Missing files are skipped.
const PIECES := [
	["window_2x2_raw.png", Vector2i(0, 1), Vector2i(2, 2)],
	["window_3x2_raw.png", Vector2i(2, 1), Vector2i(3, 2)],
]
## Cells that held props before they moved to the Props layer's sheets: empty.
const EMPTY_CELLS := [
	Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0),
	Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1), Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2),
	Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
	Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3),
]
# Broken wall edges around a hole knocked through the wall: 16 tiles in rows
# 4-5, one per set of open sides. Tile n has bit 1 = N open, 2 = E, 4 = S,
# 8 = W, and sits at (n % 8, 4 + n / 8).
const EDGE_ORIGIN := Vector2i(0, 4)
const EDGE_DEPTH := Vector2i(1, 9)  # how far a broken edge bites in, min/max px
const EDGE_CHUNK := 4               # edge pixels per bite

# Sample wall for the preview. Letters are sheet cells, see LEGEND: a cell
# of this sheet, or [props or pipes sheet, cell] laid over plain brick.
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
	"W": Vector2i(0, 1), "X": Vector2i(1, 1), "Y": Vector2i(0, 2), "Z": Vector2i(1, 2),
	"L": Vector2i(2, 1), "M": Vector2i(3, 1), "N": Vector2i(4, 1),
	"l": Vector2i(2, 2), "m": Vector2i(3, 2), "n": Vector2i(4, 2),
	"h": [PROPS_SHEET, RoomArt.HAZARD], "g": [PROPS_SHEET, RoomArt.GIRDER],
	"P": [PROPS_SHEET, RoomArt.POSTERS[0]], "Q": [PROPS_SHEET, RoomArt.POSTERS[0] + Vector2i(1, 0)],
	"T": [PROPS_SHEET, RoomArt.GRAFFITI[0]], "t": [PROPS_SHEET, RoomArt.GRAFFITI[0] + Vector2i(1, 0)],
	"V": [PROPS_SHEET, RoomArt.LIGHT_LIT], "v": [PROPS_SHEET, RoomArt.LIGHT_DEAD],
	"-": [PIPES_SHEET, RoomArt.PIPE_H], "|": [PIPES_SHEET, RoomArt.PIPE_V], "+": [PIPES_SHEET, RoomArt.PIPE_JUNCTION],
}


func _init() -> void:
	var sheet := Image.create(SHEET_SIZE.x * TILE, SHEET_SIZE.y * TILE, false, Image.FORMAT_RGBA8)
	# Plain wall everywhere first, so every piece has brick behind it.
	for cy in SHEET_SIZE.y:
		for cx in SHEET_SIZE.x:
			_wall(sheet, Vector2i(cx, cy) * TILE)
	_stain(sheet, Vector2i(2, 0) * TILE)
	_damage(sheet, Vector2i(3, 0) * TILE)
	for n in 16:
		_broken_edges(sheet, (EDGE_ORIGIN + Vector2i(n % 8, n / 8)) * TILE, n)
	for p in PIECES:
		var path: String = SRC + p[0]
		if not FileAccess.file_exists(path):
			continue
		var piece := Image.load_from_file(ProjectSettings.globalize_path(path))
		_place(sheet, piece, p[1] * TILE, p[2] * TILE)
	for cell in EMPTY_CELLS:
		sheet.fill_rect(Rect2i(cell * TILE, Vector2i(TILE, TILE)), Color(0, 0, 0, 0))
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





## Knocks ragged bites out of the wall along each open side in `open_sides`
## (bits: 1 N, 2 E, 4 S, 8 W), with a dark broken face just inside the bite.
func _broken_edges(img: Image, o: Vector2i, open_sides: int) -> void:
	for y in TILE:
		for x in TILE:
			var bite := 0     # how far inside the nearest broken edge this pixel is (<0 = gone)
			var nearest := TILE
			for side in 4:
				if open_sides & (1 << side) == 0:
					continue
				# [distance from that side, position along it]
				var d: Array = [[y, x], [TILE - 1 - x, y], [TILE - 1 - y, x], [x, y]][side]
				var depth := EDGE_DEPTH.x + int(_noise(d[1] / EDGE_CHUNK, side, 11) * (EDGE_DEPTH.y - EDGE_DEPTH.x + 1))
				nearest = mini(nearest, d[0] - depth)
			bite = nearest
			var at := o + Vector2i(x, y)
			if bite < 0 or (bite == 0 and _noise(x, y, 12) < 0.35):
				img.set_pixelv(at, Color(0, 0, 0, 0))
			elif bite <= 1:
				img.set_pixelv(at, SOOT)
			elif bite == 2:
				img.set_pixelv(at, img.get_pixelv(at).darkened(0.3))




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
	var sheets := {}
	for path in [PROPS_SHEET, PIPES_SHEET]:
		if FileAccess.file_exists(path):
			sheets[path] = Image.load_from_file(ProjectSettings.globalize_path(path))
			sheets[path].convert(Image.FORMAT_RGBA8)
	for y in rows:
		for x in cols:
			var at := Vector2i(x, y) * TILE
			var entry = LEGEND[PREVIEW_ROWS[y][x]]
			if entry is Vector2i:
				img.blend_rect(sheet, Rect2i(entry * TILE, Vector2i(TILE, TILE)), at)
			else:
				img.blend_rect(sheet, Rect2i(RoomArt.WALLS[0] * TILE, Vector2i(TILE, TILE)), at)
				if sheets.has(entry[0]):
					img.blend_rect(sheets[entry[0]], Rect2i(entry[1] * TILE, Vector2i(TILE, TILE)), at)
	img.resize(img.get_width() * PREVIEW_SCALE, img.get_height() * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(PREVIEW_PATH))
