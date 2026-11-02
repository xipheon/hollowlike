class_name DeathMenu
extends CanvasLayer
## The death screen: YOU DIED, what dealt the final blow (the player's
## killed_by, e.g. "Impaled on the spikes"), and Respawn (restart the room) or
## Quit to Main Menu. The room opens it a moment after you die; the game
## pauses behind it. Laid out in scenes/ui/death_menu.tscn; edit it there. Its
## text is translation keys (UI_..., in localization/<language>/ui.po).

@onready var _panel: Control = %Panel
@onready var _cause: Label = %Cause
@onready var respawn_button: Button = %RespawnButton
@onready var quit_to_menu_button: Button = %QuitToMenuButton


func _ready() -> void:
	_panel.visible = false   # shown in the editor, hidden until you die
	respawn_button.pressed.connect(_respawn)
	quit_to_menu_button.pressed.connect(func() -> void: GameState.return_to_menu())


func is_open() -> bool:
	return _panel.visible


## Shows the screen, saying what killed you (`blow`: a translation key).
func open(blow: String) -> void:
	_cause.text = blow   # a key: the Label translates it
	_panel.visible = true
	get_tree().paused = true
	respawn_button.grab_focus()


func _respawn() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
