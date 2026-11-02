class_name LevelData
extends RefCounted
## The rooms of the game, each made in the editor as a room scene (see
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
}
