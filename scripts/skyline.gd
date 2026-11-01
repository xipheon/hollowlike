@tool
class_name Skyline
extends Parallax2D
## The far city skyline behind every room, seen through windows and holes in
## the wall. It repeats sideways and stays put vertically, its bottom edge a
## little above the bottom of the screen; sky colour fills above it, ground
## colour below. Builds itself, so it also shows in the editor.

const TEXTURE := preload("res://art/backgrounds/skyline.png")
const SCROLL := Vector2(0.15, 0.0)     # x drifts slowly; y stays fixed on screen
const SCREEN_BOTTOM := 450.0           # screen y of the skyline's bottom edge (the screen is 540 tall)
const FILL := 4000.0                   # px of plain sky above and ground below
const EDITOR_STACK_ABOVE := 1          # copies above and below the game position, in the editor
const EDITOR_STACK_BELOW := 6          # (enough for a 2,500 px tall room)


func _ready() -> void:
	scroll_scale = SCROLL
	repeat_size = Vector2(TEXTURE.get_width(), 0)
	repeat_times = 2
	z_index = -2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for child in get_children():
		child.free()   # rebuilt every time, never saved into a scene
	var top := SCREEN_BOTTOM - TEXTURE.get_height()
	# The editor has no camera for it to follow, so there it's stacked down
	# the whole room instead: every window and hole shows the city while you paint.
	if Engine.is_editor_hint():
		for i in range(-EDITOR_STACK_ABOVE, EDITOR_STACK_BELOW + 1):
			add_child(_city(Vector2(0, top + i * TEXTURE.get_height())))
		return
	var image := TEXTURE.get_image()
	var sky := ColorRect.new()
	sky.color = image.get_pixel(0, 0)
	sky.position = Vector2(0, top - FILL)
	sky.size = Vector2(TEXTURE.get_width(), FILL)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	var ground := ColorRect.new()
	ground.color = image.get_pixel(0, image.get_height() - 1)
	ground.position = Vector2(0, SCREEN_BOTTOM)
	ground.size = Vector2(TEXTURE.get_width(), FILL)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	add_child(_city(Vector2(0, top)))


func _city(at: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = TEXTURE
	sprite.centered = false
	sprite.position = at
	return sprite
