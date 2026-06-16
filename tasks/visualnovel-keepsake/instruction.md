# Keepsake

Build **Keepsake**, a quiet memory-reconstruction visual novel about sorting a
late person's belongings, in Godot 4 at `/workspace/game/`. This is not a
prototype. It is a **complete, shippable micro-game** that could sit on an
itch.io page or Steam as a polished vertical slice.

## Core Vision

Someone has died, and you have been asked to sort through what they left behind.
A faded photograph, a folded letter, a worn ring, a diary with a torn-out
page — each object holds a fragment of a life, and they do not give up their
meaning in order. Keepsake is a **choice-driven visual novel of reconstruction**
where the player examines the keepsakes of a stranger and, piece by piece and
out of sequence, assembles the story of who this person really was — and the
quiet secret time had buried with them.

The fantasy is **piecing together a life from the things it left behind**. The
heart of the loop is **examine, remember, connect, understand** — turning a
keepsake over, hearing the memory it stirs, and fitting it against what you have
already found until a hidden shape emerges. The order the player chooses, and
how they come to read an ambiguous choice the dead made, shape the
understanding they arrive at. It should feel like a slow, tender, melancholy
piece with real emotional weight and more than one way to understand a life, not
a single linear obituary read start to finish.

## What the Player Experiences

1. **An Authored Opening** — From a styled title the player is given their
   task — a room, a box, a life's worth of objects to sort — established as a
   quiet illustrated scene with narration that sets the mood and the absence at
   its center.
2. **Examining the Keepsakes** — The player chooses which object to take up,
   in whatever order they like, and each keepsake is examined as an illustrated
   item with the memory or fragment of the past it reveals. The room of
   belongings is something the player works through at their own pace, not a
   fixed slideshow.
3. **Fragments That Connect** — Each examined keepsake adds a remembered
   fragment to what the player knows, and fragments fit against one another:
   a date on a letter explains a photograph, an object's absence answers an
   earlier question. The player feels a life assembling out of order, and what
   they have already found colors how the next piece reads.
4. **A Choice of Understanding** — As the picture comes together the player
   reaches moments of interpretation — how to read an ambiguous decision the
   dead person made, what to believe about a secret, whether to judge or
   forgive. These choices are deliberate and remembered, and what the player has
   uncovered shapes which understandings are even available.
5. **More Than One Way to Remember** — The piece resolves into one of several
   genuinely different closing understandings — a life redeemed, a secret kept
   in kindness, a quiet grief, a truth that recasts everything — each reached
   through which fragments the player found and how they chose to read them,
   and shown as an authored, styled conclusion that names the understanding they
   came to. The player can begin again and arrive somewhere else.

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
`godot --headless --quit-after 5 --path . -- --scenario ending_forgive`.

A screenshot helper is available at `/workspace/tools/screenshot.sh`. Use it to
actually see what your title / room / keepsake / ending screens look like.

```
/workspace/tools/screenshot.sh --path /workspace/game \
      -- --out /workspace/frame.png --frames 60
```

To screenshot a specific scenario, append `--scenario <id>` after `--`. The
helper consumes only `--out` / `--frames` / `--scene`; remaining args stay in
`OS.get_cmdline_user_args()` for your game code to read. Example:

```
/workspace/tools/screenshot.sh --path /workspace/game \
      -- --out /workspace/memory_debug.png --frames 120 --scenario ending_forgive
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
(a particular keepsake, a memory-board state, an interpretation choice, or one
of the closing understandings), define named scenarios your game loads when
launched with:

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
