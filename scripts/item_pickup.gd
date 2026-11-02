class_name ItemPickup
extends Area2D
## An item lying in a room, floating just off the floor and glowing, waiting
## to be picked up: touch it and GameState.give_item() gets it (the HUD says
## what you got). Bosses drop their rewards as these (Room._drop_rewards());
## `picked_flag` remembers it's gone, so it's still there if you leave and
## come back without it, and not once you have it.

const SCALE := 2.0                 # the 16 px icon, shown at 32
const BOB := 3.0                   # px up and down
const BOB_RATE := 2.5
const HOVER := 22.0                # px its middle floats above the floor
const SIZE := Vector2(28, 28)      # what you touch to pick it up
const LIGHT_COLOR := Color(1.0, 0.85, 0.55)
const LIGHT_RADIUS := 56
const LIGHT_ENERGY := 0.6
const LIGHT_HEIGHT := 24.0

var item: Item
var picked_flag := ""
var _time := 0.0
var _taken := false


func _ready() -> void:
	add_to_group("item_pickup")
	collision_layer = 0
	collision_mask = 2   # the player's body
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	add_child(shape)
	add_child(FlickerLight.make_light(LIGHT_RADIUS, LIGHT_COLOR, LIGHT_ENERGY, LIGHT_HEIGHT))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body_entered.connect(func(body: Node) -> void:
		if body is Player:
			collect())
	_time = randf() * TAU


## Gives you the item, remembers it's been taken, and goes.
func collect() -> void:
	if _taken:
		return
	_taken = true
	GameState.set_flag(picked_flag)
	GameState.give_item(item)
	queue_free()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if item == null or item.icon == null:
		return
	var size := item.icon.get_size() * SCALE
	var at := Vector2(-size.x * 0.5, -size.y * 0.5 + sin(_time * BOB_RATE) * BOB)
	draw_texture_rect(item.icon, Rect2(at, size), false)
