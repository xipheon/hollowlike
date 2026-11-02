@tool
class_name DialogueState
extends Resource
## What an NPC says at one point in the game: when it applies (the progress
## flags it needs and the ones it mustn't have; see GameState.flags), what
## it says the first time you talk to it then, and what it says after that.
## An NPC lists its states, latest in the game first, and uses the first that
## applies (pick()), e.g. after the Harrier, after the Warden, before either.

## A short name, unique among the NPC's states (e.g. after_warden). Hearing
## its first talk sets the flag talked_<npc>_<name>, so you hear it once.
@export var name := ""
## Flags that must all be set, e.g. warden_defeated.
@export var requires: Array[String] = []
## Flags that must not be set.
@export var forbids: Array[String] = []
## The first time you talk in this state.
@export var first_talk: Dialogue
## Every time after. Empty: the first talk again.
@export var repeat_talk: Dialogue


## Whether its flags are as it needs.
func applies() -> bool:
	return requires.all(func(f): return GameState.has_flag(f)) and not forbids.any(func(f): return GameState.has_flag(f))


## The flag set once its first talk has been heard, for an NPC called `npc`.
func heard_flag(npc: String) -> String:
	return "talked_%s_%s" % [npc, name]


## What the NPC called `npc` says now, from its `states` (the first that
## applies): its first talk, or its repeat talk once that's been heard. Null
## if no state applies. Doesn't mark anything heard: call heard() once it has.
static func pick(states: Array[DialogueState], npc: String) -> Dialogue:
	for state in states:
		if state != null and state.applies():
			if GameState.has_flag(state.heard_flag(npc)) and state.repeat_talk != null:
				return state.repeat_talk
			return state.first_talk
	return null


## Marks the state `npc` is in as heard, so it says its repeat talk next time.
static func heard(states: Array[DialogueState], npc: String) -> void:
	for state in states:
		if state != null and state.applies():
			GameState.set_flag(state.heard_flag(npc))
			return


## The flag drop-downs: GameState's progress flags.
func _validate_property(property: Dictionary) -> void:
	if property.name in ["requires", "forbids"]:
		var progress: Array = load("res://scripts/game_state.gd").get_script_constant_map()["PROGRESS_FLAGS"]
		property.hint = PROPERTY_HINT_TYPE_STRING
		property.hint_string = "%d/%d:%s" % [TYPE_STRING, PROPERTY_HINT_ENUM, ",".join(progress)]
