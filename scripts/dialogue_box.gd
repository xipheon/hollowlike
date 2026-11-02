class_name DialogueBox
extends CanvasLayer
## The box at the bottom of the screen a conversation is shown in (see NPC):
## the speaker's name, and the line typed out a few letters at a time. Attack
## shows the rest of a line being typed, then goes on to the next; after the
## last, the box closes. The game is paused while it's open, but the box (and
## the NPC, see npc.tscn) keep animating. A line that gives an ability gives
## it as it's shown. Laid out in scenes/ui/dialogue_box.tscn; edit it there.

## Emitted once the box has closed and the game carries on.
signal finished

## How fast lines type out.
@export var chars_per_second := 45.0
## How fast the "more" marker blinks, times a second, once a line is all shown.
@export var more_blink_rate := 2.0

@onready var _panel: Control = %Panel
@onready var _name: Label = %Name
@onready var _text: Label = %Text
@onready var _more: Control = %More

var _lines: Array[DialogueLine] = []
var _index := -1
var _speaker := ""   # the NPC's name key, for lines with no speaker of their own
var _typed := 0.0    # characters shown so far
var _blink := 0.0


func _ready() -> void:
	add_to_group("dialogue_box")
	_panel.visible = false   # shown in the editor, hidden until a conversation
	set_process(false)


func is_open() -> bool:
	return _panel.visible


## Shows `dialogue` from its first line; `speaker` is the name key for lines
## with none of their own. Pauses the game until it's done (see finished).
func open(dialogue: Dialogue, speaker: String) -> void:
	if dialogue == null or dialogue.lines.is_empty():
		finished.emit.call_deferred()
		return
	_lines = dialogue.lines
	_speaker = speaker
	_panel.visible = true
	get_tree().paused = true
	set_process(true)
	_show(0)


## The line being shown (its index in the conversation), -1 when closed.
func line_index() -> int:
	return _index if is_open() else -1


## Whether the line is still typing out.
func is_typing() -> bool:
	return _text.visible_characters >= 0 and _text.visible_characters < _text.get_total_character_count()


## Attack: the rest of the line, else the next line, else close.
func advance() -> void:
	if is_typing():
		_text.visible_characters = -1
	elif _index + 1 < _lines.size():
		_show(_index + 1)
	else:
		_close()


func _show(index: int) -> void:
	_index = index
	var line := _lines[index]
	_name.text = tr(line.speaker if line.speaker != "" else _speaker)
	_text.text = tr(line.text)
	_typed = 0.0
	_text.visible_characters = 0
	_blink = 0.0
	if line.give_ability != "" and not GameState.has_ability(line.give_ability):
		GameState.unlock(line.give_ability)


func _process(delta: float) -> void:
	if is_typing():
		_typed += chars_per_second * delta
		_text.visible_characters = int(_typed)
		if _text.visible_characters >= _text.get_total_character_count():
			_text.visible_characters = -1
	_blink += delta
	_more.visible = not is_typing() and fmod(_blink * more_blink_rate, 1.0) < 0.6


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("attack") and not event.is_echo():
		get_viewport().set_input_as_handled()
		advance()


func _close() -> void:
	_panel.visible = false
	_index = -1
	set_process(false)
	# Let the press that closed it go by before the game runs again, so it
	# isn't also taken as a swing.
	await get_tree().physics_frame
	await get_tree().physics_frame
	get_tree().paused = false
	finished.emit()
