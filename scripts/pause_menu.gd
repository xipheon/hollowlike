class_name PauseMenu
extends CanvasLayer
## Esc / P / Start pauses: Resume, pick a Skin, Quit back to the main menu, or
## Quit the game. Also lists the controls. Won't open while something else
## (the boss intro) already has the game paused.

const CONTROLS_TEXT := "Move: A/D or arrows · left stick / d-pad\n" \
	+ "Jump: Space/Z · A   (hold = higher)\n" \
	+ "Attack: J/X · X   (hold Up / Down-in-air to aim)\n" \
	+ "Sprint: Shift · LT   (uses stamina)\n" \
	+ "Dash: K/C · RB/B   (uses stamina)\n" \
	+ "Pause: Esc/P · Start      Restart: R"
const DEBUG_CONTROLS_TEXT := "\nDebug: F1 = dash, F2 = wall jump, F3 = kill boss"

const SKIN_MARK := "▶  "   # in front of the skin being worn

var _panel: Control
var _main_box: VBoxContainer
var _skin_box: VBoxContainer
var _resume_button: Button
var _skin_button: Button
var _quit_game_button: Button
var _kill_boss_button: Button
## One button per PlayerSprite.SKINS entry, keyed by skin id.
var _skin_buttons := {}


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS

	_panel = ColorRect.new()
	(_panel as ColorRect).color = Color(0, 0, 0, 0.6)
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)
	var box := _add_box(center, "PAUSED")
	_main_box = box

	_resume_button = _add_button(box, "Resume", close)
	_skin_button = _add_button(box, "Skin", show_skins)
	_add_button(box, "Quit to Menu", func() -> void: GameState.return_to_menu())
	_quit_game_button = _add_button(box, "Quit Game", func() -> void: get_tree().quit())
	# Debug mode only, and only in a room with a living boss (see open()).
	_kill_boss_button = _add_button(box, "Debug: Kill Boss", _debug_kill_boss)
	_kill_boss_button.modulate = Color(1.0, 0.6, 0.6)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	box.add_child(spacer)

	var controls := Label.new()
	controls.text = CONTROLS_TEXT + (DEBUG_CONTROLS_TEXT if GameState.debug_mode else "")
	controls.add_theme_font_size_override("font_size", 13)
	controls.modulate = Color(1, 1, 1, 0.6)
	box.add_child(controls)

	_skin_box = _add_box(center, "SKIN")
	for s in PlayerSprite.SKINS:
		_skin_buttons[s.id] = _add_button(_skin_box, s.name, func() -> void: _pick_skin(s.id))
	_add_button(_skin_box, "Back", show_main)
	_skin_box.visible = false

	_panel.visible = false


func _add_box(parent: Control, title_text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	parent.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)
	return box


func _add_button(box: Container, text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 40)
	button.pressed.connect(on_press)
	box.add_child(button)
	return button


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
