# Open-World Archaeology

Build a **2D open-world archaeology game** in Godot 4 at `/workspace/game/`:
an expedition across ancient ruins where the player excavates buried artefacts,
deciphers forgotten inscriptions, and reconstructs lost civilisations one dig
at a time.

This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

Unearth the past. The player is an archaeologist who travels to remote dig
sites, carefully removes layers of earth and stone, and discovers artefacts
that tell the story of vanished cultures. The fantasy is patient revelation:
each brush stroke peels back time, each shard connects to a larger picture, and
the deeper you dig the rarer and more fragile the finds become. One careless
swing of the pickaxe can shatter a legendary relic; one solved inscription can
unlock a hidden chamber no one has entered in millennia.

The pressure comes from the sites themselves. Sandstorms bury progress, floors
collapse underfoot, oxygen runs thin in flooded passages. The player must read
the terrain, choose the right tool, and decide when to push deeper versus when
to retreat and catalogue what they have. A growing museum back at base camp
makes every expedition feel worthwhile -- each new display fills in a gap in
the timeline and unlocks access to the next frontier.

## What the Player Experiences

1. **Title and Entry** -- The player arrives at a styled title screen that
   establishes the mysterious, ancient tone -- torchlit stone, weathered maps,
   sand drifting across glyphs. Starting an expedition drops them into the
   overworld.

2. **Exploration** -- The world stretches across multiple biomes, each hiding
   its own dig sites. Desert temples shimmer under a scorching sun, jungle ruins
   drip with moss and vine, sunken pillars glow beneath turquoise water, and
   mountain tombs sit locked in ice. Walking between sites feels like a journey
   -- the terrain changes, the palette shifts, the ambient mood transforms.

3. **Excavation** -- At a dig site the player switches between tools -- a
   delicate brush for fragile surfaces, a trowel for packed earth, a pickaxe
   for solid rock. Each tool removes material at a different speed and risk.
   Layers peel away visually, revealing colour changes and texture shifts as
   depth increases, until an artefact edge glimmers into view.

4. **Discovery and Cataloguing** -- Unearthed artefacts range from common
   pottery shards to legendary golden idols. Each has a distinct look, a rarity
   tier, and a short historical description. Rare finds are buried deeper and
   demand more careful tool selection. The player feels the thrill of not
   knowing what lies beneath the next layer.

5. **Puzzles and Secrets** -- Some sites hide inscribed tablets or symbol murals
   that gate access to sealed chambers. The player manipulates symbols -- matching,
   rotating, tracing -- until the lock yields and a passage opens with a
   satisfying rumble. Inside waits a guaranteed rare artefact or a new wing of
   ruins to explore.

6. **Museum and Progression** -- Back at base camp, a museum tent displays
   every collected artefact on labelled shelves. Arranging finds by culture or
   era earns research points that unlock improved tools and new dig sites on the
   map. The museum grows from empty shelves to a rich gallery, charting the
   player's journey through history.

7. **Hazards and Tension** -- Each biome threatens the player differently:
   sandstorms obscure vision, jungle floors collapse, underwater oxygen depletes,
   mountain ice triggers avalanches. The player watches a health or safety gauge,
   decides whether to press on or retreat, and scavenges safety gear to push
   further next time.

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
