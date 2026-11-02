class_name LightFlash
extends PointLight2D
## A brief flash of light: full at once, fading to nothing over `time`, then
## gone. Thrown by attacks (the player's slash, the Warden's slam) onto the
## room around them; see flash().

const HEIGHT := 48.0   # px out from the wall, so it shades the normal maps

var time := 0.15
var peak := 1.0
var _left := 0.0


## A flash at `at` in `parent`: `radius` px, `peak` energy, fading over `time` s.
static func flash(parent: Node, at: Vector2, colour: Color, radius: int, peak_energy: float, fade: float) -> LightFlash:
	var light := LightFlash.new()
	light.texture = FlickerLight.light_texture(radius)
	light.color = colour
	light.height = HEIGHT
	light.range_item_cull_mask = FlickerLight.LIT_ALL
	light.position = at
	light.peak = peak_energy
	light.time = fade
	parent.add_child(light)
	return light


func _ready() -> void:
	_left = time
	energy = peak


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	energy = peak * _left / time
