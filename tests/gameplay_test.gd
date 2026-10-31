extends Node
## Headless gameplay checks. Run with:
##   godot --headless --path . res://tests/gameplay_test.tscn
## Exits with the number of failed checks (0 = all passed).

const TILE := 32
const MAIN_SCENE := preload("res://scenes/main.tscn")
const BOSS_SCENE := preload("res://scenes/boss_room.tscn")
const CLIMB_SCENE := preload("res://scenes/climb_room.tscn")
const MENU_SCENE := preload("res://scenes/main_menu.tscn")

# Climb room, bottom to top. Solid ledges sit 2 rows above the platform before
# them (a 3-row rise onto a solid ledge is too tight to clear its edge).
const CLIMB_ROUTE := [
	[44, 0, 5],     # floor, up to just beside the first platform
	[41, 6, 11],
	[38, 13, 18],
	[36, 20, 29],   # knight ledge
	[33, 12, 16],
	[31, 0, 8],     # knight ledge
	[28, 11, 15],
	[25, 17, 21],
	[23, 23, 29],   # knight ledge
	[20, 15, 20],
	[17, 9, 14],
	[15, 0, 6],     # health pickup ledge
	[12, 9, 14],
	[9, 16, 21],
	[6, 9, 14],
	[4, 18, 29],    # top ledge with the coin row
]

# Platforms along the acid section: [top row, first column, last column].
const ACID_ROUTE := [
	[8, 49, 59],    # enemy block (start)
	[9, 63, 66],
	[12, 69, 73],
	[14, 78, 86],
	[12, 88, 91],
	[10, 93, 96],
	[12, 99, 104],  # end ledge
]

# Boss room shafts, bottom to top. The top step is the one-way floor of the
# hallway above.
const BOSS_LEFT_SHAFT := [
	[29, 1, 5],     # corridor floor by the entrance
	[26, 6, 10],
	[24, 1, 5],     # crawler ledge
	[21, 6, 10],
	[18, 2, 6],
	[15, 1, 10],    # left hallway floor
]
const BOSS_RIGHT_SHAFT := [
	[29, 70, 76],   # corridor floor past the acid
	[26, 66, 69],
	[23, 62, 65],
	[20, 66, 69],
	[17, 62, 65],
	[15, 62, 69],   # right hallway floor
]

