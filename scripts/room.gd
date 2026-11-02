@tool
class_name Room
extends Node2D
## A room: builds collisions, hazards, gates and doors from its layout, sets up
## its boss fight, and runs it (HUD, pause menu, death, the boss intro and
## camera). Made in the editor (see "Making rooms" in art/README.md; start from
## scenes/rooms/room_template.tscn):
##   Skyline     the far city, behind everything
##   Background  the wall behind the room (background_tileset.tres)
##   Props       things on the wall, over its brick: lights, posters, graffiti,
##               girders and pipes (props_tileset.tres)
##   Terrain     what you stand on and what hurts (foreground_tileset.tres)
##   Gates       arena gates, shut during a boss fight (foreground_tileset.tres)
##   Entities    placed enemies and bosses, a PlayerStart, RoomDoors, Arenas
## Paint from the room's top-left (0, 0). What each tile does comes from its
## custom data `kind` (see tools/make_tilesets.gd); the room reads the tiles
## into a grid of RoomArt.Kind (solid, platform, spikes, sewer water, gate,
## door). Does nothing while editing.

const TILE := 32
const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const DEATH_MENU_SCENE := preload("res://scenes/ui/death_menu.tscn")
const DEATH_MENU_DELAY := 1.0   # seconds after you die before the death screen
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
## The room's look, built in game (_set_look): its dimming (a CanvasModulate),
## glow on its brightest pixels (a WorldEnvironment), and its colour grade on a
## layer of its own, over everything in the room and under the HUD (HUD.LAYER)
## and menus. Glow reaches up to the grade's layer, so the HUD doesn't glow.
const GRADE_LAYER := 5
const GRADE_SHADER := preload("res://shaders/color_grade.gdshader")
const DEFAULT_GRADE := preload("res://art/grades/default_grade.tres")
const GLOW_THRESHOLD := 0.75   # pixels brighter than this glow: bulbs, signs, acid, slashes
const GLOW_INTENSITY := 0.9
const GLOW_BLOOM := 0.0
## On your last heart (this many half-hearts or fewer), the room drains toward
## grey: to LAST_HEART_LOW, where it holds LAST_HEART_HOLD seconds, then pulses
## up to LAST_HEART_HIGH and back, over and over until you heal. It changes at
## LAST_HEART_SPEED (of the way to grey per second), coming and going too.
const LAST_HEART := 2
const LAST_HEART_LOW := 0.4
const LAST_HEART_HIGH := 0.8
const LAST_HEART_HOLD := 5.0
const LAST_HEART_SPEED := 1.0

## This room's id in LevelData.ROOMS.
@export var room := ""
## How much the room is dimmed, so its lights stand out: every colour in it is
## multiplied by this (a CanvasModulate, added in game). Keep it light: the
## room should read clearly without them. White: no dimming. The skyline, HUD
## and menus aren't dimmed.
@export var dimming := Color(0.8, 0.82, 0.88)
## The room's colour grade (see ColorGrade). Empty: art/grades/default_grade.tres.
@export var grade: ColorGrade
## Fills every unpainted cell of the Background layer with brick and windows,
## with lights, posters and graffiti on the Props layer (the same each time
## for the same room), so you can edit it by hand. Wall you've already painted
## is kept. The room shows exactly what's painted: unpainted wall is open, and
## the skyline shows through. Save the scene to keep it.
@export_tool_button("Decorate wall", "TileMapLayer") var decorate_wall_action: Callable = decorate_wall

var _grid := {}   # Vector2i -> RoomArt.Kind (EMPTY cells left out)
var _art: RoomArt
var _w := 0
var _h := 0
var _player: Player
var _hud: HUD
var _death_menu: DeathMenu
var _boss: BossBase
var _boss_fight_started := false
var _gate_shapes: Array[CollisionShape2D] = []
var _gate_closed := false
var _arena_center := Vector2.ZERO
var _arena_camera: Camera2D   # current camera from the boss intro until the boss dies
var _grade_rect: ColorRect   # the colour grade, over the whole screen
var _drain_tween: Tween
var _draining := false   # on your last heart: the grade is pulsing grey
## [{rect: Rect2i in cells, target: room id, arrive_at: door name, name: String}]
var _doors: Array[Dictionary] = []


func background() -> TileMapLayer:
	return get_node_or_null("Background")


func props() -> TileMapLayer:
	return get_node_or_null("Props")


