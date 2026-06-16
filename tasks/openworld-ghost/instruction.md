# Open-World Ghost Hunting

Build a **2D open-world ghost hunting game** in Godot 4 at `/workspace/game/`.
This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

The player explores haunted locations across an open-world town, using
specialised equipment to detect, track, and capture ghosts. The game feels
**atmospheric, tense, and investigative** -- think *Phasmophobia* meets
*A Short Hike* at a smaller scale. The art style must be **coherent and
dark-atmospheric**: muted palettes, fog overlays, flickering light sources,
and readable sprites against shadowy backgrounds.

## What the Player Experiences

1. **Title and Entry** -- The player arrives at a styled title screen with a
   spooky backdrop (foggy graveyard, flickering lantern, silhouette of a house)
   and a "Begin Hunt" or "Play" button. Starting drops them into the open-world
   town hub.

2. **The Haunted World** -- The player walks freely across an open-world town
   with at least four visually distinct haunted locations: an abandoned mansion
   (dark, broken windows, overgrown garden), a haunted forest (twisted trees,
   fog, glowing eyes), an old lighthouse (coastal, waves, creaking wood), and a
   derelict hospital (corridors, flickering lights, wheelchairs). Each location
   has its own atmosphere and ghost type.

3. **Detection Equipment** -- The player carries at least three tools: an EMF
   reader (beep frequency increases near ghosts), a thermal camera (shows cold
   spots as blue overlays), and a spirit box (captures ghost voices as text).
   Each tool has distinct visual and audio feedback. Ghosts are invisible
   without equipment -- the tools are the only way to find them.

4. **Ghost Types and Evidence** -- At least four distinct ghost types with
   unique behaviours: poltergeist (throws objects), wraith (freezing breath,
   walks through walls), banshee (screams before attacking), and shade (hides
   in darkness, afraid of light). Each type leaves specific evidence that the
   player must collect and cross-reference on an evidence board to identify it.

5. **The Hunt Phase** -- When enough evidence is collected, the ghost becomes
   aggressive: lights flicker, the environment distorts, and a hunt timer
   counts down. The player must use defensive items (crucifix, salt circle,
   flashlight) to survive and capture the ghost before time runs out.

6. **Sanity and Pressure** -- A sanity meter drops in darkness, when seeing
   ghost activity, or when alone too long. Low sanity causes hallucinations
   (false readings, fake shadows) and makes the ghost more aggressive. Light
   sources and safe rooms restore sanity, creating a push-pull between
   investigation and self-preservation.

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
