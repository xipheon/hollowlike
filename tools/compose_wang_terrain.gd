extends SceneTree
## Turns a PixelLab corner-Wang tileset (4x4 sheet of 32px tiles plus its
## metadata JSON) into the 4x4 "Match Sides" terrain block of the game's tile
## sheet, and writes a preview of a sample room. Run from the project folder:
##   godot --headless --path . --script res://tools/compose_wang_terrain.gd -- <raw.png> <meta.json>
##
## Wang tiles sit on the dual grid: each tile spans the corners of four cells.
## A game tile is built from four 16px quadrants, each taken from the Wang tile
## centred on that corner of the cell. Match Sides only knows the four side
## neighbours, so a diagonal counts as solid when both sides next to it are.

const TILE := 32
const HALF := TILE / 2
const SHEET_PATH := "res://art/tiles/tileset.png"
const SHEET_SIZE := Vector2i(256, 224)
const PREVIEW_PATH := "res://art/tiles/source/terrain_preview.png"
const PREVIEW_SCALE := 3

# Same layout as TERRAIN in make_art_templates.gd: solid sides (N, E, S, W).
const TERRAIN := [
	["S", "ES", "ESW", "SW"],
	["NS", "NES", "NESW", "NSW"],
	["N", "NE", "NEW", "NW"],
	["", "E", "EW", "W"],
]

const PREVIEW_ROWS := [
	"....................",
	"..####.......#......",
	"..####.......#...##.",
	".............#...##.",
	"......####...#......",
	"#.....#..#...###....",
	"#.....####..........",
	"####..........######",
	"####...####...######",
	"####################",
]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: -- <raw.png> <meta.json>")
		quit(1)
		return
	var raw := Image.load_from_file(args[0])
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	raw.convert(Image.FORMAT_RGBA8)

	# Corner key "NW,NE,SW,SE" (1 = solid) -> tile position on the raw sheet.
	var wang := {}
	for tile in meta["tileset_data"]["tiles"]:
		var c: Dictionary = tile["corners"]
		var key := _key(c["NW"] == "lower", c["NE"] == "lower", c["SW"] == "lower", c["SE"] == "lower")
		wang[key] = Vector2i(int(tile["bounding_box"]["x"]), int(tile["bounding_box"]["y"]))

	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SHEET_PATH)) \
		if FileAccess.file_exists(SHEET_PATH) else null
	if sheet == null:
		sheet = Image.create(SHEET_SIZE.x, SHEET_SIZE.y, false, Image.FORMAT_RGBA8)
	sheet.convert(Image.FORMAT_RGBA8)
	for r in TERRAIN.size():
		for c in TERRAIN[r].size():
			var sides: String = TERRAIN[r][c]
			var cell := _build_cell(raw, wang, "N" in sides, "E" in sides, "S" in sides, "W" in sides)
			sheet.fill_rect(Rect2i(c * TILE, r * TILE, TILE, TILE), Color(0, 0, 0, 0))
			sheet.blit_rect(cell, Rect2i(0, 0, TILE, TILE), Vector2i(c * TILE, r * TILE))
	sheet.save_png(ProjectSettings.globalize_path(SHEET_PATH))
	_save_preview(raw, wang)
	print("Wrote terrain block to %s and preview to %s" % [SHEET_PATH, PREVIEW_PATH])
	quit()


func _key(nw: bool, ne: bool, sw: bool, se: bool) -> String:
	return "%d%d%d%d" % [int(nw), int(ne), int(sw), int(se)]


## A solid cell with the given solid neighbours, as one 32px tile.
func _build_cell(raw: Image, wang: Dictionary, n: bool, e: bool, s: bool, w: bool) -> Image:
	var out := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	# [Wang corners around the cell's corner, quarter of that tile to take, where it goes].
	var quads := [
		[_key(n and w, n, w, true), Vector2i(HALF, HALF), Vector2i(0, 0)],
		[_key(n, n and e, true, e), Vector2i(0, HALF), Vector2i(HALF, 0)],
		[_key(w, true, s and w, s), Vector2i(HALF, 0), Vector2i(0, HALF)],
		[_key(true, e, s, s and e), Vector2i(0, 0), Vector2i(HALF, HALF)],
	]
	for q in quads:
		var origin: Vector2i = wang[q[0]]
		out.blit_rect(raw, Rect2i(origin + q[1], Vector2i(HALF, HALF)), q[2])
	return out


func _save_preview(raw: Image, wang: Dictionary) -> void:
	var rows := PREVIEW_ROWS.size()
	var cols: int = PREVIEW_ROWS[0].length()
	var img := Image.create(cols * TILE, rows * TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color8(40, 44, 52))
	for y in rows:
		for x in cols:
			if not _solid(x, y):
				continue
			var cell := _build_cell(raw, wang, _solid(x, y - 1), _solid(x + 1, y), _solid(x, y + 1), _solid(x - 1, y))
			img.blend_rect(cell, Rect2i(0, 0, TILE, TILE), Vector2i(x * TILE, y * TILE))
	img.resize(img.get_width() * PREVIEW_SCALE, img.get_height() * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(PREVIEW_PATH))


func _solid(x: int, y: int) -> bool:
	if y < 0 or y >= PREVIEW_ROWS.size() or x < 0 or x >= PREVIEW_ROWS[y].length():
		return true
	return PREVIEW_ROWS[y][x] == "#"
