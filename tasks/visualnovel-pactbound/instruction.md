# Pactbound

Build **Pactbound**, a summoner pact-choice visual novel, in Godot 4 at
`/workspace/game/`. This is not a prototype. It is a **complete, shippable
micro-game** that could sit on an itch.io page or Steam as a polished vertical
slice.

## Core Vision

You are a summoner walking a road lined with spirits and monsters, and each one
offers the same dangerous bargain: a pact. Bind it and gain its power, but carry
its price and its loyalties; refuse it and stay clean but weaker; deceive it and
risk what comes due later. Pactbound is a **choice-driven visual novel** where
the player meets a procession of would-be familiars and decides which to bind,
and the **collection of pacts they carry becomes who they are** — shaping which
factions trust them, which paths open, and how the journey ends.

The fantasy is **defining yourself by the bargains you make**. The heart of the
loop is **meet, weigh, bind or break** — encountering a spirit with its own
nature and cost, judging what a pact with it would make of you, and committing
to a bargain the story remembers. A summoner bound to gentle hearth-spirits
walks a different road than one who collected demons, and the writing should make
those allegiances felt. It should play like an atmospheric journey with real
stakes and genuinely different endings, not a linear tour with a single path.

## What the Player Experiences

1. **An Authored Opening** — From a styled title the player sets out as a
   summoner and is introduced to the road ahead and the bargain at the heart of
   the world, presented as illustrated scenes with characters and narration.
2. **Spirits with Their Own Nature** — Along the way the player meets a variety
   of would-be familiars — a loyal hearth-spirit, a proud beast, a whispering
   demon, and others — each with its own voice, temperament, the power it
   offers, and the price it asks. Encounters feel like meeting distinct
   characters, not picking from an identical list.
3. **Bind, Refuse, or Deceive** — At each spirit the player makes a real choice:
   seal a pact and take on its power and its loyalties, refuse and stay
   unbound, or strike a false bargain with consequences down the line. The
   decision is deliberate and clearly registered, and the player can see what
   they have bound to themselves.
4. **Pacts That Define You** — The pacts the player carries are **remembered and
   accumulate into an identity**: which factions and spirits trust or revile the
   player, which options and dialogue open up, and which later encounters and
   endings become reachable all depend on the company they keep. A choice made
   early should visibly shape a scene much later.
5. **A Journey That Ends Many Ways** — The road resolves in one of several
   genuinely different endings — crowned among monsters, a champion of the
   unbound, a betrayer alone, or a peacemaker between worlds — each reachable
   through the pacts and choices the player made, and shown as an authored,
   styled conclusion that names what they became. The player can set out again
   to bind a different fate.

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
`godot --headless --quit-after 5 --path . -- --scenario ending_monarch`.

A screenshot helper is available at `/workspace/tools/screenshot.sh`. Use it to
actually see what your title / encounter / choice / ending screens look like.

```
/workspace/tools/screenshot.sh --path /workspace/game \
      -- --out /workspace/frame.png --frames 60
```

To screenshot a specific scenario, append `--scenario <id>` after `--`. The
helper consumes only `--out` / `--frames` / `--scene`; remaining args stay in
`OS.get_cmdline_user_args()` for your game code to read. Example:

```
/workspace/tools/screenshot.sh --path /workspace/game \
      -- --out /workspace/pact_debug.png --frames 120 --scenario ending_monarch
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
(a particular spirit encounter, a pact roster state, a pact-gated choice, or
one of the journey endings), define named scenarios your game loads when
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
