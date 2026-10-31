class_name WardenShockwave
extends Area2D
## Ground wave from the Warden's slam. Travels along the floor until it hits a
## wall. Low enough to jump over. Position = its bottom-centre on the floor.

const SIZE := Vector2(20, 26)

var direction := 1
var speed := 380.0


func _ready() -> void:
	add_to_group("enemy_hitbox")
	add_to_group("boss_attack")   # cleared when the boss dies
	collision_layer = 16   # hazard layer, which the player's hurtbox watches
	collision_mask = 0
	monitoring = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	shape.position = Vector2(0, -SIZE.y * 0.5)
	add_child(shape)


func _physics_process(delta: float) -> void:
	var step := direction * speed * delta
	var from := global_position + Vector2(0, -SIZE.y * 0.5)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(step + direction * SIZE.x * 0.5, 0), 1)
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		queue_free()
		return
	position.x += step
	queue_redraw()


func _draw() -> void:
	var w := SIZE.x * 0.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w, 0), Vector2(direction * w * 0.4, -SIZE.y), Vector2(w, 0)]),
		Color(1.0, 0.7, 0.3, 0.9))
