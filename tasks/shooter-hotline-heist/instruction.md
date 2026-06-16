# Hotline Heist

Build **Hotline Heist**, a top-down fast-action shooter in Godot 4 at `/workspace/game/`.
This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

The fantasy is bursting through doors into rooms full of armed guards, clearing
entire floors in seconds with precise aim and brutal efficiency. The interesting
tension is fragility: both the player and enemies die in one hit, making every
room entry a lethal puzzle where hesitation means death. Combo scoring rewards
speed — chaining kills without pause multiplies the score, encouraging reckless
aggression balanced against the instant-death stakes. Weapon variety scattered
across floors forces improvisation: a shotgun clears a cluster but alerts the
next room, while a silenced pistol preserves surprise but demands accuracy.

## What the Player Experiences

The player sees a stylized title screen, selects a floor from the campaign list,
and spawns outside the building's entrance. The camera shows the full floor plan
from above — rooms, corridors, doors, and enemy patrol routes are partially
visible. The player moves with WASD, aims with the mouse, and clicks to attack.
Doors can be kicked open to stun enemies behind them.

Each floor is a self-contained puzzle of 4-8 rooms connected by doors and
hallways. Guards patrol set routes; some stand still, others pace. Weapons litter
the ground — bats, pistols, shotguns, SMGs, thrown knives — each with limited
ammo or single-use. Clearing all enemies on a floor triggers a score screen
showing time, combo chain, and weapon variety bonus. Dying restarts the floor
instantly. The campaign offers 8+ floors with escalating guard density, new enemy
types (armored, dogs, gunners), and tighter layouts.

## Assets

2D assets are mounted read-only at:

- `/workspace/assets/library/` — Kenney CC0 packs (sprites, tiles, UI, fonts).
- `/workspace/assets/library-oga/` — OpenGameArt entries; respect each
  subdir's `LICENSE.txt`.

Browse the library and choose packs.
Copy what you need into your project's `assets/` folder.

## Project layout

```
/workspace/game/
  project.godot
  Main.tscn
  demo_outputs/    <- your input traces (1-10 files)
  scripts/  scenes/  assets/
```

The build must launch cleanly with:

```
godot --headless --path /workspace/game --quit-after 5
```

A reference for Godot CLI flags is at `/workspace/tools/godot_command_line.md`.
**Engine flags like `--headless` and `--quit-after N` must come BEFORE `--`** —
anything after `--` is forwarded to the project as user args and silently
ignored by the engine. Correct shape:
`godot --headless --quit-after 5 --path . -- --scenario near_victory`.

A screenshot helper is available at `/workspace/tools/screenshot.sh`. Use it to actually see what your UI / battlefield /
result screens look like.

```
/workspace/tools/screenshot.sh --path /workspace/game \
      -- --out /workspace/frame.png --frames 60
```

To screenshot a specific scenario, append `--scenario <id>` after `--`. The
helper consumes only `--out` / `--frames` / `--scene`; remaining args stay in
`OS.get_cmdline_user_args()` for your game code to read. Example:

```
/workspace/tools/screenshot.sh --path /workspace/game \
      -- --out /workspace/battle_debug.png --frames 120 --scenario battle
```

## Demos

Ship **1-10 input-trace files** under `/workspace/game/demo_outputs/`, one per
demo, each named `*.json`. The evaluator launches a fresh game per trace,
replays your trace as synthetic mouse and keyboard input at 1280x720, and
records the screen. Only the first 10 traces by filename are evaluated;
recordings longer than 20 s are sampled from a random 20 s window.

### Scenarios

Normal play should start from the title screen and demonstrate the task's
core gameplay loop.
Demo playback must be deterministic. For demos that need a specific state
(a specific level, combat state, upgrade screen, result state, or late-game
setup), define named scenarios your game loads when launched with:

```
godot --path /workspace/game -- --scenario <id>
```

When `--scenario <id>` is present the game must skip menus, set up the named
state deterministically (seed any RNG), and begin accepting input immediately.

### Trace file format

```json
{
  "scenario": "title_flow",
  "duration_frames": 360,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 300, "y": 360},
    {"frame": 90,  "type": "key_press",   "keycode": "1"},
    {"frame": 180, "type": "key_press",   "keycode": "SPACE"},
    {"frame": 300, "type": "wait"}
  ]
}
```

- `scenario` — optional; omit for a normal game launch from the title screen.
- `duration_frames` — total frames to record at 30 fps; cap at **600 (20 s)**.
- `events` — time-ordered inputs. Coordinates are pixels in the 1280x720
  viewport. Supported types:
  - `mouse_click`: `{frame, type, button: "left"|"right", x, y}`
  - `mouse_down` / `mouse_up`: `{frame, type, button: "left"|"right", x, y}` —
    use these for drag interactions: emit `mouse_down` at the start point,
    one or more `mouse_move` events along the way, and `mouse_up` at the end.
    A `mouse_click` is a `mouse_down` + `mouse_up` at the same point in tight
    succession.
  - `mouse_move`: `{frame, type, x, y}`
  - `key_press` / `key_down` / `key_up`: `{frame, type, keycode}` — keycodes:
    `A`-`Z`, `0`-`9`, `ESCAPE`, `ENTER`, `SPACE`, `TAB`, `BACKSPACE`,
    `DELETE`, `SHIFT`, `CTRL`, `ALT`, `UP`, `DOWN`, `LEFT`, `RIGHT`.
  - `wait`: `{frame, type}` — anchor frame, no input.

Replay must be deterministic: same trace, fresh launch, same outcome every time.
