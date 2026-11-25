extends Node
## Autoload. Persists across scene reloads (death/respawn). What a save holds
## is to_dict() / from_dict() (see SaveSystem): add a field to both when you
## add progress, and bump SaveSystem.VERSION when a change makes old saves
## wrong.

signal ability_unlocked(ability: String)
signal player_skin_changed(skin_id: String)
signal flag_set(flag: String)
signal item_received(item: Item)

const FADE_TIME := 0.25
const MENU_SCENE := "res://scenes/main_menu.tscn"
## Player preferences kept between runs (the language, for now).
const SETTINGS_PATH := "user://settings.cfg"

## Abilities you begin a new game with; the rest are unlocked by bosses.
const STARTING_ABILITIES := {
	"double_jump": false,
	"sprint": false,
	"dash": false,
	"wall_jump": false,
}

var abilities := STARTING_ABILITIES.duplicate()

## Progress flags with a fixed name, offered in drop-downs (a LevelButton's
## flags, and later an NPC's dialogue states). Other flags are made as they're
## needed, e.g. "talked_guard" once you've spoken to the guard.
const PROGRESS_FLAGS := ["warden_defeated", "harrier_defeated"]
## What has happened this game, as flags (flag -> true): a boss beaten
## (BossBase.defeat_flag), an NPC spoken to... Anything can check one with
## has_flag(), e.g. an NPC choosing what to say. Wiped by a new game.
var flags := {}
## What you hold: item id -> how many, in the order you got them (see Item).
var items := {}
var _item_defs := {}   # item id -> its Item

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
## The campaign being played (1..SaveSystem.CAMPAIGNS), or 0 when nothing is
## saved (the Test Rooms, the tests).
var campaign := 0
## Seconds played this campaign, counted while a room is running.
var play_time := 0.0
## The room you last rested in, and its bench (a Bench node's name): where
## Continue puts you, and where you get up again if you die in that room.
var rest_room := ""
var rest_bench := ""

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
	# The language picked last time; otherwise Godot's own pick (the computer's
	# language, or English if there's no translation for it).
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK and settings.has_section_key("game", "language"):
		TranslationServer.set_locale(settings.get_value("game", "language"))


# --------------------------------------------------------------- Language ----
# Text is translated from the .po files in localization/ (see its README).

## The languages there are translations for, e.g. ["en"].
func languages() -> PackedStringArray:
	var found := TranslationServer.get_loaded_locales()
	found.sort()
	return found


## The language in use: the translated one closest to the locale (e.g. "en"
## for "en_US"), or the fallback.
func language() -> String:
	var best := ""
	var best_score := 0
	for l in languages():
		var score := TranslationServer.compare_locales(l, TranslationServer.get_locale())
		if score > best_score:
			best = l
			best_score = score
	return best if best != "" else String(ProjectSettings.get_setting("internationalization/locale/fallback", "en"))


## Switches to `locale` and remembers it for next time. Translated text on
## screen updates itself.
func set_language(locale: String) -> void:
	TranslationServer.set_locale(locale)
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)   # keep anything else saved there
	settings.set_value("game", "language", locale)
	settings.save(SETTINGS_PATH)


## The next language after the one in use (round to the first), for the
## menus' Language button.
func next_language() -> void:
	var all := languages()
	if all.is_empty():
		return
	set_language(all[(all.find(language()) + 1) % all.size()])


## An ability's name in the language in use, e.g. "Wall Jump" for wall_jump.
func ability_name(ability: String) -> String:
	return tr("UI_ABILITY_" + ability.to_upper())


## The Language button's text, e.g. "Language: English".
func language_button_text() -> String:
	return tr("UI_MENU_LANGUAGE").format({"language": TranslationServer.get_locale_name(language())})


func has_flag(flag: String) -> bool:
	return flags.has(flag)


## Records that `flag` has happened (once; flag_set fires the first time).
func set_flag(flag: String) -> void:
	if flag == "" or flags.has(flag):
		return
	flags[flag] = true
	flag_set.emit(flag)


# --------------------------------------------------------------- Items ----

## Adds `item` to what you hold and applies it: the ability it grants, and
## (through max_health_bonus() and damage_bonus()) its health or damage. Sets
## got_<id>. False if it's one you already hold and can't have two of.
func give_item(item: Item) -> bool:
	if item == null or (not item.stackable and items.has(item.id)):
		return false
	items[item.id] = items.get(item.id, 0) + 1
	_item_defs[item.id] = item
	set_flag("got_" + item.id)
	if item.grants_ability != "" and not has_ability(item.grants_ability):
		unlock(item.grants_ability)
	item_received.emit(item)
	return true


func has_item(id: String) -> bool:
	return items.has(id)


func item_count(id: String) -> int:
	return items.get(id, 0)


