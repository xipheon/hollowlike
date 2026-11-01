@tool
class_name Room
extends Node2D
## A room: builds collisions, hazards, gates and doors from its layout, sets up
## its boss fight, and runs it (HUD, pause menu, death, the boss intro and
## camera). The layout comes from one of two places while the overhaul is under
## way:
##  - Made in the editor (start from scenes/rooms/room_template.tscn):
##      Skyline     the far city, behind everything
##      Background  the wall behind the room (background_tileset.tres)
##      Terrain     what you stand on and what hurts (foreground_tileset.tres)
##      Gates       arena gates, shut during a boss fight (foreground_tileset.tres)
##      Entities    placed enemies and bosses, a PlayerStart, RoomDoors, Arenas
##    Paint from the room's top-left (0, 0). What each tile does comes from its
##    custom data `kind` (see tools/make_tilesets.gd).
##  - ASCII rows in LevelData (the rooms not converted yet): leave the layers
##    empty and set `room`; the art is built from the rows.
## Both become the same grid of layout characters ("#" solid, "=" platform,
## "^" spikes, "~" sewer water, "|" gate, ">" door), so the rest of the room
## doesn't care where it came from. Does nothing while editing.

const TILE := 32
const CRAWLER_SCENE := preload("res://scenes/enemies/crawler.tscn")
const KNIGHT_SCENE := preload("res://scenes/enemies/knight.tscn")
const LAYER_WORLD := 1
const LAYER_PLATFORMS := 32
const SPIKE_HEIGHT := 24.0   # damage area: the bottom of the tile, up to the spike tips
const ARENA_TRIGGER_INSET := 3   # tiles past a gate before the boss fight starts
const INTRO_ZOOM := 2.2
const INTRO_ZOOM_IN_TIME := 0.7
const INTRO_TITLE_FADE_TIME := 0.4
const INTRO_HOLD_TIME := 1.2
const INTRO_ZOOM_OUT_TIME := 0.8
const CAMERA_RELEASE_TIME := 0.6
## A painted tile's `kind` as a layout character.
const KIND_CHARS := {"solid": "#", "platform": "=", "spikes": "^", "acid": "~", "door": ">", "gate": "|"}

## This room's id in LevelData.ROOMS.
@export var room := ""
## Fill the parts of the wall you haven't painted with brick, windows, lights,
## posters and graffiti when the room loads (the same every time). Wall you
## paint by hand is always kept as it is. Off: unpainted wall stays open, and
## the skyline shows through.
@export var auto_decorate := true

var _grid := {}   # Vector2i -> layout character
var _from_ascii := false   # built from LevelData rows (decided before the art adds its layers)
var _art: RoomArt
var _w := 0
var _h := 0
var _player: Player
var _hud: HUD
var _boss: BossBase
var _boss_fight_started := false
var _gate_shapes: Array[CollisionShape2D] = []
var _gate_closed := false
var _arena_center := Vector2.ZERO
var _arena_camera: Camera2D   # current camera from the boss intro until the boss dies
## [{rect: Rect2i in cells, target: room id, arrive_at: door name, name: String}]
var _doors: Array[Dictionary] = []


func background() -> TileMapLayer:
	return get_node_or_null("Background")


func terrain() -> TileMapLayer:
	return get_node_or_null("Terrain")


func gates() -> TileMapLayer:
	return get_node_or_null("Gates")


func entities() -> Node2D:
	return get_node_or_null("Entities")


## Made in the editor (painted layers), as opposed to built from ASCII rows.
func is_painted() -> bool:
	return terrain() != null and not terrain().get_used_cells().is_empty()


