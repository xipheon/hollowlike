extends SceneTree
## Makes the far parallax skyline: the PixelLab image, toned down towards grey
## so it stays in the distance, followed by a mirrored copy so both joins
## (middle and wrap-around) match pixel for pixel. Run from the project folder:
##   godot --headless --path . --script res://tools/make_skyline.gd

const SRC_PATH := "res://art/tiles/source/skyline_raw.png"
const OUT_PATH := "res://art/backgrounds/skyline.png"
const DESATURATE := 0.45  # 0 = original colours, 1 = fully grey
const CONTRAST := 0.75    # 1 = original, lower pulls every pixel towards the image's average


func _init() -> void:
	var src := Image.load_from_file(ProjectSettings.globalize_path(SRC_PATH))
	src.convert(Image.FORMAT_RGBA8)
	_tone_down(src)
	var size := src.get_size()
	var mirrored := src.duplicate() as Image
	mirrored.flip_x()
	var out := Image.create(size.x * 2, size.y, false, Image.FORMAT_RGBA8)
	out.blit_rect(src, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	out.blit_rect(mirrored, Rect2i(Vector2i.ZERO, size), Vector2i(size.x, 0))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_PATH.get_base_dir()))
	out.save_png(ProjectSettings.globalize_path(OUT_PATH))
	print("Wrote %s (%dx%d)" % [OUT_PATH, out.get_width(), out.get_height()])
	quit()


func _tone_down(img: Image) -> void:
	var total := Color(0, 0, 0)
	for y in img.get_height():
		for x in img.get_width():
			total += img.get_pixel(x, y)
	var count := img.get_width() * img.get_height()
	var average := Color(total.r / count, total.g / count, total.b / count)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var grey := c.get_luminance()
			c = c.lerp(Color(grey, grey, grey), DESATURATE)
			c = average.lerp(c, CONTRAST)
			img.set_pixel(x, y, Color(c, 1.0))
