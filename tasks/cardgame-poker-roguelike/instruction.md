# Cardgame Poker Roguelike

Build a Cardgame Poker Roguelike in Godot 4 at `/workspace/game/`.
This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

A roguelike scoring game built on poker hand evaluation. The player is dealt
cards and must form poker hands (pairs, straights, flushes) to score points
against escalating blind targets. The twist: collectible Joker cards modify
scoring rules in wild ways — one might triple the value of all hearts, another
might make every pair count as a full house. Between rounds, a shop sells new
Jokers, card enhancements, and consumable items. The fantasy is discovering
absurd scoring combos that turn a humble pair of twos into a million-point
hand. Fail to meet the blind and the run ends.

## What the Player Experiences

1. **Title Screen** — A casino-noir aesthetic with the game name in gold
   embossed lettering on green felt, animated card shuffling in the background,
   and New Run / Stats buttons. No plain Godot grey.
2. **The Hand** — The player is dealt 8 cards from a standard deck. They select
   up to 5 cards to form a poker hand and submit it for scoring. Remaining
   cards can be discarded and redrawn (limited discards per round).
3. **Scoring** — Each hand type has a base chip value and multiplier (e.g.,
   Pair = 10 chips x2, Flush = 35 chips x4). Jokers and enhancements modify
   these values. The score animates with each modifier applied sequentially,
   building dramatic tension.
4. **Blinds** — Each round has a target score (the blind). Small Blind, Big
   Blind, and Boss Blind escalate. The player has multiple hands per round to
   meet the target. Failing to reach the blind ends the run.
5. **Joker Cards** — Up to 5 Joker slots. Each Joker has a unique rule-bending
   effect with illustrated art and a description. Jokers are purchased from
   the shop or earned from Boss Blinds. Synergies between Jokers create
   exponential scoring potential.
6. **Shop** — Between rounds, spend earned money on new Jokers, card
   enhancements (foil, holographic, polychrome — each with scoring bonuses),
   vouchers (permanent upgrades), or booster packs (new playing cards).
7. **Boss Blinds** — Special blinds with debuff conditions (e.g., "all clubs
   are face-down", "no discards this round", "first hand played is
   debuffed"). The player must adapt their strategy to the boss condition.

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
