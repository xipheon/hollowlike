extends SceneTree
## Writes art/grades/neutral_lut.png: a colour lookup table that changes
## nothing, the starting point for a room's grade (ColorGrade.lut). A 256x16
## strip of sixteen 16x16 squares: red across each square, green down it, blue
## from square to square. Recolour a copy in any paint program (curves, hue,
## levels: anything applied to the whole image the same way), save it beside
## this one, and set it as a grade's `lut`. Run from the project folder:
##   godot --headless --path . --script res://tools/make_neutral_lut.gd

const PATH := "res://art/grades/neutral_lut.png"
const SIZE := 16


func _init() -> void:
	var img := Image.create(SIZE * SIZE, SIZE, false, Image.FORMAT_RGB8)
	for b in SIZE:
		for g in SIZE:
			for r in SIZE:
				img.set_pixel(b * SIZE + r, g, Color(r / (SIZE - 1.0), g / (SIZE - 1.0), b / (SIZE - 1.0)))
	img.save_png(ProjectSettings.globalize_path(PATH))
	print("Wrote %s" % PATH)
	quit()
