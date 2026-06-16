# Open-World Survival

Build a **2D open-world survival game** in Godot 4 at `/workspace/game/`.
This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

The player awakens alone in a wilderness and must gather resources, craft tools,
build shelter, and survive the night. The fantasy is **self-reliance under
pressure** -- every decision matters because daylight is finite, hunger is
constant, and the world turns hostile after dark. The interesting tension is
choosing what to prioritize: food now or tools for later, exploration or
fortification, risk or safety. Temperature drops, visibility shrinks, and
survival depends on preparation. The art style should feel **earthy, raw, and
immersive** -- think *Don't Starve* meets *A Short Hike* at a smaller scale.

## What the Player Experiences

1. **Title Screen** -- A stylised opening with the game name, a play button, and
   a wilderness backdrop (forest, campsite, or mountain vista). No naked Godot
   grey.

2. **The Wilderness** -- The player spawns in an open-world map with multiple
   visually distinct biomes: grassy plains, dense forest, and rocky terrain or
   water. The player moves freely in 8 directions across a large explorable
   space.

3. **Resource Gathering** -- Scattered across the map are interactable resources:
   trees for wood, stone outcrops for stone, and berry bushes for food. The
   player approaches a resource and interacts to gather it, with visible feedback
   (animation, particle effect, or resource disappearing).

4. **Survival Metrics** -- Status bars are always visible (hunger, thirst, or
   temperature). They drain over time. When a bar hits critical levels, the
   player suffers consequences: slowed movement, screen vignette, health loss, or
   other visible penalties.

5. **Crafting** -- A crafting panel shows available recipes that consume gathered
   materials. Recipes produce useful items: a campfire for warmth, a shelter for
   protection, an axe for faster gathering. The player sees what they can and
   cannot afford to build.

6. **Building and Placement** -- Crafted structures can be placed into the world
   as persistent objects. A campfire provides warmth and light. A shelter
   restores health or blocks environmental damage. Placement has clear visual
   indicators.

7. **Day-Night Cycle** -- Time passes automatically. Day is bright and safe.
   Night darkens the map, shrinks visibility, and accelerates survival drain.
   Being near a campfire at night extends the player's safe radius. Surviving a
   full day-night cycle is the minimal success condition.

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
