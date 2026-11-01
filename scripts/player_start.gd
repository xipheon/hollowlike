@tool
class_name PlayerStart
extends Node2D
## Where the player appears when a room is started fresh (a new game, level
## select, or running the room on its own). Place it with its origin on the
## floor: that's where the player's feet go. Drawn in the editor only.

const BODY := Vector2(22, 44)   # Player.BODY_SIZE
const COLOR := Color(0.4, 0.85, 1.0)


func _ready() -> void:
	visible = Engine.is_editor_hint()


func _draw() -> void:
	draw_rect(Rect2(Vector2(-BODY.x * 0.5, -BODY.y), BODY), Color(COLOR, 0.25))
	draw_rect(Rect2(Vector2(-BODY.x * 0.5, -BODY.y), BODY), COLOR, false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(-16, -BODY.y - 4), "START", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR)
