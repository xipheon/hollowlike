class_name HarrierFeather
extends Area2D
## The Harrier's ranged shot: flies straight until it hits a wall or times out.
## Damage comes from the "damage" meta the Harrier sets.

const LENGTH := 22.0
const LIFETIME := 3.0

var direction := Vector2.RIGHT
var speed := 460.0

var _age := 0.0


func _ready() -> void:
	add_to_group("enemy_hitbox")
	add_to_group("boss_attack")   # cleared when the boss dies
	collision_layer = 16   # hazard layer, which the player's hurtbox watches
	collision_mask = 0
	monitoring = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(LENGTH, 8)
	shape.shape = rect
	add_child(shape)
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	_age += delta
	var step := direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + step + direction * LENGTH * 0.5, 1)
	if _age > LIFETIME or not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		queue_free()
		return
	global_position += step


func _draw() -> void:
	var half := LENGTH * 0.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(half, 0), Vector2(-half * 0.2, -4), Vector2(-half, 0), Vector2(-half * 0.2, 4)]),
		Color(0.6, 0.95, 1.0))
