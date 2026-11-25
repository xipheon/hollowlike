# Review notes: commit 5387bd6 (the world, Reach, title backdrop, welcome card)

**Verdict.** The world is laid out the way the commit says it is, and the gates that matter hold in play: you can't reach the Sin Hawk without the dash, and you can't reach the Vault without the wall jump. But `Reach` is not sound, so "out of reach is certain" is false. It doesn't model an upward dash started on the ground, and that dash keeps the air dash. A ground up-dash followed by an air up-dash lifts you 325.6 px. Reach's `dash_rise()` says 295.8. I played this in the real Span with only the dash: it reaches the alcove's Heart Container, which is meant to need the wall jump. The world test passes anyway, because it trusts Reach. The other gaps in Reach are small (under a tile) or are things it already says it ignores, and none of them opens a bypass in the current rooms. I found no soft-locks. The world segment passes (0 failed, 13 s, 11.6 s of that in `_test_world_order_by_reach`).

## Confirmed

### 1. Reach misses the ground up-dash, and the Span alcove falls to the dash alone
- **What:** `Player._start_dash` (scripts/player.gd:499) only spends the air dash when `not on_floor`. A dash straight up (or up-diagonal) started on the ground leaves `_air_dash_available` true. Once the cooldown is over (`dash_duration + dash_cooldown`, 0.47 s from the start), you can air-dash again. Reach models a ground dash only sideways, off a ledge (scripts/reach.gd:234-240, a `FALL` launch). Its best vertical move is a jump plus one air dash (reach.gd:80, `dash_rise()` = 295.8 px).
- **Numbers (played, headless, real Player in scenes/world/span.tscn):**
  - Jump, then an up-dash at the apex: feet rise 287.9 px.
  - Ground up-dash, then an air up-dash as soon as the cooldown ends: feet rise **325.6 px**.
  - Reach's `dash_rise()`: 295.8 px. So Reach is about 30 px short of what the player can really do.
- **Scenario:** Have only the dash. Stand on the Span's catwalk at col 45, row 15 (feet y 512). Hold up, dash, dash again after the cooldown, then hold right near the top. Your feet reach y 186.4. The alcove floor is at y 192 (row 6), so you are 5.6 px above it, and you land in the alcove at (47, 6) with the Heart Container. `Reach.cells_from(Vector2i(45, 15), ["dash"])` returns no alcove cells. `_test_world_order_by_reach` (tests/gameplay_test.gd, the "but not the Span's alcove or the Vault" check) passes, but what it asserts is false in play.
- **Also affected:** the Entrance wall to the Vault needs 352 px. The real best is 325.6, so it still holds, but the margin is 26 px, not the ~56 px Reach implies. The played check `_climb_wall(..., dash_up=true)` only tries a jump followed by a dash, so it never tests the stronger move.
- **Fix:**
  - In `Reach._fly`, when `launch == JUMP and _dash`, also dash from the ground: up, both up-diagonals, and the sideways steps already there. Launch `DASH_END` with `dashed = false`, for example a `_dash_from` variant that takes `dashed`.
  - Add a played check for ground up-dash plus air up-dash next to the jump-height one in `_test_reach_matches_play`.
  - For the room: move the alcove one row higher in the `span` plan (alcove floor at row 5), so the dash-only best (feet at y 186.4) falls short of the new floor at y 160. Or lower the catwalk at (43, 16). Then rebuild `span`.

## Plausible (reasoned from the code and arithmetic, not played)

### 2. Dashing off a ledge and then jumping in coyote time goes further than Reach allows
- **What:** coyote time keeps running during a dash. A ground dash that leaves the ledge in its last ~0.1 s still allows a full jump (113 px) on the first frame after the dash, and the air dash is unspent. The dash carries you about 55 px past where a run would (4 frames at 13.7 px instead of 5.3 px). You leave the ground at about 79 px past the edge, at ledge height, with no fall yet.
- **Where Reach falls short:** a `JUMP` launch counts coyote as `run_speed * coyote_time` = 32 px (reach.gd:212). The ground-dash `FALL` launch has no jump (reach.gd:240, rise 4 px). By my estimate, the real horizontal position at a given height runs about 15-25 px past Reach's limit. That is sometimes one more column, both before and after the follow-up air dash.
- **Scenario:** no current gate depends on it. The gaps it could matter at (hub, tunnels ledge) are crossed with the dash anyway, and the vertical gates are far from any ledge. It would bite a future gap that sits within a tile of the limit.
- **Fix:** add `(dash_speed - run_speed) * coyote_time` to the `JUMP` spans when `_dash` is set. Or, from a ground-dash `FALL` cell no further than `dash_speed * coyote_time` past the edge, also queue a `JUMP` launch with the air dash unspent.

