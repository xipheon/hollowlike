extends SceneTree
## Generates blank guide sheets for the sprite and tile art, plus SHEETS.md
## describing each one. Run from the project folder:
##   godot --headless --path . --script res://tools/make_art_templates.gd
##   godot --headless --path . --script res://tools/make_art_templates.gd -- --scale=2
## --scale draws the guides bigger for working at 2x/4x; the game expects 1x.
##
## Guides go to art/templates/ (which has a .gdignore so Godot doesn't import
## them). Draw on a layer above the guide, hide the guide, and export the art
## at the same size into art/sprites/ or art/tiles/.

const OUT_DIR := "res://art/templates"

# Sizes are in game pixels (1 tile = 32). `box` is the collision box from the
# scripts; `pivot` is where the node's origin sits in each frame: "feet" =
# bottom centre (ground walkers), "center" = middle (fliers, effects, pickups).
const SHEETS := [
	{"name": "player", "frame": Vector2i(64, 64), "pivot": "feet", "box": Vector2i(22, 44),
		"notes": "Facing right. Slashes, dust and trails go on the effects sheet, not here.",
		"rows": [["idle", 6, 8, true], ["run", 8, 12, true], ["sprint", 8, 14, true],
			["jump", 3, 10, false], ["fall", 3, 10, true], ["land", 2, 12, false],
			["wall_slide", 3, 8, true], ["wall_jump", 2, 12, false], ["dash", 4, 16, false],
			["attack_side", 5, 20, false], ["attack_up", 5, 20, false], ["attack_down", 5, 20, false],
			["hurt", 2, 10, false], ["death", 8, 10, false]]},
	{"name": "player_effects", "frame": Vector2i(64, 64), "pivot": "center", "box": Vector2i(0, 0),
		"notes": "Pivot is the player's centre. Side slash reaches 60x40 to the right; up/down slashes are 48x52.",
		"rows": [["slash_side", 4, 24, false], ["slash_up", 4, 24, false], ["slash_down", 4, 24, false],
			["dash_trail", 4, 16, false], ["land_dust", 4, 16, false], ["hit_spark", 4, 20, false]]},
	{"name": "crawler", "frame": Vector2i(32, 32), "pivot": "feet", "box": Vector2i(28, 24),
		"notes": "Facing right.",
		"rows": [["walk", 4, 8, true], ["turn", 2, 10, false], ["hurt", 2, 10, false], ["death", 5, 12, false]]},
	{"name": "knight", "frame": Vector2i(96, 64), "pivot": "feet", "box": Vector2i(24, 44),
		"notes": "Facing right. The swing hits a 46x28 area in front; the windup raises the blade about 34 px above the hand.",
		"rows": [["walk", 6, 8, true], ["windup", 4, 10, false], ["swing", 4, 16, false],
			["recover", 3, 8, false], ["hurt", 2, 10, false], ["death", 6, 10, false]]},
	{"name": "warden", "frame": Vector2i(128, 96), "pivot": "feet", "box": Vector2i(56, 72),
		"notes": "Facing right. The last death frame is the corpse left in the arena (about 90 px wide, lying down). Damage flash and phase-two tint are done in code.",
		"rows": [["idle", 4, 6, true], ["charge_windup", 4, 10, false], ["charge", 6, 14, true],
			["dazed", 4, 6, true], ["leap_windup", 3, 10, false], ["leap", 2, 10, true],
			["land", 3, 12, false], ["death", 6, 8, false]]},
	{"name": "harrier", "frame": Vector2i(128, 96), "pivot": "center", "box": Vector2i(52, 36),
		"notes": "Facing right. Wingspan is about 88 px. Dazed and death frames lie on the ground: their bottom edge is 18 px below the pivot.",
		"rows": [["hover", 6, 10, true], ["shot_windup", 4, 10, false], ["homing_windup", 4, 10, false],
			["swoop_windup", 3, 10, false], ["swoop", 3, 12, true], ["dazed", 4, 6, true],
			["rise", 3, 10, false], ["death", 6, 8, false]]},
	{"name": "projectiles", "frame": Vector2i(32, 32), "pivot": "center", "box": Vector2i(0, 0),
		"notes": "Pointing right; rotated in code. Feather 22x8, homing feather 18x18, shockwave 20x26 (bottom on the floor).",
		"rows": [["feather", 2, 12, true], ["homing_feather", 4, 10, true], ["shockwave", 4, 12, true],
			["dazed_stars", 4, 10, true]]},
	{"name": "pickups", "frame": Vector2i(32, 32), "pivot": "center", "box": Vector2i(24, 24),
		"notes": "The box is the pickup radius (12). Bobbing is done in code.",
		"rows": [["coin", 6, 10, true], ["health", 4, 8, true], ["ability_orb", 6, 10, true]]},
	{"name": "hud", "frame": Vector2i(24, 24), "pivot": "center", "box": Vector2i(0, 0),
		"notes": "One frame per icon.",
		"rows": [["heart_full", 1, 0, false], ["heart_half", 1, 0, false], ["heart_empty", 1, 0, false],
			["coin_icon", 1, 0, false]]},
]

