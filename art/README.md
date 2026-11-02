# Art pipeline

The game currently draws everything in code (`_draw()` in each script). This folder holds the real art that will replace it.

```
art/
  templates/   guide sheets (not imported by Godot) and SHEETS.md, the exact layout of each sheet
  sprites/     finished character, effect and pickup sheets go here
  tiles/       finished tileset goes here
```

## 1. Choose a style and scale

The game renders at 960 x 540, and one tile is 32 x 32 game pixels. The templates are drawn at that 1x size.

- **Pixel art.** Draw at 1x, straight on the templates. The texture filter gets set to *Nearest* so pixels stay crisp when the window is scaled up.
- **Smooth or painted art.** Draw at 2x or 4x for detail, then export at 1x (or keep the larger size, and Sprite2D scales it down). To get bigger guides, run:

  ```bash
  godot --headless --path . --script res://tools/make_art_templates.gd -- --scale=2
  ```

  This overwrites the 1x guides. Rerun without `--scale` to get them back.

Pick one style for the whole game before drawing much: mixing pixel and smooth art looks off.

## 2. Draw on a template

Any editor with layers works: Aseprite, LibreSprite, Krita, Photoshop or Piskel.

1. Open `templates/<name>_guide.png`. Lock that layer and lower its opacity.
2. Draw on a new transparent layer above it. Each row is one animation, read left to right. `templates/SHEETS.md` lists the frame counts, speeds and what each row is.
3. Keep the character over the **red pivot**, which is the feet for walkers and the centre for fliers. Keep the body roughly inside the **blue collision box**. Arms, weapons and wings can go outside the box.
4. Face **right**. The game mirrors sprites for the left.
5. Leave grey X cells empty. Leave the background transparent.
6. Hide the guide layer and export a PNG at exactly the guide's size to `sprites/<name>.png`, or `tiles/tileset.png` for tiles.

You don't have to finish a sheet in one go. Placeholder frames are fine: a few rough frames per row is enough to test timing in game.

## 3. Hook the art up in Godot

Tell Claude when a sheet is in place, and it will be wired in:

- **Characters.** An `AnimatedSprite2D` replaces the `_draw()` placeholder. It is built straight from the sheet using the layout in SHEETS.md, and each state plays the matching row. Flashes and tints (damage, the phase-two colour, telegraph colours) stay in code as `modulate`.
- **Tiles.** `tiles/foreground_tileset.tres`, `tiles/background_tileset.tres` and `tiles/props_tileset.tres`, built by `tools/make_tilesets.gd`, with *Match Sides* terrain brushes. Rooms are painted with them in the editor (see Making rooms below). Collisions come from code, from each tile's `kind`.

The layouts are fixed, so a sheet can be swapped or redrawn later without touching the game code. Only resizing a frame or adding a row needs a code change. To do that, edit `SHEETS` in `tools/make_art_templates.gd`, rerun it, and update your drawing to match.


## Making rooms

Rooms are scenes made in the Godot editor. Each tile you paint says what it is (its `kind` custom data: solid, platform, spikes, acid, door, gate), and the room builds its collisions and hazards from that when it loads.

1. **Start from the template.** Duplicate `scenes/rooms/room_template.tscn` (right-click it in the FileSystem dock, then *Duplicate*). Rename the root node, and set its `room` to the new room's id.
   - Its look is also on the root, in the Inspector, and only shows in game. **Dimming** darkens the room a little so its lights stand out. **Grade** is a colour grade (a `ColorGrade`: brightness, contrast, saturation, shadow and highlight tints, and an optional lookup table to start from `art/grades/neutral_lut.png`). Leave it empty for `art/grades/default_grade.tres`.
2. **Add it to the game.** Add the id and scene path to `ROOMS` in `scripts/level_data.gd`. Doors can then lead to it. To list it in the Level Select, open `scenes/main_menu.tscn` and duplicate a button under `Center/LevelBox/Levels`, then set its text, its **Room**, and any **Abilities** to start with (dash, for a room past the Warden). Show `LevelBox` (the eye icon) to see the list while you edit it.
3. **Paint the Terrain layer** with `art/tiles/foreground_tileset.tres`. The room's top-left corner is cell (0, 0). Use the *Terrains* tab for brushes that pick the right edge tiles on their own: **concrete** for solid ground, **catwalk** for one-way platforms, **spikes**, and **sewer** for acid water. To place one exact tile, pick it from the *Tiles* tab instead. Door tiles go here too.
4. **Moving platforms.** Paint a track on the Terrain layer with the **track** brush. A track is a straight line, either side to side or up and down. Then drag `scenes/props/moving_platform.tscn` onto Entities and put its origin, the middle of the deck's top edge, on the track.
   - **Side to side:** the deck rides along the rail at the top of the track tiles, and stays between the end stops.
   - **Up and down:** the deck stays centred on the rail.

   Platforms go back and forth and pause at each end. Set `width_tiles`, `speed` and `end_pause` in the Inspector. A platform placed off a track stays still.
