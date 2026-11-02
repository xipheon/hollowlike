extends Node
## Autoload. Persists across scene reloads (death/respawn).
## Later: save/load, checkpoints, map discovery, boss flags all live here.

signal ability_unlocked(ability: String)
signal player_skin_changed(skin_id: String)

const FADE_TIME := 0.25
const MENU_SCENE := "res://scenes/main_menu.tscn"

## Abilities you begin a new game with; the rest are unlocked by bosses.
const STARTING_ABILITIES := {
	"double_jump": false,
	"sprint": false,
	"dash": false,
	"wall_jump": false,
}

var abilities := STARTING_ABILITIES.duplicate()

## Debug-only tools (F1/F2 unlocks, killing the boss from the pause menu).
## On when run from the editor or a debug export, off in release exports.
var debug_mode := OS.is_debug_build()

## Room the player last came from through a door ("" = fresh start, at the PlayerStart).
var arrived_from := ""
## Name of the door to arrive at in the next room ("" = the one leading back).
var arrive_at := ""
## Rooms whose boss has been beaten (room id -> where its corpse lies, Vector2).
var bosses_defeated := {}
## Health carried through a door into the next room, in half-hearts (-1 = none,
## start full). Used once, so dying or restarting a room still refills it.
var carried_health := -1
## The player's look (PlayerSprite.SKINS). Cosmetic, so a new game keeps it.
var player_skin := PlayerSprite.DEFAULT_SKIN

var _fade: ColorRect
var _transitioning := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # fades must run even if the game is paused
	# Fade overlay lives on the autoload so it survives scene changes.
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


func has_ability(ability: String) -> bool:
	return abilities.get(ability, false)

func unlock(ability: String) -> void:
	abilities[ability] = true
	ability_unlocked.emit(ability)


func set_player_skin(skin_id: String) -> void:
	player_skin = skin_id
	player_skin_changed.emit(skin_id)


## Fade out, load the target room's scene, fade back in. The player arrives
## with the health they left with, at the door named `door` there (or, if
## empty, the door leading back).
func go_through_door(from_room: String, to_room: String, health: int, door := "") -> void:
	if _transitioning:
		return
	carried_health = health
	arrive_at = door
	_fade_to_scene(LevelData.ROOMS[to_room].scene, from_room)


## The health to start a room with, or `full` if not coming through a door.
func take_carried_health(full: int) -> int:
	var health := carried_health if carried_health > 0 else full
	carried_health = -1
	return health


## Wipe progress and load the first room (from the main menu).
func start_new_game() -> void:
	start_at_room("first_test_room")


## Wipe progress and load any room at its PlayerStart (level select), with
## the starting abilities plus any in `unlocked` (a LevelButton's abilities).
func start_at_room(room: String, unlocked: Array = []) -> void:
	abilities = STARTING_ABILITIES.duplicate()
	for ability in unlocked:
		abilities[ability] = true
	bosses_defeated = {}
	carried_health = -1
	_fade_to_scene(LevelData.ROOMS[room].scene, "")


func return_to_menu() -> void:
	_fade_to_scene(MENU_SCENE, "")


func _fade_to_scene(path: String, from_room: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	get_tree().paused = false
	await create_tween().tween_property(_fade, "modulate:a", 1.0, FADE_TIME).finished
	arrived_from = from_room
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await create_tween().tween_property(_fade, "modulate:a", 0.0, FADE_TIME).finished
	_transitioning = false
