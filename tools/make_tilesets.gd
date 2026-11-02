extends SceneTree
## Builds the two TileSet resources rooms are painted with, from the tile
## sheets (art/tiles/tileset.png and background.png). Run from the project folder:
##   godot --headless --path . --script res://tools/make_tilesets.gd
##
## foreground_tileset.tres: terrain, one-way platforms, spikes, sewer water,
## gates, doors and moving platform tracks. background_tileset.tres: the brick
## wall, windows, decor, lights and broken-wall edges. Every tile carries custom
## data saying what it is, so the game reads behaviour from the tile, not from
## where it sits on a sheet:
##   kind   foreground: solid, platform, spikes, acid, gate, door, track
##          background: wall, window, decor, light
##   light  steady, broken or sign (a glow the room adds; FlickerLight)
## Terrain sets let the editor's terrain brush pick tiles by their neighbours:
##   foreground: concrete, catwalk, spikes, sewer, track (all Match Sides)
##   background: wall (Match Sides): plain brick in weighted random variants,
##               and the crumbled edge facing any unpainted (open) side.
##               Props (decor, windows, lights) count as wall to it, so
##               only a really empty cell gets an edge.
## Patterns (the TileMap panel's Patterns tab): the large window, whole.
## Rerun after changing a sheet's layout (it keeps each file's ID). Once rooms are painted, prefer
## editing the .tres in Godot over rerunning this (it rebuilds from scratch).

const FOREGROUND_PATH := "res://art/tiles/foreground_tileset.tres"
const BACKGROUND_PATH := "res://art/tiles/background_tileset.tres"
const TILE := Vector2i(32, 32)

# Terrain indexes in each tileset's terrain set 0.
const CONCRETE := 0
const CATWALK := 1
const SPIKES := 2
const SEWER := 3
const TRACK := 4
const WALL := 0

const SIDES := {
	"N": TileSet.CELL_NEIGHBOR_TOP_SIDE, "E": TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
	"S": TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, "W": TileSet.CELL_NEIGHBOR_LEFT_SIDE,
}


func _init() -> void:
	_save(_foreground(), FOREGROUND_PATH)
	_save(_background(), BACKGROUND_PATH)
	quit()


## Saves over the old file, keeping its ID so scenes still find it.
func _save(tileset: TileSet, path: String) -> void:
	var uid := ResourceLoader.get_resource_uid(path) if ResourceLoader.exists(path) else ResourceUID.INVALID_ID
	var err := ResourceSaver.save(tileset, path)
	if err == OK and uid != ResourceUID.INVALID_ID:
		err = ResourceSaver.set_uid(path, uid)
	print("Wrote %s (%s)" % [path, error_string(err)])


func _new_tileset(sheet_path: String, data_layers: Array, terrains: Array) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = TILE
	for i in data_layers.size():
		ts.add_custom_data_layer()
		ts.set_custom_data_layer_name(i, data_layers[i])
		ts.set_custom_data_layer_type(i, TYPE_STRING)
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)
	for i in terrains.size():
		ts.add_terrain(0)
		ts.set_terrain_name(0, i, terrains[i][0])
		ts.set_terrain_color(0, i, terrains[i][1])
	var source := TileSetAtlasSource.new()
	source.texture = load(sheet_path)
	source.texture_region_size = TILE
	ts.add_source(source, 0)
	return ts


## Creates a tile and sets its custom data; returns its TileData.
func _tile(ts: TileSet, coords: Vector2i, kind: String, light := "") -> TileData:
	var source: TileSetAtlasSource = ts.get_source(0)
	if not source.has_tile(coords):
		source.create_tile(coords)
	var data := source.get_tile_data(coords, 0)
	data.set_custom_data("kind", kind)
	if light != "":
		data.set_custom_data("light", light)
	return data


## Puts a tile in a terrain, connecting on the given sides ("NESW" letters).
func _terrain(data: TileData, terrain: int, sides: String, probability := 1.0) -> void:
	data.terrain_set = 0
	data.terrain = terrain
	for s in sides:
		data.set_terrain_peering_bit(SIDES[s], terrain)
	data.probability = probability


## A terrain tile that looks the same whatever is on its `free` sides (a
## pool's edges, a spike next to a wall). The brush needs a tile matching
## every side exactly, so this adds an alternative of it for each combination
## of the free sides connecting or not. Alternative 0 connects on all of them.
func _terrain_any(ts: TileSet, coords: Vector2i, kind: String, terrain: int, fixed: String, free: String, probability := 1.0) -> void:
	var source: TileSetAtlasSource = ts.get_source(0)
	_terrain(_tile(ts, coords, kind), terrain, fixed + free, probability)
	for combo in range(1, 1 << free.length()):
		var sides := fixed
		for i in free.length():
			if combo & (1 << i) == 0:
				sides += free[i]
		var alt := source.create_alternative_tile(coords)
		var data := source.get_tile_data(coords, alt)
		data.set_custom_data("kind", kind)
		_terrain(data, terrain, sides, probability)


