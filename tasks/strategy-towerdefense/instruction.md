# Strategy: Tower-Defense

Build a **2D Tower-Defense Game** in Godot 4 at `/workspace/game/`. This is not
a prototype. It is a **complete, shippable micro-game** that could sit on an
itch.io page or Steam as a polished vertical slice.

## Core Vision

The player is a field commander staring down a map of chokepoints and open
ground, watching a tide of hostiles pour along fixed corridors toward a
vulnerable endpoint. The only tool is a handful of deployable defenders and a
ticking resource clock. The fantasy is **spatial puzzle-solving under escalating
pressure** -- every tile placement is a commitment, every wave ratchets the
stakes, and the interesting tension is that resources spent now on a safe pick
could have been saved for a desperate answer later. The pressure comes from
reading the next wave's composition, choosing where to invest scarce Deployment
Points, and deciding whether to shore up a crumbling lane or gamble on a
high-cost unit that might turn the whole map. The risk is always that one
misread wave or one greedy save leaves the line too thin and enemies pour
through before the next DP tick arrives.

## What the Player Experiences

1. **Title and Campaign Entry** -- A cold, industrial title screen sets the tone.
   The player starts fresh or loads a save, then enters a stage-select map
   showing available missions, each hinting at the enemy composition and
   difficulty ahead.

2. **Deployment Phase** -- Inside a stage the player sees a grid battlefield with
   clearly marked paths, deployable tiles, and a base endpoint. DP ticks upward
   over time. The player drags unit cards from a hand onto legal tiles; each
   placement costs DP and commits a defender to that position. Invalid spots or
   insufficient funds refuse cleanly.

3. **The Assault** -- Enemies surge along the fixed path in discrete waves. Each
   wave is stronger or stranger than the last -- faster scouts, armored brutes,
   flying threats that bypass blockers. Defenders auto-attack within range,
   blockers hold the line, and the player watches HP bars tick down on both
   sides. Deaths remove units from the field; leaks chip away at the base's
   life total.

4. **Escalation and Adaptation** -- Later waves demand answers the opening
   roster cannot provide alone. The player weighs upgrades, repositions
   priorities, and stretches DP across competing needs. The map becomes a living
   puzzle of overlapping ranges and shifting pressure points.

5. **Resolution** -- The final wave breaks against the defense and victory is
   declared, or the base's life hits zero and defeat is acknowledged. Clearing
   a stage marks progress and unlocks the next. The player can retry, return to
   stage select, or quit to title without relaunching.

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
