# Racing Drift Circuit

Build a Racing Drift Circuit in Godot 4 at `/workspace/game/`.
This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

A precision time-trial racing game where mastering the drift is everything. The
player pilots a car through tight circuits, initiating controlled drifts around
corners to maintain speed. Each track is a puzzle of racing lines — brake too
early and you lose seconds; drift too wide and you clip the barrier. Ghost
replays of your best run haunt every attempt, pushing you to shave milliseconds.
A medal system (Gold/Silver/Bronze) across 10+ tracks provides clear progression
goals, and the satisfaction of a perfect drift chain through a complex chicane
is the core reward.

## What the Player Experiences

1. **Title Screen** — A dynamic menu with the game name in speed-styled italic
   font, a blurred track in the background with a ghost car drifting past, and
   buttons for Campaign and Time Trial. No plain Godot grey.
2. **Track Select** — A grid of 10+ tracks with preview thumbnails, medal
   status (empty/bronze/silver/gold), and best time displayed. Tracks unlock
   sequentially by earning at least bronze on the previous track.
3. **Driving Feel** — Top-down or angled-top view. The car accelerates smoothly,
   brakes with visible deceleration, and steers with momentum. Holding a drift
   key while turning initiates a drift: the car slides sideways with tyre smoke
   particles trailing behind.
4. **Drift Boost** — Maintaining a drift builds a boost meter. Releasing the
   drift at the right moment grants a speed burst with a visible flame/trail
   effect. Longer drifts yield bigger boosts but risk hitting walls.
5. **Ghost Replay** — A translucent ghost of the player's best lap drives
   alongside them in real time. The ghost is clearly distinguishable (different
   colour, slight transparency) and shows exactly where time is being gained
   or lost.
6. **Medal System** — Each track has Gold/Silver/Bronze time thresholds shown
   before the race. Finishing awards the appropriate medal with a podium
   animation. Medals are tracked on the track select screen.
7. **Track Variety** — Tracks range from simple ovals to complex circuits with
   hairpins, chicanes, elevation changes (visual only), and varying widths.
   Each track has a distinct visual theme (city, desert, forest, night).

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
