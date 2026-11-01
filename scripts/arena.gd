@tool
class_name Arena
extends Node2D
## A boss arena: the box the boss fights in and the camera locks to. Its origin
## is the top-left corner; size it in tiles. Walking a few tiles into it starts
## the fight and shuts the room's gates (gate tiles on the Gates layer); beating
## the boss opens them. Drawn in the editor only.

const TILE := 32
const COLOR := Color(1.0, 0.35, 0.3)

## Width and height in tiles.
@export var size_tiles := Vector2i(28, 8):
	set(value):
		size_tiles = value
		queue_redraw()
## The boss that fights here (a node in this room).
@export var boss: NodePath


func _ready() -> void:
	visible = Engine.is_editor_hint()


## The arena, in the room's coordinates.
func rect() -> Rect2:
	return Rect2(position, Vector2(size_tiles * TILE))


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(size_tiles * TILE))
	draw_rect(r, Color(COLOR, 0.08))
	draw_rect(r, COLOR, false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(4, 12), "ARENA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR)