func terrain() -> TileMapLayer:
	return get_node_or_null("Terrain")


func gates() -> TileMapLayer:
	return get_node_or_null("Gates")


func entities() -> Node2D:
	return get_node_or_null("Entities")


## Every node under Entities that is a `type` (a script class, e.g. RoomDoor).
func entities_of(type: Variant) -> Array:
	if entities() == null:
		return []
	return entities().find_children("*", "", true, false).filter(func(n): return is_instance_of(n, type))


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	Engine.time_scale = 1.0
	_set_look()
	_load_room()
	_build_solids()
	_spawn_player()
	_hud = HUD.new()
	add_child(_hud)
	_hud.bind_player(_player)
	_player.died.connect(_on_player_died)
	_player.health_changed.connect(_on_health_for_grade)
	_on_health_for_grade(_player.health, _player.max_health)
	add_child(PAUSE_MENU_SCENE.instantiate())
	_death_menu = DEATH_MENU_SCENE.instantiate()
	add_child(_death_menu)


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


## The room's look: dimmed by `dimming` (all but the skyline), glowing where
## it's brightest, and graded by `grade`.
func _set_look() -> void:
	var modulate_node := CanvasModulate.new()
	modulate_node.name = "Dimming"
	modulate_node.color = dimming
	add_child(modulate_node)
	var skyline := get_node_or_null("Skyline") as Skyline
	if skyline != null:
		skyline.undim(dimming)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.background_canvas_max_layer = GRADE_LAYER
	environment.glow_enabled = true
	environment.glow_hdr_threshold = GLOW_THRESHOLD
	environment.glow_intensity = GLOW_INTENSITY
	environment.glow_bloom = GLOW_BLOOM
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var world := WorldEnvironment.new()
	world.name = "Glow"
	world.environment = environment
	add_child(world)

	var layer := CanvasLayer.new()
	layer.name = "Grade"
	layer.layer = GRADE_LAYER
	_grade_rect = ColorRect.new()
	_grade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = GRADE_SHADER
	material.set_shader_parameter("desaturate", 0.0)   # unset, it reads back as null
	_grade_rect.material = material
	layer.add_child(_grade_rect)
	add_child(layer)
	apply_grade(grade if grade != null else DEFAULT_GRADE)


## Shows `look` as the room's colour grade.
func apply_grade(look: ColorGrade) -> void:
	var material := _grade_rect.material as ShaderMaterial
	material.set_shader_parameter("brightness", look.brightness)
	material.set_shader_parameter("contrast", look.contrast)
	material.set_shader_parameter("saturation", look.saturation)
	material.set_shader_parameter("shadow_tint", look.shadow_tint)
	material.set_shader_parameter("highlight_tint", look.highlight_tint)
	material.set_shader_parameter("use_lut", look.lut != null)
	material.set_shader_parameter("lut", look.lut)
	material.set_shader_parameter("lut_strength", look.lut_strength)


## The grade drains toward grey on your last heart, pulsing, and comes back
## with health.
func _on_health_for_grade(current: int, _maximum: int) -> void:
	var draining := current > 0 and current <= LAST_HEART
	if draining == _draining:
		return
	_draining = draining
	if _drain_tween != null:
		_drain_tween.kill()
	_drain_tween = create_tween()
	_drain_to(_drain_tween, LAST_HEART_LOW if draining else 0.0)
	if draining:
		_drain_tween.tween_callback(_pulse_drain)


## Holds at LAST_HEART_LOW, then up to LAST_HEART_HIGH and back, on a loop.
func _pulse_drain() -> void:
	_drain_tween = create_tween().set_loops()
	_drain_tween.tween_interval(LAST_HEART_HOLD)
	_drain_to(_drain_tween, LAST_HEART_HIGH, LAST_HEART_LOW)
	_drain_to(_drain_tween, LAST_HEART_LOW, LAST_HEART_HIGH)


## Adds a step to `tween` taking the grade's drain to `target` at
## LAST_HEART_SPEED, from `from` (or wherever it is now).
func _drain_to(tween: Tween, target: float, from := -1.0) -> void:
	var material := _grade_rect.material as ShaderMaterial
	var start: float = from if from >= 0.0 else material.get_shader_parameter("desaturate")
	tween.tween_property(material, "shader_parameter/desaturate", target, absf(target - start) / LAST_HEART_SPEED)


