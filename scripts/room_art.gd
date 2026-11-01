class_name RoomArt
extends RefCounted
## A room's tile art, for a room made in the editor: dress() adds what the
## painted layers don't hold (light glows, the gates' open/shut state) and the
## automatic wall decoration where the wall is unpainted. Art only: collisions
## and hazards are the room's (room.gd). The tile constants here are where each
## tile sits in its sheet; tools/make_tilesets.gd builds the tilesets from them.
##
## Automatic decoration (windows, lights, posters, graffiti) is seeded by the
## room name so it looks the same every visit.

const TILE := 32
## Built by tools/make_tilesets.gd; every tile says what it is in its custom data.
const FOREGROUND_TILES := preload("res://art/tiles/foreground_tileset.tres")
const BACKGROUND_TILES := preload("res://art/tiles/background_tileset.tres")
const BACKGROUND := preload("res://art/tiles/background.png")

# Solid neighbours (N, E, S, W) of each cell in the tileset's 4x4 terrain block,
# as in tools/make_art_templates.gd.
const TERRAIN := [
	["S", "ES", "ESW", "SW"],
	["NS", "NES", "NESW", "NSW"],
	["N", "NE", "NEW", "NW"],
	["", "E", "EW", "W"],
]
const ACID_TOP := Vector2i(0, 5)
const ACID_FILL := Vector2i(4, 5)
const PLAT_L := Vector2i(0, 4)
const PLAT_MID := Vector2i(1, 4)
const PLAT_R := Vector2i(2, 4)
const PLAT_ONE := Vector2i(3, 4)
const SPIKES := [Vector2i(4, 4), Vector2i(5, 4), Vector2i(3, 6), Vector2i(4, 6)]
const GATE := Vector2i(6, 4)       # shut: the shutter, repeating down the column
const GATE_END := Vector2i(7, 4)   # shut: its bottom tile, with the teeth
const GATE_UP := Vector2i(0, 6)    # raised: just the teeth under the lintel
const DOOR := Vector2i(1, 6)
const DOOR_TOP := Vector2i(2, 6)   # under solid ground: lintel and EXIT sign
const TRACK_H := Vector2i(4, 0)    # moving platform track, side to side: left end, middle, right end
const TRACK_V := Vector2i(7, 0)    # up and down: top end, middle, bottom end (going down the sheet)

# Light glows (see FlickerLight). Positions are within the light's tile.
const BULB_GLOW := Color(0.78, 1.0, 0.9)
const BULB_GLOW_CENTRE := Vector2(16, 22)
const BULB_GLOW_SIZE := Vector2i(56, 56)
const BULB_GLOW_STRENGTH := 0.22
const SIGN_GLOW := Color(1.0, 0.25, 0.25)
const SIGN_GLOW_CENTRE := Vector2(16, 12)
const SIGN_GLOW_SIZE := Vector2i(40, 24)
const SIGN_GLOW_STRENGTH := 0.3
const SIGN_LETTERS := Rect2(8, 9, 16, 7)   # inside the sign's frame (tools/make_door_tiles.gd)
const SIGN_OFF := Color8(52, 10, 14)        # the sign box's colour, covering the letters when it's out
const ACID_FRAMES := 4
const ACID_FRAME_TIME := 0.24


# Background sheet cells (art/tiles/background.png). Pieces bigger than one
# tile give their top-left cell and size.
const WALLS := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
const WALL_WEIGHTS := [0.475, 0.475, 0.03, 0.02]   # plain, plain, stained, broken
const HAZARD := Vector2i(4, 0)
const PIPE_H := Vector2i(5, 0)
const PIPE_V := Vector2i(6, 0)
const GIRDER := Vector2i(7, 0)
const PIPE_JUNCTION := Vector2i(0, 3)
const WINDOW_SMALL := [Vector2i(0, 1), Vector2i(2, 2)]
const WINDOW_LARGE := [Vector2i(2, 1), Vector2i(3, 2)]
const POSTERS := [Vector2i(5, 1), Vector2i(2, 1)]
const GRAFFITI := [Vector2i(5, 2), Vector2i(2, 1)]
const LIGHT_LIT := Vector2i(7, 1)
const LIGHT_DEAD := Vector2i(7, 2)
# Broken wall around a hole: tile n has bit 1 = N open, 2 = E, 4 = S, 8 = W,
# at EDGE_ORIGIN + (n % 8, n / 8). See tools/make_background_tiles.gd.
const EDGE_ORIGIN := Vector2i(0, 4)

