class_name RoomArt
extends RefCounted
## Builds a room's tile art from its ASCII rows: solid terrain, one-way
## platforms, spikes, arena gates and acid on the
## main tile sheet, the warehouse wall behind (with windows the skyline shows
## through), and the far skyline as a parallax layer. Art only: collisions and
## hazards stay in main.gd.
##
## The wall is decorated automatically (windows, lights, posters, graffiti),
## seeded by the room name so it looks the same every visit. A room can instead
## give its own `background` rows in LevelData, using BACKGROUND_LEGEND.

const TILE := 32
const TILESET := preload("res://art/tiles/tileset.png")
const BACKGROUND := preload("res://art/tiles/background.png")
const SKYLINE := preload("res://art/backgrounds/skyline.png")

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
const ACID_FRAMES := 4
const ACID_FRAME_TIME := 0.24

const SKYLINE_SCROLL := Vector2(0.15, 0.0)  # x drifts slowly; y stays fixed on screen
const SKYLINE_SCREEN_BOTTOM := 450.0        # screen y of the skyline's bottom edge (the screen is 540 tall)

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

## For hand-made `background` rows. A piece's letter marks its top-left cell;
## the rest of its cells can be anything. "." knocks the wall out so the
## skyline shows (the wall around it gets a crumbled edge); any other
## character is plain wall.
const BACKGROUND_LEGEND := {
	"W": WINDOW_SMALL, "L": WINDOW_LARGE, "P": POSTERS, "G": GRAFFITI,
	"V": [LIGHT_LIT, Vector2i.ONE], "v": [LIGHT_DEAD, Vector2i.ONE],
	"-": [PIPE_H, Vector2i.ONE], "|": [PIPE_V, Vector2i.ONE], "+": [PIPE_JUNCTION, Vector2i.ONE],
	"s": [HAZARD, Vector2i.ONE], "g": [GIRDER, Vector2i.ONE],
}

# Automatic decoration spacing, in tiles.
const WINDOW_ROW_STEP := 9       # rows between window bands
const WINDOW_GAP := 10           # at least this much wall between windows in a band
const LIGHT_SPACING := 14
const LIGHT_SKIP_CHANCE := 0.4   # a spot that could take a light gets none
const LIGHT_LIT_CHANCE := 0.65
const WALL_ART_CHANCE := 0.04    # chance per spot for a poster or graffiti
const WALL_ART_GAP := 24         # tiles after one before the next can go up

var _rows: Array
var _w := 0
var _h := 0
var _rng := RandomNumberGenerator.new()
var _terrain_by_sides := {}
var _gates: TileMapLayer


func _init(rows: Array, width: int, height: int) -> void:
	_rows = rows
	_w = width
	_h = height
	for r in TERRAIN.size():
		for c in TERRAIN[r].size():
			_terrain_by_sides[TERRAIN[r][c]] = Vector2i(c, r)


## Adds the art under `parent`, behind anything added later. `background_rows`
## is the room's hand-made background, or empty for the automatic one.
func build(parent: Node2D, room: String, background_rows: Array) -> void:
	_rng.seed = hash(room)
	parent.add_child(_make_skyline())
	parent.add_child(_make_background(background_rows))
	parent.add_child(_make_foreground())
	_gates = _layer(TILESET, 0)
	_gates.name = "Gates"
	for coords in [GATE, GATE_END, GATE_UP]:
		_ensure_tile(_gates, coords)
	parent.add_child(_gates)
	set_gates_closed(false)


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
	if x < 0 or y < 0 or x >= _w or y >= _h:
		return "#"
	var row: String = _rows[y]
	return row[x] if x < row.length() else " "


