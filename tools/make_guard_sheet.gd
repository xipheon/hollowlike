extends SceneTree
## Builds the security guard's sprite sheet, art/sprites/guard.png: the thug's
## (art/sprites/thug.png, tools/make_thug_sheet.gd) with his white T-shirt
## turned navy blue, keeping its shading. Same layout and animations, saved as
## art/sprites/guard_frames.tres for scenes/npcs/guard.tscn; also a preview.
## Run from the project folder (twice the first time: the frames need the new
## sheet imported):
##   godot --headless --path . --script res://tools/make_guard_sheet.gd
##
## A shirt pixel is light and nearly grey (white, and the light greys of its
## folds) in the torso's rows: the whites of the eyes are above them and the
## sneakers below. Its brightness picks the navy shade; the dark outline is
## left as it is.

const THUG_SHEET := "res://art/sprites/thug.png"
const SHEET_PATH := "res://art/sprites/guard.png"
const FRAMES_PATH := "res://art/sprites/guard_frames.tres"
const PREVIEW_PATH := "res://art/sprites/source/guard_preview.png"
const PREVIEW_SCALE := 4
const FRAME := Vector2i(64, 64)
const TORSO_ROWS := Vector2i(24, 50)   # within each frame
const SHIRT_MAX_SATURATION := 0.2
const SHIRT_MIN_VALUE := 0.38   # its shaded back is a darker grey (0.42); the outline is far darker
const NAVY_HUE := 0.62                 # about 223 degrees
const NAVY_SATURATION := 0.62
const NAVY_VALUE := Vector2(0.12, 0.38)   # value = x + y * the shirt's brightness


func _init() -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(THUG_SHEET))
	sheet.convert(Image.FORMAT_RGBA8)
	var changed := 0
	for y in sheet.get_height():
		var row := y % FRAME.y
		if row < TORSO_ROWS.x or row > TORSO_ROWS.y:
			continue
		for x in sheet.get_width():
			var c := sheet.get_pixel(x, y)
			if c.a < 0.5 or c.s > SHIRT_MAX_SATURATION or c.v < SHIRT_MIN_VALUE:
				continue
			sheet.set_pixel(x, y, Color.from_hsv(NAVY_HUE, NAVY_SATURATION, NAVY_VALUE.x + NAVY_VALUE.y * c.v, c.a))
			changed += 1
	sheet.save_png(ProjectSettings.globalize_path(SHEET_PATH))
	var preview := sheet.duplicate() as Image
	preview.resize(sheet.get_width() * PREVIEW_SCALE, sheet.get_height() * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
	preview.save_png(ProjectSettings.globalize_path(PREVIEW_PATH))
	_save_frames(sheet)
	print("Wrote %s (%d shirt pixels), %s and %s" % [SHEET_PATH, changed, FRAMES_PATH, PREVIEW_PATH])
	quit()


## The thug's animations (make_thug_sheet.gd's ANIMATIONS), cut from the
## guard's sheet: the imported sheet if it's there yet, else the image as written.
func _save_frames(sheet: Image) -> void:
	var animations: Dictionary = load("res://tools/make_thug_sheet.gd").get_script_constant_map()["ANIMATIONS"]
	var texture: Texture2D = load(SHEET_PATH) if ResourceLoader.exists(SHEET_PATH) else ImageTexture.create_from_image(sheet)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim in animations:
		var a: Array = animations[anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, a[3])
		frames.set_animation_loop(anim, a[4])
		for i in a[2]:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(Vector2(a[1] + i, a[0]) * Vector2(FRAME), Vector2(FRAME))
			frames.add_frame(anim, atlas)
	ResourceSaver.save(frames, FRAMES_PATH)
