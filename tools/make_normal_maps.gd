extends SceneTree
## Gives every lit sheet a normal map, for the room's lights (see "Normal maps"
## in art/README.md). For each sheet in SHEETS, beside it:
##   <sheet>_n.png       its normal map: the same size, and blank (flat, facing
##                       out of the screen) until it's drawn
##   <sheet>_canvas.tres a CanvasTexture pairing the sheet with its normal map,
##                       which the tilesets, sprite frames and scripts use
## Never overwrites either, so a normal map you've drawn is safe: delete one to
## have it made blank again. A new or resized sheet gets its own. Run from the
## project folder:
##   godot --headless --path . --script res://tools/make_normal_maps.gd
## The skyline and the slash effects aren't lit, so they have none.

const SHEETS := [
	"res://art/tiles/tileset.png",
	"res://art/tiles/background.png",
	"res://art/tiles/props.png",
	"res://art/tiles/pipes.png",
	"res://art/sprites/player.png",
	"res://art/sprites/player_pink.png",
	"res://art/sprites/thug.png",
	"res://art/sprites/crawler_sewer.png",
	"res://art/sprites/crawler_sickly.png",
	"res://art/sprites/crawler_pink.png",
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
