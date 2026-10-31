class_name HarrierBoss
extends BossBase
## Flying arena boss. Sleeps until activate(), then repeats an attack cycle,
## hovering high above you between attacks:
##   Phase one: a few shallow swoops, then a full swoop.
##   Phase two: a few feather shots, then the shallow swoops, then a full swoop.
## Each new cycle starts once the full swoop is over, crash or not.
##   Shot:    flashes cyan, then throws a feather straight at you.
##   Shallow: brief yellow flash, then a fast U-shaped pass that dips to your
##            height but never reaches the floor.
##   Full:    flashes orange, then dives in a straight line at where you stood.
##            Hits you -> pulls straight back up. Misses -> crashes into the
##            floor and lies dazed.
## Armoured: takes half damage, except while dazed (full damage). Below half
## health it moves faster. Grants wall jump.

const SIZE := Vector2(52, 36)
const HITBOX_SIZE := SIZE - Vector2(6, 6)
const FOLLOW_THROUGH := 0.08   # keeps diving this long after contact so the hit registers
const LAYER_WORLD := 1
const MIN_DIVE_STEEPNESS := 0.45   # dives always head this much downward, so they reach the floor
const SHALLOW_MIN_SPAN := 4.0 * 32.0   # a shallow pass carries at least this far past you
const SHALLOW_FLOOR_CLEARANCE := 48.0  # its lowest point stays this far above the floor (centre)

enum State { DORMANT, HOVER, SHOT_WINDUP, SHALLOW_WINDUP, SHALLOW, SWOOP_WINDUP, SWOOP, DAZED, RISE, DEAD }

@export var damage := 2                  ## contact, in half-hearts
@export var shot_damage := 1             ## per feather, in half-hearts
@export_range(0.0, 1.0) var damage_reduction := 0.5   ## fraction of each hit blocked, unless dazed
@export var hover_speed := 420.0
@export var hover_height := 4.5          ## tiles below the ceiling it hovers at
@export var hover_time := 1.1            ## before each cycle
@export var chain_gap := 0.35            ## between attacks within a cycle
@export var shallow_swoop_count := 2
@export var shot_count := 3              ## phase two only
@export var shot_windup_time := 0.3
@export var shot_speed := 460.0
@export var shallow_windup_time := 0.22
@export var shallow_speed := 620.0
@export var windup_time := 0.45          ## full swoop
@export var swoop_speed := 760.0
@export var dazed_time := 1.8
@export var rise_speed := 320.0
@export var gravity := 2000.0            ## only while dazed or dead
@export var phase_two_speedup := 1.3

var _state := State.DORMANT
var _timer := 0.0
var _dir := -1
var _flash_timer := 0.0
var _swoop_dir := Vector2.DOWN
var _hover_side := 1
var _damage_carry := 0.0   # reduced hits leave fractions; they add up across hits
var _swoop_hit := false    # this dive connected: pull up instead of crashing
var _plan: Array[String] = []   # attacks left in the current cycle
# Shallow pass: from _path_from across to _path_end_x, dipping to _path_low_y.
var _path_from := Vector2.ZERO
var _path_end_x := 0.0
var _path_low_y := 0.0
var _path_t := 0.0
var _path_duration := 1.0
var _hitbox: Area2D
var _hit_shape: CollisionShape2D


func _init() -> void:
	boss_name = "THE HARRIER"
	reward_ability = "wall_jump"
	max_health = 16


func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	collision_layer = 4    # enemy
	collision_mask = LAYER_WORLD   # flies through one-way platforms

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	add_child(shape)

	_hitbox = Area2D.new()
	_hitbox.add_to_group("enemy_hitbox")
	_hitbox.set_meta("damage", damage)   # read by the player's hurtbox
	_hitbox.collision_layer = 16   # hazard layer, which the player's hurtbox watches
	_hitbox.collision_mask = 0
	_hitbox.monitoring = false
	_hit_shape = CollisionShape2D.new()
	var hit_rect := RectangleShape2D.new()
	hit_rect.size = HITBOX_SIZE
	_hit_shape.shape = hit_rect
	_hitbox.add_child(_hit_shape)
	add_child(_hitbox)


func activate(target: Node2D) -> void:
	super(target)
	_enter(State.HOVER, hover_time)


func is_dazed() -> bool:
	return _state == State.DAZED


func _speed() -> float:
	return phase_two_speedup if is_phase_two() else 1.0


