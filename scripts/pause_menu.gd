class_name PauseMenu
extends CanvasLayer
## Esc / P / Start pauses: Resume, look through your Inventory, pick a Skin,
## switch Language, Quit back to the main menu, or Quit the game. Also lists the controls. Won't open while
## something else (the boss intro) already has the game paused. Laid out in
## scenes/ui/pause_menu.tscn; edit it there (the room adds it to itself). Its
## text is translation keys (UI_..., in localization/<language>/ui.po).
## The skin list is made from PlayerSprite.SKINS: one copy of SkinTemplate,
## the styled button in the scene, per skin. The inventory is made the same
## way from what you hold (GameState.held_items()), one ItemTemplate per item,
## each saying what it does below the list when highlighted.

const SKIN_MARK := "▶  "   # in front of the skin being worn

@onready var _panel: Control = %Panel
@onready var _main_box: Control = %MainBox
@onready var _skin_box: Control = %SkinBox
@onready var _inventory_box: Control = %InventoryBox
@onready var _inventory_button: Button = %InventoryButton
@onready var _items: Control = %Items
@onready var _item_description: Label = %ItemDescription
@onready var _inventory_empty: Control = %InventoryEmpty
@onready var _resume_button: Button = %ResumeButton
@onready var _skin_button: Button = %SkinButton
@onready var _language_button: Button = %LanguageButton
@onready var _quit_game_button: Button = %QuitGameButton
## Debug mode only, and only in a room with a living boss (see open()).
@onready var _kill_boss_button: Button = %KillBossButton
## One button per PlayerSprite.SKINS entry, keyed by skin id.
var _skin_buttons := {}
## One button per item held, in the order you got them (rebuilt each time the
## inventory opens), and the template they're copied from.
var item_buttons: Array[Button] = []
var _item_template: Button


func _ready() -> void:
	_panel.visible = false   # shown in the editor, hidden until paused
	_resume_button.pressed.connect(close)
	_skin_button.pressed.connect(show_skins)
	%QuitToMenuButton.pressed.connect(func() -> void: GameState.return_to_menu())
	_quit_game_button.pressed.connect(func() -> void: get_tree().quit())
	_kill_boss_button.pressed.connect(_debug_kill_boss)
	%SkinBackButton.pressed.connect(show_main)
	_inventory_button.pressed.connect(show_inventory)
	%InventoryBackButton.pressed.connect(show_main)
	_item_template = %ItemTemplate
	_items.remove_child(_item_template)
	%DebugControls.visible = GameState.debug_mode
	_language_button.pressed.connect(GameState.next_language)
	_language_button.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED   # its text is built here
	_language_button.text = GameState.language_button_text()

	var template: Button = %SkinTemplate
	for s in PlayerSprite.SKINS:
		var button := template.duplicate() as Button
		button.name = "Skin_" + s.id
		button.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED   # translated in _refresh_skin_marks()
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
	var from_inventory := _inventory_box.visible
	_skin_box.visible = false
	_inventory_box.visible = false
	_main_box.visible = true
	if from_skins:
		_skin_button.grab_focus()   # cursor back on the button that led here
	elif from_inventory:
		_inventory_button.grab_focus()


## The inventory: a button per item you hold (name, and how many if more than
## one), and what the highlighted one does.
func show_inventory() -> void:
	_main_box.visible = false
	_inventory_box.visible = true
	for button in item_buttons:
		button.queue_free()
	item_buttons.clear()
	for item in GameState.held_items():
		var button := _item_template.duplicate() as Button
		button.icon = item.icon
		button.text = _item_label(item)
		button.focus_entered.connect(func() -> void: _item_description.text = tr(item.description_key))
		_items.add_child(button)
		item_buttons.append(button)
	_inventory_empty.visible = item_buttons.is_empty()
	_item_description.text = ""
	if item_buttons.is_empty():
		%InventoryBackButton.grab_focus()
	else:
		item_buttons[0].grab_focus()


func _item_label(item: Item) -> String:
	var count := GameState.item_count(item.id)
	return tr(item.name_key) if count == 1 else tr("UI_INVENTORY_COUNT").format({"item": tr(item.name_key), "count": count})


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
		_skin_buttons[s.id].text = (SKIN_MARK if s.id == GameState.player_skin else "") + tr(s.name)


## The language changed: text built here follows (the rest translates itself).
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_language_button.text = GameState.language_button_text()
		_refresh_skin_marks()


func _debug_kill_boss() -> void:
	close()
	get_parent().debug_kill_boss()


func close() -> void:
	if not is_open():
		return
	_panel.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and (_skin_box.visible or _inventory_box.visible) and event.is_action_pressed("ui_cancel"):
		show_main()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if is_open():
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if is_instance_valid(_item_template):
		_item_template.free()   # kept out of the tree as the copy to make item buttons from
