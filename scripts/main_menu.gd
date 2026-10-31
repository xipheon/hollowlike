extends Control
## Title screen: Start a new game, pick a level, or Quit. Built in code like the HUD.

var start_button: Button
var level_select_button: Button
## Level select: one button per room in LevelData.ROOMS, keyed by room id.
var level_buttons := {}
var back_button: Button

var _main_box: VBoxContainer
var _level_box: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color(0.07, 0.08, 0.11)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_main_box = _add_box(center, "HOLLOWLIKE", 52)
	start_button = _add_button(_main_box, "Start", func() -> void: GameState.start_new_game())
	level_select_button = _add_button(_main_box, "Level Select", show_level_select)
	_add_button(_main_box, "Quit", func() -> void: get_tree().quit())

	_level_box = _add_box(center, "LEVEL SELECT", 40)
	for room in LevelData.ROOMS:
		level_buttons[room] = _add_button(_level_box, String(room).capitalize(),
				func() -> void: GameState.start_at_room(room))
	back_button = _add_button(_level_box, "Back", _back_to_main)

	var hint := Label.new()
	hint.text = "Arrows / Enter or d-pad / A to choose   ·   Esc / Start pauses in game"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.5)
	add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -50
	hint.offset_bottom = -26

	show_main()


func _add_box(parent: Control, title_text: String, font_size: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	parent.add_child(box)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", font_size)
	box.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	box.add_child(spacer)
	return box


func _add_button(box: Container, text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 44)
	button.pressed.connect(on_press)
	box.add_child(button)
	return button


func show_main() -> void:
	_level_box.visible = false
	_main_box.visible = true
	start_button.grab_focus()


func show_level_select() -> void:
	_main_box.visible = false
	_level_box.visible = true
	level_buttons["start"].grab_focus()


func _back_to_main() -> void:
	show_main()
	level_select_button.grab_focus()   # cursor back on the button that led here


func _unhandled_input(event: InputEvent) -> void:
	if _level_box.visible and event.is_action_pressed("ui_cancel"):
		_back_to_main()
		get_viewport().set_input_as_handled()
