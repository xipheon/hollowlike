class_name LevelData
extends RefCounted
## The rooms of the game, each a room scene (see
## "Making rooms" in art/README.md). Add a room here so doors can lead to it
## (RoomDoor's target drop-down lists these ids) and a Level Select button can
## start it (LevelButton's room drop-down; the buttons are in main_menu.tscn).
## The rooms were ASCII rows until the editor overhaul; the tag
## ascii-to-editor-overhaul in git has the last version of them.

const ROOMS := {
	"first_test_room": {"scene": "res://scenes/first_test_room.tscn"},
	"boss": {"scene": "res://scenes/boss_room.tscn"},
	"climb": {"scene": "res://scenes/climb_room.tscn"},
	"aerie": {"scene": "res://scenes/aerie_room.tscn"},
	# The world (built by tools/build_world.gd, then edited by hand).
	"entrance": {"scene": "res://scenes/world/entrance.tscn"},
	"hub": {"scene": "res://scenes/world/hub.tscn"},
	"tunnels": {"scene": "res://scenes/world/tunnels.tscn"},
	"warden_arena": {"scene": "res://scenes/world/warden_arena.tscn"},
	"span": {"scene": "res://scenes/world/span.tscn"},
	"hawk_arena": {"scene": "res://scenes/world/hawk_arena.tscn"},
	"vault": {"scene": "res://scenes/world/vault.tscn"},
}
## The room a new game starts in, and the test rooms kept for trying things
## out (the main menu's Test rooms list, in debug builds).
const FIRST_ROOM := "entrance"
