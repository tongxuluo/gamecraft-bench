# Lemming Factory

Build **Lemming Factory**, a 2D creature-guiding puzzle game in Godot 4 at
`/workspace/game/`. The player assigns jobs to a stream of marching factory
workers — diggers, builders, blockers, climbers — to guide them safely from
an entrance hatch to an exit door, saving a required quota each level.

This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

The game is a real-time puzzle about indirect control. Creatures march
autonomously in a straight line, turning at walls, falling off ledges, and
walking into hazards unless the player intervenes. The player cannot move
creatures directly but can click on individual workers to assign them a job
from a limited toolbar. Each job transforms the creature's behavior: diggers
carve downward through terrain, builders construct diagonal staircases, blockers
become impassable walls that redirect traffic, and climbers scale vertical
surfaces. The tension comes from limited job supplies, time pressure as
creatures march toward danger, and the spatial reasoning needed to route a
crowd through complex terrain. The best version feels like conducting an
orchestra of tiny workers where every assignment ripples through the crowd's
path.

## What the Player Experiences

A title screen sets the factory tone with marching creature silhouettes and a
clear way to begin. The player enters a level where terrain, hazards (pits,
saws, lava), an entrance hatch, and an exit door are visible. A toolbar shows
available jobs with remaining counts. The hatch opens and creatures begin
marching out at a steady rate.

Early levels teach one job at a time: assign a digger to carve through a floor,
or a builder to bridge a gap. Soon levels require combining jobs — a blocker
redirects traffic while a digger opens an alternate path. Mid-game introduces
climbers for vertical navigation, floaters for safe falls, and bombers for
emergency terrain removal. Each level specifies a save quota; losing too many
creatures to hazards means failure.

The player can adjust release rate and pause to plan. When enough creatures
reach the exit, a results screen shows the save percentage and offers the next
challenge. The campaign has levels grouped into difficulty tiers, each
introducing new terrain types and job combinations.

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
