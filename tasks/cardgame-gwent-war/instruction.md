# Cardgame Gwent War

Build a Cardgame Gwent War in Godot 4 at `/workspace/game/`.
This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

A row-based card battle game where bluffing is as important as card strength.
Each player places unit cards into one of three combat rows (melee, ranged,
siege), and the side with the higher total strength at round's end wins. But
matches are best-of-three — winning a round early by dumping your hand leaves
you empty for the next. The core tension is knowing when to push and when to
pass, baiting the opponent into overcommitting. Multiple faction decks with
unique abilities and a campaign of escalating AI opponents provide depth. The
fantasy is the poker-face moment of passing with a slim lead, daring the
opponent to waste cards chasing it.

## What the Player Experiences

1. **Title Screen** — A medieval war-table aesthetic with the game name in
   iron-forged lettering, faction banners flanking the sides, and Campaign /
   Quick Match / Deck Builder buttons. No plain Godot grey.
2. **Deck Builder** — At least 3 factions (Northern Realms, Monsters, Elves)
   each with 15+ unique cards. The player builds a deck of exactly 25 cards
   from their chosen faction plus neutral cards. Each card shows art, strength
   value, row placement, and any special ability.
3. **The Board** — Three rows per side (melee/ranged/siege) displayed
   horizontally. Cards are played from hand into their designated row. Total
   strength per row and overall total are shown. The opponent's rows mirror
   above.
4. **Turn Structure** — Players alternate playing one card or passing. Once
   both pass, the round ends. The side with higher total strength wins the
   round. Best of 3 rounds wins the match. A round tracker shows current
   standing.
5. **Bluffing and Passing** — The player can pass at any time, locking in their
   current strength. The opponent must then decide whether to keep playing
   cards (wasting resources for future rounds) or also pass. This creates
   rich mind-game dynamics.
6. **Special Abilities** — Cards have abilities: Spy (played on opponent's side
   but draws 2 cards), Medic (resurrects a card from discard), Weather (reduces
   all cards in a row to 1 strength), Commander's Horn (doubles a row's
   strength), Decoy (returns a played card to hand). Each ability has a
   distinct visual effect.
7. **Campaign** — A series of AI opponents with increasing difficulty and
   unique deck strategies. Winning matches earns new cards for the player's
   collection. A world map shows progression through the campaign.

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