### 3. Heights can come out up to about 0.6 px short
- **What:** this has two parts.
  - `_rise_at` (reach.gd:87) gives 113.12 px for the jump, but stepping the frames gives 113.17. The discrete maximum can exceed the formula by up to g/(8·tps²), which is 0.07 px here.
  - `_launch` prunes a launch when an earlier one was up to 0.5 px lower (`b[0] <= y + 0.5`, reach.gd:196). The same applies in `_dash_from` (reach.gd:280).
- **Impact:** small, but it contradicts "heights exact to the pixel" and could flip a layout that sits within a pixel of the limit.
- **Fix:** add `_g / (8.0 * tps * tps)` to `_rise_at`. Prune only when the earlier launch is as high or higher (`b[0] <= y`), or add 0.5 px back to the rises.

### 4. Moves Reach ignores, and why they don't break these rooms
- **Pogo (`_recoil`):** hitting something from above sends you up at `hit_recoil` and gives back the air dash.
  - Lift per bounce: 300 px/s for crawlers, bosses and the default, about 26 px; 180 px/s for the thug, about 10 px.
  - Crawlers don't climb walls (scripts/enemy_crawler.gd: they turn at walls and ledges), and every crawler and thug in the world stands on a floor. Without the dash, a bounce never beats a plain jump: your feet bounce at roughly the enemy's height plus the swing's reach plus 26 px, well under 113 px.
  - With the dash, each bounce is worth about +26 px plus a fresh dash (about 174 px). No enemy sits near the shaft, the hub gap or the Vault wall.
  - Spikes can't be bounced on: `_on_attack_area_entered` only recoils off the "breakable" group.
  - Ceiling crawlers can only be hit from below, which pushes you down.
- **Knockback** (`knockback` = (500, -300)): about 26 px of lift, plus about 84 px sideways during the 0.22 s stun. The hub has no enemies, so nothing helps you over its gap. In the Tunnels, the thug and the pink crawler stand on the floor, far below ledges C and D.
- **I-frames over spikes:** spikes are an Area2D only (room.gd `_add_spikes`), so you stand inside the spike cell. After an enemy hit you get 0.5 s of invulnerability, 0.22 s of it stunned. In that window you can stand on spikes and jump off them, which Reach never allows (spikes neither hold you nor let you through). This only matters in the Span's pits, which you can only reach with the dash. Acid kills through invulnerability.
- **Moving platforms:** there are none in scenes/world, so nothing to model.
- **Fix:** none is needed now. Do add a line to Reach's header saying that enemies and spike i-frames make "out of reach" conditional on there being no enemy near the gate.

### 5. The backdrop only stops the Room itself
- **What:** `Room._show_as_backdrop` (room.gd) turns off the Room's own physics and unhandled input. Enemies, NPCs and bosses under Entities still run their own `_physics_process`, with no player in the tree. The Entrance has none, so nothing goes wrong today. Change `LevelData.FIRST_ROOM` to a room with enemies and the title screen would run crawlers, along with any sounds, errors or null-player paths they have.
- **Fix:** when `backdrop` is set, set `entities().process_mode = PROCESS_MODE_DISABLED` (the camera sway tween is on the room, so it keeps running), or free the enemies.

### 6. A placed item's picked flag follows its node name
- **What:** room.gd:337 sets `picked_<room>_<node name>`.
  - Renaming the node in the editor makes an item you already picked up come back in existing saves.
  - `entities_of` searches recursively, so two pickups with the same name under different parents share a flag: picking up one removes the other.
- **Fix:** add an exported `pickup_id` (defaulting to the node name), or use the path relative to Entities. Warn about duplicates when the room loads.

### 7. The welcome card's controls line hard-codes the keys
- **What:** `UI_INTRO_CONTROLS` names A/D, Space, J and Esc. If bindings ever become remappable, it will be wrong. It also leaves out the dash.
- **Status:** it is a translation key, so the project's string rule is met. This is minor.

