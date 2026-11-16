extends Node
## Draws every room of the world on one image, each as it looks in game (its
## tiles, lights and dimming; nobody moving), to look the whole world over at
## a glance: build/world_contact_sheet.png. Needs a window (not --headless).
## Run from the project folder:
##   godot --path . res://tools/make_contact_sheet.tscn

const OUT := "res://build/world_contact_sheet.png"
const SCALE := 0.5      # of the rooms' own size
const GAP := 16         # px between rooms on the sheet
const LABEL_SIZE := 28
const SETTLE_FRAMES := 6   # for lights and tiles to draw before the picture


func _ready() -> void:
	var shots: Array[Image] = []
	for id: String in LevelData.ROOMS:
		var path: String = LevelData.ROOMS[id].scene
		if not path.begins_with("res://scenes/world/"):
			continue
		var room: Room = load(path).instantiate()
		room.backdrop = true
		room.entities().process_mode = Node.PROCESS_MODE_DISABLED   # enemies stand still
		var view := SubViewport.new()
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(view)
		view.add_child(room)
		var size := Vector2i(room._w, room._h) * Room.TILE
		view.size = size
		# The whole room, not the backdrop's view from its start.
		var camera := Camera2D.new()
		camera.position = size * 0.5
		room.add_child(camera)
		camera.make_current()
		var label := Label.new()
		label.text = id
		label.add_theme_font_size_override("font_size", LABEL_SIZE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 8)
		label.position = Vector2(12, 8)
		var over := CanvasLayer.new()
		over.layer = Room.GRADE_LAYER + 1
		over.add_child(label)
		view.add_child(over)
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
		var shot := view.get_texture().get_image()
		shot.resize(int(size.x * SCALE), int(size.y * SCALE), Image.INTERPOLATE_BILINEAR)
		shots.append(shot)
		view.queue_free()
	var width := 0
	var height := GAP
	for shot in shots:
		width = maxi(width, shot.get_width() + GAP * 2)
		height += shot.get_height() + GAP
	var sheet := Image.create(width, height, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.05, 0.05, 0.07))
	var y := GAP
	for shot in shots:
		shot.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i(GAP, y))
		y += shot.get_height() + GAP
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	sheet.save_png(ProjectSettings.globalize_path(OUT))
	print("Wrote %s (%d rooms, %d x %d)" % [OUT, shots.size(), width, height])
	get_tree().quit()
