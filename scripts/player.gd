class_name Player
extends CharacterBody2D
## Core platforming + combat controller.
## Every feel parameter is an exported var: tweak the defaults here, or live
## via the Remote tab in the editor's scene tree while the game runs.
##
## Collision layers: 1 world | 2 player | 3 enemy | 4 player_attack | 5 hazard | 6 platforms

signal health_changed(current: int, maximum: int)
signal stamina_changed(current: float, maximum: float)
signal died

const BODY_SIZE := Vector2(22, 44)
const HURTBOX_SIZE := BODY_SIZE - Vector2(4, 6)
const LAYER_ENEMY := 4
const LAYER_HAZARD := 16
const LAYER_WORLD := 1
const LAYER_GROUND := 1 | 32   # world solids + one-way platforms
const PLATFORM_LAYER_NUMBER := 6
const SAFE_GROUND_DELAY := 0.1
const BLOW_UNKNOWN := "UI_DEATH_BY_UNKNOWN"   # a hit with no "blow" meta
const DEFAULT_HIT_DAMAGE := 2   # one full heart, in half-hearts, for hitboxes with no "damage" meta
const PLATFORM_DROP_TIME := 0.25
const DASH_STICK_THRESHOLD := 0.4   # how far a stick must lean on an axis to dash along it
const DEFAULT_HIT_RECOIL := 300.0   # px/s, for things you hit that set no hit_recoil
const RECOIL_MOSTLY := 0.5   # a recoil pointing this far up refreshes air moves; this far sideways locks steering

@export_group("Light")
## A faint light that goes with you, so you always read against the wall.
@export var light_radius := 96
@export var light_energy := 0.3
@export var light_color := Color(1.0, 0.95, 0.85)
@export var light_height := 40.0            ## px out from the wall (see FlickerLight)
## Each swing throws a brief flash over the slash.
@export var slash_flash_radius := 80
@export var slash_flash_energy := 0.6
@export var slash_flash_time := 0.12
@export var slash_flash_color := Color(0.85, 0.95, 1.0)

@export_group("Run")
@export var run_speed := 320.0
@export var ground_accel := 3200.0
@export var ground_friction := 3600.0
@export var air_accel := 2200.0
@export var air_friction := 900.0

@export_group("Sprint & Stamina")
@export var sprint_speed := 480.0
@export var max_stamina := 100.0
@export var sprint_drain := 35.0            ## per second while sprinting
@export var stamina_regen := 45.0           ## per second, only while standing on ground
@export var dash_stamina_cost := 30.0
@export var wall_jump_stamina_cost := 20.0

@export_group("Jump")
@export var jump_velocity := -640.0
@export var gravity := 1900.0
@export var fall_gravity_multiplier := 1.35
@export var max_fall_speed := 950.0
@export var jump_cut_multiplier := 0.4   ## release early = shorter hop
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.12

@export_group("Double Jump (ability)")
@export var double_jump_velocity := -560.0   ## one extra jump in the air; back on landing, wall sliding or a down-strike bounce

@export_group("Dash (ability)")
@export var dash_speed := 820.0
@export var dash_duration := 0.17
@export var dash_cooldown := 0.3
@export var dash_buffer_time := 0.15   ## a dash pressed this soon before it's allowed again still happens

@export_group("Wall Jump (ability)")
@export var wall_slide_speed := 140.0
@export var wall_jump_velocity := Vector2(140, -600)
@export var wall_jump_lock_time := 0.15

@export_group("Combat")
## In half-hearts (10 = 5 hearts), before items: Heart Containers add to it
## (GameState.max_health_bonus()).
@export var max_health := 10
## Before items: a Strong Pipe adds to it (GameState.damage_bonus()).
@export var attack_damage := 1
@export var attack_duration := 0.12
@export var attack_cooldown := 0.26
@export var attack_buffer_time := 0.15   ## an attack pressed this soon before the cooldown ends still swings
@export var recoil_lock_time := 0.12   ## after a side swing's recoil shoves you back, how long before you steer again
@export var platform_carry_time := 0.5   ## leaving a moving platform, its sideways speed fades out over this many seconds
@export var invulnerability_time := 0.5
@export var knockback := Vector2(500, -300)
@export var stun_time := 0.22

@export_group("Armor")
@export var armor_flat := 0          ## half-hearts taken off every hit, applied first
@export_range(0.0, 1.0) var armor_percent := 0.0   ## then this fraction of what's left is blocked