func _layer(texture: Texture2D, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = TileSet.new()
	layer.tile_set.tile_size = Vector2i(TILE, TILE)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	layer.tile_set.add_source(source, 0)
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.z_index = z
	return layer


func _source(layer: TileMapLayer) -> TileSetAtlasSource:
	return layer.tile_set.get_source(0)


func _ensure_tile(layer: TileMapLayer, coords: Vector2i) -> void:
	if not _source(layer).has_tile(coords):
		_source(layer).create_tile(coords)


# --------------------------------------------------- Terrain and acid ----

func _make_foreground() -> TileMapLayer:
	var layer := _layer(TILESET, 0)
	layer.name = "Terrain"
	for coords in _terrain_by_sides.values() + [PLAT_L, PLAT_MID, PLAT_R, PLAT_ONE] + SPIKES:
		_ensure_tile(layer, coords)
	var last_spike := -1   # variant of the spike just to the left, so neighbours differ
	for coords in [ACID_TOP, ACID_FILL]:
		_source(layer).create_tile(coords)
		_source(layer).set_tile_animation_columns(coords, ACID_FRAMES)
		_source(layer).set_tile_animation_frames_count(coords, ACID_FRAMES)
		for f in ACID_FRAMES:
			_source(layer).set_tile_animation_frame_duration(coords, f, ACID_FRAME_TIME)
	for y in _h:
		for x in _w:
			match _ch(x, y):
				"#":
					var sides := ""
					for d in [["N", Vector2i.UP], ["E", Vector2i.RIGHT], ["S", Vector2i.DOWN], ["W", Vector2i.LEFT]]:
						if _ch(x + d[1].x, y + d[1].y) == "#":
							sides += d[0]
					layer.set_cell(Vector2i(x, y), 0, _terrain_by_sides[sides])
				"~":
					layer.set_cell(Vector2i(x, y), 0, ACID_FILL if _ch(x, y - 1) == "~" else ACID_TOP)
				"=":
					var left := _ch(x - 1, y) == "="
					var right := _ch(x + 1, y) == "="
					var plat := PLAT_MID if left and right else PLAT_R if left else PLAT_L if right else PLAT_ONE
					layer.set_cell(Vector2i(x, y), 0, plat)
				"^":
					var variant := absi(hash(Vector2i(x, y))) % SPIKES.size()
					if _ch(x - 1, y) == "^" and variant == last_spike:
						variant = (variant + 1) % SPIKES.size()
					last_spike = variant
					layer.set_cell(Vector2i(x, y), 0, SPIKES[variant])
	return layer


# ---------------------------------------------------------- Background ----

func _make_background(hand_rows: Array) -> TileMapLayer:
	var layer := _layer(BACKGROUND, -1)
	layer.name = "Background"
	# cell -> background sheet cell; cells left out stay open to the skyline.
	# Solid cells get wall too, so the terrain's ragged edges have brick behind them.
	var cells := {}
	for y in _h:
		for x in _w:
			cells[Vector2i(x, y)] = _pick_wall()
	if hand_rows.is_empty():
		_decorate(cells)
	else:
		_apply_hand_rows(cells, hand_rows)
		_break_edges(cells)
	for cell in cells:
		var coords: Vector2i = cells[cell]
		_ensure_tile(layer, coords)
		layer.set_cell(cell, 0, coords)
	return layer


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


func _apply_hand_rows(cells: Dictionary, hand_rows: Array) -> void:
	for y in hand_rows.size():
		var row: String = hand_rows[y]
		for x in row.length():
			var c := Vector2i(x, y)
			var ch := row[x]
			if ch == ".":
				cells.erase(c)
			elif BACKGROUND_LEGEND.has(ch):
				_put(cells, c, BACKGROUND_LEGEND[ch])


## Plain wall next to an opening gets a crumbled edge on each open side.
func _break_edges(cells: Dictionary) -> void:
	var sides := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var edges := {}
	for cell in cells:
		if not cells[cell] in WALLS:
			continue
		var open := 0
		for i in sides.size():
			var n: Vector2i = cell + sides[i]
			if n.x >= 0 and n.y >= 0 and n.x < _w and n.y < _h and not cells.has(n):
				open |= 1 << i
		if open != 0:
			edges[cell] = EDGE_ORIGIN + Vector2i(open % 8, open / 8)
	cells.merge(edges, true)


# ------------------------------------------------------------- Skyline ----

## The skyline repeats sideways and stays put vertically, its bottom edge a
## little above the bottom of the screen. Sky colour fills above it, ground
## colour below.
func _make_skyline() -> Parallax2D:
	var parallax := Parallax2D.new()
	parallax.name = "Skyline"
	parallax.scroll_scale = SKYLINE_SCROLL
	parallax.repeat_size = Vector2(SKYLINE.get_width(), 0)
	parallax.repeat_times = 2
	parallax.z_index = -2
	parallax.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var image := SKYLINE.get_image()
	var top := SKYLINE_SCREEN_BOTTOM - SKYLINE.get_height()
	var sky := ColorRect.new()
	sky.color = image.get_pixel(0, 0)
	sky.position = Vector2(0, top - 4000.0)
	sky.size = Vector2(SKYLINE.get_width(), 4000.0)
	parallax.add_child(sky)
	var ground := ColorRect.new()
	ground.color = image.get_pixel(0, image.get_height() - 1)
	ground.position = Vector2(0, SKYLINE_SCREEN_BOTTOM)
	ground.size = Vector2(SKYLINE.get_width(), 4000.0)
	parallax.add_child(ground)
	var sprite := Sprite2D.new()
	sprite.texture = SKYLINE
	sprite.centered = false
	sprite.position = Vector2(0, top)
	parallax.add_child(sprite)
	return parallax
