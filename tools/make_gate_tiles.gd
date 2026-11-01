extends SceneTree
## Draws the arena gate as a rusted roll-up steel shutter (GATE, GATE END and
## GATE UP on the tile sheet) and writes a preview. GATE is the ribbed shutter
## and repeats up the column; GATE END is its bottom tile, ending in a heavy
## bar with teeth; GATE UP is just that bar and teeth peeking out under the
## lintel when the gate is raised. Run from the project folder:
##   godot --headless --path . --script res://tools/make_gate_tiles.gd

const TILE := 32
const SHEET_PATH := "res://art/tiles/tileset.png"
const PREVIEW_PATH := "res://art/tiles/source/gate_preview.png"
const PREVIEW_SCALE := 4
const GATE := Vector2i(6, 4)
const GATE_END := Vector2i(7, 4)
const GATE_UP := Vector2i(0, 6)

const SLAT := 8          # px per shutter slat; divides TILE so the shutter repeats
const RAIL := 3          # width of the guide channel down each side
const BAR := 6           # height of the bottom bar
const TEETH := 4         # height of the teeth below it
const TOOTH_PITCH := 8
const UP_SHOWS := 8      # px of bar and teeth showing when raised (SHEETS.md)

# Slat rows, top to bottom: highlight, face, face, face, face, shadow, groove, shadow.
const SLAT_ROWS := [Color8(128, 136, 144), Color8(100, 106, 114), Color8(96, 102, 110), Color8(92, 98, 106),
	Color8(88, 94, 102), Color8(62, 66, 74), Color8(34, 36, 42), Color8(56, 60, 68)]
const RAIL_COLORS := [Color8(30, 32, 38), Color8(52, 56, 62), Color8(40, 42, 48)]
const BAR_COLORS := [Color8(140, 146, 150), Color8(84, 88, 94), Color8(66, 70, 76), Color8(40, 42, 48)]
const TOOTH := Color8(150, 156, 160)
const TOOTH_DARK := Color8(70, 74, 80)
const OUTLINE := Color8(22, 22, 26)
const RUST := Color8(122, 62, 30)
const RUST_DARK := Color8(84, 40, 22)


func _init() -> void:
	var gate := _shutter()
	var end := _shutter()
	_bar_and_teeth(end, TILE - BAR - TEETH)
	# Raised: the last UP_SHOWS px of the bottom end, at the top of the tile.
	var up := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	up.blit_rect(end, Rect2i(0, TILE - UP_SHOWS, TILE, UP_SHOWS), Vector2i.ZERO)

	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SHEET_PATH))
	sheet.convert(Image.FORMAT_RGBA8)
	for pair in [[gate, GATE], [end, GATE_END], [up, GATE_UP]]:
		var at: Vector2i = pair[1] * TILE
		sheet.fill_rect(Rect2i(at, Vector2i(TILE, TILE)), Color(0, 0, 0, 0))
		sheet.blit_rect(pair[0], Rect2i(0, 0, TILE, TILE), at)
	sheet.save_png(ProjectSettings.globalize_path(SHEET_PATH))
	_save_preview(gate, end, up)
	print("Wrote gate tiles to %s and preview to %s" % [SHEET_PATH, PREVIEW_PATH])
	quit()


func _noise(x: int, y: int, salt: int) -> float:
	return float(absi(hash(Vector3i(x, y, salt))) % 1000) / 1000.0


## Ribbed steel slats between two guide rails, with rust running down from the
## grooves. Everything is worked out from y mod TILE, so it repeats vertically.
func _shutter() -> Image:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	for y in TILE:
		for x in TILE:
			var c: Color
			if x < RAIL or x >= TILE - RAIL:
				var k := x if x < RAIL else TILE - 1 - x
				c = RAIL_COLORS[k]
			else:
				var row := y % SLAT
				c = SLAT_ROWS[row]
				# Rust streaks run down a slat from the groove above it.
				var streak := _noise(x, y / SLAT, 1)
				if streak < 0.18 and row < 1 + int(streak * 30.0):
					c = RUST if row > 0 else RUST_DARK
				elif _noise(x, y, 2) < 0.05:
					c = c.darkened(0.15)
			img.set_pixel(x, y, c)
	return img


## The heavy bottom bar, with bolts, and a row of teeth pointing down under it.
func _bar_and_teeth(img: Image, top: int) -> void:
	for y in range(top, top + BAR):
		var k := y - top
		for x in TILE:
			var c: Color = BAR_COLORS[0] if k == 0 else BAR_COLORS[3] if k == BAR - 1 else BAR_COLORS[1] if k < 3 else BAR_COLORS[2]
			if k in [2, 3] and x in [6, 7, 24, 25]:
				c = BAR_COLORS[0] if k == 2 else BAR_COLORS[3]   # bolts
			elif _noise(x, y, 3) < 0.08:
				c = RUST
			img.set_pixel(x, y, c)
	for y in range(top + BAR, TILE):
		var depth := y - top - BAR
		for x in TILE:
			var into := posmod(x - TOOTH_PITCH / 2, TOOTH_PITCH) - TOOTH_PITCH / 2   # -4..3, 0 = tooth centre
			var half := 3 - depth
			if into < -half or into > half:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var c := TOOTH if into >= 0 else TOOTH_DARK
			if into == -half or into == half:
				c = OUTLINE
			img.set_pixel(x, y, c)


## Shut (GATE x3 over GATE END) beside raised (GATE UP under a lintel).
func _save_preview(gate: Image, end: Image, up: Image) -> void:
	var img := Image.create(TILE * 4, TILE * 5, false, Image.FORMAT_RGBA8)
	img.fill(Color8(40, 33, 32))
	var lintel := Color8(120, 120, 124)
	for col in [0, 2]:
		img.fill_rect(Rect2i(col * TILE, 0, TILE, TILE), lintel)
	for y in range(1, 4):
		img.blend_rect(gate, Rect2i(0, 0, TILE, TILE), Vector2i(0, y * TILE))
	img.blend_rect(end, Rect2i(0, 0, TILE, TILE), Vector2i(0, 4 * TILE))
	img.blend_rect(up, Rect2i(0, 0, TILE, TILE), Vector2i(2 * TILE, TILE))
	img.resize(img.get_width() * PREVIEW_SCALE, img.get_height() * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(PREVIEW_PATH))
