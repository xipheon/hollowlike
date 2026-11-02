extends Node
## Headless gameplay checks. Run everything with:
##   godot --headless --path . --fixed-fps 60 --quit-after 200000 res://tests/gameplay_test.tscn
## or just some segments (see SEGMENTS below):
##   godot --headless --path . --fixed-fps 60 --quit-after 200000 res://tests/gameplay_test.tscn -- --segment=warden,menus
## `-- --list` prints the segments. Exits with the number of failed checks
## (0 = all passed).
## --fixed-fps 60 steps every frame by exactly 1/60 s as fast as the CPU allows,
## instead of waiting in real time: the whole suite takes seconds, not minutes.
## --quit-after is a safety net so a broken test can't hang the run.

# Tests grouped by what they cover, so a change only needs its segments run.
# Each test spawns its own room, so segments run fine alone or in any order.
const SEGMENTS := {
	# Acid, spikes, safe-ground respawn, down-strikes (player.gd, room.gd hazards).
	"hazards": [
		"_test_acid_kills", "_test_acid_kills_through_invulnerability",
		"_test_spikes_hurt_and_respawn", "_test_spikes_respect_invulnerability",
		"_test_safe_ground_needs_both_feet", "_test_tapped_down_strike_ends",
		"_test_held_down_strike_ends", "_test_down_strike_doesnt_bounce_on_spikes",
	],
	# First room: layout routes, crawlers, one-way platforms, its door.
	"first_test_room": [
		"_test_acid_route_jumps", "_test_acid_enemies_stay_on_platforms", "_test_crawler_turns_at_wall",
		"_test_door_to_boss_room_and_back",
		"_test_down_jump_drops_through_platform", "_test_down_jump_on_solid_ground_still_jumps",
		"_test_pink_crawler_kill_heals", "_test_crawler_sludge", "_test_ceiling_crawler", "_test_room_lights_flicker",
		"_test_room_dimming",
	],
	# The tilesets' terrain brushes and tile data (tools/make_tilesets.gd, room_art.gd), the room template.
	"tilesets": [
		"_test_terrain_brushes", "_test_tiles_say_what_they_are", "_test_room_template",
		"_test_props_layer", "_test_pipe_brush", "_test_normal_maps",
	],
	# Rooms made in the editor: painted layers, helper nodes, decoration (room.gd, room_art.gd).
	"editor_rooms": [
		"_test_editor_room_plays", "_test_editor_room_door", "_test_editor_room_arena",
		"_test_decorate_wall_button", "_test_unpainted_wall_stays_open",
	],
	# Moving platforms and their track tiles (moving_platform.gd, tools/make_track_tiles.gd).
	"platforms": [
		"_test_track_brush", "_test_moving_platform_travel", "_test_moving_platform_carries_player",
		"_test_moving_platform_momentum",
	],
	# Every ceiling crawler placed in any room, and placed enemies' Inspector settings (enemy_crawler.gd, enemy_base.gd).
	"crawlers": [
		"_test_placed_ceiling_crawlers_stay_up", "_test_enemy_inspector_settings",
	],
	# Boss room layout around the arena: shafts, the drop, the acid gap, the climb door.
	"boss_room": [
		"_test_boss_room_shafts_climbable", "_test_right_hallway_drops_to_far_side",
		"_test_acid_gap_needs_dash", "_test_boss_hallway_door_to_climb_room_and_back",
	],
	# The Warden fight (boss_warden.gd, boss_shockwave.gd, room.gd boss/intro/camera code).
	"warden": [
		"_test_boss_fight_starts_and_gate_shuts", "_test_boss_fight_starts_from_right_side",
		"_test_boss_attacks_stay_in_arena", "_test_boss_hurts_player", "_test_player_attacks_hurt_boss",
		"_test_boss_defeat_opens_gate_and_sticks", "_test_warden_damage_split_and_phase_two",
		"_test_warden_charge_stops_at_player", "_test_camera_returns_to_player_after_boss",
		"_test_warden_attacks_light_up",
	],
	# Climb room route, thugs (enemy_thug.gd), and the door up to the Aerie.
	"climb": [
		"_test_climb_route_jumps", "_test_thugs_are_slow", "_test_thug_punch_hurts",
		"_test_thug_punch_can_be_dodged", "_test_thug_kill_doesnt_heal",
		"_test_thug_blocks", "_test_thug_pauses", "_test_thug_punch_reach",
		"_test_climb_top_door_to_aerie_and_back",
	],
	# The Harrier fight (boss_harrier.gd, boss_feather.gd).
	"harrier": [
		"_test_harrier_flies_and_swoops", "_test_harrier_shallow_swoop_hits_standing_player",
		"_test_harrier_swoops_ignore_player_height", "_test_harrier_phase_two_cycle",
		"_test_harrier_feathers", "_test_homing_feather_limits", "_test_harrier_pulls_up_after_hitting_you",
		"_test_harrier_crashes_when_it_misses", "_test_harrier_armor_except_dazed", "_test_harrier_dazed_recoil",
		"_test_harrier_defeat_grants_wall_jump", "_test_harrier_feathers_glow",
	],
	# Damage numbers and armor, sprint and stamina (player.gd, enemy damage settings).
	"player": [
		"_test_double_jump", "_test_player_animations", "_test_attack_buffer", "_test_enemies_set_their_own_damage", "_test_armor_reduces_damage",
		"_test_sprint_is_faster_and_drains_stamina", "_test_stamina_refills_only_on_ground",
		"_test_dash_needs_stamina", "_test_dash_eight_directions", "_test_wall_jump_needs_stamina",
		"_test_hit_recoil", "_test_player_light",
	],
	# Translations: localization/<language>/<feature>.po, keys in use, switching language (game_state.gd).
	"localization": [
		"_test_translation_files_registered", "_test_every_key_has_english", "_test_language_switch",
	],
	# Pause menu, main menu, level select, debug tools.
	"menus": [
		"_test_pause_menu_toggles", "_test_pause_ignored_during_boss_intro",
		"_test_debug_kill_boss", "_test_debug_kill_boss_off_outside_debug_mode",
		"_test_main_menu_starts_game", "_test_level_select_loads_each_room",
		"_test_pause_menu_quits_to_main_menu", "_test_pause_menu_skins", "_test_death_screen",
	],
}

const TILE := 32
const FIRST_TEST_ROOM_SCENE := preload("res://scenes/first_test_room.tscn")
const BOSS_SCENE := preload("res://scenes/boss_room.tscn")
const CLIMB_SCENE := preload("res://scenes/climb_room.tscn")
const AERIE_SCENE := preload("res://scenes/aerie_room.tscn")
const MENU_SCENE := preload("res://scenes/main_menu.tscn")

