extends SceneTree
## Draws the four floor-spike tiles (SPIKE, SPIKE 2-4 on the tile sheet):
## broken glass shards and snapped rebar on a strip of rubble, with the odd gap.
## Nearly everything stays inside the bottom 24 px where spikes hurt; a few tips
## poke a couple of px above. Each variant is laid out at random from its own
## seed, so rerunning gives the same tiles; change a seed to reroll one.
## Colours follow the PixelLab spike image. Also writes a preview beside that
## image. Run from the project folder:
##   godot --headless --path . --script res://tools/make_spike_tiles.gd

const TILE := 32
const FLOOR_Y := 31               # bottom row of the tile
const DAMAGE_TOP := TILE - 24     # spikes hurt from here down (main.gd SPIKE_HEIGHT)
const SHEET_PATH := "res://art/tiles/tileset.png"
const RAW_PATH := "res://art/tiles/source/spikes_raw.png"
const PREVIEW_PATH := "res://art/tiles/source/spikes_preview.png"
const PREVIEW_SCALE := 4
const SPIKE_CELLS := [Vector2i(4, 4), Vector2i(5, 4), Vector2i(3, 6), Vector2i(4, 6)]
const SEEDS := [11, 23, 37, 58]   # one per variant

const OUTLINE := Color8(22, 22, 26)
const GLASS_DARK := Color8(86, 128, 120)
const GLASS := Color8(148, 196, 182)
const GLASS_LIGHT := Color8(212, 236, 226)
const REBAR_DARK := Color8(92, 42, 22)
const REBAR := Color8(150, 72, 36)
const REBAR_LIGHT := Color8(190, 104, 56)
const RUBBLE := [Color8(150, 150, 152), Color8(122, 122, 126), Color8(96, 96, 100)]

# Layout odds. Heights are px above the floor; DAMAGE_TOP is 24 px up.
const GAP_CHANCE := 0.16       # a stretch of bare rubble instead of the next spike
const GAP_WIDTH := Vector2i(4, 7)
const REBAR_CHANCE := 0.3      # otherwise a glass shard
const TALL_CHANCE := 0.1       # a spike that pokes just above the damage zone
const HEIGHT := Vector2i(9, 23)
const TALL_HEIGHT := Vector2i(24, 26)
const SHARD_WIDTH := Vector2i(6, 11)


func _init() -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SHEET_PATH))
	sheet.convert(Image.FORMAT_RGBA8)
	var tiles: Array[Image] = []
	for v in SEEDS.size():
		var tile := _draw_variant(_layout(SEEDS[v]), v)
		tiles.append(tile)
		var at: Vector2i = SPIKE_CELLS[v] * TILE
		sheet.fill_rect(Rect2i(at, Vector2i(TILE, TILE)), Color(0, 0, 0, 0))
		sheet.blit_rect(tile, Rect2i(0, 0, TILE, TILE), at)
	sheet.save_png(ProjectSettings.globalize_path(SHEET_PATH))
	_save_preview(tiles)
	print("Wrote spike tiles to %s and preview to %s" % [SHEET_PATH, PREVIEW_PATH])
	quit()


func _noise(x: int, y: int, salt: int) -> float:
	return float(absi(hash(Vector3i(x, y, salt))) % 1000) / 1000.0


