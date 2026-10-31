class_name ItemPickup
extends Area2D
## Walk-over collectible.
##   coin:   adds to GameState.coins; remembered by coin_id, so it never respawns.
##   health: restores a heart; ignored at full health, respawns with the room.

const HEALTH_AMOUNT := 2   # one heart, in half-hearts

var kind := "coin"
var coin_id := ""
var _time := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2   # player body
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)
	_time = randf() * TAU   # so rows of coins don't bob in lockstep


func _physics_process(_delta: float) -> void:
	# Polled rather than body_entered, so a health pickup you stand on at full
	# health is still taken the moment you get hurt.
	for body in get_overlapping_bodies():
		if body is Player and _try_collect(body):
			queue_free()
			return


func _try_collect(player: Player) -> bool:
	match kind:
		"coin":
			GameState.collect_coin(coin_id)
			return true
		"health":
			if player.health >= player.max_health:
				return false
			player.heal(HEALTH_AMOUNT)
			return true
	return false


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var bob := sin(_time * 3.0) * 3.0
	match kind:
		"coin":
			var squash := absf(cos(_time * 2.0))   # spinning
			var w := maxf(9.0 * squash, 2.0)
			draw_colored_polygon(_ellipse(Vector2(0, bob), w, 9.0), Color(1.0, 0.8, 0.2))
			draw_colored_polygon(_ellipse(Vector2(0, bob), w * 0.55, 5.5), Color(1.0, 0.92, 0.55))
		"health":
			var c := Color(0.95, 0.3, 0.35)
			draw_circle(Vector2(-5, bob - 3), 6.0, c)
			draw_circle(Vector2(5, bob - 3), 6.0, c)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-10.5, bob - 1), Vector2(10.5, bob - 1), Vector2(0, bob + 11)]), c)


func _ellipse(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return points
