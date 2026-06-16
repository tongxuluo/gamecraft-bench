# Rhythm DJ Arena

Build a Rhythm DJ Arena in Godot 4 at `/workspace/game/`.
This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

Two musical fighters face off on a neon stage, trading rhythmic attacks in a
battle of beats. Each fighter has a note highway; hitting notes charges special
moves that launch across the arena as musical projectiles. The opponent must
dodge or counter with their own charged abilities. The fantasy is a DJ battle
where musical skill translates directly into combat power — perfect combos
unleash devastating bass drops while missed notes leave you vulnerable. Multiple
characters with distinct musical styles and move sets provide variety.

## What the Player Experiences

1. **Title Screen** — A vibrant neon club aesthetic with the game name in
   glowing graffiti-style text, character select and versus mode buttons, and
   animated equalizer bars in the background. No plain Godot grey.
2. **Character Select** — At least 4 playable characters, each with a distinct
   musical theme (electronic, rock, jazz, hip-hop), unique sprite design, and
   different special move sets. Each character's selection shows a preview
   animation and their move list.
3. **Split Highway** — The screen splits: each side has a 3-lane note highway.
   The player hits notes on their side to build a charge meter. The AI opponent
   plays their own highway simultaneously.
4. **Charge and Attack** — When the charge meter fills a threshold, the player
   can spend it to launch a musical attack (bass wave, treble spike, chord
   blast). Attacks travel across the arena toward the opponent. Stronger charges
   (from higher combos) produce more powerful attacks.
5. **Defence and Dodge** — The opponent can dodge attacks by timing a key press
   as the projectile arrives, or absorb hits (losing health). A health bar
   depletes with each successful hit. First to zero loses the round.
6. **Best of Three** — Matches are best-of-3 rounds. Between rounds, a brief
   interlude shows score and lets the tempo increase for the next round.
7. **Arcade Mode** — A ladder of increasingly difficult AI opponents, each with
   faster note patterns and more aggressive attack usage. Defeating all
   opponents shows a character-specific victory screen.

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