func _foreground() -> TileSet:
	var ts := _new_tileset("res://art/tiles/tileset.png", ["kind", "light"], [
		["concrete", Color(0.6, 0.6, 0.62)], ["catwalk", Color(0.6, 0.35, 0.2)],
		["spikes", Color(0.6, 0.85, 0.8)], ["sewer", Color(0.45, 0.5, 0.05)],
		["track", Color(0.85, 0.7, 0.2)],
	])
	# Concrete: the 4x4 block, each tile connecting on the sides it's solid on.
	for r in RoomArt.TERRAIN.size():
		for c in RoomArt.TERRAIN[r].size():
			_terrain(_tile(ts, Vector2i(c, r), "solid"), CONCRETE, RoomArt.TERRAIN[r][c])
	# Catwalk: ends and middle connect sideways only.
	_terrain(_tile(ts, RoomArt.PLAT_L, "platform"), CATWALK, "E")
	_terrain(_tile(ts, RoomArt.PLAT_MID, "platform"), CATWALK, "EW")
	_terrain(_tile(ts, RoomArt.PLAT_R, "platform"), CATWALK, "W")
	_terrain(_tile(ts, RoomArt.PLAT_ONE, "platform"), CATWALK, "")
	# Spikes: four variants of one terrain, so the brush picks among them at
	# random, fitting next to more spikes or a wall on either side.
	for coords in RoomArt.SPIKES:
		_terrain_any(ts, coords, "spikes", SPIKES, "", "EW")
	# Sewer water: the surface where there's nothing above, fill below it. Both
	# animate, and fit against walls and the pool's floor on any side but the top.
	var source: TileSetAtlasSource = ts.get_source(0)
	for pair in [[RoomArt.ACID_TOP, ""], [RoomArt.ACID_FILL, "N"]]:
		_terrain_any(ts, pair[0], "acid", SEWER, pair[1], "ESW")
		source.set_tile_animation_columns(pair[0], RoomArt.ACID_FRAMES)
		source.set_tile_animation_frames_count(pair[0], RoomArt.ACID_FRAMES)
		for f in RoomArt.ACID_FRAMES:
			source.set_tile_animation_frame_duration(pair[0], f, RoomArt.ACID_FRAME_TIME)
	# Track for moving platforms: straight lines only, side to side or up and
	# down. Its tiles only connect along their own line, so the brush can't
	# make a corner or a junction.
	for i in 3:
		_terrain(_tile(ts, RoomArt.TRACK_H + Vector2i(i, 0), "track"), TRACK, ["E", "EW", "W"][i])
		_terrain(_tile(ts, RoomArt.TRACK_V + Vector2i(0, i), "track"), TRACK, ["S", "NS", "N"][i])
	# Gates and doors: painted tile by tile.
	for coords in [RoomArt.GATE, RoomArt.GATE_END, RoomArt.GATE_UP]:
		_tile(ts, coords, "gate")
	_tile(ts, RoomArt.DOOR, "door")
	_tile(ts, RoomArt.DOOR_TOP, "door", "sign")
	return ts


func _background() -> TileSet:
	var ts := _new_tileset("res://art/tiles/background.png", ["kind", "light"], [
		["wall", Color(0.45, 0.28, 0.25)],
	])
	# Plain brick in its weighted variants: the brush scatters them.
	for i in RoomArt.WALLS.size():
		_terrain(_tile(ts, RoomArt.WALLS[i], "wall"), WALL, "NESW", RoomArt.WALL_WEIGHTS[i])
	# Crumbled edges: tile n is open (connects to nothing) on its set bits.
	for n in range(1, 16):
		var sides := ""
		for b in 4:
			if n & (1 << b) == 0:
				sides += "NESW"[b]
		_terrain(_tile(ts, RoomArt.EDGE_ORIGIN + Vector2i(n % 8, n / 8), "wall"), WALL, sides)
	# Decor, windows and lights: painted tile by tile (or the large window as a
	# pattern). Each is wall to the brush (see _wall_prop).
	for coords in [RoomArt.HAZARD, RoomArt.PIPE_H, RoomArt.PIPE_V, RoomArt.GIRDER, RoomArt.PIPE_JUNCTION] + RoomArt.PIPE_ENDS:
		_wall_prop(_tile(ts, coords, "decor"))
	for piece in [RoomArt.POSTERS, RoomArt.GRAFFITI]:
		_piece(ts, piece, "decor")
	for piece in [RoomArt.WINDOW_SMALL, RoomArt.WINDOW_LARGE]:
		_piece(ts, piece, "window")
	_wall_prop(_tile(ts, RoomArt.LIGHT_LIT, "light", "steady"))
	_wall_prop(_tile(ts, RoomArt.LIGHT_DEAD, "light", "broken"))
	ts.add_pattern(_piece_pattern(RoomArt.WINDOW_LARGE))
	return ts


## A prop on the wall (a poster, a pipe, a window, a light) counts as wall to
## the wall brush: brick painted next to it stays plain, and only an empty cell
## gets a crumbled edge. Probability 0: the brush never paints one itself.
func _wall_prop(data: TileData) -> void:
	_terrain(data, WALL, "NESW", 0.0)


## A multi-tile piece as a pattern (the TileMap panel's Patterns tab), to place
## it whole in one click.
func _piece_pattern(piece: Array) -> TileMapPattern:
	var pattern := TileMapPattern.new()
	var size: Vector2i = piece[1]
	for y in size.y:
		for x in size.x:
			pattern.set_cell(Vector2i(x, y), 0, piece[0] + Vector2i(x, y), 0)   # alternative 0: its default is -1 (no tile)
	return pattern


## Every cell of a multi-tile piece ([top-left, size in tiles]).
func _piece(ts: TileSet, piece: Array, kind: String) -> void:
	var origin: Vector2i = piece[0]
	var size: Vector2i = piece[1]
	for y in size.y:
		for x in size.x:
			_wall_prop(_tile(ts, origin + Vector2i(x, y), kind))
