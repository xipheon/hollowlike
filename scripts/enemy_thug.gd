class_name ThugEnemy
extends EnemyBase
## Street thug, as tall as the player. Patrols, now and then stopping for a
## moment, walks toward you when it sees you, and once you're inside its
## punch's reach (punch_size) raises its guard (glowing orange) then throws the
## punch, a red swoosh showing exactly how far it reaches. The punch is slow to
## start: step back, or hit it first.
## It blocks with its guard up (the first frame of its punch): while paused,
## while winding up, and while standing still watching you from a ledge. A hit
## then does block_reduction less damage, and its flash is blue-grey. Walking,
## punching and recovering from the punch, it can't block.
## Place scenes/enemies/thug.tscn and set it up in the Inspector. Its type's
## defaults (5 health, 8 damage, a light hit_recoil of 180) are set in that
## scene, along with its Sprite (art/sprites/thug_frames.tres, built by
## tools/make_thug_sheet.gd).

const SIZE := Vector2(24, 44)
const PUNCH_BLOW := "UI_DEATH_BY_THUG_PUNCH"   # the death screen's message for the punch
const PUNCH_EFFECT_COLOR := Color(1.0, 0.25, 0.2)   # the player's slash, in red
const FLASH := Color(2.5, 2.5, 2.5)          # hit: brightens towards white
const BLOCK_FLASH := Color(0.6, 0.8, 1.6)    # blocked hit: a cold blue-grey
const TELEGRAPH := Color(1.6, 1.0, 0.45)     # winding up: orange

enum State { PATROL, PAUSE, WINDUP, SWING, RECOVER }

@export var walk_speed := 90.0
@export var gravity := 1800.0
@export var sight_range := 220.0     ## starts walking toward you within this
## The punch's reach: its hit box in front of it, which its red swoosh fills. It
## starts a punch only once you're inside it.
@export var punch_size := Vector2(46, 28)
@export var windup_time := 0.30
@export var swing_time := 0.15
@export var recover_time := 0.8
## Damage taken off each hit while it's blocking (see the class description).
@export var block_reduction := 1
## Seconds it patrols between pauses: a random time in this range.
@export var patrol_time := Vector2(2.5, 5.0)
## Seconds each pause lasts.
@export var pause_time := 1.0

var swings := 0   # punches started; handy for tests and debugging
var sprite: AnimatedSprite2D
var punch_effect: SlashEffect   # the red swoosh over the punch's reach

var _state := State.PATROL
var _timer := 0.0
var _dir := -1
var _standing := false   # patrolling, but stopped at a ledge watching the player
var _patrol_left := 0.0  # until the next pause
var _last_hit_blocked := false
var _knockback := 0.0
var _ledge_ray: RayCast2D
var _punch_shape: CollisionShape2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	add_child(shape)

	add_child(make_contact_hitbox(SIZE - Vector2(4, 4)))
	var punch := make_contact_hitbox(punch_size)
	punch.set_meta("blow", PUNCH_BLOW)
	_punch_shape = punch.get_child(0)
	_punch_shape.disabled = true
	add_child(punch)
	punch_effect = SlashEffect.new()
	punch_effect.modulate = PUNCH_EFFECT_COLOR
	punch_effect.scale = punch_size / SlashEffect.SIDE_FITS
	add_child(punch_effect)

	_ledge_ray = RayCast2D.new()
	_ledge_ray.target_position = Vector2(0, SIZE.y * 0.5 + 10)
	_ledge_ray.collision_mask = 1 | 32
	add_child(_ledge_ray)

	sprite = $Sprite
	_rng.randomize()
	_patrol_left = _next_patrol()
	_set_dir(_dir)


