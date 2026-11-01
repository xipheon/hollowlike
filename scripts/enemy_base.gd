class_name EnemyBase
extends CharacterBody2D
## What every regular enemy shares (bosses have BossBase): health, contact
## damage, the hit flash, healing the player on a kill, and dying. Each placed
## enemy can override these in the Inspector. A type that wants different
## defaults sets them on its scene's root (e.g. thug.tscn), not in code, so
## the Inspector shows them; script-only instances (.new()) keep these.
## Subclasses hook in with _on_hit() (stagger, knockback...), damage_taken()
## (blocking) and _on_death() (play a death animation, then queue_free; the
## default frees at once), and can give their type a default kill heal with
## default_kill_heal().

signal died

const FLASH_TIME := 0.1
const LAYER_ENEMY := 4
const LAYER_HAZARD := 16

@export var max_health := 3
@export var damage := 2   ## contact damage, in half-hearts
## Half-hearts the player gets back for the kill. -1 uses this enemy type's
## default (see default_kill_heal()).
@export var heal_on_kill := -1
## How hard hitting this pushes the player away, in px/s, along the line from
## this to them: struck from above, that bounces them up (a high value is a
## pogo); from the side, it shoves them back. 0: no push.
@export var hit_recoil := 300.0

var health := 0
var _flash_timer := 0.0
var _dying := false


func _enter_tree() -> void:
	add_to_group("enemy")


func _ready() -> void:
	health = max_health
	collision_layer = LAYER_ENEMY
	collision_mask = 1 | 32   # world + platforms only, so the player walks through enemies


## Half-hearts a kill gives back: the placed value, or the type's default.
func kill_heal() -> int:
	return heal_on_kill if heal_on_kill >= 0 else default_kill_heal()


## The type's kill heal when heal_on_kill is left at -1.
func default_kill_heal() -> int:
	return 0


func is_dying() -> bool:
	return _dying


func take_hit(amount: int, hit_dir: Vector2) -> void:
	if _dying:
		return
	health -= damage_taken(amount)
	_flash_timer = FLASH_TIME
	if health <= 0:
		if kill_heal() > 0:
			get_tree().call_group("player", "heal", kill_heal())
		_die()
	else:
		_on_hit(hit_dir)


## How much of a hit of `amount` it actually takes. A type that can guard
## (ThugEnemy's block) takes less.
func damage_taken(amount: int) -> int:
	return amount


## Stops being an enemy at once: no more contact damage, can't be hit again.
func _die() -> void:
	_dying = true
	remove_from_group("enemy")
	collision_layer = 0
	for hitbox in find_children("*", "Area2D", false, false):
		hitbox.set_deferred("monitorable", false)
	died.emit()
	_on_death()


func _on_hit(_hit_dir: Vector2) -> void:
	pass


func _on_death() -> void:
	queue_free()


## Counts the hit flash down; true while it's showing.
func _flashing(delta: float) -> bool:
	_flash_timer = maxf(_flash_timer - delta, 0.0)
	return _flash_timer > 0.0


## A box that hurts the player on contact (read by the player's hurtbox).
func make_contact_hitbox(size: Vector2, offset := Vector2.ZERO) -> Area2D:
	var hitbox := Area2D.new()
	hitbox.add_to_group("enemy_hitbox")
	hitbox.set_meta("damage", damage)
	hitbox.collision_layer = LAYER_HAZARD   # the hazard layer, which the player's hurtbox watches
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = offset
	hitbox.add_child(shape)
	return hitbox