5. **Paint the Gates layer** where a boss arena's gates go, with the shut gate tiles. They show raised until a fight starts, then drop shut.
6. **Paint the wall (Background layer).** The game shows exactly what you paint here. Any cell left empty is open, and the skyline shows through it.
   - Press **Decorate wall** in the root's Inspector to fill every empty cell with brick and windows, and hang lights, posters and graffiti on the Props layer. Cells you've already painted are kept. Then edit the result by hand.
   - Or paint the wall yourself. Use the **wall** brush (Terrains tab) for brick: it gives a crumbled edge only where brick meets an empty cell. Windows count as wall, so painting brick around them leaves them alone and adds no edges.
   - Windows come from the **Tiles** tab. Each one has its own brick around it, so it takes the place of brick cells: drag across all of its tiles in the picker, then click once in the room. The large rusty window is also in the **Patterns** tab: click it, then click once in the room.
   - Window glass is see-through. In the editor the skyline is repeated down the whole room so every window shows the city. In game the skyline stays at screen height.

   Save the scene to keep the wall.
7. **Hang props on the wall (Props layer)** with `art/tiles/props_tileset.tres`. Props have nothing behind them, so paint brick on the Background first, then the prop over it on Props. The tileset has two sheets, each its own entry in the **Tiles** tab:
   - **Props** (`props.png`): posters, graffiti, hazard stripes, lit and dead bulbs (they glow and flicker in game), and the steel girder, which stacks into a column. For a piece more than one tile wide, drag across its tiles in the picker, then click once.
   - **Pipes** (`pipes.png`): use the **pipe** brush (Terrains tab). Drag a line and it joins the pieces up as you go: straight lengths, elbows, T's and crossings under a bolted collar, and an end going into the wall behind a flange. Now and then an end comes out broken off instead. A single cell on its own is a valve stub. Any piece can also be picked by hand from the Tiles tab.
8. **Place things under Entities** by dragging scenes onto it from the FileSystem dock:
   - **Enemies:** the crawlers, one scene per colour: `scenes/enemies/crawler_sewer.tscn`, `crawler_sickly.tscn` and `crawler_pink.tscn` (the pink one heals you when killed). Then `thug.tscn`, which blocks and pauses on patrol (its block reduction, patrol and pause times are in the Inspector). In the Inspector, every enemy can set its health, damage, heal on kill and hit recoil, and a crawler can start on the ceiling.
   - **NPCs:** `scenes/npcs/npc.tscn`, with its origin at its feet on the floor. In the Inspector set:
     - `npc_id` (names what it remembers you heard, e.g. `guard`);
     - `name_key` (its name in `localization/en/dialog.po`, e.g. `NPC_GUARD`);
     - its sprite frames on its Sprite;
     - its **States**: what it says at each point in the game, latest first. Each state has the progress flags it requires or forbids (e.g. `warden_defeated`), a **first talk** heard once and a **repeat talk** after that. A talk is a list of lines, each a key in `dialog.po`, and a line can give an ability.

     In game, standing in its talk range (the box drawn in the editor) on the ground, attack talks to it instead of swinging.
   - **Bosses:** `scenes/bosses/warden.tscn` and `harrier.tscn`. Each needs an **Arena** node (`scripts/arena.gd`). Its origin is the arena's top-left corner, and `size_tiles` is its size. Point its `boss` at the boss node. The fight starts a few tiles past a gate, and the camera frames the arena.
   - **PlayerStart** (`scripts/player_start.gd`): where a fresh game starts, at the player's feet. Players coming through a door arrive at the door instead.
   - **RoomDoor** (`scripts/room_door.gd`): put it over the door tiles, with its origin at the doorway's top-left corner. Set its `height` in tiles, and choose `target_room` from the list. `arrive_at` names the door to arrive at in that room. Leave it empty to arrive at the door there that leads back.

   PlayerStart, RoomDoor and Arena show labels in the editor and are hidden in the game.
9. **Play it.** Press F6 to run just this scene. Without a PlayerStart, the player appears at a door. Run the tests too (see `tests/gameplay_test.gd`).

To add a new enemy, make a scene whose script extends `EnemyBase`. It shows up with the same Inspector settings, and can be placed in any room.

## Normal maps

The room's lights can shade a sheet using a normal map: a second image, the same size as the sheet, whose colours say which way each pixel faces. A light then brightens the pixels that face it and darkens those that face away, so a pipe looks round and a collar's edge catches a bulb beside it.

