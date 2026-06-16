# Roguelike: Wildwood

Build a **node-map forest-exploration roguelike with turn-based combat** in
Godot 4 at `/workspace/game/`. This is not a prototype. It is a **complete,
shippable micro-game** that could sit on an itch.io page or Steam as a polished
vertical slice.

## Core Vision

The fantasy is reading a dangerous forest. Every fork in the trail is a bet
placed with incomplete information: claw marks on a trunk, smoke curling above
the canopy, a glint of metal in the undergrowth. The player pushes deeper not
because the path is safe but because the clues make the risk feel knowable. When
a beast appears, combat is deliberate and positional — a small kit of skills
spent against creatures that each punish a different mistake. Health never
refills for free, so every scratch from three clearings ago still matters at the
final gate. Death is permanent for the run, but not for the player: banked gold
and a dwindling supply of entry tickets give each expedition weight without
making failure a dead end. The tone is hushed and watchful — dappled light,
distant howls, the crackle of a campfire earned by surviving one more node.

## What the Player Experiences

The player begins at a trailhead camp that remembers them between sessions —
tickets, gold, and whatever lasting advantages they have earned are all visible
here. Entering the forest costs a ticket, so the decision to set out already
carries stakes.

Once inside, the run unfolds as a branching map of trail nodes stretching deeper
into the wood. Nodes are not fully revealed; instead the map offers partial
evidence — tracks, smoke, glitter, disturbed brush — that lets the player weigh
risk against their current health, gold, and depth. Committing to a node strips
away the mystery: it might be a beast, a chest, a campfire, a trader, a trap, or
something worse.

Combat is turn-based and skill-driven. The hero carries several distinct
abilities that cost a resource, and different beasts demand different responses —
a fast wolf, an armored bear, a venomous serpent. Lingering conditions like
poison or bleed play out over multiple turns, rewarding the player who reads the
threat and plans ahead.

Between fights the player collects relics and gear that reshape how the hero
fights, not just refill health. Growth within a run is tangible: new buttons, new
options, new ways to handle what the forest throws next.

A run ends in victory — reaching the heart of the wood and overcoming its
guardian — or in death, which sends the player back to camp minus a ticket but
richer in banked gold. Progress persists across sessions, so quitting and
returning picks up the same hoard and the same slow accumulation of power.

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