## Every node under Entities that is a `type` (a script class, e.g. RoomDoor).
func entities_of(type: Variant) -> Array:
	if entities() == null:
		return []
	return entities().find_children("*", "", true, false).filter(func(n): return is_instance_of(n, type))


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	Engine.time_scale = 1.0
	_from_ascii = not is_painted() and LevelData.ROOMS.has(room) and LevelData.ROOMS[room].has("rows")
	if not _from_ascii:
		_load_painted()
	else:
		_load_ascii()
	_build_solids()
	_spawn_player()
	_hud = HUD.new()
	add_child(_hud)
	_hud.bind_player(_player)
	_player.died.connect(_on_player_died)
	add_child(PauseMenu.new())


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# The fight starts once you're a few tiles into the arena, from either side.
	if _boss != null and not _boss_fight_started:
		var x := _player.global_position.x
		var y := _player.global_position.y
		var inset := ARENA_TRIGGER_INSET * TILE
		if x > _boss.arena_left + inset and x < _boss.arena_right - inset and y > _boss.arena_top and y < _boss.arena_bottom:
			_start_boss_fight()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	elif GameState.debug_mode and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			GameState.unlock("dash")
		elif event.keycode == KEY_F2:
			GameState.unlock("wall_jump")
		elif event.keycode == KEY_F3:
			debug_kill_boss()


func _on_player_died() -> void:
	_hud.show_message("YOU DIED", 3.0)
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()


# ------------------------------------------------------------ Layout ----

