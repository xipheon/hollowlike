@tool
class_name Bench
extends Node2D
## A bench to rest at: on the ground beside it, attack rests (as it talks to
## an NPC, see Player._talk_to_nearby). Resting fills your health, and you'll
## get up here again if you die in this room; in a campaign it saves the game
## too (GameState.rest_at). Place it under a room's Entities with its origin
## on the floor, at its middle. Its name is how saves find it: don't rename
## one once the game's out. Drawn in code.

const SIZE := Vector2(44, 18)          # the seat, px
const LEG := Vector2(4, 10)
const COLOR := Color(0.36, 0.38, 0.44)
const COLOR_LIT := Color(0.56, 0.6, 0.68)
const PROMPT_COLOR := Color(1.0, 0.85, 0.55)
const PROMPT_BOB := 3.0
const PROMPT_BOB_RATE := 3.0
const LIGHT_COLOR := Color(1.0, 0.85, 0.55)
const LIGHT_RADIUS := 72
const LIGHT_ENERGY := 0.5
const LIGHT_HEIGHT := 24.0

## How far from its middle your feet can be to rest, sideways and up or down.
@export var rest_range := 40.0
@export var rest_height := 24.0
## How high over it the prompt floats.
@export var prompt_height := 48.0

var _time := 0.0
var _prompt_shown := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("npc")   # the player rests at it the way it talks to NPCs
	add_child(FlickerLight.make_light(LIGHT_RADIUS, LIGHT_COLOR, LIGHT_ENERGY, LIGHT_HEIGHT))


## Whether `player` can rest here: on the ground, close enough.
func can_talk_to(player: Player) -> bool:
	var feet := player.global_position + Vector2(0, Player.BODY_SIZE.y * 0.5)
	return player.is_on_floor() and absf(feet.x - global_position.x) <= rest_range and absf(feet.y - global_position.y) <= rest_height


## Rests: full health, and the game saved where there's a campaign.
func talk() -> bool:
	var room := _room()
	if room == null:
		return false
	var player := room._player
	player.health = player.max_health
	player.health_changed.emit(player.health, player.max_health)
	var saved := GameState.rest_at(room.room, String(name))
	var key := "UI_HUD_RESTED" if GameState.campaign <= 0 else "UI_HUD_RESTED_SAVED" if saved else "UI_HUD_SAVE_FAILED"
	if room.hud() != null:
		room.hud().show_message(tr(key), 2.0)
	return true


func is_prompt_shown() -> bool:
	return _prompt_shown


func _room() -> Room:
	var node := get_parent()
	while node != null and not node is Room:
		node = node.get_parent()
	return node


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	var room := _room()
	var near := room != null and room._player != null and can_talk_to(room._player)
	if near != _prompt_shown or near:
		_prompt_shown = near
		queue_redraw()


func _draw() -> void:
	var seat := Rect2(Vector2(-SIZE.x * 0.5, -LEG.y - SIZE.y * 0.5), Vector2(SIZE.x, SIZE.y * 0.5))
	var back := Rect2(Vector2(-SIZE.x * 0.5, -LEG.y - SIZE.y), Vector2(SIZE.x, 3))
	for x in [-SIZE.x * 0.5 + 2, SIZE.x * 0.5 - 2 - LEG.x]:
		draw_rect(Rect2(Vector2(x, -LEG.y), LEG), COLOR)
		draw_rect(Rect2(Vector2(x, -LEG.y - SIZE.y), Vector2(LEG.x, SIZE.y * 0.5)), COLOR)
	draw_rect(seat, COLOR)
	draw_rect(Rect2(seat.position, Vector2(seat.size.x, 2)), COLOR_LIT)
	draw_rect(back, COLOR_LIT)
	if _prompt_shown:
		var at := Vector2(0, -prompt_height + sin(_time * PROMPT_BOB_RATE) * PROMPT_BOB)
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -6), at + Vector2(6, 0), at + Vector2(0, 6), at + Vector2(-6, 0)]), PROMPT_COLOR)
	if Engine.is_editor_hint():
		draw_rect(Rect2(-rest_range, -rest_height, rest_range * 2.0, rest_height * 2.0), Color(PROMPT_COLOR, 0.6), false, 1.0)