var camera: Camera2D
var health := 0
var stamina := 0.0
var facing := 1
var last_safe_position := Vector2.ZERO

var _hurtbox: Area2D
var _attack_area: Area2D
var _attack_shape: CollisionShape2D
var _attack_dir := Vector2.RIGHT
var _hit_this_swing := {}

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _dash_dir := Vector2.RIGHT   # one of 8 directions, normalised
var _air_dash_available := true
var _air_jump_available := true
var _wall_normal_x := 0.0
var _wall_lock_timer := 0.0
var _recoil_timer := 0.0
var _platform_velocity := Vector2.ZERO   # the moving platform's, while you stand on one
var _carried_x := 0.0   # sideways speed kept from a moving platform you left, on top of your own
var _carry_bleed := 0.0   # px/s per second it fades by
var _attack_timer := 0.0
var _attack_cooldown_timer := 0.0
var _attack_buffer_timer := 0.0
var _dash_buffer_timer := 0.0
var _invuln_timer := 0.0
var _stun_timer := 0.0
var _shake_timer := 0.0
var _shake_strength := 0.0
var _safe_ground_timer := 0.0
var _platform_drop_timer := 0.0
var _sprint_exhausted := false   # ran dry: let go of sprint before it works again
var _hitstop_active := false
var _dead := false
## What dealt the final blow, as the death screen's message (a translation
## key; see blow_of()). Set when you die.
var killed_by := ""
var _last_blow := BLOW_UNKNOWN   # what hit you last

