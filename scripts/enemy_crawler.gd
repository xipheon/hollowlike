class_name CrawlerEnemy
extends EnemyBase
## What every crawler shares: a blob of sewer sludge that oozes along, turns at
## walls and ledges, hurts on contact, and leaves a fading slime trail. It
## melts into a puddle when killed.
## A crawler can start on a ceiling instead (`on_ceiling`): it oozes along
## upside down, and when the player passes underneath it lets go, drops on
## them, and carries on as a floor crawler. Hitting it up there knocks it down.
## Each colour is its own scene, with its sprite already in it (built by
## tools/make_crawler_scenes.gd): scenes/enemies/crawler_sewer.tscn,
## crawler_sickly.tscn and crawler_pink.tscn (PinkCrawler, which heals you when
## killed). Place one and set it up in the Inspector.

const SIZE := Vector2(28, 24)
const FRAME := Vector2i(32, 32)   # sprite frame size, art/templates/SHEETS.md
const FLASH := Color(2.5, 2.5, 2.5)   # brightens the sprite towards white when hit
const TRAIL_SPACING := 10.0           # px travelled between slime drips
## Drops when the player is below it, at most this far to either side and this far down.
const DROP_RANGE := Vector2(20, 12 * 32)

@export var speed := 70.0
@export var gravity := 1800.0
## Start stuck to the ceiling above.
@export var on_ceiling := false
## The slime trail's colour (each colour's scene sets its own).
@export var slime_color := Color.WHITE

var sprite: AnimatedSprite2D
var _dir := -1
var _stagger_timer := 0.0
var _turning := false
var _dropping := false
var _landing := false
var _trail_distance := 0.0
var _ledge_ray: RayCast2D


func _ready() -> void:
	super._ready()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	add_child(shape)
	add_child(make_contact_hitbox(SIZE - Vector2(2, 2)))

	_ledge_ray = RayCast2D.new()
	_ledge_ray.collision_mask = 1 | 32
	_ledge_ray.position = Vector2(_dir * 16, 0)
	add_child(_ledge_ray)

	sprite = $Sprite
	sprite.animation_finished.connect(_on_animation_finished)
	_set_surface(on_ceiling)
	sprite.play(_anim("walk"))


## Which way is "down" for it: the ceiling or the floor. Its feet, the ledge
## check and the sprite's attachment point follow.
func _set_surface(ceiling: bool) -> void:
	on_ceiling = ceiling
	up_direction = Vector2.DOWN if ceiling else Vector2.UP
	_ledge_ray.target_position = Vector2(0, -22 if ceiling else 22)
	var half := SIZE.y * 0.5 - FRAME.y * 0.5
	sprite.position = Vector2(0, -half if ceiling else half)


## An animation by its floor name, as the ceiling version when up there.
func _anim(anim_name: String) -> String:
	return "ceiling_" + anim_name if on_ceiling else anim_name


func _physics_process(delta: float) -> void:
	var flashing := _flashing(delta)
	_stagger_timer = maxf(_stagger_timer - delta, 0.0)
	velocity.y += gravity * delta * (-1.0 if on_ceiling else 1.0)

	if on_ceiling and not _dying and _player_below():
		_drop()
	if _dropping:
		velocity.x = 0.0   # straight down onto them
	elif _dying or _stagger_timer > 0.0 or _landing:
		velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
	else:
		if is_on_floor() and (_wall_ahead() or not _ledge_ray.is_colliding()):
			_turn()
		velocity.x = _dir * speed   # after any turn, so it walks away from the wall this frame
	var before := global_position
	move_and_slide()
	if _dropping and is_on_floor():
		_land()
	if is_on_floor() and not on_ceiling and not _dying:
		_trail_distance += absf(global_position.x - before.x)
		if _trail_distance >= TRAIL_SPACING:
			_trail_distance = 0.0
			_drip()
	_update_sprite(flashing)


# Only a wall we're walking into, not one we just turned away from.
func _wall_ahead() -> bool:
	return is_on_wall() and get_wall_normal().x * _dir < 0.0


func _turn() -> void:
	_dir *= -1
	_ledge_ray.position.x = _dir * 16
	_ledge_ray.force_raycast_update()
	_turning = true
	sprite.play(_anim("turn"))


## The player is below, close enough to either side, with nothing solid between.
func _player_below() -> bool:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty() or not players[0].visible:
		return false
	var offset: Vector2 = players[0].global_position - global_position
	if absf(offset.x) > DROP_RANGE.x or offset.y <= 0.0 or offset.y > DROP_RANGE.y:
		return false
	var sight := PhysicsRayQueryParameters2D.create(global_position, players[0].global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(sight).is_empty()


## Lets go of the ceiling and falls as a stretched drop; it hurts on the way down.
func _drop() -> void:
	_set_surface(false)
	_dropping = true
	_turning = false
	velocity = Vector2.ZERO
	sprite.play("drop")


## Splats onto the floor, then oozes on as a floor crawler.
func _land() -> void:
	_dropping = false
	_landing = true
	sprite.play("land")


func _on_hit(_hit_dir: Vector2) -> void:
	_stagger_timer = 0.3
	if on_ceiling:
		_drop()   # knocked off the ceiling
	elif not _dropping:
		sprite.play("hurt")


## Melts (into a puddle, or dripping off the ceiling); removed when the animation ends.
func _on_death() -> void:
	_dropping = false
	sprite.play(_anim("death"))


func _on_animation_finished() -> void:
	if _dying:
		queue_free()
	elif sprite.animation in ["turn", "hurt", "land", "ceiling_turn", "ceiling_hurt"]:
		_turning = false
		_landing = false
		sprite.play(_anim("walk"))


func _update_sprite(flashing: bool) -> void:
	sprite.flip_h = _dir < 0
	sprite.self_modulate = FLASH if flashing else Color.WHITE
	var busy := _dying or _turning or _dropping or _landing or _stagger_timer > 0.0
	if not busy and sprite.animation != _anim("walk"):
		sprite.play(_anim("walk"))


## A small blob of sludge left on the floor behind it, fading out.
func _drip() -> void:
	var drip := SlimeDrip.new()
	drip.color = slime_color
	drip.global_position = global_position + Vector2(-_dir * SIZE.x * 0.4, SIZE.y * 0.5)
	get_parent().add_child(drip)