# Automatic decoration spacing, in tiles.
const WINDOW_ROW_STEP := 9       # rows between window bands
const WINDOW_GAP := 10           # at least this much wall between windows in a band
const LIGHT_SPACING := 14
const LIGHT_SKIP_CHANCE := 0.4   # a spot that could take a light gets none
const LIGHT_LIT_CHANCE := 0.65
const WALL_ART_CHANCE := 0.04    # chance per spot for a poster or graffiti
const WALL_ART_GAP := 24         # tiles after one before the next can go up

var _cell: Callable
var _w := 0
var _h := 0
var _rng := RandomNumberGenerator.new()
var _gates: TileMapLayer


## `cell` answers what's at (x, y) as a layout character ("#" solid, "="
## platform, "^" spikes, "~" sewer, "|" gate, ">" door, " " empty), with
## anything outside the room solid.
func _init(cell: Callable, width: int, height: int) -> void:
	_cell = cell
	_w = width
	_h = height


## For a room made in the editor, whose tile layers are already painted: adds
## the light glows, shows its gates raised, and (with `auto_decorate`) fills
## the wall you haven't painted with brick, windows, lights and posters. Hand-
## painted wall is kept as it is. Seeded by `room`, so it's the same every time.
func dress(parent: Node2D, room: String, background: TileMapLayer, terrain: TileMapLayer,
		gates: TileMapLayer, auto_decorate: bool) -> void:
	_gates = gates
	set_gates_closed(false)
	if auto_decorate:
		decorate_unpainted(room, background)
	_add_lights(parent, background, terrain)


## Paints brick, windows, lights, posters and graffiti into every cell of the
## room's wall that isn't painted yet. Seeded by `room`: the same every time.
func decorate_unpainted(room: String, background: TileMapLayer) -> void:
	_rng.seed = hash(room)
	var cells := {}
	for y in _h:
		for x in _w:
			var c := Vector2i(x, y)
			if background.get_cell_source_id(c) == -1:
				cells[c] = _pick_wall()
	_decorate(cells)
	for c in cells:
		background.set_cell(c, 0, cells[c])


## Glows for every tile whose `light` data says it has one: lit bulbs, dead
## bulbs (which sputter, showing the lit bulb over the dead one while they're
## on) and EXIT signs (which blink, darkening their letters while they're out).
func _add_lights(parent: Node2D, background: TileMapLayer, foreground: TileMapLayer) -> void:
	for layer in [background, foreground]:
		for cell in layer.get_used_cells():
			var data: TileData = layer.get_cell_tile_data(cell)
			match data.get_custom_data("light") if data != null else "":
				"steady":
					_add_light(parent, cell, FlickerLight.Kind.STEADY, null, null)
				"broken":
					_add_broken_light(parent, cell)
				"sign":
					_add_sign(parent, cell)


func _add_broken_light(parent: Node2D, cell: Vector2i) -> void:
	var lit := Sprite2D.new()
	lit.texture = BACKGROUND
	lit.region_enabled = true
	lit.region_rect = Rect2(LIGHT_LIT * TILE, Vector2(TILE, TILE))
	lit.centered = false
	lit.position = Vector2(cell * TILE)
	lit.z_index = -1
	lit.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(lit)
	_add_light(parent, cell, FlickerLight.Kind.BROKEN, lit, null)


func _add_sign(parent: Node2D, cell: Vector2i) -> void:
	var dark := ColorRect.new()
	dark.color = SIGN_OFF
	dark.position = Vector2(cell * TILE) + SIGN_LETTERS.position
	dark.size = SIGN_LETTERS.size
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(dark)
	_add_light(parent, cell, FlickerLight.Kind.SIGN, null, dark)


func _add_light(parent: Node2D, cell: Vector2i, kind: FlickerLight.Kind, lit: CanvasItem, dark: CanvasItem) -> void:
	var light := FlickerLight.new()
	light.kind = kind
	light.lit_overlay = lit
	light.dim_overlay = dark
	if kind == FlickerLight.Kind.SIGN:
		light.position = Vector2(cell * TILE) + SIGN_GLOW_CENTRE
		light.glow_size = SIGN_GLOW_SIZE
		light.glow_color = SIGN_GLOW
		light.glow_strength = SIGN_GLOW_STRENGTH
	else:
		light.position = Vector2(cell * TILE) + BULB_GLOW_CENTRE
		light.glow_size = BULB_GLOW_SIZE
		light.glow_color = BULB_GLOW
		light.glow_strength = BULB_GLOW_STRENGTH
		light.z_index = -1
	parent.add_child(light)


