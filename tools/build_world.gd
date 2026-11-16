extends Node
## Builds the world's rooms (scenes/world/*.tscn) from the plans in ROOMS
## below, as ordinary room scenes you can then edit by hand. A room that
## already exists is left alone, so hand edits are safe: name a room to rebuild
## it from its plan (which replaces the scene). Run from the project folder:
##   godot --headless --path . res://tools/build_world.tscn               (missing rooms only)
##   godot --headless --path . res://tools/build_world.tscn -- hub vault  (rebuild these)
##
## A plan starts as solid ground with the inside carved out (`ceiling` rows of
## ground on top, `floor` rows below, one column each side), then its `ops`
## paint rectangles, in order: [what, x, y, width, height], in tiles from the
## top-left, where what is "#" ground, " " open, "=" catwalk, "^" spikes,
## "~" acid or "|" an arena gate. `doors` are 3 tiles tall on the left or
## right wall: {name, side, top (row), target}. `things` are placed by the
## cell they stand in (the cell above the floor): [what, x, y, ...]:
##   start, guard, crawler, sickly, pink, thug, ceiling (a crawler hanging
##   from the cell above), item (then its id in items/), warden / hawk (then
##   the arena, x, y, width, height).
## The wall behind is decorated the way the Decorate wall button does it.
## The room is printed as it's built ("D" door).

const TILE := 32
const TEMPLATE := "res://scenes/rooms/room_template.tscn"
const DOOR_HEIGHT := 3
const LIGHT_EVERY := 7   # columns between the bulbs hung under every ceiling and ledge, so no room is dark
const SCENES := {
	"crawler": "res://scenes/enemies/crawler_sewer.tscn", "ceiling": "res://scenes/enemies/crawler_sewer.tscn",
	"sickly": "res://scenes/enemies/crawler_sickly.tscn", "pink": "res://scenes/enemies/crawler_pink.tscn",
	"thug": "res://scenes/enemies/thug.tscn", "guard": "res://scenes/npcs/guard.tscn",
	"warden": "res://scenes/bosses/warden.tscn", "hawk": "res://scenes/bosses/harrier.tscn",
}
## Node names, and how far above the floor under its cell each one's origin is.
const PLACED := {
	"crawler": ["Crawler", 12.0], "sickly": ["SicklyCrawler", 12.0], "pink": ["PinkCrawler", 12.0],
	"thug": ["Thug", 22.0], "guard": ["Guard", 0.0], "warden": ["Warden", 36.0],
}

