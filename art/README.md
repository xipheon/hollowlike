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
- **Tiles.** `tiles/foreground_tileset.tres` and `tiles/background_tileset.tres`, built by `tools/make_tilesets.gd`, with *Match Sides* terrain brushes. Rooms are painted with them in the editor (see Making rooms below). Collisions come from code, from each tile's `kind`.

The layouts are fixed, so a sheet can be swapped or redrawn later without touching the game code. Only resizing a frame or adding a row needs a code change. To do that, edit `SHEETS` in `tools/make_art_templates.gd`, rerun it, and update your drawing to match.


## Making rooms

Rooms are scenes made in the Godot editor. Each tile you paint says what it is (its `kind` custom data: solid, platform, spikes, acid, door, gate), and the room builds its collisions and hazards from that when it loads.

1. **Start from the template.** Duplicate `scenes/rooms/room_template.tscn` (right-click it in the FileSystem dock, then *Duplicate*). Rename the root node, and set its `room` to the new room's id.
2. **Add it to the game.** Add the id and scene path to `ROOMS` in `scripts/level_data.gd`. Doors can then lead to it, and the level select lists it.
3. **Paint the Terrain layer** with `art/tiles/foreground_tileset.tres`. The room's top-left corner is cell (0, 0). Use the *Terrains* tab for brushes that pick the right edge tiles on their own: **concrete** for solid ground, **catwalk** for one-way platforms, **spikes**, and **sewer** for acid water. To place one exact tile, pick it from the *Tiles* tab instead. Door tiles go here too.
4. **Moving platforms (Tracks layer).** Select the Tracks layer and paint a track with the **track** brush. A track is a straight line, either side to side or up and down. Then select Terrain and paint catwalk over the track. When the room loads, each catwalk run that touches a track becomes a moving platform, as wide as the run.
   - **Side to side:** the whole deck stays between the track's end stops.
   - **Up and down:** paint the catwalk across the rail. The deck stays centred on the rail.

   Platforms go back and forth and pause at each end. To give one its own `speed` or `end_pause`, place `scenes/props/moving_platform.tscn` under Entities instead of painting it. Put its origin, the middle of the deck's top edge, on the track. Older rooms get a Tracks layer the first time you open them. Save the scene to keep it.
5. **Paint the Gates layer** where a boss arena's gates go, with the shut gate tiles. They show raised until a fight starts, then drop shut.
6. **Paint the wall (Background layer).** The game shows exactly what you paint here. Any cell left empty is open, and the skyline shows through it.
   - Press **Decorate wall** in the root's Inspector to fill every empty cell with brick, windows, lights, posters and graffiti. Cells you've already painted are kept. Then edit the result by hand.
   - Or paint the wall yourself. Use the **wall** brush (Terrains tab) for brick: it gives a crumbled edge wherever brick meets an empty cell.
   - Props come from the **Tiles** tab. Each one is a whole tile with its own brick behind it, so it takes the place of a brick cell. For a prop more than one tile big (graffiti, windows), drag across all of its tiles in the picker, then click once in the room.
   - Window glass is see-through. In the editor the skyline is repeated down the whole room so every window shows the city. In game the skyline stays at screen height.

   Save the scene to keep the wall.
7. **Place things under Entities** by dragging scenes onto it from the FileSystem dock:
   - **Enemies:** `scenes/enemies/crawler.tscn` and `knight.tscn`. Set each one in the Inspector: health, damage and heal on kill for any enemy, and palette and on-ceiling for a crawler.
   - **Bosses:** `scenes/bosses/warden.tscn` and `harrier.tscn`. Each needs an **Arena** node (`scripts/arena.gd`). Its origin is the arena's top-left corner, and `size_tiles` is its size. Point its `boss` at the boss node. The fight starts a few tiles past a gate, and the camera frames the arena.
   - **PlayerStart** (`scripts/player_start.gd`): where a fresh game starts, at the player's feet. Players coming through a door arrive at the door instead.
   - **RoomDoor** (`scripts/room_door.gd`): put it over the door tiles, with its origin at the doorway's top-left corner. Set its `height` in tiles, and choose `target_room` from the list. `arrive_at` names the door to arrive at in that room. Leave it empty to arrive at the door there that leads back.

   PlayerStart, RoomDoor and Arena show labels in the editor and are hidden in the game.
8. **Play it.** Press F6 to run just this scene. Without a PlayerStart, the player appears at a door. Run the tests too (see `tests/gameplay_test.gd`).

To add a new enemy, make a scene whose script extends `EnemyBase`. It shows up with the same Inspector settings, and can be placed in any room.

## Suggested order

1. **Tileset terrain block plus one platform.** Changes the whole look fastest, and it's a quick test of the pipeline.
2. **Player: idle, run, jump, fall.** You see these constantly.
3. **Player attacks and effects, then the crawler and the knight.**
4. **The two bosses, then pickups and HUD icons.**
