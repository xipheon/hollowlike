extends SceneTree
## Draws the moving platform track tiles onto the tile sheet and writes a
## preview. A track is a steel guide rail with a slot down the middle and a
## striped buffer stop at each end. Horizontal tiles (left end, middle, right
## end) go at RoomArt.TRACK_H, with the rail centred on the height of the
## platform's catwalk deck. The vertical ones, at RoomArt.TRACK_V (top end,
## middle, bottom end), are the same rail centred and turned on end, so it runs
## up the middle of the deck. Run from the project folder:
##   godot --headless --path . --script res://tools/make_track_tiles.gd

const TILE := 32
const SHEET_PATH := "res://art/tiles/tileset.png"
const PREVIEW_PATH := "res://art/tiles/source/track_preview.png"
const PREVIEW_SCALE := 4

const OUTLINE := Color8(22, 20, 22)
const STEEL_DARK := Color8(52, 54, 60)
const STEEL := Color8(84, 87, 94)
const STEEL_LIGHT := Color8(122, 125, 132)
const SLOT := Color8(14, 13, 15)
const RUST := Color8(108, 62, 36)
const RUST_DARK := Color8(74, 42, 26)
const BOLT := Color8(150, 152, 156)
const STRIPE_A := Color8(196, 158, 44)
const STRIPE_B := Color8(30, 28, 26)

const RAIL_HEIGHT := 8     # rail rows, outline to outline
const TOP_RAIL := 5       # side to side: the rail's top row, centred on the catwalk deck (its rows 1-17)
const MIDDLE_RAIL := 12   # up and down (before turning on end): centred, under the deck's middle
const STOP_FROM := 3      # the buffer stop's columns, from the end's outer edge
const STOP_TO := 9


func _init() -> void:
	var left := _rail_tile(-1, TOP_RAIL)
	var mid := _rail_tile(0, TOP_RAIL)
	var right := _rail_tile(1, TOP_RAIL)
	var horizontal := [left, mid, right]
	# Turned anticlockwise, the left end points down: top, middle, bottom is R, M, L.
	var vertical := [_turned(_rail_tile(1, MIDDLE_RAIL)), _turned(_rail_tile(0, MIDDLE_RAIL)), _turned(_rail_tile(-1, MIDDLE_RAIL))]

	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SHEET_PATH))
	sheet.convert(Image.FORMAT_RGBA8)
	for i in 3:
		_put(sheet, horizontal[i], RoomArt.TRACK_H + Vector2i(i, 0))
		_put(sheet, vertical[i], RoomArt.TRACK_V + Vector2i(0, i))
	sheet.save_png(ProjectSettings.globalize_path(SHEET_PATH))
	_save_preview(horizontal, vertical)
	print("Wrote track tiles to %s and preview to %s" % [SHEET_PATH, PREVIEW_PATH])
	quit()


## A horizontal rail tile: `end` -1 stops at the left, 1 at the right, 0 runs
## through. `top` is the rail's top row.
func _rail_tile(end: int, top: int) -> Image:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var x0 := 0
	var x1 := TILE - 1
	if end < 0:
		x0 = STOP_FROM + 2
	elif end > 0:
		x1 = TILE - 1 - STOP_FROM - 2
	for x in range(x0, x1 + 1):
		img.set_pixel(x, top, OUTLINE)
		img.set_pixel(x, top + 1, STEEL_LIGHT)
		img.set_pixel(x, top + 2, STEEL)
		img.set_pixel(x, top + 3, SLOT)
		img.set_pixel(x, top + 4, SLOT)
		img.set_pixel(x, top + 5, STEEL)
		img.set_pixel(x, top + 6, STEEL_DARK)
		img.set_pixel(x, top + RAIL_HEIGHT - 1, OUTLINE)
		# Rust creeping along the rail, the same on every tile so they join up.
		var h := (x * 7 + 3) % 11
		if h == 0:
			img.set_pixel(x, top + 2, RUST)
		elif h == 5:
			img.set_pixel(x, top + 5, RUST_DARK)
	# Bolts where the rail is fixed to the wall, every 16 px.
	for bx in [7, 23]:
		if bx >= x0 + 1 and bx <= x1 - 1:
			img.set_pixel(bx, top + 1, BOLT)
			img.set_pixel(bx, top + 6, BOLT)
	if end != 0:
		_buffer_stop(img, end, top)
	return img


## A striped steel block across the rail's end, taller than the rail.
func _buffer_stop(img: Image, end: int, rail_top: int) -> void:
	var a := STOP_FROM if end < 0 else TILE - 1 - STOP_TO
	var b := STOP_TO if end < 0 else TILE - 1 - STOP_FROM
	var top := maxi(rail_top - 4, 0)
	var bottom := rail_top + RAIL_HEIGHT - 1 + 4
	for y in range(top, bottom + 1):
		for x in range(a, b + 1):
			var c: Color
			if x == a or x == b or y == top or y == bottom:
				c = OUTLINE
			elif y == top + 1:
				c = STEEL_LIGHT
			elif y == bottom - 1:
				c = STEEL_DARK
			else:
				c = STRIPE_A if (x + y) / 3 % 2 == 0 else STRIPE_B
			img.set_pixel(x, y, c)
	# Its mounting plate, bolted top and bottom.
	var mid := (a + b) / 2
	img.set_pixel(mid, top + 1, BOLT)
	img.set_pixel(mid, bottom - 1, BOLT)


func _turned(img: Image) -> Image:
	var copy := img.duplicate() as Image
	copy.rotate_90(COUNTERCLOCKWISE)
	return copy


func _put(sheet: Image, tile: Image, cell: Vector2i) -> void:
	var at := cell * TILE
	sheet.fill_rect(Rect2i(at, Vector2i(TILE, TILE)), Color(0, 0, 0, 0))
	sheet.blit_rect(tile, Rect2i(0, 0, TILE, TILE), at)


## A horizontal run (L, 3 x M, R) and a vertical one, over the brick colour.
func _save_preview(horizontal: Array, vertical: Array) -> void:
	var img := Image.create(7 * TILE, 5 * TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color8(40, 33, 32))
	var row := [0, 1, 1, 1, 2]
	for i in row.size():
		img.blend_rect(horizontal[row[i]], Rect2i(0, 0, TILE, TILE), Vector2i(i * TILE, 2 * TILE))
	for i in row.size():
		img.blend_rect(vertical[row[i]], Rect2i(0, 0, TILE, TILE), Vector2i(6 * TILE, i * TILE))
	img.resize(img.get_width() * PREVIEW_SCALE, img.get_height() * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(PREVIEW_PATH))
