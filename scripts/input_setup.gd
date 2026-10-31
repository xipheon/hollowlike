extends Node
## Autoload. Registers input actions in code so the project works out of the
## box. Once you want to rebind via Project Settings, remove this autoload
## and define the actions there instead.

const KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE, KEY_Z],
	"attack": [KEY_J, KEY_X],
	"dash": [KEY_K, KEY_C, KEY_SHIFT],
	"restart": [KEY_R],
	"pause": [KEY_ESCAPE, KEY_P],
}

const PAD_BUTTONS := {
	"jump": [JOY_BUTTON_A],
	"attack": [JOY_BUTTON_X],
	"dash": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_B],
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"move_up": [JOY_BUTTON_DPAD_UP],
	"move_down": [JOY_BUTTON_DPAD_DOWN],
	"pause": [JOY_BUTTON_START],
}

const PAD_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	"move_down": [JOY_AXIS_LEFT_Y, 1.0],
}

func _ready() -> void:
	for action in KEYS:
		_ensure(action)
		for keycode in KEYS[action]:
			var key_event := InputEventKey.new()
			key_event.physical_keycode = keycode
			InputMap.action_add_event(action, key_event)
	for action in PAD_BUTTONS:
		_ensure(action)
		for button in PAD_BUTTONS[action]:
			var button_event := InputEventJoypadButton.new()
			button_event.button_index = button
			InputMap.action_add_event(action, button_event)
	for action in PAD_AXES:
		_ensure(action)
		var axis_event := InputEventJoypadMotion.new()
		axis_event.axis = PAD_AXES[action][0]
		axis_event.axis_value = PAD_AXES[action][1]
		InputMap.action_add_event(action, axis_event)

func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.35)