## What's at (x, y) as a layout character; anything outside the room is solid.
func _ch(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= _w or y >= _h:
		return "#"
	return _grid.get(Vector2i(x, y), " ")


## A room made in the editor: the grid comes from the painted tiles' kinds, and
## doors, the player start and bosses from the nodes under Entities.
func _load_painted() -> void:
	var used := Rect2i()
	for layer in [terrain(), gates(), background()]:
		if layer != null and not layer.get_used_cells().is_empty():
			used = layer.get_used_rect() if used.size == Vector2i.ZERO else used.merge(layer.get_used_rect())
	_w = used.end.x
	_h = used.end.y
	for layer in [terrain(), gates()]:
		for cell in layer.get_used_cells():
			var kind: String = layer.get_cell_tile_data(cell).get_custom_data("kind")
			if KIND_CHARS.has(kind):
				_grid[cell] = KIND_CHARS[kind]
	_art = RoomArt.new(_ch, _w, _h)
	_art.dress(self, room, background(), terrain(), gates(), auto_decorate)
	for door in entities_of(RoomDoor):
		var at := Vector2i((to_local(door.global_position) / TILE).round())
		_doors.append({"rect": Rect2i(at, Vector2i(1, door.height)), "target": door.target_room,
				"arrive_at": door.arrive_at, "name": String(door.name)})
	for arena in entities_of(Arena):
		var boss: BossBase = arena.get_node_or_null(arena.boss)
		if boss != null:
			_set_up_boss(boss, Rect2(to_local(arena.global_position), Vector2(arena.size_tiles * TILE)))


## A room from LevelData's ASCII rows: the grid is the rows; art, enemies,
## bosses and doors come from their characters.
func _load_ascii() -> void:
	var rows: Array = LevelData.ROOMS[room].rows
	for row in rows:
		_w = maxi(_w, row.length())
	_h = rows.size()
	for y in _h:
		var row: String = rows[y]
		for x in row.length():
			if row[x] != " ":
				_grid[Vector2i(x, y)] = row[x]
	_art = RoomArt.new(_ch, _w, _h)
	_art.build(self, room, LevelData.ROOMS[room].get("background", []))
	_spawn_ascii_entities()
	# Each column of ">" is a door, leading to the room on its wall's side.
	for x in _w:
		var y := 0
		while y < _h:
			if _ch(x, y) == ">":
				var top := y
				while _ch(x, y) == ">":
					y += 1
				var side := "left" if x * 2 < _w else "right"
				_doors.append({"rect": Rect2i(x, top, 1, y - top), "target": LevelData.ROOMS[room].doors[side],
						"arrive_at": "", "name": side})
			y += 1


func _spawn_ascii_entities() -> void:
	for y in _h:
		for x in _w:
			var tile_origin := Vector2(x * TILE, y * TILE)
			match _ch(x, y):
				"E":
					var enemy: CrawlerEnemy = CRAWLER_SCENE.instantiate()
					enemy.position = tile_origin + Vector2(TILE * 0.5, TILE - CrawlerEnemy.SIZE.y * 0.5)
					add_child(enemy)
				"c":
					var hanger: CrawlerEnemy = CRAWLER_SCENE.instantiate()
					hanger.on_ceiling = true
					hanger.position = tile_origin + Vector2(TILE * 0.5, CrawlerEnemy.SIZE.y * 0.5)
					add_child(hanger)
				"K":
					var knight: KnightEnemy = KNIGHT_SCENE.instantiate()
					knight.position = tile_origin + Vector2(TILE * 0.5, TILE - KnightEnemy.SIZE.y * 0.5)
					add_child(knight)
				"B":
					var warden := WardenBoss.new()
					warden.position = tile_origin + Vector2(TILE * 0.5, TILE - WardenBoss.SIZE.y * 0.5)
					add_child(warden)
					_set_up_boss(warden, _ascii_arena(x, y))
				"F":
					var harrier := HarrierBoss.new()
					harrier.position = tile_origin + Vector2(TILE * 0.5, TILE * 0.5)
					add_child(harrier)
					_set_up_boss(harrier, _ascii_arena(x, y))


## An ASCII boss's arena: out to the nearest wall or gate on each side of its
## row, and up and down to the nearest solid tile (platforms don't count).
func _ascii_arena(x: int, y: int) -> Rect2:
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
	return Rect2(left * TILE, top * TILE, (right - left + 1) * TILE, (bottom - top + 1) * TILE)


func _build_solids() -> void:
	var body := _make_static_body(LAYER_WORLD)
	# One-way platforms get their own layer so heavy enemies (the boss) can ignore them.
	var platforms := _make_static_body(LAYER_PLATFORMS)

	# Merge horizontal runs into single shapes (avoids snagging on tile seams).
	for y in range(-1, _h + 1):
		var x := -1
		while x <= _w:
			var c := _ch(x, y)
			if c == "#" or c == "=":
				var start := x
				while x <= _w and _ch(x, y) == c:
					x += 1
				var rect := Rect2(start * TILE, y * TILE, (x - start) * TILE, TILE)
				if c == "=":
					rect.size.y = 10.0
					_add_shape(platforms, rect, true)
				else:
					_add_shape(body, rect, false)
			else:
				x += 1

	for y in _h:
		for x in _w:
			match _ch(x, y):
				"^":
					_add_spikes(x, y)
				"~":
					_add_acid(x, y, _ch(x, y - 1) == "~")
				"|":
					_add_gate(x, y)
	for door in _doors:
		_add_door(door)


func _make_static_body(layer: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	add_child(body)
	return body


func _add_shape(body: StaticBody2D, rect: Rect2, one_way: bool) -> void:
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	shape.position = rect.get_center()
	shape.one_way_collision = one_way
	body.add_child(shape)


func _add_spikes(x: int, y: int) -> void:
	var area := Area2D.new()
	area.add_to_group("hazard")
	area.add_to_group("pogo")
	area.collision_layer = 16
	area.collision_mask = 0
	area.monitoring = false
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(28, SPIKE_HEIGHT)
	shape.shape = rs
	shape.position = Vector2(x * TILE + 16, (y + 1) * TILE - SPIKE_HEIGHT * 0.5)
	area.add_child(shape)
	add_child(area)


# Acid kills outright and can't be pogoed off. Tiles under other acid fill the
# whole tile, so deep pools are one continuous body.
func _add_acid(x: int, y: int, submerged: bool) -> void:
	var area := Area2D.new()
	area.add_to_group("lethal_hazard")
	area.collision_layer = 16
	area.collision_mask = 0
	area.monitoring = false
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(TILE, TILE if submerged else 20.0)
	shape.shape = rs
	shape.position = Vector2(x * TILE + 16, y * TILE + (16 if submerged else 22))
	area.add_child(shape)
	add_child(area)


# Gate tiles start open; _set_gate_closed() turns their collision on.
func _add_gate(x: int, y: int) -> void:
	var body := _make_static_body(LAYER_WORLD)
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(TILE, TILE)
	shape.shape = rs
	shape.position = Vector2(x * TILE + TILE * 0.5, y * TILE + TILE * 0.5)
	shape.disabled = true
	body.add_child(shape)
	_gate_shapes.append(shape)


# ------------------------------------------------------------- Doors ----

# Direction pointing from a door into the room (doors sit on the left or right edge).
func _door_inward(door: Dictionary) -> int:
	return 1 if door.rect.position.x * 2 < _w else -1


# The trigger fills the outer half of the doorway, so you visibly step into it.
func _add_door(door: Dictionary) -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2   # player body
	area.monitorable = false
	var r: Rect2i = door.rect
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(TILE * 0.5, r.size.y * TILE)
	shape.shape = rs
	shape.position = Vector2((r.position.x + 0.5) * TILE - _door_inward(door) * TILE * 0.25, (r.position.y + r.size.y * 0.5) * TILE)
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(body: Node) -> void:
		if body is Player:
			GameState.go_through_door(room, door.target, body.health, door.arrive_at))


# Standing spot two tiles inside a door, on its bottom row.
func _door_stand_point(door: Dictionary) -> Vector2:
	var r: Rect2i = door.rect
	return Vector2((r.position.x + 0.5) * TILE + _door_inward(door) * TILE * 2, r.end.y * TILE - Player.BODY_SIZE.y * 0.5)


# The door to arrive at: the one named by the door we came through, else the
# one leading back where we came from, else any.
func _arrival_door() -> Variant:
	for door in _doors:
		if GameState.arrive_at != "" and door.name == GameState.arrive_at:
			return door
	for door in _doors:
		if door.target == GameState.arrived_from:
			return door
	return _doors[0] if not _doors.is_empty() else null


# ------------------------------------------------------------ Player ----

func _spawn_player() -> void:
	var start := Vector2(TILE * 2, TILE * 2)
	var has_start := false
	var found := entities_of(PlayerStart)
	var marker: PlayerStart = found[0] if not found.is_empty() else null
	if marker != null:
		start = to_local(marker.global_position) - Vector2(0, Player.BODY_SIZE.y * 0.5)
		has_start = true
	elif _from_ascii:
		for y in _h:
			for x in _w:
				if _ch(x, y) == "P":
					start = Vector2(x * TILE + TILE * 0.5, (y + 1) * TILE - Player.BODY_SIZE.y * 0.5)
					has_start = true
	# Arriving through a door (or a room with no start, e.g. run directly with F6).
	if GameState.arrived_from != "" or not has_start:
		var door: Variant = _arrival_door()
		if door != null:
			start = _door_stand_point(door)
	GameState.arrive_at = ""

	_player = Player.new()
	_player.position = start
	add_child(_player)
	_player.camera.limit_left = 0
	_player.camera.limit_top = 0
	_player.camera.limit_right = _w * TILE
	_player.camera.limit_bottom = _h * TILE


# --------------------------------------------------------------- Boss ----

## Gives a boss (already in the room) its arena, or leaves only its corpse if
## it's been beaten.
func _set_up_boss(boss: BossBase, arena: Rect2) -> void:
	if GameState.bosses_defeated.has(room):
		var fell_at: Variant = GameState.bosses_defeated[room]
		if fell_at is Vector2:
			boss.position = fell_at
		boss.become_corpse()
		return
	_boss = boss
	_boss.arena_left = arena.position.x
	_boss.arena_right = arena.end.x
	_boss.arena_top = arena.position.y
	_boss.arena_bottom = arena.end.y
	_arena_center = arena.get_center()


func _start_boss_fight() -> void:
	_boss_fight_started = true
	_set_gate_closed(true)
	_boss.health_changed.connect(_hud.set_boss_health)
	_boss.defeated.connect(_on_boss_defeated)
	await _play_boss_intro()
	_boss.activate(_player)


# Gameplay pauses; a separate camera (which keeps running while paused) zooms
# in on the boss for the name reveal, then pulls back to the arena's centre,
# where it stays locked for the fight.
func _play_boss_intro() -> void:
	get_tree().paused = true
	_arena_camera = Camera2D.new()
	_arena_camera.process_mode = Node.PROCESS_MODE_ALWAYS
	_arena_camera.limit_left = _player.camera.limit_left
	_arena_camera.limit_top = _player.camera.limit_top
	_arena_camera.limit_right = _player.camera.limit_right
	_arena_camera.limit_bottom = _player.camera.limit_bottom
	_arena_camera.position = _player.camera.get_screen_center_position()
	add_child(_arena_camera)
	_arena_camera.make_current()

	await _move_arena_camera(_boss.global_position + Vector2(0, -16), INTRO_ZOOM, INTRO_ZOOM_IN_TIME).finished
	await _hud.reveal_boss_title(_boss.boss_name, INTRO_TITLE_FADE_TIME).finished
	await get_tree().create_timer(INTRO_HOLD_TIME).timeout
	_hud.dock_boss_title(INTRO_ZOOM_OUT_TIME, _boss.health, _boss.max_health)
	await _move_arena_camera(_arena_center, 1.0, INTRO_ZOOM_OUT_TIME).finished
	get_tree().paused = false


func _move_arena_camera(target: Vector2, zoom: float, duration: float) -> Tween:
	var tween := _arena_camera.create_tween().set_parallel() \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_arena_camera, "position", target, duration)
	tween.tween_property(_arena_camera, "zoom", Vector2.ONE * zoom, duration)
	return tween