const ROOMS := {
	# The friendly start: nothing here hurts. The tall wall on the left is the
	# way up to the Vault, once you can wall jump.
	"entrance": {
		"root": "Entrance", "size": Vector2i(40, 26), "ceiling": 3, "floor": 2,
		"ops": [
			["#", 1, 13, 6, 11],     # the wall to the Vault's ledge
			["#", 22, 22, 4, 2],     # a step to jump onto,
			["=", 28, 20, 5, 1],     # and a catwalk from it: far from the wall, so they're no help up it
		],
		"doors": [
			{"name": "VaultDoor", "side": "left", "top": 10, "target": "vault"},
			{"name": "HubDoor", "side": "right", "top": 21, "target": "hub"},
		],
		"things": [["start", 11, 23]],
	},
	# The junction: the guard, the way down to the Tunnels, and the upper door
	# to the Span across a gap only a dash clears.
	"hub": {
		"root": "Hub", "size": Vector2i(50, 30), "ceiling": 3, "floor": 2,
		"ops": [
			["=", 10, 25, 5, 1], ["=", 15, 22, 5, 1], ["=", 10, 19, 5, 1], ["=", 15, 16, 5, 1],
			["#", 20, 13, 10, 2],    # this side of the gap
			["#", 40, 13, 9, 2],     # the far side, and the Span's door
		],
		"doors": [
			{"name": "EntranceDoor", "side": "left", "top": 25, "target": "entrance"},
			{"name": "SpanDoor", "side": "right", "top": 10, "target": "span"},
			{"name": "TunnelsDoor", "side": "right", "top": 25, "target": "tunnels"},
		],
		"things": [["start", 3, 27], ["guard", 7, 27]],
	},
	# The way to the Warden. The ledge up on the right, past a dash gap, holds
	# a Heart Container for when you come back.
	"tunnels": {
		"root": "Tunnels", "size": Vector2i(70, 22), "ceiling": 3, "floor": 2,
		"ops": [
			["^", 14, 20, 4, 1],
			["#", 34, 18, 6, 2],
			["=", 41, 15, 4, 1],
			["#", 46, 12, 5, 2],     # this side of the gap
			["#", 61, 12, 8, 2],     # the Heart Container's ledge
			["~", 55, 20, 3, 1],
			["=", 55, 18, 3, 1],
		],
		"doors": [
			{"name": "HubDoor", "side": "left", "top": 17, "target": "hub"},
			{"name": "WardenDoor", "side": "right", "top": 17, "target": "warden_arena"},
		],
		"things": [
			["start", 3, 19], ["crawler", 24, 19], ["crawler", 30, 19], ["ceiling", 27, 3],
			["thug", 47, 19], ["pink", 64, 19], ["item", 65, 11, "heart_container"],
		],
	},
	"warden_arena": {
		"root": "WardenArena", "size": Vector2i(42, 18), "ceiling": 4, "floor": 3,
		"ops": [
			["#", 1, 4, 8, 7],       # over the way in
			["|", 8, 11, 1, 4],
			["#", 37, 4, 4, 11],
		],
		"doors": [{"name": "TunnelsDoor", "side": "left", "top": 12, "target": "tunnels"}],
		"things": [["start", 3, 14], ["warden", 29, 14, 9, 4, 28, 11]],
	},
	# Past the Junction's gap, on the way to the Sin Hawk: two pits to dash
	# over, and a shaft up into the ceiling (wall jumps) to a Heart Container.
	"span": {
		"root": "Span", "size": Vector2i(66, 26), "ceiling": 11, "floor": 4,
		"ops": [
			[" ", 12, 22, 10, 2], ["^", 12, 24, 10, 1],
			["=", 38, 19, 4, 1], ["=", 43, 16, 5, 1],   # up to the shaft's mouth
			[" ", 44, 3, 3, 8],      # the shaft
			[" ", 47, 3, 6, 3],      # the Heart Container's alcove
			[" ", 49, 22, 10, 2], ["^", 49, 24, 10, 1],
			["=", 53, 22, 2, 1],     # a rest halfway over the second pit
		],
		"doors": [
			{"name": "HubDoor", "side": "left", "top": 19, "target": "hub"},
			{"name": "HawkDoor", "side": "right", "top": 19, "target": "hawk_arena"},
		],
		"things": [
			["start", 3, 21], ["ceiling", 24, 11], ["crawler", 27, 21], ["thug", 33, 21],
			["sickly", 62, 21], ["item", 50, 5, "heart_container"],
		],
	},
	"hawk_arena": {
		"root": "HawkArena", "size": Vector2i(34, 18), "ceiling": 3, "floor": 2,
		"ops": [
			["#", 1, 3, 4, 9],       # over the way in
			["|", 4, 12, 1, 4],
		],
		"doors": [{"name": "SpanDoor", "side": "left", "top": 13, "target": "span"}],
		"things": [["start", 2, 15], ["hawk", 26, 6, 5, 3, 28, 13]],
	},
	# Up the Entrance's wall: a Heart Container, and a Lead Core on its stand.
	"vault": {
		"root": "Vault", "size": Vector2i(30, 18), "ceiling": 3, "floor": 2,
		"ops": [
			["#", 8, 14, 3, 2],      # the Lead Core's stand
			["=", 14, 12, 4, 1],
		],
		"doors": [{"name": "EntranceDoor", "side": "right", "top": 13, "target": "entrance"}],
		"things": [["start", 26, 15], ["item", 9, 13, "lead_core"], ["item", 18, 15, "heart_container"]],
	},
}