# Animation
const LAND_ANIM_TIME := 0.15
const WALL_JUMP_ANIM_TIME := 0.3
const DOUBLE_JUMP_ANIM_TIME := 0.25
var sprite: PlayerSprite
var slash: SlashEffect
var light: PointLight2D   # the faint light that goes with you
var _wall_sliding := false
var _sprinting := false
var _was_on_floor := true
var _land_anim_timer := 0.0
var _wall_jump_anim_timer := 0.0
var _double_jump_anim_timer := 0.0
var _attack_anim_timer := 0.0
var _attack_anim := ""
var _attack_anim_restart := false
var _base_max_health := 0     # max_health and attack_damage as set, before items
var _base_attack_damage := 0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = LAYER_GROUND
	floor_snap_length = 6.0
	platform_on_leave = PLATFORM_ON_LEAVE_DO_NOTHING   # _carry_platform_momentum() does it
	_base_max_health = max_health
	_base_attack_damage = attack_damage
	_apply_items()
	GameState.item_received.connect(_on_item_received)
	health = GameState.take_carried_health(max_health)
	stamina = max_stamina
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
	hurt_rect.size = HURTBOX_SIZE
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

	# Feet at the bottom of the body box.
	sprite = PlayerSprite.new()
	sprite.position = Vector2(0, BODY_SIZE.y * 0.5 - PlayerSprite.FRAME.y * 0.5)
	add_child(sprite)
	sprite.apply_skin(GameState.player_skin)
	GameState.player_skin_changed.connect(sprite.apply_skin)
	slash = SlashEffect.new()
	add_child(slash)
	light = FlickerLight.make_light(light_radius, light_color, light_energy, light_height)
	add_child(light)


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
		_air_jump_available = true
	_carry_platform_momentum(on_floor, delta)
	_update_safe_ground(on_floor, delta)
	var sprinting := _update_stamina(input_x, on_floor and not stunned, delta)
	_sprinting = sprinting
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time

	# Wall slide: needs the ability, airborne, pressing into a wall.
	var wall_sliding := false
	if GameState.has_ability("wall_jump") and not on_floor and is_on_wall() and not stunned:
		var normal := get_wall_normal()
		if input_x != 0.0 and signf(input_x) == -signf(normal.x):
			wall_sliding = true
			_wall_normal_x = normal.x
			_air_jump_available = true
	_wall_sliding = wall_sliding

	# Dash (buffered: a press during the cooldown, a stun, or just before landing
	# with the air dash used goes off as soon as dashing is allowed)
	if Input.is_action_just_pressed("dash"):
		_dash_buffer_timer = dash_buffer_time
	if not stunned and _dash_timer <= 0.0 and _dash_cooldown_timer <= 0.0 \
			and _dash_buffer_timer > 0.0 and GameState.has_ability("dash") \
			and (on_floor or _air_dash_available) and stamina >= dash_stamina_cost:
		_dash_buffer_timer = 0.0
		_start_dash(input_x, input_y, on_floor)
	# A dash into the floor or a ceiling stops there.
	if _dash_timer > 0.0 and ((_dash_dir.y > 0.0 and on_floor) or (_dash_dir.y < 0.0 and is_on_ceiling())):
		_end_dash()

	if _dash_timer > 0.0:
		velocity = _dash_dir * dash_speed
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
			elif wall_sliding and stamina >= wall_jump_stamina_cost:
				_set_stamina(stamina - wall_jump_stamina_cost)
				velocity = Vector2(_wall_normal_x * wall_jump_velocity.x, wall_jump_velocity.y)
				facing = int(signf(_wall_normal_x))
				_wall_lock_timer = wall_jump_lock_time
				_wall_jump_anim_timer = WALL_JUMP_ANIM_TIME
				_jump_buffer_timer = 0.0
			# Only on a fresh press: a buffered press just before landing is a ground jump.
			elif Input.is_action_just_pressed("jump") and _air_jump_available and GameState.has_ability("double_jump"):
				velocity.y = double_jump_velocity
				_air_jump_available = false
				_double_jump_anim_timer = DOUBLE_JUMP_ANIM_TIME
				_jump_buffer_timer = 0.0
		# Variable jump height
		if Input.is_action_just_released("jump") and velocity.y < 0.0:
			velocity.y *= jump_cut_multiplier

		# Horizontal movement
		if stunned:
			velocity.x = move_toward(velocity.x, 0.0, ground_friction * 0.3 * delta)
		elif _wall_lock_timer <= 0.0 and _recoil_timer <= 0.0:
			var accel := ground_accel if on_floor else air_accel
			if input_x == 0.0:
				accel = ground_friction if on_floor else air_friction
			var top_speed := sprint_speed if sprinting else run_speed
			# Steering and air friction work on your own speed; a platform's carried speed rides on top.
			velocity.x = _carried_x + move_toward(velocity.x - _carried_x, input_x * top_speed, accel * delta)

	# Attack (buffered: a press during the cooldown or a stun swings once it's over,
	# aimed by whatever direction is held then). On the ground next to an NPC,
	# it talks to them instead.
	if Input.is_action_just_pressed("attack"):
		if stunned or not on_floor or not _talk_to_nearby():
			_attack_buffer_timer = attack_buffer_time
	if not stunned and _attack_buffer_timer > 0.0 and _attack_cooldown_timer <= 0.0:
		_attack_buffer_timer = 0.0
		_start_attack(input_y, on_floor)

	move_and_slide()
	if is_on_wall():
		_carried_x = 0.0

	if input_x != 0.0 and not stunned and _wall_lock_timer <= 0.0 and _dash_timer <= 0.0:
		facing = int(signf(input_x))

	_check_hurtbox()
	_update_animation(delta)


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


# Only remember ground as "safe" after standing on it hazard-free for a moment.
# Hazard overlaps lag a physics frame, so committing on the first frame of a
# landing could save a spot inside a spike pit and respawn you onto the spikes.
func _update_safe_ground(on_floor: bool, delta: float) -> void:
	# Not on a moving platform: it won't be there when you respawn.
	if not on_floor or _touching_hazard() or not _both_feet_supported() or _on_moving_platform():
		_safe_ground_timer = 0.0
		return
	_safe_ground_timer += delta
	if _safe_ground_timer >= SAFE_GROUND_DELAY:
		last_safe_position = global_position


# Standing on a moving platform, remembers its velocity (move_and_slide carries
# you with it). Leaving it, by jumping or walking off, keeps its sideways speed
# on top of your own, bleeding away over platform_carry_time (sooner if you
# land, hit a wall, dash or get hit), and its upward speed as a boost.
func _carry_platform_momentum(on_floor: bool, delta: float) -> void:
	if on_floor:
		_platform_velocity = get_platform_velocity()
		_carried_x = 0.0
	elif _platform_velocity != Vector2.ZERO:
		_carried_x = _platform_velocity.x
		_carry_bleed = absf(_carried_x) / platform_carry_time
		velocity.x += _carried_x
		velocity.y += minf(_platform_velocity.y, 0.0)
		_platform_velocity = Vector2.ZERO
	elif _carried_x != 0.0:
		var bled := move_toward(_carried_x, 0.0, _carry_bleed * delta)
		velocity.x += bled - _carried_x
		_carried_x = bled


