extends SceneTree
## One-off: turns each ASCII room in LevelData into an editor room scene, saved
## over its scene file (LevelData.ROOMS[room].scene). Run from the project folder:
##   godot --headless --path . --script res://tools/convert_ascii_rooms.gd
##
## Each room becomes a copy of scenes/rooms/room_template.tscn with:
##  - Terrain painted exactly as the ASCII room's art (same tiles, same spike
##    variants), and Gates painted shut on every "|" cell.
##  - Background: left unpainted with auto_decorate on (it decorates exactly as
##    before), except a room with hand-made `background` rows (the Aerie),
##    whose wall is painted as it was, with auto_decorate off.
##  - Entities: a PlayerStart for "P", crawler / knight scenes for "E", "c" and
##    "K" (palette left random), boss scenes for "B" and "F" with an Arena
##    covering the arena the ASCII room worked out, and a RoomDoor for each
##    column of ">" leading where the room's `doors` said.
## Kept in tools/ for reference; once the ASCII rows are gone it has nothing
## to read. Untyped on purpose: the room scripts use autoloads, which a
## --script run can't compile against up front.

const TILE := 32
const TEMPLATE := "res://scenes/rooms/room_template.tscn"
const SCENES := {
	"crawler": "res://scenes/enemies/crawler.tscn", "knight": "res://scenes/enemies/knight.tscn",
	"warden": "res://scenes/bosses/warden.tscn", "harrier": "res://scenes/bosses/harrier.tscn",
}
const ROOT_NAMES := {"start": "StartRoom", "boss": "BossRoom", "climb": "ClimbRoom", "aerie": "AerieRoom"}

var _grid := {}
var _w := 0
var _h := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for id in LevelData.ROOMS:
		if LevelData.ROOMS[id].has("rows"):
			_convert(id)
	quit()


func _ch(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= _w or y >= _h:
		return "#"
	return _grid.get(Vector2i(x, y), " ")


func _convert(id: String) -> void:
	var data: Dictionary = LevelData.ROOMS[id]
	var rows: Array = data.rows
	_grid.clear()
	_w = 0
	for row in rows:
		_w = maxi(_w, row.length())
	_h = rows.size()
	for y in _h:
		for x in rows[y].length():
			if rows[y][x] != " ":
				_grid[Vector2i(x, y)] = rows[y][x]
	var background_rows: Array = data.get("background", [])

	# The ASCII room's art, built the way it always was.
	var art := Node2D.new()
	RoomArt.new(_ch, _w, _h).build(art, id, background_rows)

	var room: Node2D = load(TEMPLATE).instantiate()
	room.name = ROOT_NAMES.get(id, id.capitalize() + "Room")
	room.set("room", id)
	var terrain: TileMapLayer = room.get_node("Terrain")
	var gates: TileMapLayer = room.get_node("Gates")
	var background: TileMapLayer = room.get_node("Background")
	_copy_layer(art.get_node("Terrain"), terrain)
	for cell in _grid:
		if _grid[cell] == "|":
			gates.set_cell(cell, 0, RoomArt.GATE_END if _ch(cell.x, cell.y + 1) != "|" else RoomArt.GATE)
	if background_rows.is_empty():
		room.set("auto_decorate", true)
	else:
		_copy_layer(art.get_node("Background"), background)
		room.set("auto_decorate", false)
	art.free()

	var entities: Node2D = room.get_node("Entities")
	entities.get_node("PlayerStart").free()
	_place_entities(room, entities, data.get("doors", {}))
	_own(room, room)
	room.scene_file_path = ""   # a standalone room, not one inheriting the template
	var scene := PackedScene.new()
	var err := scene.pack(room)
	if err == OK:
		err = ResourceSaver.save(scene, data.scene)
	print("%s -> %s: %d x %d tiles, %d entities (%s)" % [id, data.scene, _w, _h, entities.get_child_count(), error_string(err)])
	room.free()


func _copy_layer(from: TileMapLayer, to: TileMapLayer) -> void:
	for cell in from.get_used_cells():
		to.set_cell(cell, from.get_cell_source_id(cell), from.get_cell_atlas_coords(cell), from.get_cell_alternative_tile(cell))


func _place_entities(room: Node2D, entities: Node2D, doors: Dictionary) -> void:
	var counts := {}
	for y in _h:
		for x in _w:
			var origin := Vector2(x * TILE, y * TILE)
			match _ch(x, y):
				"P":
					var start := Node2D.new()
					start.set_script(load("res://scripts/player_start.gd"))
					start.name = "PlayerStart"
					start.position = origin + Vector2(TILE * 0.5, TILE)
					entities.add_child(start)
				"E":
					_add(entities, counts, "crawler", "Crawler", origin + Vector2(TILE * 0.5, TILE - 12))
				"c":
					var hanger := _add(entities, counts, "crawler", "CeilingCrawler", origin + Vector2(TILE * 0.5, 12))
					hanger.set("on_ceiling", true)
				"K":
					_add(entities, counts, "knight", "Knight", origin + Vector2(TILE * 0.5, TILE - 22))
				"B":
					var warden := _add(entities, counts, "warden", "Warden", origin + Vector2(TILE * 0.5, TILE - 36))
					_add_arena(entities, warden, x, y)
				"F":
					var harrier := _add(entities, counts, "harrier", "Harrier", origin + Vector2(TILE * 0.5, TILE * 0.5))
					_add_arena(entities, harrier, x, y)
	# Each column of ">" is a door, leading to the room on its wall's side.
	for x in _w:
		var y := 0
		while y < _h:
			if _ch(x, y) == ">":
				var top := y
				while _ch(x, y) == ">":
					y += 1
				var side := "left" if x * 2 < _w else "right"
				var door := Node2D.new()
				door.set_script(load("res://scripts/room_door.gd"))
				door.name = side.capitalize() + "Door"
				door.position = Vector2(x * TILE, top * TILE)
				door.set("target_room", doors[side])
				door.set("height", y - top)
				entities.add_child(door)
			y += 1


## An instance of one of SCENES, named Base, Base2, Base3... in order.
func _add(entities: Node2D, counts: Dictionary, scene: String, base: String, at: Vector2) -> Node2D:
	counts[base] = counts.get(base, 0) + 1
	var node: Node2D = load(SCENES[scene]).instantiate()
	node.name = base if counts[base] == 1 else "%s%d" % [base, counts[base]]
	node.position = at
	entities.add_child(node)
	return node


## The arena the ASCII room worked out for a boss at (x, y): out to the nearest
## wall or gate on each side of its row, up and down to the nearest solid tile.
func _add_arena(entities: Node2D, boss: Node2D, x: int, y: int) -> void:
	var left := x
	while not _ch(left - 1, y) in ["#", "|"]:
		left -= 1
	var right := x
	while not _ch(right + 1, y) in ["#", "|"]:
		right += 1
	var top := y
	while _ch(x, top - 1) != "#":
		top -= 1
	var bottom := y
	while _ch(x, bottom + 1) != "#":
		bottom += 1
	var arena := Node2D.new()
	arena.set_script(load("res://scripts/arena.gd"))
	arena.name = "Arena"
	arena.position = Vector2(left * TILE, top * TILE)
	arena.set("size_tiles", Vector2i(right - left + 1, bottom - top + 1))
	arena.set("boss", NodePath("../" + boss.name))
	entities.add_child(arena)


## Gives every node the room as owner so it's saved, except inside instanced scenes.
func _own(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		if child.scene_file_path == "":
			_own(child, root)
