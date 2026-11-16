class_name IntroCard
extends CanvasLayer
## The welcome card a new game opens with, over the first room: a few words on
## where you are and the controls. The game is paused while it's up; attack,
## jump or accept closes it. Shown once a game (SEEN_FLAG). Laid out in
## scenes/ui/intro_card.tscn; edit it there. The room adds it (Room._ready).

## Emitted once the card has closed and the game carries on.
signal finished

## Set when the card is shown, so it isn't again this game.
const SEEN_FLAG := "intro_seen"
const CLOSE_ACTIONS := ["attack", "jump", "ui_accept"]
const FADE_TIME := 0.25

@onready var _panel: Control = %Panel

var _closing := false


func _ready() -> void:
	add_to_group("intro_card")
	GameState.set_flag(SEEN_FLAG)
	get_tree().paused = true
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, FADE_TIME)


func is_open() -> bool:
	return not _closing


func close() -> void:
	if _closing:
		return
	_closing = true
	await create_tween().tween_property(_panel, "modulate:a", 0.0, FADE_TIME).finished
	# Let the press that closed it go by before the game runs again, so it
	# isn't also taken as a swing or a jump.
	await get_tree().physics_frame
	await get_tree().physics_frame
	get_tree().paused = false
	finished.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	for action in CLOSE_ACTIONS:
		if event.is_action_pressed(action) and not event.is_echo():
			get_viewport().set_input_as_handled()
			close()
			return
