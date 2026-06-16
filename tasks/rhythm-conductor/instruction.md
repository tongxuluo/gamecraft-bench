# Rhythm Conductor

Build a Rhythm Conductor in Godot 4 at `/workspace/game/`.
This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

The player is a battlefield conductor issuing rhythmic commands to a squad of
warriors. Each command — march, attack, defend, charge — must be tapped in a
specific rhythm pattern. Nail the timing and your troops execute with power and
precision; fumble it and they stumble into disarray. Enemies advance in waves,
and the player must read the battlefield and choose the right command at the
right tempo. Between battles, the squad levels up and unlocks new command
patterns with more complex rhythms.

## What the Player Experiences

1. **Title Screen** — A war-drum themed menu with the game name in bold
   military-style lettering, a campaign button, and marching silhouettes in
   the background. No plain Godot grey.
2. **Command Input** — The bottom of the screen shows a rhythm bar. The player
   taps 4-beat patterns (e.g., tap-tap-hold-tap for "Attack") in time with a
   metronome pulse. Visual feedback shows timing accuracy per beat.
3. **Squad Response** — When a command is executed successfully, the squad
   performs the action with a power level proportional to timing accuracy.
   Perfect timing triggers a "Fever" version with bonus effects (extra damage,
   wider shield, faster march).
4. **Enemy Waves** — Enemies march from the right in formation. Different enemy
   types require different counter-strategies: shielded foes need the "Charge"
   command to break through; archers need "Defend" to block volleys; swarms
   need "Attack" for area damage.
5. **Battlefield View** — A side-scrolling battlefield shows the player's squad
   on the left and enemies on the right. Units animate their actions in sync
   with the rhythm. Health bars float above each unit group.
6. **Upgrades** — Between missions, the player spends earned resources to
   upgrade unit types (stronger attacks, faster movement) or unlock new command
   patterns (a 6-beat "Rally" that heals, a syncopated "Ambush" for critical
   hits).
7. **Boss Encounters** — Boss enemies have their own rhythm patterns that
   interfere with the player's commands. The player must maintain their own
   tempo while adapting to the boss's disruption beats.

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
