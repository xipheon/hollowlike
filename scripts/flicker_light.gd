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
## light (a PointLight2D, `light_radius` px, `light_energy` at full) shines on
## the room around it, following the same brightness. Optional
## `lit_overlay` is shown at the current brightness (the lit bulb drawn over a
## dead one); optional `dim_overlay` is shown at the opposite (a dark box over
## a sign's letters when it's out).

enum Kind { STEADY, SIGN, BROKEN }

const GLOW_BANDS := 4

static var _glow_textures := {}   # Vector2i size -> banded radial texture
static var _light_textures := {}  # int radius -> soft radial texture

var kind := Kind.STEADY
var glow_color := Color.WHITE
var glow_size := Vector2i(48, 48)
var glow_strength := 0.35
var light_radius := 96
var light_energy := 0.6
var light: PointLight2D   # the real light, made in _ready
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
	light = PointLight2D.new()
	light.texture = _light_texture(light_radius)
	light.color = glow_color
	add_child(light)
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
	if light != null:
		light.energy = light_energy * brightness
		light.enabled = brightness > 0.0
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


## A soft radial falloff for the real light: full in the middle, fading to
## nothing at `radius`.
static func _light_texture(radius: int) -> Texture2D:
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
