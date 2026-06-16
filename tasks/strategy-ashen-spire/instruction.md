# Strategy: Ashen Spire

Build **Ashen Spire**, a compact **dark-fantasy roguelike deckbuilding card
battler** in Godot 4 at `/workspace/game/`. This is not a prototype. It is a
**complete, shippable micro-game** that could sit on an itch.io page or Steam as
a polished vertical slice.

## Core Vision

The fantasy is climbing a cursed tower one floor at a time with nothing but a
thin deck of cards and whatever you scavenge along the way. Each combat is a
small tactical puzzle: energy is scarce, the enemy telegraphs its next move, and
every card played reshapes the odds for the rest of the run. The interesting
tension is that the deck is both your weapon and your liability -- adding
powerful cards dilutes consistency, while staying lean means fewer answers to
escalating threats. The pressure comes from reading enemy intent, rationing
energy across attack and defense, and gambling on which reward cards will pay off
three fights from now. The risk is always that one greedy pick or one misread
intent leaves you one hit from death with no block in hand.

## What the Player Experiences

The player arrives at a dark, atmospheric title screen that sets the tone of a
grim tower ascent. Starting a run reveals a branching route map -- a web of
nodes stretching upward toward a final confrontation, with forks that force the
player to choose which dangers to face and which to skip.

Entering a combat node drops the player into a turn-based card duel. A small
hand is drawn, energy refills, and the enemy displays what it intends to do next
turn. The player spends energy playing cards -- strikes that chip away at the
enemy, guards that raise a shield, and stranger tactical effects that poison,
burn, draw extra cards, or bend the rules. When the hand is spent or the player
is satisfied, ending the turn lets the enemy act, then a fresh hand is drawn and
the cycle repeats.

Winning a fight offers a choice of new cards to weave into the deck, each with
its own identity and cost. The map updates, the player picks the next node, and
the deck grows richer and riskier with every floor. Different encounters reveal
different pixel monsters with distinct silhouettes and behaviors, so no two
climbs feel identical.

The run resolves at the top: defeat the boss and a styled victory screen
celebrates the climb, or fall to zero health anywhere along the way and a defeat
screen marks how far you got. Either way, the player can retry or return to the
title without restarting the application.

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
