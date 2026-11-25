class_name Reach
extends RefCounted
## Works out where the player could possibly get to in a room, from its
## layout and the player's own movement settings (Player's exported jump,
## dash and wall jump values), for a given set of abilities. Used to prove a
## path is locked: if a door isn't in reach without the dash, no amount of
## skill gets you there.
##
## It errs on the side of reaching too much, never too little. Heights are
## exact (to the pixel, at the top of each jump and wall jump; the dash never
## goes up, but stops your fall wherever it starts); sideways
## it works in whole tiles with a tile of slack, ignores ceilings cutting a
## jump short, and lets a dash or wall jump start from anywhere you can be in
## the air. So "out of reach" here is certain, and "in reach" means "not ruled
## out": that a path really can be done is for a played test to show. It knows
## the dash and the wall jump, and stamina if the player uses it (otherwise
## wall jumps are endless); not the double jump or sprint, which the game
## doesn't give out, nor bouncing off enemies or riding moving platforms.

const TILE := 32
## One way of leaving the ground or changing course in the air.
enum Launch { JUMP, WALL_JUMP, DASH_END, FALL }
const FALL_RISE := 4.0        # px: walking or dashing off an edge lifts you nothing, give or take
const DASH_SAMPLE := 16.0     # px between the points checked along a dash's path
const DIAGONAL := 0.70710678

var _w := 0
var _h := 0
var _kinds := PackedByteArray()   # RoomArt.Kind per cell, row by row
var _player: Player
var _g := 0.0
var _fall_g := 0.0
var _rise := {}            # Launch -> px it lifts your feet
var _dash_length := 0.0    # px a dash covers
var _wall_jumps := 0       # how many a full stamina bar pays for
var _free_wall_jumps := false   # no stamina: as many as you like

# One cells_from() at a time:
var _dash := false
var _wall_jump := false
var _reached := PackedByteArray()
var _todo: Array = []         # launches to try, by wall jumps used: [launch, x, feet y, wall jumps, dashed]
var _tried := {}              # launch and cell -> the launches tried from there
var _falls: Array = []        # cells to fall through: [x, row, wall jumps, dashed]
var _fallen := {}             # cell -> [wall jumps, dashed] it's been fallen through with
var _dashed_from := {}        # cell -> [feet y, wall jumps] it's been dashed from


## `kind_at` answers what's at (x, y) as a RoomArt.Kind (Room._kind_at, after
## the room has read its layout). `player` is read for its movement settings.
func _init(kind_at: Callable, width: int, height: int, player: Player) -> void:
	_w = width
	_h = height
	_kinds.resize(_w * _h)
	for y in _h:
		for x in _w:
			_kinds[y * _w + x] = kind_at.call(x, y)
	_player = player
	_g = player.gravity
	_fall_g = player.gravity * player.fall_gravity_multiplier
	var tick := 1.0 / Engine.physics_ticks_per_second
	_rise[Launch.JUMP] = _rise_at(player.jump_velocity)
	_rise[Launch.WALL_JUMP] = _rise_at(player.wall_jump_velocity.y)
	_rise[Launch.DASH_END] = FALL_RISE   # the dash never goes up: it ends level or falling
	_rise[Launch.FALL] = FALL_RISE
	_dash_length = player.dash_speed * (player.dash_duration + tick)
	_free_wall_jumps = not player.use_stamina
	_wall_jumps = 0 if _free_wall_jumps else int(player.max_stamina / player.wall_jump_stamina_cost)


## A room's layout, read from its painted tiles (the room needn't be in the
## scene tree).
static func of_room(room: Room, player: Player) -> Reach:
	room._read_painted_grid()
	return Reach.new(room._kind_at, room._w, room._h, player)


## How high a jump lifts your feet, in px.
func jump_rise() -> float:
	return _rise[Launch.JUMP]


## How high leaving at `speed` px/s upward lifts you, in px: the arc's
## height, plus the half step the game's physics ticks add to it.
func _rise_at(speed: float) -> float:
	return speed * speed / (2.0 * _g) + absf(speed) / (2.0 * Engine.physics_ticks_per_second)


## The cell you stand in having come through `door` (one of this room's
## RoomDoors): two tiles inside it, on its bottom row (Room._door_stand_point).
func door_stand(door: RoomDoor) -> Vector2i:
	var at := Vector2i((door.position / TILE).round())
	var inward := 1 if at.x * 2 < _w else -1
	return Vector2i(at.x + inward * 2, at.y + door.height - 1)


## The cells of `door`'s doorway.
func door_cells(door: RoomDoor) -> Array[Vector2i]:
	var at := Vector2i((door.position / TILE).round())
	var cells: Array[Vector2i] = []
	for i in door.height:
		cells.append(at + Vector2i(0, i))
	return cells


## Whether you can stand in `cell`: it's open, with ground or a catwalk under it.
func can_stand(cell: Vector2i) -> bool:
	return _open(cell.x, cell.y) and _holds(cell.x, cell.y + 1)