const TILE := 32
const TILE_COLS := 8
const TILE_ROWS := 7
# Solid terrain, Godot "Match Sides" terrain: which neighbours are solid in
# each cell of the 4x4 block (N, E, S, W).
const TERRAIN := [
	["S", "ES", "ESW", "SW"],
	["NS", "NES", "NESW", "NSW"],
	["N", "NE", "NEW", "NW"],
	["", "E", "EW", "W"],
]
# Everything else on the tile sheet: [col, row, label, guide line y or -1].
const TILE_CELLS := [
	[0, 4, "PLAT\nL", 10], [1, 4, "PLAT\nMID", 10], [2, 4, "PLAT\nR", 10], [3, 4, "PLAT\nONE", 10],
	[4, 4, "SPIKE", 24], [5, 4, "SPIKE\n2", 24], [6, 4, "GATE", -1], [7, 4, "GATE\nEND", -1],
	[0, 5, "ACID\nTOP 1", 8], [1, 5, "ACID\nTOP 2", 8], [2, 5, "ACID\nTOP 3", 8], [3, 5, "ACID\nTOP 4", 8],
	[4, 5, "ACID\nFILL1", -1], [5, 5, "ACID\nFILL2", -1], [6, 5, "ACID\nFILL3", -1], [7, 5, "ACID\nFILL4", -1],
	[0, 6, "GATE\nUP", 8], [1, 6, "DOOR", -1], [2, 6, "DOOR\nTOP", 6],
	[3, 6, "SPIKE\n3", 24], [4, 6, "SPIKE\n4", 24],
]

const CELL_A := Color8(236, 236, 242)
const CELL_B := Color8(222, 222, 232)
const UNUSED := Color8(138, 138, 150)
const UNUSED_X := Color8(156, 156, 168)
const TEXT := Color8(48, 48, 64)
const CENTRE_LINE := Color8(190, 190, 205)
const BOX := Color8(0, 160, 210)
const PIVOT := Color8(224, 32, 64)
const TERRAIN_FILL := Color8(230, 220, 200)
const EDGE := Color8(192, 112, 48)

