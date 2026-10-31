class_name HarrierBoss
extends BossBase
## Flying arena boss. Sleeps until activate(), then repeats an attack cycle:
##   two feather fans and a homing volley (hovering close to you), then a few
##   shallow swoops and a full swoop (retreating to the far side of the arena
##   from you before each). Phase two fires two homing feathers instead of one.
## Each new cycle starts once the full swoop is over, crash or not.
##   Fan:     flashes cyan, then throws three feathers in a spread at you.
##   Homing:  flashes violet, then releases slow feathers that curve toward
##            you from different angles. Strike them down, or dodge until they
##            hit a wall or the floor. It waits for them to be gone.
##   Shallow: brief yellow flash, then a fast pass from one side of the arena
##            to the other, diving steeply to skim the floor under you and climbing out
##            again without touching the floor.
##   Full:    flashes orange, then dives in a straight line at the floor under you.
##            Hits you -> pulls straight back up. Misses -> crashes into the
##            floor and lies dazed.
## Armoured: takes half damage, except while dazed (full damage). Below half
## health it moves faster. Grants wall jump.

const SIZE := Vector2(52, 36)
const HITBOX_SIZE := SIZE - Vector2(6, 6)
const LAYER_WORLD := 1
const MIN_DIVE_STEEPNESS := 0.2   # dives always head this much downward, so they reach the floor
const SHALLOW_FLOOR_CLEARANCE := SIZE.y * 0.5 + 6.0   # lowest a shallow pass goes (centre above floor)
const ARENA_MARGIN := SIZE.x * 0.5 + 16.0   # how close to the walls it flies
const HOVER_ARRIVE_DISTANCE := 24.0   # within this of its hover spot, it starts counting down

enum State { DORMANT, HOVER, SHOT_WINDUP, HOMING_WINDUP, WAIT_HOMING, SHALLOW_WINDUP, SHALLOW,
		SWOOP_WINDUP, SWOOP, DAZED, RISE, DEAD }

@export var damage := 2                  ## contact, in half-hearts
@export var shot_damage := 1             ## per feather, in half-hearts
@export_range(0.0, 1.0) var damage_reduction := 0.5   ## fraction of each hit blocked, unless dazed
@export var hover_speed := 520.0
@export var hover_height := 4.5          ## tiles below the ceiling it waits at before swoops
@export var close_hover_distance := 3.5  ## tiles to the side of the player it waits at for feathers
@export var close_hover_height := 5.5    ## tiles below the ceiling, for feathers
@export var hover_time := 1.1            ## before each cycle
@export var chain_gap := 0.35            ## between attacks within a cycle
@export var shallow_swoop_count := 2
@export var shot_count := 3              ## volleys per cycle; the last one is the homing volley
@export var shot_windup_time := 0.3
@export var shot_speed := 230.0
@export var fan_spread_degrees := 18.0   ## angle between the three feathers of a fan
@export var homing_windup_time := 0.5
@export var homing_speed := 170.0
@export var homing_count_phase_one := 1
@export var homing_count_phase_two := 3
@export var homing_spread_degrees := 120.0   ## angle between homing feathers when there are two or more
@export var shallow_windup_time := 0.22
@export var shallow_speed := 800.0
@export var windup_time := 0.45          ## full swoop
@export var swoop_speed := 960.0
@export var dazed_time := 1.8
@export var rise_speed := 320.0
@export var gravity := 2000.0            ## only while dazed or dead
@export var phase_two_speedup := 1.3

var _state := State.DORMANT
var _timer := 0.0
var _dir := -1
var _flash_timer := 0.0
var _swoop_dir := Vector2.DOWN
var _hover_side := 1       # which wall it hangs back by for swoops: -1 left, 1 right
var _close_side := 1       # which side of the player it hangs by for feathers
var _damage_carry := 0.0   # reduced hits leave fractions; they add up across hits
var _plan: Array[String] = []   # attacks left in the current cycle
var _homing: Array[HarrierFeather] = []   # live homing feathers it's waiting on
# Shallow pass: from _path_from across to _path_end_x, bottoming out at _path_low.
var _path_from := Vector2.ZERO
var _path_end_x := 0.0
var _path_low := Vector2.ZERO
var _path_t := 0.0
var _path_duration := 1.0
var _hitbox: Area2D
var _hit_shape: CollisionShape2D


func _init() -> void:
	boss_name = "THE HARRIER"
	reward_ability = "wall_jump"
	max_health = 32


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
	_hover(hover_time)


func is_dazed() -> bool:
	return _state == State.DAZED


func _speed() -> float:
	return phase_two_speedup if is_phase_two() else 1.0


