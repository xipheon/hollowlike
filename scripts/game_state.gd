extends Node
## Autoload. Persists across scene reloads (death/respawn).
## Later: save/load, checkpoints, map discovery, boss flags all live here.

signal ability_unlocked(ability: String)
signal coins_changed(count: int)

const FADE_TIME := 0.25
const MENU_SCENE := "res://scenes/main_menu.tscn"

var abilities := {
	"dash": false,
	"wall_jump": false,
}

## Room the player last came from through a door ("" = fresh start, use P).
var arrived_from := ""
## Rooms whose boss has been beaten (room id -> where its corpse lies, Vector2).
var bosses_defeated := {}
var coins := 0
## Coins already picked up, keyed "room:x,y", so they don't respawn.
var collected_coins := {}

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


func collect_coin(coin_id: String) -> void:
	collected_coins[coin_id] = true
	coins += 1
	coins_changed.emit(coins)


## Fade out, load the target room's scene, fade back in.
func go_through_door(from_room: String, to_room: String) -> void:
	_fade_to_scene(LevelData.ROOMS[to_room].scene, from_room)


## Wipe progress and load the first room (from the main menu).
func start_new_game() -> void:
	abilities = {"dash": false, "wall_jump": false}
	bosses_defeated = {}
	coins = 0
	collected_coins = {}
	_fade_to_scene(LevelData.ROOMS["start"].scene, "")


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
