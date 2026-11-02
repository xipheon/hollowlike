@tool
class_name Item
extends Resource
## Something you can hold: dropped by a boss (BossBase.rewards, picked up as an
## ItemPickup), given in a conversation (DialogueLine.give_item), or held from
## the start of a Level Select room. GameState.give_item() adds it and applies
## what it does. Each item is a file in items/; its icon is in art/items/
## (tools/make_item_icons.gd), its name and description in
## localization/<language>/ui.po.

## Unique among items, e.g. dash_boots. Holding it sets the flag got_<id>.
@export var id := ""
## Its name, a key (e.g. UI_ITEM_DASH_BOOTS).
@export var name_key := ""
## What it does, a key, shown in the inventory and when you get it.
@export var description_key := ""
@export var icon: Texture2D
## Several can be held (Heart Containers); otherwise you only get it once.
@export var stackable := false
## An ability it gives (e.g. dash). Empty: none.
@export var grants_ability := ""
## Added to your most health, in half-hearts (2 = a whole heart).
@export var max_health_bonus := 0
## Added to every hit of your attack.
@export var damage_bonus := 0


## The ability drop-down: the abilities GameState knows.
func _validate_property(property: Dictionary) -> void:
	if property.name == "grants_ability":
		var known: Dictionary = load("res://scripts/game_state.gd").get_script_constant_map()["STARTING_ABILITIES"]
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = "," + ",".join(known.keys())