var _fails := 0
var _main: Node2D
var _player: Player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep driving checks through the paused boss intro
	await get_tree().process_frame   # root can't take new children during startup
	await _test_acid_kills()
	await _test_acid_kills_through_invulnerability()
	await _test_spikes_hurt_and_respawn()
	await _test_spikes_respect_invulnerability()
	await _test_safe_ground_needs_both_feet()
	await _test_tapped_down_strike_ends()
	await _test_held_down_strike_stays_out()
	await _test_held_pogo_chains_on_spikes()
	await _test_acid_route_jumps()
	await _test_acid_enemies_stay_on_platforms()
	await _test_crawler_turns_at_wall()
	await _test_door_to_boss_room_and_back()
	await _test_boss_room_shafts_climbable()
	await _test_right_hallway_drops_to_far_side()
	await _test_acid_gap_needs_dash()
	await _test_boss_fight_starts_and_gate_shuts()
	await _test_boss_fight_starts_from_right_side()
	await _test_boss_attacks_stay_in_arena()
	await _test_boss_hurts_player()
	await _test_player_attacks_hurt_boss()
	await _test_boss_defeat_opens_gate_and_sticks()
	await _test_coin_counts_and_stays_collected()
	await _test_down_jump_drops_through_platform()
	await _test_down_jump_on_solid_ground_still_jumps()
	await _test_crawler_kill_heals_half_heart()
	await _test_health_pickup()
	await _test_boss_hallway_door_to_climb_room_and_back()
	await _test_climb_route_jumps()
	await _test_knights_are_slow()
	await _test_knight_swing_hurts()
	await _test_knight_swing_can_be_dodged()
	await _test_knight_kill_heals_half_heart()
	await _test_pause_menu_toggles()
	await _test_pause_ignored_during_boss_intro()
	await _test_main_menu_starts_game()
	await _test_pause_menu_quits_to_main_menu()
	print("\n%s: %d failed check(s)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)


# ------------------------------------------------------------- Helpers ----

# Rooms run as the tree's current scene (beside this test node, not under it),
# so door transitions and death reloads replace the room, not the test.
func _spawn(scene: PackedScene = MAIN_SCENE, boss_beaten := false) -> void:
	GameState.arrived_from = ""
	GameState.bosses_defeated = {"boss": Vector2(49.5 * TILE, 15 * TILE - WardenBoss.SIZE.y * 0.5)} if boss_beaten else {}
	GameState.collected_coins = {}
	GameState.coins = 0
	GameState.abilities = {"dash": false, "wall_jump": false}
	_main = scene.instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_player = _main._player
	await _frames(2)


func _despawn() -> void:
	_release_all()
	get_tree().paused = false   # in case a check failed mid-intro
	get_tree().current_scene.queue_free()
	await _frames(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		_fails += 1


func _place(col: float, row: float) -> void:
	_player.global_position = Vector2(col * TILE + TILE * 0.5, row * TILE)
	_player.velocity = Vector2.ZERO


func _release_all() -> void:
	for a in ["move_left", "move_right", "move_down", "jump", "attack"]:
		Input.action_release(a)


func _wait_for_room(room: String, max_frames: int) -> Node:
	for i in max_frames:
		await _frames(1)
		var scene := get_tree().current_scene
		if scene != null and scene.get("room") == room and scene.get("_player") != null:
			return scene
	return null


func _remove_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	await _frames(1)


# --------------------------------------------------------------- Tests ----

func _test_acid_kills() -> void:
	print("Acid kills instantly")
	await _spawn()
	_place(75, 15)   # over the acid section's floor
	await _frames(60)
	_check(_player._dead, "player died in acid")
	await _despawn()


func _test_acid_kills_through_invulnerability() -> void:
	print("Acid ignores invulnerability")
	await _spawn()
	_player._invuln_timer = 5.0
	_place(75, 15)   # over the acid section's floor
	await _frames(60)
	_check(_player._dead, "invulnerable player still died in acid")
	await _despawn()


func _test_spikes_hurt_and_respawn() -> void:
	print("Spikes deal 1 damage and return you to safe ground")
	await _spawn()
	var safe := _player.global_position
	_place(33, 17)
	await _frames(120)   # long enough for a repeat hit if respawned onto the spikes
	_check(not _player._dead, "player survived spikes")
	_check(_player.health == _player.max_health - Player.HIT_DAMAGE, "lost exactly one heart (%d/%d)" % [_player.health, _player.max_health])
	_check(_player.global_position.distance_to(safe) < 40.0, "returned to last safe position")
	await _despawn()


func _test_spikes_respect_invulnerability() -> void:
	print("Spikes don't hurt during invulnerability")
	await _spawn()
	_player._invuln_timer = 5.0
	_place(33, 17)
	await _frames(60)
	_check(_player.health == _player.max_health, "no damage while invulnerable")
	await _despawn()


func _test_safe_ground_needs_both_feet() -> void:
	print("Safe ground is only saved with both feet on solid ground")
	await _spawn()
	var feet_y := 18 * TILE - Player.BODY_SIZE.y * 0.5
	# Overhanging the spike pit's left edge (floor ends at x = 30 tiles).
	var edge := Vector2(30 * TILE - 5, feet_y)
	_player.global_position = edge
	_player.velocity = Vector2.ZERO
	await _frames(30)
	_check(_player.is_on_floor(), "standing on the ledge edge")
	_check(_player.last_safe_position.distance_to(edge) > 1.0, "edge spot not saved")
	# Fully on the floor a little further back.
	var solid := Vector2(30 * TILE - 40, feet_y)
	_player.global_position = solid
	await _frames(30)
	_check(_player.last_safe_position.distance_to(solid) < 1.0, "solid spot saved")
	# Middle of a one-way platform also counts.
	var platform := Vector2(10.5 * TILE + TILE * 0.5, 16 * TILE - Player.BODY_SIZE.y * 0.5)
	_player.global_position = platform
	await _frames(30)
	_check(_player.last_safe_position.distance_to(platform) < 1.0, "one-way platform spot saved")
	await _despawn()


func _test_tapped_down_strike_ends() -> void:
	print("Tapped down-strike ends after its normal duration")
	await _spawn()
	_place(32, 0)   # long fall into the spike pit
	await _frames(5)
	Input.action_press("move_down")
	Input.action_press("attack")
	await _frames(2)
	_check(_player._attack_timer > 0.0 and _player._attack_dir == Vector2.DOWN, "strike went downward")
	Input.action_release("attack")
	await _frames(15)
	_check(not _player.is_on_floor(), "still airborne")
	_check(_player._attack_timer <= 0.0, "strike ended")
	await _despawn()


func _test_held_down_strike_stays_out() -> void:
	print("Held down-strike stays out until release")
	await _spawn()
	_place(32, 0)   # long fall into the spike pit
	await _frames(5)
	Input.action_press("move_down")
	Input.action_press("attack")
	await _frames(20)
	_check(not _player.is_on_floor(), "still airborne")
	_check(_player._attack_timer > 0.0, "strike still out after 20 frames")
	Input.action_release("attack")
	await _frames(15)
	_check(_player._attack_timer <= 0.0, "strike ended after release")
	await _despawn()


func _test_held_pogo_chains_on_spikes() -> void:
	print("Holding the down-strike chains pogos on spikes")
	await _spawn()
	_place(32, 9)
	Input.action_press("move_down")
	Input.action_press("attack")
	var bounces := 0
	var prev_vy := 0.0
	for i in 240:
		await _frames(1)
		if _player.velocity.y < -400.0 and prev_vy >= 0.0:
			bounces += 1
		prev_vy = _player.velocity.y
	_check(bounces >= 3, "bounced %d times in 4s" % bounces)
	_check(_player.health == _player.max_health, "never touched the spikes")
	await _despawn()


func _test_acid_route_jumps() -> void:
	print("Every acid-section jump is makeable with a plain jump")
	await _spawn()
	await _remove_enemies()
	await _check_route(ACID_ROUTE)
	await _despawn()


func _test_boss_room_shafts_climbable() -> void:
	print("Both boss-room shafts can be climbed with plain jumps")
	await _spawn(BOSS_SCENE, true)
	var crawlers := get_tree().get_nodes_in_group("enemy").filter(func(e): return e is CrawlerEnemy)
	_check(crawlers.size() == 1 and crawlers[0].global_position.x < 11 * TILE and crawlers[0].global_position.y > 16 * TILE,
			"one crawler, in the left shaft")
	await _remove_enemies()
	await _check_route(BOSS_LEFT_SHAFT)
	await _check_route(BOSS_RIGHT_SHAFT)
	await _despawn()


func _test_right_hallway_drops_to_far_side() -> void:
	print("Down + jump in the right hallway drops to the far side of the acid")
	await _spawn(BOSS_SCENE, true)
	await _remove_enemies()
	_player.global_position = Vector2(65.5 * TILE, 15 * TILE - Player.BODY_SIZE.y * 0.5)
	await _frames(10)
	Input.action_press("move_down")
	await _frames(1)
	Input.action_press("jump")
	await _frames(3)
	_release_all()
	for i in 120:
		await _frames(1)
		if _player.global_position.y > 25 * TILE and _player.is_on_floor():
			break
	var p := _player.global_position
	_check(_player.is_on_floor() and p.y > 16 * TILE and p.x > 42 * TILE and not _player._dead,
			"landed below, past the acid (col %.1f, row %.1f)" % [p.x / TILE, p.y / TILE])
	await _despawn()


# Runs at the acid gap from `from_col` toward `dir`, jumps at the edge and
# dashes at the top of the jump. Returns true if it lands safely across.
func _try_acid_dash_crossing(from_col: float, dir: int, edge_col: float, far_col: float) -> bool:
	_player.global_position = Vector2(from_col * TILE, 29 * TILE - Player.BODY_SIZE.y * 0.5)
	_player.velocity = Vector2.ZERO
	await _frames(5)
	var move := "move_right" if dir > 0 else "move_left"
	Input.action_press(move)
	var jumped := false
	var dashed := false
	var airborne := false
	for i in 240:
		await _frames(1)
		var x := _player.global_position.x / TILE
		airborne = airborne or (jumped and not _player.is_on_floor())
		if not jumped and (x - edge_col) * dir >= -0.3:
			Input.action_press("jump")
			jumped = true
		elif airborne and not dashed and _player.velocity.y > -150.0:
			Input.action_press("dash")   # near the top of the jump
			dashed = true
		elif dashed:
			Input.action_release("dash")
		if _player._dead or (airborne and _player.is_on_floor()):
			break
	_release_all()
	var x_end := _player.global_position.x / TILE
	return not _player._dead and _player.is_on_floor() and (x_end - far_col) * dir >= 0.0


func _test_acid_gap_needs_dash() -> void:
	print("The lower corridor's acid gap can only be crossed with dash")
	await _spawn(BOSS_SCENE, true)
	await _remove_enemies()
	_check(not await _try_acid_dash_crossing(27, 1, 34, 42), "no crossing without dash")
	_check(_player._dead, "fell in the acid")
	await _despawn()
	await _spawn(BOSS_SCENE, true)
	await _remove_enemies()
	GameState.unlock("dash")
	_check(await _try_acid_dash_crossing(27, 1, 34, 42), "dash crosses left to right (col %.1f)" % (_player.global_position.x / TILE))
	_check(await _try_acid_dash_crossing(49, -1, 42, 34), "dash crosses right to left (col %.1f)" % (_player.global_position.x / TILE))
	await _despawn()


# Places the player mid-arena and waits out the intro cutscene.
func _start_boss_fight() -> WardenBoss:
	seed(1)   # deterministic attack choices
	await _spawn(BOSS_SCENE)
	_place(40, 14)
	await _frames(3)
	_check(await _wait_for_intro_end(), "intro cutscene finished")
	return _main._boss


# The fight flag is set in the same frame the tree pauses, so "started and
# not paused" only holds once the intro is over.
func _wait_for_intro_end(max_frames := 400) -> bool:
	for i in max_frames:
		if _main._boss_fight_started and not get_tree().paused:
			return true
		await _frames(1)
	return false


# Holds a direction until the boss fight triggers (or the frame limit runs out).
func _walk_until_fight(action: String, max_frames: int) -> void:
	Input.action_press(action)
	for i in max_frames:
		await _frames(1)
		if _main._boss_fight_started:
			break
	Input.action_release(action)


func _test_boss_fight_starts_and_gate_shuts() -> void:
	print("Walking into the arena plays the intro, shuts the gates and locks the camera")
	await _spawn(BOSS_SCENE)
	_check(_main._boss != null and not _main._boss_fight_started, "boss waits, dormant")
	_place(20, 14)
	await _walk_until_fight("move_right", 120)
	_check(_main._boss_fight_started, "fight started")
	_check(get_tree().paused, "gameplay paused for the intro")
	_check(get_viewport().get_camera_2d() == _main._arena_camera, "intro camera took over")
	await _frames(1)
	_check(_main._gate_closed, "gate closed")
	_check(not _main._hud.is_boss_shown(), "health bar hidden during the intro")
	var boss_x: float = _main._boss.global_position.x
	var max_zoom := 1.0
	var title_peak_scale := 0.0
	var paused_frames := 0
	while get_tree().paused and paused_frames < 400:
		await _frames(1)
		paused_frames += 1
		max_zoom = maxf(max_zoom, _main._arena_camera.zoom.x)
		if _main._hud._boss_label.visible and _main._hud._boss_label.modulate.a > 0.9:
			title_peak_scale = maxf(title_peak_scale, _main._hud._boss_label.scale.x)
	_check(not get_tree().paused, "gameplay resumed after %.1fs" % (paused_frames / 60.0))
	_check(max_zoom >= _main.INTRO_ZOOM - 0.01, "camera zoomed in on the boss (%.2fx)" % max_zoom)
	_check(title_peak_scale >= 0.99, "name shown full size mid-intro")
	_check(_main._boss.global_position.x == boss_x and _main._boss.attack_log.is_empty(), "boss held still during the intro")
	await _frames(20)
	_check(_main._hud.is_boss_shown() and _main._hud._boss_bar.modulate.a > 0.99, "health bar faded in")
	_check(is_equal_approx(_main._hud._boss_label.scale.x, _main._hud.BOSS_TITLE_DOCKED_SCALE), "name docked above the bar")
	var cam: Camera2D = _main._arena_camera
	_check(cam.zoom.is_equal_approx(Vector2.ONE) and cam.position.distance_to(_main._arena_center) < 1.0,
			"camera back at 1x on the arena centre")
	Input.action_press("move_left")
	await _frames(90)
	Input.action_release("move_left")
	_check(_player.global_position.x > 25 * TILE, "gate blocks the way back (col %.1f)" % (_player.global_position.x / TILE))
	_check(get_viewport().get_camera_2d() == cam and cam.position.distance_to(_main._arena_center) < 1.0,
			"camera stayed locked while the player moved")
	await _despawn()


func _test_boss_fight_starts_from_right_side() -> void:
	print("Entering from the right hallway also starts the fight and shuts both gates")
	await _spawn(BOSS_SCENE)
	_check(_main._gate_shapes.size() == 8, "two 4-tile gates (%d gate tiles)" % _main._gate_shapes.size())
	_place(60, 14)
	await _frames(20)
	_check(not _main._boss_fight_started, "still dormant in the right hallway")
	_player._invuln_timer = 999.0
	await _walk_until_fight("move_left", 150)
	_check(_main._boss_fight_started, "fight started")
	await _frames(2)
	_check(_main._gate_shapes.all(func(s): return not s.disabled), "both gates closed")
	_check(await _wait_for_intro_end(), "intro cutscene finished")
	_player._invuln_timer = 999.0
	Input.action_press("move_right")
	await _frames(90)
	Input.action_release("move_right")
	_check(_player.global_position.x < 53 * TILE, "right gate blocks the way back (col %.1f)" % (_player.global_position.x / TILE))
	await _despawn()


func _test_boss_attacks_stay_in_arena() -> void:
	print("The Warden cycles its attacks and stays inside the arena")
	var boss := await _start_boss_fight()
	_player._invuln_timer = 999.0
	var saw_wave := false
	var in_bounds := true
	for phase in 2:
		if phase == 1:
			boss.health = boss.max_health / 2   # phase two
		for i in 720:
			await _frames(1)
			_player._invuln_timer = 999.0
			for c in _main.get_children():
				saw_wave = saw_wave or c is WardenShockwave
			var bx := boss.global_position.x
			if bx < boss.arena_left or bx > boss.arena_right or boss.global_position.y > 15 * TILE:
				in_bounds = false
	print("        attacks: ", boss.attack_log)
	_check("charge" in boss.attack_log, "used charge")
	_check("leap" in boss.attack_log, "used leap")
	_check(saw_wave, "leap slam made shockwaves")
	_check(not "volley" in boss.attack_log, "no volley any more")
	_check(in_bounds, "stayed inside the arena")
	_check(boss.attack_log.size() >= 8, "kept attacking (%d attacks in 24s)" % boss.attack_log.size())
	await _despawn()


func _test_boss_hurts_player() -> void:
	print("Standing still against the Warden gets you hurt")
	await _start_boss_fight()
	for i in 600:
		await _frames(1)
		if _player.health < _player.max_health:
			break
	_check(_player.health < _player.max_health, "player took damage (%d/%d)" % [_player.health, _player.max_health])
	await _despawn()


func _test_player_attacks_hurt_boss() -> void:
	print("Player attacks damage the Warden once the fight is on")
	var boss := await _start_boss_fight()
	_player._invuln_timer = 999.0
	_player.global_position = boss.global_position + Vector2(-50, WardenBoss.SIZE.y * 0.5 - Player.BODY_SIZE.y * 0.5)
	_player.facing = 1
	await _frames(2)
	Input.action_press("attack")
	await _frames(3)
	Input.action_release("attack")
	await _frames(2)
	_check(boss.health == boss.max_health - 1, "boss lost 1 health (%d/%d)" % [boss.health, boss.max_health])
	_check(_main._hud._boss_bar.current == boss.health, "health bar follows")
	await _despawn()


func _test_boss_defeat_opens_gate_and_sticks() -> void:
	print("Beating the Warden opens the gate, and it stays beaten")
	var boss := await _start_boss_fight()
	for i in boss.max_health:
		boss.take_hit(1, Vector2.RIGHT)
	var died_at := boss.global_position
	await _frames(3)
	_check(GameState.bosses_defeated.get("boss") is Vector2, "defeat recorded with where it fell")
	_check(_main._boss == null and not get_tree().get_nodes_in_group("enemy").any(func(e): return e is WardenBoss), "boss no longer an enemy")
	_check(is_instance_valid(boss) and boss._state == WardenBoss.State.DEAD, "corpse left in the arena")
	var hp_before := boss.health
	boss.take_hit(1, Vector2.RIGHT)
	_check(boss.health == hp_before and boss.collision_layer == 0, "corpse can't be hit")
	await _frames(30)
	_check(absf(boss.global_position.x - died_at.x) < 8.0, "corpse stayed where it died")
	_check(not _main._gate_closed and _main._gate_shapes.all(func(s): return s.disabled), "both gates open")
	_check(not _main._hud.is_boss_shown(), "boss bar hidden")
	_check(GameState.has_ability("dash"), "dash granted")
	await _frames(int(_main.CAMERA_RELEASE_TIME * 60) + 10)
	_check(get_viewport().get_camera_2d() == _player.camera and _main._arena_camera == null,
			"camera handed back to the player")
	get_tree().reload_current_scene()
	var room := await _wait_for_room("boss", 30)
	await _frames(3)
	_check(room != null and room._boss == null, "no live boss after reloading the room")
	var corpses := room.get_children().filter(func(c): return c is WardenBoss) if room != null else []
	_check(corpses.size() == 1 and corpses[0]._state == WardenBoss.State.DEAD, "corpse is back after reloading")
	_check(corpses.size() == 1 and absf(corpses[0].global_position.x - died_at.x) < 8.0, "in the same spot")
	await _despawn()


func _test_boss_hallway_door_to_climb_room_and_back() -> void:
	print("The door behind the arena leads to the climb room, and back")
	await _spawn(BOSS_SCENE, true)
	_place(61, 14)
	Input.action_press("move_right")
	var room := await _wait_for_room("climb", 120)
	Input.action_release("move_right")
	_check(room != null, "climb room loaded")
	if room == null:
		await _despawn()
		return
	await _frames(20)
	var p: Player = room._player
	_check(p.is_on_floor() and p.global_position.x < 4 * TILE and p.global_position.y > 42 * TILE,
			"arrived at the bottom-left door (col %.1f, row %.1f)" % [p.global_position.x / TILE, p.global_position.y / TILE])
	Input.action_press("move_left")
	room = await _wait_for_room("boss", 120)
	Input.action_release("move_left")
	_check(room != null, "back in the boss room")
	if room != null:
		await _frames(20)
		p = room._player
		_check(p.is_on_floor() and p.global_position.x > 60 * TILE,
				"arrived in the right hallway (col %.1f, row %.1f)" % [p.global_position.x / TILE, p.global_position.y / TILE])
	await _frames(20)   # let the fade finish before the next test
	await _despawn()


func _test_climb_route_jumps() -> void:
	print("The climb room can be climbed with plain jumps")
	await _spawn(CLIMB_SCENE)
	await _remove_enemies()
	await _check_route(CLIMB_ROUTE)
	await _despawn()


func _knights() -> Array:
	return get_tree().get_nodes_in_group("enemy").filter(func(e): return e is KnightEnemy)


# The knight on the first ledge (row 36, cols 20-29), with the others removed.
func _lone_knight() -> KnightEnemy:
	var keep: KnightEnemy = null
	for k in _knights():
		if absf(k.global_position.y - (36 * TILE - KnightEnemy.SIZE.y * 0.5)) < 4.0:
			keep = k
		else:
			k.queue_free()
	await _frames(1)
	return keep


func _test_knights_are_slow() -> void:
	print("Knights are as tall as the player and slow")
	await _spawn(CLIMB_SCENE)
	_check(_knights().size() == 3, "3 knights in the climb room (%d)" % _knights().size())
	_check(KnightEnemy.SIZE.y == Player.BODY_SIZE.y, "same height as the player")
	var knight := await _lone_knight()
	_player.process_mode = Node.PROCESS_MODE_DISABLED   # out of sight at the door
	await _frames(10)
	var x0 := knight.global_position.x
	var travelled := 0.0
	var prev := x0
	for i in 120:
		await _frames(1)
		travelled += absf(knight.global_position.x - prev)
		prev = knight.global_position.x
	var speed := travelled / 2.0
	_check(speed > 10.0, "it patrols (%.0f px/s)" % speed)
	_check(speed < _player.run_speed * 0.25, "at under a quarter of the player's run speed (%.0f vs %.0f)" % [speed, _player.run_speed])
	await _despawn()


func _test_knight_swing_hurts() -> void:
	print("Standing in front of a knight gets you hit by its sword")
	await _spawn(CLIMB_SCENE)
	var knight := await _lone_knight()
	_player.global_position = knight.global_position + Vector2(-50, 0)
	_player.velocity = Vector2.ZERO
	var frames := 0
	while _player.health == _player.max_health and frames < 180:
		await _frames(1)
		frames += 1
	_check(knight.swings >= 1, "knight swung (%d)" % knight.swings)
	_check(_player.health < _player.max_health, "player hit after %d frames" % frames)
	_check(frames >= int(knight.windup_time * 60) - 2, "only after the wind-up (%d frames)" % frames)
	await _despawn()


func _test_knight_swing_can_be_dodged() -> void:
	print("Backing off during the wind-up dodges the swing")
	await _spawn(CLIMB_SCENE)
	var knight := await _lone_knight()
	_player.global_position = knight.global_position + Vector2(-50, 0)
	_player.velocity = Vector2.ZERO
	for i in 60:
		await _frames(1)
		if knight._state == KnightEnemy.State.WINDUP:
			break
	_check(knight._state == KnightEnemy.State.WINDUP, "knight wound up")
	_player.global_position = knight.global_position + Vector2(-150, 0)
	_player.velocity = Vector2.ZERO
	await _frames(int((knight.windup_time + knight.swing_time) * 60) + 10)
	_check(knight.swings >= 1, "it swung anyway")
	_check(_player.health == _player.max_health, "and missed")
	await _despawn()


func _test_knight_kill_heals_half_heart() -> void:
	print("Killing a knight heals half a heart")
	await _spawn(CLIMB_SCENE)
	_player.health = 5
	var knight: KnightEnemy = _knights()[0]
	knight.take_hit(knight.max_health, Vector2.RIGHT)
	_check(_player.health == 6, "health 5 -> %d half-hearts" % _player.health)
	await _despawn()


func _press_pause() -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = "pause"
		event.pressed = pressed
		Input.parse_input_event(event)
	await _frames(2)


func _pause_menu() -> PauseMenu:
	for c in get_tree().current_scene.get_children():
		if c is PauseMenu:
			return c
	return null


func _test_pause_menu_toggles() -> void:
	print("Pause opens the pause menu; pause again or Resume closes it")
	await _spawn()
	var menu := _pause_menu()
	_check(menu != null and not menu.is_open(), "pause menu present, closed")
	await _press_pause()
	_check(menu.is_open() and get_tree().paused, "opened and paused")
	_check(menu._resume_button.has_focus(), "Resume focused")
	await _press_pause()
	_check(not menu.is_open() and not get_tree().paused, "closed and resumed with pause")
	await _press_pause()
	menu._resume_button.pressed.emit()
	_check(not menu.is_open() and not get_tree().paused, "closed and resumed with Resume")
	await _despawn()


func _test_pause_ignored_during_boss_intro() -> void:
	print("The pause menu doesn't open over the boss intro")
	await _spawn(BOSS_SCENE)
	_place(20, 14)
	await _walk_until_fight("move_right", 120)
	await _press_pause()
	_check(not _pause_menu().is_open(), "menu stayed closed")
	_check(await _wait_for_intro_end(), "intro still finished and unpaused")
	await _despawn()


func _test_main_menu_starts_game() -> void:
	print("Main menu: Start loads the first room with fresh progress")
	GameState.coins = 7
	GameState.unlock("dash")
	var menu := MENU_SCENE.instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await _frames(2)
	_check(menu.start_button.has_focus(), "Start focused")
	menu.start_button.pressed.emit()
	var room := await _wait_for_room("start", 120)
	_check(room != null, "first room loaded")
	_check(GameState.coins == 0 and not GameState.has_ability("dash"), "progress reset")
	if room != null:
		var p: Player = room._player
		_check(p.global_position.x < 5 * TILE, "starting at P (col %.1f)" % (p.global_position.x / TILE))
	await _frames(30)   # let the fade finish
	await _despawn()


func _test_pause_menu_quits_to_main_menu() -> void:
	print("Pause menu: Quit returns to the main menu")
	await _spawn()
	await _press_pause()
	var quit: Button = _pause_menu()._panel.find_children("*", "Button", true, false)[1]
	quit.pressed.emit()
	var at_menu := false
	for i in 120:
		await _frames(1)
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == MENU_SCENE.resource_path:
			at_menu = true
			break
	_check(at_menu, "main menu loaded")
	_check(not get_tree().paused, "game unpaused")
	await _frames(30)
	await _despawn()


func _items(kind: String) -> Array:
	return get_tree().current_scene.get_children().filter(
			func(c): return c is ItemPickup and c.kind == kind)


func _test_coin_counts_and_stays_collected() -> void:
	print("Coins count on the HUD and don't respawn on reload")
	await _spawn()
	var before := _items("coin").size()
	_place(10, 15)
	await _frames(5)
	_check(GameState.coins == 1, "coin counted (%d)" % GameState.coins)
	_check(_main._hud._coins_label.text == "Coins: 1", "HUD shows it (%s)" % _main._hud._coins_label.text)
	_check(_items("coin").size() == before - 1, "coin removed")
	get_tree().reload_current_scene()
	var room := await _wait_for_room("start", 30)
	await _frames(2)
	_check(room != null and _items("coin").size() == before - 1, "still gone after reload (%d of %d left)" % [_items("coin").size(), before])
	_check(room != null and room._hud._coins_label.text == "Coins: 1", "count kept after reload")
	await _despawn()


func _test_down_jump_drops_through_platform() -> void:
	print("Down + jump on a one-way platform drops through it")
	await _spawn()
	var top := 16 * TILE
	_player.global_position = Vector2(11.5 * TILE, top - Player.BODY_SIZE.y * 0.5)
	await _frames(10)
	_check(_player.is_on_floor(), "standing on the platform")
	Input.action_press("move_down")
	await _frames(1)
	Input.action_press("jump")
	var rose := false
	for i in 30:
		await _frames(1)
		rose = rose or _player.velocity.y < -100.0
	_release_all()
	_check(not rose, "didn't jump up")
	_check(_player.global_position.y - Player.BODY_SIZE.y * 0.5 > top, "fell below the platform (row %.1f)" % (_player.global_position.y / TILE))
	await _frames(30)
	_check(_player.get_collision_mask_value(Player.PLATFORM_LAYER_NUMBER), "platform collision restored")
	await _despawn()


func _test_down_jump_on_solid_ground_still_jumps() -> void:
	print("Down + jump on solid ground is still a jump")
	await _spawn()
	_place(5, 17)
	await _frames(5)
	Input.action_press("move_down")
	await _frames(1)
	Input.action_press("jump")
	var rose := false
	for i in 10:
		await _frames(1)
		rose = rose or _player.velocity.y < -100.0
	_release_all()
	_check(rose, "jumped")
	await _despawn()


func _test_crawler_kill_heals_half_heart() -> void:
	print("Killing a crawler heals half a heart")
	await _spawn()
	_player.health = 5
	var crawler: CrawlerEnemy = get_tree().get_nodes_in_group("enemy")[0]
	crawler.take_hit(crawler.max_health, Vector2.RIGHT)
	_check(_player.health == 6, "health 5 -> %d half-hearts" % _player.health)
	_check(_main._hud._health_bar.current == 6, "HUD updated")
	_player.health = _player.max_health
	get_tree().get_nodes_in_group("enemy")[1].take_hit(99, Vector2.RIGHT)
	_check(_player.health == _player.max_health, "no overheal")
	await _despawn()


func _test_health_pickup() -> void:
	print("Health pickup restores a heart, but waits while you're at full health")
	await _spawn()
	_place(101, 11)
	await _frames(5)
	_check(_items("health").size() == 1 and _player.health == _player.max_health, "left alone at full health")
	_player.health = 6
	await _frames(3)
	_check(_player.health == 8, "healed one heart (6 -> %d half-hearts)" % _player.health)
	_check(_items("health").is_empty(), "pickup used up")
	await _despawn()


# Jumps from the near edge of each platform to the next one (left or right).
# Tries a full jump, then shorter hops (jump released early) if something
# overhead catches the full one.
func _check_route(route: Array) -> void:
	for i in route.size() - 1:
		var from: Array = route[i]
		var to: Array = route[i + 1]
		var ok := false
		var how := ""
		for hold_frames in [999, 10, 5]:
			ok = await _try_jump(from, to, hold_frames)
			how = "full jump" if hold_frames == 999 else "short hop"
			if ok or _player._dead:
				break
		var x := _player.global_position.x
		_check(ok, "jump to cols %d-%d, row %d by %s (landed at col %.1f, row %.1f)" % [to[1], to[2], to[0], how, x / TILE, _player.global_position.y / TILE])
		if _player._dead:
			break


func _try_jump(from: Array, to: Array, hold_frames: int) -> bool:
	# Stand at the edge of the current platform facing the next one, jump toward
	# it, and stop steering once a tile past its near edge.
	var right: bool = to[1] + to[2] >= from[1] + from[2]
	var start_x: float = (from[2] + 1) * TILE - 12 if right else from[1] * TILE + 12
	_player.global_position = Vector2(start_x, from[0] * TILE - Player.BODY_SIZE.y * 0.5)
	_player.velocity = Vector2.ZERO
	await _frames(10)
	var move := "move_right" if right else "move_left"
	Input.action_press(move)
	Input.action_press("jump")
	var target_x: float = to[1] * TILE + TILE if right else to[2] * TILE
	var left_ground := false
	for f in 120:
		await _frames(1)
		if f == hold_frames:
			Input.action_release("jump")
		var x_now := _player.global_position.x
		if (right and x_now >= target_x) or (not right and x_now <= target_x):
			Input.action_release(move)
		if not _player.is_on_floor():
			left_ground = true
		elif left_ground:
			break
	_release_all()
	var landed_y: float = to[0] * TILE - Player.BODY_SIZE.y * 0.5
	var x := _player.global_position.x
	return not _player._dead and _player.is_on_floor() \
			and absf(_player.global_position.y - landed_y) < 4.0 \
			and x >= to[1] * TILE and x <= (to[2] + 1) * TILE


func _test_crawler_turns_at_wall() -> void:
	print("Crawlers turn around at walls, not just at ledges")
	await _spawn()
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	# The crawler on the floor just left of the inner wall (cols 44-45).
	var crawler: CrawlerEnemy = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is CrawlerEnemy and absf(e.global_position.x - 42.5 * TILE) < TILE and e.global_position.y > 16 * TILE:
			crawler = e
	_check(crawler != null, "found the crawler by the wall")
	if crawler == null:
		await _despawn()
		return
	var reached_wall_at := -1
	var max_x := 0.0
	for i in 1200:
		await _frames(1)
		max_x = maxf(max_x, crawler.global_position.x)
		if reached_wall_at < 0 and crawler.global_position.x > 43.4 * TILE:
			reached_wall_at = i
		if reached_wall_at >= 0 and i - reached_wall_at > 60:
			break
	_check(reached_wall_at >= 0, "walked up to the wall")
	_check(crawler._dir == -1 and crawler.global_position.x < max_x - TILE,
			"turned and walked away (now %.1f tiles from the wall)" % ((max_x - crawler.global_position.x) / TILE))
	await _despawn()


func _test_acid_enemies_stay_on_platforms() -> void:
	print("Acid-section crawlers patrol without falling off")
	await _spawn()
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	var start_y := {}
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.global_position.x > 60 * TILE:
			start_y[e] = e.global_position.y
	await _frames(300)
	for e in start_y:
		_check(absf(e.global_position.y - start_y[e]) < 4.0, "crawler at col %.1f still on its platform (row %.1f)" % [e.global_position.x / TILE, e.global_position.y / TILE])
	_check(start_y.size() == 2, "found 2 crawlers in the acid section (%d)" % start_y.size())
	await _despawn()


func _test_door_to_boss_room_and_back() -> void:
	print("Right-edge door leads to the boss room's lower corridor, and back")
	await _spawn()
	await _remove_enemies()
	_player.global_position = Vector2(102.5 * TILE, 12 * TILE - Player.BODY_SIZE.y * 0.5)
	Input.action_press("move_right")
	var room := await _wait_for_room("boss", 120)
	Input.action_release("move_right")
	_check(room != null, "boss room loaded")
	if room == null:
		await _despawn()
		return
	await _frames(20)
	var p: Player = room._player
	_check(GameState.arrived_from == "start", "arrival recorded from start")
	_check(p.is_on_floor() and p.global_position.x < 5 * TILE and absf(p.global_position.y - (29 * TILE - Player.BODY_SIZE.y * 0.5)) < 4.0,
			"arrived inside the lower corridor's door (col %.1f, row %.1f)" % [p.global_position.x / TILE, p.global_position.y / TILE])
	Input.action_press("move_left")
	room = await _wait_for_room("start", 300)
	Input.action_release("move_left")
	_check(room != null, "returned to the start room")
	if room != null:
		await _frames(20)
		p = room._player
		_check(p.is_on_floor() and p.global_position.x > 100 * TILE,
				"arrived on the ledge beside the door (col %.1f, row %.1f)" % [p.global_position.x / TILE, p.global_position.y / TILE])
	await _despawn()