# Climb room, bottom to top. Solid ledges sit 2 rows above the platform before
# them (a 3-row rise onto a solid ledge is too tight to clear its edge).
const CLIMB_ROUTE := [
	[44, 0, 5],     # floor, up to just beside the first platform
	[41, 6, 11],
	[38, 13, 18],
	[36, 20, 29],   # thug ledge
	[33, 12, 16],
	[31, 0, 8],     # thug ledge
	[28, 11, 15],
	[25, 17, 21],
	[23, 23, 29],   # thug ledge
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

var _fails := 0
var _main: Node2D
var _player: Player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep driving checks through the paused boss intro
	TranslationServer.set_locale("en")   # checks read English text, whatever language is saved here
	await get_tree().process_frame   # root can't take new children during startup
	var chosen := _chosen_segments()
	if chosen.is_empty():
		get_tree().quit(1)
		return
	var timings: PackedStringArray = []
	for segment in chosen:
		print("\n==== %s ====" % segment)
		var started := Time.get_ticks_msec()
		for test in SEGMENTS[segment]:
			await call(test)
		timings.append("%s %.0fs" % [segment, (Time.get_ticks_msec() - started) / 1000.0])
	print("\nRan: %s" % ", ".join(timings))
	print("%s: %d failed check(s)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)


# Segments named after `-- --segment=` (comma-separated), or all of them.
# Prints the list and returns nothing for `-- --list` or an unknown name.
func _chosen_segments() -> Array:
	var names: Array = SEGMENTS.keys()
	for arg in OS.get_cmdline_user_args():
		if arg == "--list":
			names = []
		elif arg.begins_with("--segment="):
			names = Array(arg.trim_prefix("--segment=").split(",", false))
	var unknown := names.filter(func(n): return not SEGMENTS.has(n))
	if names.is_empty() or not unknown.is_empty():
		if not unknown.is_empty():
			print("Unknown segment(s): %s" % ", ".join(unknown))
		for segment in SEGMENTS:
			print("  %-12s %d tests" % [segment, SEGMENTS[segment].size()])
		return []
	return names


# ------------------------------------------------------------- Helpers ----

# Rooms run as the tree's current scene (beside this test node, not under it),
# so door transitions and death reloads replace the room, not the test.
func _spawn(scene: PackedScene = FIRST_TEST_ROOM_SCENE, boss_beaten := false) -> void:
	await _spawn_node(scene.instantiate(), boss_beaten)


# Like _spawn, for a room built in the test instead of loaded from a scene.
func _spawn_node(room: Node, boss_beaten := false) -> void:
	GameState.arrived_from = ""
	GameState.arrive_at = ""
	GameState.bosses_defeated = {"boss": Vector2(49.5 * TILE, 15 * TILE - WardenBoss.SIZE.y * 0.5)} if boss_beaten else {}
	GameState.carried_health = -1
	GameState.player_skin = PlayerSprite.DEFAULT_SKIN
	GameState.abilities = GameState.STARTING_ABILITIES.duplicate()
	GameState.debug_mode = true
	_main = room
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_player = _main._player
	await _frames(2)


## Every node in a room, however deep (enemies and bosses sit under Entities,
## and what they spawn lands beside them).
func _all(room: Node) -> Array:
	return room.find_children("*", "", true, false)


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
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "attack", "dash", "sprint"]:
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
	_check(_player.health == _player.max_health - Player.DEFAULT_HIT_DAMAGE, "lost exactly one heart (%d/%d)" % [_player.health, _player.max_health])
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


func _test_held_down_strike_ends() -> void:
	print("Holding attack doesn't keep the down-strike out: it lasts like any swing")
	await _spawn()
	_place(32, 0)   # long fall into the spike pit
	await _frames(5)
	Input.action_press("move_down")
	Input.action_press("attack")
	await _frames(2)
	_check(_player._attack_timer > 0.0 and _player._attack_dir == Vector2.DOWN, "strike went downward")
	await _frames(15)
	_check(not _player.is_on_floor(), "still airborne")
	_check(_player._attack_timer <= 0.0, "strike ended though attack is still held")
	_release_all()
	await _despawn()


func _test_down_strike_doesnt_bounce_on_spikes() -> void:
	print("A down-strike on spikes doesn't bounce you: you land on them and get hurt")
	await _spawn()
	_place(32, 9)
	Input.action_press("move_down")
	var spike_top: float = 19 * TILE + TILE - _main.SPIKE_HEIGHT
	var swung := false
	var rose := false
	for i in 120:
		# Swing as you drop to within reach of the spikes.
		if not swung and _player.velocity.y > 0.0 and _player.global_position.y > spike_top - 70.0:
			Input.action_press("attack")
			swung = true
		await _frames(1)
		Input.action_release("attack")
		if swung and _player.velocity.y < -100.0 and _player.health == _player.max_health:
			rose = true
		if _player.health < _player.max_health:
			break
	_release_all()
	_check(swung and not rose, "the strike didn't bounce you up")
	_check(_player.health < _player.max_health, "the spikes hurt (%d of %d)" % [_player.health, _player.max_health])
	await _despawn()


func _test_acid_route_jumps() -> void:
	print("Every acid-section jump is makeable with a plain jump")
	await _spawn()
	await _remove_enemies()
	await _check_route(ACID_ROUTE)
	await _despawn()


func _test_boss_room_shafts_climbable() -> void:
	print("The left boss-room shaft can be climbed with plain jumps")
	await _spawn(BOSS_SCENE, true)
	var crawlers := get_tree().get_nodes_in_group("enemy").filter(func(e): return e is CrawlerEnemy and not e.on_ceiling)
	var in_shaft := crawlers.filter(func(c): return c.global_position.x < 11 * TILE and c.global_position.y > 16 * TILE)
	_check(not in_shaft.is_empty(), "a floor crawler guards the left shaft (%d)" % in_shaft.size())
	await _remove_enemies()
	await _check_route(BOSS_LEFT_SHAFT)
	await _despawn()


func _test_right_hallway_drops_to_far_side() -> void:
	print("The right hallway's shaft drops to the corridor past the acid pools")
	await _spawn(BOSS_SCENE, true)
	await _remove_enemies()
	_place(63, 14)
	for i in 120:
		await _frames(1)
		if _player.global_position.y > 25 * TILE and _player.is_on_floor():
			break
	var p := _player.global_position
	_check(_player.is_on_floor() and p.y > 25 * TILE and p.x > 55 * TILE and not _player._dead,
			"landed below, past the acid (col %.1f, row %.1f)" % [p.x / TILE, p.y / TILE])
	await _despawn()


# Runs at the acid gap from `from_col` toward `dir`, jumps at the edge and
# dashes at the top of the jump. Returns true if it lands safely across.
# Jumps off the edge and, near the top of the jump, dashes, or with
# `air_jump` double-jumps instead.
func _try_acid_dash_crossing(from_col: float, dir: int, edge_col: float, far_col: float, floor_row := 29, air_jump := false) -> bool:
	_player.global_position = Vector2(from_col * TILE, floor_row * TILE - Player.BODY_SIZE.y * 0.5)
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
			# Near the top of the jump.
			if air_jump:
				Input.action_release("jump")
				await _frames(1)
				Input.action_press("jump")
			else:
				Input.action_press("dash")
			dashed = true
		elif dashed and not air_jump:
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
	_check(not await _try_acid_dash_crossing(27, 1, 34, 42, 29, true), "no crossing with a double jump either")
	await _despawn()
	await _spawn(BOSS_SCENE, true)
	await _remove_enemies()
	GameState.unlock("dash")
	_check(await _try_acid_dash_crossing(27, 1, 34, 42), "dash crosses left to right (col %.1f)" % (_player.global_position.x / TILE))
	# Back from the raised block (cols 42-44) between this gap and the next pool.
	_check(await _try_acid_dash_crossing(44.5, -1, 42, 34, 28), "dash crosses right to left (col %.1f)" % (_player.global_position.x / TILE))
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
	_place(57, 14)
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
			for c in _all(_main):
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
	var corpses := _all(room).filter(func(c): return c is WardenBoss) if room != null else []
	_check(corpses.size() == 1 and corpses[0]._state == WardenBoss.State.DEAD, "corpse is back after reloading")
	_check(corpses.size() == 1 and absf(corpses[0].global_position.x - died_at.x) < 8.0, "in the same spot")
	await _despawn()


func _test_boss_hallway_door_to_climb_room_and_back() -> void:
	print("The lower corridor's right door leads to the climb room, and back")
	await _spawn(BOSS_SCENE, true)
	_place(86, 28)
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
		_check(p.is_on_floor() and p.global_position.x > 84 * TILE and p.global_position.y > 27 * TILE,
				"arrived inside the corridor's right door (col %.1f, row %.1f)" % [p.global_position.x / TILE, p.global_position.y / TILE])
	await _frames(20)   # let the fade finish before the next test
	await _despawn()


func _test_climb_route_jumps() -> void:
	print("The climb room can be climbed with plain jumps")
	await _spawn(CLIMB_SCENE)
	await _remove_enemies()
	await _check_route(CLIMB_ROUTE)
	await _despawn()


func _thugs() -> Array:
	return get_tree().get_nodes_in_group("enemy").filter(func(e): return e is ThugEnemy)


# The lowest thug in the room (the first one you meet climbing), with the others removed.
func _lone_thug() -> ThugEnemy:
	var thugs := _thugs()
	thugs.sort_custom(func(a, b): return a.global_position.y > b.global_position.y)
	for k in thugs.slice(1):
		k.queue_free()
	await _frames(1)
	return thugs[0] if not thugs.is_empty() else null


func _test_thugs_are_slow() -> void:
	print("Thugs are as tall as the player and slower")
	await _spawn(CLIMB_SCENE)
	_check(not _thugs().is_empty(), "thugs in the climb room (%d)" % _thugs().size())
	_check(ThugEnemy.SIZE.y == Player.BODY_SIZE.y, "same height as the player")
	var thug := await _lone_thug()
	thug.patrol_time = Vector2(999, 999)   # no pauses while its speed is measured
	_player.process_mode = Node.PROCESS_MODE_DISABLED   # out of sight at the door
	await _frames(10)
	var x0 := thug.global_position.x
	var travelled := 0.0
	var prev := x0
	for i in 120:
		await _frames(1)
		travelled += absf(thug.global_position.x - prev)
		prev = thug.global_position.x
	var speed := travelled / 2.0
	_check(speed > 10.0, "it patrols (%.0f px/s)" % speed)
	_check(speed < _player.run_speed * 0.5, "at under half the player's run speed (%.0f vs %.0f)" % [speed, _player.run_speed])
	await _despawn()


func _test_thug_punch_hurts() -> void:
	print("Standing in front of a thug gets you punched")
	await _spawn(CLIMB_SCENE)
	var thug := await _lone_thug()
	_player.global_position = thug.global_position + Vector2(-50, 0)
	_player.velocity = Vector2.ZERO
	var frames := 0
	while _player.health == _player.max_health and frames < 180:
		await _frames(1)
		frames += 1
	_check(thug.swings >= 1, "thug swung (%d)" % thug.swings)
	_check(_player.health < _player.max_health, "player hit after %d frames" % frames)
	_check(frames >= int(thug.windup_time * 60) - 2, "only after the wind-up (%d frames)" % frames)
	await _despawn()


func _test_thug_punch_can_be_dodged() -> void:
	print("Backing off during the wind-up dodges the punch")
	await _spawn(CLIMB_SCENE)
	var thug := await _lone_thug()
	_player.global_position = thug.global_position + Vector2(-50, 0)
	_player.velocity = Vector2.ZERO
	for i in 60:
		await _frames(1)
		if thug._state == ThugEnemy.State.WINDUP:
			break
	_check(thug._state == ThugEnemy.State.WINDUP, "thug wound up")
	_player.global_position = thug.global_position + Vector2(-150, 0)
	_player.velocity = Vector2.ZERO
	await _frames(int((thug.windup_time + thug.swing_time) * 60) + 10)
	_check(thug.swings >= 1, "it swung anyway")
	_check(_player.health == _player.max_health, "and missed")
	await _despawn()


func _test_thug_kill_doesnt_heal() -> void:
	print("Killing a thug doesn't heal (only pink crawlers do)")
	await _spawn(CLIMB_SCENE)
	_player.health = 5
	var thug: ThugEnemy = _thugs()[0]
	thug.take_hit(thug.max_health + thug.block_reduction, Vector2.RIGHT)   # through a block too
	await _frames(1)
	_check(not is_instance_valid(thug), "thug died")
	_check(_player.health == 5, "health stayed at %d half-hearts" % _player.health)
	await _despawn()


func _test_thug_blocks() -> void:
	print("Thugs block (guard up) while paused or winding up: hits do block_reduction less; walking, they don't")
	await _spawn(CLIMB_SCENE)
	var thug := await _lone_thug()
	thug.patrol_time = Vector2(999, 999)   # no pause of its own while walking
	_player.visible = false   # nobody to chase
	await _frames(20)
	var hp := thug.health
	_check(thug._state == ThugEnemy.State.PATROL and absf(thug.velocity.x) > 1.0 and not thug.is_blocking()
			and thug.sprite.animation == "walk" and thug.sprite.flip_h == (thug._dir < 0),
			"walking, facing its way: guard down")
	thug.take_hit(1, Vector2.RIGHT)
	_check(thug.health == hp - 1, "a hit while walking does full damage (%d -> %d)" % [hp, thug.health])

	thug._enter(ThugEnemy.State.PAUSE, 5.0)
	await _frames(2)
	hp = thug.health
	thug.take_hit(2, Vector2.RIGHT)
	_check(thug.is_blocking() and thug.sprite.animation == "block", "paused: guard up (%s)" % thug.sprite.animation)
	_check(thug.health == hp - (2 - thug.block_reduction),
			"a 2-damage hit does %d less (%d -> %d)" % [thug.block_reduction, hp, thug.health])
	await _frames(2)
	_check(thug.sprite.self_modulate == ThugEnemy.BLOCK_FLASH, "and flashes blue-grey")

	# Winding up a punch at the player is guarded too.
	_player.visible = true
	_player._invuln_timer = 999.0
	_player.global_position = thug.global_position + Vector2(-50, 0)
	_player.velocity = Vector2.ZERO
	for i in 60:
		await _frames(1)
		if thug._state == ThugEnemy.State.WINDUP:
			break
	hp = thug.health
	thug.take_hit(1, Vector2.RIGHT)
	_check(thug._state == ThugEnemy.State.WINDUP and thug.sprite.animation == "block"
			and thug.health == hp - maxi(1 - thug.block_reduction, 0),
			"winding up: guard up, a 1-damage hit does %d" % (hp - thug.health))
	await _despawn()


func _test_thug_pauses() -> void:
	print("Thugs now and then stop patrolling for pause_time, then walk on")
	await _spawn(CLIMB_SCENE)
	var thug := await _lone_thug()
	thug.patrol_time = Vector2(0.5, 0.5)
	thug._patrol_left = 0.5
	_player.visible = false
	var paused_at := -1
	var resumed_at := -1
	var still := true
	for i in 120:
		await _frames(1)
		if paused_at < 0 and thug._state == ThugEnemy.State.PAUSE:
			paused_at = i
		elif paused_at >= 0 and resumed_at < 0:
			if thug._state == ThugEnemy.State.PATROL and absf(thug.velocity.x) > 1.0:
				resumed_at = i
			else:
				still = still and absf(thug.velocity.x) < 1.0
	_check(paused_at >= 0 and paused_at <= 40, "stopped after about patrol_time (frame %d)" % paused_at)
	var paused_for := (resumed_at - paused_at) / 60.0
	_check(resumed_at > 0 and still and absf(paused_for - thug.pause_time) < 0.1,
			"stood still for %.2f s (pause_time %.2f), then walked on" % [paused_for, thug.pause_time])
	await _despawn()


# Waits until the player's health drops, up to max_frames. Returns how much it dropped.
func _wait_for_hit(max_frames: int) -> int:
	var before := _player.health
	for i in max_frames:
		await _frames(1)
		if _player.health < before:
			break
	return before - _player.health


func _test_enemies_set_their_own_damage() -> void:
	print("Each enemy hits for its own damage: a crawler, a thug, the Warden's body")
	await _spawn()
	var crawler: CrawlerEnemy = get_tree().get_nodes_in_group("enemy")[0]
	_player.global_position = crawler.global_position + Vector2(0, -6)
	_check(await _wait_for_hit(30) == crawler.damage, "crawler hit for %d half-hearts" % crawler.damage)
	await _despawn()

	await _spawn(CLIMB_SCENE)
	var thug := await _lone_thug()
	_player.global_position = thug.global_position + Vector2(-50, 0)
	_player.velocity = Vector2.ZERO
	var lost := await _wait_for_hit(180)
	_check(lost == thug.damage, "thug hit for %d half-hearts (its damage: %d)" % [lost, thug.damage])
	await _despawn()

	var boss := await _start_boss_fight()
	_player.global_position = boss.global_position + Vector2(0, WardenBoss.SIZE.y * 0.5 - Player.BODY_SIZE.y * 0.5)
	lost = await _wait_for_hit(30)
	_check(lost == 2, "Warden body hit for %d half-hearts" % lost)
	await _despawn()


func _test_warden_damage_split_and_phase_two() -> void:
	print("Warden: body 2, shockwave 1, both +1 in phase two")
	var boss := await _start_boss_fight()
	_check(boss._hitbox.get_meta("damage") == 2, "body 2")
	boss._shockwave()
	var waves := _all(_main).filter(func(c): return c is WardenShockwave)
	_check(waves.size() == 2 and waves.all(func(w): return w.get_meta("damage") == 1), "shockwaves 1")
	for w in waves:
		w.queue_free()
	boss.health = boss.max_health / 2 + 1
	boss.take_hit(1, Vector2.RIGHT)
	_check(boss.is_phase_two() and boss._hitbox.get_meta("damage") == 3, "phase two body 3")
	await _frames(1)
	boss._charge_end()   # phase two: hitting a wall sends shockwaves too
	waves = _all(_main).filter(func(c): return c is WardenShockwave)
	_check(waves.size() == 2 and waves.all(func(w): return w.get_meta("damage") == 2), "phase two shockwaves 2, from a wall hit")
	await _despawn()


func _test_warden_attacks_light_up() -> void:
	print("Warden: the slam flashes orange at its feet, and its shockwaves glow as they go")
	var boss := await _start_boss_fight()
	boss._shockwave()
	var flashes := _all(_main).filter(func(c): return c is LightFlash)
	_check(flashes.size() == 1 and flashes[0].color == WardenShockwave.COLOR and is_equal_approx(flashes[0].energy, boss.slam_flash_energy)
			and flashes[0].global_position.is_equal_approx(boss.global_position + Vector2(0, WardenBoss.SIZE.y * 0.5)),
			"one flash at its feet, in the shockwaves' colour")
	var waves := _all(_main).filter(func(c): return c is WardenShockwave)
	_check(waves.size() == 2 and waves.all(func(w): return w.light.color == WardenShockwave.COLOR and is_equal_approx(w.light.energy, WardenShockwave.LIGHT_ENERGY)),
			"each shockwave carries its own light")
	await _frames(int(boss.slam_flash_time * 60) + 2)
	_check(flashes.size() == 1 and not is_instance_valid(flashes[0]), "the flash is gone after %.2f s" % boss.slam_flash_time)
	await _despawn()


func _test_warden_charge_stops_at_player() -> void:
	for running_away in [false, true]:
		print("Warden: a charge stops when it hits you, without the daze (%s)" % ["running away" if running_away else "standing"])
		var boss := await _start_boss_fight()
		await _frames(1)
		var floor_y := boss.global_position.y + WardenBoss.SIZE.y * 0.5 - Player.BODY_SIZE.y * 0.5
		_player.global_position = Vector2(boss.global_position.x - 200, floor_y)
		var hp := _player.health
		if running_away:
			Input.action_press("move_left")
		boss._dir = -1
		boss._enter(WardenBoss.State.CHARGE, 3.0)
		var stopped_at := 0.0
		for i in 90:
			await _frames(1)
			if boss._state != WardenBoss.State.CHARGE:
				stopped_at = boss.global_position.x
				break
		_release_all()
		await _frames(3)
		_check(_player.health == hp - boss.body_damage, "the hit landed (%d half-hearts)" % (hp - _player.health))
		_check(boss._state == WardenBoss.State.RECOVER, "stopped and recovering, not dazed (%s)" % WardenBoss.State.keys()[boss._state])
		_check(stopped_at - boss.arena_left > 2 * TILE, "short of the wall (%.1f tiles out)" % ((stopped_at - boss.arena_left) / TILE))
		await _despawn()


func _test_camera_returns_to_player_after_boss() -> void:
	print("After the boss dies the camera glides to where the player is now")
	await _start_boss_fight()
	_place(27, 14)   # far from where the fight started (col 40)
	await _frames(5)
	_main.debug_kill_boss()
	var target: Vector2 = _main._player_camera_target()
	await _frames(int(_main.CAMERA_RELEASE_TIME * 60) + 10)
	var cam := get_viewport().get_camera_2d()
	_check(cam == _player.camera, "player camera is current")
	var centre := cam.get_screen_center_position()
	_check(centre.distance_to(target) < 4.0, "centred on the player (off by %.0f px)" % centre.distance_to(target))
	await _despawn()


func _test_climb_top_door_to_aerie_and_back() -> void:
	print("The door at the top of the climb leads to the Harrier's arena, and back")
	await _spawn(CLIMB_SCENE)
	await _remove_enemies()
	_place(26, 3)
	Input.action_press("move_right")
	var room := await _wait_for_room("aerie", 120)
	Input.action_release("move_right")
	_check(room != null, "aerie loaded")
	if room == null:
		await _despawn()
		return
	await _frames(20)
	var p: Player = room._player
	_check(p.is_on_floor() and p.global_position.x < 4 * TILE and p.global_position.y > 15 * TILE,
			"arrived in the hallway (col %.1f, row %.1f)" % [p.global_position.x / TILE, p.global_position.y / TILE])
	_check(room._boss is HarrierBoss and not room._boss_fight_started, "Harrier waiting")
	Input.action_press("move_left")
	room = await _wait_for_room("climb", 120)
	Input.action_release("move_left")
	_check(room != null, "back in the climb room")
	if room != null:
		await _frames(20)
		p = room._player
		_check(p.is_on_floor() and p.global_position.x > 25 * TILE and p.global_position.y < 5 * TILE,
				"arrived on the top ledge (col %.1f, row %.1f)" % [p.global_position.x / TILE, p.global_position.y / TILE])
	await _frames(20)
	await _despawn()


# Walks into the Harrier's arena and waits out the intro.
func _start_harrier_fight() -> HarrierBoss:
	seed(1)
	await _spawn(AERIE_SCENE)
	_place(15, 15)
	await _frames(3)
	_check(await _wait_for_intro_end(), "intro cutscene finished")
	_check(get_viewport().get_camera_2d() == _main._arena_camera, "camera locked on the arena")
	# Feathers and swoops land a lot of hits on a player standing still; enough
	# health to sit through a whole cycle.
	_player.max_health = 99
	_player.health = 99
	return _main._boss


func _test_harrier_flies_and_swoops() -> void:
	print("Harrier phase one: feathers up close, then shallow swoops and a full swoop from the far side")
	var boss := await _start_harrier_fight()
	_player._invuln_timer = 999.0
	var in_bounds := true
	var hover_frames := 0
	var hover_far_side := 0
	var feather_hover_frames := 0
	var feather_hover_close := 0
	var most_homing := 0
	var shallow_lowest := -INF
	var shallow_touched_floor := false
	var shallow_min_x := INF
	var shallow_max_x := -INF
	var arena_mid := (boss.arena_left + boss.arena_right) * 0.5
	for i in 1800:
		await _frames(1)
		var p := boss.global_position
		var settled := p.distance_to(boss._hover_spot()) < HarrierBoss.HOVER_ARRIVE_DISTANCE
		if boss.is_feather_phase() and settled:
			feather_hover_frames += 1
			if absf(p.x - _player.global_position.x) < 5 * TILE:
				feather_hover_close += 1
		elif boss._state == HarrierBoss.State.HOVER and settled:
			hover_frames += 1
			if signf(p.x - arena_mid) != signf(_player.global_position.x - arena_mid):
				hover_far_side += 1
		most_homing = maxi(most_homing, _feathers().filter(func(f): return f.homing).size())
		if boss._state == HarrierBoss.State.SHALLOW:
			shallow_lowest = maxf(shallow_lowest, p.y)
			shallow_touched_floor = shallow_touched_floor or boss.is_on_floor()
			shallow_min_x = minf(shallow_min_x, p.x)
			shallow_max_x = maxf(shallow_max_x, p.x)
		if p.x < boss.arena_left or p.x > boss.arena_right or p.y < boss.arena_top or p.y > boss.arena_bottom:
			in_bounds = false
		if boss.attack_log.size() >= 6:
			break
	print("        attacks: %s" % [boss.attack_log])
	_check(boss.attack_log.slice(0, 6) == ["shot", "shot", "homing", "shallow", "shallow", "swoop"],
			"cycle: 2 fans, homing, 2 shallow swoops, a full swoop")
	_check(most_homing == 1, "a single homing feather in phase one (%d)" % most_homing)
	_check(feather_hover_frames > 20 and feather_hover_close == feather_hover_frames,
			"hovers close to you for feathers (%d/%d frames)" % [feather_hover_close, feather_hover_frames])
	_check(hover_frames > 20 and hover_far_side == hover_frames,
			"hovers on the far side from you for swoops (%d/%d frames)" % [hover_far_side, hover_frames])
	_check(boss.shallow_windup_time < boss.windup_time, "shallow swoops have the shorter telegraph")
	var arena_width := boss.arena_right - boss.arena_left
	_check(shallow_max_x - shallow_min_x > arena_width * 0.75,
			"shallow swoops go wall to wall (%.0f of %.0f px)" % [shallow_max_x - shallow_min_x, arena_width])
	var gap := boss.arena_bottom - (shallow_lowest + HarrierBoss.SIZE.y * 0.5)
	_check(not shallow_touched_floor and gap > 0.0, "shallow swoops stay off the floor (lowest %.0f px above it)" % gap)
	_check(absf(shallow_lowest - _player.global_position.y) < 6.0,
			"and skim close to the ground, through a standing player (%.0f px off their middle)" % (shallow_lowest - _player.global_position.y))
	_check(in_bounds, "stayed inside the arena")
	await _despawn()


func _test_harrier_shallow_swoop_hits_standing_player() -> void:
	print("Harrier: a shallow swoop hits a player standing still")
	var boss := await _start_harrier_fight()
	for i in 1500:
		await _frames(1)
		if boss._state == HarrierBoss.State.SHALLOW_WINDUP:
			break
	_place(15, 15)   # standing on the floor (feather hits may have knocked us about)
	_player._invuln_timer = 0.0
	for i in 60:
		await _frames(1)
		if boss._state == HarrierBoss.State.SHALLOW:
			break
	var hp := _player.health
	for i in 180:
		await _frames(1)
		if boss._state != HarrierBoss.State.SHALLOW:
			break
	_check(_player.health == hp - boss.damage, "hit by a shallow swoop (%d half-hearts)" % (hp - _player.health))
	await _despawn()


func _test_harrier_swoops_ignore_player_height() -> void:
	print("Harrier: swoops go to the ground under you, even when you're up in the air")
	var boss := await _start_harrier_fight()
	# The hall has no perches any more, so hold the player in mid-air at the old perch height.
	_player._invuln_timer = 999.0
	_player.global_position = Vector2(10.5 * TILE, 10 * TILE - Player.BODY_SIZE.y * 0.5)
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	var lowest := -INF
	var dive_target_y := 0.0
	for i in 1800:
		await _frames(1)
		if boss._state == HarrierBoss.State.SHALLOW:
			lowest = maxf(lowest, boss.global_position.y)
		if boss._state == HarrierBoss.State.SWOOP_WINDUP:
			# Where the locked dive line reaches skimming height (centre half a body above the floor).
			var d := boss._swoop_dir
			var t := (boss.arena_bottom - HarrierBoss.SIZE.y * 0.5 - boss.global_position.y) / d.y
			dive_target_y = boss.global_position.y + d.y * t
			var dive_target_x := boss.global_position.x + d.x * t
			_check(absf(dive_target_x - _player.global_position.x) < 1.0 * TILE,
					"full swoop aims at the floor under the player (%.1f tiles off)" % ((dive_target_x - _player.global_position.x) / TILE))
			break
	_check(_player.global_position.y < 10 * TILE, "player stayed up in the air")
	_check(lowest > boss.arena_bottom - 2 * TILE, "shallow swoops still skim the floor (%.0f px above it)" % (boss.arena_bottom - lowest))
	await _despawn()


func _feathers() -> Array:
	return _all(_main).filter(func(c): return c is HarrierFeather)


func _test_harrier_phase_two_cycle() -> void:
	print("Harrier phase two: 2 feather fans, a homing volley, shallow swoops, full swoop, repeat")
	var boss := await _start_harrier_fight()
	boss.health = boss.max_health / 2   # before its first attack
	_player._invuln_timer = 999.0
	var fan_sizes: Array[int] = []
	var seen := {}
	var homing_alive_at_shallow := false
	for i in 1500:
		await _frames(1)
		var fresh := _feathers().filter(func(f): return not seen.has(f))
		for f in fresh:
			seen[f] = true
		var plain := fresh.filter(func(f): return not f.homing)
		if not plain.is_empty():
			fan_sizes.append(plain.size())
		if boss._state == HarrierBoss.State.SHALLOW_WINDUP and _feathers().any(func(f): return f.homing):
			homing_alive_at_shallow = true
		if boss.attack_log.size() >= 8:
			break
	print("        attacks: %s" % [boss.attack_log])
	_check(boss.attack_log.slice(0, 8) == ["shot", "shot", "homing", "shallow", "shallow", "swoop", "shot", "shot"],
			"2 fans, homing, 2 shallow swoops, a full swoop, then back to fans")
	_check(fan_sizes.size() >= 2 and fan_sizes.all(func(n): return n == 3), "each fan is 3 feathers %s" % [fan_sizes])
	_check(not homing_alive_at_shallow, "waited for the homing feathers before swooping")
	await _despawn()


func _test_harrier_feathers_glow() -> void:
	print("Harrier feathers glow in their colour; homing ones brighter")
	var boss := await _start_harrier_fight()
	var plain := boss._spawn_feather(Vector2.DOWN, boss.shot_speed, false)
	var homing := boss._spawn_feather(Vector2.DOWN, boss.homing_speed, true)
	await _frames(1)
	_check(plain.light.color == HarrierFeather.COLOR and is_equal_approx(plain.light.energy, HarrierFeather.LIGHT_ENERGY), "a plain feather glows its colour")
	_check(homing.light.color == HarrierFeather.HOMING_COLOR and is_equal_approx(homing.light.energy, HarrierFeather.HOMING_LIGHT_ENERGY)
			and homing.light.energy > plain.light.energy, "a homing feather glows brighter, in its own colour")
	await _despawn()


func _test_harrier_feathers() -> void:
	print("Harrier feathers: fans spread at half speed; homing feathers curve in and can be struck")
	var boss := await _start_harrier_fight()
	boss.health = boss.max_health / 2
	boss._fire_fan()
	var fan := _feathers()
	_check(fan.size() == 3, "fan of 3")
	if fan.size() == 3:
		var angles: Array = fan.map(func(f): return rad_to_deg(f.direction.angle()))
		angles.sort()
		_check(absf(angles[1] - angles[0] - boss.fan_spread_degrees) < 0.5 and absf(angles[2] - angles[1] - boss.fan_spread_degrees) < 0.5,
				"spread %.0f degrees apart" % boss.fan_spread_degrees)
		_check(is_equal_approx(fan[0].speed, 230.0 * boss.phase_two_speedup), "half the old speed (230, x phase two speed-up)")
	for f in fan:
		f.queue_free()
	await _frames(1)

	boss._fire_homing()
	var homing := _feathers()
	var count := boss.homing_count_phase_two
	_check(homing.size() == count and homing.all(func(f): return f.homing), "phase two: %d homing feathers" % count)
	if homing.size() == count and count >= 2:
		_check(absf(homing[0].direction.angle_to(homing[-1].direction)) > deg_to_rad(60), "starting at different angles")
		_check(homing[0].speed < 230.0, "slower than the fan feathers")
	for f in homing:
		f.queue_free()
	await _frames(1)

	# Curves toward the player.
	_player._invuln_timer = 999.0   # so it doesn't break on contact mid-check
	var curver := boss._spawn_feather(Vector2.DOWN, boss.homing_speed, true)
	curver.global_position = _player.global_position + Vector2(-100, -160)
	# Its turns are wide (see _test_homing_feather_limits), so give it up to two seconds.
	var faced_player := false
	for i in 120:
		await _frames(1)
		if not is_instance_valid(curver):
			break
		var to_player := (_player.global_position - curver.global_position).normalized()
		if curver.direction.dot(to_player) > 0.7:
			faced_player = true
			break
	_player._invuln_timer = 0.0
	_check(faced_player, "homing feather turns toward the player")
	if is_instance_valid(curver):
		curver.queue_free()

	# Hits the player: half a heart, and it's gone.
	var hp := _player.health
	var hitter := boss._spawn_feather(Vector2.RIGHT, boss.homing_speed, true)
	hitter.global_position = _player.global_position + Vector2(-40, 0)
	await _frames(30)
	_check(_player.health == hp - 1 and not is_instance_valid(hitter), "hit the player for half a heart and broke")

	# Struck by an attack.
	_player._invuln_timer = 999.0
	_player.facing = 1
	var target := boss._spawn_feather(Vector2.UP, 10.0, true)
	target.global_position = _player.global_position + Vector2(40, 0)
	await _frames(1)
	Input.action_press("attack")
	await _frames(3)
	Input.action_release("attack")
	await _frames(2)
	_check(not is_instance_valid(target), "an attack destroys a homing feather")

	# Plain feathers ignore attacks.
	var plain := boss._spawn_feather(Vector2.UP, 5.0, false)
	plain.global_position = _player.global_position + Vector2(40, 0)
	await _frames(20)
	Input.action_press("attack")
	await _frames(3)
	Input.action_release("attack")
	await _frames(2)
	_check(is_instance_valid(plain), "plain feathers can't be struck")

	# Walls and floor.
	var into_wall := boss._spawn_feather(Vector2.LEFT, boss.homing_speed, true)
	into_wall.global_position = Vector2(boss.arena_left + 20, 8 * TILE)
	var into_floor := boss._spawn_feather(Vector2.DOWN, boss.homing_speed, true)
	into_floor.global_position = Vector2(30 * TILE, boss.arena_bottom - 20)
	await _frames(20)
	_check(not is_instance_valid(into_wall) and not is_instance_valid(into_floor), "breaks on walls and the floor")

	_main.debug_kill_boss()
	await _frames(2)
	_check(_feathers().is_empty(), "feathers cleared on defeat")
	await _despawn()


func _test_homing_feather_limits() -> void:
	print("Homing feathers: only head downward, turn no tighter than their radius, and can be sidestepped")
	var boss := await _start_harrier_fight()
	boss.health = boss.max_health / 2
	boss.process_mode = Node.PROCESS_MODE_DISABLED   # only the feathers spawned here
	for f in _feathers():
		f.queue_free()
	_player._invuln_timer = 999.0
	var floor_y := _player.global_position.y

	# Fired sideways from level with you: it swings down and never climbs or flattens out.
	var flat := boss._spawn_feather(Vector2.RIGHT, boss.homing_speed, true)
	flat.global_position = _player.global_position + Vector2(-260, -40)
	var max_tilt := 0.0
	var climbed := false
	for i in 90:
		await _frames(1)
		if not is_instance_valid(flat):
			break
		if flat._heading_down:
			max_tilt = maxf(max_tilt, absf(flat.tilt()))
			climbed = climbed or flat.direction.y < 0.0
	_check(not climbed and rad_to_deg(max_tilt) <= 70.5,
			"never above 70 degrees from straight down (max %.1f)" % rad_to_deg(max_tilt))
	if is_instance_valid(flat):
		flat.queue_free()

	# Once it has seen you, its turn rate is capped by the minimum radius.
	var turner := boss._spawn_feather(Vector2.DOWN, boss.homing_speed, true)
	turner.global_position = _player.global_position + Vector2(-140, -200)
	var cap: float = turner.speed / turner.min_turn_radius / 60.0
	var fastest := 0.0
	var last := turner.direction
	var saw := false
	for i in 60:
		await _frames(1)
		if not is_instance_valid(turner):
			break
		saw = saw or turner._seen_player
		fastest = maxf(fastest, absf(last.angle_to(turner.direction)))
		last = turner.direction
	_check(saw, "saw the player")
	_check(fastest <= cap + 0.0001, "turns no tighter than its radius (%.3f <= %.3f rad/frame)" % [fastest, cap])
	if is_instance_valid(turner):
		turner.queue_free()

	# Dropping on you from above: a dash-length sidestep at the last moment gets clear.
	_player._invuln_timer = 0.0
	var hp := _player.health
	var diver := boss._spawn_feather(Vector2.DOWN, boss.homing_speed, true)
	diver.global_position = _player.global_position + Vector2(0, -160)
	await _frames(int(100.0 / diver.speed * 60))
	_player.global_position.x += 3 * TILE
	for i in 90:
		await _frames(1)
		if not is_instance_valid(diver):
			break
	_check(_player.health == hp, "sidestepped it (health %d -> %d)" % [hp, _player.health])
	_check(not is_instance_valid(diver) or diver.global_position.y > floor_y, "it carried on into the floor")
	await _despawn()


# Waits for the Harrier to lock in a full dive (after its shallow swoops).
func _wait_for_swoop_windup(boss: HarrierBoss) -> bool:
	for i in 1200:
		await _frames(1)
		if boss._state == HarrierBoss.State.SWOOP_WINDUP:
			return true
	return false


func _test_harrier_pulls_up_after_hitting_you() -> void:
	print("Harrier: a swoop that hits you pulls back up, no crash")
	var boss := await _start_harrier_fight()
	_check(await _wait_for_swoop_windup(boss), "wound up a swoop")
	var hp := _player.health
	var dazed := false
	for i in 120:
		await _frames(1)
		dazed = dazed or boss.is_dazed()
		if boss._state == HarrierBoss.State.RISE:
			break
	_check(_player.health == hp - boss.damage, "player hit for %d half-hearts" % (hp - _player.health))
	_check(boss._state == HarrierBoss.State.RISE and not dazed, "pulled up without crashing")
	await _despawn()


func _test_harrier_crashes_when_it_misses() -> void:
	print("Harrier: a missed swoop crashes into the floor and leaves it dazed")
	var boss := await _start_harrier_fight()
	_player._invuln_timer = 999.0   # stay put at col 15: no knockback from feathers or passes
	_check(await _wait_for_swoop_windup(boss), "wound up a swoop")
	# Step well clear of the dive line, to the other side of the arena.
	var aside := 28.0 if boss._swoop_dir.x < 0.0 else 7.0
	_place(aside, 15)
	_player._invuln_timer = 999.0
	for i in 150:
		await _frames(1)
		if boss.is_dazed():
			break
	_check(boss.is_dazed() and boss.is_on_floor(), "dazed on the floor")
	await _frames(2)
	_check(boss._hit_shape.disabled, "harmless to touch while dazed")
	await _frames(int(boss.dazed_time * 60) + 5)
	_check(boss._state == HarrierBoss.State.RISE or boss._state == HarrierBoss.State.HOVER, "gets back up")
	await _frames(2)
	_check(not boss._hit_shape.disabled, "and is dangerous again")
	await _despawn()


func _test_harrier_armor_except_dazed() -> void:
	print("Harrier: takes half damage, full damage while dazed")
	var boss := await _start_harrier_fight()
	_check(boss.damage_reduction == 0.5, "50% damage reduction by default")
	var hp := boss.health
	boss.take_hit(1, Vector2.RIGHT)
	_check(boss.health == hp, "first hit absorbed (half a point)")
	boss.take_hit(1, Vector2.RIGHT)
	_check(boss.health == hp - 1, "two hits = 1 damage (%d -> %d)" % [hp, boss.health])
	boss._crash()
	hp = boss.health
	boss.take_hit(1, Vector2.RIGHT)
	boss.take_hit(1, Vector2.RIGHT)
	_check(boss.health == hp - 2, "dazed: full damage (%d -> %d)" % [hp, boss.health])
	_check(_main._hud._boss_bar.current == boss.health, "health bar follows")
	await _despawn()


func _test_harrier_dazed_recoil() -> void:
	print("Harrier: hitting it while it lies dazed barely pushes you (dazed_hit_recoil)")
	var boss := await _start_harrier_fight()
	_check(boss.current_hit_recoil() == boss.hit_recoil and boss.dazed_hit_recoil < boss.hit_recoil,
			"flying: %.0f; dazed it will be less, %.0f" % [boss.current_hit_recoil(), boss.dazed_hit_recoil])
	boss._crash()
	for i in 60:
		await _frames(1)
		if boss.is_on_floor():
			break
	_check(boss._state == HarrierBoss.State.DAZED and boss.current_hit_recoil() == boss.dazed_hit_recoil,
			"dazed: %.0f" % boss.current_hit_recoil())
	# A real side swing from beside it, standing on the floor.
	_player._invuln_timer = 999.0
	_player.facing = 1
	_player.global_position = Vector2(boss.global_position.x - 50.0,
			boss.global_position.y + HarrierBoss.SIZE.y * 0.5 - Player.BODY_SIZE.y * 0.5)
	_player.velocity = Vector2.ZERO
	_player._attack_cooldown_timer = 0.0
	var hp := boss.health
	Input.action_press("attack")
	var pushed := Vector2.ZERO
	for i in 6:
		await _frames(1)
		if boss.health < hp:
			pushed = _player.velocity
			break
	_release_all()
	_check(boss.health < hp and absf(pushed.length() - boss.dazed_hit_recoil) < 3.0,
			"the swing landed and pushed you back %.0f px/s (dazed_hit_recoil %.0f)" % [pushed.length(), boss.dazed_hit_recoil])
	await _despawn()


func _test_harrier_defeat_grants_wall_jump() -> void:
	print("Beating the Harrier grants wall jump and leaves its body behind")
	var boss := await _start_harrier_fight()
	boss._crash()
	while boss.health > 0:
		boss.take_hit(1, Vector2.RIGHT)
	await _frames(60)
	_check(GameState.has_ability("wall_jump"), "wall jump granted")
	_check(not _main._gate_closed and not _main._hud.is_boss_shown(), "gate open, bar hidden")
	_check(boss._state == HarrierBoss.State.DEAD and boss.is_on_floor(), "body lies on the floor")
	_check(GameState.bosses_defeated.has("aerie"), "defeat recorded")
	await _frames(int(_main.CAMERA_RELEASE_TIME * 60))
	_check(get_viewport().get_camera_2d() == _player.camera, "camera handed back")
	get_tree().reload_current_scene()
	var room := await _wait_for_room("aerie", 30)
	await _frames(30)
	var bodies := _all(room).filter(func(c): return c is HarrierBoss) if room != null else []
	_check(room != null and room._boss == null and bodies.size() == 1 and bodies[0]._state == HarrierBoss.State.DEAD,
			"still beaten after reloading")
	await _despawn()


func _test_armor_reduces_damage() -> void:
	print("Armor: flat reduction first, then percentage")
	await _spawn()
	_check(_player.reduce_damage(8) == 8, "no armor: 8 stays 8")
	_player.armor_flat = 2
	_check(_player.reduce_damage(8) == 6, "flat 2: 8 -> 6")
	_player.armor_percent = 0.5
	_check(_player.reduce_damage(8) == 3, "flat 2 then 50%%: 8 -> 3 (got %d)" % _player.reduce_damage(8))
	_check(_player.reduce_damage(1) == 0, "never below 0")
	_player.take_damage(8, _player.global_position + Vector2(-20, 0), false)
	_check(_player.health == _player.max_health - 3, "take_damage applies it (%d/%d)" % [_player.health, _player.max_health])
	_player._invuln_timer = 0.0
	_player.armor_flat = 99
	_player.kill()
	_check(_player._dead, "lethal hazards ignore armor")
	await _despawn()


# Flat floor in the boss room's lower corridor, clear of acid: cols 55-70, row 28.
func _place_in_corridor(col := 56.0) -> void:
	_player.global_position = Vector2(col * TILE, 29 * TILE - Player.BODY_SIZE.y * 0.5)
	_player.velocity = Vector2.ZERO


func _test_sprint_is_faster_and_drains_stamina() -> void:
	print("Sprint: faster while held, drains stamina, stops when it runs out")
	await _spawn(BOSS_SCENE, true)
	await _remove_enemies()
	_place_in_corridor()
	await _frames(5)
	Input.action_press("move_right")
	Input.action_press("sprint")
	await _frames(20)
	_check(not GameState.has_ability("sprint") and absf(_player.velocity.x - _player.run_speed) < 1.0, "locked at first: just runs")
	_release_all()
	GameState.unlock("sprint")
	_check(_main._hud._stamina_bar.visible and _main._hud._stamina_bar.position.y > _main._hud._health_bar.position.y,
			"stamina bar under the health bar")
	_place_in_corridor()
	await _frames(5)
	Input.action_press("move_right")
	Input.action_press("sprint")
	await _frames(20)
	var speed := _player.velocity.x
	_check(speed > _player.run_speed + 50.0, "sprinting at %.0f (run %.0f)" % [speed, _player.run_speed])
	_check(_player.stamina < _player.max_stamina, "stamina draining (%.0f)" % _player.stamina)
	_check(_main._hud._stamina_bar.current == _player.stamina, "bar follows")
	_release_all()
	_player.stamina = 1.0
	_place_in_corridor()
	await _frames(5)
	Input.action_press("move_right")
	Input.action_press("sprint")
	await _frames(20)
	_check(absf(_player.velocity.x - _player.run_speed) < 1.0, "out of stamina: back to run speed (%.0f)" % _player.velocity.x)
	await _frames(40)   # refilling on the ground meanwhile
	_check(absf(_player.velocity.x - _player.run_speed) < 1.0 and _player.stamina > 10.0,
			"stays off until sprint is let go, even as stamina refills (%.0f stamina)" % _player.stamina)
	Input.action_release("sprint")
	await _frames(1)
	Input.action_press("sprint")
	await _frames(10)
	_check(_player.velocity.x > _player.run_speed + 50.0, "works again after letting go")
	_release_all()
	await _despawn()


func _test_stamina_refills_only_on_ground() -> void:
	print("Stamina refills over time, but only on the ground")
	await _spawn(BOSS_SCENE, true)
	await _remove_enemies()
	_place(63, 8)   # top of the shaft above the right hallway: a long fall
	await _frames(2)   # is_on_floor() still holds from before the move for a frame
	_player.stamina = 10.0
	await _frames(12)
	_check(not _player.is_on_floor() and _player.stamina == 10.0, "no refill in the air (%.1f)" % _player.stamina)
	_place_in_corridor()
	_player.stamina = 10.0
	await _frames(60)
	_check(_player.stamina > 40.0, "refilled on the ground (%.1f after 1s)" % _player.stamina)
	await _frames(120)
	_check(_player.stamina == _player.max_stamina, "up to full")
	await _despawn()


func _test_dash_needs_stamina() -> void:
	print("Dash costs stamina and won't fire without enough")
	await _spawn(BOSS_SCENE, true)
	await _remove_enemies()
	GameState.unlock("dash")
	_place_in_corridor()
	await _frames(5)
	Input.action_press("dash")
	await _frames(2)
	Input.action_release("dash")
	_check(_player.stamina <= _player.max_stamina - _player.dash_stamina_cost + 1.0, "dash spent %.0f stamina" % (_player.max_stamina - _player.stamina))
	await _frames(30)
	_place_in_corridor()
	_player.stamina = _player.dash_stamina_cost - 10.0   # regen won't top it up within the test
	var x0 := _player.global_position.x
	Input.action_press("dash")
	await _frames(6)
	Input.action_release("dash")
	_check(absf(_player.global_position.x - x0) < 4.0, "no dash with too little stamina (moved %.0f px)" % absf(_player.global_position.x - x0))
	await _despawn()


# Airborne beside the right shaft's left wall (col 58 is solid), pressing into it.
func _try_wall_jump(stamina: float) -> float:
	_place(59, 18)
	_player.stamina = stamina
	Input.action_press("move_left")
	await _frames(8)
	Input.action_press("jump")
	await _frames(3)
	var vx := _player.velocity.x
	_release_all()
	return vx


func _test_wall_jump_needs_stamina() -> void:
	print("Wall jump costs stamina and won't fire without enough")
	await _spawn(BOSS_SCENE, true)
	await _remove_enemies()
	GameState.unlock("wall_jump")
	var vx := await _try_wall_jump(_player.max_stamina)
	_check(vx > 50.0, "wall jump kicks off the wall (vx %.0f)" % vx)
	_check(_player.stamina <= _player.max_stamina - _player.wall_jump_stamina_cost, "spent %.0f stamina" % (_player.max_stamina - _player.stamina))
	vx = await _try_wall_jump(_player.wall_jump_stamina_cost - 1.0)
	_check(vx <= 0.0, "no wall jump with too little stamina (vx %.0f)" % vx)
	await _despawn()


func _press_pause() -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = "pause"
		event.pressed = pressed
		Input.parse_input_event(event)
	await _frames(2)


func _test_pause_menu_skins() -> void:
	print("Pause menu: Skin lists every skin, marks the one worn, and swaps the player's look")
	await _spawn()
	_check(_player.sprite.skin_id == PlayerSprite.DEFAULT_SKIN, "starts in the default skin (%s)" % _player.sprite.skin_id)
	await _press_pause()
	var menu := _pause_menu()
	menu._skin_button.pressed.emit()
	_check(menu._skin_box.visible and not menu._main_box.visible, "Skin opens the skin list")
	_check(menu._skin_buttons.size() == PlayerSprite.SKINS.size(), "%d skin buttons" % menu._skin_buttons.size())
	_check(menu._skin_buttons[PlayerSprite.DEFAULT_SKIN].text.begins_with(menu.SKIN_MARK) and menu._skin_buttons[PlayerSprite.DEFAULT_SKIN].has_focus(),
			"the worn skin is marked and focused")
	var other: String = PlayerSprite.SKINS.filter(func(s): return s.id != PlayerSprite.DEFAULT_SKIN)[0].id
	menu._skin_buttons[other].pressed.emit()
	_check(GameState.player_skin == other and _player.sprite.skin_id == other, "picking %s swaps the player's look" % other)
	_check(menu._skin_buttons[other].text.begins_with(menu.SKIN_MARK) and not menu._skin_buttons[PlayerSprite.DEFAULT_SKIN].text.begins_with(menu.SKIN_MARK),
			"the mark moves")
	var sheet: Texture2D = _player.sprite.sprite_frames.get_frame_texture("idle", 0).atlas
	_check(sheet.resource_path == PlayerSprite.skin(other).sheet, "drawn from %s" % sheet.resource_path)
	menu.show_main()
	_check(menu._main_box.visible and menu._skin_button.has_focus(), "Back returns to the pause menu")
	menu.close()
	# The look carries into the next room.
	var old := get_tree().current_scene
	get_tree().reload_current_scene()
	for i in 30:
		await _frames(1)
		if get_tree().current_scene != old and get_tree().current_scene != null:
			break
	_main = get_tree().current_scene
	_check(_main._player.sprite.skin_id == other, "kept after reloading the room")
	await _despawn()


# Taps `action` once, then again `at_frame` frames later, standing on the
# floor. Returns how many times `active` (attack swinging, dash dashing...)
# switched on over the next second.
func _starts_after_two_taps(action: String, at_frame: int, active: Callable) -> int:
	_place(5, 17)
	await _frames(40)   # cooldowns from any earlier taps run out
	_player.stamina = _player.max_stamina
	var starts := 0
	var was_active := false
	for i in 60 + at_frame:
		if i == 0 or i == at_frame:
			Input.action_press(action)
		elif i == 1 or i == at_frame + 1:
			Input.action_release(action)
		await _frames(1)
		var now: bool = active.call()
		if now and not was_active:
			starts += 1
		was_active = now
	return starts


# Checks a buffered action: a second press inside the buffer window before the
# lockout ends goes off, one earlier is dropped. Timings come from the player's
# own settings.
func _check_buffer(action: String, lockout: float, buffer: float, active: Callable) -> void:
	var lockout_frames := roundi(lockout * 60)
	var buffer_frames := roundi(buffer * 60)
	var late := lockout_frames - buffer_frames + 3   # inside the window
	_check(await _starts_after_two_taps(action, late, active) == 2,
			"%s pressed %d frames before it's allowed again: it goes off" % [action, lockout_frames - late])
	var early := lockout_frames - buffer_frames - 4   # too early
	_check(await _starts_after_two_taps(action, early, active) == 1,
			"%s pressed %d frames before: dropped" % [action, lockout_frames - early])


func _test_attack_buffer() -> void:
	print("Attack and dash buffers: a press shortly before they're allowed again still goes off")
	await _spawn()
	await _check_buffer("attack", _player.attack_cooldown, _player.attack_buffer_time,
			func() -> bool: return _player._attack_timer > 0.0)
	GameState.unlock("dash")
	await _check_buffer("dash", _player.dash_duration + _player.dash_cooldown, _player.dash_buffer_time,
			func() -> bool: return _player._dash_timer > 0.0)
	await _despawn()


func _test_player_animations() -> void:
	print("Player sprite: idle, run, jump, fall and land as you move")
	await _spawn()
	_place(5, 17)
	await _frames(20)
	_check(_player.sprite.animation == "idle", "idle standing still (%s)" % _player.sprite.animation)
	Input.action_press("move_right")
	await _frames(15)
	_check(_player.sprite.animation == "run" and not _player.sprite.flip_h, "run, facing right (%s)" % _player.sprite.animation)
	Input.action_release("move_right")
	Input.action_press("move_left")
	await _frames(15)
	_check(_player.sprite.flip_h, "turned to face left")
	Input.action_release("move_left")
	await _frames(20)
	Input.action_press("jump")
	await _frames(4)
	_check(_player.sprite.animation == "jump", "jump on the way up (%s)" % _player.sprite.animation)
	var saw_fall := false
	var saw_land := false
	for i in 120:
		await _frames(1)
		saw_fall = saw_fall or _player.sprite.animation == "fall"
		saw_land = saw_land or _player.sprite.animation == "land"
		if saw_land:
			break
	_release_all()
	_check(saw_fall, "fall on the way down")
	_check(saw_land, "land on touching down")
	await _frames(30)
	_check(_player.sprite.animation == "idle", "back to idle (%s)" % _player.sprite.animation)

	# Attacking plays the swing and a slash over the hit area, then hides it.
	Input.action_press("attack")
	await _frames(2)
	Input.action_release("attack")
	_check(_player.sprite.animation == "attack_side", "attack_side on a swing (%s)" % _player.sprite.animation)
	_check(_player.slash.visible and _player.slash.animation == "slash_side"
			and _player.slash.position == _player._attack_shape.position, "slash shown over the hit area")
	await _frames(30)
	_check(not _player.slash.visible, "slash gone once it's played")
	_check(_player.sprite.animation == "idle", "back to idle after the swing (%s)" % _player.sprite.animation)
	await _despawn()


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
	await _press_pause()
	await _press_pad_a()
	_check(not menu.is_open() and not get_tree().paused, "gamepad A presses the focused Resume")
	_check(menu._quit_game_button != null and tr(menu._quit_game_button.text) == "Quit Game", "has a Quit Game button")
	var labels := menu._panel.find_children("*", "Label", true, false)
	_check(labels.any(func(l: Label) -> bool: return tr(l.text).contains("Jump:")), "controls listed in the menu")
	var screen_labels := _main.find_children("*", "Label", true, false).filter(
		func(l: Label) -> bool: return not menu.is_ancestor_of(l))
	_check(not screen_labels.any(func(l: Label) -> bool: return tr(l.text).contains("Jump:")), "controls gone from the game screen")
	await _despawn()


func _press_pad_a() -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_A
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(1)
	await _frames(1)


func _test_pause_ignored_during_boss_intro() -> void:
	print("The pause menu doesn't open over the boss intro")
	await _spawn(BOSS_SCENE)
	_place(20, 14)
	await _walk_until_fight("move_right", 120)
	await _press_pause()
	_check(not _pause_menu().is_open(), "menu stayed closed")
	_check(await _wait_for_intro_end(), "intro still finished and unpaused")
	await _despawn()


func _test_debug_kill_boss() -> void:
	print("Debug: the pause menu's Kill Boss button kills the Warden")
	await _spawn(BOSS_SCENE)
	await _press_pause()
	var menu := _pause_menu()
	_check(menu._kill_boss_button.visible, "button shown in debug mode with a live boss")
	menu._kill_boss_button.pressed.emit()
	await _frames(2)
	_check(not menu.is_open() and not get_tree().paused, "menu closed")
	_check(_main._boss == null and GameState.bosses_defeated.has("boss"), "boss dead")
	_check(GameState.has_ability("dash"), "dash granted")
	_check(not _main._gate_closed, "gates open")
	await _press_pause()
	_check(not menu._kill_boss_button.visible, "button hidden once the boss is dead")
	await _despawn()
	# Mid-fight, after the intro.
	await _start_boss_fight()
	_main.debug_kill_boss()
	await _frames(60)
	_check(_main._boss == null and not _main._gate_closed and not _main._hud.is_boss_shown(), "works mid-fight too")
	_check(get_viewport().get_camera_2d() == _player.camera, "camera handed back to the player")
	await _despawn()


func _test_debug_kill_boss_off_outside_debug_mode() -> void:
	print("Debug: Kill Boss (button and F3) does nothing outside debug mode")
	await _spawn(BOSS_SCENE)
	GameState.debug_mode = false
	await _press_pause()
	_check(not _pause_menu()._kill_boss_button.visible, "button hidden")
	_pause_menu().close()
	var f3 := InputEventKey.new()
	f3.keycode = KEY_F3
	f3.pressed = true
	Input.parse_input_event(f3)
	await _frames(2)
	_check(_main._boss != null and not GameState.bosses_defeated.has("boss"), "F3 ignored, boss alive")
	GameState.debug_mode = true
	Input.parse_input_event(f3)
	await _frames(2)
	_check(_main._boss == null, "F3 kills it in debug mode")
	await _despawn()


func _test_level_select_loads_each_room() -> void:
	print("Main menu: Level Select's buttons (set in the scene) each start their room at its PlayerStart, with their abilities; debug mode only")
	# Outside debug mode (release exports) there's no Level Select.
	GameState.debug_mode = false
	var release_menu := MENU_SCENE.instantiate()
	get_tree().root.add_child(release_menu)
	get_tree().current_scene = release_menu
	await _frames(2)
	release_menu.show_level_select()
	_check(not release_menu.level_select_button.visible and release_menu._main_box.visible and not release_menu._level_box.visible,
			"hidden outside debug mode")
	await _despawn()
	GameState.debug_mode = true
	# The buttons are whatever the scene has: read them from a copy of it.
	var listed: Node = MENU_SCENE.instantiate()
	var buttons: Array = listed.find_children("*", "Button", true, false).filter(func(b): return b is LevelButton)
	var entries := buttons.map(func(b): return [b.room, b.abilities.duplicate()])
	listed.free()
	_check(not entries.is_empty() and entries.all(func(e): return LevelData.ROOMS.has(e[0])),
			"%d level buttons, each for a real room %s" % [entries.size(), entries.map(func(e): return e[0])])
	for entry in entries:
		var room: String = entry[0]
		var granted: Array = entry[1]
		GameState.unlock("wall_jump")   # progress from before, which a level start wipes
		var menu := MENU_SCENE.instantiate()
		get_tree().root.add_child(menu)
		get_tree().current_scene = menu
		await _frames(2)
		menu.level_select_button.pressed.emit()
		_check(menu._levels.get_child(0).has_focus(), "first level focused")
		menu.level_buttons[room].pressed.emit()
		var loaded := await _wait_for_room(room, 120)
		_check(loaded != null, "%s loaded" % room)
		if loaded != null:
			var p: Player = loaded._player
			var start: PlayerStart = loaded.entities_of(PlayerStart)[0]
			var expected := GameState.STARTING_ABILITIES.duplicate()
			for a in granted:
				expected[a] = true
			_check(absf(p.global_position.x - start.global_position.x) < 2.0 and GameState.abilities == expected,
					"%s: at its PlayerStart (col %.1f), starting abilities plus %s" % [room, p.global_position.x / TILE, granted])
		await _frames(30)   # let the fade finish
		await _despawn()
	var menu := MENU_SCENE.instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await _frames(2)
	menu.level_select_button.pressed.emit()
	menu.back_button.pressed.emit()
	_check(menu._main_box.visible and not menu._level_box.visible and menu.level_select_button.has_focus(), "Back returns to the main menu")
	await _despawn()


func _test_main_menu_starts_game() -> void:
	print("Main menu: Start loads the first room with fresh progress")
	GameState.unlock("dash")
	var menu := MENU_SCENE.instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await _frames(2)
	_check(menu.start_button.has_focus(), "Start focused")
	await _press_pad_a()
	var room := await _wait_for_room("first_test_room", 120)
	_check(room != null, "first room loaded")
	_check(not GameState.has_ability("dash"), "progress reset")
	if room != null:
		var p: Player = room._player
		_check(p.global_position.x < 5 * TILE, "starting at its PlayerStart (col %.1f)" % (p.global_position.x / TILE))
	await _frames(30)   # let the fade finish
	await _despawn()


func _test_pause_menu_quits_to_main_menu() -> void:
	print("Pause menu: Quit returns to the main menu")
	await _spawn()
	await _press_pause()
	var buttons := _pause_menu()._panel.find_children("*", "Button", true, false)
	var found := buttons.filter(func(b): return tr(b.text) == "Quit to Menu")
	_check(found.size() == 1, "has a Quit to Menu button")
	var quit: Button = found[0]
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


func _test_room_lights_flicker() -> void:
	print("Room lights: bulbs glow steadily, dead bulbs sputter now and then, EXIT signs blink but stay mostly on")
	await _spawn()
	var lights := _main.get_children().filter(func(c): return c is FlickerLight)
	var signs := lights.filter(func(l): return l.kind == FlickerLight.Kind.SIGN)
	_check(not signs.is_empty(), "the door has a glowing EXIT sign (%d)" % signs.size())
	_check(lights.any(func(l): return l.kind != FlickerLight.Kind.SIGN), "the ceiling bulbs glow")
	_check(lights.all(func(l): return l.light is PointLight2D and l.light.color == l.glow_color and l.light.texture != null),
			"each one shines a real light in its glow's colour")

	# One of each kind, watched for 20 seconds.
	var watched := {}
	for kind in [FlickerLight.Kind.STEADY, FlickerLight.Kind.SIGN, FlickerLight.Kind.BROKEN]:
		var light := FlickerLight.new()
		light.kind = kind
		light.position = Vector2(200 + kind * 100, 200)
		_main.add_child(light)
		watched[kind] = {"light": light, "on": 0, "lowest": 1.0, "flashes": 0, "was_on": false}
	var frames := 20 * 60
	var out_of_step := 0
	for i in frames:
		await _frames(1)
		for kind in watched:
			var w: Dictionary = watched[kind]
			var b: float = w.light.brightness
			var real: PointLight2D = w.light.light
			if absf(real.energy - w.light.light_energy * b) > 0.001 or real.enabled != (b > 0.0):
				out_of_step += 1
			var on := b > 0.0
			w.on += int(b >= 0.99) if kind == FlickerLight.Kind.SIGN else int(on)
			w.lowest = minf(w.lowest, b)
			if on and not w.was_on:
				w.flashes += 1
			w.was_on = on
	var steady: Dictionary = watched[FlickerLight.Kind.STEADY]
	var sign: Dictionary = watched[FlickerLight.Kind.SIGN]
	var broken: Dictionary = watched[FlickerLight.Kind.BROKEN]
	_check(steady.lowest > 0.85, "a working bulb never dips much (lowest %.2f)" % steady.lowest)
	_check(sign.lowest < 0.6 and float(sign.on) / frames > 0.8,
			"the sign blinks or sags but is fully on %.0f%% of the time" % (100.0 * sign.on / frames))
	_check(broken.flashes >= 2 and float(broken.on) / frames < 0.35,
			"a dead bulb sputters on (%d flashes) but is dark %.0f%% of the time" % [broken.flashes, 100.0 - 100.0 * broken.on / frames])
	_check(out_of_step == 0, "the real lights flicker in step with the glows (%d frames out)" % out_of_step)
	await _despawn()


func _test_room_dimming() -> void:
	print("Rooms are dimmed a little (set in the Inspector) so lights stand out; the skyline and HUD aren't")
	await _spawn()
	var dim := _main.get_children().filter(func(c): return c is CanvasModulate)
	_check(dim.size() == 1 and dim[0].color == _main.dimming, "the room is dimmed by its dimming (%s)" % _main.dimming)
	_check(_main.dimming.v > 0.7, "only lightly: the room reads without its lights (%.2f)" % _main.dimming.v)
	var skyline: Skyline = _main.get_node("Skyline")
	var seen := Color(skyline.modulate.r * _main.dimming.r, skyline.modulate.g * _main.dimming.g, skyline.modulate.b * _main.dimming.b)
	_check(seen.is_equal_approx(Color.WHITE), "the skyline is undimmed (%s)" % seen)
	_check(skyline.get_children().all(func(c): return c.light_mask == 0), "and out of reach of the room's lights")
	_check(_main.get_children().any(func(c): return c is HUD and c is CanvasLayer), "the HUD is on its own layer, undimmed")
	await _despawn()
	# Another room's own setting.
	var room := _build_editor_room()
	room.dimming = Color(0.9, 0.85, 0.8)
	await _spawn_node(room)
	dim = _main.get_children().filter(func(c): return c is CanvasModulate)
	_check(dim.size() == 1 and dim[0].color == Color(0.9, 0.85, 0.8), "each room sets its own")
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


# Presses jump fresh (release, then press) and reports whether it launched upward.
func _air_jump_press() -> bool:
	Input.action_release("jump")
	await _frames(1)
	Input.action_press("jump")
	await _frames(2)
	return _player.velocity.y < -400.0


func _test_double_jump() -> void:
	print("Double jump: one extra jump in the air, back on landing; a new game has it if STARTING_ABILITIES says so")
	await _spawn()
	var starts_with: bool = GameState.STARTING_ABILITIES.get("double_jump", false)
	_check(GameState.has_ability("double_jump") == starts_with,
			"a new game starts %s double jump, as STARTING_ABILITIES says" % ("with" if starts_with else "without"))
	GameState.abilities["double_jump"] = true
	_place(5, 17)
	await _frames(5)
	Input.action_press("jump")
	for i in 60:   # up to the top of the first jump
		await _frames(1)
		if _player.velocity.y > -50.0:
			break
	_check(await _air_jump_press(), "second jump in the air")
	for i in 20:
		await _frames(1)
	_check(not await _air_jump_press(), "no third jump")
	_release_all()
	for i in 120:
		await _frames(1)
		if _player.is_on_floor():
			break
	await _frames(2)
	Input.action_press("jump")
	for i in 30:
		await _frames(1)
	_check(await _air_jump_press(), "back after landing")
	_release_all()
	await _despawn()

	await _spawn()
	GameState.abilities["double_jump"] = false
	_place(5, 17)
	await _frames(5)
	Input.action_press("jump")
	for i in 30:
		await _frames(1)
	_check(not await _air_jump_press(), "no double jump without the ability")
	_release_all()
	await _despawn()


func _test_pink_crawler_kill_heals() -> void:
	print("Killing a pink crawler heals a heart; other colours don't heal")
	await _spawn()
	await _remove_enemies()
	var floor_y := 18 * TILE - CrawlerEnemy.SIZE.y * 0.5
	var pink: CrawlerEnemy = _place_enemy(PINK_CRAWLER_SCENE, {}, Vector2(5.5 * TILE, floor_y))
	var sewer: CrawlerEnemy = _place_enemy(CRAWLER_SCENE, {}, Vector2(9.5 * TILE, floor_y))
	var pink2: CrawlerEnemy = _place_enemy(PINK_CRAWLER_SCENE, {}, Vector2(13.5 * TILE, floor_y))
	await _frames(2)
	_check(pink is PinkCrawler and not sewer is PinkCrawler, "the pink scene is a PinkCrawler, the sewer one isn't")
	_player.health = 5
	pink.take_hit(99, Vector2.RIGHT)
	_check(_player.health == 5 + PinkCrawler.KILL_HEAL, "pink: health 5 -> %d half-hearts" % _player.health)
	_check(_main._hud._health_bar.current == _player.health, "HUD updated")
	sewer.take_hit(99, Vector2.RIGHT)
	_check(_player.health == 5 + PinkCrawler.KILL_HEAL, "sewer: no healing (%d)" % _player.health)
	_player.health = _player.max_health
	pink2.take_hit(99, Vector2.RIGHT)
	_check(_player.health == _player.max_health, "no overheal")
	await _despawn()


func _test_crawler_sludge() -> void:
	print("Crawlers: placed by colour, ooze with a slime trail, wobble when hit, melt when killed")
	await _spawn()
	var crawlers := get_tree().get_nodes_in_group("enemy").filter(func(e): return e is CrawlerEnemy)
	var colours := ["sewer", "sickly", "pink"].map(func(c): return "res://scenes/enemies/crawler_%s.tscn" % c)
	_check(not crawlers.is_empty() and crawlers.all(func(c): return c.scene_file_path in colours),
			"the room's crawlers are all colour scenes %s" % [crawlers.map(func(c): return c.scene_file_path.get_file())])
	var crawler: CrawlerEnemy = crawlers[0]
	await _frames(60)
	_check(crawler.sprite.animation in ["walk", "turn"], "oozing along (%s)" % crawler.sprite.animation)
	_check(crawler.sprite.flip_h == (crawler._dir < 0), "faces the way it's going")
	_check(_all(_main).any(func(c): return c is SlimeDrip and c.color == crawler.slime_color), "leaves a slime trail in its colour")
	crawler.take_hit(1, Vector2.RIGHT)
	await _frames(1)
	_check(crawler.sprite.animation == "hurt", "wobbles when hit (%s)" % crawler.sprite.animation)
	crawler.take_hit(99, Vector2.RIGHT)
	await _frames(1)
	_check(is_instance_valid(crawler) and crawler.sprite.animation == "death", "melts instead of vanishing")
	_check(not crawler.is_in_group("enemy") and crawler.collision_layer == 0, "harmless and can't be hit while melting")
	await _frames(60)
	_check(not is_instance_valid(crawler), "gone once it's melted")
	await _despawn()


func _test_ceiling_crawler() -> void:
	print("Ceiling crawlers: ooze along upside down, drop when you pass beneath, then crawl the floor")
	await _spawn()
	await _remove_enemies()
	_player._invuln_timer = 999.0
	_player.global_position = Vector2(25 * TILE, 17 * TILE)   # well off to the side
	var hanger: CrawlerEnemy = CRAWLER_SCENE.instantiate()
	hanger.on_ceiling = true
	hanger.position = Vector2(8.5 * TILE, CrawlerEnemy.SIZE.y * 0.5)   # under the room's top edge
	_main.add_child(hanger)
	await _frames(30)
	var x0 := hanger.global_position.x
	await _frames(30)
	_check(hanger.on_ceiling and hanger.is_on_floor() and hanger.global_position.y < TILE,
			"stuck to the ceiling (y %.0f)" % hanger.global_position.y)
	_check(absf(hanger.global_position.x - x0) > 10.0, "oozing along it")
	_check(hanger.sprite.animation in ["ceiling_walk", "ceiling_turn"], "droopy ceiling animation (%s)" % hanger.sprite.animation)
	# Walk underneath: hold the player in the air below it.
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_player.global_position = Vector2(hanger.global_position.x, 8 * TILE)
	await _frames(2)
	_check(not hanger.on_ceiling and hanger.sprite.animation == "drop", "drops when you're below (%s)" % hanger.sprite.animation)
	var x_drop := hanger.global_position.x
	var landed := false
	for i in 120:
		await _frames(1)
		if hanger.sprite.animation == "land":
			landed = true
			break
	_check(landed and absf(hanger.global_position.x - x_drop) < 1.0, "fell straight down and splatted")
	await _frames(30)
	_check(hanger.is_on_floor() and hanger.up_direction == Vector2.UP and hanger.sprite.animation in ["walk", "turn"],
			"crawls the floor afterwards (%s)" % hanger.sprite.animation)
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	hanger.queue_free()

	# Hitting one on the ceiling knocks it down.
	var knocked: CrawlerEnemy = CRAWLER_SCENE.instantiate()
	knocked.on_ceiling = true
	knocked.position = Vector2(5.5 * TILE, CrawlerEnemy.SIZE.y * 0.5)
	_main.add_child(knocked)
	await _frames(10)
	knocked.take_hit(1, Vector2.UP)
	await _frames(1)
	_check(not knocked.on_ceiling and knocked.sprite.animation == "drop", "a hit knocks it off the ceiling")
	await _despawn()


func _layer_named(layer_name: String) -> TileMapLayer:
	return _main.get_children().filter(func(c): return c is TileMapLayer and c.name == layer_name)[0]


# For each terrain, repaints every room's cells of that terrain with the
# editor's terrain brush (set_cells_terrain_connect) and checks it picks the
# same tile the room art did. Cells just outside the room count as concrete,
# like the room's solid border.
func _test_terrain_brushes() -> void:
	print("Terrain brushes pick tiles by their neighbours: concrete, catwalk, spikes, sewer")
	var layer := TileMapLayer.new()
	layer.tile_set = RoomArt.FOREGROUND_TILES
	# Concrete: a 4 x 3 block, a 1-wide column, a 1-tall strip and a lone block.
	# Each tile should connect on exactly the sides with concrete next to it.
	var concrete: Array[Vector2i] = []
	for x in 4:
		for y in 3:
			concrete.append(Vector2i(x, y))
	for y in 3:
		concrete.append(Vector2i(6, y))
	for x in range(8, 11):
		concrete.append(Vector2i(x, 0))
	concrete.append(Vector2i(12, 0))
	layer.set_cells_terrain_connect(concrete, 0, 0)
	var steps := {"N": Vector2i.UP, "E": Vector2i.RIGHT, "S": Vector2i.DOWN, "W": Vector2i.LEFT}
	var wrong := concrete.filter(func(c):
		var sides := ""
		for s in "NESW":
			if concrete.has(c + steps[s]):
				sides += s
		var at := layer.get_cell_atlas_coords(c)
		return at.y < 0 or at.y >= RoomArt.TERRAIN.size() or at.x >= RoomArt.TERRAIN[at.y].size() or RoomArt.TERRAIN[at.y][at.x] != sides)
	_check(wrong.is_empty(), "concrete: every tile joins its neighbours%s" % ("" if wrong.is_empty() else ", wrong at %s" % [wrong]))
	# Catwalk: a run of four (end, middle, middle, end) and a single one.
	layer.set_cells_terrain_connect([Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5)], 0, 1)
	layer.set_cells_terrain_connect([Vector2i(6, 5)], 0, 1)
	var catwalk := [0, 1, 2, 3, 6].map(func(x): return layer.get_cell_atlas_coords(Vector2i(x, 5)))
	_check(catwalk == [RoomArt.PLAT_L, RoomArt.PLAT_MID, RoomArt.PLAT_MID, RoomArt.PLAT_R, RoomArt.PLAT_ONE], "catwalk: %s" % [catwalk])
	# Spikes: any of the variants, against a wall or more spikes on either side.
	layer.set_cells_terrain_connect([Vector2i(0, 7), Vector2i(1, 7), Vector2i(2, 7)], 0, 2)
	var spikes := [0, 1, 2].map(func(x): return layer.get_cell_atlas_coords(Vector2i(x, 7)))
	_check(spikes.all(func(s): return s in RoomArt.SPIKES), "spikes: %s" % [spikes])
	# Sewer: surface on top, fill below.
	var pool: Array[Vector2i] = []
	for x in 3:
		for y in range(9, 11):
			pool.append(Vector2i(x, y))
	layer.set_cells_terrain_connect(pool, 0, 3)
	var surface := [0, 1, 2].map(func(x): return layer.get_cell_atlas_coords(Vector2i(x, 9)))
	var fill := [0, 1, 2].map(func(x): return layer.get_cell_atlas_coords(Vector2i(x, 10)))
	_check(surface.all(func(s): return s == RoomArt.ACID_TOP) and fill.all(func(s): return s == RoomArt.ACID_FILL),
			"sewer: surface %s, fill %s" % [surface, fill])
	layer.free()

	# The wall brush: plain brick in the open, crumbled edges around a hole.
	var wall := TileMapLayer.new()
	wall.tile_set = RoomArt.BACKGROUND_TILES
	var hole := Rect2i(4, 3, 4, 3)
	var bricks: Array[Vector2i] = []
	for y in 10:
		for x in 12:
			if not hole.has_point(Vector2i(x, y)):
				bricks.append(Vector2i(x, y))
	wall.set_cells_terrain_connect(bricks, 0, 0)
	var sides := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var bad := bricks.filter(func(c):
		var open := 0
		for i in 4:
			var n: Vector2i = c + sides[i]
			if hole.has_point(n) or n.x < 0 or n.y < 0 or n.x >= 12 or n.y >= 10:
				open |= 1 << i
		var got := wall.get_cell_atlas_coords(c)
		if open == 0:
			return not got in RoomArt.WALLS
		# The wall's outer border is open too here, so expect an edge facing out.
		return got != RoomArt.EDGE_ORIGIN + Vector2i(open % 8, open / 8))
	_check(bad.is_empty(), "wall brush: brick inside, crumbled edges at holes (%d of %d wrong)" % [bad.size(), bricks.size()])
	wall.free()

	# Windows count as wall: brick painted around both sizes stays plain, and
	# they stay put.
	var props := TileMapLayer.new()
	props.tile_set = RoomArt.BACKGROUND_TILES
	var placed := {}
	for dy in 2:
		for dx in 3:
			placed[Vector2i(6 + dx, 2 + dy)] = RoomArt.WINDOW_LARGE[0] + Vector2i(dx, dy)
	for dy in 2:
		for dx in 2:
			placed[Vector2i(2 + dx, 5 + dy)] = RoomArt.WINDOW_SMALL[0] + Vector2i(dx, dy)
	for c in placed:
		props.set_cell(c, 0, placed[c])
	var around: Array[Vector2i] = []
	for y in range(1, 9):
		for x in range(1, 11):
			if not placed.has(Vector2i(x, y)):
				around.append(Vector2i(x, y))
	props.set_cells_terrain_connect(around, 0, 0)
	var inside := around.filter(func(c): return c.x > 1 and c.y > 1 and c.x < 10 and c.y < 8)
	var edged := inside.filter(func(c): return not props.get_cell_atlas_coords(c) in RoomArt.WALLS)
	var moved := placed.keys().filter(func(c): return props.get_cell_atlas_coords(c) != placed[c])
	_check(edged.is_empty() and moved.is_empty(),
			"wall brush: windows count as wall (%d bricks edged beside them, %d windows changed)" % [edged.size(), moved.size()])
	props.free()
	var window: TileMapPattern = RoomArt.BACKGROUND_TILES.get_pattern(0) if RoomArt.BACKGROUND_TILES.get_patterns_count() > 0 else null
	_check(window != null and window.get_size() == RoomArt.WINDOW_LARGE[1]
			and window.get_cell_atlas_coords(Vector2i.ZERO) == RoomArt.WINDOW_LARGE[0],
			"the large window is a pattern, placed whole")
	# Every pattern cell must be a real tile: alternative -1 (TileMapPattern's
	# default) crashes the editor's Patterns tab.
	var broken := []
	for i in RoomArt.BACKGROUND_TILES.get_patterns_count():
		var pattern := RoomArt.BACKGROUND_TILES.get_pattern(i)
		for c in pattern.get_used_cells():
			var source: TileSetAtlasSource = RoomArt.BACKGROUND_TILES.get_source(pattern.get_cell_source_id(c))
			var at := pattern.get_cell_atlas_coords(c)
			if not source.has_tile(at) or not source.has_alternative_tile(at, pattern.get_cell_alternative_tile(c)):
				broken.append([i, c])
	_check(broken.is_empty(), "every pattern cell is a real tile%s" % ("" if broken.is_empty() else ": not %s" % [broken]))


