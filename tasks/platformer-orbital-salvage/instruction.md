# Orbital Salvage

Build **Orbital Salvage**, a compact 2D space-salvage physics game in Godot 4
at `/workspace/game/`: a polished micro-game about piloting a small tug through
orbital debris, latching onto wreckage with a tractor beam, and hauling it back
to a recovery station before fuel runs dry or hazards tear the payload loose.

This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

The player is a salvage pilot working the edge of a debris belt. The tug does
not stop on a dime — it drifts, coasts, and fights momentum every time the
thrusters fire. Attaching a tractor beam to a chunk of wreckage changes
everything: heavier salvage drags the tug off course, volatile pieces threaten
to rupture, and the route back to the station threads between gravity wells,
drifting mines, and radiation arcs. The decision space lives in choosing which
contract to accept, which salvage to grab first, how aggressively to burn fuel,
and whether to risk a shortcut through a hazard corridor for a bigger payout.
Between runs the player reinvests credits into thrust power, beam strength, or
hull plating, shaping how the next contract feels. The tone is tense and
industrial — a blue-collar space job where physics is the real antagonist.

## What the Player Experiences

A styled title screen sets the mood: the game name over a starfield with
drifting debris silhouettes, a tug outline, and a clear way to begin.

The player picks a contract from a board showing salvage type, estimated mass,
payout, and hazard warnings. The tug launches into a 2D orbital field where
inertia is king — tapping thrust accelerates, releasing it lets the ship coast,
and reversing burns fuel fast. Salvage floats among asteroid chunks and hazard
zones. The player maneuvers close, fires the tractor beam, and feels the tug
lurch as the mass latches on. Towing a heavy reactor core is nothing like
dragging a light panel — the ship wallows, turns wide, and fuel burns faster.

Hazards punctuate the route: gravity wells bend the flight path, mines detonate
if clipped, radiation arcs pulse warnings before firing. The player reads the
field, plans a line, and commits — or cuts the beam and abandons the payload to
save the tug. Delivering salvage to the station awards credits and advances the
contract. A result screen tallies earnings, fuel spent, hull damage, and offers
the next contract or a return to title.

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
