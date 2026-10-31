class_name HarrierFeather
extends Area2D
## The Harrier's ranged shot: flies until it hits a wall, the floor or you.
## A homing feather is slow, curves toward you, and can be struck down with an
## attack (a down-strike bounces off it). Damage comes from the "damage" meta
## the Harrier sets.

const LENGTH := 22.0

var direction := Vector2.RIGHT
var speed := 230.0
var homing := false
var turn_rate := 2.2      ## radians per second, homing only
var lifetime := 3.0

var _age := 0.0


func _ready() -> void:
	add_to_group("enemy_hitbox")
	add_to_group("boss_attack")   # cleared when the boss dies
	if homing:
		add_to_group("breakable")   # player attacks call take_hit() on these
	collision_layer = 16   # hazard layer: the player's hurtbox and attacks both see it
	collision_mask = 0
	monitoring = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(LENGTH, 8) if not homing else Vector2(18, 18)
	shape.shape = rect
	add_child(shape)
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	_age += delta
	if homing:
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty() and players[0].visible:
			var want: float = (players[0].global_position - global_position).angle()
			var turn := clampf(wrapf(want - direction.angle(), -PI, PI), -turn_rate * delta, turn_rate * delta)
			direction = direction.rotated(turn)
			rotation = direction.angle()
	var step := direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + step + direction * LENGTH * 0.5, 1)
	if _age > lifetime or not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		queue_free()
		return
	global_position += step
	queue_redraw()


## Called by the player when this feather's hit lands.
func on_hit_player() -> void:
	queue_free()


## Homing feathers (group "breakable") can be struck down.
func take_hit(_amount: int, _hit_dir: Vector2) -> void:
	queue_free()


func _draw() -> void:
	var half := LENGTH * 0.5
	if homing:
		# Bigger, glowing, pulsing: clearly a different (hittable) thing.
		var pulse := 1.0 + 0.15 * sin(_age * 10.0)
		draw_circle(Vector2.ZERO, 10.0 * pulse, Color(0.75, 0.5, 1.0, 0.45))
		draw_colored_polygon(PackedVector2Array([
			Vector2(half, 0), Vector2(-half * 0.2, -6), Vector2(-half, 0), Vector2(-half * 0.2, 6)]),
			Color(0.85, 0.65, 1.0))
		return
	draw_colored_polygon(PackedVector2Array([
		Vector2(half, 0), Vector2(-half * 0.2, -4), Vector2(-half, 0), Vector2(-half * 0.2, 4)]),
		Color(0.6, 0.95, 1.0))
