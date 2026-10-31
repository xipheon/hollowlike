class_name PauseMenu
extends CanvasLayer
## Esc / P / Start pauses: Resume, or Quit back to the main menu.
## Won't open while something else (the boss intro) already has the game paused.

var _panel: Control
var _resume_button: Button


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
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)

	_resume_button = _add_button(box, "Resume", close)
	_add_button(box, "Quit to Menu", func() -> void: GameState.return_to_menu())

	_panel.visible = false


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
	_panel.visible = true
	get_tree().paused = true
	_resume_button.grab_focus()


func close() -> void:
	if not is_open():
		return
	_panel.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if is_open():
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