# 3x5 pixel font for the labels.
const GLYPHS := {
	"A": [".#.", "#.#", "###", "#.#", "#.#"], "B": ["##.", "#.#", "##.", "#.#", "##."],
	"C": [".##", "#..", "#..", "#..", ".##"], "D": ["##.", "#.#", "#.#", "#.#", "##."],
	"E": ["###", "#..", "##.", "#..", "###"], "F": ["###", "#..", "##.", "#..", "#.."],
	"G": [".##", "#..", "#.#", "#.#", ".##"], "H": ["#.#", "#.#", "###", "#.#", "#.#"],
	"I": ["###", ".#.", ".#.", ".#.", "###"], "J": ["..#", "..#", "..#", "#.#", ".#."],
	"K": ["#.#", "#.#", "##.", "#.#", "#.#"], "L": ["#..", "#..", "#..", "#..", "###"],
	"M": ["#.#", "###", "###", "#.#", "#.#"], "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
	"O": [".#.", "#.#", "#.#", "#.#", ".#."], "P": ["##.", "#.#", "##.", "#..", "#.."],
	"Q": [".#.", "#.#", "#.#", "##.", ".##"], "R": ["##.", "#.#", "##.", "#.#", "#.#"],
	"S": [".##", "#..", ".#.", "..#", "##."], "T": ["###", ".#.", ".#.", ".#.", ".#."],
	"U": ["#.#", "#.#", "#.#", "#.#", "###"], "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
	"W": ["#.#", "#.#", "###", "###", "#.#"], "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
	"Y": ["#.#", "#.#", ".#.", ".#.", ".#."], "Z": ["###", "..#", ".#.", "#..", "###"],
	"0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#.", "##.", ".#.", ".#.", "###"],
	"2": ["##.", "..#", ".#.", "#..", "###"], "3": ["##.", "..#", ".#.", "..#", "##."],
	"4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "##.", "..#", "##."],
	"6": [".##", "#..", "###", "#.#", "###"], "7": ["###", "..#", ".#.", ".#.", ".#."],
	"8": ["###", "#.#", "###", "#.#", "###"], "9": ["###", "#.#", "###", "..#", "##."],
	"-": ["...", "...", "###", "...", "..."], "/": ["..#", "..#", ".#.", "#..", "#.."],
}


