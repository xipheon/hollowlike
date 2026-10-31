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
- **Tiles.** A `TileSet` with a *Match Sides* terrain for solid ground, and a `TileMapLayer` that is still filled from the ASCII rows in `level_data.gd`. Rooms keep being edited as text. Collisions keep coming from code.

The layouts are fixed, so a sheet can be swapped or redrawn later without touching the game code. Only resizing a frame or adding a row needs a code change. To do that, edit `SHEETS` in `tools/make_art_templates.gd`, rerun it, and update your drawing to match.

## Suggested order

1. **Tileset terrain block plus one platform.** Changes the whole look fastest, and it's a quick test of the pipeline.
2. **Player: idle, run, jump, fall.** You see these constantly.
3. **Player attacks and effects, then the crawler and the knight.**
4. **The two bosses, then pickups and HUD icons.**