# A moving platform under either foot.
func _on_moving_platform() -> bool:
	return _foot_hit(-1, LAYER_GROUND).get("collider") is MovingPlatform \
			or _foot_hit(1, LAYER_GROUND).get("collider") is MovingPlatform


# Ground directly under both bottom corners, so a respawn here can't start
# hanging off a ledge.
func _both_feet_supported() -> bool:
	return _foot_on(-1, LAYER_GROUND) and _foot_on(1, LAYER_GROUND)


# Standing on a one-way platform with no solid ground under either foot.
func _on_platform_only() -> bool:
	return not _foot_on(-1, LAYER_WORLD) and not _foot_on(1, LAYER_WORLD)


# Whether something on `mask` is just below the left (-1) or right (1) bottom corner.
func _foot_on(side: int, mask: int) -> bool:
	return not _foot_hit(side, mask).is_empty()


# What's on `mask` just below that corner (a ray hit; empty if nothing).
func _foot_hit(side: int, mask: int) -> Dictionary:
	var half := BODY_SIZE * 0.5
	var from := global_position + Vector2(side * half.x, half.y - 2.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 8), mask)
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query)


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
	_dash_buffer_timer = maxf(_dash_buffer_timer - delta, 0.0)
	_wall_lock_timer = maxf(_wall_lock_timer - delta, 0.0)
	_recoil_timer = maxf(_recoil_timer - delta, 0.0)
	_attack_cooldown_timer = maxf(_attack_cooldown_timer - delta, 0.0)
	_attack_buffer_timer = maxf(_attack_buffer_timer - delta, 0.0)
	_invuln_timer = maxf(_invuln_timer - delta, 0.0)
	_stun_timer = maxf(_stun_timer - delta, 0.0)
	if _platform_drop_timer > 0.0:
		_platform_drop_timer -= delta
		if _platform_drop_timer <= 0.0:
			set_collision_mask_value(PLATFORM_LAYER_NUMBER, true)
	if _dash_timer > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_end_dash()
	if _attack_timer > 0.0:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_attack_shape.set_deferred("disabled", true)


# ------------------------------------------------------ Sprint/Stamina ----

# Drains while sprinting, refills only while standing on ground. Returns
# whether you're sprinting this frame.
func _update_stamina(input_x: float, grounded: bool, delta: float) -> bool:
	var held := Input.is_action_pressed("sprint")
	if not held:
		_sprint_exhausted = false
	var sprinting := held and input_x != 0.0 and not _sprint_exhausted \
			and stamina > 0.0 and GameState.has_ability("sprint")
	if sprinting:
		_set_stamina(stamina - sprint_drain * delta)
		if stamina <= 0.0:
			_sprint_exhausted = true
	elif grounded and _dash_timer <= 0.0:
		_set_stamina(stamina + stamina_regen * delta)
	return sprinting


func _set_stamina(value: float) -> void:
	var clamped := clampf(value, 0.0, max_stamina)
	if clamped != stamina:
		stamina = clamped
		stamina_changed.emit(stamina, max_stamina)


# ---------------------------------------------------------------- Dash ----

## Dashes the way the direction input points, in 8 directions (straight ahead
## with nothing held). On the ground, down is ignored: down-forward dashes
## along the floor.
func _start_dash(input_x: float, input_y: float, on_floor: bool) -> void:
	_set_stamina(stamina - dash_stamina_cost)
	_carried_x = 0.0
	var dir :=Vector2(_dash_axis(input_x), _dash_axis(input_y))
	if on_floor and dir.y > 0.0:
		dir.y = 0.0
	if dir == Vector2.ZERO:
		dir.x = facing
	_dash_dir = dir.normalized()
	if dir.x != 0.0:
		facing = int(dir.x)
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_duration + dash_cooldown
	if not on_floor:
		_air_dash_available = false


## An input axis snapped to -1, 0 or 1 (a stick held about halfway counts).
func _dash_axis(value: float) -> float:
	return signf(value) if absf(value) >= DASH_STICK_THRESHOLD else 0.0


## Keeps some momentum out of the dash, in its direction.
func _end_dash() -> void:
	_dash_timer = 0.0
	velocity = _dash_dir * run_speed
	if _dash_dir.y > 0.0 and is_on_floor():
		velocity.y = 0.0


# -------------------------------------------------------------- Attack ----