func _physics_process(delta: float) -> void:
	_flash_timer = maxf(_flash_timer - delta, 0.0)
	_timer -= delta * (_speed() if _state in [State.HOVER, State.SHOT_WINDUP, State.SWOOP_WINDUP] else 1.0)

	match _state:
		State.DORMANT:
			velocity = Vector2.ZERO
		State.HOVER, State.SHOT_WINDUP:
			_hover_toward_spot(delta)
			if _timer <= 0.0:
				if _state == State.SHOT_WINDUP:
					_fire_feather()
					_enter(State.HOVER, chain_gap)
				else:
					_next_attack()
		State.SHALLOW_WINDUP:
			velocity = Vector2(-_dir * 60.0, -30.0)   # quick flinch back
			if _timer <= 0.0:
				_start_shallow()
		State.SHALLOW:
			_path_t = minf(_path_t + delta * _speed() / _path_duration, 1.0)
			velocity = (_shallow_point(_path_t) - global_position) / delta
		State.SWOOP_WINDUP:
			velocity = -_swoop_dir * 40.0   # rears back
			if _timer <= 0.0:
				attack_log.append("swoop")
				_swoop_hit = false
				_enter(State.SWOOP, 2.5)
		State.SWOOP:
			velocity = _swoop_dir * swoop_speed * _speed()
		State.DAZED, State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
			velocity.y = minf(velocity.y + gravity * delta, 1200.0)
			if _state == State.DAZED and _timer <= 0.0:
				_set_hitbox_active(true)
				_enter(State.RISE, 3.0)
		State.RISE:
			velocity = Vector2(0, -rise_speed * _speed())
			if global_position.y <= _hover_spot().y or _timer <= 0.0 or is_on_ceiling():
				_enter(State.HOVER, hover_time)

	move_and_slide()

	if _state == State.SHALLOW and (_path_t >= 1.0 or is_on_wall() or is_on_floor() or is_on_ceiling()):
		_enter(State.HOVER, chain_gap)
	elif _state == State.SWOOP:
		if not _swoop_hit and _touching_target(HITBOX_SIZE):
			_swoop_hit = true   # got you: follow through a moment, then pull up
			_timer = minf(_timer, FOLLOW_THROUGH)
		if is_on_floor() and not _swoop_hit:
			_crash()
		elif is_on_floor() or is_on_wall() or is_on_ceiling() or _timer <= 0.0:
			_enter(State.RISE, 3.0)   # hit you, or glanced off a wall: no daze
	queue_redraw()


func _enter(state: State, time: float) -> void:
	_state = state
	_timer = time


# High above the player, a little to one side, inside the arena.
func _hover_spot() -> Vector2:
	var x := global_position.x
	if is_instance_valid(_target):
		x = _target.global_position.x + _hover_side * 3.0 * 32.0
	var margin := SIZE.x * 0.5 + 16.0
	x = clampf(x, arena_left + margin, arena_right - margin)
	return Vector2(x, arena_top + hover_height * 32.0)


func _hover_toward_spot(delta: float) -> void:
	var to_spot := _hover_spot() - global_position
	velocity = to_spot.limit_length(hover_speed * _speed())
	if to_spot.length() < 6.0:
		velocity = to_spot / delta * 0.5
	_face_target()


func _face_target() -> void:
	if is_instance_valid(_target):
		var dx := _target.global_position.x - global_position.x
		if absf(dx) > 4.0:
			_dir = int(signf(dx))


# Starts the next attack in the cycle, planning a new cycle when the last one is done.
func _next_attack() -> void:
	if _plan.is_empty():
		if is_phase_two():
			for i in shot_count:
				_plan.append("shot")
		for i in shallow_swoop_count:
			_plan.append("shallow")
		_plan.append("swoop")
	match _plan.pop_front():
		"shot":
			_face_target()
			_enter(State.SHOT_WINDUP, shot_windup_time)
		"shallow":
			_face_target()
			_enter(State.SHALLOW_WINDUP, shallow_windup_time)
		"swoop":
			_start_windup()


func _fire_feather() -> void:
	attack_log.append("shot")
	var aim := global_position + Vector2(_dir, 1)
	if is_instance_valid(_target):
		aim = _target.global_position
	var feather := HarrierFeather.new()
	feather.direction = (aim - global_position).normalized()
	feather.speed = shot_speed * _speed()
	feather.set_meta("damage", shot_damage)
	feather.position = global_position
	get_parent().add_child(feather)


# Locks the pass onto the player: across and past them, dipping to their
# height (clipping a standing player's head), never down to the floor.
func _start_shallow() -> void:
	attack_log.append("shallow")
	var target := global_position + Vector2(_dir * SHALLOW_MIN_SPAN, 4.0 * 32.0)
	if is_instance_valid(_target):
		target = _target.global_position
	var dir := signf(target.x - global_position.x)
	if dir == 0.0:
		dir = _dir
	var margin := SIZE.x * 0.5 + 16.0
	_path_from = global_position
	_path_end_x = clampf(target.x + dir * maxf(absf(target.x - global_position.x), SHALLOW_MIN_SPAN),
			arena_left + margin, arena_right - margin)
	_path_low_y = maxf(minf(target.y - 26.0, arena_bottom - SHALLOW_FLOOR_CLEARANCE), _path_from.y)
	var length := absf(_path_end_x - _path_from.x) + 2.0 * (_path_low_y - _path_from.y)
	_path_duration = maxf(length / shallow_speed, 0.3)
	_path_t = 0.0
	_hover_side = -_hover_side   # pass ends on the other side; hover there next
	_enter(State.SHALLOW, 0.0)


