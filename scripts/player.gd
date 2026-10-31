class_name Player
extends CharacterBody2D
## Core platforming + combat controller.
## Every feel parameter is an exported var: tweak the defaults here, or live
## via the Remote tab in the editor's scene tree while the game runs.
##
## Collision layers: 1 world | 2 player | 3 enemy | 4 player_attack | 5 hazard | 6 platforms

signal health_changed(current: int, maximum: int)
signal died

const BODY_SIZE := Vector2(22, 44)
const LAYER_ENEMY := 4
const LAYER_HAZARD := 16
const LAYER_WORLD := 1
const LAYER_GROUND := 1 | 32   # world solids + one-way platforms
const PLATFORM_LAYER_NUMBER := 6
const SAFE_GROUND_DELAY := 0.1
const HIT_DAMAGE := 2   # one full heart, in half-hearts
const PLATFORM_DROP_TIME := 0.25

@export_group("Run")
@export var run_speed := 320.0
@export var ground_accel := 3200.0
@export var ground_friction := 3600.0
@export var air_accel := 2200.0
@export var air_friction := 900.0

@export_group("Jump")
@export var jump_velocity := -640.0
@export var gravity := 1900.0
@export var fall_gravity_multiplier := 1.35
@export var max_fall_speed := 950.0
@export var jump_cut_multiplier := 0.4   ## release early = shorter hop
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.12

@export_group("Dash (ability)")
@export var dash_speed := 820.0
@export var dash_duration := 0.17
@export var dash_cooldown := 0.3

@export_group("Wall Jump (ability)")
@export var wall_slide_speed := 140.0
@export var wall_jump_velocity := Vector2(140, -600)
@export var wall_jump_lock_time := 0.15

@export_group("Combat")
@export var max_health := 10   ## in half-hearts (10 = 5 hearts)
@export var attack_damage := 1
@export var attack_duration := 0.12
@export var attack_cooldown := 0.26
@export var pogo_velocity := -560.0
@export var invulnerability_time := 0.5
@export var knockback := Vector2(500, -300)
@export var stun_time := 0.22

var camera: Camera2D
var health := 0
var facing := 1
var last_safe_position := Vector2.ZERO

