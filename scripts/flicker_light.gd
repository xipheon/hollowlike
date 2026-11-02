class_name FlickerLight
extends Node2D
## A light's glow, and the way it misbehaves:
##   STEADY  a working bulb: on, with a faint slow hum in brightness.
##   SIGN    an EXIT sign: on, but every few seconds it blinks out, stutters
##           or sags.
##   BROKEN  a dead bulb: dark, then every few seconds it sputters on in a
##           burst of fast flashes, sometimes catching and buzzing for a
##           moment before it dies again.
## The glow is banded rings drawn additively, so it stays pixel art. A real
## light (a PointLight2D, `light_radius` px, `light_energy` at full, hanging
## `light_height` px out from the wall) shines on the room around it, following
## the same brightness. Its height is what lets the normal maps shade: a light
## level with the wall would only graze a flat surface. With `shadows` on (the
## ceiling bulbs), solid ground and shut gates cast shadows from it: soft ones
## on the wall, and hard ones on the terrain itself, which only catches the
## light on a rim of its face (RoomArt.LIT_RIM); see MASK_WALL. Optional
## `lit_overlay` is shown at the current brightness (the lit bulb drawn over a
## dead one); optional `dim_overlay` is shown at the opposite (a dark box over
## a sign's letters when it's out).

enum Kind { STEADY, SIGN, BROKEN }

const GLOW_BANDS := 4
## Light masks. Most things (the wall, props, characters) are MASK_WALL; the
## room puts its Terrain and Gates layers on MASK_TERRAIN. A light that casts
## shadows lights MASK_WALL with soft shadows, and has a twin lighting
## MASK_TERRAIN with hard ones; every other light (make_light()) lights both,
## shadowless.
const MASK_WALL := 1
const MASK_TERRAIN := 2
const LIT_ALL := MASK_WALL | MASK_TERRAIN
## On the wall: soft, light shadows that add depth without hiding anything.
const SHADOW_COLOR := Color(0, 0, 0, 0.6)
const SHADOW_SMOOTH := 3.0
## On the terrain: past its lit rim, a sharp drop to none of this light.
const TERRAIN_SHADOW_COLOR := Color(0, 0, 0, 1)

static var _glow_textures := {}   # Vector2i size -> banded radial texture
static var _light_textures := {}  # int radius -> soft radial texture

var kind := Kind.STEADY
var glow_color := Color.WHITE
var glow_size := Vector2i(48, 48)
var glow_strength := 0.35
var light_radius := 96
var light_energy := 0.6
var light_height := 64.0
var shadows := false
var light: PointLight2D   # the real light, made in _ready
var terrain_light: PointLight2D   # with shadows: its twin, on the terrain and gates
var lit_overlay: CanvasItem
var dim_overlay: CanvasItem
var brightness := 1.0

var _rng := RandomNumberGenerator.new()
var _queue: Array = []   # [brightness, seconds] still to play
var _timer := 0.0
var _time := 0.0
var _phase := 0.0


func _ready() -> void:
	_rng.seed = hash(global_position)
	_phase = _rng.randf() * TAU
	material = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	light = make_light(light_radius, glow_color, light_energy, light_height)
	add_child(light)
	if shadows:
		light.range_item_cull_mask = MASK_WALL
		light.shadow_enabled = true
		light.shadow_color = SHADOW_COLOR
		light.shadow_filter = Light2D.SHADOW_FILTER_PCF13
		light.shadow_filter_smooth = SHADOW_SMOOTH
		terrain_light = make_light(light_radius, glow_color, light_energy, light_height)
		terrain_light.range_item_cull_mask = MASK_TERRAIN
		terrain_light.shadow_enabled = true
		terrain_light.shadow_color = TERRAIN_SHADOW_COLOR
		terrain_light.shadow_filter = Light2D.SHADOW_FILTER_NONE
		# Godot shadows an item only if this mask covers both the occluders
		# (on MASK_WALL, the tileset's default) and the item itself.
		terrain_light.shadow_item_cull_mask = LIT_ALL
		add_child(terrain_light)
	# Start part-way into a cycle so lights in a room don't keep time together.
	match kind:
		Kind.BROKEN:
			_queue = [[0.0, _rng.randf_range(0.2, 4.0)]]
		Kind.SIGN:
			_queue = [[1.0, _rng.randf_range(0.5, 6.0)]]
	_apply(1.0 if kind != Kind.BROKEN else 0.0)