## A small room made the editor way, from the template: 30x14 tiles, concrete
## painted with the terrain brush (floor, ceiling, right wall, and a left wall
## with a 3-tile door at the bottom), spikes, a gate column at x 10 in front of
## an arena, and placed nodes: PlayerStart, a crawler, a RoomDoor to the start
## room, and an Arena with a Warden.
func _build_editor_room() -> Room:
	var room: Room = load("res://scenes/rooms/room_template.tscn").instantiate()
	room.room = "test"
	var solid: Array[Vector2i] = []
	for x in 30:
		for y in [0, 12, 13]:
			solid.append(Vector2i(x, y))
	for y in range(1, 12):
		solid.append(Vector2i(29, y))
		if y < 9:
			solid.append(Vector2i(0, y))
	room.terrain().set_cells_terrain_connect(solid, 0, 0)
	room.terrain().set_cell(Vector2i(0, 9), 0, RoomArt.DOOR_TOP)
	room.terrain().set_cell(Vector2i(0, 10), 0, RoomArt.DOOR)
	room.terrain().set_cell(Vector2i(0, 11), 0, RoomArt.DOOR)
	room.terrain().set_cells_terrain_connect([Vector2i(6, 11)], 0, 2)
	for y in range(8, 12):
		room.gates().set_cell(Vector2i(10, y), 0, RoomArt.GATE)
	for y in range(1, 8):   # the wall above the gate
		room.terrain().set_cells_terrain_connect([Vector2i(10, y)], 0, 0)
	var start: PlayerStart = room.entities().get_node("PlayerStart")
	start.position = Vector2(4.5 * TILE, 12 * TILE)
	var crawler: CrawlerEnemy = CRAWLER_SCENE.instantiate()
	crawler.name = "Crawler"
	crawler.position = Vector2(8.5 * TILE, 12 * TILE - CrawlerEnemy.SIZE.y * 0.5)
	room.entities().add_child(crawler)
	var door := RoomDoor.new()
	door.name = "WestDoor"
	door.position = Vector2(0, 9 * TILE)
	door.target_room = "first_test_room"
	room.entities().add_child(door)
	var warden: WardenBoss = load("res://scenes/bosses/warden.tscn").instantiate()
	warden.name = "Warden"
	warden.position = Vector2(22.5 * TILE, 12 * TILE - WardenBoss.SIZE.y * 0.5)
	room.entities().add_child(warden)
	var arena := Arena.new()
	arena.position = Vector2(11 * TILE, 1 * TILE)
	arena.size_tiles = Vector2i(18, 11)
	arena.boss = NodePath("../Warden")
	room.entities().add_child(arena)
	return room


