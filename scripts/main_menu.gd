extends Control
## Title screen, over a view of the room a new game starts in (the Backdrop):
## Continue from your newest save, start a New Game (in one of the
## SaveSystem.CAMPAIGNS; a used one asks again before its saves go), Load a
## save, switch Language, or Quit. Continue and Load only show once there's a
## save. Laid out in
## scenes/main_menu.tscn; edit it there (everything you see is under UI, a
## layer of its own so the room's dimming doesn't reach it). Its text is
## translation keys (UI_..., in localization/<language>/ui.po).
## Test Rooms lists the LevelButtons under Levels in that scene: add, remove,
## reorder and label them there, and set which room each starts and with which
## abilities. It's a debug tool: it only shows in debug mode (the editor,
## debug exports), not in release exports.

@onready var continue_button: Button = %ContinueButton
@onready var start_button: Button = %StartButton
@onready var load_button: Button = %LoadButton
@onready var level_select_button: Button = %LevelSelectButton
@onready var language_button: Button = %LanguageButton
@onready var quit_button: Button = %QuitButton
@onready var back_button: Button = %BackButton
@onready var _main_box: Control = %MainBox
@onready var _level_box: Control = %LevelBox
@onready var _levels: Control = %Levels
@onready var _campaign_box: Control = %CampaignBox
@onready var _campaigns: Control = %Campaigns
@onready var _load_box: Control = %LoadBox
@onready var _saves: Control = %Saves
@onready var _load_problem: Label = %LoadProblem

## The Level Select's buttons, keyed by the room each starts.
var level_buttons := {}
## New Game's buttons, one per campaign (campaign 1 first), and the campaign
## that's been pressed once, waiting for a second press to start over.
var campaign_buttons: Array[Button] = []
var _confirming := 0
## Load's buttons, one per save: [button, campaign, slot].
var save_buttons: Array = []


func _ready() -> void:
	_add_backdrop()
	continue_button.pressed.connect(_on_continue)
	start_button.pressed.connect(show_campaigns)
	load_button.pressed.connect(show_load)
	%CampaignBackButton.pressed.connect(_back_to_main.bind(start_button))
	%LoadBackButton.pressed.connect(_back_to_main.bind(load_button))
	var has_save := not SaveSystem.latest_overall().is_empty()
	continue_button.visible = has_save
	load_button.visible = SaveSystem.any_used()
	level_select_button.pressed.connect(show_level_select)
	level_select_button.visible = GameState.debug_mode
	language_button.pressed.connect(GameState.next_language)
	language_button.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED   # its text is built here
	language_button.text = GameState.language_button_text()
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	back_button.pressed.connect(_back_to_main.bind(level_select_button))
	for button in _levels.get_children():
		if button is LevelButton:
			level_buttons[button.room] = button
	show_main()


## The first room, as a picture behind the menu (Room.backdrop), over the
## plain Background and under the UI layer.
func _add_backdrop() -> void:
	var room: Room = load(LevelData.ROOMS[LevelData.FIRST_ROOM].scene).instantiate()
	room.name = "Backdrop"
	room.backdrop = true
	add_child(room)
	move_child(room, $Background.get_index() + 1)


## The language changed: text built here follows (the rest translates itself).
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		language_button.text = GameState.language_button_text()


func show_main() -> void:
	_level_box.visible = false
	_campaign_box.visible = false
	_load_box.visible = false
	_main_box.visible = true
	(continue_button if continue_button.visible else start_button).grab_focus()


## New Game: a button per campaign, saying whether it's empty.
func show_campaigns() -> void:
	_main_box.visible = false
	_campaign_box.visible = true
	_confirming = 0
	for button in campaign_buttons:
		button.queue_free()
	campaign_buttons.clear()
	for n in range(1, SaveSystem.CAMPAIGNS + 1):
		var button := _make_button()
		button.pressed.connect(_on_campaign_pressed.bind(n))
		_campaigns.add_child(button)
		campaign_buttons.append(button)
	_label_campaigns()
	campaign_buttons[0].grab_focus()


func _label_campaigns() -> void:
	for i in campaign_buttons.size():
		var n := i + 1
		var newest := SaveSystem.latest(n)
		var key := "UI_CAMPAIGN_EMPTY" if newest.is_empty() else "UI_CAMPAIGN_CONFIRM" if _confirming == n else "UI_CAMPAIGN_USED"
		var time := "" if newest.is_empty() else SaveSystem.time_text(float(newest.header.get("play_time", 0.0)))
		campaign_buttons[i].text = tr(key).format({"n": n, "time": time})


## An empty campaign starts at once; a used one asks for a second press.
func _on_campaign_pressed(n: int) -> void:
	if SaveSystem.is_used(n) and _confirming != n:
		_confirming = n
		_label_campaigns()
		return
	GameState.start_new_game(n)


## Continue; if the newest save can't be loaded, says why under the title.
func _on_continue() -> void:
	if GameState.continue_game():
		return
	%MenuProblem.text = SaveSystem.load_problem()
	%MenuProblem.visible = true


## Load: every save, campaign by campaign, each a button (then the debug
## saves, in debug builds). One that can't be loaded says why when pressed.
func show_load() -> void:
	_main_box.visible = false
	_load_box.visible = true
	_load_problem.text = ""
	for entry in save_buttons:
		entry[0].queue_free()
	save_buttons.clear()
	for n in range(1, SaveSystem.CAMPAIGNS + 1):
		for save in SaveSystem.saves(n):
			var button := _make_button()
			button.text = SaveSystem.describe(n, save)
			button.pressed.connect(_on_save_pressed.bind(n, save.slot))
			_saves.add_child(button)
			save_buttons.append([button, n, save.slot])
	for save in SaveSystem.debug_saves():
		var button := _make_button()
		button.text = SaveSystem.slot_name(save.slot)
		button.pressed.connect(_on_save_pressed.bind(1, save.slot))
		_saves.add_child(button)
		save_buttons.append([button, 1, save.slot])
	%LoadEmpty.visible = save_buttons.is_empty()
	(save_buttons[0][0] if not save_buttons.is_empty() else %LoadBackButton).grab_focus()


func _on_save_pressed(n: int, slot: String) -> void:
	if not GameState.load_game(n, slot):
		_load_problem.text = SaveSystem.load_problem()


## A list button, sized like the menu's own; its text is set by the caller.
func _make_button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(420, 44)
	button.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED   # its text is built here
	return button


func show_level_select() -> void:
	if not GameState.debug_mode:
		return
	_main_box.visible = false
	_level_box.visible = true
	var first: Button = _levels.get_child(0) if _levels.get_child_count() > 0 else back_button
	first.grab_focus()


func _back_to_main(from: Button) -> void:
	show_main()
	from.grab_focus()   # cursor back on the button that led here


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	for pair in [[_level_box, level_select_button], [_campaign_box, start_button], [_load_box, load_button]]:
		if pair[0].visible:
			_back_to_main(pair[1])
			get_viewport().set_input_as_handled()
			return
