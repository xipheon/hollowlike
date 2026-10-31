class_name HarrierFeather
extends Area2D
## The Harrier's ranged shot: flies until it hits a wall, the floor or you.
## A homing feather is slow, curves toward you, and can be struck down with an
## attack (a down-strike bounces off it). It only ever heads downward, within
## MAX_TILT of straight down, and once it has seen you it can't turn tighter
## than min_turn_radius, so a quick sidestep dodges it. Damage comes from the
## "damage" meta the Harrier sets.

const LENGTH := 22.0
const MAX_TILT := 70.0 * PI / 180.0   ## homing: furthest from straight down it will fly

var direction := Vector2.RIGHT
var speed := 230.0
var homing := false
var turn_rate := 2.2               ## radians per second, homing only
var min_turn_radius := 150.0       ## px; homing, once it has seen the player
var lifetime := 3.0

var _age := 0.0
var _seen_player := false
var _heading_down := false   # inside the downward cone; from then on it stays there


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
		_steer(delta)
	var step := direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + step + direction * LENGTH * 0.5, 1)
	if _age > lifetime or not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		queue_free()
		return
	global_position += step
	queue_redraw()


## Signed angle from straight down; positive leans left.
func tilt() -> float:
	return wrapf(direction.angle() - PI * 0.5, -PI, PI)


func _steer(delta: float) -> void:
	# Launched outside the downward cone (fired sideways or up): swing down into it first.
	if not _heading_down:
		var back := clampf(-tilt(), -turn_rate * delta, turn_rate * delta)
		direction = direction.rotated(back)
		_heading_down = absf(tilt()) <= MAX_TILT
		rotation = direction.angle()
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty() or not players[0].visible:
		return
	var target: Vector2 = players[0].global_position
	if not _seen_player:
		var sight := PhysicsRayQueryParameters2D.create(global_position, target, 1)
		_seen_player = get_world_2d().direct_space_state.intersect_ray(sight).is_empty()
	var rate := turn_rate
	if _seen_player:
		rate = minf(rate, speed / min_turn_radius)
	var want := wrapf((target - global_position).angle() - direction.angle(), -PI, PI)
	var lean := tilt()
	if signf(want) == signf(lean):
		# Turning further from vertical: slower the nearer it is to its limit.
		rate *= clampf(1.0 - absf(lean) / MAX_TILT, 0.0, 1.0)
	direction = direction.rotated(clampf(want, -rate * delta, rate * delta))
	lean = tilt()
	if absf(lean) > MAX_TILT:
		direction = Vector2.DOWN.rotated(signf(lean) * MAX_TILT)
	rotation = direction.angle()


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