var _cells := {}   # Vector2i -> what's there ("#", "=", "^", "~", "|", "D"); open cells left out
var _size := Vector2i.ZERO


func _ready() -> void:
	var asked := OS.get_cmdline_user_args()
	for id in ROOMS:
		var path: String = LevelData.ROOMS[id].scene
		if id in asked or not ResourceLoader.exists(path):
			_build(id, path)
		else:
			print("%s: kept (%s exists; name it to rebuild)" % [id, path])
	get_tree().quit()


func _at(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= _size.x or y >= _size.y:
		return "#"
	return _cells.get(Vector2i(x, y), " ")


func _fill(what: String, x: int, y: int, w: int, h: int) -> void:
	for cy in range(y, y + h):
		for cx in range(x, x + w):
			if what == " ":
				_cells.erase(Vector2i(cx, cy))
			else:
				_cells[Vector2i(cx, cy)] = what


func _build(id: String, path: String) -> void:
	var plan: Dictionary = ROOMS[id]
	_size = plan.size
	_cells.clear()
	_fill("#", 0, 0, _size.x, _size.y)
	_fill(" ", 1, plan.ceiling, _size.x - 2, _size.y - plan.ceiling - plan.floor)
	for op in plan.ops:
		_fill(op[0], op[1], op[2], op[3], op[4])
	for door in plan.doors:
		_fill("D", 0 if door.side == "left" else _size.x - 1, door.top, 1, DOOR_HEIGHT)

	var room: Room = load(TEMPLATE).instantiate()
	room.name = plan.root
	room.room = id
	_paint(room.terrain(), room.gates())
	room.decorate_wall()
	_light(room.background(), room.props())

	var entities := room.entities()
	entities.get_node("PlayerStart").free()
	var counts := {}
	for thing in plan.things:
		_place(entities, counts, thing)
	for door in plan.doors:
		var node := RoomDoor.new()
		node.name = door.name
		node.position = Vector2(0 if door.side == "left" else _size.x - 1, door.top) * TILE
		node.target_room = door.target
		node.height = DOOR_HEIGHT
		entities.add_child(node)
	_own(room, room)
	room.scene_file_path = ""   # a room of its own, not one inheriting the template
	var scene := PackedScene.new()
	var err := scene.pack(room)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		err = ResourceSaver.save(scene, path)
	print("%s -> %s (%s)" % [id, path, error_string(err)])
	for y in _size.y:
		var row := ""
		for x in _size.x:
			row += _at(x, y)
		print("  ", row)
	room.free()


## The Terrain and Gates tiles, picked the way the terrain brushes would, with
## everything past the room's edge counting as ground.
func _paint(terrain: TileMapLayer, gates: TileMapLayer) -> void:
	var by_sides := {}
	for r in RoomArt.TERRAIN.size():
		for c in RoomArt.TERRAIN[r].size():
			by_sides[RoomArt.TERRAIN[r][c]] = Vector2i(c, r)
	var last_spike := -1   # the spike just to the left, so neighbours differ
	for y in _size.y:
		for x in _size.x:
			var cell := Vector2i(x, y)
			match _at(x, y):
				"#":
					var sides := ""
					for d in [["N", Vector2i.UP], ["E", Vector2i.RIGHT], ["S", Vector2i.DOWN], ["W", Vector2i.LEFT]]:
						if _at(x + d[1].x, y + d[1].y) == "#":
							sides += d[0]
					terrain.set_cell(cell, 0, by_sides[sides])
				"~":
					terrain.set_cell(cell, 0, RoomArt.ACID_FILL if _at(x, y - 1) == "~" else RoomArt.ACID_TOP)
				"=":
					var left := _at(x - 1, y) == "="
					var right := _at(x + 1, y) == "="
					terrain.set_cell(cell, 0, RoomArt.PLAT_MID if left and right else RoomArt.PLAT_R if left
							else RoomArt.PLAT_L if right else RoomArt.PLAT_ONE)
				"^":
					var variant := absi(hash(cell)) % RoomArt.SPIKES.size()
					if _at(x - 1, y) == "^" and variant == last_spike:
						variant = (variant + 1) % RoomArt.SPIKES.size()
					last_spike = variant
					terrain.set_cell(cell, 0, RoomArt.SPIKES[variant])
				"D":
					terrain.set_cell(cell, 0, RoomArt.DOOR_TOP if _at(x, y - 1) == "#" else RoomArt.DOOR)
				"|":
					gates.set_cell(cell, 0, RoomArt.GATE_END if _at(x, y + 1) != "|" else RoomArt.GATE)


## Hangs lit bulbs under every ceiling and ledge, LIGHT_EVERY columns apart
## (Decorate wall hangs few, and leaves some dead), on plain brick only.
func _light(background: TileMapLayer, props: TileMapLayer) -> void:
	for y in range(1, _size.y):
		var since := LIGHT_EVERY / 2
		for x in _size.x:
			since += 1
			var cell := Vector2i(x, y)
			if _at(x, y - 1) != "#" or _at(x, y) != " ":
				continue
			if props.get_cell_atlas_coords(cell) == RoomArt.LIGHT_LIT:
				since = 0
			elif since >= LIGHT_EVERY and props.get_cell_source_id(cell) in [-1, RoomArt.PROPS_SOURCE] 					and background.get_cell_atlas_coords(cell) in RoomArt.WALLS 					and (props.get_cell_source_id(cell) == -1 or props.get_cell_atlas_coords(cell) == RoomArt.LIGHT_DEAD):
				props.set_cell(cell, RoomArt.PROPS_SOURCE, RoomArt.LIGHT_LIT)
				since = 0


func _place(entities: Node2D, counts: Dictionary, thing: Array) -> void:
	var what: String = thing[0]
	var cell := Vector2(thing[1], thing[2])
	var feet := (cell + Vector2(0.5, 1.0)) * TILE   # on the floor under its cell
	match what:
		"start":
			var start := PlayerStart.new()
			start.name = "PlayerStart"
			start.position = feet
			entities.add_child(start)
		"ceiling":
			var hanger := _add(entities, counts, what, "CeilingCrawler", (cell + Vector2(0.5, 0.0)) * TILE + Vector2(0, 12))
			hanger.set("on_ceiling", true)
		"item":
			var pickup := ItemPickup.new()
			pickup.item = load("res://items/%s.tres" % thing[3])
			_name(pickup, counts, String(thing[3]).to_pascal_case())
			pickup.position = feet - Vector2(0, ItemPickup.HOVER)
			entities.add_child(pickup)
		"hawk", "warden":
			var boss: Node2D
			if what == "hawk":
				boss = _add(entities, counts, what, "SinHawk", (cell + Vector2(0.5, 0.5)) * TILE)
			else:
				boss = _add(entities, counts, what, PLACED[what][0], feet - Vector2(0, PLACED[what][1]))
			var arena := Arena.new()
			arena.name = "Arena"
			arena.position = Vector2(thing[3], thing[4]) * TILE
			arena.size_tiles = Vector2i(thing[5], thing[6])
			entities.add_child(arena)
			arena.boss = NodePath("../" + boss.name)
		_:
			_add(entities, counts, what, PLACED[what][0], feet - Vector2(0, PLACED[what][1]))


## An instance of one of SCENES, named Base, Base2, Base3... in order.
func _add(entities: Node2D, counts: Dictionary, what: String, base: String, at: Vector2) -> Node2D:
	var node: Node2D = load(SCENES[what]).instantiate()
	_name(node, counts, base)
	node.position = at
	entities.add_child(node)
	return node


func _name(node: Node, counts: Dictionary, base: String) -> void:
	counts[base] = counts.get(base, 0) + 1
	node.name = base if counts[base] == 1 else "%s%d" % [base, counts[base]]


## Gives every node the room as owner so it's saved, except inside instanced scenes.
func _own(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		if child.scene_file_path == "":
			_own(child, root)
