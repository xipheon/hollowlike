# Hollowlike Prototype (Godot 4.7+)

Open this folder in Godot (Import -> project.godot) and press F5.

## Controls
| Action | Keys | Pad |
|---|---|---|
| Move | A/D or arrows | stick / d-pad |
| Jump (hold for height) | Space / Z | A |
| Attack | J / X (hold Up to aim up, Down in the air to strike down; hits push you back, so striking down on a crawler bounces you up) | X |
| Sprint (uses stamina) | Shift | LT |
| Dash (after beating the boss; uses stamina; hold a direction to dash any of 8 ways) | K / C | RB / B |
| Pause | Esc / P | Start |
| Restart | R | |
| Debug (debug builds only) | F1 dash, F2 wall jump, F3 kill boss | |

## Layout
- `scripts/player.gd`          movement + combat, all tuning vars at the top
- `scripts/enemy_crawler.gd`   template enemy
- `scripts/level_data.gd`      the list of rooms (each a scene made in the editor)
- `scripts/room.gd`            runs a room: collisions from its tiles, doors, boss fights
- `scripts/game_state.gd`      autoload: persistent abilities (survives death)
- `scripts/input_setup.gd`     autoload: registers input actions in code
- `scripts/hud.gd`             health boxes + ability list

## Test room flow (the metroidvania loop in miniature)
1. Climb the one-way platforms up-left to grab **Dash**.
2. The 8-tile spike pit can't be jumped without dash.
3. Beyond it, grab **Wall Jump**; the tall shaft needs it to reach the ledge with the enemy.
