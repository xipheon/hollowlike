class_name KnightEnemy
extends CharacterBody2D
## Slow armoured swordsman, as tall as the player. Patrols, walks toward you
## when it sees you, and when you're in reach raises its sword (glows orange)
## then swings. The swing is slow to start: step back, or hit it first.
## Needs: take_hit(), "enemy_hitbox" areas (body + sword).

const SIZE := Vector2(24, 44)
const KILL_HEAL := 1   # half a heart for the player
const SWORD_SIZE := Vector2(46, 28)

enum State { PATROL, WINDUP, SWING, RECOVER }

@export var max_health := 5
@export var walk_speed := 45.0
@export var gravity := 1800.0
@export var sight_range := 220.0     ## starts walking toward you within this
@export var attack_range := 70.0     ## starts a swing when you're this close
@export var windup_time := 0.55
@export var swing_time := 0.18
@export var recover_time := 0.8

var health := 0
var swings := 0   # swings started; handy for tests and debugging

var _state := State.PATROL
var _timer := 0.0
var _dir := -1
var _flash_timer := 0.0
var _knockback := 0.0
var _ledge_ray: RayCast2D
var _sword_shape: CollisionShape2D


func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	collision_layer = 4       # enemy
	collision_mask = 1 | 32   # world + platforms only, so the player walks through enemies

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	add_child(shape)

	add_child(_make_hitbox(SIZE - Vector2(4, 4), Vector2.ZERO))
	var sword := _make_hitbox(SWORD_SIZE, Vector2.ZERO)
	_sword_shape = sword.get_child(0)
	_sword_shape.disabled = true
	add_child(sword)

	_ledge_ray = RayCast2D.new()
	_ledge_ray.target_position = Vector2(0, SIZE.y * 0.5 + 10)
	_ledge_ray.collision_mask = 1 | 32
	add_child(_ledge_ray)
	_set_dir(_dir)


func _make_hitbox(size: Vector2, offset: Vector2) -> Area2D:
	var hitbox := Area2D.new()
	hitbox.add_to_group("enemy_hitbox")
	hitbox.collision_layer = 16   # hazard layer, which the player's hurtbox watches
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	var hit_shape := CollisionShape2D.new()
	var hit_rect := RectangleShape2D.new()
	hit_rect.size = size
	hit_shape.shape = hit_rect
	hit_shape.position = offset
	hitbox.add_child(hit_shape)
	return hitbox


func _physics_process(delta: float) -> void:
	_flash_timer = maxf(_flash_timer - delta, 0.0)
	_timer -= delta
	velocity.y += gravity * delta
	var player := _find_player()

	match _state:
		State.PATROL:
			var speed := walk_speed
			if player != null and _can_see(player):
				_set_dir(int(signf(player.global_position.x - global_position.x)))
				if absf(player.global_position.x - global_position.x) <= attack_range:
					_enter(State.WINDUP, windup_time)
					speed = 0.0
			var wall_ahead := is_on_wall() and get_wall_normal().x * _dir < 0.0
			if speed > 0.0 and is_on_floor() and (wall_ahead or not _ledge_ray.is_colliding()):
				if player != null and _can_see(player):
					speed = 0.0   # wait at the edge rather than walking off
				else:
					_set_dir(-_dir)
			velocity.x = _dir * speed   # after any turn, so it walks away from the wall this frame
		State.WINDUP:
			velocity.x = 0.0
			if _timer <= 0.0:
				swings += 1
				_sword_shape.set_deferred("disabled", false)
				_enter(State.SWING, swing_time)
		State.SWING:
			velocity.x = _dir * 60.0   # small lunge into the swing
			if not _ledge_ray.is_colliding():
				velocity.x = 0.0
			if _timer <= 0.0:
				_sword_shape.set_deferred("disabled", true)
				_enter(State.RECOVER, recover_time)
		State.RECOVER:
			velocity.x = 0.0
			if _timer <= 0.0:
				_enter(State.PATROL, 0.0)

	if _knockback != 0.0:
		velocity.x += _knockback
		_knockback = move_toward(_knockback, 0.0, 900.0 * delta)
	move_and_slide()
	queue_redraw()


func _enter(state: State, time: float) -> void:
	_state = state
	_timer = time


func _set_dir(dir: int) -> void:
	if dir == 0:
		return
	_dir = dir
	_ledge_ray.position.x = _dir * (SIZE.x * 0.5 + 4)
	_ledge_ray.force_raycast_update()
	_sword_shape.position = Vector2(_dir * (SIZE.x * 0.5 + SWORD_SIZE.x * 0.5 - 4), -4)


func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() and players[0].visible else null


# Roughly level with us and within sight range.
func _can_see(player: Node2D) -> bool:
	var d := player.global_position - global_position
	return absf(d.x) <= sight_range and absf(d.y) <= SIZE.y


func take_hit(damage: int, hit_dir: Vector2) -> void:
	health -= damage
	_flash_timer = 0.1
	if hit_dir.x != 0.0:
		_knockback = signf(hit_dir.x) * 160.0   # heavy: shoved, not staggered
	if health <= 0:
		get_tree().call_group("player", "heal", KILL_HEAL)
		queue_free()


func _draw() -> void:
	var half := SIZE * 0.5
	var armour := Color(0.42, 0.46, 0.55)
	if _state == State.WINDUP:
		armour = Color(1.0, 0.6, 0.2)   # telegraph
	if _flash_timer > 0.0:
		armour = Color.WHITE
	draw_rect(Rect2(-half, SIZE), armour)
	# Helmet visor slit, facing forward
	draw_rect(Rect2(_dir * 2 - 6, -half.y + 7, 12, 3), Color(0.06, 0.06, 0.1))
	# Plume
	draw_rect(Rect2(-_dir * 4 - 2, -half.y - 6, 4, 8), Color(0.75, 0.2, 0.2))
	# Sword: lowered while walking, raised overhead in the wind-up, out level in the swing.
	var hand := Vector2(_dir * (half.x - 2), 2)
	var blade := Color(0.85, 0.88, 0.95)
	match _state:
		State.WINDUP:
			draw_line(hand, hand + Vector2(-_dir * 10, -34), blade, 4.0)
		State.SWING:
			draw_line(hand, hand + Vector2(_dir * (SWORD_SIZE.x - 4), -4), blade, 4.0)
		_:
			draw_line(hand, hand + Vector2(_dir * 18, 16), blade, 4.0)