## Project rules
- **Tests hard-code layout numbers instead of reading them:**
  - `far - edge >= 9`, `edge - 6` and `ledge_row + 4` in `_test_hub_gap_needs_dash`.
  - `floor_row - top_row >= 10` in `_test_entrance_wall_needs_wall_jump`.
  - `ids.size() >= 7` in `_test_world_rooms_join_up`.
  - `all.items.size() >= 4` in `_test_world_order_by_reach`.
  - `from + Vector2i(6, 0)` and the 4.0 px tolerance in `_test_reach_matches_play`.
  - The literal `"picked_tunnels_HeartContainer"` in `_test_placed_item_pickup`, which could be built from `room.room` and `heart.name`.

  The gap and wall sizes could come from `tools/build_world.gd`'s ROOMS, or from Reach (for example, "the gap is wider than a jump covers per Reach").
- **Strings:** every new player-visible string I found is a key in localization/en/ui.po (UI_INTRO_*, UI_MENU_*).
- **Comments:** they match the house style. One is now wrong: reach.gd:9-16 says heights are exact and that "out of reach" is certain. Correct it along with finding 1.

## Checked and fine
- **Jump height:** Reach's 113.1 px matches play (113.17 px). Jump buffering adds no height. Variable jump height only shortens jumps.
- **Dash:** Reach's length of 153.1 px is more than the real 150.3 px (11 frames). The exit at `run_speed` gives 24 px of lift in play, and Reach allows 29.6. There is one air dash per landing, and wall sliding doesn't refresh it, which matches Reach. Down-dashes are covered by Reach's sideways dash followed by a fall.
- **Wall jump:** Reach allows 5 per landing (100/20) and ignores the stamina the dash spends, which is generous. It ignores the 0.15 s lock and steers at full run speed, also generous. A wall at head height is covered, because Reach lets your feet into that cell even where the body wouldn't fit.
- **Falls:** the ±1 column per row below the launch row is enough, because real fall speed by then keeps you under 32 px sideways per row.
- **One-way drop-through:** it only goes down, which Reach's falls cover.
- **Hub gap:** 10 tiles. The best jump with no abilities is about 230 px, against the 298 px needed. There are no enemies in the hub.
- **Tunnels:** ledge D needs the dash. The acid (3 tiles) and spikes (4 tiles) can be jumped. Dropping through the catwalk over the acid kills you; that is a hazard, not a soft-lock.
- **Entrance and Vault:** you can't reach the Vault without the wall jump, with or without the dash: 352 px are needed and the real best is 325.6 px. The step and the catwalk are 20+ tiles from the wall.
- **Span's second pit:** the catwalk at (53, 22) sits level with the floor, so the pit is two 4-tile jumps. That's harmless, because the Span is only reachable with the dash.
- **Soft-locks:** none found. Every ledge and pit drops back to the floor, spike pits put you back on safe ground, and each arena's gate reopens after the fight.
- **Arenas:** both match the conventions in boss_room.tscn and aerie_room.tscn: 28×11 and 28×13, the gate one column left of the Arena, and the fight starting `ARENA_TRIGGER_INSET` (3) tiles in. The Warden's arena is at (9, 4) and the Hawk's at (5, 3), and the scenes match their plans.
- **Welcome card:**
  - It is `PROCESS_MODE_ALWAYS` and pauses the game.
  - The pause menu won't open while the game is paused (pause_menu.gd:72), so it can't unpause behind the card.
  - The card waits two physics frames before unpausing, so the press that closes it doesn't also swing.
  - It shows once, and a new game wipes its flag.
- **Main menu:** the UI layer (20) sits over the room's grade. The backdrop's unhandled input is off, so the restart key and debug keys don't fire on the title screen.
- **ItemPickup:** the `@tool` changes are guarded by `Engine.is_editor_hint()`. The placed-pickup flags can't collide with boss-drop flags (`picked_<room>_<index>`) unless a node is named with a bare number.
- **Test cleanup:** the world tests free the rooms and the Player they load (`_close_world`, `_test_world_rooms_join_up`), and the world segment reports no leaks.

## Review: commit 3e9dabb (saving)

**Status:** all twelve findings were fixed in the commit after 3e9dabb. Notes on choices made:
- Resting with nothing new since the newest save doesn't write a new autosave. Play time alone doesn't count as new.
- Dying after coming back into your bench room by a door gets you up at the bench (Respawn sets `GameState.respawning`), as the docs say.
- Starting a used campaign over still deletes its saves at once. The confirm text now says so.
- The skin is kept in `settings.cfg` with the language, not in saves.

