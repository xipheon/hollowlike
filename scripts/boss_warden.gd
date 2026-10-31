class_name WardenBoss
extends CharacterBody2D
## Arena boss. Sleeps until activate(), then loops: recover -> pick an attack.
##   Charge: crouches (orange), then rushes until it hits a wall, and is dazed.
##   Leap:   hops to where you stand and slams, sending shockwaves both ways.
## Below half health it gets faster. When beaten it stays where it fell as a corpse. Needs: take_hit(), "enemy_hitbox" area.

signal health_changed(current: int, maximum: int)
signal defeated

const SIZE := Vector2(56, 72)
const LAYER_WORLD := 1

enum State { DORMANT, RECOVER, CHARGE_WINDUP, CHARGE, DAZED, LEAP_WINDUP, LEAP, LANDED, DEAD }

@export var max_health := 24
@export var gravity := 2400.0
@export var charge_speed := 620.0
@export var leap_velocity := -900.0
@export var shockwave_speed := 380.0
@export var recover_time := 0.9
@export var phase_two_speedup := 1.3   ## timers shrink and charge speeds up by this

var health := 0
## Horizontal limits for leap targets (set by the room before activate()).
var arena_left := 0.0
var arena_right := 0.0
## Attacks started, in order. Handy for tests and debugging.
var attack_log: Array[String] = []

var _state := State.DORMANT
var _timer := 0.0
var _dir := -1
var _flash_timer := 0.0
var _last_attack := ""
var _target: Node2D
var _hitbox: Area2D


func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	collision_layer = 4    # enemy
	collision_mask = LAYER_WORLD   # solid ground only: it ignores one-way platforms

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	add_child(shape)

	_hitbox = Area2D.new()
	_hitbox.add_to_group("enemy_hitbox")
	_hitbox.collision_layer = 16   # hazard layer, which the player's hurtbox watches
	_hitbox.collision_mask = 0
	_hitbox.monitoring = false
	var hit_shape := CollisionShape2D.new()
	var hit_rect := RectangleShape2D.new()
	hit_rect.size = SIZE - Vector2(6, 6)
	hit_shape.shape = hit_rect
	_hitbox.add_child(hit_shape)
	add_child(_hitbox)


func activate(target: Node2D) -> void:
	_target = target
	_enter(State.RECOVER, 1.0)


func is_phase_two() -> bool:
	return health * 2 <= max_health


func _speed() -> float:
	return phase_two_speedup if is_phase_two() else 1.0


func _physics_process(delta: float) -> void:
	_flash_timer = maxf(_flash_timer - delta, 0.0)
	_timer -= delta
	velocity.y = minf(velocity.y + gravity * delta, 1400.0)

	match _state:
		State.DORMANT, State.RECOVER, State.DAZED, State.LANDED:
			velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)
			if _state == State.RECOVER:
				_face_target()
			if _state != State.DORMANT and _timer <= 0.0:
				if _state == State.RECOVER:
					_choose_attack()
				else:
					_enter(State.RECOVER, recover_time / _speed())
		State.CHARGE_WINDUP:
			velocity.x = -_dir * 40.0   # small backstep sells the wind-up
			if _timer <= 0.0:
				_enter(State.CHARGE, 3.0)
		State.CHARGE:
			velocity.x = _dir * charge_speed * _speed()
		State.LEAP_WINDUP:
			velocity.x = 0.0
			if _timer <= 0.0:
				_start_leap()
		State.LEAP:
			pass
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, 2400.0 * delta)

	move_and_slide()

	if _state == State.CHARGE and (is_on_wall() or _timer <= 0.0):
		velocity.x = 0.0
		get_tree().call_group("player", "shake", 6.0, 0.2)
		_enter(State.DAZED, 0.7 / _speed())
	elif _state == State.LEAP and is_on_floor() and _timer <= 0.0:
		_land()
	queue_redraw()


func _enter(state: State, time: float) -> void:
	_state = state
	_timer = time


func _face_target() -> void:
	if is_instance_valid(_target):
		var dx := _target.global_position.x - global_position.x
		if absf(dx) > 4.0:
			_dir = int(signf(dx))


func _choose_attack() -> void:
	var options: Array[String] = ["charge", "leap"]
	# Usually avoid repeating the last attack.
	if options.size() > 1 and randf() < 0.75:
		options.erase(_last_attack)
	var attack: String = options.pick_random()
	_last_attack = attack
	attack_log.append(attack)
	_face_target()
	match attack:
		"charge":
			_enter(State.CHARGE_WINDUP, 0.8 / _speed())
		"leap":
			_enter(State.LEAP_WINDUP, 0.6 / _speed())


