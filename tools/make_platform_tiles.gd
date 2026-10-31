extends SceneTree
## Cuts the PixelLab catwalk strip into the one-way platform tiles (PLAT L /
## MID / R / ONE on the tile sheet) and writes a preview. The catwalk is moved
## up so its walking surface is the top of the tile, where the 10 px of
## collision is. Run from the project folder:
##   godot --headless --path . --script res://tools/make_platform_tiles.gd

const TILE := 32
const SRC_PATH := "res://art/tiles/source/catwalk_raw.png"
const SHEET_PATH := "res://art/tiles/tileset.png"
const PREVIEW_PATH := "res://art/tiles/source/platform_preview.png"
const PREVIEW_SCALE := 4
const PLAT_L := Vector2i(0, 4)    # MID, R and ONE follow to the right
const MID_FROM := 48              # x of the strip's 32 px used for the middle tile


func _init() -> void:
	var strip := Image.load_from_file(ProjectSettings.globalize_path(SRC_PATH))
	strip.convert(Image.FORMAT_RGBA8)
	var top := strip.get_used_rect().position.y
	var raised := Image.create(strip.get_width(), TILE, false, Image.FORMAT_RGBA8)
	raised.blit_rect(strip, Rect2i(0, top, strip.get_width(), TILE - top), Vector2i.ZERO)

	var w := raised.get_width()
	var tiles := [
		raised.get_region(Rect2i(0, 0, TILE, TILE)),
		raised.get_region(Rect2i(MID_FROM, 0, TILE, TILE)),
		raised.get_region(Rect2i(w - TILE, 0, TILE, TILE)),
		Image.create(TILE, TILE, false, Image.FORMAT_RGBA8),
	]
	# ONE: the left end's left half and the right end's right half.
	var half := TILE / 2
	tiles[3].blit_rect(raised, Rect2i(0, 0, half, TILE), Vector2i.ZERO)
	tiles[3].blit_rect(raised, Rect2i(w - half, 0, half, TILE), Vector2i(half, 0))

	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SHEET_PATH))
	sheet.convert(Image.FORMAT_RGBA8)
	for i in tiles.size():
		var at := (PLAT_L + Vector2i(i, 0)) * TILE
		sheet.fill_rect(Rect2i(at, Vector2i(TILE, TILE)), Color(0, 0, 0, 0))
		sheet.blit_rect(tiles[i], Rect2i(0, 0, TILE, TILE), at)
	sheet.save_png(ProjectSettings.globalize_path(SHEET_PATH))
	_save_preview(tiles)
	print("Wrote platform tiles to %s and preview to %s" % [SHEET_PATH, PREVIEW_PATH])
	quit()


## A long platform (L, 4 x MID, R) and a single one, over the brick colour.
func _save_preview(tiles: Array) -> void:
	var row := [0, 1, 1, 1, 1, 2, -1, 3]
	var img := Image.create(row.size() * TILE, TILE + 8, false, Image.FORMAT_RGBA8)
	img.fill(Color8(40, 33, 32))
	for i in row.size():
		if row[i] >= 0:
			img.blend_rect(tiles[row[i]], Rect2i(0, 0, TILE, TILE), Vector2i(i * TILE, 4))
	img.resize(img.get_width() * PREVIEW_SCALE, img.get_height() * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(PREVIEW_PATH))
