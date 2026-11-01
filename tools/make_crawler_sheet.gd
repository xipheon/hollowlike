extends SceneTree
## Draws the crawler, a blob of sewer sludge that oozes along the floor, into
## one sheet per palette (art/sprites/crawler_<palette>.png, the crawler layout
## in art/templates/SHEETS.md) and writes a preview. Nothing is generated: each
## frame is a dome-shaped height profile with a ripple travelling from back to
## front, shaded from its surface down and outlined. Then run
## tools/make_crawler_scenes.gd to rebuild the crawler scenes from the sheets.
## Run from the project folder:
##   godot --headless --path . --script res://tools/make_crawler_sheet.gd

const FRAME := 32
const COLUMNS := 5
const FLOOR_Y := 31   # bottom row: the feet
const SHEET_PATH := "res://art/sprites/crawler_%s.png"
const PREVIEW_PATH := "res://art/sprites/source/crawler_preview.png"
const PREVIEW_SCALE := 4

## Colours per palette (each has its crawler scene; see tools/make_crawler_scenes.gd).
const PALETTES := {
	"sewer": {   # the sewer water's own colours
		"outline": Color8(20, 18, 8), "dark": Color8(45, 42, 16), "body": Color8(76, 73, 0),
		"light": Color8(110, 118, 12), "rim": Color8(170, 196, 60), "speck": Color8(133, 231, 0),
		"eye": Color8(255, 226, 80),   # yellow: green would be lost among the specks
	},
	"sickly": {   # a sicklier yellow-green, so it stands out more
		"outline": Color8(38, 40, 8), "dark": Color8(96, 108, 22), "body": Color8(146, 164, 36),
		"light": Color8(186, 200, 66), "rim": Color8(232, 240, 150), "speck": Color8(255, 236, 110),
		"eye": Color8(255, 96, 48),
	},
	"pink": {   # light pink
		"outline": Color8(92, 40, 62), "dark": Color8(204, 112, 152), "body": Color8(236, 158, 188),
		"light": Color8(250, 192, 214), "rim": Color8(255, 234, 244), "speck": Color8(255, 255, 255),
		"eye": Color8(120, 22, 64),
	},
}

## Rows, as in SHEETS.md: [name, frame shapes]. A shape is
## [back reach, front reach, height, ripple, phase (0-1), peak shift, extras].
## Reaches and height are px; the peak shift moves the dome's top forward (+)
## as a share of the width; extras: "eyes", "bubble:<size>", "pop", "specks",
## and for hanging from a ceiling: "ceiling" (drawn upside down, stuck to the
## top of the frame), "drip:<across>:<length>" (a drip hanging from the belly;
## across is -1 back to 1 front) and "drop:<across>:<gap>" (a drop that's let go).
const ROWS := [
	["walk", [
		[13.0, 13.0, 17.0, 1.6, 0.0, 0.15, ["eyes"]],
		[12.0, 14.5, 16.0, 1.6, 0.25, 0.2, ["eyes", "bubble:1"]],
		[13.0, 13.0, 17.0, 1.6, 0.5, 0.15, ["eyes", "bubble:2"]],
		[14.5, 12.0, 18.0, 1.6, 0.75, 0.1, ["eyes", "pop"]],
	]],
	["turn", [
		[11.0, 11.0, 21.0, 0.6, 0.0, 0.0, ["eyes"]],
		[11.5, 13.5, 19.0, 1.0, 0.25, 0.12, ["eyes"]],
	]],
	["hurt", [
		[15.5, 15.5, 11.0, 2.2, 0.0, 0.0, ["eyes"]],
		[11.0, 11.0, 20.0, 1.2, 0.5, 0.05, ["eyes"]],
	]],
	["death", [
		[15.5, 15.5, 9.0, 2.0, 0.0, 0.0, []],
		[16.5, 16.5, 5.0, 1.2, 0.3, 0.0, ["bubble:1"]],
		[16.0, 16.0, 4.0, 1.0, 0.6, 0.0, ["pop"]],
		[14.0, 14.0, 2.0, 0.5, 0.9, 0.0, ["specks"]],
		[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ["specks"]],
	]],
	# On a ceiling: saggier, with drips that grow, stretch and let go.
	["ceiling_walk", [
		[13.0, 13.0, 15.0, 1.4, 0.0, 0.05, ["ceiling", "eyes", "drip:-0.35:2", "drip:0.3:1"]],
		[12.0, 14.5, 14.0, 1.4, 0.25, 0.1, ["ceiling", "eyes", "drip:-0.35:4", "drip:0.3:2"]],
		[13.0, 13.0, 15.0, 1.4, 0.5, 0.05, ["ceiling", "eyes", "drip:-0.35:6", "drip:0.3:3"]],
		[14.5, 12.0, 16.0, 1.4, 0.75, 0.0, ["ceiling", "eyes", "drip:-0.35:1", "drop:-0.35:5", "drip:0.3:4"]],
	]],
	["ceiling_turn", [
		[11.0, 11.0, 18.0, 0.6, 0.0, 0.0, ["ceiling", "eyes", "drip:0.0:3"]],
		[11.5, 13.5, 16.0, 1.0, 0.25, 0.1, ["ceiling", "eyes", "drip:-0.2:2"]],
	]],
	["ceiling_hurt", [
		[15.5, 15.5, 10.0, 2.2, 0.0, 0.0, ["ceiling", "eyes", "drip:-0.5:2", "drip:0.5:2"]],
		[11.0, 11.0, 19.0, 1.2, 0.5, 0.0, ["ceiling", "eyes", "drip:0.0:5"]],
	]],
	["ceiling_death", [
		[15.0, 15.0, 12.0, 2.0, 0.0, 0.0, ["ceiling", "drip:-0.3:5", "drip:0.35:4"]],
		[14.0, 14.0, 9.0, 1.4, 0.3, 0.0, ["ceiling", "drip:-0.3:8", "drip:0.35:6"]],
		[12.0, 12.0, 6.0, 1.0, 0.6, 0.0, ["ceiling", "drip:-0.3:3", "drop:-0.3:8", "drip:0.35:10"]],
		[9.0, 9.0, 3.0, 0.5, 0.9, 0.0, ["ceiling", "specks", "drop:0.35:14"]],
		[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ["ceiling", "specks"]],
	]],
	# Let go of the ceiling: a stretched falling drop, then a splat on landing.
	["drop", [
		[7.0, 7.0, 24.0, 0.6, 0.0, 0.0, ["eyes"]],
		[6.5, 6.5, 26.0, 0.6, 0.5, 0.0, ["eyes"]],
	]],
	["land", [
		[16.0, 16.0, 9.0, 2.2, 0.0, 0.0, ["eyes"]],
		[12.0, 12.0, 19.0, 1.2, 0.5, 0.05, ["eyes"]],
	]],
]