It's a special effect, for the few things whose shape it brings out. On the dark brick wall it was too faint to be worth it. Everything else is lit flat.

**The files.** A sheet with a normal map has it beside it, named `<sheet>_n.png`.
- Only `tiles/pipes.png` has one so far, `tiles/pipes_n.png`. `tools/make_pipe_tiles.gd` draws it from the pipe geometry, so rerunning that tool redraws it.
- Each pixel of `_n.png` describes the pixel at the same spot on the sheet, so keep the same size and layout. Where the sheet is transparent, the normal map doesn't matter; leave it flat.
- `<sheet>_canvas.tres` pairs a sheet with its normal map. Don't edit it.
- **To give another sheet one:**
  1. Add the sheet to `SHEETS` in `tools/make_normal_maps.gd` and run it. That makes a blank (flat) `_n.png` and the `_canvas.tres`, and never overwrites one that's already drawn.
  2. Rerun `tools/make_tilesets.gd` for a tile sheet. Anything else that draws the sheet needs pointing at the `_canvas.tres`.
  3. Draw the map.

**The colours.** Each channel is one direction, from 0 to 255, with 128 meaning "neither way":
- **Red:** facing left (0) or right (255).
- **Green:** facing down (0) or up (255). This is the "OpenGL" or "Y+" convention; if a tool asks, pick that one.
- **Blue:** how much the pixel faces you: 255 is flat on, lower is turned further away. Never below 128.

A useful palette, for surfaces turned about 45° (the usual edge bevel):

| Facing | Colour (R, G, B) |
|---|---|
| Flat, straight at you | 128, 128, 255 |
| Up | 128, 218, 218 |
| Down | 128, 38, 218 |
| Left | 38, 128, 218 |
| Right | 218, 128, 218 |
| Up-left | 64, 192, 218 |
| Up-right | 192, 192, 218 |
| Down-left | 64, 64, 218 |
| Down-right | 192, 64, 218 |

For a steeper slope, move further from 128 and lower the blue: straight up, edge-on, is 128, 255, 128. For a gentle one, stay closer to flat. The exact rule is `colour = (direction × 0.5 + 0.5) × 255` for a direction of length 1.

**Drawing them.**
1. Open the sheet and its `_n.png` together, as two layers in your editor, with the sheet on top at partial opacity so you can see what you're shading. Or draw on a copy of the sheet and fill each shape with palette colours.
2. Fill everything flat first. Then pick the shapes: for each, decide which way its surfaces face and paint those pixels with the matching colour.
   - **Bricks:** top row of each brick up, bottom row down, left and right columns left and right, the face flat. Mortar lines flat, or pushed slightly back.
   - **Pipes:** across a horizontal pipe, the top rows up, the middle flat, the bottom rows down. Up a vertical one, left to right. Collars and flanges are boxes with bevelled edges.
   - **Concrete blocks:** bevel the edges; chips and cracks face into the hole.
   - **Characters:** shade them like round shapes lit from all sides: a head, an arm and a torso are each a ball or a tube. Draw them facing the way the sheet faces. Godot should mirror the normals when a sprite turns around. If a turned character lights from the wrong side, that's a bug to report, not something to draw around.
3. Keep it to a few colours per shape, like the pixel art itself. Hard steps between directions look crisp; smooth gradients look soft and blurry at this scale.
4. Save as a plain PNG: no colour profile, no premultiplied alpha, no dithering, no resizing. Godot reimports it as soon as you save.

**Tools.**
- **Aseprite** (or the free LibreSprite): its colour wheel has a *Normal Map* mode that picks a direction by clicking where the surface points.
- **Laigter** (free) generates a normal map from a sprite's shading, as a starting point to clean up by hand.
- **PixelLab** has a normal-map generator too.

Generated maps guess from brightness, so a dark stain can look like a dent. Check and fix them.

**Seeing the result.** Run a room with F6: lights only exist in game, not in the editor.
- A shape that lights from the wrong side has a channel flipped. Green is the usual culprit when a map comes from a tool using the other convention: invert the green channel.
- Effects too subtle or too harsh: tune the lights in `scripts/room_art.gd` (`BULB_LIGHT_*` and `SIGN_LIGHT_*`). Height is how far out from the wall a light hangs. Lower makes the light rake across the surface and exaggerates the shading; higher flattens it.
- After a sheet's layout changes, its normal map has to change to match. The test suite checks that each one is still the sheet's size.

## Suggested order

1. **Tileset terrain block plus one platform.** Changes the whole look fastest, and it's a quick test of the pipeline.
2. **Player: idle, run, jump, fall.** You see these constantly.
3. **Player attacks and effects, then the crawler and the thug.**
4. **The two bosses, then pickups and HUD icons.**
