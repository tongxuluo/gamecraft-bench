# Thunder Valkyrie

Build **Thunder Valkyrie**, a 2D vertical scrolling bullet-hell shoot-'em-up in
Godot 4 at `/workspace/game/`. This is not a prototype. It is a **complete,
shippable micro-game** that could sit on an itch.io page or Steam as a polished
vertical slice.

## Core Vision

A lone starfighter threads through mathematically dense curtains of enemy fire,
where every pixel of the hitbox matters and every split-second dodge buys another
breath. The tension lives in reading bullet geometry: patterns sweep, spiral, and
converge while the player traces the one safe seam through the chaos. Between
sorties the pilot reinvests plundered gold into hull upgrades, sub-weapons, and
wingman attachments, reshaping how the next wave feels. The tone is bright,
kinetic, and relentless — an arcade reflex challenge wrapped in deep-space neon
and spectacular particle destruction.

## What the Player Experiences

A styled title screen introduces the game with a cosmic backdrop and a clear
path into the hangar.

In the hangar the player reviews their persistent loadout — starfighter level,
shield type, sub-weapon, wingman — and spends gold earned from prior runs to
upgrade slots. Each upgrade visibly changes projectile patterns or survivability
for the next sortie.

From a sector map the player selects a constellation stage. Each stage has a
distinct stellar backdrop and its own enemy composition. Locked stages remain
gated until the previous boss falls.

Once deployed, the screen scrolls vertically over a layered starfield. The
starfighter moves smoothly in response to input, its tiny glowing core hitbox
the only vulnerable point. Primary lasers fire continuously; sub-weapons and
wingmen add flanking fire. Waves of enemy interceptors enter in geometric
formations, releasing scripted bullet configurations that sweep downward. Elite
capital ships drop red power crystals; collecting them triggers a frenzy state
that doubles fire rate and vacuums nearby pickups.

Each stage culminates in a multi-phase boss that locks the scroll and floods the
arena with layered patterns. Taking damage degrades the shield; if it breaks the
run ends with a results overlay showing gold earned and waves survived. Defeating
the boss unlocks the next stage and awards premium components.

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
