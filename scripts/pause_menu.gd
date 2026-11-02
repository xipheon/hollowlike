class_name PauseMenu
extends CanvasLayer
## Esc / P / Start pauses: Resume, pick a Skin, Quit back to the main menu, or
## Quit the game. Also lists the controls. Won't open while something else
## (the boss intro) already has the game paused. Laid out in
## scenes/ui/pause_menu.tscn; edit it there (the room adds it to itself).
## The skin list is made from PlayerSprite.SKINS: one copy of SkinTemplate,
## the styled button in the scene, per skin.

const DEBUG_CONTROLS_TEXT := "\nDebug: F1 = dash, F2 = wall jump, F3 = kill boss"
const SKIN_MARK := "▶  "   # in front of the skin being worn

@onready var _panel: Control = %Panel
@onready var _main_box: Control = %MainBox
@onready var _skin_box: Control = %SkinBox
@onready var _resume_button: Button = %ResumeButton
@onready var _skin_button: Button = %SkinButton
@onready var _quit_game_button: Button = %QuitGameButton
## Debug mode only, and only in a room with a living boss (see open()).
@onready var _kill_boss_button: Button = %KillBossButton
## One button per PlayerSprite.SKINS entry, keyed by skin id.
var _skin_buttons := {}


func _ready() -> void:
	_panel.visible = false   # shown in the editor, hidden until paused
	_resume_button.pressed.connect(close)
	_skin_button.pressed.connect(show_skins)
	%QuitToMenuButton.pressed.connect(func() -> void: GameState.return_to_menu())
	_quit_game_button.pressed.connect(func() -> void: get_tree().quit())
	_kill_boss_button.pressed.connect(_debug_kill_boss)
	%SkinBackButton.pressed.connect(show_main)
	if GameState.debug_mode:
		%Controls.text += DEBUG_CONTROLS_TEXT

	var template: Button = %SkinTemplate
	for s in PlayerSprite.SKINS:
		var button := template.duplicate() as Button
		button.name = "Skin_" + s.id
		button.pressed.connect(func() -> void: _pick_skin(s.id))
		template.add_sibling(button)
		_skin_buttons[s.id] = button
	template.get_parent().remove_child(template)
	template.queue_free()
	_refresh_skin_marks()


func is_open() -> bool:
	return _panel.visible


func open() -> void:
	if is_open() or get_tree().paused:
		return
	var room := get_parent()
	_kill_boss_button.visible = room.has_method("can_debug_kill_boss") and room.can_debug_kill_boss()
	_panel.visible = true
	get_tree().paused = true
	show_main()
	_resume_button.grab_focus()


func show_main() -> void:
	var from_skins := _skin_box.visible
	_skin_box.visible = false
	_main_box.visible = true
	if from_skins:
		_skin_button.grab_focus()   # cursor back on the button that led here


func show_skins() -> void:
	_main_box.visible = false
	_skin_box.visible = true
	_refresh_skin_marks()
	_skin_buttons[GameState.player_skin].grab_focus()


func _pick_skin(skin_id: String) -> void:
	GameState.set_player_skin(skin_id)
	_refresh_skin_marks()


func _refresh_skin_marks() -> void:
	for s in PlayerSprite.SKINS:
		_skin_buttons[s.id].text = (SKIN_MARK if s.id == GameState.player_skin else "") + s.name


func _debug_kill_boss() -> void:
	close()
	get_parent().debug_kill_boss()


func close() -> void:
	if not is_open():
		return
	_panel.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and _skin_box.visible and event.is_action_pressed("ui_cancel"):
		show_main()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if is_open():
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