var _hurtbox: Area2D
var _attack_area: Area2D
var _attack_shape: CollisionShape2D
var _attack_rect := Rect2()
var _attack_dir := Vector2.RIGHT
var _hit_this_swing := {}

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _dash_dir := 1
var _air_dash_available := true
var _wall_normal_x := 0.0
var _wall_lock_timer := 0.0
var _attack_timer := 0.0
var _attack_cooldown_timer := 0.0
var _invuln_timer := 0.0
var _stun_timer := 0.0
var _shake_timer := 0.0
var _shake_strength := 0.0
var _safe_ground_timer := 0.0
var _platform_drop_timer := 0.0
var _hitstop_active := false
var _dead := false


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = LAYER_GROUND
	floor_snap_length = 6.0
	health = max_health
	last_safe_position = global_position

	var body_shape := CollisionShape2D.new()
	var body_rect := RectangleShape2D.new()
	body_rect.size = BODY_SIZE
	body_shape.shape = body_rect
	add_child(body_shape)

	# Hurtbox: detects enemy contact boxes and hazards.
	_hurtbox = Area2D.new()
	_hurtbox.collision_layer = 0
	_hurtbox.collision_mask = LAYER_HAZARD
	_hurtbox.monitorable = false
	var hurt_shape := CollisionShape2D.new()
	var hurt_rect := RectangleShape2D.new()
	hurt_rect.size = BODY_SIZE - Vector2(4, 6)
	hurt_shape.shape = hurt_rect
	_hurtbox.add_child(hurt_shape)
	add_child(_hurtbox)

	# Attack hitbox: shape is moved/resized per swing direction.
	_attack_area = Area2D.new()
	_attack_area.collision_layer = 0
	_attack_area.collision_mask = LAYER_ENEMY | LAYER_HAZARD
	_attack_area.monitorable = false
	_attack_shape = CollisionShape2D.new()
	_attack_shape.shape = RectangleShape2D.new()
	_attack_shape.disabled = true
	_attack_area.add_child(_attack_shape)
	add_child(_attack_area)
	_attack_area.body_entered.connect(_on_attack_body_entered)
	_attack_area.area_entered.connect(_on_attack_area_entered)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	add_child(camera)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_update_timers(delta)

	var input_x := Input.get_axis("move_left", "move_right")
	var input_y := Input.get_axis("move_up", "move_down")
	var on_floor := is_on_floor()
	var stunned := _stun_timer > 0.0

	if on_floor:
		_coyote_timer = coyote_time
		_air_dash_available = true
	_update_safe_ground(on_floor, delta)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time

	# Wall slide: needs the ability, airborne, pressing into a wall.
	var wall_sliding := false
	if GameState.has_ability("wall_jump") and not on_floor and is_on_wall() and not stunned:
		var normal := get_wall_normal()
		if input_x != 0.0 and signf(input_x) == -signf(normal.x):
			wall_sliding = true
			_wall_normal_x = normal.x

	# Dash
	if not stunned and _dash_timer <= 0.0 and _dash_cooldown_timer <= 0.0 \
			and Input.is_action_just_pressed("dash") and GameState.has_ability("dash") \
			and (on_floor or _air_dash_available):
		_start_dash(input_x, on_floor)

	if _dash_timer > 0.0:
		velocity = Vector2(_dash_dir * dash_speed, 0.0)
	else:
		# Gravity (heavier on the way down for a snappier arc)
		var g := gravity
		if velocity.y > 0.0:
			g *= fall_gravity_multiplier
		velocity.y = minf(velocity.y + g * delta, max_fall_speed)
		if wall_sliding and velocity.y > wall_slide_speed:
			velocity.y = wall_slide_speed

		# Jump / wall jump (buffered)
		if _jump_buffer_timer > 0.0 and not stunned:
			if on_floor and input_y > 0.5 and _on_platform_only():
				_drop_through_platform()
			elif _coyote_timer > 0.0:
				velocity.y = jump_velocity
				_coyote_timer = 0.0
				_jump_buffer_timer = 0.0
			elif wall_sliding:
				velocity = Vector2(_wall_normal_x * wall_jump_velocity.x, wall_jump_velocity.y)
				facing = int(signf(_wall_normal_x))
				_wall_lock_timer = wall_jump_lock_time
				_jump_buffer_timer = 0.0
		# Variable jump height
		if Input.is_action_just_released("jump") and velocity.y < 0.0:
			velocity.y *= jump_cut_multiplier

		# Horizontal movement
		if stunned:
			velocity.x = move_toward(velocity.x, 0.0, ground_friction * 0.3 * delta)
		elif _wall_lock_timer <= 0.0:
			var accel := ground_accel if on_floor else air_accel
			if input_x == 0.0:
				accel = ground_friction if on_floor else air_friction
			velocity.x = move_toward(velocity.x, input_x * run_speed, accel * delta)

	# Attack
	if not stunned and Input.is_action_just_pressed("attack") and _attack_cooldown_timer <= 0.0:
		_start_attack(input_y, on_floor)

	move_and_slide()

	if input_x != 0.0 and not stunned and _wall_lock_timer <= 0.0 and _dash_timer <= 0.0:
		facing = int(signf(input_x))

	_check_hurtbox()


