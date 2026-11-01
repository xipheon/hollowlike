extends SceneTree
## Builds the crawler scenes from the crawler sheets (art/sprites/crawler_<colour>.png,
## drawn by tools/make_crawler_sheet.gd), so no crawler builds its sprite in
## game. For each colour it saves the sprite's animations as
## art/sprites/crawler_<colour>_frames.tres and a scene,
## scenes/enemies/crawler_<colour>.tscn: the colour's crawler script, its slime
## colour, its hit_recoil, and a Sprite (scripts/crawler_sprite.gd) using those
## frames. Run from the project folder after redrawing the sheets:
##   godot --headless --path . --script res://tools/make_crawler_scenes.gd
## Untyped on purpose: the crawler scripts use autoloads, which a --script run
## can't compile against up front.

const SHEET_PATH := "res://art/sprites/crawler_%s.png"
const FRAMES_PATH := "res://art/sprites/crawler_%s_frames.tres"
const SCENE_PATH := "res://scenes/enemies/crawler_%s.tscn"
const SPRITE_SCRIPT := "res://scripts/crawler_sprite.gd"
const FRAME := Vector2i(32, 32)
const BODY_HEIGHT := 24   # CrawlerEnemy.SIZE.y
const HIT_RECOIL := 500.0   # every crawler: soft and springy, a down-strike bounces you high
## Colour: [scene root name, script].
const COLOURS := {
	"sewer": ["SewerCrawler", "res://scripts/enemy_crawler.gd"],
	"sickly": ["SicklyCrawler", "res://scripts/enemy_crawler.gd"],
	"pink": ["PinkCrawler", "res://scripts/crawler_pink.gd"],
}
## Sheet rows: [animation, frames, fps, loops], as in art/templates/SHEETS.md.
const ROWS := [
	["walk", 4, 8.0, true], ["turn", 2, 10.0, false], ["hurt", 2, 10.0, false], ["death", 5, 10.0, false],
	["ceiling_walk", 4, 8.0, true], ["ceiling_turn", 2, 10.0, false], ["ceiling_hurt", 2, 10.0, false],
	["ceiling_death", 5, 10.0, false], ["drop", 2, 8.0, true], ["land", 2, 10.0, false],
]


func _init() -> void:
	for colour in COLOURS:
		var sheet: Texture2D = load(SHEET_PATH % colour)
		_save(_frames(sheet), FRAMES_PATH % colour)
		var crawler := CharacterBody2D.new()
		crawler.name = COLOURS[colour][0]
		crawler.set_script(load(COLOURS[colour][1]))
		# The trail matches the walk frame's body, low down.
		crawler.set("slime_color", sheet.get_image().get_pixel(FRAME.x / 2, FRAME.y - 2))
		crawler.set("hit_recoil", HIT_RECOIL)
		_add_sprite(crawler, colour)
		_save_scene(crawler, SCENE_PATH % colour)
	quit()


## Every animation on the sheet, one row each.
func _frames(sheet: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row in ROWS.size():
		var r: Array = ROWS[row]
		frames.add_animation(r[0])
		frames.set_animation_speed(r[0], r[2])
		frames.set_animation_loop(r[0], r[3])
		for f in r[1]:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(Vector2(f, row) * Vector2(FRAME), Vector2(FRAME))
			frames.add_frame(r[0], atlas)
	return frames


## The Sprite: the colour's frames, standing on the floor, facing left as it starts.
func _add_sprite(parent: Node2D, colour: String) -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = load(FRAMES_PATH % colour)
	sprite.animation = "walk"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.flip_h = true
	sprite.position = Vector2(0, BODY_HEIGHT * 0.5 - FRAME.y * 0.5)
	sprite.set_script(load(SPRITE_SCRIPT))
	parent.add_child(sprite)
	sprite.owner = parent


func _save(resource: Resource, path: String) -> void:
	print("Wrote %s (%s)" % [path, error_string(ResourceSaver.save(resource, path))])


func _save_scene(root: Node, path: String) -> void:
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err == OK:
		err = ResourceSaver.save(scene, path)
	print("Wrote %s (%s)" % [path, error_string(err)])
	root.free()
