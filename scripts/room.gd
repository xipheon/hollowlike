@tool
class_name Room
extends Node2D
## A room made in the editor (start from scenes/rooms/room_template.tscn):
##   Skyline     the far city, behind everything
##   Background  the wall behind the room (background_tileset.tres)
##   Terrain     what you stand on and what hurts (foreground_tileset.tres)
##   Gates       arena gates, shut during a boss fight (foreground_tileset.tres)
##   Entities    placed enemies, bosses, PlayerStart, RoomDoors and Arenas
## Paint with the tilesets' terrain brushes or tile by tile; what each tile
## does comes from its custom data (see tools/make_tilesets.gd).
## The rooms still play from LevelData's ASCII rows for now; this scene
## takes over in the next step of the overhaul.

## This room's id in LevelData.ROOMS.
@export var room_id := ""
## Fill the parts of the wall you haven't painted with brick, windows, lights,
## posters and graffiti when the room loads (the same every time). Wall you
## paint by hand is always kept as it is. Off: unpainted wall stays open, and
## the skyline shows through.
@export var auto_decorate := true


func background() -> TileMapLayer:
	return $Background


func terrain() -> TileMapLayer:
	return $Terrain


func gates() -> TileMapLayer:
	return $Gates


func entities() -> Node2D:
	return $Entities