func kind(cell: Vector2i) -> RoomArt.Kind:
	return _kind(cell.x, cell.y)


## Every cell (Vector2i -> true) your feet could be in, starting stood in
## `from`, with `abilities` (any of "dash", "wall_jump").
func cells_from(from: Vector2i, abilities: Array) -> Dictionary:
	_dash = "dash" in abilities
	_wall_jump = "wall_jump" in abilities
	_reached = PackedByteArray()
	_reached.resize(_w * _h)
	_todo = []
	for i in _wall_jumps + 1:
		_todo.append([])
	_tried = {}
	_falls = []
	_fallen = {}
	_dashed_from = {}
	_launch(Launch.JUMP, from.x, (from.y + 1) * TILE, 0, false)
	while true:
		if not _falls.is_empty():
			var fall: Array = _falls.pop_back()
			_fall_through(fall[0], fall[1], fall[2], fall[3])
			continue
		# Fewest wall jumps used first, so each launch is tried at its best.
		var next: Array = []
		for bucket: Array in _todo:
			if not bucket.is_empty():
				next = bucket.pop_back()
				break
		if next.is_empty():
			break
		_fly(next[0], next[1], next[2], next[3], next[4])
	var cells := {}
	for i in _reached.size():
		if _reached[i] == 1:
			@warning_ignore("integer_division")
			cells[Vector2i(i % _w, i / _w)] = true
	return cells


## Whether any of `cells` (say a doorway's) is in reach from `from`.
func reaches_any(from: Vector2i, cells: Array, abilities: Array) -> bool:
	var reached := cells_from(from, abilities)
	for cell in cells:
		if reached.has(cell):
			return true
	return false


func _kind(x: int, y: int) -> RoomArt.Kind:
	if x < 0 or y < 0 or x >= _w or y >= _h:
		return RoomArt.Kind.SOLID
	return _kinds[y * _w + x] as RoomArt.Kind


## Open to move through: air, a catwalk (from below or the side), a doorway,
## a raised gate. Not ground, and not spikes or acid, which send you back.
func _open(x: int, y: int) -> bool:
	var k := _kind(x, y)
	return k == RoomArt.Kind.EMPTY or k == RoomArt.Kind.PLATFORM or k == RoomArt.Kind.DOOR or k == RoomArt.Kind.GATE


## Holds you up: ground or a catwalk.
func _holds(x: int, y: int) -> bool:
	var k := _kind(x, y)
	return k == RoomArt.Kind.SOLID or k == RoomArt.Kind.PLATFORM


## The row feet at `y` px are in (feet on a floor are in the row above it).
func _row(y: float) -> int:
	return ceili(y / TILE) - 1


## Queues a launch, unless one as good or better has been tried from there:
## as high or higher, with as few wall jumps used, and the dash unused if
## this one's is.
func _launch(launch: Launch, x: int, y: float, jumps: int, dashed: bool) -> void:
	var row := _row(y)
	if not _open(x, row):
		return
	var key := (row * _w + x) * 4 + launch
	var before: Array = _tried.get(key, [])
	for b: Array in before:
		if b[0] <= y + 0.5 and b[1] <= jumps and (dashed or not b[2]):
			return
	before.append([y, jumps, dashed])
	_tried[key] = before
	_todo[jumps].append([launch, x, y, jumps, dashed])


## Everywhere a launch takes your feet on the way up and back down to the row
## it began in: open cells joined to its start, no higher than it lifts you,
## and no further sideways than you can steer before falling past each row.
## Below that row it's a fall (_fall_through).
func _fly(launch: Launch, x0: int, y0: float, jumps: int, dashed: bool) -> void:
	var rise: float = _rise[launch]
	var top := y0 - rise                    # the highest your feet get, px
	var row0 := _row(y0)
	var top_row := floori(top / TILE)
	var time_up := sqrt(2.0 * rise / _g) + (_player.coyote_time if launch == Launch.JUMP else 0.0)
	var spans := PackedInt32Array()         # per row from top_row: columns either way
	for row in range(top_row, row0 + 1):
		# A body's width of overhang at both ends, and a tile for where in
		# their tiles the two ends are.
		var px := _player.run_speed * (time_up + _fall_time((row + 1) * TILE - top)) + Player.BODY_SIZE.x + TILE
		spans.append(int(px / TILE))
	var found: Array[Vector2i] = [Vector2i(x0, row0)]
	var seen := {found[0]: true}
	var i := 0
	while i < found.size():
		var at := found[i]
		i += 1
		_be_at(at.x, at.y, maxf(top, at.y * TILE), jumps, dashed)
		for d: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next := at + d
			if next.y < top_row or next.y > row0 or seen.has(next) or not _open(next.x, next.y):
				continue
			if absi(next.x - x0) > spans[next.y - top_row]:
				continue
			seen[next] = true
			found.append(next)
	# A dash along the ground leaves the air dash unspent, and can carry you
	# off a ledge.
	if launch == Launch.JUMP and _dash:
		for side: int in [-1, 1]:
			for step in range(1, int((_dash_length + TILE) / TILE) + 1):
				if not _open(x0 + side * step, row0):
					break
				_launch(Launch.FALL, x0 + side * step, y0, 0, false)