const CRAWLER_SCENE := preload("res://scenes/enemies/crawler_sewer.tscn")
const PINK_CRAWLER_SCENE := preload("res://scenes/enemies/crawler_pink.tscn")
const THUG_SCENE := preload("res://scenes/enemies/thug.tscn")


func _test_editor_room_plays() -> void:
	print("An editor-made room plays: floor, start, raised gate, crawler, spikes")
	await _spawn_node(_build_editor_room())
	await _frames(30)
	_check(_player.is_on_floor() and absf(_player.global_position.x - 4.5 * TILE) < 2.0,
			"player starts at the PlayerStart, on the painted floor (col %.1f)" % (_player.global_position.x / TILE))
	_check(_main._kind_at(6, 11) == RoomArt.Kind.SPIKES and _main._kind_at(10, 9) == RoomArt.Kind.GATE
			and _main._kind_at(0, 10) == RoomArt.Kind.DOOR,
			"spikes, gate and door read from the tiles' kinds")
	_check(not _main._gate_closed and _main.gates().get_used_cells().size() == 1, "the gate starts raised (teeth only)")
	var crawler: CrawlerEnemy = _main.entities().get_node("Crawler")
	var x0 := crawler.global_position.x
	await _frames(30)
	_check(crawler.is_on_floor() and absf(crawler.global_position.x - x0) > 10.0, "the placed crawler patrols the floor")
	_player.global_position = Vector2(6.5 * TILE, 10 * TILE)
	_player.velocity = Vector2.ZERO
	var hp := _player.health
	await _frames(30)
	_check(_player.health < hp, "the painted spikes hurt")
	await _despawn()