func _init() -> void:
	var scale := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scale="):
			scale = maxi(1, int(arg.get_slice("=", 1)))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for dir in ["res://art/sprites", "res://art/tiles"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var ignore := FileAccess.open(OUT_DIR.path_join(".gdignore"), FileAccess.WRITE)
	ignore.close()

	for sheet in SHEETS:
		_save(_sprite_guide(sheet), "%s_guide.png" % sheet.name, scale)
	_save(_tile_guide(), "tileset_guide.png", scale)
	_write_spec()
	print("Templates written to %s" % ProjectSettings.globalize_path(OUT_DIR))
	quit()


func _save(img: Image, file: String, scale: int) -> void:
	if scale > 1:
		img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	img.save_png(OUT_DIR.path_join(file))


# ------------------------------------------------------------ Sprite sheets ----

func _sprite_guide(sheet: Dictionary) -> Image:
	var fw: int = sheet.frame.x
	var fh: int = sheet.frame.y
	var cols := 0
	for row in sheet.rows:
		cols = maxi(cols, row[1])
	var img := Image.create_empty(cols * fw, sheet.rows.size() * fh, false, Image.FORMAT_RGBA8)
	for r in sheet.rows.size():
		var anim: String = sheet.rows[r][0]
		var frames: int = sheet.rows[r][1]
		for c in cols:
			var cell := Rect2i(c * fw, r * fh, fw, fh)
			if c >= frames:
				_unused_cell(img, cell)
				continue
			img.fill_rect(cell, CELL_A if (r + c) % 2 == 0 else CELL_B)
			_frame_guides(img, cell, sheet)
			_text(img, cell.position + Vector2i(2, 2), anim.to_upper() if c == 0 else str(c + 1))
	return img


func _frame_guides(img: Image, cell: Rect2i, sheet: Dictionary) -> void:
	var pivot := cell.position + Vector2i(cell.size.x / 2, cell.size.y - 1 if sheet.pivot == "feet" else cell.size.y / 2)
	# Dotted centre line, to keep the character from drifting between frames.
	for y in range(cell.position.y + 9, cell.end.y, 2):
		img.set_pixelv(Vector2i(pivot.x, y), CENTRE_LINE)
	var box: Vector2i = sheet.box
	if box != Vector2i.ZERO:
		var top := pivot.y - box.y + 1 if sheet.pivot == "feet" else pivot.y - box.y / 2
		_outline(img, Rect2i(pivot.x - box.x / 2, top, box.x, box.y), BOX)
	for d in [-1, 0, 1]:
		_put(img, pivot + Vector2i(d, 0), PIVOT)
		_put(img, pivot + Vector2i(0, d), PIVOT)


func _unused_cell(img: Image, cell: Rect2i) -> void:
	img.fill_rect(cell, UNUSED)
	var n := mini(cell.size.x, cell.size.y)
	var off := Vector2i((cell.size.x - n) / 2, (cell.size.y - n) / 2)
	for i in n:
		img.set_pixelv(cell.position + off + Vector2i(i, i), UNUSED_X)
		img.set_pixelv(cell.position + off + Vector2i(n - 1 - i, i), UNUSED_X)


# ------------------------------------------------------------------ Tileset ----

func _tile_guide() -> Image:
	var img := Image.create_empty(TILE_COLS * TILE, TILE_ROWS * TILE, false, Image.FORMAT_RGBA8)
	for r in TILE_ROWS:
		for c in TILE_COLS:
			var cell := Rect2i(c * TILE, r * TILE, TILE, TILE)
			img.fill_rect(cell, CELL_A if (r + c) % 2 == 0 else CELL_B)
			if c >= 4 and r < 4 or r == 6 and c >= 3:
				_text(img, cell.position + Vector2i(2, 2), "DECOR")
	# Solid terrain: the orange strip marks each exposed edge (a side with no
	# solid neighbour), which is where the surface detail goes.
	for r in 4:
		for c in 4:
			var cell := Rect2i(c * TILE, r * TILE, TILE, TILE)
			img.fill_rect(cell, TERRAIN_FILL)
			var solid: String = TERRAIN[r][c]
			if not solid.contains("N"):
				img.fill_rect(Rect2i(cell.position, Vector2i(TILE, 3)), EDGE)
			if not solid.contains("S"):
				img.fill_rect(Rect2i(cell.position + Vector2i(0, TILE - 3), Vector2i(TILE, 3)), EDGE)
			if not solid.contains("W"):
				img.fill_rect(Rect2i(cell.position, Vector2i(3, TILE)), EDGE)
			if not solid.contains("E"):
				img.fill_rect(Rect2i(cell.position + Vector2i(TILE - 3, 0), Vector2i(3, TILE)), EDGE)
	# Dotted tile borders, so the 16 tiles read as separate tiles.
	for i in range(1, 4):
		for j in range(0, 4 * TILE, 2):
			img.set_pixelv(Vector2i(i * TILE, j), TEXT)
			img.set_pixelv(Vector2i(j, i * TILE), TEXT)
	for t in TILE_CELLS:
		var pos := Vector2i(t[0] * TILE, t[1] * TILE)
		# Labels sit at the bottom, clear of the guide lines near the top.
		var lines: int = t[2].count("\n") + 1
		var label_y := TILE - 1 - lines * 6
		_text(img, pos + Vector2i(2, label_y), t[2])
		if t[3] >= 0:
			# Platform thickness / spike height / acid surface / frame depth.
			for x in range(0, TILE, 2):
				img.set_pixelv(pos + Vector2i(x, TILE - 1 - t[3] if t[2].begins_with("SPIKE") else t[3]), BOX)
	_outline(img, Rect2i(0, 0, 4 * TILE, 4 * TILE), TEXT)
	return img


# ------------------------------------------------------------------ Drawing ----

func _put(img: Image, p: Vector2i, color: Color) -> void:
	if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
		img.set_pixelv(p, color)


func _outline(img: Image, r: Rect2i, color: Color) -> void:
	for x in range(r.position.x, r.end.x):
		_put(img, Vector2i(x, r.position.y), color)
		_put(img, Vector2i(x, r.end.y - 1), color)
	for y in range(r.position.y, r.end.y):
		_put(img, Vector2i(r.position.x, y), color)
		_put(img, Vector2i(r.end.x - 1, y), color)


func _text(img: Image, at: Vector2i, text: String) -> void:
	var lines := text.split("\n")
	for l in lines.size():
		var x := at.x
		for ch in lines[l]:
			var glyph: Array = GLYPHS.get(ch, [])
			for gy in glyph.size():
				for gx in 3:
					if glyph[gy][gx] == "#":
						_put(img, Vector2i(x + gx, at.y + l * 6 + gy), TEXT)
			x += 4


# --------------------------------------------------------------------- Spec ----

func _write_spec() -> void:
	var md := "# Sprite sheet layouts\n\nGenerated by `tools/make_art_templates.gd`. Don't edit by hand: change `SHEETS` in the script and rerun it.\n\n"
	md += "Every sheet is a grid of equal frames. Each row is one animation, read left to right, starting at the left edge. Grey cells with an X are unused, so leave them empty.\n\n"
	md += "Guide colours:\n\n- **Blue box**: the collision box. The body should roughly fill it.\n- **Red cross**: the pivot, the point the game lines the sprite up on.\n- **Dotted line**: the centre line.\n\n"
	for sheet in SHEETS:
		var cols := 0
		for row in sheet.rows:
			cols = maxi(cols, row[1])
		md += "## %s\n\n" % sheet.name
		md += "- Guide: `art/templates/%s_guide.png`\n" % sheet.name
		md += "- Save the art as: `art/sprites/%s.png`\n" % sheet.name
		md += "- Frame: %d x %d px; the sheet is %d x %d frames (%d x %d px)\n" % [
			sheet.frame.x, sheet.frame.y, cols, sheet.rows.size(), cols * sheet.frame.x, sheet.rows.size() * sheet.frame.y]
		md += "- Pivot: %s\n" % ("bottom centre (the feet)" if sheet.pivot == "feet" else "centre")
		if sheet.box != Vector2i.ZERO:
			md += "- Collision box: %d x %d\n" % [sheet.box.x, sheet.box.y]
		md += "- %s\n\n" % sheet.notes
		md += "| Row | Animation | Frames | FPS | Loops |\n|---|---|---|---|---|\n"
		for r in sheet.rows.size():
			var row: Array = sheet.rows[r]
			md += "| %d | %s | %d | %s | %s |\n" % [r, row[0], row[1], str(row[2]) if row[2] > 0 else "-", "yes" if row[3] else "no"]
		md += "\n"
	md += "## tileset\n\n"
	md += "- Guide: `art/templates/tileset_guide.png`\n- Save the art as: `art/tiles/tileset.png`\n"
	md += "- Tile: 32 x 32 px; the sheet is 8 x 7 tiles (256 x 224 px)\n\n"
	md += "**Solid terrain (the top-left 4x4 block)** uses Godot's *Match Sides* terrain. Each tile is painted from the ASCII `#` map according to which of its four neighbours are solid. An orange strip marks an exposed edge: a side that faces open air, where the grass, rim or crust goes. Each terrain tile should tile seamlessly with its neighbours.\n\n"
	md += "**Other tiles.** The blue dotted line marks a size the game uses:\n\n"
	md += "| Tile | What it is |\n|---|---|\n"
	md += "| PLAT L / MID / R / ONE | One-way platform (`=`). Its collision is the top 10 px. ONE is a single-tile platform. |\n"
	md += "| SPIKE, SPIKE 2-4 | Floor spikes (`^`). The damage area is the bottom 24 px. Four variants so a long row doesn't repeat. |\n"
	md += "| GATE / GATE END | Arena gate (`|`), shut: the middle of the column and its bottom tile (spiked tips). |\n"
	md += "| GATE UP | Raised gate: only the tips peek out, about 8 px. |\n"
	md += "| ACID TOP 1-4 | Acid surface (`~` with air above). The liquid starts 8 px down. 4 animation frames. |\n"
	md += "| ACID FILL 1-4 | Acid below the surface. 4 animation frames. |\n"
	md += "| DOOR / DOOR TOP | Door (`>`). DOOR TOP sits under solid rock, with a 6 px frame. |\n"
	md += "| DECOR | Free cells for background or decoration tiles (moss, chains, cracks), placed by hand later. |\n"
	var f := FileAccess.open(OUT_DIR.path_join("SHEETS.md"), FileAccess.WRITE)
	f.store_string(md)
	f.close()