func _process(delta: float) -> void:
	# Invulnerability blink
	modulate.a = 0.35 if (_invuln_timer > 0.0 and int(_invuln_timer * 20.0) % 2 == 0) else 1.0
	# Camera shake, on whichever camera is live (the boss arena locks its own).
	var live_camera := get_viewport().get_camera_2d()
	if live_camera == null:
		live_camera = camera
	elif live_camera != camera:
		camera.offset = Vector2.ZERO   # don't leave a stale shake for the hand-back
	if _shake_timer > 0.0:
		_shake_timer -= delta
		live_camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
	else:
		live_camera.offset = Vector2.ZERO
	queue_redraw()


# Only remember ground as "safe" after standing on it hazard-free for a moment.
# Hazard overlaps lag a physics frame, so committing on the first frame of a
# landing could save a spot inside a spike pit and respawn you onto the spikes.
func _update_safe_ground(on_floor: bool, delta: float) -> void:
	if not on_floor or _touching_hazard() or not _both_feet_supported():
		_safe_ground_timer = 0.0
		return
	_safe_ground_timer += delta
	if _safe_ground_timer >= SAFE_GROUND_DELAY:
		last_safe_position = global_position


# Ground directly under both bottom corners, so a respawn here can't start
# hanging off a ledge.
func _both_feet_supported() -> bool:
	return _foot_on(-1, LAYER_GROUND) and _foot_on(1, LAYER_GROUND)


# Standing on a one-way platform with no solid ground under either foot.
func _on_platform_only() -> bool:
	return not _foot_on(-1, LAYER_WORLD) and not _foot_on(1, LAYER_WORLD)


# Whether something on `mask` is just below the left (-1) or right (1) bottom corner.
func _foot_on(side: int, mask: int) -> bool:
	var half := BODY_SIZE * 0.5
	var from := global_position + Vector2(side * half.x, half.y - 2.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 8), mask)
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


# Down + jump on a one-way platform: stop colliding with platforms briefly.
func _drop_through_platform() -> void:
	set_collision_mask_value(PLATFORM_LAYER_NUMBER, false)
	_platform_drop_timer = PLATFORM_DROP_TIME
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	velocity.y = maxf(velocity.y, 60.0)


func _touching_hazard() -> bool:
	for area in _hurtbox.get_overlapping_areas():
		if area.is_in_group("hazard") or area.is_in_group("lethal_hazard"):
			return true
	return false


func _update_timers(delta: float) -> void:
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_wall_lock_timer = maxf(_wall_lock_timer - delta, 0.0)
	_attack_cooldown_timer = maxf(_attack_cooldown_timer - delta, 0.0)
	_invuln_timer = maxf(_invuln_timer - delta, 0.0)
	_stun_timer = maxf(_stun_timer - delta, 0.0)
	if _platform_drop_timer > 0.0:
		_platform_drop_timer -= delta
		if _platform_drop_timer <= 0.0:
			set_collision_mask_value(PLATFORM_LAYER_NUMBER, true)
	if _dash_timer > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			velocity.x = _dash_dir * run_speed   # keep some momentum out of the dash
			velocity.y = 0.0
	if _attack_timer > 0.0 and not _is_holding_pogo():
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_attack_shape.set_deferred("disabled", true)


# ---------------------------------------------------------------- Dash ----

func _start_dash(input_x: float, on_floor: bool) -> void:
	_dash_dir = int(signf(input_x)) if input_x != 0.0 else facing
	facing = _dash_dir
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_duration + dash_cooldown
	if not on_floor:
		_air_dash_available = false


# -------------------------------------------------------------- Attack ----

func _start_attack(input_y: float, on_floor: bool) -> void:
	_attack_timer = attack_duration
	_attack_cooldown_timer = attack_cooldown
	_hit_this_swing.clear()

	var size := Vector2(60, 40)
	var offset := Vector2.ZERO
	if input_y < -0.5:
		_attack_dir = Vector2.UP
		size = Vector2(48, 52)
		offset = Vector2(0, -48)
	elif input_y > 0.5 and not on_floor:
		_attack_dir = Vector2.DOWN
		size = Vector2(40, 52)
		offset = Vector2(0, 48)
	else:
		_attack_dir = Vector2(facing, 0)
		offset = Vector2(facing * 41, 0)

	(_attack_shape.shape as RectangleShape2D).size = size
	_attack_shape.position = offset
	_attack_rect = Rect2(offset - size * 0.5, size)
	_attack_shape.set_deferred("disabled", false)


