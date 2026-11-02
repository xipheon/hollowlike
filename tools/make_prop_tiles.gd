extends SceneTree
## Builds the props tile sheet (art/tiles/props.png): things hung on the wall,
## with nothing behind them, painted on a room's Props layer over the brick of
## its Background layer. Starting with the posters; more props move here from
## background.png in time. Run from the project folder:
##   godot --headless --path . --script res://tools/make_prop_tiles.gd
## Then rerun tools/make_tilesets.gd if a prop was added or moved.

const TILE := 32
const SRC := "res://art/tiles/source/"
const SHEET_PATH := "res://art/tiles/props.png"
const SHEET_SIZE := Vector2i(8, 1)  # in tiles

# Pieces: [file, top-left cell, size in tiles], each centred in its cells.
# The cells match RoomArt's props constants.
const PIECES := [
	["posters_raw.png", Vector2i(0, 0), Vector2i(2, 1)],
]


func _init() -> void:
	var sheet := Image.create(SHEET_SIZE.x * TILE, SHEET_SIZE.y * TILE, false, Image.FORMAT_RGBA8)
	for p in PIECES:
		var piece := Image.load_from_file(ProjectSettings.globalize_path(SRC + p[0]))
		_place(sheet, piece, p[1] * TILE, p[2] * TILE)
	sheet.save_png(ProjectSettings.globalize_path(SHEET_PATH))
	print("Wrote %s" % SHEET_PATH)
	quit()


## Lays a piece, centred, on the transparent sheet: its solid pixels, fully
## opaque, as background.png's pieces are drawn, and nothing else.
func _place(img: Image, piece: Image, o: Vector2i, area: Vector2i) -> void:
	piece.convert(Image.FORMAT_RGBA8)
	var off := o + (area - piece.get_size()) / 2
	for y in piece.get_height():
		for x in piece.get_width():
			var c := piece.get_pixel(x, y)
			var at := off + Vector2i(x, y)
			if c.a > 0.5 and Rect2i(o, area).has_point(at):
				img.set_pixelv(at, Color(c, 1.0))
