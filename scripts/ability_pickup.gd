class_name AbilityPickup
extends Area2D
## Walk into it to permanently unlock an ability (stored in GameState).

var ability := ""
var label := ""
var _time := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2   # player body
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if body is Player:
		GameState.unlock(ability)
		queue_free()


func _draw() -> void:
	var bob := sin(_time * 3.0) * 4.0
	var c := Color(1.0, 0.85, 0.25)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -14 + bob), Vector2(12, bob), Vector2(0, 14 + bob), Vector2(-12, bob)]), c)
	draw_string(ThemeDB.fallback_font, Vector2(-40, -24 + bob), label,
		HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color(1, 1, 1, 0.8))
