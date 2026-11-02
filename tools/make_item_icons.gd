extends SceneTree
## Draws the items' icons, art/items/<id>.png: 16x16 pixel art from the maps
## below, one character per pixel (PALETTE; "." is see-through). Shown scaled
## up, pixels kept sharp: in the inventory, the dialogue box and as pickups.
## Edit a map and rerun from the project folder:
##   godot --headless --path . --script res://tools/make_item_icons.gd

const OUT := "res://art/items/%s.png"
const PALETTE := {
	"k": Color8(24, 20, 22),      # outline
	"b": Color8(112, 70, 40),     # leather
	"B": Color8(158, 104, 58),    # leather, lit
	"w": Color8(214, 210, 198),   # sole
	"c": Color8(110, 226, 255),   # dash streaks
	"R": Color8(214, 52, 62),     # heart
	"r": Color8(140, 26, 40),     # heart, shaded
	"W": Color8(255, 214, 214),   # heart, shine
	"m": Color8(120, 128, 136),   # steel
	"M": Color8(196, 204, 212),   # steel, lit
	"T": Color8(46, 48, 58),      # tape
	"t": Color8(84, 88, 104),     # tape, lit
}
const ICONS := {
	"dash_boots": [
		"................",
		"................",
		"....kkkkk.......",
		"....kBbbk.......",
		"....kBbbk.......",
		".cc.kBbbk.......",
		"..cckBbbk.......",
		".cc.kBbbbk......",
		"....kBbbbbkk....",
		".ccckBbbbbbbkk..",
		"....kBbbbbbbbbk.",
		"....kbbbbbbbbbk.",
		"....kwwwwwwwwwk.",
		"....kkkkkkkkkkk.",
		"................",
		"................",
	],
	"heart_container": [
		"................",
		"................",
		"..kkk.....kkk...",
		".kRRRk...kRRRk..",
		"kRWWRRk.kRRRRRk.",
		"kRWRRRRkRRRRRRk.",
		"kRRRRRRRRRRRRRk.",
		"kRRRRRRRRRRRRrk.",
		".kRRRRRRRRRRrk..",
		"..kRRRRRRRRrk...",
		"...kRRRRRRrk....",
		"....kRRRRrk.....",
		".....kRRrk......",
		"......kkk.......",
		"................",
		"................",
	],
	"climbing_spurs": [
		"................",
		"................",
		"................",
		".kkkkkkkkkkkkk..",
		".kbBbbbBbbbBbk..",
		".kbbbbbbbbbbbk..",
		".kkkkkkkkkkkkk..",
		"..kMmk.kMmk.kMk.",
		"..kMmk.kMmk.kMk.",
		"..kMk..kMk..kMk.",
		"..kMk..kMk...kk.",
		"...kk...kk......",
		"................",
		"................",
		"................",
		"................",
	],
	"strong_pipe": [
		"............kkk.",
		"...........kMMk.",
		"..........kMmmk.",
		".........kMmmk..",
		"........ktTTk...",
		".......ktTTk....",
		"......kMmmk.....",
		".....kMmmk......",
		"....kMmmk.......",
		"...ktTTk........",
		"..ktTTk.........",
		".kMmmk..........",
		"kMmmk...........",
		"kMmk............",
		"kkk.............",
		"................",
	],
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/items"))
	for id in ICONS:
		var rows: Array = ICONS[id]
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in rows.size():
			for x in rows[y].length():
				var ch: String = rows[y][x]
				if ch != ".":
					img.set_pixel(x, y, PALETTE[ch])
		img.save_png(ProjectSettings.globalize_path(OUT % id))
		print("Wrote %s" % (OUT % id))
	quit()
