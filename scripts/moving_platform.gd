@tool
class_name MovingPlatform
extends AnimatableBody2D
## A one-way catwalk platform that rides a track. Paint a straight line of
## track on the Terrain layer (the "track" terrain brush), then place this
## scene under Entities on it: its origin is the middle of the deck's top edge.
## On a side-to-side track the whole deck stays between the buffer stops; on an
## up-and-down track the deck's middle follows the rail, its top level with a
## track tile's top at each end. It goes back and forth, waiting a moment at
## each end, and carries whatever stands on it. Off a track it stays put.

const TILE := 32
const LAYER_PLATFORMS := 32
const DECK_HEIGHT := 10.0   # collision at the top of the deck, as on a painted platform
const SHEET := preload("res://art/tiles/tileset.png")

## Deck width in tiles.
@export_range(1, 8) var width_tiles := 3:
	set(value):
		width_tiles = value
		_fit_deck()
		queue_redraw()
## Pixels per second.
@export var speed := 90.0
## Seconds it waits at each end.
@export var end_pause := 0.6

var _from := Vector2.ZERO   # the ends of its travel, in its parent's coordinates
var _to := Vector2.ZERO
var _progress := 0.0        # 0 at _from, 1 at _to
var _heading := 1           # toward _to (right or down) or back
var _wait := 0.0


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _ready() -> void:
	_fit_deck()
	if Engine.is_editor_hint():
		return
	collision_layer = LAYER_PLATFORMS
	collision_mask = 0
	_find_track()


## Sizes the scene's one-way Deck shape to the deck's width.
func _fit_deck() -> void:
	var deck := get_node_or_null("Deck") as CollisionShape2D
	if deck == null:
		return
	deck.shape.size = Vector2(width_tiles * TILE, DECK_HEIGHT)
	deck.position = Vector2(0, DECK_HEIGHT * 0.5)
	deck.one_way_collision = true


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _from == _to:
		return
	if _wait > 0.0:
		_wait -= delta
		return
	_progress += _heading * speed * delta / _from.distance_to(_to)
	if _progress >= 1.0 or _progress <= 0.0:
		_progress = clampf(_progress, 0.0, 1.0)
		_heading = -_heading
		_wait = end_pause
	position = _from.lerp(_to, _progress)


## Whether it found a track to ride (it moves only then).
func on_track() -> bool:
	return _from != _to


## The ends of its travel, in its parent's coordinates.
func travel() -> Array[Vector2]:
	return [_from, _to]


## Finds the track under the deck and the ends of its travel along it, and
## puts the deck on the track where it was placed.
func _find_track() -> void:
	var room := _room()
	var layer: TileMapLayer = room.terrain() if room != null else null
	if layer == null:
		return
	# A track cell under the deck, nearest its middle first.
	var left := layer.local_to_map(layer.to_local(global_position + Vector2(-width_tiles * TILE * 0.5 + 1, 1)))
	var right := layer.local_to_map(layer.to_local(global_position + Vector2(width_tiles * TILE * 0.5 - 1, 1)))
	var cells := range(left.x, right.x + 1).map(func(x): return Vector2i(x, left.y))
	var middle := (left.x + right.x) * 0.5
	cells.sort_custom(func(a, b): return absf(a.x - middle) < absf(b.x - middle))
	var cell = null
	for c in cells:
		if _is_track(layer, c):
			cell = c
			break
	if cell == null:
		return
	var step := Vector2i.RIGHT if _is_track(layer, cell + Vector2i.RIGHT) or _is_track(layer, cell + Vector2i.LEFT) else Vector2i.DOWN
	var a: Vector2i = cell
	while _is_track(layer, a - step):
		a -= step
	var b: Vector2i = cell
	while _is_track(layer, b + step):
		b += step
	var from: Vector2
	var to: Vector2
	if step == Vector2i.RIGHT:
		var half := width_tiles * TILE * 0.5
		from = Vector2(a.x * TILE + half, a.y * TILE)
		to = Vector2((b.x + 1) * TILE - half, a.y * TILE)
		if to.x < from.x:   # a track shorter than the deck: sit in its middle
			from = (from + to) * 0.5
			to = from
	else:
		from = Vector2(a.x * TILE + TILE * 0.5, a.y * TILE)
		to = Vector2(a.x * TILE + TILE * 0.5, b.y * TILE)
	var parent := get_parent() as Node2D
	_from = parent.to_local(layer.to_global(from))
	_to = parent.to_local(layer.to_global(to))
	if _from == _to:
		position = _from
		return
	var along := _to - _from
	_progress = clampf((position - _from).dot(along) / along.length_squared(), 0.0, 1.0)
	position = _from.lerp(_to, _progress)


func _is_track(layer: TileMapLayer, cell: Vector2i) -> bool:
	var data := layer.get_cell_tile_data(cell)
	return data != null and data.get_custom_data("kind") == "track"


func _room() -> Room:
	var node := get_parent()
	while node != null and not node is Room:
		node = node.get_parent()
	return node


## The catwalk tiles, side by side, the deck's top at the origin.
func _draw() -> void:
	for i in width_tiles:
		var tile := RoomArt.PLAT_ONE
		if width_tiles > 1:
			tile = RoomArt.PLAT_L if i == 0 else RoomArt.PLAT_R if i == width_tiles - 1 else RoomArt.PLAT_MID
		var at := Vector2((i - width_tiles * 0.5) * TILE, 0)
		draw_texture_rect_region(SHEET, Rect2(at, Vector2(TILE, TILE)), Rect2(tile * TILE, Vector2(TILE, TILE)))
