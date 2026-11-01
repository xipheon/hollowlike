extends SceneTree
## Recolours the player's brown leather jacket to strong pink, keeping its
## shading. Works on any PixelLab frame of the character, so every animation
## can be run through it the same way. Run from the project folder:
##   godot --headless --path . --script res://tools/recolor_jacket.gd -- <in.png> <out.png> [mask.png]
## The optional mask image shows which pixels were changed (white), for checking.
## Other tools call recolor() directly.
##
## A jacket pixel is a mid-dark, saturated brown or red-brown. The hair is the
## same brown, so the area just around and below the cap is left alone (the
## cap is found by its bright red, so this follows the head through crouches
## and flips); skin is lighter than any jacket shade.

const HUE_RANGE := Vector2(-12.0, 32.0)   # degrees; wraps through red
const MIN_SATURATION := 0.45
const VALUE_RANGE := Vector2(0.18, 0.78)   # brighter than this is skin (hands, face)
const CAP_HUE_RANGE := Vector2(-20.0, 16.0)
const CAP_MIN_SATURATION := 0.75
const CAP_MIN_VALUE := 0.6               # the cap's darkest reds also turn up in the jacket's shadows
const HAIR_MARGIN := Vector2i(3, 6)       # px around the cap (sides, below) where brown is hair
const HEAD_ROWS := 15                     # no cap found: px from the sprite's top treated as head

const PINK_HUE := 325.0
const PINK_SATURATION := 0.78
const PINK_VALUE_SCALE := 1.35            # pink reads brighter than brown at the same shade
const PINK_VALUE_LIFT := 0.12


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var img := Image.load_from_file(args[0])
	var mask := recolor(img)
	img.save_png(args[1])
	if args.size() > 2:
		mask.save_png(args[2])
	quit()


## Recolours `img` in place. Returns a mask of the changed pixels.
static func recolor(img: Image) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	var mask := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	var head := _head_rect(img)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.5 or head.has_point(Vector2i(x, y)) or not _is_jacket(c):
				continue
			var v := clampf(c.v * PINK_VALUE_SCALE + PINK_VALUE_LIFT, 0.0, 1.0)
			img.set_pixel(x, y, Color.from_hsv(PINK_HUE / 360.0, PINK_SATURATION, v, c.a))
			mask.set_pixel(x, y, Color.WHITE)
	return mask


## The cap's bounds grown by HAIR_MARGIN; without a cap, the top HEAD_ROWS.
## Cap reds also turn up in the jacket's shadows, so the cap is only the
## connected patch of cap colour that reaches highest on the sprite.
static func _head_rect(img: Image) -> Rect2i:
	var start := Vector2i(-1, -1)
	for y in img.get_height():
		for x in img.get_width():
			if _is_cap(img.get_pixel(x, y)):
				start = Vector2i(x, y)
				break
		if start.x >= 0:
			break
	if start.x < 0:
		var used := img.get_used_rect()
		return Rect2i(used.position, Vector2i(used.size.x, HEAD_ROWS))
	var cap := Rect2i(start, Vector2i.ONE)
	var seen := {start: true}
	var stack: Array[Vector2i] = [start]
	var bounds := Rect2i(Vector2i.ZERO, img.get_size())
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		cap = cap.expand(p).expand(p + Vector2i.ONE)
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var n := p + Vector2i(dx, dy)
				if bounds.has_point(n) and not seen.has(n) and _is_cap(img.get_pixelv(n)):
					seen[n] = true
					stack.append(n)
	return Rect2i(cap.position - Vector2i(HAIR_MARGIN.x, 0), cap.size + Vector2i(HAIR_MARGIN.x * 2, HAIR_MARGIN.y))


static func _is_cap(c: Color) -> bool:
	var hue := wrapf(c.h * 360.0, -180.0, 180.0)
	return c.a >= 0.5 and hue >= CAP_HUE_RANGE.x and hue <= CAP_HUE_RANGE.y \
			and c.s >= CAP_MIN_SATURATION and c.v >= CAP_MIN_VALUE


static func _is_jacket(c: Color) -> bool:
	var hue := wrapf(c.h * 360.0, -180.0, 180.0)
	return hue >= HUE_RANGE.x and hue <= HUE_RANGE.y and c.s >= MIN_SATURATION \
			and c.v >= VALUE_RANGE.x and c.v <= VALUE_RANGE.y