const SPECKS := [Vector2(-0.45, 0.45), Vector2(0.1, 0.3), Vector2(-0.1, 0.65), Vector2(0.4, 0.5)]   # (across, up) in body space


func _init() -> void:
	var previews: Array[Image] = []
	for id in PALETTES:
		var sheet := Image.create(COLUMNS * FRAME, ROWS.size() * FRAME, false, Image.FORMAT_RGBA8)
		for r in ROWS.size():
			var shapes: Array = ROWS[r][1]
			for f in shapes.size():
				var frame := _draw_frame(shapes[f], PALETTES[id])
				sheet.blit_rect(frame, Rect2i(0, 0, FRAME, FRAME), Vector2i(f, r) * FRAME)
		sheet.save_png(ProjectSettings.globalize_path(SHEET_PATH % id))
		print("Wrote ", SHEET_PATH % id)
		previews.append(sheet)
	_save_preview(previews)
	quit()


func _draw_frame(shape: Array, pal: Dictionary) -> Image:
	var img := Image.create(FRAME, FRAME, false, Image.FORMAT_RGBA8)
	var back: float = shape[0]
	var front: float = shape[1]
	var height: float = shape[2]
	var extras: Array = shape[6]
	var centre_x := FRAME / 2
	# Surface height of every column, from back (-) to front (+).
	var tops := {}
	for x in FRAME:
		var t := _surface(float(x - centre_x) + 0.5, shape)
		if t > 0.5:
			tops[x] = t
	# Body: shaded by depth below the surface, darker near the floor.
	for x in tops:
		var top: float = tops[x]
		for up in int(ceil(top)):
			var y := FLOOR_Y - up
			var depth := top - up
			var c: Color = pal.body
			if depth < 1.5:
				c = pal.rim if depth < 1.0 and up > top * 0.4 else pal.light
			elif depth < 3.5:
				c = pal.light
			elif up < 2:
				c = pal.dark
			img.set_pixel(x, y, c)
	if "specks" in extras or height > 3.0:
		_specks(img, shape, pal, height <= 3.0)
	if "eyes" in extras:
		_eyes(img, shape, pal)
	for e in extras:
		if e.begins_with("bubble:"):
			_bubble(img, shape, pal, int(e.split(":")[1]))
		elif e == "pop":
			_pop(img, shape, pal)
	if "ceiling" in extras:
		img.flip_y()   # hang from the top of the frame, belly down
		for e in extras:
			var parts: PackedStringArray = e.split(":")
			if parts[0] == "drip":
				_drip(img, shape, pal, float(parts[1]), int(parts[2]))
			elif parts[0] == "drop":
				_falling_drop(img, shape, pal, float(parts[1]), int(parts[2]))
	_outline(img, pal.outline)
	return img


## Column `across` (-1 back to 1 front) of a hanging blob, and how far down
## its belly reaches there.
func _belly(shape: Array, across: float) -> Vector2i:
	var reach: float = shape[1] if across >= 0.0 else shape[0]
	var x := int(across * reach)
	return Vector2i(FRAME / 2 + x, int(_surface(float(x) + 0.5, shape)))