func _physics_process(delta: float) -> void:
	var flashing := _flashing(delta)
	_timer -= delta
	velocity.y += gravity * delta
	var player := _find_player()
	var sees_player := player != null and _can_see(player)
	_standing = false

	match _state:
		State.PATROL:
			var speed := walk_speed
			if sees_player:
				_set_dir(int(signf(player.global_position.x - global_position.x)))
				if in_punch_reach(player):
					_enter(State.WINDUP, windup_time)
					speed = 0.0
			var wall_ahead := is_on_wall() and get_wall_normal().x * _dir < 0.0
			if speed > 0.0 and is_on_floor() and (wall_ahead or not _ledge_ray.is_colliding()):
				if sees_player:
					speed = 0.0   # wait at the edge rather than walking off
					_standing = true
				else:
					_set_dir(-_dir)
			# Now and then, with nobody to chase, it stops for a moment.
			if speed > 0.0 and not sees_player:
				_patrol_left -= delta
				if _patrol_left <= 0.0:
					_enter(State.PAUSE, pause_time)
					speed = 0.0
			velocity.x = _dir * speed   # after any turn, so it walks away from the wall this frame
		State.PAUSE:
			velocity.x = 0.0
			if sees_player or _timer <= 0.0:
				_patrol_left = _next_patrol()
				_enter(State.PATROL, 0.0)
		State.WINDUP:
			velocity.x = 0.0
			if _timer <= 0.0:
				swings += 1
				_punch_shape.set_deferred("disabled", false)
				_enter(State.SWING, swing_time)
		State.SWING:
			velocity.x = _dir * 60.0   # small lunge into the punch
			if not _ledge_ray.is_colliding():
				velocity.x = 0.0
			if _timer <= 0.0:
				_punch_shape.set_deferred("disabled", true)
				_enter(State.RECOVER, recover_time)
		State.RECOVER:
			velocity.x = 0.0
			if _timer <= 0.0:
				_enter(State.PATROL, 0.0)

	if _knockback != 0.0:
		velocity.x += _knockback
		_knockback = move_toward(_knockback, 0.0, 900.0 * delta)
	move_and_slide()
	_update_sprite(flashing)


## Guard up: paused, winding up, or standing at a ledge watching the player.
func is_blocking() -> bool:
	return _state in [State.PAUSE, State.WINDUP] or (_state == State.PATROL and _standing)


func damage_taken(amount: int) -> int:
	_last_hit_blocked = is_blocking()
	return maxi(amount - block_reduction, 0) if _last_hit_blocked else amount


func _enter(state: State, time: float) -> void:
	_state = state
	_timer = time
	if state == State.SWING:
		sprite.play("punch")
		punch_effect.swing(Vector2(_dir, 0), _punch_shape.position, _dir)


func _next_patrol() -> float:
	return _rng.randf_range(patrol_time.x, patrol_time.y)


func _set_dir(dir: int) -> void:
	if dir == 0:
		return
	_dir = dir
	_ledge_ray.position.x = _dir * (SIZE.x * 0.5 + 4)
	_ledge_ray.force_raycast_update()
	_punch_shape.position = Vector2(_dir * (SIZE.x * 0.5 + punch_size.x * 0.5 - 4), -4)


func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() and players[0].visible else null


## Whether the player's body is inside the punch's reach (its hit box, facing
## the way it faces now).
func in_punch_reach(player: Node2D) -> bool:
	var reach := Rect2(global_position + _punch_shape.position - punch_size * 0.5, punch_size)
	var body := Rect2(player.global_position - Player.BODY_SIZE * 0.5, Player.BODY_SIZE)
	return reach.intersects(body)


# Roughly level with us and within sight range.
func _can_see(player: Node2D) -> bool:
	var d := player.global_position - global_position
	return absf(d.x) <= sight_range and absf(d.y) <= SIZE.y


func _on_hit(hit_dir: Vector2) -> void:
	if hit_dir.x != 0.0:
		_knockback = signf(hit_dir.x) * 160.0   # heavy: shoved, not staggered


## Walks, guards, punches or stands, facing its way, tinted for hits and the wind-up.
func _update_sprite(flashing: bool) -> void:
	sprite.flip_h = _dir < 0
	var anim := "walk"
	match _state:
		State.SWING:
			anim = "punch"
		State.RECOVER:
			anim = "idle"
		_:
			if is_blocking():
				anim = "block"
			elif absf(velocity.x) < 1.0:
				anim = "idle"
	if sprite.animation != anim:
		sprite.play(anim)
	if flashing:
		sprite.self_modulate = BLOCK_FLASH if _last_hit_blocked else FLASH
	elif _state == State.WINDUP:
		sprite.self_modulate = TELEGRAPH
	else:
		sprite.self_modulate = Color.WHITE
