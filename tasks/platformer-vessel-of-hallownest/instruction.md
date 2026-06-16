# Vessel of Hallownest

Build a **2D atmospheric metroidvania platform-action game** in Godot 4 at
`/workspace/game/`. This is not a prototype. It is a **complete, shippable
micro-game** that could sit on an itch.io page or Steam as a polished vertical
slice.

## Core Vision

A silent bug knight descends into a ruined underground kingdom, armed only with
a nail and the will to press deeper. The fantasy is exploration under pressure:
every room might hold a new threat or a shortcut home, and the player is always
weighing aggression against survival. Combat is fast and punishing — each slash
refills the soul that fuels healing, so standing still means dying slowly. The
interesting tension is that the resource loop forces engagement: you heal by
fighting, but fighting risks the health you are trying to recover. Progression
gates the world behind abilities earned in earlier zones, rewarding mastery with
access rather than numbers. The tone is somber, desolate, and beautifully
tragic — cold underground ruins, glowing particles drifting through silence, and
the quiet weight of a kingdom that fell long ago.

## What the Player Experiences

A melancholic title screen greets the player with the game name and a lone
knight silhouette before they choose to begin or continue a saved journey.

The Kingdom Map appears — a network of named stages stretching downward, each
locked until the one before it falls. The player selects the first open stage
and drops in. Inside, the world is a continuous side-scrolling corridor of
connected rooms: platforms jut from cavern walls, thorn pits line the floor, and
infected husks patrol ledges. Movement feels tight and responsive — the knight
accelerates smoothly, jumps with a satisfying arc, clings to walls, and dashes
through gaps that demand precision.

Combat is immediate and visceral. Slashing an enemy staggers it, sprays geo
currency, and fills the soul meter. Taking a hit costs a mask of health and
triggers a brief flash of invincibility. When masks run low the player faces the
core dilemma: hold still to channel soul into healing — vulnerable, exposed — or
press forward and hope the next kill refills enough to survive. Enemies guard
room exits behind soul-barriers that lift only when every husk in the chamber is
dead.

Deeper rooms demand wall-clings and dashes to cross chasms the knight cannot
simply jump. Reaching the far end of a stage triggers a checkpoint that saves
progress and unlocks the next zone on the map. Death is costly — all carried geo
drops at the point of failure and the knight returns to the map to try again.

The final stage is a boss chamber: a large creature with telegraphed attack
patterns that test everything the player has learned. Victory crowns the run;
defeat sends the knight back with nothing but knowledge.

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