## Starts talking to an NPC you can talk to (see NPC.can_talk_to), if there is one.
func _talk_to_nearby() -> bool:
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.can_talk_to(self):
			npc.talk()
			return true
	return false


func _start_attack(input_y: float, on_floor: bool) -> void:
	_attack_timer = attack_duration
	_attack_cooldown_timer = attack_cooldown
	_hit_this_swing.clear()

	var size := SlashEffect.SIDE_FITS   # the side attack, which the slash art fits
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
	_attack_shape.set_deferred("disabled", false)

	_attack_anim = "attack_up" if _attack_dir == Vector2.UP else "attack_down" if _attack_dir == Vector2.DOWN else "attack_side"
	_attack_anim_timer = PlayerSprite.length(_attack_anim)
	_attack_anim_restart = true
	slash.swing(_attack_dir, offset, facing)
	LightFlash.flash(self, offset, slash_flash_color, slash_flash_radius, slash_flash_energy, slash_flash_time)


func _on_attack_body_entered(body: Node) -> void:
	if _hit_this_swing.has(body) or not body.has_method("take_hit"):
		return
	_hit_this_swing[body] = true
	# Read before the hit lands: it can change the target's state (and so its recoil).
	var recoil: Variant = body.current_hit_recoil() if body.has_method("current_hit_recoil") else body.get("hit_recoil")
	body.take_hit(attack_damage, _attack_dir)
	hit_stop(0.05)
	shake(3.0, 0.1)
	_recoil(body, recoil)


func _on_attack_area_entered(area: Area2D) -> void:
	if _hit_this_swing.has(area):
		return
	# Breakable projectiles (the Harrier's homing feather). Hazards like spikes push nothing.
	if area.is_in_group("breakable"):
		_hit_this_swing[area] = true
		area.take_hit(attack_damage, _attack_dir)
		hit_stop(0.03)
		_recoil(area, area.get("hit_recoil"))


## Pushes you away from what the swing hit, along the line from it to you, at
## `speed` px/s (its current_hit_recoil() or hit_recoil; null if it has
## neither, which uses DEFAULT_HIT_RECOIL). Struck from above, that bounces you up and gives back
## the air jump and dash, so a high recoil works like a pogo; struck from the
## side, it shoves you back and you can't steer for recoil_lock_time.
func _recoil(target: Node2D, speed: Variant) -> void:
	var push: float = DEFAULT_HIT_RECOIL if speed == null else speed
	if push <= 0.0:
		return
	var away := (global_position - target.global_position).normalized()
	if away == Vector2.ZERO:
		away = -_attack_dir
	velocity = away * push
	_carried_x = 0.0
	if away.y < -RECOIL_MOSTLY:
		_air_dash_available = true
		_air_jump_available = true
		_hit_this_swing.clear()
	if absf(away.x) > RECOIL_MOSTLY:
		_recoil_timer = recoil_lock_time


# -------------------------------------------------------------- Damage ----

func _check_hurtbox() -> void:
	# Lethal hazards (acid) kill instantly, even through invulnerability frames.
	for area in _hurtbox.get_overlapping_areas():
		if area.is_in_group("lethal_hazard"):
			_last_blow = blow_of(area)
			kill()
			return
	if _invuln_timer > 0.0:
		return
	for area in _hurtbox.get_overlapping_areas():
		if area.is_in_group("hazard"):
			_last_blow = blow_of(area)
			take_damage(damage_of(area), area.global_position, true)
			return
		if area.is_in_group("enemy_hitbox"):
			_last_blow = blow_of(area)
			if take_damage(damage_of(area), area.global_position, false):
				_notify_hit(area)
			return


## True if `hitbox` is touching us and would land a hit right now.
func can_be_hit_by(hitbox: Area2D) -> bool:
	return not _dead and _invuln_timer <= 0.0 and _hurtbox.overlaps_area(hitbox)


# Lets whatever just hit us react: a charge stops, a feather breaks. The hitbox
# itself or its owner (an enemy's contact box) can define on_hit_player().
func _notify_hit(area: Area2D) -> void:
	var source: Node = area if area.has_method("on_hit_player") else area.get_parent()
	if source != null and source.has_method("on_hit_player"):
		source.on_hit_player()


## What a hitbox is, for the death screen: its "blow" meta, a translation key
## for the whole message ("Impaled on the spikes"), set by whatever made it.
static func blow_of(area: Area2D) -> String:
	return area.get_meta("blow", BLOW_UNKNOWN)


