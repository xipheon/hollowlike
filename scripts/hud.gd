class_name HUD
extends CanvasLayer
## Placeholder HUD: health boxes, ability list, pop-up messages.

# Health is in half-hearts: one box per 2 points, half-filled for an odd point.
class HealthBar extends Control:
	var current := 10
	var maximum := 10
	func _draw() -> void:
		var color := Color(0.9, 0.95, 1.0)
		for i in ceili(maximum / 2.0):
			var r := Rect2(i * 30, 0, 24, 24)
			var fill := clampi(current - i * 2, 0, 2)
			if fill > 0:
				draw_rect(Rect2(r.position, Vector2(r.size.x * fill / 2.0, r.size.y)), color)
			if fill < 2:
				draw_rect(r, Color(color, 0.5), false, 2.0)

class StaminaBar extends Control:
	var current := 1.0
	var maximum := 1.0
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))
		var fill := size.x * current / maxf(maximum, 1.0)
		draw_rect(Rect2(1, 1, maxf(fill - 2, 0), size.y - 2), Color(0.45, 0.85, 0.4))

class BossBar extends Control:
	var current := 1
	var maximum := 1
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
		var fill := size.x * float(current) / float(maxi(maximum, 1))
		draw_rect(Rect2(2, 2, maxf(fill - 4, 0), size.y - 4), Color(0.85, 0.25, 0.25))

const SCREEN_WIDTH := 960.0
const BOSS_TITLE_FONT_SIZE := 44
const BOSS_TITLE_HEIGHT := 60.0
const BOSS_TITLE_REVEAL_Y := 200.0   # text centre while revealed
const BOSS_TITLE_DOCKED_Y := 22.0    # text centre above the health bar
const BOSS_TITLE_DOCKED_SCALE := 0.4

var _health_bar: HealthBar
var _stamina_bar: StaminaBar
var _boss_bar: BossBar
var _boss_label: Label
var _coins_label: Label
var _abilities_label: Label
var _message_label: Label
var _message_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # animates during the paused boss intro
	_health_bar = HealthBar.new()
	_health_bar.position = Vector2(20, 20)
	add_child(_health_bar)
	_stamina_bar = StaminaBar.new()
	_stamina_bar.position = Vector2(20, 52)
	_stamina_bar.size = Vector2(144, 8)   # as wide as five hearts
	add_child(_stamina_bar)

	_abilities_label = _make_label(Vector2(20, 66), 14)

	_message_label = _make_label(Vector2(0, 150), 28)
	_message_label.size = Vector2(960, 40)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.modulate.a = 0.0

	_coins_label = _make_label(Vector2(20, 88), 14)
	_coins_label.modulate = Color(1.0, 0.85, 0.3)
	GameState.coins_changed.connect(_on_coins_changed)
	_on_coins_changed(GameState.coins)

	# Boss title: drawn big, then scaled down to sit above the bar.
	_boss_label = _make_label(Vector2.ZERO, BOSS_TITLE_FONT_SIZE)
	_boss_label.size = Vector2(SCREEN_WIDTH, BOSS_TITLE_HEIGHT)
	_boss_label.pivot_offset = _boss_label.size * 0.5
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_bar = BossBar.new()
	_boss_bar.position = Vector2(230, 36)
	_boss_bar.size = Vector2(500, 14)
	add_child(_boss_bar)
	hide_boss()

	GameState.ability_unlocked.connect(_on_ability_unlocked)
	_refresh_abilities()


func _make_label(pos: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label


func bind_player(player: Player) -> void:
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, player.max_health)
	player.stamina_changed.connect(_on_stamina_changed)
	_on_stamina_changed(player.stamina, player.max_stamina)


func show_boss(boss_name: String, current: int, maximum: int) -> void:
	_boss_label.text = boss_name
	_place_boss_title(BOSS_TITLE_DOCKED_Y, BOSS_TITLE_DOCKED_SCALE)
	_boss_label.modulate.a = 1.0
	_boss_label.visible = true
	_boss_bar.modulate.a = 1.0
	_boss_bar.visible = true
	set_boss_health(current, maximum)


## Intro step 1: fade the boss's name in, large, in the middle of the screen.
func reveal_boss_title(boss_name: String, duration: float) -> Tween:
	_boss_label.text = boss_name
	_place_boss_title(BOSS_TITLE_REVEAL_Y, 1.0)
	_boss_label.modulate.a = 0.0
	_boss_label.visible = true
	var tween := create_tween()
	tween.tween_property(_boss_label, "modulate:a", 1.0, duration)
	return tween


## Intro step 2: shrink the name up into place, then fade the health bar in.
func dock_boss_title(duration: float, current: int, maximum: int) -> Tween:
	set_boss_health(current, maximum)
	_boss_bar.modulate.a = 0.0
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel()
	tween.tween_property(_boss_label, "position:y", BOSS_TITLE_DOCKED_Y - BOSS_TITLE_HEIGHT * 0.5, duration)
	tween.tween_property(_boss_label, "scale", Vector2.ONE * BOSS_TITLE_DOCKED_SCALE, duration)
	tween.chain().tween_callback(func() -> void: _boss_bar.visible = true)
	tween.tween_property(_boss_bar, "modulate:a", 1.0, 0.3)
	return tween


# center_y is where the middle of the text sits on screen.
func _place_boss_title(center_y: float, title_scale: float) -> void:
	_boss_label.position = Vector2(0, center_y - BOSS_TITLE_HEIGHT * 0.5)
	_boss_label.scale = Vector2.ONE * title_scale


func set_boss_health(current: int, maximum: int) -> void:
	_boss_bar.current = current
	_boss_bar.maximum = maximum
	_boss_bar.queue_redraw()


func hide_boss() -> void:
	_boss_label.visible = false
	_boss_bar.visible = false


func is_boss_shown() -> bool:
	return _boss_bar.visible


func show_message(text: String, duration := 2.5) -> void:
	_message_label.text = text
	_message_timer = duration


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		_message_label.modulate.a = clampf(_message_timer, 0.0, 1.0)


func _on_health_changed(current: int, maximum: int) -> void:
	_health_bar.current = current
	_health_bar.maximum = maximum
	_health_bar.queue_redraw()


func _on_stamina_changed(current: float, maximum: float) -> void:
	_stamina_bar.current = current
	_stamina_bar.maximum = maximum
	_stamina_bar.queue_redraw()


func _on_coins_changed(count: int) -> void:
	_coins_label.text = "Coins: %d" % count


func _on_ability_unlocked(ability: String) -> void:
	_refresh_abilities()
	show_message("Unlocked: %s" % ability.capitalize().replace("_", " "))


func _refresh_abilities() -> void:
	var parts: PackedStringArray = []
	for ability in GameState.abilities:
		if GameState.abilities[ability]:
			parts.append(String(ability).capitalize())
	_abilities_label.text = "Abilities: " + (", ".join(parts) if parts.size() > 0 else "none")
