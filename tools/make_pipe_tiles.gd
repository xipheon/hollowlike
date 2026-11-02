extends SceneTree
## Builds the pipes tile sheet (art/tiles/pipes.png), for the Props layer, with
## nothing behind the pipes: their shadows and the rust stains are translucent,
## so over brick they look as they did drawn onto it. Laid out like the concrete
## terrain block (RoomArt.TERRAIN), so the tileset's pipe brush can join pipes
## up: each cell of the 4x4 block is pipe running out of the sides it names:
##   two opposite sides  a straight length, with a flange halfway
##   any other two/three/four sides  an elbow, T or cross, under a bolted collar
##   one side            the end, going into the wall behind a bolted flange
##   no side             just a collar: a lone valve stub
## Row 4 is the broken-off ends (a jagged edge, the hollow inside showing, rust,
## and on a horizontal pipe a stain dripping down the wall), in the order
## RoomArt.PIPE_BROKEN_ENDS: the end at the top, left, bottom, right.
## Also draws the sheet's normal map, art/tiles/pipes_n.png (overwriting it),
## so the room's lights shade the pipes (see "Normal maps" in art/README.md):
## each length rounds like a tube (top rows face up, bottom rows down; a
## vertical one left and right), the flange rings' edges face along the pipe,
## collars and wall flanges are boxes with bevelled edges, and a broken end's
## hollow curves the other way, the inside of the tube. Shadows and stains
## stay flat. And writes a preview over brick. Run from the project folder,
## then tools/make_tilesets.gd:
##   godot --headless --path . --script res://tools/make_pipe_tiles.gd

const TILE := 32
const SHEET_PATH := "res://art/tiles/pipes.png"
const NORMAL_PATH := "res://art/tiles/pipes_n.png"
const SHEET_SIZE := Vector2i(4, 5)   # in tiles
const BRICK_SHEET := "res://art/tiles/background.png"
const PREVIEW_PATH := "res://art/tiles/source/pipes_preview.png"
const PREVIEW_SCALE := 4

const SHADOW := Color(0, 0, 0, 0.4)   # the same as darkening the wall by 0.4
const PIPE := [Color8(54, 58, 62), Color8(86, 92, 96), Color8(122, 128, 130), Color8(70, 76, 80), Color8(40, 42, 46)]
const RUST := Color8(120, 62, 30)
const SIDES := {"N": Vector2i.UP, "E": Vector2i.RIGHT, "S": Vector2i.DOWN, "W": Vector2i.LEFT}

const BAND := Vector2i(11, 20)    # the pipe's rows (or columns) across the tile, edge to edge
const COLLAR := Vector2i(10, 22)  # the collar over a joint, both ways
const WALL_END := 21              # into the wall: the pipe runs this far toward its end...
const FLANGE := Vector2i(20, 23)  # ...under a flange this thick (along the pipe)...
const FLANGE_ACROSS := Vector2i(8, 23)   # ...and this wide (across it)
const BROKEN_END := 19            # broken: about this far, give or take the jagged edge
const JAGS := [0, -1, 1, -2, 0, 2, -1, 1, 0, -2]   # per row (or column) across the pipe

# The normal map: how far a surface turns from facing straight out (the
# sideways part of its normal, 0 flat to 1 edge-on).
const ROUND := 0.85        # a tube's edges, its curve between
const RING := 0.5          # a flange ring's edges, along the pipe
const BEVEL := 0.6         # a collar's or wall flange's bevelled edges
const FLAT := Color8(128, 128, 255)