func can_debug_kill_boss() -> bool:
	return GameState.debug_mode and _boss != null


## Debug: the boss dies on the spot, with the usual rewards. Works before the
## fight has started too (no intro, gates just stay open).
func debug_kill_boss() -> void:
	if not can_debug_kill_boss():
		return
	if not _boss_fight_started:
		_boss_fight_started = true
		_boss.defeated.connect(_on_boss_defeated)
	_boss.debug_kill()


func _on_boss_defeated() -> void:
	GameState.bosses_defeated[room] = _boss.global_position
	var beaten := _boss
	_boss = null
	get_tree().call_group("boss_attack", "queue_free")   # shockwaves, feathers
	_set_gate_closed(false)
	_hud.hide_boss()
	GameState.unlock(beaten.reward_ability)
	_hud.show_message("%s FALLS\n%s unlocked" % [beaten.boss_name, beaten.reward_ability.capitalize()], 3.5)
	_player.shake(10.0, 0.5)
	if _arena_camera == null:
		return   # killed (debug) before the fight locked the camera
	# Unlock the camera: glide to where the player camera *will* be. Its own
	# position is stale (a camera that isn't current stops tracking), so work it
	# out from where the player is now, every frame, since they can keep moving.
	var from := _arena_camera.position
	var glide := func(t: float) -> void:
		_arena_camera.position = from.lerp(_player_camera_target(), t)
	var tween := _arena_camera.create_tween().set_parallel() \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(glide, 0.0, 1.0, CAMERA_RELEASE_TIME)
	tween.tween_property(_arena_camera, "zoom", Vector2.ONE, CAMERA_RELEASE_TIME)
	await tween.finished
	_player.camera.make_current()
	_player.camera.reset_smoothing()   # start from the player, not from where it was switched off
	_arena_camera.queue_free()
	_arena_camera = null


# Where the player's camera centres right now: on the player, kept inside its limits.
func _player_camera_target() -> Vector2:
	var cam := _player.camera
	var half := get_viewport_rect().size * 0.5 / cam.zoom
	var p := _player.global_position
	return Vector2(clampf(p.x, cam.limit_left + half.x, cam.limit_right - half.x),
			clampf(p.y, cam.limit_top + half.y, cam.limit_bottom - half.y))


func _set_gate_closed(closed: bool) -> void:
	_gate_closed = closed
	for shape in _gate_shapes:
		shape.set_deferred("disabled", not closed)
	_art.set_gates_closed(closed)
