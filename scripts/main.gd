extends Node2D
## Builds a room from LevelData (ASCII): tile art (RoomArt), collisions and
## hazards, entities. Platforms, spikes, gates and doors are still placeholders
## drawn here.

const TILE := 32
const LAYER_WORLD := 1
const LAYER_PLATFORMS := 32
const SPIKE_COLOR := Color(0.75, 0.78, 0.85)
const DOOR_COLOR := Color(0.02, 0.02, 0.04)
const DOOR_FRAME_COLOR := Color(0.5, 0.45, 0.35)
const GATE_COLOR := Color(0.6, 0.6, 0.65)
const ARENA_TRIGGER_INSET := 3   # tiles past a gate before the boss fight starts
const INTRO_ZOOM := 2.2
const INTRO_ZOOM_IN_TIME := 0.7
const INTRO_TITLE_FADE_TIME := 0.4
const INTRO_HOLD_TIME := 1.2
const INTRO_ZOOM_OUT_TIME := 0.8
const CAMERA_RELEASE_TIME := 0.6

## Key into LevelData.ROOMS.
@export var room := "start"

var _rows: Array
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


func _ready() -> void:
	Engine.time_scale = 1.0
	_rows = LevelData.ROOMS[room].rows
	for row in _rows:
		_w = maxi(_w, row.length())
	_h = _rows.size()

	RoomArt.new(_rows, _w, _h).build(self, room, LevelData.ROOMS[room].get("background", []))
	_build_solids()
	_spawn_entities()
	_hud = HUD.new()
	add_child(_hud)
	_hud.bind_player(_player)
	_player.died.connect(_on_player_died)
	add_child(PauseMenu.new())


func _physics_process(_delta: float) -> void:
	# The fight starts once you're a few tiles into the arena, from either side.
	if _boss != null and not _boss_fight_started:
		var x := _player.global_position.x
		var y := _player.global_position.y
		var inset := ARENA_TRIGGER_INSET * TILE
		if x > _boss.arena_left + inset and x < _boss.arena_right - inset and y > _boss.arena_top and y < _boss.arena_bottom:
			_start_boss_fight()


func _unhandled_input(event: InputEvent) -> void:
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


# --------------------------------------------------------------- Boss ----

# `boss` is already positioned; (x, y) is its marker tile.
func _spawn_boss(boss: BossBase, x: int, y: int) -> void:
	if GameState.bosses_defeated.has(room):
		# Already beaten: just its corpse, where it fell.
		var fell_at: Variant = GameState.bosses_defeated[room]
		if fell_at is Vector2:
			boss.position = fell_at
		add_child(boss)
		boss.become_corpse()
		return
	_boss = boss
	# Arena edges: the nearest wall or gate on each side of the boss's row.
	var left := x
	while not _ch(left - 1, y) in ["#", "|"]:
		left -= 1
	var right := x
	while not _ch(right + 1, y) in ["#", "|"]:
		right += 1
	_boss.arena_left = left * TILE
	_boss.arena_right = (right + 1) * TILE
	# Ceiling: the nearest solid tile straight above the boss (platforms don't count).
	var top := y
	while _ch(x, top - 1) != "#":
		top -= 1
	var bottom := y
	while _ch(x, bottom + 1) != "#":
		bottom += 1
	_boss.arena_top = top * TILE
	_boss.arena_bottom = (bottom + 1) * TILE
	_arena_center = Vector2((_boss.arena_left + _boss.arena_right) * 0.5, (top + bottom + 1) * TILE * 0.5)
	add_child(_boss)


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
	queue_redraw()


# ------------------------------------------------------------- Level ----

func _ch(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= _w or y >= _h:
		return "#"
	var row: String = _rows[y]
	return row[x] if x < row.length() else " "


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
				">":
					_add_door(x, y)
				"|":
					_add_gate(x, y)


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
	rs.size = Vector2(28, 16)
	shape.shape = rs
	shape.position = Vector2(x * TILE + 16, y * TILE + 24)
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


# Trigger sits in the outer half of the doorway, so you visibly step into it.
func _add_door(x: int, y: int) -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2   # player body
	area.monitorable = false
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(TILE * 0.5, TILE)
	shape.shape = rs
	shape.position = Vector2(x * TILE + TILE * 0.5 - _door_inward(x) * TILE * 0.25, y * TILE + TILE * 0.5)
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(body: Node) -> void:
		if body is Player:
			GameState.go_through_door(room, _door_target(x), body.health))


# Direction pointing from a door into the room (doors sit on the left or right edge).
func _door_inward(x: int) -> int:
	return 1 if x * 2 < _w else -1


func _door_side(x: int) -> String:
	return "left" if _door_inward(x) > 0 else "right"


func _door_target(x: int) -> String:
	return LevelData.ROOMS[room].doors[_door_side(x)]


