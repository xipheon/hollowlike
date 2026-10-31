class_name CrawlerEnemy
extends CharacterBody2D
## Simple patrolling enemy: walks, turns at walls and ledges, hurts on contact.
## Copy this as a template for new enemies. Needs: take_hit(), "enemy_hitbox" area.

const SIZE := Vector2(28, 24)
const KILL_HEAL := 1   # half a heart for the player

@export var max_health := 3
@export var speed := 70.0
@export var gravity := 1800.0
@export var damage := 2   ## per hit, in half-hearts

var health := 0
var _dir := -1
var _stagger_timer := 0.0
var _flash_timer := 0.0
var _ledge_ray: RayCast2D


func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	collision_layer = 4    # enemy
	collision_mask = 1 | 32   # world + platforms only, so the player walks through enemies

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	add_child(shape)

	var hitbox := Area2D.new()
	hitbox.add_to_group("enemy_hitbox")
	hitbox.set_meta("damage", damage)   # read by the player's hurtbox
	hitbox.collision_layer = 16   # hazard layer, which the player's hurtbox watches
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	var hit_shape := CollisionShape2D.new()
	var hit_rect := RectangleShape2D.new()
	hit_rect.size = SIZE - Vector2(2, 2)
	hit_shape.shape = hit_rect
	hitbox.add_child(hit_shape)
	add_child(hitbox)

	_ledge_ray = RayCast2D.new()
	_ledge_ray.target_position = Vector2(0, 22)
	_ledge_ray.collision_mask = 1 | 32
	_ledge_ray.position = Vector2(_dir * 16, 0)
	add_child(_ledge_ray)


func _physics_process(delta: float) -> void:
	_flash_timer = maxf(_flash_timer - delta, 0.0)
	_stagger_timer = maxf(_stagger_timer - delta, 0.0)
	velocity.y += gravity * delta

	if _stagger_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
	else:
		if is_on_floor() and (_wall_ahead() or not _ledge_ray.is_colliding()):
			_turn()
		velocity.x = _dir * speed   # after any turn, so it walks away from the wall this frame
	move_and_slide()
	queue_redraw()


# Only a wall we're walking into, not one we just turned away from.
func _wall_ahead() -> bool:
	return is_on_wall() and get_wall_normal().x * _dir < 0.0


func _turn() -> void:
	_dir *= -1
	_ledge_ray.position.x = _dir * 16
	_ledge_ray.force_raycast_update()


func take_hit(amount: int, hit_dir: Vector2) -> void:
	health -= amount
	_flash_timer = 0.1
	_stagger_timer = 0.3
	if health <= 0:
		get_tree().call_group("player", "heal", KILL_HEAL)
		queue_free()


func _draw() -> void:
	var color := Color.WHITE if _flash_timer > 0.0 else Color(0.85, 0.3, 0.3)
	draw_rect(Rect2(-SIZE * 0.5, SIZE), color)
	draw_rect(Rect2(_dir * 7 - 3, -7, 6, 6), Color(0.1, 0.05, 0.05))
