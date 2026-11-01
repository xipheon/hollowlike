class_name SlashEffect
extends AnimatedSprite2D
## The swoosh of the player's pipe: plays a slash row of art/sprites/
## player_effects.png once over the attack's hit area, then hides. Frames are
## centred on the hit area and face right; mirrored when facing left.

const SHEET := preload("res://art/sprites/player_effects.png")
const FRAME := Vector2i(64, 64)
const FPS := 24.0
## Row of each slash on the sheet, and its frame count.
const SLASHES := {"slash_side": [0, 4], "slash_up": [1, 4], "slash_down": [2, 4]}


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim in SLASHES:
		frames.add_animation(anim)
		frames.set_animation_speed(anim, FPS)
		frames.set_animation_loop(anim, false)
		for f in SLASHES[anim][1]:
			var atlas := AtlasTexture.new()
			atlas.atlas = SHEET
			atlas.region = Rect2(Vector2(f, SLASHES[anim][0]) * Vector2(FRAME), Vector2(FRAME))
			frames.add_frame(anim, atlas)
	sprite_frames = frames
	animation_finished.connect(func() -> void: visible = false)


## Plays a slash centred on `at` (the hit area's centre, relative to the player).
func swing(dir: Vector2, at: Vector2, facing: int) -> void:
	var anim := "slash_up" if dir == Vector2.UP else "slash_down" if dir == Vector2.DOWN else "slash_side"
	position = at
	flip_h = facing < 0
	visible = true
	play(anim)
	frame = 0