## A drip hanging `length` px from the belly of a ceiling blob, swelling at its tip.
func _drip(img: Image, shape: Array, pal: Dictionary, across: float, length: int) -> void:
	var at := _belly(shape, across)
	if at.y <= 0:
		return
	for i in length:
		img.set_pixel(at.x, at.y + i, pal.body)
	var tip := at.y + length - 1
	if length >= 3:
		img.set_pixel(at.x - 1, tip, pal.body)
		img.set_pixel(at.x + 1, tip, pal.body)
		img.set_pixel(at.x, tip + 1, pal.light)


## A drop that has let go, `gap` px below the belly.
func _falling_drop(img: Image, shape: Array, pal: Dictionary, across: float, gap: int) -> void:
	var at := _belly(shape, across) + Vector2i(0, gap)
	if at.y + 1 >= FRAME:
		return
	img.set_pixel(at.x, at.y, pal.body)
	img.set_pixel(at.x, at.y + 1, pal.light)


## Height of the blob's top at `x` px from the centre (0 = outside it).
func _surface(x: float, shape: Array) -> float:
	var back: float = shape[0]
	var front: float = shape[1]
	if back + front <= 0.0 or x < -back or x > front:
		return 0.0
	var s := x / front if x >= 0.0 else x / back   # -1 at the back edge, 1 at the front
	var peak: float = shape[5]
	var u := (s - peak) / (1.0 + absf(peak) * signf(s - peak))
	var dome := pow(maxf(1.0 - u * u, 0.0), 0.55)
	var tail := lerpf(0.75, 1.0, (s + 1.0) * 0.5)   # the back trails off lower
	var ripple: float = shape[3] * sin(TAU * (s * 0.9 - shape[4])) * (1.0 - s * s)
	return maxf(shape[2] * dome * tail + ripple, 0.0)


## Two glowing eyes near the front, a little below the surface.
func _eyes(img: Image, shape: Array, pal: Dictionary) -> void:
	var front: float = shape[1]
	for ex in [front * 0.35, front * 0.62]:
		var x := FRAME / 2 + int(ex)
		var top := _surface(float(int(ex)) + 0.5, shape)
		var y := FLOOR_Y - int(top) + 4
		if top > 6.0:
			img.set_pixel(x, y, pal.eye)
			img.set_pixel(x, y - 1, pal.eye.darkened(0.25))


## Glowing specks suspended in the sludge, fixed in body space so they ride
## along with it; `fading` leaves them dimmer (the puddle drying up).
func _specks(img: Image, shape: Array, pal: Dictionary, fading: bool) -> void:
	var back: float = maxf(shape[0], 10.0)
	var front: float = maxf(shape[1], 10.0)
	for sp in SPECKS:
		var x := FRAME / 2 + int(sp.x * (back if sp.x < 0.0 else front))
		var top := maxf(_surface(float(x - FRAME / 2) + 0.5, shape), 3.0)
		var y := FLOOR_Y - int(sp.y * top)
		if fading or img.get_pixel(x, y).a > 0.0:
			var c: Color = pal.speck
			if fading:
				c.a = 0.6
			img.set_pixel(x, y, c)


## A bubble swelling on the back of the blob's top.
func _bubble(img: Image, shape: Array, pal: Dictionary, size: int) -> void:
	var bx: float = -shape[0] * 0.3
	var top := _surface(bx, shape)
	var centre := Vector2i(FRAME / 2 + int(bx), FLOOR_Y - int(top) - size + 1)
	for y in range(-size, size + 1):
		for x in range(-size, size + 1):
			var d := Vector2(x, y).length()
			if d <= size + 0.3:
				img.set_pixel(centre.x + x, centre.y + y, pal.rim if d > size - 0.7 else pal.light)


## A bubble that's just burst: a few droplets over where it was.
func _pop(img: Image, shape: Array, pal: Dictionary) -> void:
	var bx: float = -shape[0] * 0.3
	var top := _surface(bx, shape)
	var at := Vector2i(FRAME / 2 + int(bx), FLOOR_Y - int(top) - 3)
	for d in [Vector2i(-2, 0), Vector2i(2, -1), Vector2i(0, -2)]:
		img.set_pixelv(at + d, pal.rim)


## A one-pixel outline around everything, except along the floor.
func _outline(img: Image, color: Color) -> void:
	var src := img.duplicate() as Image
	for y in FLOOR_Y + 1:
		for x in FRAME:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.x < FRAME and n.y >= 0 and n.y < FRAME and src.get_pixelv(n).a > 0.5:
					img.set_pixel(x, y, color)
					break


## Each palette's sheet, stacked, over the brick colour with a strip of floor.
func _save_preview(sheets: Array[Image]) -> void:
	var h := ROWS.size() * FRAME
	var img := Image.create(COLUMNS * FRAME, sheets.size() * h, false, Image.FORMAT_RGBA8)
	img.fill(Color8(40, 33, 32))
	for i in sheets.size():
		for r in ROWS.size():
			img.fill_rect(Rect2i(0, i * h + r * FRAME + FRAME - 1, COLUMNS * FRAME, 1), Color8(120, 120, 124))
		img.blend_rect(sheets[i], Rect2i(Vector2i.ZERO, sheets[i].get_size()), Vector2i(0, i * h))
	img.resize(img.get_width() * PREVIEW_SCALE, img.get_height() * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(PREVIEW_PATH))
