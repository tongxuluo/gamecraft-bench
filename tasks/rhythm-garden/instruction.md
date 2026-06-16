# Rhythm Garden

Build a Rhythm Garden in Godot 4 at `/workspace/game/`.
This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

A whimsical garden overworld connects a collection of eight or more timing
minigames, each themed around a different garden activity — watering flowers to
a beat, swatting bugs in rhythm, conducting a bird choir, bouncing seeds into
pots with timed taps. Each minigame teaches a different rhythmic skill (steady
pulse, syncopation, polyrhythm, call-and-response). Mastering individual games
unlocks a final "Remix" stage that weaves all mechanics together into one
climactic performance. The fantasy is a musical gardener tending a world that
blooms in response to rhythmic mastery.

## What the Player Experiences

1. **Title Screen** — A pastel garden scene with the game name in a playful
   hand-drawn font, flowers swaying to a gentle beat, and a "Play" button
   shaped like a watering can. No plain Godot grey.
2. **Garden Hub** — An overworld map showing garden plots, each representing a
   minigame. Completed games bloom with flowers; locked ones show wilted buds.
   The player clicks a plot to enter its minigame.
3. **Minigame Variety** — At least 8 distinct minigames, each with unique
   visuals and a different timing mechanic:
   - Tap to the beat (steady quarter notes)
   - Hold and release (sustained timing)
   - Call and response (echo a pattern)
   - Syncopation (off-beat hits)
   - Polyrhythm (two simultaneous patterns)
   - Speed ramp (accelerating tempo)
   - Pattern memory (repeat increasingly long sequences)
   - Free-form (improvise within a groove)
4. **Scoring** — Each minigame scores accuracy as a star rating (1-3 stars).
   Visual feedback during play shows timing quality with particle bursts for
   perfect hits and wilting effects for misses.
5. **Progression** — Earning stars unlocks later minigames. The garden visibly
   grows and blooms as the player progresses. New flowers, butterflies, and
   decorations appear with each milestone.
6. **Final Remix** — After completing all 8 minigames, a final challenge
   combines mechanics from multiple games into one extended performance. The
   remix transitions between styles every few measures.
7. **Results and Gallery** — A gallery screen shows total stars, best scores per
   minigame, and the fully-bloomed garden as a reward illustration.

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
