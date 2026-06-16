# Strategy: Beast Clash

Build a **single-lane real-time animal-war strategy game** in Godot 4 at
`/workspace/game/`. This is not a prototype. It is a **complete, shippable
micro-game** that could sit on an itch.io page or Steam as a polished vertical
slice.

## Core Vision

Two animal kingdoms clash across a single contested lane. The player commands
one side, spending food to send creatures marching toward the enemy den while
the opponent does the same. Every kill feeds growth, growth unlocks evolution,
and evolution turns a trickle of small critters into a roaring tide of apex
predators. The tension lives in the economy: food is scarce, creatures cost
real resources, and the wrong spend at the wrong moment hands the lane to the
enemy. The tone is lively but fierce — a sunlit savanna-and-jungle frontier
where war escalates from scurrying critters to towering, screen-shaking beasts.

## What the Player Experiences

From the title screen the player picks a kingdom — each feels like a real
faction with its own animals, identity, and fighting temperament, so the choice
is a strategy decision, not a skin swap.

The battle unfolds on a side-scrolling lane between two dens. Food ticks up
over time and the player spends it to send creatures out of their den. Each
creature marches on its own toward the enemy, clashing with whatever it meets
and pushing the front line back and forth. The player never pilots a creature
directly; the strategy is about when to spend, which creature to send, when to
invest in gatherers for more food, and when to save up for evolution.

Creatures come in distinct roles — sturdy blockers that hold the front, ranged
strikers that punish from behind, and gatherers that keep the economy flowing.
The best armies use cooperation: blockers absorb hits while ranged beasts deal
damage safely and gatherers sustain the pressure. The enemy fields its own mix
and grows more dangerous over time, so a static plan loses.

As skirmishes are won, a growth track fills. Reaching thresholds evolves the
kingdom into a new era, unlocking larger, fiercer creatures and visibly
upgrading the den. A later-era beast plainly outclasses an opening-era critter
and expands tactics rather than simply replacing everything before it.

Throughout the battle the player reads the war at a glance — food, evolution
progress, and the health of each den. Victory comes when the enemy den is
destroyed; defeat when the player's own den falls. Each ending lands on a
styled result screen that makes the outcome unmistakable and lets the player
fight again without restarting the application.

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