func _init() -> void:
	var sheet := Image.create(SHEET_SIZE.x * TILE, SHEET_SIZE.y * TILE, false, Image.FORMAT_RGBA8)
	var normals := _flat(sheet.get_size())
	# Each piece is [art, normal map].
	var pipe_h := _piece("EW")
	var pipe_v := _piece("NS")
	var colours := _palette(pipe_h[0], _brick())
	for r in RoomArt.TERRAIN.size():
		for c in RoomArt.TERRAIN[r].size():
			var sides: String = RoomArt.TERRAIN[r][c]
			var piece: Array
			if sides.length() == 1:
				piece = _end(pipe_v if sides in "NS" else pipe_h, -SIDES[sides], false, colours)
			else:
				piece = _piece(sides)
			sheet.blit_rect(piece[0], Rect2i(0, 0, TILE, TILE), Vector2i(c, r) * TILE)
			normals.blit_rect(piece[1], Rect2i(0, 0, TILE, TILE), Vector2i(c, r) * TILE)
	for i in RoomArt.PIPE_BROKEN_ENDS.size():
		var sides: String = RoomArt.TERRAIN[RoomArt.PIPE_WALL_ENDS[i].y][RoomArt.PIPE_WALL_ENDS[i].x]
		var piece := _end(pipe_v if sides in "NS" else pipe_h, -SIDES[sides], true, colours)
		sheet.blit_rect(piece[0], Rect2i(0, 0, TILE, TILE), RoomArt.PIPE_BROKEN_ENDS[i] * TILE)
		normals.blit_rect(piece[1], Rect2i(0, 0, TILE, TILE), RoomArt.PIPE_BROKEN_ENDS[i] * TILE)
	sheet.save_png(ProjectSettings.globalize_path(SHEET_PATH))
	normals.save_png(ProjectSettings.globalize_path(NORMAL_PATH))
	_save_preview(sheet)
	print("Wrote %s, %s and %s" % [SHEET_PATH, NORMAL_PATH, PREVIEW_PATH])
	quit()


func _noise(x: int, y: int, salt: int) -> float:
	return float(absi(hash(Vector3i(x, y, salt))) % 1000) / 1000.0


## A fixed scatter in [0, 1) for each pixel, so reruns draw the same rust.
func _scatter(x: int, y: int) -> float:
	return float((x * 73856093) ^ (y * 19349663) & 1023) / 1024.0


## A normal map facing straight out everywhere.
func _flat(size: Vector2i) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(FLAT)
	return img


## A normal turned `lean` from facing out: its sideways part, in screen
## directions (x right, y down), as a normal-map colour (green up).
func _encode(lean: Vector2) -> Color:
	lean = lean.limit_length(0.95)
	var z := sqrt(1.0 - lean.length_squared())
	return Color(lean.x * 0.5 + 0.5, -lean.y * 0.5 + 0.5, z * 0.5 + 0.5, 1.0)


## Pipe running from the middle out of each of `sides`, horizontal halves
## first, under a collar where it doesn't run straight through: [art, normal map].
func _piece(sides: String) -> Array:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var nrm := _flat(Vector2i(TILE, TILE))
	for s in ["W", "E", "N", "S"]:
		if s in sides:
			_half(img, nrm, s)
	if not sides in ["EW", "NS"]:
		_collar(img, nrm)
	return [img, nrm]


## Half a length of pipe, from the middle of the tile out to `side`'s edge:
## 8px wide, rusty, with half of the flange at the middle, then its shadow on
## the wall below (or right of) it. Rounded like a tube on the normal map.
func _half(img: Image, nrm: Image, side: String) -> void:
	var vertical := side in "NS"
	var along := range(0, TILE / 2) if side in "NW" else range(TILE / 2, TILE)
	for a in along:
		var flange: bool = a >= 14 and a <= 17
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
			img.set_pixelv(p, c)
			# Across the tube from one edge to the other, and the ring's edges along it.
			var curve := (b - (lo + hi - 1) * 0.5) / ((hi - lo) * 0.5) * ROUND
			var ring := -RING if flange and a == 14 else RING if flange and a == 17 else 0.0
			nrm.set_pixelv(p, _encode(Vector2(curve, ring) if vertical else Vector2(ring, curve)))
	for a in along:
		var p := Vector2i(20, a) if vertical else Vector2i(a, 20)
		img.set_pixelv(p, img.get_pixelv(p).blend(SHADOW))


