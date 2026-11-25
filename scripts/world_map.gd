class_name WorldMap
extends RefCounted
## Where the world's rooms sit on the map, worked out from their doors: from
## the first room, each door's room goes on the side the door's on, its door
## level with this one's. Nobody places rooms by hand; a room's place moves
## with its doors. Read once from the room scenes and kept (rooms() is
## cached), in tiles. The map page draws it (MapView).

const TILE := 32

## Room id -> {rect: Rect2i (on the map, in tiles), open: Image (a pixel per
## open cell), benches: Array[Vector2i] (cells, in the room)}.
static var _rooms := {}


## The rooms of the world joined by doors to LevelData.FIRST_ROOM.
static func rooms() -> Dictionary:
	if _rooms.is_empty():
		_rooms = _lay_out(LevelData.FIRST_ROOM)
	return _rooms


## Each room joined to `first`, placed by its doors.
static func _lay_out(first: String) -> Dictionary:
	var placed := {}
	var todo: Array = [[first, Vector2i.ZERO]]
	while not todo.is_empty():
		var next: Array = todo.pop_front()
		var id: String = next[0]
		if placed.has(id) or not LevelData.ROOMS.has(id):
			continue
		var room: Room = load(LevelData.ROOMS[id].scene).instantiate()
		room._read_painted_grid()
		var size := Vector2i(room._w, room._h)
		var at: Vector2i = next[1]
		var open := Image.create(size.x, size.y, false, Image.FORMAT_LA8)
		for y in size.y:
			for x in size.x:
				var kind: RoomArt.Kind = room._kind_at(x, y)
				if kind != RoomArt.Kind.SOLID:
					open.set_pixel(x, y, Color(1, 1, 1, 1))
		var benches: Array[Vector2i] = []
		for bench in room.entities_of(Bench):
			benches.append(Vector2i((bench.position / TILE).floor()) + Vector2i.UP)
		placed[id] = {"rect": Rect2i(at, size), "open": open, "benches": benches}
		for door in room.entities_of(RoomDoor):
			if placed.has(door.target_room) or not LevelData.ROOMS.has(door.target_room):
				continue
			var cell := Vector2i((door.position / TILE).round())
			var right := cell.x * 2 >= size.x
			var other := _door_into(door.target_room, id, door.arrive_at)
			if other.is_empty():
				continue
			# Level doorways, side by side.
			var y: int = at.y + cell.y + door.height - (other.cell.y + other.height)
			var x: int = at.x + size.x if right else at.x - other.width
			todo.append([door.target_room, Vector2i(x, y)])
		room.free()
	return placed


## The door in `room` leading back to `from` (or named `name`): its cell,
## height, and the room's width.
static func _door_into(room_id: String, from: String, door_name: String) -> Dictionary:
	var room: Room = load(LevelData.ROOMS[room_id].scene).instantiate()
	room._read_painted_grid()
	var found := {}
	for door in room.entities_of(RoomDoor):
		if (door_name != "" and String(door.name) == door_name) or (door_name == "" and door.target_room == from):
			found = {"cell": Vector2i((door.position / TILE).round()), "height": door.height, "width": room._w}
			break
	room.free()
	return found


## Whether you've been in `room` this game.
static func visited(room: String) -> bool:
	return GameState.has_flag(visited_flag(room))


static func visited_flag(room: String) -> String:
	return "visited_" + room
