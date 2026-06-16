# Arcborne

Build **Arcborne**, a 2D **grappling-hook swing-momentum platformer** in Godot 4
at `/workspace/game/`: a time-attack about chaining pendulum swings across deadly
terrain, releasing at the perfect instant to soar, and hooking again before
gravity wins.

This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

Fly, don't walk. The player is an acrobat who crosses chasms by firing a
grappling hook, swinging on the line, and releasing at the apex to launch into a
soaring arc -- then hooking again to chain momentum across the course. The
fantasy is momentum mastery: gravity, swing arcs, and well-timed releases
compound into speed, and the difference between a clumsy crawl and a flowing
chain of perfect swings is visceral. One clean run of linked swings feels
glorious; one mistimed release drops you into the spikes.

The pressure comes from the clock. Every course is a time-attack where the
player reads terrain, picks anchor points, commits to a swing, and decides the
exact frame to let go. Multiple hook modes add tactical depth -- sometimes you
need raw pendulum momentum, sometimes a direct yank to reposition -- and the
worlds themselves bend the rules of motion so mastery in one biome doesn't
guarantee mastery in the next.

## What the Player Experiences

1. **Title and Entry** -- The player arrives at a styled title screen that
   establishes the acrobatic, high-velocity tone. Starting a run drops them into
   the first world with a visible clock already ticking.

2. **Swing and Chain** -- The core sensation is physical: fire a hook at an
   overhead anchor, feel gravity pull the arc, build speed at the bottom of the
   pendulum, and release to fling forward. A fresh hook mid-flight chains one
   swing into the next without touching the ground. The player shapes each swing
   -- pumping, reeling, steering -- so skilled play looks fluid and fast while
   beginners flail and recover.

3. **Multiple Hook Modes** -- The player discovers they have more than one kind
   of hook. A swing line carries pendulum momentum; a pull line yanks them
   straight to an anchor for tight climbs or recoveries. Switching between modes
   becomes second nature as the terrain demands it.

4. **Worlds that Change the Rules** -- The journey carries the player through
   escalating worlds with distinct environments. Each world introduces its own
   anchor types, hazards, and an environmental modifier that alters how swinging
   feels -- gusts that shove mid-arc, conveyors that drag on the ground, low
   gravity that stretches every launch into a long glide. The player must adapt
   their timing and technique to each new set of physics.

5. **Danger and Recovery** -- Pits, spikes, blades, and moving hazards punish
   mistimed releases. Hitting a hazard or falling sends the player back to a
   checkpoint with clear feedback. The course is forgiving enough to learn but
   punishing enough that a clean run feels earned.

6. **Resolution** -- Reaching the goal ends the course with a result showing
   time and medal. The player can retry for a better time or advance to the next
   course. The full loop -- title, play, result, retry or advance -- flows
   without restarting the application.

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
