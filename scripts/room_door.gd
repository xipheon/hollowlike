@tool
class_name RoomDoor
extends Node2D
## A way into another room. Paint the doorway's door tiles on the Terrain
## layer, then place one of these over them: its origin is the doorway's
## top-left corner, and it's `height` tiles tall. Walking into it loads
## `target_room`; you arrive at that room's door named `arrive_at`, or, left
## empty, the door there that leads back here. Drawn in the editor only.

const TILE := 32
const COLOR := Color(1.0, 0.75, 0.3)

## The room it leads to (an id from LevelData.ROOMS).
@export var target_room := "":
	set(value):
		target_room = value
		queue_redraw()
## Name of the door node to arrive at in the target room; empty = the one that leads back.
@export var arrive_at := ""
## Doorway height in tiles.
@export_range(1, 8) var height := 3:
	set(value):
		height = value
		queue_redraw()


func _ready() -> void:
	visible = Engine.is_editor_hint()


## Offers the rooms as a drop-down in the Inspector.
func _validate_property(property: Dictionary) -> void:
	if property.name == "target_room":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(LevelData.ROOMS.keys())


## The doorway, in the room's coordinates.
func rect() -> Rect2:
	return Rect2(position, Vector2(TILE, height * TILE))


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(TILE, height * TILE))
	draw_rect(r, Color(COLOR, 0.2))
	draw_rect(r, COLOR, false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(2, -4), "-> " + (target_room if target_room != "" else "?"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR)
