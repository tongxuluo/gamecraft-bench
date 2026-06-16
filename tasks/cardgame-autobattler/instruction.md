# Cardgame Autobattler

Build a Cardgame Autobattler in Godot 4 at `/workspace/game/`.
This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

A draft-and-watch autobattler where the player recruits creatures from a shared
shop each round, arranges them on a board, and watches them fight automatically
against an opponent's team. Strategy lives entirely in the draft phase: which
creatures to buy, when to level up for stronger units, and how to build
synergies between tribal tags. Creatures of the same tribe buff each other —
stack enough Beasts and they gain attack; fill a row with Undead and they
resurrect once. An 8-player elimination format (simulated against AI) creates
escalating pressure as the field narrows. The fantasy is assembling a dream
team from random offerings and watching your synergy engine demolish the
opposition.

## What the Player Experiences

1. **Title Screen** — A tavern interior with the game name on a wooden sign
   above the bar, creature silhouettes seated at tables, and a "Find Match"
   button styled as a tavern door. No plain Godot grey.
2. **Shop Phase** — Each round, a shop displays 3-5 random creatures for
   purchase. The player buys creatures (spending gold), places them on a
   bench or directly onto the board (limited slots). Selling creatures
   refunds partial gold. A timer counts down to the fight phase.
3. **Board Arrangement** — The player's board has a front row and back row.
   Positioning matters: front-row creatures are attacked first; back-row
   creatures with ranged attacks stay safe longer. Drag-and-drop placement.
4. **Auto Combat** — When the timer expires, the player's board fights an
   opponent's board automatically. Creatures attack in order, targeting the
   nearest enemy. Abilities trigger based on conditions (on-attack, on-death,
   start-of-combat). The fight plays out with attack animations and health
   bars depleting.
5. **Tribal Synergies** — At least 5 tribes (Beast, Undead, Mech, Dragon,
   Elemental). Having 2/4/6 of a tribe activates escalating bonuses shown in
   a synergy tracker panel. Synergies are the primary strategic axis.
6. **Economy** — Gold income increases each round. Winning streaks and losing
   streaks both grant bonus gold. Interest accrues on saved gold (1 gold per
   10 saved). Levelling up costs gold but increases shop quality and board
   size.
7. **Elimination** — The player starts with a health pool. Losing a round
   costs health proportional to surviving enemy creatures. Last player
   standing wins. A placement screen shows final ranking.

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
