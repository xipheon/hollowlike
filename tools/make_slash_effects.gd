extends SceneTree
## Draws the player's slash effects into art/sprites/player_effects.png (the
## slash_side / slash_up / slash_down rows of the player_effects sheet in
## art/templates/SHEETS.md) and writes a preview. Each slash is a crescent
## that sweeps across the attack's hit area over 4 frames: the leading edge
## appears, the full arc flashes, then it thins out from the start. Frames are
## centred on the centre of the hit area, facing right. Run from the project folder:
##   godot --headless --path . --script res://tools/make_slash_effects.gd

const FRAME := 64
const FRAMES := 4
const COLUMNS := 4
const ROWS := 6   # slash_side, slash_up, slash_down, dash_trail, land_dust, hit_spark
const SHEET_PATH := "res://art/sprites/player_effects.png"
const PREVIEW_PATH := "res://art/sprites/source/slash_preview.png"
const PREVIEW_SCALE := 4

# Per slash: [row, reach (px along the strike), width (px across it), forward axis, sweep axis].
# Sizes match the attack hitboxes in player.gd _start_attack.
const SLASHES := [
	[0, 60, 40, Vector2(1, 0), Vector2(0, 1)],    # side: forward is right, sweeps top to bottom
	[1, 52, 48, Vector2(0, -1), Vector2(1, 0)],   # up: forward is up, sweeps back to front
	[2, 52, 40, Vector2(0, 1), Vector2(1, 0)],    # down: forward is down, sweeps back to front
]
# Each frame: [sweep start, sweep end] in degrees (-90 = start edge, 90 = end
# edge), thickness (0-1 of the full crescent), brightness.
const FRAME_SHAPES := [
	[-90.0, -10.0, 0.6, 1.0],
	[-90.0, 90.0, 1.0, 1.0],
	[-35.0, 90.0, 0.7, 0.8],
	[25.0, 90.0, 0.35, 0.55],
]
const MAX_THICKNESS := 0.4    # of the crescent's radius, at the middle of the arc
const TAPER := 0.55           # lower keeps the ends thicker (1 = tapers to points evenly)
const CENTRE_BACK := 0.65     # the arc's centre sits this far behind the hit area's centre (of the reach), so it wraps around the player

const CORE := Color8(255, 255, 255)
const MID := Color8(214, 230, 240)
const EDGE := Color8(132, 156, 176)


func _init() -> void:
	var sheet := Image.create(COLUMNS * FRAME, ROWS * FRAME, false, Image.FORMAT_RGBA8)
	for s in SLASHES:
		for f in FRAMES:
			_draw_slash(sheet, Vector2i(f, s[0]) * FRAME, s, FRAME_SHAPES[f])
	sheet.save_png(ProjectSettings.globalize_path(SHEET_PATH))
	_save_preview(sheet)
	print("Wrote %s and %s" % [SHEET_PATH, PREVIEW_PATH])
	quit()


## A crescent: the band between two ellipses around a point behind the hit
## area, thickest mid-sweep and tapering to points, cut to this frame's part
## of the sweep. Brightest on its outer edge.
func _draw_slash(img: Image, cell: Vector2i, s: Array, shape: Array) -> void:
	var reach: float = s[1]
	var width: float = s[2]
	var fwd: Vector2 = s[3]
	var side: Vector2 = s[4]
	var radius := Vector2(reach * (0.5 + CENTRE_BACK), width * 0.5)   # along forward, along the sweep
	var centre := -fwd * reach * CENTRE_BACK
	for y in FRAME:
		for x in FRAME:
			var p := Vector2(x, y) - Vector2(FRAME, FRAME) * 0.5 + Vector2(0.5, 0.5) - centre
			var u := p.dot(fwd) / radius.x    # 1 = the arc's tip ahead
			var v := p.dot(side) / radius.y
			if u <= 0.0:
				continue
			var r := sqrt(u * u + v * v)
			var angle := rad_to_deg(atan2(v, u))
			if angle < shape[0] or angle > shape[1]:
				continue
			var taper := pow(cos(deg_to_rad(angle)), TAPER)   # 1 mid-sweep, 0 at the ends
			var thickness: float = MAX_THICKNESS * shape[2] * taper
			if r > 1.0 or r < 1.0 - thickness or thickness < 0.04:
				continue
			var depth := (1.0 - r) / thickness    # 0 at the outer edge, 1 at the inner
			var c := CORE if depth < 0.35 else MID if depth < 0.7 else EDGE
			c.a = shape[3] * (1.0 if depth < 0.7 else 0.75)
			img.set_pixel(cell.x + x, cell.y + y, c)


## The three slashes' frames side by side, over the brick colour.
func _save_preview(sheet: Image) -> void:
	var img := Image.create(FRAMES * FRAME, SLASHES.size() * FRAME, false, Image.FORMAT_RGBA8)
	img.fill(Color8(40, 33, 32))
	img.blend_rect(sheet, Rect2i(0, 0, FRAMES * FRAME, SLASHES.size() * FRAME), Vector2i.ZERO)
	for x in range(0, img.get_width(), FRAME):
		for y in img.get_height():
			img.set_pixel(x, y, Color8(70, 60, 60))
	img.resize(img.get_width() * PREVIEW_SCALE, img.get_height() * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(PREVIEW_PATH))
