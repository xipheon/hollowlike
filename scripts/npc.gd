@tool
class_name NPC
extends Node2D
## A character you can talk to. Stand within its talk range, on the ground,
## and a speech bubble shows over its head: attack talks to it instead of
## swinging (see Player). What it says depends on how far the game has got:
## its `states` (DialogueState), the first that applies. The conversation is
## shown in the room's DialogueBox, the game paused; it keeps animating.
## Place scenes/npcs/npc.tscn (or a character's own scene made from it) under
## a room's Entities, with its origin at its feet, and set it up in the
## Inspector. In the editor it shows its talk range and name.

const PROMPT_FILL := Color(0.92, 0.93, 0.95)
const PROMPT_INK := Color(0.12, 0.12, 0.16)
const PROMPT_SIZE := Vector2(22, 14)
const PROMPT_BOB := 2.0      # px up and down
const PROMPT_BOB_RATE := 3.0
const EDITOR_COLOR := Color(0.55, 0.85, 1.0, 0.8)

## Names the flags that remember what you've heard from it: talked_<npc_id>_<state>.
@export var npc_id := ""
## Its name, a key in localization/<language>/dialog.po (e.g. NPC_GUARD),
## shown on the dialogue box.
@export var name_key := ""
## What it says, latest in the game first: it uses the first that applies.
@export var states: Array[DialogueState] = []
## How far either side of it you can talk to it from, in px.
@export var talk_range := 56.0
## How far above or below its feet yours can be, in px.
@export var talk_height := 40.0
## Turns to face you when you're near.
@export var faces_player := true
## Where the speech bubble shows: px above its feet.
@export var prompt_height := 60.0

var sprite: AnimatedSprite2D
var _talking := false
var _prompt_shown := false
var _time := 0.0


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		add_to_group("npc")


func _ready() -> void:
	sprite = get_node_or_null("Sprite")
	queue_redraw()


## Whether `player` can talk to it now: in range, on the ground, not already
## talking, and it has something to say.
func can_talk_to(player: Player) -> bool:
	return not _talking and player.is_on_floor() and in_range(player) and DialogueState.pick(states, npc_id) != null


## Whether `player`'s feet are within talk range of its.
func in_range(player: Player) -> bool:
	var feet := player.global_position + Vector2(0, Player.BODY_SIZE.y * 0.5)
	return absf(feet.x - global_position.x) <= talk_range and absf(feet.y - global_position.y) <= talk_height


## Starts a conversation in the room's dialogue box. False if it can't.
func talk() -> bool:
	var box := get_tree().get_first_node_in_group("dialogue_box") as DialogueBox
	var dialogue := DialogueState.pick(states, npc_id)
	if box == null or dialogue == null or _talking:
		return false
	_talking = true
	box.open(dialogue, name_key)
	await box.finished
	DialogueState.heard(states, npc_id)
	_talking = false
	return true


func is_talking() -> bool:
	return _talking


func is_prompt_shown() -> bool:
	return _prompt_shown


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	var player := get_tree().get_first_node_in_group("player") as Player
	var near := player != null and player.visible and not _talking and in_range(player) and DialogueState.pick(states, npc_id) != null
	if near and faces_player and sprite != null:
		sprite.flip_h = player.global_position.x < global_position.x
	if near != _prompt_shown or near:
		_prompt_shown = near
		queue_redraw()


func _draw() -> void:
	if Engine.is_editor_hint():
		_draw_editor()
	elif _prompt_shown:
		_draw_prompt(Vector2(0, -prompt_height + sin(_time * PROMPT_BOB_RATE) * PROMPT_BOB))


## A speech bubble with three dots, its tail pointing down at the NPC.
func _draw_prompt(at: Vector2) -> void:
	var box := Rect2(at - PROMPT_SIZE * 0.5, PROMPT_SIZE)
	draw_rect(box.grow(1), PROMPT_INK)
	draw_rect(box, PROMPT_FILL)
	var tail := PackedVector2Array([at + Vector2(-3, PROMPT_SIZE.y * 0.5), at + Vector2(3, PROMPT_SIZE.y * 0.5), at + Vector2(0, PROMPT_SIZE.y * 0.5 + 4)])
	draw_colored_polygon(tail, PROMPT_FILL)
	for i in 3:
		draw_rect(Rect2(at + Vector2(-6 + i * 5, -1), Vector2(2, 2)), PROMPT_INK)


## In the editor: its talk range, its name, and a stand-in figure if it has no sprite yet.
func _draw_editor() -> void:
	draw_rect(Rect2(-talk_range, -talk_height, talk_range * 2.0, talk_height * 2.0), EDITOR_COLOR, false, 1.0)
	if sprite == null or sprite.sprite_frames == null:
		draw_rect(Rect2(-10, -44, 20, 44), Color(EDITOR_COLOR, 0.35))
	var label := name_key if name_key != "" else "NPC"
	draw_string(ThemeDB.fallback_font, Vector2(-talk_range, -prompt_height), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, EDITOR_COLOR)
	draw_line(Vector2(-4, 0), Vector2(4, 0), EDITOR_COLOR, 1.0)


func _validate_property(property: Dictionary) -> void:
	if property.name in ["talk_range", "talk_height", "prompt_height"]:
		queue_redraw.call_deferred()