## The collar over a joint: square, with a bolt in each corner, and its shadow
## down and right. A box with bevelled edges on the normal map.
func _collar(img: Image, nrm: Image) -> void:
	var lo := COLLAR.x
	var hi := COLLAR.y
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
			img.set_pixel(x, y, c)
			nrm.set_pixel(x, y, _encode(_bevel(Vector2i(x, y), Rect2i(lo, lo, hi - lo, hi - lo))))
	for a in range(lo + 1, hi + 1):
		img.set_pixel(hi, a, img.get_pixel(hi, a).blend(SHADOW))
		img.set_pixel(a, hi, img.get_pixel(a, hi).blend(SHADOW))


## The pipe's colours, read off a length of it over plain brick, as it's seen
## in a room: darkest (its outline, or its shadow on the brick), lightest (its
## highlight), the middle one, and its rust.
func _palette(pipe: Image, brick: Image) -> Dictionary:
	var seen := brick.duplicate() as Image
	seen.blend_rect(pipe, Rect2i(0, 0, TILE, TILE), Vector2i.ZERO)
	var found: Array[Color] = []
	var rust := Color8(120, 62, 32)
	for y in range(BAND.x, BAND.y + 1):
		for x in TILE:
			var c := seen.get_pixel(x, y)
			if c == brick.get_pixel(x, y):
				continue
			if c.r > c.g + 0.12:
				rust = c
			else:
				found.append(c)
	found.sort_custom(func(a, b): return a.get_luminance() < b.get_luminance())
	var dark := found[0]
	var light := found[-1]
	var mid := found[found.size() / 2]
	return {"dark": dark, "mid": mid, "light": light, "rust": rust,
			"hollow": dark.darkened(0.6), "stain": Color(rust.darkened(0.45), 0.55)}


## A box's bevel at `p`: its two outer pixels on each side turn outward.
func _bevel(p: Vector2i, box: Rect2i) -> Vector2:
	var lean := Vector2.ZERO
	if p.x <= box.position.x + 1:
		lean.x -= BEVEL
	elif p.x >= box.end.x - 2:
		lean.x += BEVEL
	if p.y <= box.position.y + 1:
		lean.y -= BEVEL
	elif p.y >= box.end.y - 2:
		lean.y += BEVEL
	return lean


## One end tile: a length of `pipe` ([art, normal map]), ending toward `side`:
## [art, normal map].
func _end(pipe: Array, side: Vector2i, broken: bool, colours: Dictionary) -> Array:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var nrm := _flat(Vector2i(TILE, TILE))
	var horizontal := side.y == 0
	for y in TILE:
		for x in TILE:
			var along := _along(x, y, side)
			var across := y if horizontal else x
			var c: Color = pipe[0].get_pixel(x, y)
			if c.a == 0.0:
				continue   # not part of the pipe
			var end: int = BROKEN_END + JAGS[across % JAGS.size()] if broken else WALL_END
			if along > end:
				continue
			var n: Color = pipe[1].get_pixel(x, y)
			if broken and across > BAND.x + 1 and across < BAND.y - 1 and along >= end - 1:
				c = colours.hollow   # the inside of the pipe, at the break
				n = Color(1.0 - n.r, 1.0 - n.g, n.b)   # curving the other way: the tube's inside
			elif broken and along >= end - 4 and _scatter(x, y) < 0.35:
				c = colours.rust     # rust eating at the broken end
			img.set_pixel(x, y, c)
			nrm.set_pixel(x, y, n)
	if broken:
		if horizontal:
			_stain(img, side, colours)
	else:
		_flange(img, nrm, side, colours)
	return [img, nrm]


## How far (x, y) is toward `side`, from the far edge: 0 there, 31 at `side`'s edge.
func _along(x: int, y: int, side: Vector2i) -> int:
	match side:
		Vector2i.RIGHT:
			return x
		Vector2i.LEFT:
			return TILE - 1 - x
		Vector2i.DOWN:
			return y
		_:
			return TILE - 1 - y


