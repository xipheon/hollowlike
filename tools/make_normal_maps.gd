extends SceneTree
## Gives the sheets in SHEETS a normal map, for the room's lights to shade (see
## "Normal maps" in art/README.md). A special effect, for the few things whose
## shape it brings out (on the dark brick wall it was too faint to be worth
## it); everything else is lit flat. For each sheet in SHEETS, beside it:
##   <sheet>_n.png       its normal map: the same size, and blank (flat, facing
##                       out of the screen) until it's drawn
##   <sheet>_canvas.tres a CanvasTexture pairing the sheet with its normal map,
##                       which the tilesets, sprite frames and scripts use
## Never overwrites either, so a normal map that's been drawn is safe: delete
## one to have it made blank again. After adding a sheet, point what draws it
## at its _canvas.tres (tools/make_tilesets.gd does so for tile sheets by
## itself, once rerun). Run from the project folder:
##   godot --headless --path . --script res://tools/make_normal_maps.gd
## The pipes' map is drawn by tools/make_pipe_tiles.gd.

const SHEETS := [
	"res://art/tiles/pipes.png",
]
## Facing straight out of the screen: x 0, y 0, z 1, stored as (128, 128, 255).
const FLAT := Color8(128, 128, 255)


func _init() -> void:
	for sheet in SHEETS:
		var normal := normal_path(sheet)
		if not FileAccess.file_exists(normal):
			var size := Image.load_from_file(ProjectSettings.globalize_path(sheet)).get_size()
			var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
			img.fill(FLAT)
			img.save_png(ProjectSettings.globalize_path(normal))
			print("Wrote %s (blank)" % normal)
		var canvas := canvas_path(sheet)
		if not FileAccess.file_exists(canvas):
			var file := FileAccess.open(canvas, FileAccess.WRITE)
			file.store_string(_canvas_text(sheet, normal))
			print("Wrote %s" % canvas)
	quit()


static func normal_path(sheet: String) -> String:
	return sheet.get_basename() + "_n.png"


static func canvas_path(sheet: String) -> String:
	return sheet.get_basename() + "_canvas.tres"


## Written as text, so it needs neither image imported yet.
func _canvas_text(sheet: String, normal: String) -> String:
	return """[gd_resource type="CanvasTexture" format=3]

[ext_resource type="Texture2D" path="%s" id="1_diffuse"]
[ext_resource type="Texture2D" path="%s" id="2_normal"]

[resource]
diffuse_texture = ExtResource("1_diffuse")
normal_texture = ExtResource("2_normal")
""" % [sheet, normal]
