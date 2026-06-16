# Roguelike: Relic Pinball

Build **Relic Pinball**, a compact **pinball / brick-breaker roguelite** in
Godot 4 at `/workspace/game/`: an original, polished vertical slice about
navigating a cursed mechanical table one chamber at a time, breaking target
banks, triggering arcane mechanisms, and collecting relics that visibly mutate
the ball's behavior across an escalating run.

This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

The player is exploring a cursed mechanical table one chamber at a time. Each
chamber is a live pinball board fused with brick-breaker structure: target rows,
bumpers, switches, lanes, gates, spinners, and special blocks create readable
goals while the ball remains fast and physical. The tension lives in flipper
timing and relic synergy — every launch is a gamble, every save a small
triumph, and every relic choice reshapes how the ball interacts with the world.
A ball might split on contact, burn through cracked bricks, curve toward metal
targets, leave scoring echoes, charge bumpers on pass-through, or orbit after
paddle hits. The tone is arcane arcade machine: brass rails, glass reflections,
carved stone bricks, luminous relic icons, bright impact sparks, and snappy
flipper feedback.

## What the Player Experiences

From the title screen the player sees a styled pinball-table motif with at
least one relic or magical ball identity hinting at what lies ahead.

The run drops the player into a live table. A ball launches into a bounded
playfield and the player works left and right flippers to keep it alive,
threading it through bumpers, lanes, and brick banks. Every collision feels
different — bumpers kick the ball away, bricks crack and shatter, switches
light up lanes, spinners charge multipliers, and portals warp the ball across
the board. The table is not a passive backdrop; it reacts.

Clearing enough targets or triggering the right mechanisms opens a relic
choice. The player picks from several relics, each with a name, icon, and
concise rule. The chosen relic immediately changes how the next chamber plays —
the ball splits, pierces, magnetizes, or leaves fire trails. The active relic
row persists and stacks, so the run builds toward a strange loadout that no
two attempts share.

Chambers grow harder: new layouts, tighter drains, armored targets, hazard
bumpers, and eventually a boss table whose special rule demands more than
reflexes. Victory or defeat lands on a styled result screen that lets the
player try again without restarting the application.

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
