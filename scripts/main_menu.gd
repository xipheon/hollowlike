extends Control
## Title screen: Start a new game, pick a level, switch Language, or Quit.
## Laid out in scenes/main_menu.tscn; edit it there. Its text is translation
## keys (UI_..., in localization/<language>/ui.po).
## Level Select lists the LevelButtons under Levels in that scene: add,
## remove, reorder and label them there, and set which room each starts and
## with which abilities. It's a debug tool: it only shows in debug mode (the
## editor, debug exports), not in release exports.

@onready var start_button: Button = %StartButton
@onready var level_select_button: Button = %LevelSelectButton
@onready var language_button: Button = %LanguageButton
@onready var quit_button: Button = %QuitButton
@onready var back_button: Button = %BackButton
@onready var _main_box: Control = %MainBox
@onready var _level_box: Control = %LevelBox
@onready var _levels: Control = %Levels

## The Level Select's buttons, keyed by the room each starts.
var level_buttons := {}


func _ready() -> void:
	start_button.pressed.connect(func() -> void: GameState.start_new_game())
	level_select_button.pressed.connect(show_level_select)
	level_select_button.visible = GameState.debug_mode
	language_button.pressed.connect(GameState.next_language)
	language_button.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED   # its text is built here
	language_button.text = GameState.language_button_text()
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	back_button.pressed.connect(_back_to_main)
	for button in _levels.get_children():
		if button is LevelButton:
			level_buttons[button.room] = button
	show_main()


## The language changed: text built here follows (the rest translates itself).
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		language_button.text = GameState.language_button_text()


func show_main() -> void:
	_level_box.visible = false
	_main_box.visible = true
	start_button.grab_focus()


func show_level_select() -> void:
	if not GameState.debug_mode:
		return
	_main_box.visible = false
	_level_box.visible = true
	var first: Button = _levels.get_child(0) if _levels.get_child_count() > 0 else back_button
	first.grab_focus()


func _back_to_main() -> void:
	show_main()
	level_select_button.grab_focus()   # cursor back on the button that led here


func _unhandled_input(event: InputEvent) -> void:
	if _level_box.visible and event.is_action_pressed("ui_cancel"):
		_back_to_main()
		get_viewport().set_input_as_handled()
