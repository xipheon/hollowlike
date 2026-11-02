class_name PlayerSprite
extends AnimatedSprite2D
## The player's animated sprite, built from a skin's sheet in art/sprites/.
## Every skin uses the same layout (art/templates/SHEETS.md): 64x64 frames, one
## animation per row, feet at the bottom centre, facing right. Rows that have
## no frames drawn yet fall back to another animation (FALLBACKS).

const FRAME := Vector2i(64, 64)

## Sheet rows, top to bottom: [animation, frames drawn, fps, loops].
## 0 frames = not drawn yet. tools/make_player_sheet.gd fills the rows.
const ROWS := [
	["idle", 6, 8.0, true],
	["run", 8, 12.0, true],
	["sprint", 0, 14.0, true],
	["jump", 3, 10.0, false],
	["fall", 2, 8.0, true],
	["land", 2, 12.0, false],
	["wall_slide", 4, 8.0, true],
	["wall_jump", 2, 10.0, false],
	["dash", 0, 16.0, false],
	["attack_side", 5, 20.0, false],
	["attack_up", 5, 20.0, false],
	["attack_down", 5, 20.0, false],
	["hurt", 0, 10.0, false],
	["death", 0, 10.0, false],
	["double_jump", 2, 10.0, false],
]
## What to show for an animation whose row isn't drawn yet.
const FALLBACKS := {
	"sprint": "run", "dash": "run", "hurt": "fall", "death": "fall",
	"double_jump": "jump", "wall_jump": "jump", "wall_slide": "fall", "land": "idle",
}

## Selectable looks: the same layout, a different sheet each. To add one, add
## it here and give it a recolour (or its own frames) in tools/make_player_sheet.gd.
const SKINS := [
	{"id": "classic", "name": "UI_SKIN_CLASSIC", "sheet": "res://art/sprites/player.png"},
	{"id": "pink", "name": "UI_SKIN_PINK", "sheet": "res://art/sprites/player_pink.png"},
]
const DEFAULT_SKIN := "classic"

var skin_id := ""


static func skin(id: String) -> Dictionary:
	for s in SKINS:
		if s.id == id:
			return s
	return SKINS[0]


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Rebuilds the animations from a skin's sheet, carrying on from the same
## animation and frame.
func apply_skin(id: String) -> void:
	var s := skin(id)
	skin_id = s.id
	var sheet: Texture2D = load(s.sheet)
	var current := animation
	var current_frame := frame
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row in ROWS.size():
		var r: Array = ROWS[row]
		if r[1] == 0:
			continue
		frames.add_animation(r[0])
		frames.set_animation_speed(r[0], r[2])
		frames.set_animation_loop(r[0], r[3])
		for f in r[1]:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(Vector2(f, row) * Vector2(FRAME), Vector2(FRAME))
			frames.add_frame(r[0], atlas)
	sprite_frames = frames
	if frames.has_animation(current):
		play(current)
		frame = mini(current_frame, frames.get_frame_count(current) - 1)
	else:
		play("idle")


## Plays an animation by name, or its fallback if that row isn't drawn yet.
## Does nothing if it's already playing, so one-shots run to the end, unless
## `restart` (a new swing while the last one's still showing).
func play_state(state: String, restart := false) -> void:
	var anim := state
	while not sprite_frames.has_animation(anim) and FALLBACKS.has(anim):
		anim = FALLBACKS[anim]
	if not sprite_frames.has_animation(anim):
		anim = "idle"
	if animation != anim or restart:
		play(anim)
		frame = 0


## How long an animation takes to play through once, in seconds.
static func length(anim: String) -> float:
	for r in ROWS:
		if r[0] == anim:
			return r[1] / r[2]
	return 0.0
