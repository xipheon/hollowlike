@tool
extends AnimatedSprite2D
## A crawler scene's sprite (its frames are saved in the scene). In the editor
## it shows the pose the crawler will start in, following the Inspector: the
## droopy ceiling walk hanging from above if on_ceiling, the floor walk
## otherwise. In game the crawler plays and places it (CrawlerEnemy).

var _ceiling_shown = null


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or get_parent() == null:
		return
	var ceiling: bool = get_parent().get("on_ceiling") == true
	if ceiling == _ceiling_shown:
		return
	_ceiling_shown = ceiling
	animation = "ceiling_walk" if ceiling else "walk"
	frame = 0
	# Where the crawler hangs it (see CrawlerEnemy._set_surface).
	var offset := CrawlerEnemy.SIZE.y * 0.5 - CrawlerEnemy.FRAME.y * 0.5
	position = Vector2(0, -offset if ceiling else offset)