## How hard a hitbox hits, in half-hearts. Enemies and hazards set it as a
## "damage" meta on their hitbox Area2D.
static func damage_of(area: Area2D) -> int:
	return area.get_meta("damage", DEFAULT_HIT_DAMAGE)


## Armor: flat reduction first, then percentage. A hit can be reduced to 0
## (it still knocks you back), never below.
func reduce_damage(amount: int) -> int:
	var after_flat := maxi(amount - armor_flat, 0)
	return roundi(after_flat * (1.0 - clampf(armor_percent, 0.0, 1.0)))


## Most health and attack damage: as set, plus what your items add.
func _apply_items() -> void:
	max_health = _base_max_health + GameState.max_health_bonus()
	attack_damage = _base_attack_damage + GameState.damage_bonus()


## A new item: its bonuses apply at once, and a new heart comes full.
func _on_item_received(item: Item) -> void:
	_apply_items()
	if item.max_health_bonus > 0 and not _dead:
		health = mini(health + item.max_health_bonus, max_health)
	health_changed.emit(health, max_health)


func heal(amount: int) -> void:
	if _dead:
		return
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)


# Lethal: skips armor and invulnerability.
func kill() -> void:
	_invuln_timer = 0.0
	_apply_damage(health, global_position, true)


## Returns whether the hit landed (false while invulnerable or dead).
func take_damage(amount: int, source_position: Vector2, is_hazard: bool) -> bool:
	return _apply_damage(reduce_damage(amount), source_position, is_hazard)


func _apply_damage(amount: int, source_position: Vector2, is_hazard: bool) -> bool:
	if _dead or _invuln_timer > 0.0:
		return false
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
		killed_by = _last_blow
		visible = false
		died.emit()
		return true

	_carried_x = 0.0
	_platform_velocity = Vector2.ZERO
	if is_hazard:
		# Hollow Knight-style: hazards hurt, then put you back on safe ground.
		global_position = last_safe_position
		velocity = Vector2.ZERO
	else:
		var away := signf(global_position.x - source_position.x)
		if away == 0.0:
			away = -facing
		velocity = Vector2(away * knockback.x, knockback.y)
	return true


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


# ------------------------------------------------------------ Animation ----

## Picks the sprite's animation from what the player is doing, and which way
## it faces: wall sliding faces away from the wall. Dash and stun tint it.
func _update_animation(delta: float) -> void:
	_land_anim_timer = maxf(_land_anim_timer - delta, 0.0)
	_wall_jump_anim_timer = maxf(_wall_jump_anim_timer - delta, 0.0)
	_double_jump_anim_timer = maxf(_double_jump_anim_timer - delta, 0.0)
	_attack_anim_timer = maxf(_attack_anim_timer - delta, 0.0)
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_land_anim_timer = LAND_ANIM_TIME
	_was_on_floor = on_floor

	var anim := "idle"
	if _dash_timer > 0.0:
		anim = "dash"
	elif _attack_anim_timer > 0.0:
		anim = _attack_anim
	elif _wall_sliding:
		anim = "wall_slide"
	elif not on_floor:
		if _wall_jump_anim_timer > 0.0:
			anim = "wall_jump"
		elif _double_jump_anim_timer > 0.0:
			anim = "double_jump"
		elif velocity.y < 0.0:
			anim = "jump"
		else:
			anim = "fall"
	elif absf(velocity.x) > 20.0:
		anim = "sprint" if _sprinting else "run"
	elif _land_anim_timer > 0.0:
		anim = "land"
	sprite.play_state(anim, _attack_anim_restart and anim == _attack_anim)
	_attack_anim_restart = false
	var away_from_wall := _wall_sliding and _attack_anim_timer <= 0.0
	sprite.flip_h = (int(signf(_wall_normal_x)) if away_from_wall else facing) < 0
	# Dashing up or down tilts the body that way, front first.
	sprite.rotation = atan2(_dash_dir.y, absf(_dash_dir.x)) * facing if _dash_timer > 0.0 else 0.0

	if _dash_timer > 0.0:
		sprite.self_modulate = Color(0.6, 0.95, 1.0)
	elif _stun_timer > 0.0:
		sprite.self_modulate = Color(1.0, 0.6, 0.6)
	else:
		sprite.self_modulate = Color.WHITE
