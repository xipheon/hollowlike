class_name LevelData
extends RefCounted
## ASCII level layout. Edit freely, then press F5.
##   #  solid block        =  one-way platform     ^  spikes
##   ~  acid (instant kill)
##   B  boss (the Warden, stands on the floor)   F  boss (the Harrier, flies)
##   |  arena gate: all gates shut when the fight starts
##   o  coin (never respawns once taken)   h  health pickup (one heart)
##   P  player start       E  crawler enemy
##   c  crawler on the ceiling above this cell (drops on you)
##   K  sword knight
##   D  dash pickup        W  wall-jump pickup     >  door (left/right wall; see `doors`)
## Rows may be shorter than the widest row; missing tiles are empty.
## The outer border is automatically solid.
## Each room is its own scene (main.gd with `room` set). `doors` maps the wall a
## door is in ("left"/"right") to the room it leads to; you arrive next to the
## door in that room that leads back.
## A room can add "background": rows of the wall behind it (see
## RoomArt.BACKGROUND_LEGEND); without it the wall is decorated automatically.

const ROOMS := {
	"start": {"scene": "res://scenes/main.tscn", "doors": {"right": "boss"}, "rows": START_ROWS},
	"boss": {"scene": "res://scenes/boss_room.tscn", "doors": {"left": "start", "right": "climb"}, "rows": BOSS_ROWS},
	"climb": {"scene": "res://scenes/climb_room.tscn", "doors": {"left": "boss", "right": "aerie"}, "rows": CLIMB_ROWS},
	"aerie": {"scene": "res://scenes/aerie_room.tscn", "doors": {"left": "climb"}, "rows": AERIE_ROWS,
		"background": AERIE_BACKGROUND},
}

const START_ROWS := [
	"                                                                                                         #",
	"                                                                                                         #",
	"                                                                                                       o #",
	"                                                                                          o o          o #",
	"                                                                               o o       =====         o #",
	"                                                                              =====                    o #",
	"                                                                       oo                                #",
	"                                                      E               =====                              #",
	"                                         o       ###########                                             #",
	"                                        ====     ###########   ####                           oo         >",
	"                                                 ###########     c                           ####        >",
	"                      o                          ###########           E                             h   >",
	"                     ====                   ##   ###########         #####              ####       #######",
	"                o                           ##   ########                          E               #######",
	"               ====                         ##   ######## o                   #########            #######",
	"          o                            ==== ##=  #####################        c                    #######",
	"         ====                               ##   ###########                                       #######",
	"   P                       E              E ##o  ###########~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#######",
	"##############################    ##########################~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#######",
	"##############################^^^^########################################################################"
]

# Boss room. Enter at the bottom left: a corridor runs right to an acid gap only
# dash can cross. The left shaft climbs to the hallway into the arena (gated
# both sides); the right hallway leads on to the climb room and, through a
# one-way floor (down + jump), drops to the far side of the acid.
const BOSS_ROWS := [
	"##########################################################################################",
	"##########################################################################################",
	"##########################################################################################",
	"##########################################################################################",
	"#########################                            #####################################",
	"#########################                            #####################################",
	"#########################                            #####################################",
	"#########################                            ######        #######################",
	"#########################                            ######        #######################",
	"#########################                            ######        #######################",
	"#########################                            ##                  #################",
	"#                       |                            |                    ################",
	"#                       |                            |                    ################",
	"#                       |                            |                    ################",
	"#           h           |                        B   |               h oo ################",
	"#==========################################################        #######################",
	"#          ################################################        #######################",
	"#          ################################################        #######################",
	"# =====    ################################################        #######################",
	"#          ################################################        #######################",
	"#          ################################################        #######################",
	"#     =====################################################        #######################",
	"#          ################################################        #######################",
	"#  E       ################################################        #######################",
	"######                         c                                   #####          ########",
	"#                                                                  ####            #######",
	">     =====                                                                              >",
	">                                                                                        >",
	">  P                                      ###~~~~~~~~##                ##~~~~~~~~##      >",
	"##################~~~~~~~~########~~~~~~~~###~~~~~~~~#####################################",
	"##################~~~~~~~~########~~~~~~~~################################################",
]

# Vertical climb behind the boss arena; entered from the boss room's right hallway.
const CLIMB_ROWS := [
	"#                            #",
	"#                            >",
	"#                            >",
	"#                     oo oo  >",
	"#                 ############",
	"#                  c",
	"#        ======",
	"#",
	"#",
	"#               ======",
	"#",
	"#          o",
	"#        ======",
	"#",
	"# h",
	"#######",
	"#",
	"#        ======",
	"#",
	"#                o",
	"#              ======",
	"#",
	"#                         K",
	"#                      #######",
	"#                  o",
	"#                =====",
	"#",
	"#",
	"#          =====",
	"#",
	"#   K",
	"#########",
	"#",
	"#           =====",
	"#",
	"#                        K",
	"#                   ##########",
	"#              o",
	"#            ======",
	"#",
	"#       o",
	">     ======",
	">",
	">  P",
	"##############################",
	"##############################",
]

# The Harrier's arena, through the door at the top of the climb. One screen:
# a short hallway, a gate, and an open hall.
const AERIE_ROWS := [
	"##################################",
	"##################################",
	"##################################",
	"#####                            #",
	"#####                            #",
	"#####                            #",
	"#####                     F      #",
	"#####                            #",
	"#####                            #",
	"#####                            #",
	"#####                            #",
	"#####                            #",
	"#   |                            #",
	">   |                            #",
	">   |                            #",
	">  P|                            #",
	"##################################",
	"##################################",
]

# Most of the Aerie's back wall has caved in, opening the hall to the skyline.
const AERIE_BACKGROUND := [
	"",
	"",
	"",
	"            ....................",
	"        ........................",
	"      ..........................",
	"      ..........................",
	"      ..........................",
	"       .........................",
	"       ........................",
	"         ......................",
	"             ................",
	"  V               ..........",
]