## Your feet can be in this cell, as high as `y` px: what follows from that.
func _be_at(x: int, row: int, y: float, jumps: int, dashed: bool) -> void:
	_reached[row * _w + x] = 1
	if _holds(x, row + 1):
		_launch(Launch.JUMP, x, (row + 1) * TILE, 0, false)   # land: stamina and the dash come back
	# Your body is up to two cells tall: a wall beside either will do.
	if _wall_jump and (_free_wall_jumps or jumps < _wall_jumps) and (_beside_wall(x, row) or _beside_wall(x, row - 1)):
		_launch(Launch.WALL_JUMP, x, y, jumps if _free_wall_jumps else jumps + 1, dashed)
	if _dash and not dashed:
		_dash_from(x, row, y, jumps)
	# And down from here: straight, or a column either way.
	for dx: int in [-1, 0, 1]:
		if _open(x + dx, row + 1) and (dx == 0 or _open(x + dx, row)):
			_fall(x + dx, row + 1, jumps, dashed)


func _beside_wall(x: int, row: int) -> bool:
	return _kind(x - 1, row) == RoomArt.Kind.SOLID or _kind(x + 1, row) == RoomArt.Kind.SOLID


func _fall(x: int, row: int, jumps: int, dashed: bool) -> void:
	var key := row * _w + x
	var before: Array = _fallen.get(key, [])
	for b: Array in before:
		if b[0] <= jumps and (dashed or not b[1]):
			return
	before.append([jumps, dashed])
	_fallen[key] = before
	_falls.append([x, row, jumps, dashed])


## Falling through a cell: anywhere in it, so as high as its top.
func _fall_through(x: int, row: int, jumps: int, dashed: bool) -> void:
	_be_at(x, row, row * TILE, jumps, dashed)


## The air dash, from feet at `y` in this cell: to a side, or down (straight
## or at an angle); a launch from wherever each can end, level or falling.
func _dash_from(x: int, row: int, y: float, jumps: int) -> void:
	var key := row * _w + x
	var before: Array = _dashed_from.get(key, [])
	for b: Array in before:
		if b[0] <= y + 0.5 and b[1] <= jumps:
			return
	before.append([y, jumps])
	_dashed_from[key] = before
	_dash_to(x, y, x, y + _dash_length, jumps, true)
	var across := _dash_length * DIAGONAL
	for side: int in [-1, 1]:
		# A dash that meets a wall slides along it, so it can end short.
		for step in range(1, int((across + TILE) / TILE) + 1):
			_dash_to(x, y, x + side * step, y + across, jumps, true)
		for step in range(1, int((_dash_length + TILE) / TILE) + 1):
			_dash_to(x, y, x + side * step, y, jumps, true)


## `spent`: whether it was the air dash (one from the ground isn't). A dash
## that hits the floor stops there, so one ending below it lands on it.
func _dash_to(x: int, y: float, to_x: int, to_y: float, jumps: int, spent: bool) -> void:
	var from := Vector2((x + 0.5) * TILE, y)
	var to := Vector2((to_x + 0.5) * TILE, to_y)
	var steps := maxi(ceili(from.distance_to(to) / DASH_SAMPLE), 1)
	var last := from
	for i in range(1, steps + 1):
		var p := from.lerp(to, float(i) / steps)
		if not _open(floori(p.x / TILE), _row(p.y)):
			break
		last = p
	if last != from:
		_launch(Launch.DASH_END, floori(last.x / TILE), last.y, jumps, spent)
	if _clear(from, to) or (_clear(from, Vector2(to.x, from.y)) and _clear(Vector2(to.x, from.y), to)) \
			or (_clear(from, Vector2(from.x, to.y)) and _clear(Vector2(from.x, to.y), to)):
		_launch(Launch.DASH_END, to_x, to_y, jumps, spent)


## Whether feet can go straight from `from` to `to` (px) through open cells.
func _clear(from: Vector2, to: Vector2) -> bool:
	var steps := maxi(ceili(from.distance_to(to) / DASH_SAMPLE), 1)
	for i in steps + 1:
		var p := from.lerp(to, float(i) / steps)
		if not _open(floori(p.x / TILE), _row(p.y)):
			return false
	return true


## Seconds to fall `px` from rest, with the fall's heavier gravity and top speed.
func _fall_time(px: float) -> float:
	var top := _player.max_fall_speed
	var to_top := top * top / (2.0 * _fall_g)   # px fallen reaching top speed
	if px <= to_top:
		return sqrt(2.0 * maxf(px, 0.0) / _fall_g)
	return top / _fall_g + (px - to_top) / top
