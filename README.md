# Hollowlike Prototype (Godot 4.3+)

Open this folder in Godot (Import -> project.godot) and press F5.

## Controls
| Action | Keys | Pad |
|---|---|---|
| Move | A/D or arrows | stick / d-pad |
| Jump (hold for height) | Space / Z | A |
| Attack | J / X (hold Up to aim up; Down in air = pogo) | X |
| Dash (after pickup) | K / C / Shift | RB / B |
| Restart | R | |
| Debug unlocks | F1 dash, F2 wall jump | |

## Layout
- `scripts/player.gd`          movement + combat, all tuning vars at the top
- `scripts/enemy_crawler.gd`   template enemy
- `scripts/level_data.gd`      ASCII test room: edit and re-run
- `scripts/main.gd`            builds the level, spawns entities, placeholder tile art
- `scripts/game_state.gd`      autoload: persistent abilities (survives death)
- `scripts/input_setup.gd`     autoload: registers input actions in code
- `scripts/hud.gd`             health boxes + ability list

## Test room flow (the metroidvania loop in miniature)
1. Climb the one-way platforms up-left to grab **Dash**.
2. The 8-tile spike pit can't be jumped without dash.
3. Beyond it, grab **Wall Jump**; the tall shaft needs it to reach the ledge with the enemy.
