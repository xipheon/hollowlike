extends SceneTree
## Builds the thug's sprite sheet, art/sprites/thug.png, from the PixelLab
## frames in art/sprites/source/thug/ (character "Thug", side view, facing
## right; the game mirrors it for left), and writes a preview. Every frame is
## used. Frames are 64x64 like the player's, feet on the bottom row and centred:
##   row 0  idle    1 frame   (the standing pose, east.png)
##   row 1  walk    4 frames  (walk_0..3, PixelLab walking-4-frames)
##   row 2  attack  3 frames  (attack_0..2, PixelLab lead-jab)
## The source frames sit on a 68x68 canvas with the feet's last row at y 59.
## Run from the project folder:
##   godot --headless --path . --script res://tools/make_thug_sheet.gd

const SOURCE := "res://art/sprites/source/thug/%s.png"
const SHEET_PATH := "res://art/sprites/thug.png"
const PREVIEW_PATH := "res://art/sprites/source/thug_preview.png"
const FRAME := Vector2i(64, 64)
const ROWS := [
	["idle", ["east"]],
	["walk", ["walk_0", "walk_1", "walk_2", "walk_3"]],
	["attack", ["attack_0", "attack_1", "attack_2"]],
]
const SOURCE_SIZE := Vector2i(68, 68)
const SOURCE_GROUND := 60   # first row below the feet, in the source canvas
const PREVIEW_SCALE := 4


func _init() -> void:
	var columns := 0
	for row in ROWS:
		columns = maxi(columns, row[1].size())
	var sheet := Image.create(columns * FRAME.x, ROWS.size() * FRAME.y, false, Image.FORMAT_RGBA8)
	# Source pixel -> frame pixel: centre to centre, ground to the bottom edge.
	var shift := Vector2i(FRAME.x / 2 - SOURCE_SIZE.x / 2, FRAME.y - SOURCE_GROUND)
	for r in ROWS.size():
		var names: Array = ROWS[r][1]
		for c in names.size():
			var src := Image.load_from_file(ProjectSettings.globalize_path(SOURCE % names[c]))
			src.convert(Image.FORMAT_RGBA8)
			var used := src.get_used_rect()
			var to := used.position + shift
			if not Rect2i(Vector2i.ZERO, FRAME).encloses(Rect2i(to, used.size)):
				push_warning("%s doesn't fit a %s frame (used %s)" % [names[c], FRAME, used])
			sheet.blit_rect(src, used, Vector2i(c, r) * FRAME + to)
	sheet.save_png(ProjectSettings.globalize_path(SHEET_PATH))
	_save_preview(sheet)
	print("Wrote %s (%d x %d frames) and %s" % [SHEET_PATH, columns, ROWS.size(), PREVIEW_PATH])
	quit()


## The sheet over the brick wall, scaled up, so each frame can be checked.
func _save_preview(sheet: Image) -> void:
	var wall := Image.load_from_file(ProjectSettings.globalize_path("res://art/tiles/background.png"))
	wall.convert(Image.FORMAT_RGBA8)
	var img := Image.create(sheet.get_width(), sheet.get_height(), false, Image.FORMAT_RGBA8)
	for y in range(0, img.get_height(), 32):
		for x in range(0, img.get_width(), 32):
			img.blit_rect(wall, Rect2i(0, 0, 32, 32), Vector2i(x, y))
	img.blend_rect(sheet, Rect2i(Vector2i.ZERO, sheet.get_size()), Vector2i.ZERO)
	img.resize(img.get_width() * PREVIEW_SCALE, img.get_height() * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(PREVIEW_PATH))
