class_name MapView
extends Control
## The pause menu's map: the world's rooms you've been in (WorldMap), each
## drawn as its open space, fitted into this control; the room you're in
## stands out, with a dot where you are and marks on its benches. Rooms you
## haven't been in aren't drawn.

const ROOM_COLOR := Color(0.55, 0.6, 0.7)
const HERE_COLOR := Color(0.95, 0.85, 0.55)
const EDGE_COLOR := Color(0.85, 0.9, 1.0, 0.5)
const YOU_COLOR := Color(1.0, 0.4, 0.35)
const BENCH_COLOR := Color(0.55, 0.95, 0.65)
const MARGIN := 12.0
const YOU_RADIUS := 4.0

## The room you're in, and where you are in it (px), set before showing.
var here := ""
var you := Vector2.ZERO

var _textures := {}   # room id -> its open space as a texture


## The rooms drawn: those you've been in, by id.
func shown_rooms() -> Array:
	return WorldMap.rooms().keys().filter(func(id): return WorldMap.visited(id))


## Tiles to px on screen, and the map's top-left in tiles.
func _fit() -> Array:
	var shown := shown_rooms()
	if shown.is_empty():
		return [1.0, Vector2.ZERO]
	var bounds: Rect2i = WorldMap.rooms()[shown[0]].rect
	for id in shown:
		bounds = bounds.merge(WorldMap.rooms()[id].rect)
	var room := size - Vector2.ONE * MARGIN * 2.0
	var scale := minf(room.x / bounds.size.x, room.y / bounds.size.y)
	var used := Vector2(bounds.size) * scale
	var origin := Vector2(MARGIN, MARGIN) + (room - used) * 0.5 - Vector2(bounds.position) * scale
	return [scale, origin]


## Where a room's rect (in tiles) is drawn.
func room_rect(id: String) -> Rect2:
	var fit := _fit()
	var rect: Rect2i = WorldMap.rooms()[id].rect
	return Rect2(Vector2(rect.position) * fit[0] + fit[1], Vector2(rect.size) * fit[0])


func _draw() -> void:
	var fit := _fit()
	var scale: float = fit[0]
	for id in shown_rooms():
		var info: Dictionary = WorldMap.rooms()[id]
		if not _textures.has(id):
			_textures[id] = ImageTexture.create_from_image(info.open)
		var rect := room_rect(id)
		draw_texture_rect(_textures[id], rect, false, HERE_COLOR if id == here else ROOM_COLOR)
		draw_rect(rect, EDGE_COLOR, false, 1.0)
		for cell: Vector2i in info.benches:
			draw_rect(Rect2(rect.position + (Vector2(cell) + Vector2(0.25, 0.25)) * scale, Vector2.ONE * scale * 1.5), BENCH_COLOR)
	if WorldMap.rooms().has(here) and WorldMap.visited(here):
		draw_circle(room_rect(here).position + you / WorldMap.TILE * scale, YOU_RADIUS, YOU_COLOR)
