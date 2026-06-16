# Grim Fable

Build **Grim Fable**, a branching dark-fairytale visual novel, in Godot 4 at
`/workspace/game/`. This is not a prototype. It is a **complete, shippable
micro-game** that could sit on an itch.io page or Steam as a polished vertical
slice.

## Core Vision

You step into fairy tales you think you already know — but the woods are darker
than you remember, the kind are not always good, and the wicked may have their
reasons. Grim Fable is a **choice-driven visual novel** where the player relives
familiar storybook tales as their protagonist, yet the choices on offer were
never in the original telling. What looks like a bedtime story hides an uneasy
truth, and the player's decisions decide which version of that truth comes to
pass.

The fantasy is **rewriting a story you assume you know**. The game should turn
the player's own expectations into the trap: a beloved tale opens the familiar
way, then forks toward outcomes the fairy tale never allowed. The heart of the
loop is **read, examine, weigh, decide** — taking in a richly written scene,
looking closely at what the illustration is hiding, sizing up who and what to
trust, and committing to a choice that the story remembers and pays off later.
It should feel like turning the pages of a haunted picture book where text,
portraits, backdrops, and choice menus all belong to the same authored world.
This is a polished, atmospheric storybook with real stakes and genuinely
different endings, not a linear text dump with a single path.

## What the Player Experiences

1. **An Authored Opening** — From a styled title the player begins the tale and
   is eased into a familiar fairy-tale premise, presented as an illustrated
   storybook scene with characters, narration, and a clear sense of who they
   are and where they stand.
2. **Reading & Examining the Scene** — The story unfolds through paced dialogue
   and narration over illustrated backdrops, but the scene is not just read — it
   invites investigation. Props, details of the setting, and the characters
   present can hide narration, clues, or secrets the player would otherwise
   miss, so the comforting tale's darker underside is something the player
   uncovers, not just something told to them.
3. **Clues That Add Up** — What the player examines and learns is **gathered and
   remembered**: a blood-flecked knife noticed on a table, a confession teased
   out of a character, a detail that contradicts the storybook version. These
   discoveries accumulate into the player's understanding and unlock or color
   the choices and revelations that follow, rewarding a curious player who looks
   closely over one who rushes ahead.
4. **Meaningful Choices** — At key moments the player is offered choices that
   the original story never gave them — whom to trust, what to reveal, which
   path to take through the wood. Choices are deliberate decisions with stakes,
   not cosmetic flavor; what the player has uncovered shapes which options are
   available and what they mean, and the game makes clear that a decision has
   been made and registered.
5. **Consequences That Stick** — Earlier choices are remembered and shape what
   comes later: which characters confide in the player, what truths surface,
   and which doors close. The player should feel the story bending around their
   decisions rather than running on rails, and recurring tales or returning
   characters should reflect what the player did before.
6. **Divergent Endings** — The tale resolves in one of several genuinely
   different endings — a subversion of the happy ending, a grim reckoning, a
   hidden truth uncovered, or a quiet escape — each reachable through different
   choices and clearly tied to how the player played. The ending is an authored,
   styled conclusion that names what the player's path brought about, and the
   player can begin again to seek a different one.

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
`godot --headless --quit-after 5 --path . -- --scenario ending_truth`.

A screenshot helper is available at `/workspace/tools/screenshot.sh`. Use it to
actually see what your title / dialogue / choice / ending screens look like.

```
/workspace/tools/screenshot.sh --path /workspace/game \
      -- --out /workspace/frame.png --frames 60
```

To screenshot a specific scenario, append `--scenario <id>` after `--`. The
helper consumes only `--out` / `--frames` / `--scene`; remaining args stay in
`OS.get_cmdline_user_args()` for your game code to read. Example:

```
/workspace/tools/screenshot.sh --path /workspace/game \
      -- --out /workspace/ending_debug.png --frames 120 --scenario ending_truth
```

## Demos

Ship **1–10 input-trace files** under `/workspace/game/demo_outputs/`, one per
demo, each named `*.json`. The evaluator launches a fresh game per trace,
replays your trace as synthetic mouse and keyboard input at 1280×720, and
records the screen. Only the first 10 traces by filename are evaluated;
recordings longer than 20 s are sampled from a random 20 s window.

### Scenarios

Normal play should start from the title screen and play through the story's
core loop of reading, choosing, and reaching an outcome. Demo playback must be
deterministic. For demos that need a specific state (a particular tale or
chapter, a key branching choice, or one of the divergent endings), define named
scenarios your game loads when launched with:

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