## Shows the arena gates (`|`) shut, or raised with only their teeth showing.
func set_gates_closed(closed: bool) -> void:
	_gates.clear()
	for y in _h:
		for x in _w:
			if _ch(x, y) != "|":
				continue
			if closed:
				_gates.set_cell(Vector2i(x, y), 0, GATE_END if _ch(x, y + 1) != "|" else GATE)
			elif _ch(x, y - 1) != "|":
				_gates.set_cell(Vector2i(x, y), 0, GATE_UP)


func _ch(x: int, y: int) -> String:
	return _cell.call(x, y)


func _pick_wall() -> Vector2i:
	var roll := _rng.randf()
	for i in WALLS.size():
		roll -= WALL_WEIGHTS[i]
		if roll < 0.0:
			return WALLS[i]
	return WALLS[0]


func _put(cells: Dictionary, at: Vector2i, piece: Array) -> void:
	var origin: Vector2i = piece[0]
	var size: Vector2i = piece[1]
	for dy in size.y:
		for dx in size.x:
			cells[at + Vector2i(dx, dy)] = origin + Vector2i(dx, dy)


## True if `size` fits at `at` with a `margin` of open wall around it, clear of
## solid ground and of anything already placed.
func _fits(cells: Dictionary, at: Vector2i, size: Vector2i, margin: int, used: Dictionary) -> bool:
	for y in range(at.y - margin, at.y + size.y + margin):
		for x in range(at.x - margin, at.x + size.x + margin):
			var c := Vector2i(x, y)
			if _ch(x, y) == "#" or not cells.has(c) or used.has(c):
				return false
	return true


func _mark(used: Dictionary, at: Vector2i, size: Vector2i) -> void:
	for y in size.y:
		for x in size.x:
			used[at + Vector2i(x, y)] = true


func _decorate(cells: Dictionary) -> void:
	var used := {}
	# Windows: bands of them up the room, high enough to clear the floor.
	for y in range(1 + _rng.randi_range(0, 2), _h - 3, WINDOW_ROW_STEP):
		var x := 1 + _rng.randi_range(0, 3)
		while x < _w - 2:
			var piece: Array = WINDOW_LARGE if _rng.randf() < 0.4 else WINDOW_SMALL
			var size: Vector2i = piece[1]
			if _fits(cells, Vector2i(x, y), size, 1, used):
				_put(cells, Vector2i(x, y), piece)
				_mark(used, Vector2i(x, y), size)
				x += size.x + WINDOW_GAP + _rng.randi_range(0, 3)
			else:
				x += 1
	# Lights hang from ceilings.
	var since_light := LIGHT_SPACING
	for y in range(1, _h):
		for x in _w:
			since_light += 1
			var c := Vector2i(x, y)
			if since_light >= LIGHT_SPACING and _ch(x, y - 1) == "#" and _ch(x, y) != "#" and not used.has(c):
				since_light = _rng.randi_range(0, 3)
				if _rng.randf() < LIGHT_SKIP_CHANCE:
					continue
				cells[c] = LIGHT_LIT if _rng.randf() < LIGHT_LIT_CHANCE else LIGHT_DEAD
				used[c] = true
	# Posters and graffiti at head height above a floor, spread out.
	for y in range(0, _h - 2):
		var x := 0
		while x < _w - 1:
			if _ch(x, y + 2) != "#" or _ch(x + 1, y + 2) != "#" or _rng.randf() > WALL_ART_CHANCE:
				x += 1
				continue
			var piece: Array = POSTERS if _rng.randf() < 0.5 else GRAFFITI
			if _fits(cells, Vector2i(x, y), piece[1], 0, used) and _fits(cells, Vector2i(x, y + 1), Vector2i(2, 1), 0, used):
				_put(cells, Vector2i(x, y), piece)
				_mark(used, Vector2i(x, y), piece[1])
				x += WALL_ART_GAP
			x += 1