func _test_editor_room_door() -> void:
	print("An editor-made room's RoomDoor leads to its target room")
	await _spawn_node(_build_editor_room())
	await _remove_enemies()
	_place(2, 11)
	await _frames(5)
	Input.action_press("move_left")
	var room := await _wait_for_room("first_test_room", 120)
	Input.action_release("move_left")
	_check(room != null, "walking into the door loaded the first test room")
	await _frames(10)
	await _despawn()


func _test_editor_room_arena() -> void:
	print("An editor-made room's Arena starts the boss fight and shuts its gate")
	await _spawn_node(_build_editor_room())
	var boss: BossBase = _main._boss
	_check(boss is WardenBoss and is_equal_approx(boss.arena_left, 11 * TILE) and is_equal_approx(boss.arena_right, 29 * TILE),
			"the Warden gets the Arena's box (%.0f-%.0f)" % [boss.arena_left, boss.arena_right] if boss != null else "no boss")
	_place(16, 11)
	_check(await _wait_for_intro_end(), "walking in played the intro")
	_check(_main._gate_closed and _main.gates().get_used_cells().size() == 4, "the gate came down (%d tiles)" % _main.gates().get_used_cells().size())
	await _despawn()


func _test_decorate_wall_button() -> void:
	print("Decorate wall: fills every unpainted wall cell, keeps hand-painted ones, the same each time; the room shows it as baked")
	var hand_cell := Vector2i(3, 3)
	var baked := _build_editor_room()
	baked.background().set_cell(hand_cell, 0, RoomArt.WALLS[2])
	baked.decorate_wall_action.call()
	_check(baked.background().get_cell_atlas_coords(hand_cell) == RoomArt.WALLS[2], "the hand-painted cell is kept")
	_check(baked.background().get_used_cells().size() == 30 * 14, "every cell of the 30 x 14 room is wall (%d)" % baked.background().get_used_cells().size())
	var tiles := {}
	for c in baked.background().get_used_cells():
		tiles[c] = baked.background().get_cell_atlas_coords(c)
	_check(tiles.values().any(func(t): return t in [RoomArt.WINDOW_SMALL[0], RoomArt.WINDOW_LARGE[0]]), "with windows in it")
	var bare := baked.props().get_used_cells().filter(func(c): return not baked.background().get_cell_atlas_coords(c) in RoomArt.WALLS)
	_check(bare.is_empty(), "lights, posters and graffiti go on the Props layer, over brick (%d of %d not)" % [bare.size(), baked.props().get_used_cells().size()])
	var again := _build_editor_room()
	again.background().set_cell(hand_cell, 0, RoomArt.WALLS[2])
	again.decorate_wall_action.call()
	var differ := tiles.keys().filter(func(c): return again.background().get_cell_atlas_coords(c) != tiles[c])
	_check(differ.is_empty(), "pressing it again on the same room gives the same wall (%d differ)" % differ.size())
	again.free()
	await _spawn_node(baked)
	differ = tiles.keys().filter(func(c): return _main.background().get_cell_atlas_coords(c) != tiles[c])
	_check(_main.background().get_used_cells().size() == tiles.size() and differ.is_empty(), "in game the wall is exactly what was baked")
	await _despawn()