## Walks across the tile placing shards, rebar and gaps. Returns shards as
## [base x, base width, height, lean] and rebar as [x, height, lean]. Shards
## stay a pixel inside the tile so none is cut off at a tile edge.
func _layout(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := {"rebar": [], "shards": []}
	var x := rng.randi_range(1, 3)
	while x < TILE - 2:
		if rng.randf() < GAP_CHANCE:
			x += rng.randi_range(GAP_WIDTH.x, GAP_WIDTH.y)
			continue
		var tall := rng.randf() < TALL_CHANCE
		var height := rng.randi_range(TALL_HEIGHT.x, TALL_HEIGHT.y) if tall else rng.randi_range(HEIGHT.x, HEIGHT.y)
		if rng.randf() < REBAR_CHANCE:
			out.rebar.append([x, height, rng.randi_range(-1, 1)])
			x += rng.randi_range(3, 4)
		else:
			var width := rng.randi_range(SHARD_WIDTH.x, SHARD_WIDTH.y)
			var centre := clampi(x + width / 2, 1 + width / 2, TILE - 2 - width / 2)
			out.shards.append([centre, width, height, rng.randi_range(-2, 2)])
			x = centre + rng.randi_range(2, width / 2 + 2)
	return out


func _draw_variant(v: Dictionary, salt: int) -> Image:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	for r in v.rebar:
		_rebar(img, r[0], r[1], r[2])
	for s in v.shards:
		_shard(img, s[0], s[1], s[2], s[3])
	_rubble(img, salt)
	_outline(img)
	return img


func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < TILE and y >= 0 and y < TILE:
		img.set_pixel(x, y, c)


## A 2 px rod leaning `lean` px over its height, ribbed, with a snapped tip.
func _rebar(img: Image, x: int, height: int, lean: int) -> void:
	for i in height:
		var y := FLOOR_Y - i
		var cx := x + roundi(lean * float(i) / height)
		var rib := i % 3 == 0
		_put(img, cx, y, REBAR_DARK)
		_put(img, cx + 1, y, REBAR_LIGHT if rib else REBAR)
	_put(img, x + lean + (1 if lean >= 0 else 0), FLOOR_Y - height, REBAR)   # jagged snap


## A glass shard: a tapering wedge, dark on its left face, light on its right,
## with a bright edge running up to the tip.
func _shard(img: Image, x: int, width: int, height: int, lean: int) -> void:
	for i in height + 1:
		var t := float(i) / height
		var y := FLOOR_Y - i
		var centre := x + lean * t
		var half := width * 0.5 * (1.0 - t)
		var left := roundi(centre - half)
		var right := roundi(centre + half)
		for px in range(left, right + 1):
			var c := GLASS_DARK if px < roundi(centre) else GLASS
			if px == roundi(centre) and i > 1:
				c = GLASS_LIGHT
			_put(img, px, y, c)


## Lumpy concrete rubble along the floor, 3-5 px deep. Both ends are 4 px so
## the two variants sit side by side in any order.
func _rubble(img: Image, salt: int) -> void:
	for x in TILE:
		var depth := 4 if x == 0 or x == TILE - 1 else 3 + int(_noise(x / 2, 0, 20 + salt) * 3)
		for d in depth:
			var c: Color = RUBBLE[0] if d == depth - 1 else RUBBLE[1]
			if _noise(x, d, 30 + salt) < 0.2:
				c = RUBBLE[2]
			_put(img, x, FLOOR_Y - d, c)


## A dark outline around the shapes, except along the floor and the tile's
## sides (so neighbouring tiles join).
func _outline(img: Image) -> void:
	var src := img.duplicate() as Image
	for y in TILE - 1:
		for x in range(1, TILE - 1):
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
				if src.get_pixelv(Vector2i(x, y) + d).a > 0.0:
					img.set_pixel(x, y, OUTLINE)
					break


## Top: each variant on its own. Middle: a long row mixing them. Bottom: the
## PixelLab image for comparison. Red lines mark where the damage zone starts.
const PREVIEW_ROW := [0, 2, 1, 3, 0, 1, 2, 3]


func _save_preview(tiles: Array[Image]) -> void:
	var count := PREVIEW_ROW.size()
	var img := Image.create(count * TILE, TILE * 3 + 16, false, Image.FORMAT_RGBA8)
	img.fill(Color8(40, 33, 32))
	for i in tiles.size():
		img.blend_rect(tiles[i], Rect2i(0, 0, TILE, TILE), Vector2i(i * TILE * 2, 0))
	for x in range(0, img.get_width(), 2):
		img.set_pixel(x, DAMAGE_TOP, Color8(230, 60, 60))
	for i in count:
		img.blend_rect(tiles[PREVIEW_ROW[i]], Rect2i(0, 0, TILE, TILE), Vector2i(i * TILE, TILE + 8))
	for x in range(0, img.get_width(), 2):
		img.set_pixel(x, TILE + 8 + DAMAGE_TOP, Color8(230, 60, 60))
	var raw_y := TILE * 2 + 16
	for x in range(0, img.get_width(), 2):
		img.set_pixel(x, DAMAGE_TOP, Color8(230, 60, 60))
	if FileAccess.file_exists(RAW_PATH):
		var raw := Image.load_from_file(ProjectSettings.globalize_path(RAW_PATH))
		raw.convert(Image.FORMAT_RGBA8)
		for i in count / 2:
			img.blend_rect(raw, Rect2i(Vector2i.ZERO, raw.get_size()), Vector2i(i * raw.get_width(), raw_y))
		for x in range(0, img.get_width(), 2):
			img.set_pixel(x, raw_y + DAMAGE_TOP, Color8(230, 60, 60))
	img.resize(img.get_width() * PREVIEW_SCALE, img.get_height() * PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(PREVIEW_PATH))
