@tool
class_name LevelButton
extends Button
## A Level Select entry on the main menu (scenes/main_menu.tscn): pressing it
## starts a fresh game in `room` at its PlayerStart, with the starting
## abilities plus `abilities`. Add, remove, reorder and label them in the
## editor; only the rooms you add are listed.

## The room it starts (an id from LevelData.ROOMS).
@export var room := ""
## Abilities to start with on top of GameState.STARTING_ABILITIES, e.g. dash
## for a room past the Warden.
@export var abilities: Array[String] = []


func _ready() -> void:
	if not Engine.is_editor_hint():
		pressed.connect(func() -> void: GameState.start_at_room(room, abilities))


## Drop-downs: the rooms in LevelData.ROOMS, and the abilities GameState knows.
func _validate_property(property: Dictionary) -> void:
	if property.name == "room":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(LevelData.ROOMS.keys())
	elif property.name == "abilities":
		var known: Dictionary = load("res://scripts/game_state.gd").get_script_constant_map()["STARTING_ABILITIES"]
		property.hint = PROPERTY_HINT_TYPE_STRING
		property.hint_string = "%d/%d:%s" % [TYPE_STRING, PROPERTY_HINT_ENUM, ",".join(known.keys())]