func _test_unpainted_wall_stays_open() -> void:
	print("Unpainted wall stays open to the skyline: nothing is added when the room loads")
	var room := _build_editor_room()
	room.background().set_cell(Vector2i(3, 3), 0, RoomArt.WALLS[0])
	await _spawn_node(room)
	_check(_main.background().get_used_cells().size() == 1, "only the painted wall cell (%d)" % _main.background().get_used_cells().size())
	await _despawn()


func _test_room_template() -> void:
	print("Room template: layers with the right tilesets, skyline, entities, helper nodes")
	var room: Room = load("res://scenes/rooms/room_template.tscn").instantiate()
	add_child(room)
	await _frames(1)
	_check(room.background().tile_set == RoomArt.BACKGROUND_TILES and room.background().z_index == -1, "Background: wall tiles, behind")
	_check(room.props().tile_set == RoomArt.PROPS_TILES and room.props().z_index == -1
			and room.background().get_index() < room.props().get_index() and room.props().get_index() < room.terrain().get_index(),
			"Props: props tiles, over the wall and behind the terrain")
	_check(room.terrain().tile_set == RoomArt.FOREGROUND_TILES and room.gates().tile_set == RoomArt.FOREGROUND_TILES,
			"Terrain and Gates: foreground tiles")
	var skyline: Skyline = room.get_node("Skyline")
	_check(skyline.get_children().any(func(c): return c is Sprite2D and c.texture == Skyline.TEXTURE), "the skyline builds itself")
	var start: PlayerStart = room.entities().get_node("PlayerStart")
	_check(start != null and not start.visible, "a PlayerStart, hidden in game")
	var door := RoomDoor.new()
	var prop: Array = door.get_property_list().filter(func(p): return p.name == "target_room")
	_check(prop.size() == 1 and prop[0].hint == PROPERTY_HINT_ENUM and prop[0].hint_string.split(",").size() == LevelData.ROOMS.size(),
			"a door offers the rooms to pick (%s)" % (prop[0].hint_string if prop.size() == 1 else "none"))
	door.position = Vector2(0, 64)
	_check(door.rect() == Rect2(0, 64, 32, 96), "a door is a tile wide and 3 tall by default")
	door.free()
	var arena := Arena.new()
	arena.position = Vector2(64, 32)
	arena.size_tiles = Vector2i(10, 6)
	_check(arena.rect() == Rect2(64, 32, 320, 192), "an arena's box comes from its size in tiles")
	arena.free()
	room.queue_free()
	await _frames(1)


func _test_tiles_say_what_they_are() -> void:
	print("Every painted tile carries its kind; lights come from tile data")
	await _spawn()
	var counts := {}
	for layer_name in ["Terrain", "Background", "Props", "Gates"]:
		var layer := _layer_named(layer_name)
		for cell in layer.get_used_cells():
			var kind: String = layer.get_cell_tile_data(cell).get_custom_data("kind")
			counts[kind] = counts.get(kind, 0) + 1
	_check(not counts.has(""), "no tile without a kind %s" % [counts])
	for kind in ["solid", "platform", "spikes", "acid", "door", "wall", "window", "light"]:
		_check(counts.get(kind, 0) > 0, "first test room has %s tiles (%d)" % [kind, counts.get(kind, 0)])
	var lights := _main.get_children().filter(func(c): return c is FlickerLight)
	_check(lights.size() == counts.get("light", 0) + 1, "a glow per light tile, plus the door's EXIT sign (%d)" % lights.size())
	await _despawn()
	await _spawn(BOSS_SCENE)
	var gates := _layer_named("Gates")
	_check(gates.get_used_cells().size() > 0 and gates.get_used_cells().all(
			func(c): return gates.get_cell_tile_data(c).get_custom_data("kind") == "gate"), "the boss room's gates are gate tiles")
	await _despawn()


func _test_props_layer() -> void:
	print("Props layer: props and pipes on their own sheets with no brick behind, over brick in every room")
	# The posters' cells keep only the poster: the sheet is see-through around it.
	var sheet := (load("res://art/tiles/props.png") as Texture2D).get_image()
	var size: Vector2i = RoomArt.POSTERS[1] * TILE
	var cut := sheet.get_region(Rect2i(RoomArt.POSTERS[0] * TILE, size))
	var clear := 0
	for y in size.y:
		for x in size.x:
			if cut.get_pixel(x, y).a == 0.0:
				clear += 1
	_check(clear > 0 and clear < size.x * size.y, "the posters have no brick behind them (%d of %d pixels clear)" % [clear, size.x * size.y])
	var source: TileSetAtlasSource = RoomArt.PROPS_TILES.get_source(0)
	_check(source.has_tile(RoomArt.POSTERS[0]) and source.get_tile_data(RoomArt.POSTERS[0], 0).get_custom_data("kind") == "decor",
			"a poster is a decor tile on the props sheet")
	var lights := [RoomArt.LIGHT_LIT, RoomArt.LIGHT_DEAD].map(func(c): return source.get_tile_data(c, 0).get_custom_data("light"))
	_check(lights == ["steady", "broken"], "the bulbs on the props sheet say how they glow (%s)" % [lights])
	var pipes: TileSetAtlasSource = RoomArt.PROPS_TILES.get_source(RoomArt.PIPES_SOURCE)
	_check(pipes != null and pipes.get_tiles_count() == 20 and pipes.get_tile_data(RoomArt.PIPE_H, 0).get_custom_data("kind") == "pipe",
			"pipes are the props tileset's second sheet (%d tiles)" % (pipes.get_tiles_count() if pipes != null else 0))
	var background: TileSetAtlasSource = RoomArt.BACKGROUND_TILES.get_source(0)
	var left := []
	for i in background.get_tiles_count():
		var kind: String = background.get_tile_data(background.get_tile_id(i), 0).get_custom_data("kind")
		if not kind in ["wall", "window"]:
			left.append(background.get_tile_id(i))
	_check(left.is_empty(), "the background sheet is only wall and windows%s" % ("" if left.is_empty() else ", not %s" % [left]))
	# Each room: every Props cell is a real tile with wall behind it, and every
	# Background cell is still a real tile now the posters have left that sheet.
	for room_id in LevelData.ROOMS:
		var room: Room = load(LevelData.ROOMS[room_id].scene).instantiate()
		var missing := []
		for layer in [room.background(), room.props()]:
			for c in layer.get_used_cells():
				var atlas := layer.tile_set.get_source(layer.get_cell_source_id(c)) as TileSetAtlasSource
				if atlas == null or not atlas.has_tile(layer.get_cell_atlas_coords(c)):
					missing.append(c)
		var bare := room.props().get_used_cells().filter(func(c): return room.background().get_cell_source_id(c) == -1)
		_check(missing.is_empty() and bare.is_empty(),
				"%s: props over wall, every tile real (%d missing, %d props on open wall)" % [room_id, missing.size(), bare.size()])
		room.free()