func _shallow_point(t: float) -> Vector2:
	return Vector2(lerpf(_path_from.x, _path_end_x, t),
			_path_from.y + (_path_low_y - _path_from.y) * sin(PI * t))


# Locks the dive line onto where the player stands right now.
func _start_windup() -> void:
	var aim := global_position + Vector2.DOWN * 100.0
	if is_instance_valid(_target):
		aim = _target.global_position
	_swoop_dir = (aim - global_position).normalized()
	if _swoop_dir.y < MIN_DIVE_STEEPNESS:
		_swoop_dir = Vector2(signf(_swoop_dir.x) * sqrt(1.0 - MIN_DIVE_STEEPNESS ** 2), MIN_DIVE_STEEPNESS)
	_hover_side = -_hover_side   # come back up on the other side next time
	_face_target()
	_enter(State.SWOOP_WINDUP, windup_time)


func _crash() -> void:
	velocity = Vector2.ZERO
	get_tree().call_group("player", "shake", 7.0, 0.25)
	_set_hitbox_active(false)   # lying stunned: safe to stand next to and hit
	_enter(State.DAZED, dazed_time)


func _set_hitbox_active(active: bool) -> void:
	if is_instance_valid(_hit_shape):
		_hit_shape.set_deferred("disabled", not active)


func take_hit(amount: int, _hit_dir: Vector2) -> void:
	if _state == State.DORMANT or _state == State.DEAD:
		return
	var dealt := float(amount)
	if not is_dazed():
		dealt *= 1.0 - clampf(damage_reduction, 0.0, 1.0)
	_damage_carry += dealt
	var whole := floori(_damage_carry + 0.0001)
	_damage_carry -= whole
	_flash_timer = 0.08
	if whole <= 0:
		return   # glanced off the armour; counts toward the next point
	health = maxi(health - whole, 0)
	health_changed.emit(health, max_health)
	if health <= 0:
		become_corpse()
		defeated.emit()


func debug_kill() -> void:
	if _state == State.DEAD:
		return
	health = 0
	health_changed.emit(health, max_health)
	become_corpse()
	defeated.emit()


func become_corpse() -> void:
	health = 0
	_enter(State.DEAD, 0.0)
	remove_from_group("enemy")
	collision_layer = 0   # player attacks pass through; it still falls to the floor
	_hitbox.queue_free()
	queue_redraw()


func _draw() -> void:
	var half := SIZE * 0.5
	var body := Color(0.2, 0.45, 0.5) if not is_phase_two() else Color(0.45, 0.25, 0.55)
	if _state == State.SWOOP_WINDUP:
		body = Color(1.0, 0.55, 0.15)   # telegraphs: orange = full dive,
	elif _state == State.SHALLOW_WINDUP:
		body = Color(1.0, 0.9, 0.3)     # yellow = shallow pass,
	elif _state == State.SHOT_WINDUP:
		body = Color(0.55, 0.95, 1.0)   # cyan = feather
	elif _state in [State.DAZED, State.DEAD]:
		body = body.darkened(0.4)
	if _flash_timer > 0.0:
		body = Color.WHITE
	if _state == State.DEAD:
		# Crumpled on the floor, wings folded.
		draw_rect(Rect2(-half.x, half.y - 14, SIZE.x, 14), body)
		draw_rect(Rect2(_dir * 14 - 6, half.y - 18, 12, 8), Color(0.85, 0.8, 0.65))
		return
	# Wings: raised while flying, spread flat while dazed.
	var wing_tip_y := -half.y - 6.0 if _state != State.DAZED else half.y - 4.0
	for side in [-1, 1]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(side * 6, -4), Vector2(side * (half.x + 18), wing_tip_y), Vector2(side * 10, 8)]),
			body.darkened(0.2))
	draw_rect(Rect2(-half.x * 0.6, -half.y * 0.6, SIZE.x * 0.6, SIZE.y * 0.9), body)
	# Beak and eye, facing the player
	draw_colored_polygon(PackedVector2Array([
		Vector2(_dir * half.x * 0.6, -6), Vector2(_dir * (half.x * 0.6 + 14), 0), Vector2(_dir * half.x * 0.6, 4)]),
		Color(0.9, 0.8, 0.4))
	var eye := Color(1.0, 0.3, 0.2) if is_phase_two() else Color(0.95, 0.95, 0.85)
	draw_rect(Rect2(_dir * 8 - 3, -10, 6, 6), eye)
	if _state == State.DAZED:
		# Circling stars
		var t := Time.get_ticks_msec() / 200.0
		for i in 3:
			var a := t + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * 16, -half.y - 8 + sin(a) * 4), 3.0, Color(1, 0.95, 0.5))
