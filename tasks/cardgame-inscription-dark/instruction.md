# Cardgame Inscription Dark

Build a Cardgame Inscription Dark in Godot 4 at `/workspace/game/`.
This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

A dark and atmospheric card battle game where creatures are summoned by
sacrificing other creatures. The player places cards on a grid battlefield,
but powerful cards demand blood — weaker creatures must be sacrificed to fuel
stronger summons. Each card bears sigils (passive abilities) that create
emergent interactions: a card with "Airborne" flies over blockers; one with
"Bifurcated Strike" hits two lanes. An overworld map connects encounters with
branching paths, and a creeping meta-narrative unfolds through environmental
storytelling. The fantasy is the unsettling thrill of sacrificing your own
creatures for power, wrapped in a cabin-horror atmosphere.

## What the Player Experiences

1. **Title Screen** — A dimly lit wooden table with the game name scratched
   into the surface in rough lettering, a flickering candle, and a "Begin"
   card the player clicks. No plain Godot grey.
2. **The Table** — Battles take place on a 4-lane grid. The player's row faces
   the opponent's row. Cards are played from hand into lanes. Each card has
   attack power, health, a blood cost, and zero or more sigils.
3. **Sacrifice Mechanic** — To play a card costing 2 blood, the player must
   first sacrifice 2 of their own creatures already on the field. Sacrificed
   creatures die with a visual effect. Free cards (0 cost) serve as sacrifice
   fodder. This creates a constant tension between board presence and power.
4. **Sigils** — At least 8 distinct sigils with unique icons: Airborne (attacks
   directly), Bifurcated Strike (hits adjacent lanes too), Mighty Leap (blocks
   Airborne), Stinky (adjacent enemies lose 1 attack), Unkillable (returns to
   hand on death), Fledgling (evolves after 1 turn), Touch of Death (kills
   anything it damages), Many Lives (has 3 extra lives).
5. **Damage Scale** — A balance scale tips as damage is dealt. When one side
   takes 5 more total damage than the other, that side loses. The scale
   visually tips with each hit, creating tension as it approaches the tipping
   point.
6. **Overworld Map** — Between battles, a branching path map shows nodes:
   card battles, totem poles (add a sigil to a card), campfires (merge two
   cards), and traders (buy/sell cards). The player chooses their route.
7. **Atmosphere** — Dark, muted colour palette. Cards look hand-drawn on
   parchment. The opponent is a shadowy figure whose eyes glow. Ambient
   effects (dust motes, candle flicker) reinforce the unsettling mood.

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
