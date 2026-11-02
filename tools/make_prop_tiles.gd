extends SceneTree
## Builds the props tile sheet (art/tiles/props.png): one-off things on the
## wall, with nothing behind them, painted on a room's Props layer over the
## brick of its Background layer. Pipes have their own sheet
## (tools/make_pipe_tiles.gd). A prop's shadow on the wall is translucent
## black, so over brick it looks as it did drawn onto the brick. Run from the
## project folder, then tools/make_tilesets.gd:
##   godot --headless --path . --script res://tools/make_prop_tiles.gd

const TILE := 32
const SRC := "res://art/tiles/source/"
const SHEET_PATH := "res://art/tiles/props.png"
const SHEET_SIZE := Vector2i(8, 1)  # in tiles

const SHADOW := Color(0, 0, 0, 0.4)   # the same as darkening the wall by 0.4
const STRIPE_YELLOW := Color8(196, 160, 40)
const STRIPE_BLACK := Color8(28, 26, 26)
const RUST := Color8(120, 62, 30)
const STEEL := [Color8(36, 40, 46), Color8(58, 64, 72), Color8(84, 92, 100)]

# Generated pieces: [file, top-left cell, size in tiles, optional part of the
# file to use]. A part is trimmed to its pixels and centred across the cell.
# The cells match RoomArt's props constants.
const PIECES := [
	["posters_raw.png", Vector2i(0, 0), Vector2i(2, 1)],
	["graffiti_raw.png", Vector2i(2, 0), Vector2i(2, 1)],
	["light_raw.png", Vector2i(5, 0), Vector2i(1, 1), Rect2i(16, 0, 16, 32)],  # lit bulb
	["light_raw.png", Vector2i(6, 0), Vector2i(1, 1), Rect2i(0, 0, 16, 32)],   # dead bulb
]
const HAZARD_CELL := Vector2i(4, 0)
const GIRDER_CELL := Vector2i(7, 0)


func _init() -> void:
	var sheet := Image.create(SHEET_SIZE.x * TILE, SHEET_SIZE.y * TILE, false, Image.FORMAT_RGBA8)
	for p in PIECES:
		var piece := Image.load_from_file(ProjectSettings.globalize_path(SRC + p[0]))
		if p.size() > 3:
			piece = _trim_sides(piece.get_region(p[3]))
		_place(sheet, piece, p[1] * TILE, p[2] * TILE)
	_stripes(sheet, HAZARD_CELL * TILE)
	_girder(sheet, GIRDER_CELL * TILE)
	sheet.save_png(ProjectSettings.globalize_path(SHEET_PATH))
	print("Wrote %s" % SHEET_PATH)
	quit()


func _noise(x: int, y: int, salt: int) -> float:
	return float(absi(hash(Vector3i(x, y, salt))) % 1000) / 1000.0


## Lays a piece, centred, on the transparent sheet: its solid pixels, fully
## opaque, and nothing else.
func _place(img: Image, piece: Image, o: Vector2i, area: Vector2i) -> void:
	piece.convert(Image.FORMAT_RGBA8)
	var off := o + (area - piece.get_size()) / 2
	for y in piece.get_height():
		for x in piece.get_width():
			var c := piece.get_pixel(x, y)
			var at := off + Vector2i(x, y)
			if c.a > 0.5 and Rect2i(o, area).has_point(at):
				img.set_pixelv(at, Color(c, 1.0))


## Crops away empty columns on either side, keeping the full height so a
## hanging piece still reaches the top of its tile.
func _trim_sides(piece: Image) -> Image:
	piece.convert(Image.FORMAT_RGBA8)
	var used := piece.get_used_rect()
	return piece.get_region(Rect2i(used.position.x, 0, used.size.x, piece.get_height()))


## A chipped hazard-stripe band painted across the wall. Period 8, so it tiles.
func _stripes(img: Image, o: Vector2i) -> void:
	for y in range(12, 20):
		for x in TILE:
			if _noise(x, y, 6) < 0.12:
				continue  # paint chipped off: the wall shows
			var c := STRIPE_YELLOW if posmod(x + y, 8) < 4 else STRIPE_BLACK
			if y == 12 or y == 19:
				c = c.darkened(0.2)
			img.set_pixel(o.x + x, o.y + y, c)


## A steel I-beam column, tiling vertically, with a rivet plate every 16 px,
## and its shadow on the wall to the right.
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
		img.set_pixel(o.x + 26, o.y + y, SHADOW)
