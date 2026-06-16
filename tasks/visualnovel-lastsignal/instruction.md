# Last Signal

Build **Last Signal**, a post-apocalyptic radio visual novel of scarce
resources and hard choices, in Godot 4 at `/workspace/game/`. This is not a
prototype. It is a **complete, shippable micro-game** that could sit on an
itch.io page or Steam as a polished vertical slice.

## Core Vision

The world has gone quiet, and you keep the night watch over a small radio
station that still has power. Out of the static, survivors call in — hungry,
hunted, frightened, sometimes lying. You answer with the only things you have
left: a thin store of supplies, a failing generator, and your judgment. Last
Signal is a **choice-driven visual novel of triage** where every call asks you
to decide who to help, who to turn away, who to believe — and the resources you
spend and the people you save or abandon decide what the long night makes of
you.

The fantasy is **holding a fragile lifeline together while it runs out**. The
heart of the loop is **listen, weigh, decide, live with it** — taking in a
caller's plea, judging it against what little you can spare, and committing to a
choice that costs something real and is remembered. Generosity may empty your
stores before dawn; caution may save you and damn others. The writing should
make those trade-offs weigh on the player. It should play like a tense,
atmospheric survival drama with real stakes and genuinely different endings, not
a linear script with one outcome.

## What the Player Experiences

1. **An Authored Opening** — From a styled title the player takes the night
   watch and is grounded in the station, the dead world outside, and the scarce
   resources they keep, presented as illustrated scenes with narration and a
   sense of place.
2. **Calls Out of the Static** — Survivors reach the player over the radio, each
   a distinct voice with their own situation, plea, and shadow of doubt — a
   family at a roadblock, a stranger who knows too much, a voice that may be
   bait. Calls feel like meeting people, not picking from an identical list.
3. **Decisions That Cost** — For each call the player makes a real choice — send
   supplies, open the door, talk them down, refuse, or probe for the truth — and
   choices visibly spend the player's limited resources (supplies, power, trust,
   or equivalent), so generosity and caution both have a price. The player can
   always see what they have left, and the decision is clearly registered.
4. **A Night That Remembers** — Resources and earlier decisions are carried
   forward and shape what comes later: who calls back, who can still be helped,
   which options remain affordable, and how others come to regard the station.
   Running low changes what the player can do, and a choice made early should
   visibly matter much later in the night.
5. **Many Ways for Dawn to Break** — The night resolves in one of several
   genuinely different endings — a beacon that saved many, a cold survivor who
   outlasted everyone, a station that gave until it had nothing left, or a
   darker truth uncovered — each reachable through how the player spent and
   chose, shown as an authored, styled conclusion that names what the watch
   became. The player can take the watch again to face the night differently.

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
`godot --headless --quit-after 5 --path . -- --scenario ending_beacon`.

A screenshot helper is available at `/workspace/tools/screenshot.sh`. Use it to
actually see what your title / call / choice / ending screens look like.

```
/workspace/tools/screenshot.sh --path /workspace/game \
      -- --out /workspace/frame.png --frames 60
```

To screenshot a specific scenario, append `--scenario <id>` after `--`. The
helper consumes only `--out` / `--frames` / `--scene`; remaining args stay in
`OS.get_cmdline_user_args()` for your game code to read. Example:

```
/workspace/tools/screenshot.sh --path /workspace/game \
      -- --out /workspace/night_debug.png --frames 120 --scenario ending_beacon
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
(a particular radio call, a low-resource night, a state-dependent choice, or
one of the dawn endings), define named scenarios your game loads when launched
with:

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
