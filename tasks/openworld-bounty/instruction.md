# Open-World Bounty

Build a **2D open-world bounty hunter game** in Godot 4 at `/workspace/game/`.
This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

The player is a lone hunter roaming a lawless frontier, picking contracts off a
weathered quest board and tracking dangerous marks across hostile terrain. The
fantasy is **pursuit under uncertainty** -- each bounty is a commitment to
venture deeper into unfamiliar ground, and the interesting tension is that the
hunter must read the landscape, manage limited resources, and choose when to
engage versus when to retreat. The pressure comes from escalating target
difficulty, dwindling supplies, and the knowledge that a failed hunt means
walking back empty-handed. The risk is always that the next mark fights harder
than expected, or that the hunter spent too much on an easy bounty and has
nothing left for the real threat.

## What the Player Experiences

1. **Title and Entry** -- A gritty, western-fantasy title screen sets the tone.
   The player hits start and arrives in a frontier town -- a hub with a tavern,
   a quest board, and a handful of NPCs who sell gear or patch wounds.

2. **Picking a Contract** -- The quest board displays available bounties, each
   with a target portrait, a difficulty rating, and a gold reward. The player
   reads the cards, weighs risk against payout, and commits to a mark. The
   chosen bounty becomes the active hunt, and the world shifts focus toward
   tracking.

3. **The Hunt** -- A compass or directional marker guides the player out of
   town and into the wilds. The world has multiple distinct regions -- forest
   hideouts, bandit camps, rocky canyons -- and the target waits somewhere
   inside, patrolling or lying in ambush. The journey itself is part of the
   experience: terrain changes, ambient threats, and the growing distance from
   safety.

4. **Confrontation** -- Finding the target triggers combat. The hunter has
   multiple attack options and must read the target's behavior to survive.
   Targets fight back with visible aggression; health bars deplete on both
   sides. Different marks demand different tactics -- one is fast and evasive,
   another is armored and punishing.

5. **Claiming the Reward** -- Returning to town after a successful hunt
   triggers a payout sequence. Gold is added to the purse, the bounty card is
   struck from the board, and the hunter can spend earnings on better gear or
   harder contracts. The loop resets with new marks and higher stakes.

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
