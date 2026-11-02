extends SceneTree
## Draws the pipe end tiles into the wall sheet (art/tiles/background.png, row 6,
## at RoomArt.PIPE_ENDS) and writes a preview. Each end is built from the pipe
## tiles themselves, so it matches them: the plain brick tile (RoomArt.WALLS[0],
## which the pipe tiles are drawn over), with the pipe band copied up to the
## end, then
##   into the wall: a bolted flange the pipe disappears behind;
##   broken: a jagged edge, the hollow inside showing, rust, and (on a
##           horizontal pipe) a stain dripping down the brick below.
## Horizontal ends come in left and right, vertical ones in top and bottom.
## Run from the project folder, then tools/make_tilesets.gd:
##   godot --headless --path . --script res://tools/make_pipe_end_tiles.gd

const TILE := 32
const SHEET_PATH := "res://art/tiles/background.png"
const PREVIEW_PATH := "res://art/tiles/source/pipe_ends_preview.png"
const PREVIEW_SCALE := 4
const SHEET_ROWS := 7   # the sheet grows to this many rows to fit the ends

const BAND := Vector2i(11, 20)    # the pipe's rows (or columns) across the tile, edge to edge
const WALL_END := 21              # into the wall: the pipe runs this far toward its end...
const FLANGE := Vector2i(20, 23)  # ...under a flange this thick (along the pipe)...
const FLANGE_ACROSS := Vector2i(8, 23)   # ...and this wide (across it)
const BROKEN_END := 19            # broken: about this far, give or take the jagged edge
const JAGS := [0, -1, 1, -2, 0, 2, -1, 1, 0, -2]   # per row (or column) across the pipe


func _init() -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SHEET_PATH))
	sheet.convert(Image.FORMAT_RGBA8)
	if sheet.get_height() < SHEET_ROWS * TILE:
		var taller := Image.create(sheet.get_width(), SHEET_ROWS * TILE, false, Image.FORMAT_RGBA8)
		taller.blit_rect(sheet, Rect2i(Vector2i.ZERO, sheet.get_size()), Vector2i.ZERO)
		sheet = taller
	var brick := sheet.get_region(Rect2i(RoomArt.WALLS[0] * TILE, Vector2i(TILE, TILE)))
	var pipe_h := sheet.get_region(Rect2i(RoomArt.PIPE_H * TILE, Vector2i(TILE, TILE)))
	var pipe_v := sheet.get_region(Rect2i(RoomArt.PIPE_V * TILE, Vector2i(TILE, TILE)))
	var colours := _palette(pipe_h, brick)
	var ends := {
		RoomArt.PIPE_H_WALL_LEFT: _end(brick, pipe_h, Vector2i.LEFT, false, colours),
		RoomArt.PIPE_H_WALL_RIGHT: _end(brick, pipe_h, Vector2i.RIGHT, false, colours),
		RoomArt.PIPE_H_BROKEN_LEFT: _end(brick, pipe_h, Vector2i.LEFT, true, colours),
		RoomArt.PIPE_H_BROKEN_RIGHT: _end(brick, pipe_h, Vector2i.RIGHT, true, colours),
		RoomArt.PIPE_V_WALL_TOP: _end(brick, pipe_v, Vector2i.UP, false, colours),
		RoomArt.PIPE_V_WALL_BOTTOM: _end(brick, pipe_v, Vector2i.DOWN, false, colours),
		RoomArt.PIPE_V_BROKEN_TOP: _end(brick, pipe_v, Vector2i.UP, true, colours),
		RoomArt.PIPE_V_BROKEN_BOTTOM: _end(brick, pipe_v, Vector2i.DOWN, true, colours),
	}
	for cell in ends:
		sheet.blit_rect(ends[cell], Rect2i(0, 0, TILE, TILE), cell * TILE)
	sheet.save_png(ProjectSettings.globalize_path(SHEET_PATH))
	_save_preview(sheet, pipe_h, pipe_v)
	print("Wrote %d pipe ends to %s and %s" % [ends.size(), SHEET_PATH, PREVIEW_PATH])
	quit()


## The pipe's colours, read off the pipe tile: darkest (its outline), lightest
## (its highlight), the middle one, and its rust.
func _palette(pipe: Image, brick: Image) -> Dictionary:
	var found: Array[Color] = []
	var rust := Color8(120, 62, 32)
	for y in range(BAND.x, BAND.y + 1):
		for x in TILE:
			var c := pipe.get_pixel(x, y)
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


