# Garden Ecosystem Keeper

Build **Garden Ecosystem Keeper**, a compact **ecosystem gardening management
game** in Godot 4 at `/workspace/game/`. This is not a prototype. It is a
**complete, shippable micro-game** that could sit on an itch.io page or Steam
as a polished vertical slice.

## Core Vision

The player tends a small restoration garden where every tile is part of a living
web. Plants compete for moisture and light, pollinators follow bloom corridors,
pests exploit monoculture, and weather shifts the whole balance overnight. The
core tension is stewardship under scarcity: limited actions per turn, finite
water, unpredictable seasons, and biodiversity goals that punish brute-force
planting. A thriving garden is one the player composed, not one they clicked
into existence.

The tone is gentle but systemic — readable beds, seed packets, pollinator
trails, pest warnings, seasonal color shifts, and clear biodiversity meters.
The garden should feel alive and authored, not a raw grid of colored squares.

## What the Player Experiences

The player opens to a garden restoration scene and chooses a plot to tend. The
first planting is simple: a few seed types, moist soil, calm weather. Plants
grow visibly over turns, and the player learns the rhythm of water, wait,
harvest.

Soon the ecosystem asserts itself. A pollinator visits one flower bed but
ignores another. A pest cluster appears near a monoculture row. Companion
planting hints emerge — herbs near tomatoes deter aphids, wildflowers draw
bees toward fruit trees. The player starts composing beds rather than filling
them.

Weather and seasons raise the stakes. A dry spell forces triage: which beds
get the last water? An early frost threatens unprotected seedlings. A rainy
season floods low tiles but lets the pond habitat flourish. The player adapts
their plan each turn, balancing short-term survival against long-term
biodiversity targets.

Late game, the garden is a dense web of interactions. The player manages
pollinator corridors, pest barriers, moisture zones, and seasonal rotations.
When the restoration goal is met — a target biodiversity score, a bloom
festival, or a full habitat chain — the result screen reflects the garden's
health and composition. Failure shows what collapsed and why, inviting a
different strategy next time.

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
  demo_outputs/    ← your input traces (1–10 files)
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

Ship **1–10 input-trace files** under `/workspace/game/demo_outputs/`, one per
demo, each named `*.json`. The evaluator launches a fresh game per trace,
replays your trace as synthetic mouse and keyboard input at 1280×720, and
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
- `events` — time-ordered inputs. Coordinates are pixels in the 1280×720
  viewport. Supported types:
  - `mouse_click`: `{frame, type, button: "left"|"right", x, y}`
  - `mouse_down` / `mouse_up`: `{frame, type, button: "left"|"right", x, y}` —
    use these for drag interactions: emit `mouse_down` at the start point,
    one or more `mouse_move` events along the way, and `mouse_up` at the end.
    A `mouse_click` is a `mouse_down` + `mouse_up` at the same point in tight
    succession.
  - `mouse_move`: `{frame, type, x, y}`
  - `key_press` / `key_down` / `key_up`: `{frame, type, keycode}` — keycodes:
    `A`–`Z`, `0`–`9`, `ESCAPE`, `ENTER`, `SPACE`, `TAB`, `BACKSPACE`,
    `DELETE`, `SHIFT`, `CTRL`, `ALT`, `UP`, `DOWN`, `LEFT`, `RIGHT`.
  - `wait`: `{frame, type}` — anchor frame, no input.

Replay must be deterministic: same trace, fresh launch, same outcome every time.