func _on_attack_body_entered(body: Node) -> void:
	if _hit_this_swing.has(body) or not body.has_method("take_hit"):
		return
	_hit_this_swing[body] = true
	body.take_hit(attack_damage, _attack_dir)
	hit_stop(0.05)
	shake(3.0, 0.1)
	if _attack_dir == Vector2.DOWN:
		_pogo()


func _on_attack_area_entered(area: Area2D) -> void:
	# Downward strike on spikes bounces you, like Hollow Knight.
	if _attack_dir == Vector2.DOWN and area.is_in_group("pogo") and not _hit_this_swing.has(area):
		_hit_this_swing[area] = true
		_pogo()


func _pogo() -> void:
	velocity.y = pogo_velocity
	_air_dash_available = true
	# Targets can be bounced on again once they leave and re-enter a held strike.
	_hit_this_swing.clear()


# A downward strike stays out while attack is held, until you land.
func _is_holding_pogo() -> bool:
	return _attack_dir == Vector2.DOWN and Input.is_action_pressed("attack") and not is_on_floor()


# -------------------------------------------------------------- Damage ----

func _check_hurtbox() -> void:
	# Lethal hazards (acid) kill instantly, even through invulnerability frames.
	for area in _hurtbox.get_overlapping_areas():
		if area.is_in_group("lethal_hazard"):
			kill()
			return
	if _invuln_timer > 0.0:
		return
	for area in _hurtbox.get_overlapping_areas():
		if area.is_in_group("hazard"):
			take_damage(HIT_DAMAGE, area.global_position, true)
			return
		if area.is_in_group("enemy_hitbox"):
			take_damage(HIT_DAMAGE, area.global_position, false)
			return


func heal(amount: int) -> void:
	if _dead:
		return
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)


func kill() -> void:
	_invuln_timer = 0.0
	take_damage(health, global_position, true)


func take_damage(amount: int, source_position: Vector2, is_hazard: bool) -> void:
	if _dead or _invuln_timer > 0.0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	_invuln_timer = invulnerability_time
	_stun_timer = stun_time
	_dash_timer = 0.0
	_attack_timer = 0.0
	_attack_shape.set_deferred("disabled", true)
	shake(7.0, 0.25)
	hit_stop(0.08)

	if health <= 0:
		_dead = true
		visible = false
		died.emit()
		return

	if is_hazard:
		# Hollow Knight-style: hazards hurt, then put you back on safe ground.
		global_position = last_safe_position
		velocity = Vector2.ZERO
	else:
		var away := signf(global_position.x - source_position.x)
		if away == 0.0:
			away = -facing
		velocity = Vector2(away * knockback.x, knockback.y)


# ---------------------------------------------------------------- Juice ----

func shake(strength: float, duration: float) -> void:
	_shake_strength = strength
	_shake_timer = duration


func hit_stop(duration: float) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


# ------------------------------------------------------ Placeholder art ----

func _draw() -> void:
	var color := Color(0.88, 0.92, 1.0)
	if _dash_timer > 0.0:
		color = Color(0.45, 0.9, 1.0)
	elif _stun_timer > 0.0:
		color = Color(1.0, 0.6, 0.6)
	draw_rect(Rect2(-BODY_SIZE * 0.5, BODY_SIZE), color)
	# "Eye" shows facing direction
	draw_rect(Rect2(facing * 5 - 3, -14, 6, 6), Color(0.1, 0.1, 0.15))
	if _attack_timer > 0.0:
		draw_rect(_attack_rect, Color(1, 1, 1, 0.65))