func _test_pipe_brush() -> void:
	print("Pipe brush: straight lengths, elbows, T's, crossings and ends, joined up as painted")
	var layer := TileMapLayer.new()
	layer.tile_set = RoomArt.PROPS_TILES
	# A crossing with an elbow and a T on its arms, and a lone stub:
	#   . . X . . . .
	#   . . X X X . .
	#   X X X X . . X
	#   . . X . . . .
	var cells: Array[Vector2i] = [
		Vector2i(2, 0), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3),
	]
	layer.set_cells_terrain_connect(cells, 0, 0)
	layer.set_cells_terrain_connect([Vector2i(6, 2)], 0, 0)
	cells.append(Vector2i(6, 2))
	var steps := {"N": Vector2i.UP, "E": Vector2i.RIGHT, "S": Vector2i.DOWN, "W": Vector2i.LEFT}
	var wrong := cells.filter(func(c):
		var want := ""
		for s in "NESW":
			if cells.has(c + steps[s]):
				want += s
		return layer.get_cell_source_id(c) != RoomArt.PIPES_SOURCE or _pipe_sides(layer.get_cell_atlas_coords(c)) != want)
	_check(wrong.is_empty(), "every pipe joins exactly its painted neighbours%s" % ("" if wrong.is_empty() else ", wrong at %s" % [wrong]))
	layer.free()


func _test_normal_maps() -> void:
	print("Normal maps: every lit sheet has one, the same size, and everything draws the sheet with it")
	var tool: GDScript = load("res://tools/make_normal_maps.gd")
	var bad := []
	for sheet in tool.SHEETS:
		var canvas := load(tool.canvas_path(sheet)) as CanvasTexture
		var size := (load(sheet) as Texture2D).get_size()
		if canvas == null or canvas.diffuse_texture != load(sheet) or canvas.normal_texture == null 				or canvas.normal_texture.resource_path != tool.normal_path(sheet) or canvas.normal_texture.get_size() != size:
			bad.append(sheet.get_file())
	_check(bad.is_empty(), "%d sheets, each paired with a normal map its size%s" % [tool.SHEETS.size(), "" if bad.is_empty() else ", not %s" % [bad]])
	# What draws them: the tilesets, the sprite frames, the player's skins, the moving platform.
	var users := {}
	for tileset in [RoomArt.FOREGROUND_TILES, RoomArt.BACKGROUND_TILES, RoomArt.PROPS_TILES]:
		for i in tileset.get_source_count():
			var source: TileSetAtlasSource = tileset.get_source(tileset.get_source_id(i))
			users[source.texture.resource_path] = source.texture
	for scene in [THUG_SCENE, CRAWLER_SCENE, PINK_CRAWLER_SCENE]:
		var enemy: Node = scene.instantiate()
		var frames: SpriteFrames = enemy.get_node("Sprite").sprite_frames
		var atlas: AtlasTexture = frames.get_frame_texture(frames.get_animation_names()[0], 0)
		users[scene.resource_path.get_file()] = atlas.atlas
		enemy.free()
	for skin in PlayerSprite.SKINS:
		users[skin.id] = load(skin.sheet)
	users["moving platform"] = MovingPlatform.SHEET
	var flat := users.keys().filter(func(k): return not (users[k] is CanvasTexture and users[k].normal_texture != null))
	_check(flat.is_empty(), "tiles, enemies, the player and platforms draw with their normal maps%s" % ("" if flat.is_empty() else ", not %s" % [flat]))
	# The room's lights hang out from the wall, so they shade a flat normal map
	# rather than grazing it.
	var light := FlickerLight.new()
	add_child(light)
	_check(light.light.height > 0.0 and RoomArt.BULB_LIGHT_HEIGHT > 0.0 and RoomArt.SIGN_LIGHT_HEIGHT > 0.0,
			"lights hang out from the wall (bulbs %d px, signs %d px)" % [RoomArt.BULB_LIGHT_HEIGHT, RoomArt.SIGN_LIGHT_HEIGHT])
	light.free()


## The sides a pipes-sheet tile runs out of: from the block's layout, or the
## wall end a broken end stands in for.
func _pipe_sides(at: Vector2i) -> String:
	var i := RoomArt.PIPE_BROKEN_ENDS.find(at)
	if i >= 0:
		at = RoomArt.PIPE_WALL_ENDS[i]
	return RoomArt.TERRAIN[at.y][at.x] if at.y < RoomArt.TERRAIN.size() else "?"


## An enemy scene set up as if placed and edited in the Inspector.
func _place_enemy(scene: PackedScene, settings: Dictionary, at: Vector2) -> EnemyBase:
	var enemy: EnemyBase = scene.instantiate()
	for key in settings:
		enemy.set(key, settings[key])
	enemy.position = at
	_main.add_child(enemy)
	return enemy


func _test_enemy_inspector_settings() -> void:
	print("Placed enemies keep their Inspector settings; crawler colours are ready-made scenes")
	await _spawn()
	await _remove_enemies()
	var floor_y := 18 * TILE - CrawlerEnemy.SIZE.y * 0.5
	var pink: CrawlerEnemy = _place_enemy(PINK_CRAWLER_SCENE, {}, Vector2(9.5 * TILE, floor_y))
	var tough: CrawlerEnemy = _place_enemy(CRAWLER_SCENE, {"heal_on_kill": 3, "max_health": 6}, Vector2(13.5 * TILE, floor_y))
	var thug: ThugEnemy = _place_enemy(THUG_SCENE, {"heal_on_kill": 1}, Vector2(20.5 * TILE, 18 * TILE - ThugEnemy.SIZE.y * 0.5))
	await _frames(2)
	_check(pink.sprite == pink.get_node("Sprite") and pink.sprite.sprite_frames.resource_path.ends_with("crawler_pink_frames.tres"),
			"the sprite comes with the scene, with its saved frames")
	_check(pink is PinkCrawler and pink.kill_heal() == PinkCrawler.KILL_HEAL, "pink heals by default")
	_check(tough.health == 6 and tough.kill_heal() == 3, "a sewer crawler set to heal 3, with 6 health")
	var stock: ThugEnemy = THUG_SCENE.instantiate()   # the type's defaults, from its scene
	_check(thug.health == stock.max_health and thug.damage == stock.damage and thug.kill_heal() == 1,
			"a thug keeps its scene's defaults (%d health, %d damage), set to heal 1" % [stock.max_health, stock.damage])
	stock.free()
	var deaths := []
	tough.died.connect(func() -> void: deaths.append(tough))
	_player.health = 2
	tough.take_hit(5, Vector2.RIGHT)
	_check(_player.health == 2 and not tough.is_dying(), "survives 5 of its 6 health")
	tough.take_hit(1, Vector2.RIGHT)
	_check(_player.health == 5 and deaths.size() == 1, "its kill healed 3 and sent died (health %d)" % _player.health)
	await _despawn()


func _test_placed_ceiling_crawlers_stay_up() -> void:
	print("Ceiling crawlers placed in the rooms patrol their ceilings without falling (player hidden)")
	var total := 0
	for room in LevelData.ROOMS:
		await _spawn(load(LevelData.ROOMS[room].scene), true)
		# Hidden, so none of them drops on purpose; frozen where it spawned.
		_player.visible = false
		_player.process_mode = Node.PROCESS_MODE_DISABLED
		var watched := {}
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is CrawlerEnemy and e.on_ceiling:
				watched[e] = {"start": e.global_position, "min_x": e.global_position.x, "max_x": e.global_position.x}
		for i in 600:   # 10 seconds: long enough to reach the ends of their ceilings and turn
			await _frames(1)
			for e in watched:
				if is_instance_valid(e):
					watched[e].min_x = minf(watched[e].min_x, e.global_position.x)
					watched[e].max_x = maxf(watched[e].max_x, e.global_position.x)
		for e in watched:
			var w: Dictionary = watched[e]
			var where := "%s col %.1f row %.1f" % [room, w.start.x / TILE, w.start.y / TILE]
			if not is_instance_valid(e):
				_check(false, "%s: gone" % where)
				continue
			_check(e.on_ceiling and absf(e.global_position.y - w.start.y) < 2.0,
					"%s: still on its ceiling (row %.1f)" % [where, e.global_position.y / TILE])
			_check(w.max_x - w.min_x > TILE, "%s: patrolled %.1f tiles of it" % [where, (w.max_x - w.min_x) / TILE])
		total += watched.size()
		await _despawn()
	_check(total > 0, "found %d ceiling crawlers across the rooms" % total)


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
		if e.global_position.x > 60 * TILE and not (e is CrawlerEnemy and e.on_ceiling):
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
	_player.health = 6
	Input.action_press("move_right")
	var room := await _wait_for_room("boss", 120)
	Input.action_release("move_right")
	_check(room != null, "boss room loaded")
	if room == null:
		await _despawn()
		return
	await _frames(20)
	var p: Player = room._player
	_check(GameState.arrived_from == "first_test_room", "arrival recorded from the first test room")
	_check(p.health == 6, "health carried through the door (%d)" % p.health)
	_check(p.is_on_floor() and p.global_position.x < 5 * TILE and absf(p.global_position.y - (29 * TILE - Player.BODY_SIZE.y * 0.5)) < 4.0,
			"arrived inside the lower corridor's door (col %.1f, row %.1f)" % [p.global_position.x / TILE, p.global_position.y / TILE])
	p.health = 5
	Input.action_press("move_left")
	room = await _wait_for_room("first_test_room", 300)
	Input.action_release("move_left")
	_check(room != null, "returned to the first test room")
	if room != null:
		await _frames(20)
		p = room._player
		_check(p.health == 5, "health carried back (%d)" % p.health)
		_check(p.is_on_floor() and p.global_position.x > 100 * TILE,
				"arrived on the ledge beside the door (col %.1f, row %.1f)" % [p.global_position.x / TILE, p.global_position.y / TILE])
		# Restarting the room afterwards starts at full health, as before.
		var old := room
		get_tree().reload_current_scene()
		for i in 30:
			await _frames(1)
			if get_tree().current_scene != old and get_tree().current_scene != null:
				break
		room = get_tree().current_scene
		_check(room != old and room._player.health == room._player.max_health, "restart refills health")
	await _despawn()


const MOVING_PLATFORM_SCENE := preload("res://scenes/props/moving_platform.tscn")


## An open 40 x 16 room with two tracks: side to side on row 8 (cols 4-15), and
## up and down in col 25 (rows 3-12), each with a 3-wide platform on it. A
## third platform sits off any track.
func _build_platform_room() -> Room:
	var room: Room = load("res://scenes/rooms/room_template.tscn").instantiate()
	room.room = "test"
	var solid: Array[Vector2i] = []
	for x in 40:
		solid.append(Vector2i(x, 0))
		solid.append(Vector2i(x, 15))
	for y in range(1, 15):
		solid.append(Vector2i(0, y))
		solid.append(Vector2i(39, y))
	room.terrain().set_cells_terrain_connect(solid, 0, 0)
	var across: Array[Vector2i] = []
	for x in range(4, 16):
		across.append(Vector2i(x, 8))
	room.terrain().set_cells_terrain_connect(across, 0, 4)
	var upright: Array[Vector2i] = []
	for y in range(3, 13):
		upright.append(Vector2i(25, y))
	room.terrain().set_cells_terrain_connect(upright, 0, 4)
	room.entities().get_node("PlayerStart").position = Vector2(2.5 * TILE, 15 * TILE)
	for p in [["Across", Vector2(7.5, 8)], ["Upright", Vector2(25.5, 12)], ["Loose", Vector2(33.5, 10)]]:
		var platform: MovingPlatform = MOVING_PLATFORM_SCENE.instantiate()
		platform.name = p[0]
		platform.position = p[1] * TILE
		room.entities().add_child(platform)
	return room


func _test_track_brush() -> void:
	print("Track brush: straight runs of end, middle and end tiles, side to side or up and down")
	var layer := TileMapLayer.new()
	layer.tile_set = RoomArt.FOREGROUND_TILES
	layer.set_cells_terrain_connect([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)], 0, 4)
	layer.set_cells_terrain_connect([Vector2i(0, 3), Vector2i(0, 4), Vector2i(0, 5), Vector2i(0, 6)], 0, 4)
	var across := [0, 1, 2, 3].map(func(x): return layer.get_cell_atlas_coords(Vector2i(x, 0)))
	var upright := [3, 4, 5, 6].map(func(y): return layer.get_cell_atlas_coords(Vector2i(0, y)))
	var h := RoomArt.TRACK_H
	var v := RoomArt.TRACK_V
	_check(across == [h, h + Vector2i(1, 0), h + Vector2i(1, 0), h + Vector2i(2, 0)], "side to side: %s" % [across])
	_check(upright == [v, v + Vector2i(0, 1), v + Vector2i(0, 1), v + Vector2i(0, 2)], "up and down: %s" % [upright])
	var kinds := [layer.get_cell_tile_data(Vector2i(1, 0)).get_custom_data("kind"), layer.get_cell_tile_data(Vector2i(0, 4)).get_custom_data("kind")]
	_check(kinds == ["track", "track"], "the tiles say they're track")
	layer.free()


func _test_moving_platform_travel() -> void:
	print("Moving platforms: find their track, go end to end and back, stay put off a track")
	await _spawn_node(_build_platform_room())
	var across: MovingPlatform = _main.entities().get_node("Across")
	var upright: MovingPlatform = _main.entities().get_node("Upright")
	var loose: MovingPlatform = _main.entities().get_node("Loose")
	_check(across.on_track() and across.travel() == [Vector2(5.5 * TILE, 8 * TILE), Vector2(14.5 * TILE, 8 * TILE)],
			"side to side: the deck stays between the track's ends %s" % [across.travel()])
	_check(upright.on_track() and upright.travel() == [Vector2(25.5 * TILE, 3 * TILE), Vector2(25.5 * TILE, 12 * TILE)],
			"up and down: the deck follows the rail %s" % [upright.travel()])
	_check(_main._kind_at(8, 8) == RoomArt.Kind.EMPTY, "track tiles aren't part of the layout")
	var loose_at := loose.position
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	# Long enough for a full trip each way, waits included.
	for i in int((9.0 * TILE / across.speed + across.end_pause) * 2.0 * 60.0) + 30:
		await _frames(1)
		min_x = minf(min_x, across.position.x)
		max_x = maxf(max_x, across.position.x)
		min_y = minf(min_y, upright.position.y)
		max_y = maxf(max_y, upright.position.y)
	_check(is_equal_approx(min_x, 5.5 * TILE) and is_equal_approx(max_x, 14.5 * TILE) and across.position.y == 8 * TILE,
			"side to side: reached both ends (%.1f to %.1f)" % [min_x / TILE, max_x / TILE])
	_check(is_equal_approx(min_y, 3 * TILE) and is_equal_approx(max_y, 12 * TILE) and upright.position.x == 25.5 * TILE,
			"up and down: reached both ends (%.1f to %.1f)" % [min_y / TILE, max_y / TILE])
	_check(not loose.on_track() and loose.position == loose_at, "off a track it stays put")
	await _despawn()


func _test_moving_platform_carries_player() -> void:
	print("Moving platforms carry the player, can be dropped through, and aren't safe ground")
	await _spawn_node(_build_platform_room())
	await _frames(20)
	var safe := _player.last_safe_position
	for platform_name in ["Across", "Upright"]:
		var platform: MovingPlatform = _main.entities().get_node(platform_name)
		_player.global_position = platform.global_position + Vector2(0, -Player.BODY_SIZE.y * 0.5 - 2)
		_player.velocity = Vector2.ZERO
		await _frames(10)
		var start := _player.global_position
		var deck := platform.global_position
		await _frames(60)
		var moved := platform.global_position - deck
		var rode := _player.global_position - start
		_check(_player.is_on_floor() and moved.length() > 40.0 and rode.distance_to(moved) < 4.0,
				"%s: the player rides along (platform moved %s, player %s)" % [platform_name, moved.round(), rode.round()])
	_check(_player.last_safe_position == safe, "a moving platform isn't a respawn point")
	# Drop through it: down + jump.
	Input.action_press("move_down")
	Input.action_press("jump")
	await _frames(3)
	_release_all()
	var upright: MovingPlatform = _main.entities().get_node("Upright")
	await _frames(20)
	_check(_player.global_position.y > upright.global_position.y + TILE, "down + jump drops through it")
	await _despawn()


## Dashes from where the player is with `held` directions pressed, and returns
## how far the dash itself went.
func _dash_holding(held: Array) -> Vector2:
	_player.stamina = _player.max_stamina
	for a in held:
		Input.action_press(a)
	var start := _player.global_position
	Input.action_press("dash")
	await _frames(1)
	Input.action_release("dash")
	await _frames(int(ceilf(_player.dash_duration * 60.0)) - 1)
	var moved := _player.global_position - start
	_release_all()
	await _frames(int(_player.dash_cooldown * 60.0) + 2)
	return moved


func _stand_at(col: float) -> void:
	_player.global_position = Vector2(col * TILE, 15 * TILE - Player.BODY_SIZE.y * 0.5)
	_player.velocity = Vector2.ZERO
	await _frames(10)


func _float_at(col: float, row: float) -> void:
	_player.global_position = Vector2(col * TILE, row * TILE)
	_player.velocity = Vector2.ZERO
	_player._air_dash_available = true
	await _frames(2)