func _start_leap() -> void:
	var target_x := global_position.x
	if is_instance_valid(_target):
		target_x = _target.global_position.x
	var margin := SIZE.x * 0.5 + 8.0
	target_x = clampf(target_x, arena_left + margin, arena_right - margin)
	var air_time := 2.0 * -leap_velocity / gravity
	velocity = Vector2((target_x - global_position.x) / air_time, leap_velocity)
	_enter(State.LEAP, 0.1)   # timer guards against "landing" on the take-off frame


func _land() -> void:
	velocity.x = 0.0
	get_tree().call_group("player", "shake", 8.0, 0.25)
	var feet := global_position + Vector2(0, SIZE.y * 0.5)
	for dir in [-1, 1]:
		var wave := WardenShockwave.new()
		wave.direction = dir
		wave.speed = shockwave_speed * _speed()
		wave.position = feet + Vector2(dir * SIZE.x * 0.5, 0)
		get_parent().add_child(wave)
	_enter(State.LANDED, 0.5 / _speed())


func take_hit(damage: int, _hit_dir: Vector2) -> void:
	if _state == State.DORMANT or _state == State.DEAD:
		return
	health = maxi(health - damage, 0)
	_flash_timer = 0.08
	health_changed.emit(health, max_health)
	if health <= 0:
		become_corpse()
		defeated.emit()


## Stops fighting and stays put as harmless scenery (also used to restore the
## corpse when a beaten boss's room reloads).
func become_corpse() -> void:
	health = 0
	_enter(State.DEAD, 0.0)
	remove_from_group("enemy")
	collision_layer = 0   # player attacks pass through
	_hitbox.queue_free()
	queue_redraw()


func _draw() -> void:
	if _state == State.DEAD:
		_draw_corpse()
		return
	var body := Color(0.55, 0.2, 0.25) if is_phase_two() else Color(0.45, 0.42, 0.5)
	if _state in [State.CHARGE_WINDUP, State.LEAP_WINDUP]:
		body = Color(1.0, 0.55, 0.15)   # telegraph
	elif _state == State.DAZED:
		body = body.darkened(0.35)
	if _flash_timer > 0.0:
		body = Color.WHITE
	var half := SIZE * 0.5
	var crouch := 8.0 if _state in [State.CHARGE_WINDUP, State.LEAP_WINDUP] else 0.0
	draw_rect(Rect2(-half.x, -half.y + crouch, SIZE.x, SIZE.y - crouch), body)
	# Horns
	for side in [-1, 1]:
		var base := Vector2(side * half.x * 0.6, -half.y + crouch)
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-side * 6, 0), base + Vector2(side * 10, -18), base + Vector2(side * 6, 0)]),
			Color(0.85, 0.82, 0.7))
	# Mask with eyes facing the player
	var mask := Rect2(_dir * 6 - 16, -half.y + crouch + 10, 32, 20)
	draw_rect(mask, Color(0.9, 0.88, 0.8))
	var eye := Color(1.0, 0.3, 0.2) if is_phase_two() else Color(0.08, 0.06, 0.1)
	draw_rect(Rect2(mask.position + Vector2(6, 7), Vector2(6, 6)), eye)
	draw_rect(Rect2(mask.position + Vector2(20, 7), Vector2(6, 6)), eye)


# Slumped on its side: a low body with the mask and a horn on the ground.
func _draw_corpse() -> void:
	var half := SIZE * 0.5
	var body := Rect2(-half.y * 0.5 - 10, half.y - 26, half.y + 20, 26)
	draw_rect(body, Color(0.3, 0.27, 0.33))
	var head := Vector2(body.end.x + 4, half.y - 14)
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(4, -10), head + Vector2(26, -14), head + Vector2(8, -2)]), Color(0.7, 0.67, 0.58))
	draw_rect(Rect2(head + Vector2(-8, -10), Vector2(18, 20)), Color(0.75, 0.73, 0.66))
	draw_rect(Rect2(head + Vector2(-3, -4), Vector2(5, 3)), Color(0.08, 0.06, 0.1))
	draw_rect(Rect2(head + Vector2(-3, 3), Vector2(5, 3)), Color(0.08, 0.06, 0.1))
