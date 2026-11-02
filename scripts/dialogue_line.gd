@tool
class_name DialogueLine
extends Resource
## One line of a conversation (see Dialogue): who says it and what, as
## translation keys in localization/<language>/dialog.po, and optionally
## something it gives you as it's shown.

## Who says it: a name key, e.g. NPC_GUARD. Empty: the NPC you're talking to.
@export var speaker := ""
## What's said: a line key, e.g. DLG_GUARD_HELLO_1.
@export var text := ""
## An ability it gives you as the line is shown (e.g. dash). Empty: none.
@export var give_ability := ""


## The ability drop-down: the abilities GameState knows.
func _validate_property(property: Dictionary) -> void:
	if property.name == "give_ability":
		var known: Dictionary = load("res://scripts/game_state.gd").get_script_constant_map()["STARTING_ABILITIES"]
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = "," + ",".join(known.keys())