## The point `along` / `across` from the end's side, as pixel coordinates.
func _at(along: int, across: int, side: Vector2i) -> Vector2i:
	match side:
		Vector2i.RIGHT:
			return Vector2i(along, across)
		Vector2i.LEFT:
			return Vector2i(TILE - 1 - along, across)
		Vector2i.DOWN:
			return Vector2i(across, along)
		_:
			return Vector2i(across, TILE - 1 - along)


## A steel collar fixed to the wall where the pipe goes in: outlined, lit from
## the top left, with a bolt either side of the pipe. A plate with bevelled
## edges on the normal map.
func _flange(img: Image, nrm: Image, side: Vector2i, colours: Dictionary) -> void:
	var corner := _corner(side)
	var a := _at(FLANGE.x, FLANGE_ACROSS.x, side)
	var b := _at(FLANGE.y, FLANGE_ACROSS.y, side)
	var plate := Rect2i(Vector2i(mini(a.x, b.x), mini(a.y, b.y)), (a - b).abs() + Vector2i.ONE)
	for along in range(FLANGE.x, FLANGE.y + 1):
		for across in range(FLANGE_ACROSS.x, FLANGE_ACROSS.y + 1):
			var p := _at(along, across, side)
			var c: Color = colours.mid
			if along == FLANGE.x or along == FLANGE.y or across == FLANGE_ACROSS.x or across == FLANGE_ACROSS.y:
				c = colours.dark
			elif p.x == corner.x or p.y == corner.y:
				c = colours.light
			img.set_pixel(p.x, p.y, c)
			nrm.set_pixelv(p, _encode(_bevel(p, plate)))
	var mid_along := (FLANGE.x + FLANGE.y) / 2
	for across in [FLANGE_ACROSS.x + 2, FLANGE_ACROSS.y - 2]:
		var bolt := _at(mid_along, across, side)
		img.set_pixel(bolt.x, bolt.y, colours.light.lightened(0.3))
		img.set_pixel(bolt.x + 1, bolt.y + 1, colours.dark)


## The flange's top-left inner pixel (its lit edges run along this row and column).
func _corner(side: Vector2i) -> Vector2i:
	var a := _at(FLANGE.x + 1, FLANGE_ACROSS.x + 1, side)
	var b := _at(FLANGE.y - 1, FLANGE_ACROSS.y - 1, side)
	return Vector2i(mini(a.x, b.x), mini(a.y, b.y))


## Rusty water run down the wall from under the broken end.
func _stain(img: Image, side: Vector2i, colours: Dictionary) -> void:
	for along in range(BROKEN_END - 3, BROKEN_END + 1):
		var length := 4 + (along * 7) % 5
		for down in range(BAND.y + 1, mini(BAND.y + 1 + length, TILE)):
			var p := _at(along, down, side)
			img.set_pixel(p.x, p.y, img.get_pixel(p.x, p.y).blend(colours.stain))


## The plain brick tile (RoomArt.WALLS[0]) the pipes are seen over.
func _brick() -> Image:
	var bricks := Image.load_from_file(ProjectSettings.globalize_path(BRICK_SHEET))
	bricks.convert(Image.FORMAT_RGBA8)
	return bricks.get_region(Rect2i(RoomArt.WALLS[0] * TILE, Vector2i(TILE, TILE)))


## The sheet laid over plain brick.
func _save_preview(sheet: Image) -> void:
	var brick := _brick()
	var img := Image.create(SHEET_SIZE.x * TILE, SHEET_SIZE.y * TILE, false, Image.FORMAT_RGBA8)
	for y in SHEET_SIZE.y:
		for x in SHEET_SIZE.x:
			img.blit_rect(brick, Rect2i(0, 0, TILE, TILE), Vector2i(x, y) * TILE)
	img.blend_rect(sheet, Rect2i(Vector2i.ZERO, sheet.get_size()), Vector2i.ZERO)
	img.resize(img.get_width() * PREVIEW_SCALE, img.get_height() * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(PREVIEW_PATH))