Read-only review. The `saving` test segment passes (0 failed checks). "Confirmed" means I checked it in the code. None of these were run as a repro.

### Findings (most severe first)

1. **A save header without `saved_at` breaks the title screen.** Confirmed.
   - Where: `scripts/save_system.gd:128,209,217,228,269` read `header.saved_at` directly. `_parse` (:184) only checks that `header` and `state` are Dictionaries.
   - Scenario: a hand-edited save, or another JSON file in `campaign_<n>/`, has no `saved_at`. `MainMenu._ready` calls `latest_overall()`, which hits "Invalid access to key 'saved_at'". The title errors before Continue/Load are set up. `next_auto_slot` fails the same way at the next bench.
   - Fix: use `float(header.get("saved_at", 0.0))` everywhere, or have `_parse` reject headers whose `saved_at` isn't a number.

2. **`from_dict` crashes on wrong-typed fields and leaves the game half loaded.** Confirmed.
   - Where: `scripts/game_state.gd:271-295`.
   - Scenario: a save with `"flags": []`, `"abilities": null`, `"items": {"x": 1}`, an item entry `[]` or `["x"]`, `"bosses_defeated": {"boss": 5}` or `"rest_bench": 3`. Each typed assignment (`var saved_flags: Dictionary = ...`, `for entry: Array in ...`, `rest_bench = ...`) or index (`entry[1]`, `defeated[room][0]`) is a runtime error. Fields reset before the bad one are wiped, the rest keep the previous game's values, and `load_game` still goes on to the fade.
   - Fix: read each field with a type check (`var v = d.get(k); if v is Dictionary: ...`) and check each entry's size and type. Better: build the new state in locals, assign only when all of it is valid, and have `load_game` refuse with a note otherwise.

3. **`load_game` and `start_new_game` change GameState before the fade guard.** Confirmed.
   - Where: `game_state.gd:233-238` and `:304-313`. They call `from_dict` / `delete_campaign` / `start_at_room` before `_fade_to_scene`, whose `_transitioning` check (:354) just returns. The menu buttons stay live during the 0.25 s fade.
   - Scenario: on Load, press a campaign 1 save, then within the fade press a campaign 2 save. Campaign 1's rest room loads holding campaign 2's progress, with `campaign = 2`. The bench check fails, so you start at PlayerStart, and the next rest saves that mix into campaign 2. New Game pressed during a fade deletes that campaign's saves and wipes the state, while the other scene still loads.
   - Fix: `if _transitioning: return false` at the top of `load_game`, `start_new_game` and `start_at_room`. Also set the menu's `process_mode` or `mouse_filter` to stop input once a choice is made.

4. **Continue does nothing, with no message, when its save can't be loaded.** Confirmed.
   - Where: `main_menu.gd:43`, `game_state.gd:306,316-318`.
   - Scenario: a room is renamed or removed from `LevelData.ROOMS`, and the newest save rested there. Continue stays visible and focused, but every press is a no-op. It never tries an older save. On Load the same save says `UI_SAVE_UNREADABLE`, because `read()` cleared `notes`, which is misleading.
   - Fix: when `rest_room` is unknown, add a note such as `UI_SAVE_NOTE_ROOM_GONE`, or fall back to `LevelData.FIRST_ROOM`'s PlayerStart. Have Continue show `load_problem()` and/or try the next newest save.

5. **The Load list can run off the 540 px viewport.** Plausible.
   - Where: `scenes/main_menu.tscn`. `Saves` is a plain VBoxContainer in a CenterContainer.
   - Scenario: 3 campaigns x 3 autosaves gives 9 buttons x 44 px. With the title, problem label, Back and the separations, that is about 540 px. It reaches 18 buttons once manual slots exist. Centering clips the title and Back off the screen.
   - Fix: put `Saves` in a ScrollContainer with `follow_focus = true`.

6. **Mashing attack at a bench overwrites every autosave.** Confirmed.
   - Where: `bench.gd:48-58`, `game_state.gd:245-251`.
   - Scenario: each rest writes the next autosave slot (`next_auto_slot`). Three taps by a bench fill `auto_1..3` with the same state, so the rotating history (the reason there are 3) is gone.
   - Fix: when the last autosave is from the same bench with an unchanged `to_dict()`, overwrite that slot (or skip the write).