## The items you hold, in the order you got them.
func held_items() -> Array[Item]:
	var held: Array[Item] = []
	for id in items:
		held.append(_item_defs[id])
	return held


## Health your items add to your most, in half-hearts.
func max_health_bonus() -> int:
	var bonus := 0
	for id in items:
		bonus += _item_defs[id].max_health_bonus * items[id]
	return bonus


## What your items add to every hit.
func damage_bonus() -> int:
	var bonus := 0
	for id in items:
		bonus += _item_defs[id].damage_bonus * items[id]
	return bonus


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


## Wipe progress and load the first room (from the main menu), playing
## `in_campaign` (its old saves are deleted; 0 saves nothing).
func start_new_game(in_campaign := 0) -> void:
	if in_campaign > 0:
		SaveSystem.delete_campaign(in_campaign)
	start_at_room(LevelData.FIRST_ROOM)
	campaign = in_campaign


# ------------------------------------------------------------- Saving ----

## Rests at the bench `bench` in `room`: you'll get up there again if you die
## in this room, and the game is saved (an autosave) if a campaign is being
## played. False if saving failed.
func rest_at(room: String, bench: String) -> bool:
	rest_room = room
	rest_bench = bench
	arrived_from = ""   # you're at the bench now, not a door: dying here gets you up at it
	if campaign <= 0:
		return true
	return SaveSystem.write(campaign, SaveSystem.next_auto_slot(campaign), to_dict(), save_header())


## What a save holds: everything about this game but the language and skin.
func to_dict() -> Dictionary:
	var defeated := {}
	for room in bosses_defeated:
		var at: Vector2 = bosses_defeated[room]
		defeated[room] = [at.x, at.y]
	var held := []   # in the order you got them (a file's keys come back sorted)
	for id in items:
		held.append([id, items[id]])
	return {
		"abilities": abilities.duplicate(), "flags": flags.duplicate(), "items": held,
		"bosses_defeated": defeated, "rest_room": rest_room, "rest_bench": rest_bench, "play_time": play_time,
	}


## Puts this game back as `d` (to_dict()) says. Items come back from their
## files, items/<id>.tres.
func from_dict(d: Dictionary) -> void:
	abilities = STARTING_ABILITIES.duplicate()
	var saved_abilities: Dictionary = d.get("abilities", {})
	for ability in saved_abilities:
		if abilities.has(ability):
			abilities[ability] = bool(saved_abilities[ability])
	flags = {}
	var saved_flags: Dictionary = d.get("flags", {})
	for flag in saved_flags:
		flags[flag] = true
	items = {}
	_item_defs = {}
	for entry: Array in d.get("items", []):
		var path := "res://items/%s.tres" % entry[0]
		if ResourceLoader.exists(path):
			items[entry[0]] = int(entry[1])
			_item_defs[entry[0]] = load(path)
	bosses_defeated = {}
	var defeated: Dictionary = d.get("bosses_defeated", {})
	for room in defeated:
		bosses_defeated[room] = Vector2(defeated[room][0], defeated[room][1])
	rest_room = d.get("rest_room", "")
	rest_bench = d.get("rest_bench", "")
	play_time = float(d.get("play_time", 0.0))


## What save lists show besides SaveSystem's own: the room and play time.
func save_header() -> Dictionary:
	return {"room": rest_room, "play_time": play_time}


## Loads a save and goes to the bench it was made at. False (and nothing
## changes) if it can't be read; SaveSystem.load_problem() says why.
func load_game(in_campaign: int, slot: String) -> bool:
	var save := SaveSystem.read(in_campaign, slot)
	if save.is_empty() or not LevelData.ROOMS.has(save.state.get("rest_room", "")):
		return false
	from_dict(save.state)
	campaign = in_campaign
	carried_health = -1
	_fade_to_scene(LevelData.ROOMS[rest_room].scene, "")
	return true


## Loads the newest save there is (the main menu's Continue). False if none.
func continue_game() -> bool:
	var newest := SaveSystem.latest_overall()
	return not newest.is_empty() and load_game(newest.campaign, newest.slot)


func _process(delta: float) -> void:
	if campaign > 0 and not get_tree().paused and get_tree().current_scene is Room:
		play_time += delta


## Wipe progress and load any room at its PlayerStart (level select), with
## the starting abilities plus any in `unlocked`, the flags in `progress` and
## the items in `held` (a LevelButton's abilities, flags and items).
func start_at_room(room: String, unlocked: Array = [], progress: Array = [], held: Array = []) -> void:
	abilities = STARTING_ABILITIES.duplicate()
	for ability in unlocked:
		abilities[ability] = true
	flags = {}
	for flag in progress:
		flags[flag] = true
	items = {}
	_item_defs = {}
	for item in held:
		give_item(item)
	bosses_defeated = {}
	carried_health = -1
	campaign = 0
	play_time = 0.0
	rest_room = ""
	rest_bench = ""
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
