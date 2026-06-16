# Open-World Time Travel

Build a **2D open-world time-travel game** in Godot 4 at `/workspace/game/`.
This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

The player discovers a time-travel device and explores the same open-world
location across multiple distinct eras — a lush ancient past, a bustling
industrial present, and a desolate high-tech future. Actions in one era ripple
forward and alter the landscape, inhabitants, and available paths in later eras.
The fantasy is **temporal cause and effect**: the player reads the world, makes
deliberate changes in the past, then jumps forward to witness consequences
unfold. Tension comes from the butterfly effect — a small act of kindness or
destruction cascades across centuries — and from paradox: the world resists
contradictions, and the player must think carefully about what they change and
when. The game should feel mind-bending and interconnected, like a puzzle box
made of history.

## What the Player Experiences

1. **Title Screen** — A styled opening with the game name, a "Begin Journey"
   or "Play" button, and a temporal backdrop (overlapping landscapes bleeding
   into each other, clock gears, aurora). No naked Godot grey.
2. **Three Eras** — The same geographical region rendered in three visually
   distinct time periods: an ancient wilderness with warm saturated greens, an
   industrial cityscape with muted greys and oranges, and a ruined future with
   cold blues and purples. The player walks freely in each era and recognises
   landmarks that persist across time.
3. **Time Travel** — The player activates a time-travel device to jump between
   eras. The transition plays a visible effect and the destination era loads
   with the player at the corresponding map coordinates, preserving spatial
   continuity.
4. **Butterfly Effect** — Actions in an earlier era alter later eras in visible,
   gameplay-meaningful ways. Multiple causal chains exist: planting something in
   the past changes the landscape in the future, destroying infrastructure
   reshapes routes, befriending NPCs leaves legacies for their descendants.
5. **Paradox Detection** — The game prevents or punishes paradoxical actions.
   Attempting to destroy something your future self depends on triggers warnings
   and instability until the paradox is resolved.
6. **Cross-Era Quests and NPCs** — Each era has unique NPCs whose quests span
   multiple time periods. Completing cross-era objectives unlocks new
   destinations or upgrades the time device.
7. **Temporal Inventory** — Items have era compatibility. Some survive time
   travel while others decay. The inventory communicates which items are stable
   and which will not survive the next jump.

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