func _physics_process(delta: float) -> void:
	_flash_timer = maxf(_flash_timer - delta, 0.0)
	var tick := delta * (_speed() if _state in [State.HOVER, State.SHOT_WINDUP, State.HOMING_WINDUP, State.SWOOP_WINDUP] else 1.0)
	if _state == State.HOVER and global_position.distance_to(_hover_spot()) > HOVER_ARRIVE_DISTANCE:
		tick = 0.0   # get back to the far side before the next attack
	_timer -= tick

	match _state:
		State.DORMANT:
			velocity = Vector2.ZERO
		State.HOVER, State.SHOT_WINDUP, State.HOMING_WINDUP, State.WAIT_HOMING:
			_hover_toward_spot(delta)
			if _state == State.WAIT_HOMING:
				_homing = _homing.filter(func(f): return is_instance_valid(f))
				if _homing.is_empty():
					_hover(chain_gap)
			elif _timer <= 0.0:
				match _state:
					State.SHOT_WINDUP:
						_fire_fan()
						_hover(chain_gap)
					State.HOMING_WINDUP:
						_fire_homing()
						_enter(State.WAIT_HOMING, 0.0)
					_:
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
				_hover(hover_time)

	move_and_slide()

	if _state == State.SHALLOW and (_path_t >= 1.0 or is_on_wall() or is_on_floor() or is_on_ceiling()):
		_hover(chain_gap)
	elif _state == State.SWOOP:
		if is_on_floor() and _about_to_hit_player():
			_enter(State.RISE, 3.0)   # reached you and the floor in the same frame: it's a hit, not a crash
		elif is_on_floor():
			_crash()
		elif (is_on_wall() and get_wall_normal().dot(_swoop_dir) < -0.1) or is_on_ceiling() or _timer <= 0.0:
			_enter(State.RISE, 3.0)   # flew into a wall: no daze (not one it's leaving)
	queue_redraw()


## Called by the player when our contact hitbox lands a hit. A full swoop that
## connects pulls straight back up instead of crashing.
func on_hit_player() -> void:
	if _state == State.SWOOP:
		_enter(State.RISE, 3.0)


func _enter(state: State, time: float) -> void:
	_state = state
	_timer = time


# Pick where to wait before the next attack: for swoops, the far side of the
# arena from the player; for feathers, near them on whichever side it's on.
func _hover(time: float) -> void:
	if is_instance_valid(_target):
		var px := _target.global_position.x
		_hover_side = 1 if px < (arena_left + arena_right) * 0.5 else -1
		_close_side = 1 if global_position.x >= px else -1
	_enter(State.HOVER, time)


## True while it's (about to be) throwing feathers: it hangs close for those.
func is_feather_phase() -> bool:
	if _state in [State.SHOT_WINDUP, State.HOMING_WINDUP, State.WAIT_HOMING]:
		return true
	# Waiting to start the next attack: a fresh cycle opens with feathers.
	return _state == State.HOVER and (_plan.is_empty() or _plan[0] in ["shot", "homing"])


func _hover_spot() -> Vector2:
	if is_feather_phase() and is_instance_valid(_target):
		# Up and to one side of the player, following them; switches sides
		# rather than pressing into a wall.
		var lo := arena_left + ARENA_MARGIN
		var hi := arena_right - ARENA_MARGIN
		var x := _target.global_position.x + _close_side * close_hover_distance * 32.0
		if x < lo or x > hi:
			_close_side = -_close_side
			x = clampf(_target.global_position.x + _close_side * close_hover_distance * 32.0, lo, hi)
		return Vector2(x, arena_top + close_hover_height * 32.0)
	# High up, by the wall on the side away from the player.
	var far_x := arena_right - ARENA_MARGIN if _hover_side > 0 else arena_left + ARENA_MARGIN
	return Vector2(far_x, arena_top + hover_height * 32.0)


func _hover_toward_spot(delta: float) -> void:
	# Full speed, easing in over the last couple of tiles, never overshooting.
	var to_spot := _hover_spot() - global_position
	var speed := minf(hover_speed * _speed(), to_spot.length() * 6.0)
	velocity = to_spot.normalized() * minf(speed, to_spot.length() / delta)
	_face_target()


func _face_target() -> void:
	if is_instance_valid(_target):
		var dx := _target.global_position.x - global_position.x
		if absf(dx) > 4.0:
			_dir = int(signf(dx))


func _aim_at_target() -> Vector2:
	if is_instance_valid(_target):
		return (_target.global_position - global_position).normalized()
	return Vector2(_dir, 1).normalized()


# Starts the next attack in the cycle, planning a new cycle when the last one is done.
func _next_attack() -> void:
	if _plan.is_empty():
		for i in shot_count - 1:
			_plan.append("shot")
		_plan.append("homing")
		for i in shallow_swoop_count:
			_plan.append("shallow")
		_plan.append("swoop")
	_face_target()
	match _plan.pop_front():
		"shot":
			_enter(State.SHOT_WINDUP, shot_windup_time)
		"homing":
			_enter(State.HOMING_WINDUP, homing_windup_time)
		"shallow":
			_enter(State.SHALLOW_WINDUP, shallow_windup_time)
		"swoop":
			_start_windup()