# Standing spot two tiles inside the door that leads back to the room you came
# from (or any door if none does), on the door's bottom row.
func _door_spawn() -> Variant:
	for prefer_match in [true, false]:
		for y in range(_h - 1, -1, -1):
			for x in _w:
				if _ch(x, y) == ">" and (not prefer_match or _door_target(x) == GameState.arrived_from):
					return _door_stand_point(x, y)
	return null


func _door_stand_point(x: int, y: int) -> Vector2:
	return Vector2(x * TILE + TILE * 0.5 + _door_inward(x) * TILE * 2,
			(y + 1) * TILE - Player.BODY_SIZE.y * 0.5)


func _spawn_entities() -> void:
	var start := Vector2(TILE * 2, TILE * 2)
	var has_start := false
	for y in _h:
		for x in _w:
			var tile_origin := Vector2(x * TILE, y * TILE)
			match _ch(x, y):
				"P":
					start = tile_origin + Vector2(TILE * 0.5, TILE - Player.BODY_SIZE.y * 0.5)
					has_start = true
				"E":
					var enemy := CrawlerEnemy.new()
					enemy.position = tile_origin + Vector2(TILE * 0.5, TILE - CrawlerEnemy.SIZE.y * 0.5)
					add_child(enemy)
				"K":
					var knight := KnightEnemy.new()
					knight.position = tile_origin + Vector2(TILE * 0.5, TILE - KnightEnemy.SIZE.y * 0.5)
					add_child(knight)
				"D":
					_spawn_pickup("dash", "DASH", tile_origin)
				"W":
					_spawn_pickup("wall_jump", "WALL JUMP", tile_origin)
				"B":
					var warden := WardenBoss.new()
					warden.position = tile_origin + Vector2(TILE * 0.5, TILE - WardenBoss.SIZE.y * 0.5)
					_spawn_boss(warden, x, y)
				"F":
					var harrier := HarrierBoss.new()
					harrier.position = tile_origin + Vector2(TILE * 0.5, TILE * 0.5)
					_spawn_boss(harrier, x, y)
				"o":
					var coin_id := "%s:%d,%d" % [room, x, y]
					if not GameState.collected_coins.has(coin_id):
						_spawn_item("coin", tile_origin, coin_id)
				"h":
					_spawn_item("health", tile_origin)

	# Arriving through a door (or a room with no P, e.g. run directly with F6).
	if GameState.arrived_from != "" or not has_start:
		var door_spawn: Variant = _door_spawn()
		if door_spawn != null:
			start = door_spawn

	_player = Player.new()
	_player.position = start
	add_child(_player)
	_player.camera.limit_left = 0
	_player.camera.limit_top = 0
	_player.camera.limit_right = _w * TILE
	_player.camera.limit_bottom = _h * TILE


func _spawn_item(kind: String, tile_origin: Vector2, coin_id := "") -> void:
	var item := ItemPickup.new()
	item.kind = kind
	item.coin_id = coin_id
	item.position = tile_origin + Vector2(TILE * 0.5, TILE * 0.5)
	add_child(item)


func _spawn_pickup(ability: String, label: String, tile_origin: Vector2) -> void:
	if GameState.has_ability(ability):
		return
	var pickup := AbilityPickup.new()
	pickup.ability = ability
	pickup.label = label
	pickup.position = tile_origin + Vector2(TILE * 0.5, TILE * 0.5)
	add_child(pickup)


# ------------------------------------------------- Placeholder tile art ----

# Ground, acid and the background are tile art (RoomArt). These still aren't.
func _draw() -> void:
	for y in _h:
		for x in _w:
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			match _ch(x, y):
				"=":
					draw_rect(Rect2(r.position, Vector2(TILE, 10)), Color(0.55, 0.4, 0.25))
				"^":
					for i in 4:
						var x0 := r.position.x + i * 8.0
						draw_colored_polygon(PackedVector2Array([
							Vector2(x0, r.end.y), Vector2(x0 + 4, r.end.y - 18), Vector2(x0 + 8, r.end.y)]),
							SPIKE_COLOR)
				"|":
					if _gate_closed:
						for i in 4:
							draw_rect(Rect2(r.position.x + 3 + i * 7, r.position.y, 4, TILE), GATE_COLOR)
						draw_rect(Rect2(r.position.x, r.position.y + 12, TILE, 4), GATE_COLOR)
					elif _ch(x, y - 1) != "|":
						# Raised gate: just the spiked bottom edge peeking out under the lintel.
						for i in 4:
							draw_rect(Rect2(r.position.x + 3 + i * 7, r.position.y, 4, 8), GATE_COLOR)
				">":
					draw_rect(r, DOOR_COLOR)
					if _ch(x, y - 1) == "#":
						draw_rect(Rect2(r.position, Vector2(TILE, 6)), DOOR_FRAME_COLOR)