7. **Dying in your bench room after leaving and coming back puts you at the door, not the bench.** Confirmed.
   - Where: `room.gd:525`. The bench only counts when `arrived_from == ""`. `rest_at` clears it, but coming back through a door sets it again, and `reload_current_scene` keeps it.
   - Scenario: rest in the hub, go to the tunnels, come back, die. You respawn at the tunnels door. The docs (`bench.gd:6`, `game_state.gd:59-60`) say you get up at the bench.
   - `_test_dying_gets_you_up_at_the_bench` sets `arrived_from` before resting, so it never covers this case, despite its "even having come in by a door".
   - Fix: decide which behaviour is wanted. Either have a death respawn prefer the bench (for example a GameState `respawning` flag set by DeathMenu), or reword the docs and the test.

8. **Debug saves are documented but never listed.** Confirmed.
   - Where: `save_system.gd:19-22` says they are "listed at the bottom of each campaign's saves on Load". `debug_saves()` is never called; `main_menu.show_load` uses `saves(n)` only.
   - Fix: append `SaveSystem.debug_saves()` in `show_load` (debug builds), or remove the doc.

9. **The player skin is lost every launch.** Confirmed. This was already so before this commit.
   - Where: `player_skin` (`game_state.gd:52-53`) is in neither the save nor `settings.cfg`. The `to_dict` doc ("everything but the language and skin") suggests both are kept elsewhere; only the language is.
   - Fix: store it in `settings.cfg` next to the language.

10. **Starting over deletes the old campaign before there's anything new.** Confirmed. This may be by design.
    - Where: `game_state.gd:235-236`.
    - Scenario: confirm New Game on a used campaign, then quit before the first bench. The old campaign is gone and nothing replaces it.
    - Fix: say so in `UI_CAMPAIGN_CONFIRM`, or delete at the first rest.

11. **A short write isn't detected.** Plausible, low.
    - Where: `save_system.gd:112-117`. `store_string` isn't followed by `file.get_error()`.
    - Scenario: the disk is full and the truncated `.tmp` still replaces the save. `.bak` covers one such write.
    - Fix: if `file.get_error() != OK`, close, remove the `.tmp` and return false.

12. **The tests leave state behind and hard-code values.** Confirmed, low.
    - `_test_continue_gets_you_up_at_the_bench` leaves `GameState.campaign == 2` and its progress. `_test_new_game_asks_before_starting_over` and `_test_main_menu_starts_game` leave `campaign == 1`. Only `_spawn` resets these, so any later test that builds a Room another way counts `play_time` and saves at benches (into `test_saves`).
    - `_clear_saves` leaves the `user://test_saves/` folder, and `SaveSystem.debug_root` isn't redirected.
    - Hard-coded: `"Bench"` / `"hub"` / `"span"`, `first.size() == 2` and `save_buttons.size() == 2` (these could be read from the rests made), and the 1.0/2.0 px tolerances.
    - Fix: reset campaign, rest and play time in `_despawn`.

### Checked and fine
- Progress that persists between rooms is kept by the save, because it is all flags: `talked_*` / heard, `picked_<room>_<id>` (placed items and boss drops), `got_<id>`, `intro_seen`, defeat flags. `bosses_defeated` is saved as `[x, y]`. Items keep the order you got them.
- `from_dict` replaces abilities, flags, items, `_item_defs`, bosses and rest data, and `load_game` resets `carried_health` and `campaign`, so no state leaks from the previous game. No signals fire, and abilities from items come back with the saved abilities. `arrived_from` is cleared by the fade. A stale `arrive_at` is harmless.
- JSON numbers are coerced (`int(entry[1])`, `bool()`, `float(play_time)`, `int(version)`). Versions that are older, newer or missing are refused with a note.
- Writes go through `.tmp` and keep a `.bak`; a broken main file reads from its `.bak`, with a note.
- `play_time` stops while the tree is paused: the pause menu, boss intro, welcome card, dialogue and death menu all pause it. The title backdrop isn't `current_scene`, and the Test Rooms reset `campaign` to 0.
- New Game deletes only the campaign its button was bound to, after a second press.
- The bench in group `"npc"` is only iterated by `Player._talk_to_nearby`, which uses `can_talk_to` / `talk` (Bench has both). In the Junction the guard and the bench are far apart.
- Dying before resting, or in another room, behaves as before.
- Every new UI key is in `ui.po`. Text built in code uses `tr` / `_t` and has auto-translate off. `ui_cancel` covers all three boxes, and focus goes back to the button that opened each box.
