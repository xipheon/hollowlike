class_name CrawlerEnemy
extends EnemyBase
## Simple patrolling enemy: a blob of sewer sludge that oozes along, turns at
## walls and ledges, hurts on contact, and leaves a fading slime trail. It
## melts into a puddle when killed. Comes in several palettes, random unless
## set; pink ones heal the player when killed.
## A crawler can start on a ceiling instead (`on_ceiling`): it oozes along
## upside down, and when the player passes underneath it lets go, drops on
## them, and carries on as a floor crawler. Hitting it up there knocks it down.
## Place scenes/enemies/crawler.tscn and set it up in the Inspector.

const SIZE := Vector2(28, 24)
## Pink crawlers heal the player this many half-hearts when killed; the others
## don't (unless heal_on_kill is set).
const HEALING_PALETTE := "pink"
const KILL_HEAL := 2

## Sheet per palette, drawn by tools/make_crawler_sheet.gd.
const PALETTES := ["sewer", "sickly", "pink"]
const SHEET_PATH := "res://art/sprites/crawler_%s.png"
const FRAME := Vector2i(32, 32)
## Sheet rows: [animation, frames, fps, loops], as in art/templates/SHEETS.md.
const ROWS := [
	["walk", 4, 8.0, true], ["turn", 2, 10.0, false], ["hurt", 2, 10.0, false], ["death", 5, 10.0, false],
	["ceiling_walk", 4, 8.0, true], ["ceiling_turn", 2, 10.0, false], ["ceiling_hurt", 2, 10.0, false],
	["ceiling_death", 5, 10.0, false], ["drop", 2, 8.0, true], ["land", 2, 10.0, false],
]
const FLASH := Color(2.5, 2.5, 2.5)   # brightens the sprite towards white when hit
const TRAIL_SPACING := 10.0           # px travelled between slime drips
## Drops when the player is below it, at most this far to either side and this far down.
const DROP_RANGE := Vector2(20, 12 * 32)

## Which colours: one of PALETTES, or "random" to pick one when it spawns.
@export_enum("random", "sewer", "sickly", "pink") var palette := "random"
@export var speed := 70.0
@export var gravity := 1800.0
## Start stuck to the ceiling above.
@export var on_ceiling := false

var sprite: AnimatedSprite2D
var _dir := -1
var _stagger_timer := 0.0
var _turning := false
var _dropping := false
var _landing := false
var _trail_distance := 0.0
var _drip_color := Color.WHITE
var _ledge_ray: RayCast2D


func _init() -> void:
	hit_recoil = 500.0   # soft and springy: a down-strike bounces you high


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

	if palette == "random":
		palette = PALETTES.pick_random()
	sprite = _make_sprite()
	add_child(sprite)
	_set_surface(on_ceiling)
	sprite.play(_anim("walk"))


func default_kill_heal() -> int:
	return KILL_HEAL if palette == HEALING_PALETTE else 0


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


## The animated sprite from this palette's sheet.
func _make_sprite() -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sheet: Texture2D = load(SHEET_PATH % palette)
	_drip_color = sheet.get_image().get_pixel(FRAME.x / 2, FRAME.y - 2)   # the walk frame's body, low down
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row in ROWS.size():
		var r: Array = ROWS[row]
		frames.add_animation(r[0])
		frames.set_animation_speed(r[0], r[2])
		frames.set_animation_loop(r[0], r[3])
		for f in r[1]:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(Vector2(f, row) * Vector2(FRAME), Vector2(FRAME))
			frames.add_frame(r[0], atlas)
	s.sprite_frames = frames
	s.animation_finished.connect(_on_animation_finished)
	return s


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
	drip.color = _drip_color
	drip.global_position = global_position + Vector2(-_dir * SIZE.x * 0.4, SIZE.y * 0.5)
	get_parent().add_child(drip)