## One end tile: the pipe band (from `pipe`) over `brick`, ending toward `side`.
func _end(brick: Image, pipe: Image, side: Vector2i, broken: bool, colours: Dictionary) -> Image:
	var img := brick.duplicate() as Image
	var horizontal := side.y == 0
	for y in TILE:
		for x in TILE:
			var along := _along(x, y, side)
			var across := y if horizontal else x
			var c := pipe.get_pixel(x, y)
			if c == brick.get_pixel(x, y):
				continue   # not part of the pipe
			var end: int = BROKEN_END + JAGS[across % JAGS.size()] if broken else WALL_END
			if along > end:
				continue
			if broken and across > BAND.x + 1 and across < BAND.y - 1 and along >= end - 1:
				c = colours.hollow   # the inside of the pipe, at the break
			elif broken and along >= end - 4 and _noise(x, y) < 0.35:
				c = colours.rust     # rust eating at the broken end
			img.set_pixel(x, y, c)
	if broken:
		if horizontal:
			_stain(img, side, colours)
	else:
		_flange(img, side, colours)
	return img


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
## the top left, with a bolt either side of the pipe.
func _flange(img: Image, side: Vector2i, colours: Dictionary) -> void:
	for along in range(FLANGE.x, FLANGE.y + 1):
		for across in range(FLANGE_ACROSS.x, FLANGE_ACROSS.y + 1):
			var p := _at(along, across, side)
			var c: Color = colours.mid
			if along == FLANGE.x or along == FLANGE.y or across == FLANGE_ACROSS.x or across == FLANGE_ACROSS.y:
				c = colours.dark
			elif p.x == _corner(side, along, across).x or p.y == _corner(side, along, across).y:
				c = colours.light
			img.set_pixel(p.x, p.y, c)
	var mid_along := (FLANGE.x + FLANGE.y) / 2
	for across in [FLANGE_ACROSS.x + 2, FLANGE_ACROSS.y - 2]:
		var bolt := _at(mid_along, across, side)
		img.set_pixel(bolt.x, bolt.y, colours.light.lightened(0.3))
		img.set_pixel(bolt.x + 1, bolt.y + 1, colours.dark)


## The flange's top-left inner pixel (its lit edges run along this row and column).
func _corner(side: Vector2i, _along: int, _across: int) -> Vector2i:
	var a := _at(FLANGE.x + 1, FLANGE_ACROSS.x + 1, side)
	var b := _at(FLANGE.y - 1, FLANGE_ACROSS.y - 1, side)
	return Vector2i(mini(a.x, b.x), mini(a.y, b.y))


## Rusty water run down the brick from under the broken end.
func _stain(img: Image, side: Vector2i, colours: Dictionary) -> void:
	for along in range(BROKEN_END - 3, BROKEN_END + 1):
		var length := 4 + (along * 7) % 5
		for down in range(BAND.y + 1, mini(BAND.y + 1 + length, TILE)):
			var p := _at(along, down, side)
			img.set_pixel(p.x, p.y, img.get_pixel(p.x, p.y).blend(colours.stain))


## A fixed scatter in [0, 1) for each pixel, so reruns draw the same rust.
func _noise(x: int, y: int) -> float:
	return float((x * 73856093) ^ (y * 19349663) & 1023) / 1024.0


## Runs of pipe over the brick: wall - pipe - pipe - broken, both ways, and the same upright.
func _save_preview(sheet: Image, pipe_h: Image, pipe_v: Image) -> void:
	var img := Image.create(TILE * 11, TILE * 7, false, Image.FORMAT_RGBA8)
	var brick := sheet.get_region(Rect2i(RoomArt.WALLS[0] * TILE, Vector2i(TILE, TILE)))
	for y in 7:
		for x in 11:
			img.blit_rect(brick, Rect2i(0, 0, TILE, TILE), Vector2i(x, y) * TILE)
	var tile := func(cell: Vector2i) -> Image: return sheet.get_region(Rect2i(cell * TILE, Vector2i(TILE, TILE)))
	var rows := [
		[RoomArt.PIPE_H_WALL_LEFT, null, null, RoomArt.PIPE_H_BROKEN_RIGHT],
		[RoomArt.PIPE_H_BROKEN_LEFT, null, null, RoomArt.PIPE_H_WALL_RIGHT],
	]
	for r in rows.size():
		for i in rows[r].size():
			var t: Image = pipe_h if rows[r][i] == null else tile.call(rows[r][i])
			img.blit_rect(t, Rect2i(0, 0, TILE, TILE), Vector2i(1 + i, 1 + r * 3) * TILE)
	var columns := [
		[RoomArt.PIPE_V_WALL_TOP, null, null, null, RoomArt.PIPE_V_BROKEN_BOTTOM],
		[RoomArt.PIPE_V_BROKEN_TOP, null, null, null, RoomArt.PIPE_V_WALL_BOTTOM],
	]
	for c in columns.size():
		for i in columns[c].size():
			var t: Image = pipe_v if columns[c][i] == null else tile.call(columns[c][i])
			img.blit_rect(t, Rect2i(0, 0, TILE, TILE), Vector2i(7 + c * 2, 1 + i) * TILE)
	img.resize(img.get_width() * PREVIEW_SCALE, img.get_height() * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(PREVIEW_PATH))
