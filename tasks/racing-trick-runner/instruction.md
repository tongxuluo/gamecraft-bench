# Racing Trick Runner

Build a Racing Trick Runner in Godot 4 at `/workspace/game/`.
This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

An endless downhill runner where the player carves through procedurally varied
terrain, launching off ramps to perform aerial tricks that boost speed and
score. The slope never ends — the challenge is how far you can go before
crashing. Weather shifts from sunshine to blizzard, day cycles to night, and
the terrain grows steeper and more treacherous. Tricks are the key to survival:
they refill a boost meter that lets you power through flat sections. Unlockable
characters with different trick styles and visual flair provide long-term goals.

## What the Player Experiences

1. **Title Screen** — A snowy mountain vista with the game name in a frosty
   stylized font, a silhouetted rider mid-backflip, and Play/Collection
   buttons. No plain Godot grey.
2. **The Run** — Side-scrolling endless descent. The character automatically
   moves downhill; the player controls jump timing, trick execution, and
   landing angle. Terrain scrolls with parallax mountain backgrounds.
3. **Trick System** — While airborne, the player inputs trick commands (flip,
   spin, grab) using directional keys. Each trick has a point value and a
   time cost. Landing cleanly after a trick awards points and refills boost.
   Landing badly (wrong angle) causes a stumble that costs speed.
4. **Boost Mechanic** — A boost meter fills from successful tricks. Activating
   boost increases speed dramatically with a visual trail effect. Boost is
   essential for clearing flat sections and gaps.
5. **Weather and Day/Night** — Conditions change during a run: clear skies
   transition to fog (reduced visibility), then snow (slippery terrain), then
   blizzard (both). Day fades to night with reduced visibility. Each condition
   affects gameplay and visuals distinctly.
6. **Obstacles and Terrain** — Rocks, trees, and crevasses appear as obstacles.
   The terrain varies between smooth slopes, mogul fields, cliff drops, and
   ramp sequences. Hitting an obstacle ends the run.
7. **Character Collection** — At least 5 unlockable characters earned by
   reaching distance milestones or score targets. Each has a unique sprite,
   trick animation style, and one special ability (higher jumps, longer boost,
   extra hit point).

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