func _fire_fan() -> void:
	attack_log.append("shot")
	var aim := _aim_at_target()
	for i in [-1, 0, 1]:
		_spawn_feather(aim.rotated(deg_to_rad(fan_spread_degrees) * i), shot_speed, false)


# Homing feathers start fanned out (so they arrive from different angles)
# and curve in.
func _fire_homing() -> void:
	attack_log.append("homing")
	var count := homing_count_phase_two if is_phase_two() else homing_count_phase_one
	var aim := _aim_at_target()
	for i in count:
		var offset := 0.0 if count == 1 else lerpf(-0.5, 0.5, float(i) / (count - 1)) * deg_to_rad(homing_spread_degrees)
		_homing.append(_spawn_feather(aim.rotated(offset), homing_speed, true))


func _spawn_feather(direction: Vector2, speed: float, homing: bool) -> HarrierFeather:
	var feather := HarrierFeather.new()
	feather.direction = direction
	feather.speed = speed * _speed()
	feather.homing = homing
	if homing:
		feather.lifetime = 7.0   # a safety net; walls, floor, you or an attack end it first
	feather.set_meta("damage", shot_damage)
	feather.position = global_position
	get_parent().add_child(feather)
	return feather


# Locks the pass onto the player's x: wall to wall across the arena, diving steeply
# to skim the floor under them and climbing out again, never touching it.
func _start_shallow() -> void:
	attack_log.append("shallow")
	# Only the player's x counts: it always bottoms out just above the floor.
	var low := Vector2((arena_left + arena_right) * 0.5, arena_bottom - SHALLOW_FLOOR_CLEARANCE)
	if is_instance_valid(_target):
		low.x = _target.global_position.x
	var heading := signf(low.x - global_position.x)
	if heading == 0.0:
		heading = -_hover_side
	_path_from = global_position
	_path_end_x = arena_right - ARENA_MARGIN if heading > 0.0 else arena_left + ARENA_MARGIN
	_path_low = low
	var span := absf(_path_end_x - _path_from.x)
	_path_duration = maxf((span + 2.0 * (low.y - _path_from.y)) / shallow_speed, 0.4)
	_path_t = 0.0
	_enter(State.SHALLOW, 0.0)


# x moves steadily wall to wall; y eases down to the low point (steep at first,
# levelling out under the player) and back up the same way on the far side.
func _shallow_point(t: float) -> Vector2:
	var x := lerpf(_path_from.x, _path_end_x, t)
	var span := _path_end_x - _path_from.x
	var low_t := clampf((_path_low.x - _path_from.x) / span, 0.15, 0.85) if span != 0.0 else 0.5
	var depth := _path_low.y - _path_from.y
	var y: float
	if t < low_t:
		y = _path_from.y + depth * sin(PI * 0.5 * t / low_t)
	else:
		y = _path_from.y + depth * sin(PI * 0.5 * (1.0 - t) / (1.0 - low_t))
	return Vector2(x, y)


# Locks the dive line onto the floor under the player right now (their height
# doesn't matter: it always dives to the ground).
func _start_windup() -> void:
	var aim_x := global_position.x + _dir * 32.0
	if is_instance_valid(_target):
		aim_x = _target.global_position.x
	# Aim our centre a hair below body height above the floor: we pass through
	# a standing player there and hit the ground just beyond.
	var aim_y := arena_bottom - SIZE.y * 0.5 + 4.0
	_swoop_dir = (Vector2(aim_x, aim_y) - global_position).normalized()
	if _swoop_dir.y < MIN_DIVE_STEEPNESS:
		_swoop_dir = Vector2(signf(_swoop_dir.x) * sqrt(1.0 - MIN_DIVE_STEEPNESS ** 2), MIN_DIVE_STEEPNESS)
	_face_target()
	_enter(State.SWOOP_WINDUP, windup_time)


## True if our contact box is on the player and will hurt them this frame. A
## fast swoop can touch you on the same frame it touches the floor, and the
## player only registers the hit (on_hit_player) after we've moved.
func _about_to_hit_player() -> bool:
	for player in get_tree().get_nodes_in_group("player"):
		if player.can_be_hit_by(_hitbox):
			return true
	return false


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
	match _state:
		State.SWOOP_WINDUP:
			body = Color(1.0, 0.55, 0.15)   # telegraphs: orange = full dive,
		State.SHALLOW_WINDUP:
			body = Color(1.0, 0.9, 0.3)     # yellow = shallow pass,
		State.SHOT_WINDUP:
			body = Color(0.55, 0.95, 1.0)   # cyan = feather fan,
		State.HOMING_WINDUP:
			body = Color(0.8, 0.6, 1.0)     # violet = homing feathers
		State.DAZED, State.DEAD:
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
