class_name BossBase
extends CharacterBody2D
## What every arena boss shares. room.gd only talks to bosses through this:
## it sets the arena bounds, calls activate() after the intro, shows boss_name,
## and on `defeated` grants reward_ability and saves where the corpse lies.
## Subclasses set boss_name / reward_ability / max_health in _init() and
## implement activate(), take_hit(), debug_kill() and become_corpse(). They can
## also define on_hit_player(), which the player calls when their contact
## hitbox lands a hit.

signal health_changed(current: int, maximum: int)
signal defeated

var boss_name := "BOSS"
var reward_ability := ""
var max_health := 20
## How hard hitting this pushes the player away, in px/s (see EnemyBase.hit_recoil).
## Each boss sets its own on its scene's root (warden.tscn: 180).
@export var hit_recoil := 300.0
var health := 0
## Arena limits in pixels (set by the room before activate()). Also used to
## detect when to start the fight.
var arena_left := 0.0
var arena_right := 0.0
var arena_top := 0.0
var arena_bottom := 0.0
## Attacks started, in order. Handy for tests and debugging.
var attack_log: Array[String] = []

var _target: Node2D


func activate(target: Node2D) -> void:
	_target = target


func take_hit(_amount: int, _hit_dir: Vector2) -> void:
	pass


## How hard hitting it pushes the player right now: hit_recoil, unless a boss
## changes it with its state (the Harrier, dazed).
func current_hit_recoil() -> float:
	return hit_recoil


## Debug shortcut: dies on the spot, even before the fight has started.
func debug_kill() -> void:
	pass


## Stops fighting and stays put as harmless scenery (also used to restore the
## corpse when a beaten boss's room reloads).
func become_corpse() -> void:
	pass


func is_phase_two() -> bool:
	return health * 2 <= max_health
