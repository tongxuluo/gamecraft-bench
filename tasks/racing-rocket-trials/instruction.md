# Racing Rocket Trials

Build a Racing Rocket Trials in Godot 4 at `/workspace/game/`.
This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

A physics-based motorcycle obstacle course where precision throttle control and
body lean are everything. The rider navigates increasingly absurd ramps, loops,
seesaws, and explosive barrels across 20+ hand-crafted levels. Crashing is
spectacular — the rider ragdolls on impact, tumbling across the course in a
darkly comic display. The challenge is surgical: feathering the throttle to
climb a near-vertical wall, leaning back to clear a gap, or threading between
swinging hazards. Checkpoints are generous but the clock is merciless — medals
reward speed and flawless runs.

## What the Player Experiences

1. **Title Screen** — A grungy industrial backdrop with the game name in
   stencil-style bold font, a motorcycle silhouette mid-wheelie, and
   Play/Level Select buttons. No plain Godot grey.
2. **Level Select** — A grid of 20+ levels organized into 4 difficulty tiers
   (Easy/Medium/Hard/Extreme). Each shows medal status, best time, and a small
   preview. Levels unlock sequentially within each tier.
3. **Motorcycle Physics** — The bike has realistic 2D physics: two wheels with
   suspension, a rider body that leans. Throttle (right key) accelerates the
   rear wheel; brake (left key) slows it. Up/down keys lean the rider
   forward/backward, shifting the centre of gravity.
4. **Obstacle Variety** — Levels feature ramps, loops, seesaws, swinging
   pendulums, explosive barrels, crumbling platforms, moving platforms, and
   steep inclines. Each obstacle type has distinct visual design and physics
   interaction.
5. **Ragdoll Crash** — When the rider's body hits an obstacle or the ground at
   a bad angle, they ragdoll off the bike. The crash plays out with physics-
   driven limb movement. A "Fault" counter increments and the player respawns
   at the last checkpoint.
6. **Checkpoints** — Flags or markers placed throughout each level. Reaching
   one saves progress. The timer continues running. Fewer faults and faster
   times earn better medals.
7. **Medal and Star System** — Each level awards Gold/Silver/Bronze based on
   completion time. A "Flawless" star is awarded for zero-fault completions.
   Total medals and stars unlock later difficulty tiers.

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
