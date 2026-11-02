class_name ColorGrade
extends Resource
## A room's colour grade: the last touch to how it looks, over everything in
## it (lights, shadows, glow) but under the HUD and menus. Set a room's `grade`
## in the Inspector; rooms that don't use art/grades/default_grade.tres. Drawn
## by shaders/color_grade.gdshader. Each setting at its default leaves the
## picture as it is.

## Multiplies every colour: above 1 brighter, below darker.
@export_range(0.0, 2.0, 0.01) var brightness := 1.0
## Pushes darks darker and lights lighter (above 1), or pulls them together.
@export_range(0.0, 2.0, 0.01) var contrast := 1.0
## 0 is grey, 1 as drawn, above 1 more vivid.
@export_range(0.0, 2.0, 0.01) var saturation := 1.0
## Tints the dark parts of the picture, fading out toward the light parts...
@export var shadow_tint := Color.WHITE
## ...and this tints the light parts. E.g. cool shadows, warm highlights.
@export var highlight_tint := Color.WHITE
## Optional lookup table, for a full grade from a paint program: a 256x16
## strip of sixteen 16x16 squares, the colour each colour becomes. Start from
## art/grades/neutral_lut.png (which changes nothing; tools/make_neutral_lut.gd
## makes it), recolour a copy, and set it here. Empty: none.
@export var lut: Texture2D
## How much of the lookup table's grade to use.
@export_range(0.0, 1.0, 0.01) var lut_strength := 1.0
