class_name SlimeDrip
extends Node2D
## A small smear of sludge a crawler leaves on the floor as it oozes along.
## Sits on the floor surface (its position), fades out, then frees itself.

const LIFETIME := 1.6
const SIZES := [Vector2i(3, 1), Vector2i(4, 1), Vector2i(2, 1), Vector2i(3, 2)]

var color := Color.WHITE
var _size := Vector2i(3, 1)


func _ready() -> void:
	z_index = -1   # behind the crawlers and the player
	_size = SIZES.pick_random()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _draw() -> void:
	draw_rect(Rect2(Vector2(-_size.x * 0.5, -_size.y), Vector2(_size)), color)
