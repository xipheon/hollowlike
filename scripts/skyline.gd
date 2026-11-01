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


func _ready() -> void:
	scroll_scale = SCROLL
	repeat_size = Vector2(TEXTURE.get_width(), 0)
	repeat_times = 2
	z_index = -2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for child in get_children():
		child.free()   # rebuilt every time, never saved into a scene
	var image := TEXTURE.get_image()
	var top := SCREEN_BOTTOM - TEXTURE.get_height()
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
	var sprite := Sprite2D.new()
	sprite.texture = TEXTURE
	sprite.centered = false
	sprite.position = Vector2(0, top)
	add_child(sprite)