func _process(delta: float) -> void:
	_time += delta
	if kind == Kind.STEADY:
		_apply(0.93 + 0.04 * sin(_time * 2.3 + _phase) + 0.03 * sin(_time * 7.1 + _phase * 2.0))
		return
	_timer -= delta
	while _timer <= 0.0:
		if _queue.is_empty():
			_queue = _sign_cycle() if kind == Kind.SIGN else _broken_cycle()
		var step: Array = _queue.pop_front()
		_apply(step[0])
		_timer += step[1]


## Mostly on; then one of: a few quick blinks, a sag, or a short outage that
## stutters back.
func _sign_cycle() -> Array:
	var out: Array = [[1.0, _rng.randf_range(3.0, 9.0)]]
	var roll := _rng.randf()
	if roll < 0.6:
		for i in _rng.randi_range(1, 3):
			out.append([0.0, _rng.randf_range(0.04, 0.09)])
			out.append([1.0, _rng.randf_range(0.05, 0.12)])
	elif roll < 0.85:
		out.append([0.55, _rng.randf_range(0.15, 0.4)])
	else:
		out.append([0.0, _rng.randf_range(0.3, 0.7)])
		out.append([0.6, 0.05])
		out.append([0.0, 0.06])
		out.append([0.8, 0.05])
	return out


## Dark; then a burst of flashes at uneven strength and spacing; sometimes it
## catches and buzzes (on, with brief dips) before dying.
func _broken_cycle() -> Array:
	var out: Array = [[0.0, _rng.randf_range(1.5, 6.0)]]
	for i in _rng.randi_range(2, 7):
		out.append([_rng.randf_range(0.5, 1.0), _rng.randf_range(0.03, 0.1)])
		out.append([0.0, _rng.randf_range(0.03, 0.16)])
	if _rng.randf() < 0.35:
		for i in _rng.randi_range(4, 12):
			var dip := _rng.randf() < 0.2
			out.append([0.2 if dip else _rng.randf_range(0.8, 1.0), 0.04 if dip else _rng.randf_range(0.05, 0.2)])
	return out


func _apply(value: float) -> void:
	brightness = value
	if lit_overlay != null:
		lit_overlay.modulate.a = brightness
	if dim_overlay != null:
		dim_overlay.modulate.a = 1.0 - brightness
	for real in [light, terrain_light]:
		if real != null:
			real.energy = light_energy * brightness
			real.enabled = brightness > 0.0
	queue_redraw()


func _draw() -> void:
	if brightness <= 0.0:
		return
	var tex := _glow_texture(glow_size)
	draw_texture(tex, -Vector2(glow_size) * 0.5, Color(glow_color, glow_strength * brightness))


## A radial glow in GLOW_BANDS flat rings, one texture pixel per screen pixel.
static func _glow_texture(size: Vector2i) -> Texture2D:
	if _glow_textures.has(size):
		return _glow_textures[size]
	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	gradient.offsets = PackedFloat32Array()
	gradient.colors = PackedColorArray()
	for i in GLOW_BANDS:
		gradient.add_point(float(i) / GLOW_BANDS, Color(1, 1, 1, 1.0 - float(i) / GLOW_BANDS))
	gradient.add_point(1.0, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = size.x
	tex.height = size.y
	_glow_textures[size] = tex
	return tex


## A light with no shadows, lighting everything (LIT_ALL): `radius` px,
## `colour`, `energy`, hanging `height` px out from the wall.
static func make_light(radius: int, colour: Color, energy: float, height: float) -> PointLight2D:
	var real := PointLight2D.new()
	real.texture = light_texture(radius)
	real.color = colour
	real.energy = energy
	real.height = height
	real.range_item_cull_mask = LIT_ALL
	return real


## A soft radial falloff for a real light (these, LightFlash, the player's):
## full in the middle, fading to nothing at `radius`.
static func light_texture(radius: int) -> Texture2D:
	if _light_textures.has(radius):
		return _light_textures[radius]
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = radius * 2
	tex.height = radius * 2
	_light_textures[radius] = tex
	return tex
