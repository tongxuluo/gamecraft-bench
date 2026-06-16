# Tycoon: Funfair

Build a **grid-based theme-park management tycoon** in Godot 4 at
`/workspace/game/`. This is not a prototype. It is a **complete, shippable
micro-game** that could sit on an itch.io page or Steam as a polished vertical
slice.

## Core Vision

The fantasy is turning a bare patch of land into a roaring amusement park that
people love to visit. The player is part architect, part accountant: every path
laid and ride placed shapes how a living crowd moves, spends, and feels. The
interesting tension is that growth feeds on itself — a happy crowd generates the
cash to build more attractions, which draws a bigger crowd — but the snowball
works in reverse too. Neglect paths, gouge prices, or let queues balloon and the
park empties faster than it filled. The pressure comes from balancing ambition
against the crowd's patience: expand too fast and you're broke, too slow and
guests get bored. The risk is always that one bad decision — a dead-end path, a
price hike, a missing amenity — quietly poisons satisfaction before the numbers
catch up.

## What the Player Experiences

The player starts with an empty lot, a gate, and a small pile of cash. The first
minutes are about laying a spine of paths out from the entrance and dropping a
first ride — watching the first handful of guests trickle in and spend money is
the hook. From there the arc is organic growth: earnings fund new rides and
stalls, the crowd swells, and the grid fills with colour and motion.

What the player notices most is the crowd itself — little visitors streaming
along paths, pooling at popular rides, drifting toward food stalls. A well-built
park hums with movement; a badly planned one has lonely corners and bottlenecks.
The satisfaction readout and the cash counter tell the story at a glance, but the
real feedback is visual: a thriving park looks busy and alive.

Pricing is the lever that keeps things interesting even in a mature park. Charge
more and each guest is worth more, but fewer come and they leave sooner. Drop
prices and the gates flood, but margins thin. The player is always tuning this
dial alongside layout decisions — where to put the next ride, whether to upgrade
an existing one into a headline attraction, when to add another food stall to
keep the far side of the park happy.

Over time the lot transforms from a bare grid into a sprawling, bustling
fairground. Progress persists across sessions, so the player returns to the same
park and picks up where they left off. The tone throughout is bright, cheerful,
and colourful — a sunlit carnival of spinning rides and candy colours.

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
