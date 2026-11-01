extends SceneTree
## Builds the player's sprite sheets, one per skin in PlayerSprite.SKINS, from
## the PixelLab frames in art/sprites/source/player/<animation>/<n>.png. Each
## frame is placed in its 64x64 cell with the feet on the pivot (bottom centre)
## and recoloured for its skin. Also writes a preview. Run from the project folder:
##   godot --headless --path . --script res://tools/make_player_sheet.gd

const Recolor = preload("res://tools/recolor_jacket.gd")

const SRC := "res://art/sprites/source/player/"
const PREVIEW_PATH := "res://art/sprites/source/player_sheet_preview.png"
const PREVIEW_SCALE := 3

## Which generated frames fill each row: row -> [source animation, frame numbers].
## The counts must match PlayerSprite.ROWS.
const SOURCES := {
	"idle": ["idle", [0, 1, 2, 3, 4, 5]],
	"run": ["run", [0, 1, 2, 3, 4, 5, 6, 7]],
	"jump": ["jump_arc", [1, 2, 3]],        # take-off and rise
	"fall": ["jump_arc", [4, 5]],           # top of the jump, legs reaching down
	"land": ["jump_arc", [6, 7]],           # landing crouch
	"wall_slide": ["wall_slide", [0, 1, 2, 3]],
	"wall_jump": ["wall_jump", [2, 3]],     # the leap (0-1 are a wind-up on the wall)
	"double_jump": ["double_jump", [2, 3]], # the mid-air tuck (0-1 are standing)
}
## Every frame gets the same shift, worked out from this one so its feet sit on
## the pivot; poses that crouch or rise keep their offset from it.
const ANCHOR := ["idle", 0]
const FEET_ROWS := 10   # bottom rows of the anchor used to find the legs' centre


func _init() -> void:
	var shift := _anchor_shift()
	var sheets := {}
	for s in PlayerSprite.SKINS:
		sheets[s.id] = Image.create(8 * PlayerSprite.FRAME.x, PlayerSprite.ROWS.size() * PlayerSprite.FRAME.y,
				false, Image.FORMAT_RGBA8)
	for row in PlayerSprite.ROWS.size():
		var r: Array = PlayerSprite.ROWS[row]
		if r[1] == 0:
			continue
		var src: Array = SOURCES[r[0]]
		assert(src[1].size() == r[1], "%s: %d frames in SOURCES, %d in PlayerSprite.ROWS" % [r[0], src[1].size(), r[1]])
		for f in src[1].size():
			for s in PlayerSprite.SKINS:
				var img := _load(src[0], src[1][f])
				_recolor(s.id, img)
				var cell := Vector2i(f, row) * PlayerSprite.FRAME
				var sheet: Image = sheets[s.id]
				var area := Rect2i(cell, PlayerSprite.FRAME)
				# Copy only the part that lands inside the cell.
				var dest := Rect2i(cell + shift, img.get_size()).intersection(area)
				sheet.blit_rect(img, Rect2i(dest.position - cell - shift, dest.size), dest.position)
	for s in PlayerSprite.SKINS:
		sheets[s.id].save_png(ProjectSettings.globalize_path(s.sheet))
		print("Wrote ", s.sheet)
	_save_preview(sheets)
	quit()


func _load(anim: String, n: int) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + "%s/%d.png" % [anim, n]))
	img.convert(Image.FORMAT_RGBA8)
	return img


## How a skin differs from the PixelLab originals. "classic" is them as drawn.
func _recolor(skin_id: String, img: Image) -> void:
	match skin_id:
		"pink":
			Recolor.recolor(img)


## Moves the anchor frame's lowest row to the bottom of the cell and the middle
## of its legs (jeans pixels in the bottom rows) to the cell's centre line.
func _anchor_shift() -> Vector2i:
	var img := _load(ANCHOR[0], ANCHOR[1])
	var used := img.get_used_rect()
	var sum := 0
	var count := 0
	for y in range(used.end.y - FEET_ROWS, used.end.y):
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and c.h > 0.53 and c.h < 0.66 and c.s > 0.3:   # denim blue
				sum += x
				count += 1
	var centre := roundi(float(sum) / count) if count > 0 else used.get_center().x
	return Vector2i(PlayerSprite.FRAME.x / 2 - centre, PlayerSprite.FRAME.y - used.end.y)


## The first frame of every drawn row, each skin in its own line, with a red
## dot on the pivot.
func _save_preview(sheets: Dictionary) -> void:
	var drawn := PlayerSprite.ROWS.filter(func(r): return r[1] > 0)
	var f := PlayerSprite.FRAME
	var img := Image.create(drawn.size() * f.x, PlayerSprite.SKINS.size() * f.y, false, Image.FORMAT_RGBA8)
	img.fill(Color8(40, 33, 32))
	for si in PlayerSprite.SKINS.size():
		var sheet: Image = sheets[PlayerSprite.SKINS[si].id]
		for i in drawn.size():
			var row := PlayerSprite.ROWS.find(drawn[i])
			img.blend_rect(sheet, Rect2i(Vector2i(0, row) * f, f), Vector2i(i, si) * f)
			img.set_pixel(i * f.x + f.x / 2, si * f.y + f.y - 1, Color8(230, 60, 60))
	img.resize(img.get_width() * PREVIEW_SCALE, img.get_height() * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(PREVIEW_PATH))
