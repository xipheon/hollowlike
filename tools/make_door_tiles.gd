extends SceneTree
## Draws the doorway tiles (DOOR and DOOR TOP on the tile sheet) and a
## preview: an open, dark passage between steel jambs. DOOR TOP adds the
## hazard-striped steel lintel (the 6 px frame in SHEETS.md) and a red EXIT
## sign hanging under it. Run from the project folder:
##   godot --headless --path . --script res://tools/make_door_tiles.gd

const TILE := 32
const SHEET_PATH := "res://art/tiles/tileset.png"
const PREVIEW_PATH := "res://art/tiles/source/door_preview.png"
const PREVIEW_SCALE := 4
const DOOR := Vector2i(1, 6)
const DOOR_TOP := Vector2i(2, 6)

const JAMB := 3          # px of steel frame down each side
const LINTEL := 6        # px of steel beam across the top of DOOR TOP
const SIGN := Rect2i(7, 8, 18, 9)

const DARK := Color8(10, 10, 14)
const DARK_SPECK := Color8(18, 18, 24)
const STEEL := [Color8(132, 138, 144), Color8(92, 98, 106), Color8(62, 66, 74), Color8(34, 36, 42)]
const STRIPE_YELLOW := Color8(196, 160, 40)
const STRIPE_BLACK := Color8(28, 26, 26)
const RUST := Color8(122, 62, 30)
const SIGN_BOX := Color8(52, 10, 14)
const SIGN_EDGE := Color8(26, 26, 30)
const SIGN_TEXT := Color8(255, 72, 72)
const SIGN_TEXT_CORE := Color8(255, 170, 160)
const GLOW := Color8(40, 14, 18)

# 3x5 letters; I is a single column.
const LETTERS := {
	"E": ["111", "100", "110", "100", "111"],
	"X": ["101", "101", "010", "101", "101"],
	"I": ["1", "1", "1", "1", "1"],
	"T": ["111", "010", "010", "010", "010"],
}


func _init() -> void:
	var door := _doorway(false)
	var top := _doorway(true)
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SHEET_PATH))
	sheet.convert(Image.FORMAT_RGBA8)
	for pair in [[door, DOOR], [top, DOOR_TOP]]:
		var at: Vector2i = pair[1] * TILE
		sheet.fill_rect(Rect2i(at, Vector2i(TILE, TILE)), Color(0, 0, 0, 0))
		sheet.blit_rect(pair[0], Rect2i(0, 0, TILE, TILE), at)
	sheet.save_png(ProjectSettings.globalize_path(SHEET_PATH))
	_save_preview(door, top)
	print("Wrote door tiles to %s and preview to %s" % [SHEET_PATH, PREVIEW_PATH])
	quit()


func _noise(x: int, y: int, salt: int) -> float:
	return float(absi(hash(Vector3i(x, y, salt))) % 1000) / 1000.0


func _doorway(is_top: bool) -> Image:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	for y in TILE:
		for x in TILE:
			var c := DARK_SPECK if _noise(x, y, 1) < 0.06 else DARK
			if x < JAMB or x >= TILE - JAMB:
				# Jambs: light edge facing into the doorway, dark outer edge.
				var k := x if x < JAMB else TILE - 1 - x
				c = [STEEL[3], STEEL[1], STEEL[0]][k]
				if _noise(x, y, 2) < 0.07:
					c = RUST
			img.set_pixel(x, y, c)
	if is_top:
		_lintel(img)
		_exit_sign(img)
	return img


## A steel beam with chipped hazard stripes and a rivet at each end.
func _lintel(img: Image) -> void:
	for y in LINTEL:
		for x in TILE:
			var c: Color
			if y == 0:
				c = STEEL[0]
			elif y == LINTEL - 1:
				c = STEEL[3]
			elif x >= 6 and x < TILE - 6 and _noise(x, y, 3) > 0.15:
				c = STRIPE_YELLOW if posmod(x + y, 6) < 3 else STRIPE_BLACK
			else:
				c = STEEL[1]
			if y in [2, 3] and x in [3, 28]:
				c = STEEL[0] if y == 2 else STEEL[3]
			img.set_pixel(x, y, c)


## A boxed EXIT sign on two short hangers, with a faint red glow around it.
func _exit_sign(img: Image) -> void:
	var glow := SIGN.grow(1)
	for y in range(glow.position.y, glow.end.y):
		for x in range(glow.position.x, glow.end.x):
			if img.get_pixel(x, y) == DARK or img.get_pixel(x, y) == DARK_SPECK:
				img.set_pixel(x, y, GLOW)
	for hx in [SIGN.position.x + 2, SIGN.end.x - 3]:
		for y in range(LINTEL, SIGN.position.y):
			img.set_pixel(hx, y, STEEL[2])
	for y in range(SIGN.position.y, SIGN.end.y):
		for x in range(SIGN.position.x, SIGN.end.x):
			var edge := x == SIGN.position.x or x == SIGN.end.x - 1 or y == SIGN.position.y or y == SIGN.end.y - 1
			img.set_pixel(x, y, SIGN_EDGE if edge else SIGN_BOX)
	var word := "EXIT"
	var width := 0
	for ch in word:
		width += LETTERS[ch][0].length() + 1
	width -= 1
	var lx := SIGN.position.x + (SIGN.size.x - width) / 2
	var ly := SIGN.position.y + 2
	for ch in word:
		var rows: Array = LETTERS[ch]
		for ry in rows.size():
			for rx in rows[ry].length():
				if rows[ry][rx] == "1":
					img.set_pixel(lx + rx, ly + ry, SIGN_TEXT_CORE if ry == 2 else SIGN_TEXT)
		lx += rows[0].length() + 1


## A three-tile doorway (DOOR TOP over two DOORs) set into terrain-grey wall.
func _save_preview(door: Image, top: Image) -> void:
	var img := Image.create(TILE * 3, TILE * 4, false, Image.FORMAT_RGBA8)
	img.fill(Color8(40, 33, 32))
	img.fill_rect(Rect2i(TILE, 0, TILE, TILE), Color8(120, 120, 124))
	img.blend_rect(top, Rect2i(0, 0, TILE, TILE), Vector2i(TILE, TILE))
	img.blend_rect(door, Rect2i(0, 0, TILE, TILE), Vector2i(TILE, TILE * 2))
	img.blend_rect(door, Rect2i(0, 0, TILE, TILE), Vector2i(TILE, TILE * 3))
	img.resize(img.get_width() * PREVIEW_SCALE, img.get_height() * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(PREVIEW_PATH))