func _test_dash_eight_directions() -> void:
	print("Dash goes the way you hold: 8 directions, along the floor if down on the ground")
	await _spawn_node(_build_platform_room())
	GameState.unlock("dash")
	var reach := _player.dash_speed * _player.dash_duration
	await _stand_at(32.5)
	var moved := await _dash_holding([])
	_check(moved.x > reach * 0.8 and absf(moved.y) < 2.0, "nothing held: straight ahead (%s)" % [moved.round()])

	await _stand_at(32.5)
	Input.action_press("move_up")
	Input.action_press("dash")
	await _frames(3)
	var tilt := _player.sprite.rotation
	_release_all()
	_check(is_equal_approx(tilt, -PI / 2.0 * _player.facing), "dashing up tilts the sprite head first (%.2f)" % tilt)
	await _frames(40)

	await _stand_at(32.5)
	moved = await _dash_holding(["move_up"])
	_check(moved.y < -reach * 0.8 and absf(moved.x) < 2.0, "up from the ground: straight up (%s)" % [moved.round()])
	await _frames(40)

	await _stand_at(30.5)
	moved = await _dash_holding(["move_down", "move_left"])
	_check(moved.x < -reach * 0.8 and absf(moved.y) < 2.0 and _player.is_on_floor(), "down-left on the ground: along the floor (%s)" % [moved.round()])

	await _float_at(30.5, 8)
	moved = await _dash_holding(["move_up", "move_right"])
	_check(moved.x > reach * 0.55 and moved.y < -reach * 0.55 and absf(absf(moved.x) - absf(moved.y)) < 4.0,
			"up-right in the air: diagonal (%s)" % [moved.round()])

	await _float_at(34.5, 5)
	moved = await _dash_holding(["move_down", "move_left"])
	_check(moved.x < -reach * 0.55 and moved.y > reach * 0.55, "down-left in the air: diagonal (%s)" % [moved.round()])

	await _float_at(34.5, 13)
	Input.action_press("move_down")
	Input.action_press("dash")
	await _frames(2)
	Input.action_release("dash")
	var dashing := _player._dash_timer > 0.0
	await _frames(6)
	_check(dashing and _player.is_on_floor() and _player._dash_timer <= 0.0 and _player.velocity.y <= 1.0,
			"down into the floor: lands and the dash ends there")
	await _despawn()


func _test_moving_platform_momentum() -> void:
	print("Jumping off a moving platform carries its speed, fading out over platform_carry_time")
	await _spawn_node(_build_platform_room())
	var across: MovingPlatform = _main.entities().get_node("Across")
	_player.global_position = across.global_position + Vector2(0, -Player.BODY_SIZE.y * 0.5 - 2)
	_player.velocity = Vector2.ZERO
	await _frames(10)
	var riding := _player.get_platform_velocity().x
	Input.action_press("jump")   # held: a full jump, straight up, no steering
	for i in 10:   # lift off
		await _frames(1)
		if not _player.is_on_floor():
			break
	var speeds: Array[float] = []
	var fade_frames := int(_player.platform_carry_time * 60.0)
	for i in fade_frames + 5:
		speeds.append(_player.velocity.x)
		await _frames(1)
	_release_all()
	_check(absf(riding - across.speed) < 1.0 and speeds[1] > riding * 0.9,
			"leaving, you have the platform's speed (%.0f px/s, platform %.0f)" % [speeds[1], riding])
	var halfway := speeds[fade_frames / 2]
	_check(absf(halfway - riding * 0.5) < riding * 0.12, "halfway through it's about half (%.0f px/s)" % halfway)
	_check(absf(speeds[fade_frames + 1]) < 2.0, "after %.1f s it's gone (%.0f px/s)" % [_player.platform_carry_time, speeds[fade_frames + 1]])
	for i in 120:
		await _frames(1)
		if _player.is_on_floor():
			break
	await _frames(2)
	_check(_player.is_on_floor() and _player._carried_x == 0.0, "landed, with nothing carried")
	await _despawn()


## Places an enemy of `scene` on the platform room's floor, puts the player at
## `offset` from its middle, swings ("down" or "side", facing right), and
## returns [the player's velocity right after the hit, the direction from the
## enemy to the player at that moment].
func _swing_at(scene: PackedScene, size_y: float, direction: String, offset: Vector2) -> Array:
	var floor_y := 15 * TILE
	var enemy := _place_enemy(scene, {}, Vector2(18.5 * TILE, floor_y - size_y * 0.5))
	enemy.set_physics_process(false)   # hold still to be hit
	_player._invuln_timer = 999.0
	_player.facing = 1
	_player.global_position = enemy.global_position + offset
	_player.velocity = Vector2.ZERO
	_player._attack_cooldown_timer = 0.0
	if direction == "down":
		Input.action_press("move_down")
	Input.action_press("attack")
	var result := [Vector2.ZERO, Vector2.ZERO]
	for i in 6:
		var away := (_player.global_position - enemy.global_position).normalized()
		await _frames(1)
		if enemy.health < enemy.max_health:
			result = [_player.velocity, away]
			break
	_release_all()
	enemy.queue_free()
	await _frames(20)
	_player._invuln_timer = 0.0
	return result


func _test_player_light() -> void:
	print("The player carries a faint light; each swing flashes over the slash")
	await _spawn()
	_check(_player.light != null and is_equal_approx(_player.light.energy, _player.light_energy) and _player.light.color == _player.light_color
			and is_equal_approx(_player.light.height, _player.light_height) and _player.light.texture.get_width() == _player.light_radius * 2,
			"a light on the player, as set in its Light settings")
	_player.facing = 1
	Input.action_press("attack")
	await _frames(2)
	Input.action_release("attack")
	var flashes := _player.get_children().filter(func(c): return c is LightFlash)
	_check(flashes.size() == 1 and flashes[0].color == _player.slash_flash_color and flashes[0].position == _player.slash.position,
			"a swing throws a flash over the slash")
	if flashes.size() == 1:
		var first: float = flashes[0].energy
		await _frames(3)
		_check(flashes[0].energy < first and first <= _player.slash_flash_energy, "which fades (%.2f, then %.2f)" % [first, flashes[0].energy])
		await _frames(int(_player.slash_flash_time * 60) + 2)
		_check(not is_instance_valid(flashes[0]), "and is gone after %.2f s" % _player.slash_flash_time)
	await _despawn()


func _test_hit_recoil() -> void:
	print("Hits push you away from the enemy, by its hit_recoil: crawlers hard, thugs and the Warden barely")
	# Each type's default comes from its scene, as placed in a room (and shown in the Inspector).
	var crawler: EnemyBase = CRAWLER_SCENE.instantiate()
	var thug: EnemyBase = THUG_SCENE.instantiate()
	var warden: BossBase = load("res://scenes/bosses/warden.tscn").instantiate()
	var harrier: BossBase = load("res://scenes/bosses/harrier.tscn").instantiate()
	var crawler_recoil := crawler.hit_recoil
	var thug_recoil := thug.hit_recoil
	_check(crawler_recoil > thug_recoil and crawler_recoil > warden.hit_recoil,
			"crawlers (%.0f) push harder than thugs (%.0f) and the Warden (%.0f); the Harrier %.0f"
			% [crawler_recoil, thug_recoil, warden.hit_recoil, harrier.hit_recoil])
	for n in [crawler, thug, warden, harrier]:
		n.free()
	await _spawn_node(_build_platform_room())
	await _frames(5)
	var above_crawler := Vector2(0, -CrawlerEnemy.SIZE.y * 0.5 - 50)
	var above_thug := Vector2(0, -ThugEnemy.SIZE.y * 0.5 - 50)
	var floor_level := func(size_y: float) -> Vector2: return Vector2(-52, size_y * 0.5 - Player.BODY_SIZE.y * 0.5)
	for case in [
			["a down-strike on a crawler bounces you straight up, high", CRAWLER_SCENE, CrawlerEnemy.SIZE.y, "down", above_crawler, crawler_recoil],
			["off its left edge, up and to the left", CRAWLER_SCENE, CrawlerEnemy.SIZE.y, "down", above_crawler + Vector2(-26, 0), crawler_recoil],
			["on a thug, a small hop", THUG_SCENE, ThugEnemy.SIZE.y, "down", above_thug, thug_recoil],
			["a side swing at a crawler shoves you back hard", CRAWLER_SCENE, CrawlerEnemy.SIZE.y, "side", floor_level.call(CrawlerEnemy.SIZE.y), crawler_recoil],
			["at a thug, a little", THUG_SCENE, ThugEnemy.SIZE.y, "side", floor_level.call(ThugEnemy.SIZE.y), thug_recoil]]:
		var hit: Array = await _swing_at(case[1], case[2], case[3], case[4])
		var pushed: Vector2 = hit[0]
		var away: Vector2 = hit[1]
		_check(away != Vector2.ZERO and absf(pushed.length() - case[5]) < 5.0 and absf(pushed.angle_to(away)) < deg_to_rad(4.0),
				"%s: %s, along enemy to player %s" % [case[0], pushed.round(), (away * 100).round() / 100])
	await _despawn()


## Every file under `dir` (res://...) whose name ends with `suffix`, searched recursively.
func _files_under(dir: String, suffix: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var d := DirAccess.open(dir)
	if d == null:
		return found
	for f in d.get_files():
		if f.ends_with(suffix):
			found.append(dir.path_join(f))
	for sub in d.get_directories():
		found.append_array(_files_under(dir.path_join(sub), suffix))
	return found


func _test_translation_files_registered() -> void:
	print("Localization: every .po file in localization/ is registered in the project, and every registered one exists")
	var registered: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	var on_disk := _files_under("res://localization", ".po")
	var missing := Array(on_disk).filter(func(p): return not registered.has(p))
	var gone := Array(registered).filter(func(p): return not FileAccess.file_exists(p))
	_check(not on_disk.is_empty() and missing.is_empty(),
			"%d file(s), all registered%s" % [on_disk.size(), "" if missing.is_empty() else "; not registered: %s" % [missing]])
	_check(gone.is_empty(), "no registered file is missing%s" % ("" if gone.is_empty() else ": %s" % [gone]))
	_check(Array(on_disk).all(func(p): return p.get_base_dir().get_file() == (load(p) as Translation).locale),
			"each file's language matches its folder (localization/<language>/<feature>.po)")


func _test_every_key_has_english() -> void:
	print("Localization: every UI_ key the scenes and scripts use has English text")
	TranslationServer.set_locale("en")
	var key := RegEx.create_from_string("\"(UI_[A-Z0-9_]*[A-Z0-9])\"")
	var used := {}
	for path in _files_under("res://scenes", ".tscn") + _files_under("res://scripts", ".gd"):
		for m in key.search_all(FileAccess.get_file_as_string(path)):
			used[m.get_string(1)] = path
	for ability in GameState.STARTING_ABILITIES:   # built in code: GameState.ability_name()
		used["UI_ABILITY_" + ability.to_upper()] = "game_state.gd"
	var untranslated := used.keys().filter(func(k): return TranslationServer.translate(k) == k)
	_check(used.size() > 20 and untranslated.is_empty(), "%d keys in use%s" % [used.size(),
			"" if untranslated.is_empty() else "; no English for %s" % [untranslated.map(func(k): return "%s (%s)" % [k, used[k].get_file()])]])


func _test_language_switch() -> void:
	print("Localization: switching language updates the menus and HUD; the Language button switches and remembers it")
	var saved: Variant = FileAccess.get_file_as_bytes(GameState.SETTINGS_PATH) if FileAccess.file_exists(GameState.SETTINGS_PATH) else null
	var test_language := Translation.new()
	test_language.locale = "eo"   # a stand-in second language, for this test only
	test_language.add_message("UI_MENU_START", "Komenci")
	test_language.add_message("UI_HUD_ABILITIES", "Kapabloj: {list}")
	test_language.add_message("UI_ABILITY_DASH", "Kuro")
	TranslationServer.add_translation(test_language)
	TranslationServer.set_locale("en")
	var menu := MENU_SCENE.instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await _frames(2)
	var english_language: String = menu.language_button.text
	_check(GameState.languages() == PackedStringArray(["en", "eo"]), "both languages listed %s" % [GameState.languages()])
	menu.language_button.pressed.emit()
	await _frames(2)
	var settings := ConfigFile.new()
	settings.load(GameState.SETTINGS_PATH)
	_check(GameState.language() == "eo" and settings.get_value("game", "language", "") == "eo",
			"the Language button switched to the next language, and saved it")
	_check(menu.start_button.atr(menu.start_button.text) == "Komenci", "a menu button shows its new text")
	_check(menu.language_button.text != english_language, "the Language button names the new language (%s)" % menu.language_button.text)
	await _despawn()
	await _spawn()
	GameState.unlock("dash")
	await _frames(1)
	_check(_main._hud._abilities_label.text == "Kapabloj: Kuro", "the HUD's ability list too (%s)" % _main._hud._abilities_label.text)
	TranslationServer.set_locale("en")
	await _frames(1)
	_check(_main._hud._abilities_label.text.begins_with("Abilities: "), "and back to English (%s)" % _main._hud._abilities_label.text)
	await _despawn()
	TranslationServer.remove_translation(test_language)
	TranslationServer.set_locale("en")
	if saved == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SETTINGS_PATH))
	else:
		FileAccess.open(GameState.SETTINGS_PATH, FileAccess.WRITE).store_buffer(saved)


## Waits (through a pause) for the death screen to open, up to `max_frames`.
func _wait_for_death_screen(room: Node, max_frames: int) -> bool:
	for i in max_frames:
		await _frames(1)
		if not is_instance_valid(room):
			return false
		if room._death_menu.is_open():
			return true
	return false


func _test_death_screen() -> void:
	print("Death screen: says what dealt the final blow; Respawn restarts the room, Quit goes to the main menu")
	await _spawn()
	var room := _main
	_place(75, 15)   # over the acid
	var opened := await _wait_for_death_screen(room, int(room.DEATH_MENU_DELAY * 60) + 90)
	var menu: DeathMenu = room._death_menu
	_check(opened and get_tree().paused and menu.respawn_button.has_focus(), "opens after you die, paused, Respawn focused")
	_check(menu._cause.text == "UI_DEATH_BY_ACID" and tr(menu._cause.text) == "Dissolved in the sewer water",
			"names the sewer water (%s)" % tr(menu._cause.text))
	menu.respawn_button.pressed.emit()
	var again := await _wait_for_room("first_test_room", 60)
	_check(again != null and again != room and not again._player._dead and again._player.health == again._player.max_health
			and not get_tree().paused, "Respawn restarts the room, alive and unpaused")
	await _despawn()

	# A thug's punch, then Quit.
	await _spawn(CLIMB_SCENE)
	room = _main
	var thug := await _lone_thug()
	_player.health = 1
	_player.global_position = thug.global_position + Vector2(-50, 0)
	_player.velocity = Vector2.ZERO
	opened = await _wait_for_death_screen(room, 240)
	menu = room._death_menu
	_check(opened and _player.killed_by == ThugEnemy.PUNCH_BLOW and menu._cause.text == ThugEnemy.PUNCH_BLOW,
			"names the thug's punch (%s)" % tr(menu._cause.text))
	menu.quit_to_menu_button.pressed.emit()
	var at_menu := false
	for i in 120:
		await _frames(1)
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == MENU_SCENE.resource_path:
			at_menu = true
			break
	_check(at_menu and not get_tree().paused, "Quit to Main Menu goes to the main menu, unpaused")
	await _despawn()


func _test_thug_punch_reach() -> void:
	print("Thugs start a punch only once you're inside its reach, which a red swoosh fills")
	await _spawn(CLIMB_SCENE)
	var thug := await _lone_thug()
	thug.patrol_time = Vector2(999, 999)
	_player._invuln_timer = 999.0
	_player.global_position = thug.global_position + Vector2(-150, 0)
	_player.velocity = Vector2.ZERO
	var reach_at_windup := false
	var effect_ok := false
	for i in 240:
		var was := thug._state
		await _frames(1)
		if was != ThugEnemy.State.WINDUP and thug._state == ThugEnemy.State.WINDUP:
			reach_at_windup = thug.in_punch_reach(_player)
		if thug._state == ThugEnemy.State.SWING and thug.punch_effect.visible:
			var e := thug.punch_effect
			effect_ok = e.modulate == ThugEnemy.PUNCH_EFFECT_COLOR and e.position == thug._punch_shape.position \
					and (e.scale * SlashEffect.SIDE_FITS).is_equal_approx(thug.punch_size) and e.flip_h == (thug._dir < 0)
			break
	_check(thug.swings >= 1 and reach_at_windup, "it walked up and wound up with you in reach")
	_check(effect_ok, "the punch shows a red swoosh the size of its reach (%s), facing its way" % thug.punch_size)
	# Just outside the reach: no punch.
	var edge := thug.global_position.x + thug._dir * (ThugEnemy.SIZE.x * 0.5 + thug.punch_size.x - 4.0)
	_player.global_position.x = edge + thug._dir * (Player.BODY_SIZE.x * 0.5 + 2.0)
	_check(not thug.in_punch_reach(_player), "2 px past the edge of the reach is out of it")
	_player.global_position.x -= thug._dir * 4.0
	_check(thug.in_punch_reach(_player), "2 px inside it is in")
	await _despawn()
