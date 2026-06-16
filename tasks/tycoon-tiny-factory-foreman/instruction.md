# Tiny Factory Foreman

Build **Tiny Factory Foreman**, a compact 2D automation and production-planning
game in Godot 4 at `/workspace/game/`. This is not a prototype. It is a
**complete, shippable micro-game** that could sit on an itch.io page or Steam as
a polished vertical slice.

## Core Vision

The fantasy is running a miniature factory floor where raw materials flow in one
end and finished goods roll out the other — if the player has wired everything
together correctly. The interesting tension is spatial: belts only carry forward,
sorters only split, and machines only accept certain inputs, so every tile
placement is a routing puzzle under time pressure. Orders arrive on a board with
ticking deadlines, and the player must decide whether to retool the line for a
new product or squeeze more throughput from the current layout. The risk is
always a cascade failure — one misrouted material jams a machine, the backup
stalls the belt, and suddenly three orders expire at once. Growth comes from
earning enough to unlock faster belts, smarter sorters, or multi-output machines,
but each upgrade reshapes the routing problem rather than simply solving it.

## What the Player Experiences

The player opens to a compact workshop view: a few raw-material sources on one
side, empty order bins on the other, and a grid of open floor between them. An
order board shows what products are needed and how long remains. The first
minutes are about laying a simple belt path from source to machine to bin and
watching the first coloured crate trundle across the floor.

As orders grow more complex the player drops sorters to split material streams,
places different machine types that transform inputs into intermediate or final
goods, and reroutes belts to avoid collisions. The floor fills with motion —
little icons sliding along conveyors, machines pulsing as they process, sorters
flicking left or right. A well-designed line hums; a badly planned one backs up
and flashes warnings.

Between rounds or when cash allows, the player visits an upgrade screen to
improve belt speed, unlock a new machine recipe, or expand storage capacity.
These choices shape what orders can be accepted next. Eventually the shift ends
and a result screen tallies fulfilled orders, missed deadlines, and coins earned,
offering a retry or a return to the title.

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