## A moment after you die, the death screen: what killed you, Respawn or Quit.
func _on_player_died() -> void:
	await get_tree().create_timer(DEATH_MENU_DELAY).timeout
	_death_menu.open(_player.killed_by)


# ------------------------------------------------------------ Layout ----

## What's at (x, y); anything outside the room is solid.
func _kind_at(x: int, y: int) -> RoomArt.Kind:
	if x < 0 or y < 0 or x >= _w or y >= _h:
		return RoomArt.Kind.SOLID
	return _grid.get(Vector2i(x, y), RoomArt.Kind.EMPTY)


## The Inspector's "Decorate wall" button (see decorate_wall_action).
func decorate_wall() -> void:
	_read_painted_grid()
	RoomArt.new(_kind_at, _w, _h).decorate_unpainted(room, background(), props())
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		Engine.get_singleton("EditorInterface").mark_scene_as_unsaved()


## The room's size and layout grid, from its painted layers.
func _read_painted_grid() -> void:
	_grid.clear()
	var used := Rect2i()
	for layer in [terrain(), gates(), background()]:
		if layer != null and not layer.get_used_cells().is_empty():
			used = layer.get_used_rect() if used.size == Vector2i.ZERO else used.merge(layer.get_used_rect())
	_w = used.end.x
	_h = used.end.y
	for layer in [terrain(), gates()]:
		for cell in layer.get_used_cells():
			var kind: String = layer.get_cell_tile_data(cell).get_custom_data("kind")
			if RoomArt.TILE_KINDS.has(kind):
				_grid[cell] = RoomArt.TILE_KINDS[kind]


## The grid comes from the painted tiles' kinds, and doors and bosses from the
## nodes under Entities.
func _load_room() -> void:
	_read_painted_grid()
	_art = RoomArt.new(_kind_at, _w, _h)
	# The terrain and gates get the bulbs' hard shadows (FlickerLight.MASK_TERRAIN).
	for layer in [terrain(), gates()]:
		layer.light_mask = FlickerLight.MASK_TERRAIN
	_art.dress(self, props(), terrain(), gates())
	for door in entities_of(RoomDoor):
		var at := Vector2i((to_local(door.global_position) / TILE).round())
		_doors.append({"rect": Rect2i(at, Vector2i(1, door.height)), "target": door.target_room,
				"arrive_at": door.arrive_at, "name": String(door.name)})
	for arena in entities_of(Arena):
		var boss: BossBase = arena.get_node_or_null(arena.boss)
		if boss != null:
			_set_up_boss(boss, Rect2(to_local(arena.global_position), Vector2(arena.size_tiles * TILE)))


func _build_solids() -> void:
	var body := _make_static_body(LAYER_WORLD)
	# One-way platforms get their own layer so heavy enemies (the boss) can ignore them.
	var platforms := _make_static_body(LAYER_PLATFORMS)

	# Merge horizontal runs into single shapes (avoids snagging on tile seams).
	for y in range(-1, _h + 1):
		var x := -1
		while x <= _w:
			var kind := _kind_at(x, y)
			if kind == RoomArt.Kind.SOLID or kind == RoomArt.Kind.PLATFORM:
				var start := x
				while x <= _w and _kind_at(x, y) == kind:
					x += 1
				var rect := Rect2(start * TILE, y * TILE, (x - start) * TILE, TILE)
				if kind == RoomArt.Kind.PLATFORM:
					rect.size.y = 10.0
					_add_shape(platforms, rect, true)
				else:
					_add_shape(body, rect, false)
			else:
				x += 1

	for y in _h:
		for x in _w:
			match _kind_at(x, y):
				RoomArt.Kind.SPIKES:
					_add_spikes(x, y)
				RoomArt.Kind.ACID:
					_add_acid(x, y, _kind_at(x, y - 1) == RoomArt.Kind.ACID)
				RoomArt.Kind.GATE:
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
	area.set_meta("blow", "UI_DEATH_BY_SPIKES")   # the death screen's message
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


# Acid kills outright. Tiles under other acid fill the whole tile, so deep
# pools are one continuous body.
func _add_acid(x: int, y: int, submerged: bool) -> void:
	var area := Area2D.new()
	area.add_to_group("lethal_hazard")
	area.set_meta("blow", "UI_DEATH_BY_ACID")   # the death screen's message
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
	_hud.show_message(tr("UI_HUD_BOSS_FALLS").format({"boss": tr(beaten.boss_name),
			"ability": GameState.ability_name(beaten.reward_ability)}), 3.5)
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
