# Rogue Joker Poker

Build **Rogue Joker Poker**, a compact **poker-hand roguelite score-chaser** in
Godot 4 at `/workspace/game/`. The player builds a scoring engine from poker
hands, strange jokers, and shop upgrades to beat escalating blind targets in a
single high-stakes run.

This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

The player sits at a surreal felt table trying to beat a rising sequence of
score targets using nothing but poker hands and a growing roster of bizarre
jokers. Every round is a readable tactical choice: which cards to hold, which
to discard, when to spend a hand versus fishing for a better combination, and
how the current joker lineup warps the value of a flush, straight, pair, or
high-card play. The pressure comes from limited hands and discards per round,
escalating blind targets, and boss rules that twist the scoring math. The tone
is **sleek, strange, casino-arcade, and score-hungry**: felt tables, neon chips,
animated cards, odd joker portraits, compact tooltips, and clear score math
should make the game feel designed rather than assembled from default controls.

Do not clone a named commercial game's exact UI, art, copy, card names, or
iconography. Use original terminology, jokers, rules, palette, and screen
composition while preserving the broad genre fantasy of poker scoring plus
roguelite modifiers.

## What the Player Experiences

The run opens on a styled title screen that sets the casino-arcade mood and
invites the player to begin. Once started, the player faces a sequence of
blinds with rising score targets. Each round deals a hand of cards showing
rank, suit, and selection state. The player studies the hand, selects cards to
form a poker combination, and either plays them to score or discards unwanted
cards to draw replacements, burning limited resources either way.

When a hand is played, the scoring moment unfolds visibly: the poker hand type
is identified, base chips and multiplier are calculated, and then each active
joker fires in sequence, visibly altering the math. The score animates toward
the blind target. The player watches the joker row like a machine, learning
which combinations trigger which bonuses.

Between blinds, a shop offers new jokers, deck modifications, and upgrades.
Purchases reshape the scoring engine for future rounds. The run escalates
through small blinds, big blinds, and boss blinds. Boss rounds introduce
special rules that force the player to rethink hand evaluation: a disabled
suit, a discard tax, a hand-size cap, or a reversed joker.

Victory means beating the final target. Defeat means running out of hands
below a blind. Either way, a styled result screen offers retry or return to
title.

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
