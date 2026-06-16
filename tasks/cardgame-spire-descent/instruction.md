# Cardgame Spire Descent

Build a Cardgame Spire Descent in Godot 4 at `/workspace/game/`.
This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

A deckbuilder roguelike where the player ascends a spire floor by floor,
fighting enemies with a deck of cards that grows and evolves through drafting
choices. Each combat is a tactical puzzle: play attack cards to deal damage,
skill cards to gain block, and power cards for lasting buffs — all constrained
by a per-turn energy budget. Between fights, the player drafts new cards from
a reward selection, visits shops, and collects relics that bend the rules.
Three distinct character classes with different starting decks and card pools
ensure replayability. The fantasy is crafting a broken combo engine that
trivializes the final boss — if you survive long enough to assemble it.

## What the Player Experiences

1. **Title Screen** — A dark tower silhouette against a stormy sky with the
   game name in ornate fantasy lettering, and New Run / Continue buttons. No
   plain Godot grey.
2. **Class Select** — Three character classes (Warrior, Rogue, Mage) each with
   a unique portrait, starting deck description, and signature mechanic
   (Warrior: strength scaling; Rogue: shiv generation; Mage: orb channelling).
3. **Map Navigation** — A branching path map showing the current act. Nodes
   represent combat encounters, elite fights, shops, rest sites, and events.
   The player chooses their path through the act, balancing risk and reward.
4. **Card Combat** — Turn-based battles. The player draws 5 cards per turn,
   has 3 energy to spend, and plays cards to attack or defend. Enemies show
   their intent (attack amount, buff, debuff) so the player can plan. Health
   persists between fights.
5. **Card Rewards** — After combat, choose 1 of 3 cards to add to the deck.
   Cards have rarities (Common, Uncommon, Rare) with distinct border colours.
   The player can skip the reward to keep the deck lean.
6. **Relics** — Passive items that modify rules (e.g., "gain 1 energy per
   turn", "draw 2 extra cards on turn 1"). Relics display in a bar at the top
   of the screen with tooltip descriptions. Elite enemies always drop a relic.
7. **Three Acts** — The run spans 3 acts, each with a boss at the end. Bosses
   have unique mechanics and multi-phase patterns. Defeating the final boss
   wins the run with a victory screen showing stats.

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
