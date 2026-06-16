# Roguelike: Rulescape

Build **Rulescape**, a top-down **rules-horror roguelike survival game** in
Godot 4 at `/workspace/game/`: a polished vertical slice where the player
navigates haunted public spaces, deciphers unstable rules, and escapes before
the site consumes them.

This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

The fantasy is being trapped inside a place that was once ordinary -- a
hospital, a school, a subway station -- now governed by rules that shift,
corrupt, and lie. Survival depends on reading the environment, deducing which
rules are real, and acting before time runs out. The pressure comes from an
advancing timetable that changes what is safe, anomalies whose behavior is
tied to the local mystery, and the knowledge that obeying the wrong rule is as
deadly as breaking the right one. Each site is a story before it is a level:
its rooms, props, clues, and escape condition should feel like one connected
mystery, not a generic dungeon with swapped textures. The tone is frightening,
bloody, investigative, and oppressive.

## What the Player Experiences

1. **Title and Survivor Choice** -- The player arrives at a dark, themed title screen and selects a survivor from a small roster. Each survivor brings a different tool or instinct that changes how the player reads danger and interacts with the site.
2. **Entering the Site** -- The run drops the player into a top-down anomaly site -- a real-feeling place with rooms, corridors, locked doors, scattered props, and environmental storytelling. The site has its own name, visual identity, local mystery, and set of posted rules that the player can inspect in-world.
3. **The Timetable** -- A visible clock or schedule advances during exploration. When it reaches authored thresholds the site's rhythm changes: new areas unlock, anomalies shift behavior, rules become more dangerous, or an escape window opens.
4. **Exploration and Deduction** -- The player moves through the site, searches objects for clues and items, reads rules (some incomplete, misleading, or corrupted), and pieces together what is actually true. Anomalies appear as spatial threats tied to the site's rules; the player responds by fleeing, hiding, using items, or obeying the correct rule -- wrong choices cost health, sanity, or time.
5. **Resolution** -- Victory comes from satisfying the site's escape condition; defeat comes from a fatal anomaly encounter, rule violation, or resource collapse. The result screen explains what rule, clue, or decision sealed the outcome.

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
