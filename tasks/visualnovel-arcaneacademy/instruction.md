# Arcane Academy

Build **Arcane Academy**, a magic-school stat-raising visual novel, in Godot 4
at `/workspace/game/`. This is not a prototype. It is a **complete, shippable
micro-game** that could sit on an itch.io page or Steam as a polished vertical
slice.

## Core Vision

You are a first-year at a school of magic, and a term is short. There is never
enough time to master everything, so what you choose to study — elemental
sorcery, runecraft, alchemy, the tempting forbidden arts — slowly shapes the
mage you become. Arcane Academy is a **stat-raising visual novel**: between
story beats the player spends limited time and effort training different
disciplines, and the magician they grow into decides how classmates and
mentors treat them, which paths open, and how the term ends.

The fantasy is **becoming someone through the choices of a single term**. The
heart of the loop is **plan, train, live the consequences** — deciding where to
invest scarce time, watching abilities rise, and then meeting story moments
where who you have become matters as much as what you say. A student who poured
everything into forbidden magic walks a different road than a diligent
runescribe, and the writing should make that growth felt. It should play like a
warm, atmospheric school story with real stakes and genuinely different
outcomes, not a linear tour with a single ending.

## What the Player Experiences

1. **An Authored Opening** — From a styled title the player arrives at the
   academy and is introduced to the term ahead, the disciplines they might
   study, and the classmates and mentors around them, presented as illustrated
   scenes with characters and narration.
2. **Planning the Term** — Across the term the player repeatedly decides how to
   spend limited time and energy, choosing which magical disciplines to train.
   Time is scarce, so investing in one pursuit means neglecting another, and the
   player feels the weight of the trade-off.
3. **Growth That Shows** — Training visibly raises the player's abilities, and
   that progress is something the player can read and care about. The mage they
   are building takes shape over the term rather than staying fixed.
4. **Story Beats That Test You** — Between training, authored story scenes
   unfold — a rivalry, a mentor's offer, a forbidden temptation, a crisis at the
   school — where the player makes meaningful choices. What the player has
   trained matters here: some options, lines, or events are only available to a
   mage who built the right strengths, so growth and choice intertwine.
5. **A Term That Ends in Many Ways** — The term resolves in one of several
   genuinely different endings — honored graduate, fallen to the forbidden arts,
   expelled in disgrace, or the keeper of a hidden truth — each reachable
   through how the player trained and chose, and shown as an authored, styled
   conclusion that names what they became. The player can begin a new term to
   grow into someone else.

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
`godot --headless --quit-after 5 --path . -- --scenario ending_archmage`.

A screenshot helper is available at `/workspace/tools/screenshot.sh`. Use it to
actually see what your title / training / story / ending screens look like.

```
/workspace/tools/screenshot.sh --path /workspace/game \
      -- --out /workspace/frame.png --frames 60
```

To screenshot a specific scenario, append `--scenario <id>` after `--`. The
helper consumes only `--out` / `--frames` / `--scene`; remaining args stay in
`OS.get_cmdline_user_args()` for your game code to read. Example:

```
/workspace/tools/screenshot.sh --path /workspace/game \
      -- --out /workspace/term_debug.png --frames 120 --scenario ending_archmage
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
(a particular training week, a stat-gated story beat, a late-term crisis, or
one of the term endings), define named scenarios your game loads when launched
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
