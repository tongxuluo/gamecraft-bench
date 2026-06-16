# Task Annotation Guide

This document describes how to annotate a GameCraft-Bench task into a strict,
valid benchmark sample. Annotate in this order:

1. `task.toml`
2. `instruction.md`
3. `tests/rubric.json`

The final goal is to evaluate whether an agent can build a **complete,
shippable micro-game**, not a prototype, static UI mockup, or label-only
demo.

## 1. `task.toml`

`task.toml` is metadata and runtime configuration. Keep it boring.

Check:

- `[task].name` uses the final task slug, such as `gamecraft-bench/tycoon-farm`.
- `[task].description` is a short one-line summary of the task.
- `keywords` are optional broad tags; they do not replace the instruction.
- verifier, agent, and environment settings remain standard unless the task
  truly needs a different runtime budget.

Do not put gameplay requirements, demo rules, or rubric criteria in
`task.toml`. Those belong in `instruction.md` and `tests/rubric.json`.

## 2. `instruction.md`

`instruction.md` is the source of truth for what the agent must build. The
opening should immediately set the quality target, but it should read like a
game brief, not like a scoring checklist.

Use this opening shape:

```markdown
# Name

Build a Name in Godot 4 at `/workspace/game/`.
This is not a prototype. It is a **complete, shippable micro-game** that could
sit on an itch.io page or Steam as a polished vertical slice.

## Core Vision

## What the Player Experiences
```

`# Name` should be the task title.

The first paragraph should name the game and output path. Keep the
shippable-game sentence near the top so the agent understands the expected
finish level before reading feature details.

### Core Vision

`Core Vision` should explain the fantasy and core loop in prose.

It should answer:

- What is the player trying to do?
- What makes the game interesting?
- What decisions, pressure, risk, or mastery should exist?
- What should the game feel like as a polished vertical slice?

This section should stay abstract enough that a strong agent can make design
choices. It should not prescribe every screen, count every object, or list
rubric-style requirements. Describe the kind of game that should exist and
the quality bar it must meet.

Good:

> The player runs a small creature clinic under time pressure, reading symptoms,
> prioritizing urgent cases, and choosing treatments that visibly help or harm
> patients. The game should feel like a polished, readable triage challenge
> rather than a static management dashboard.

Too specific:

> Include four patients, four stations, a queue panel, a scanner button, a
> treatment button, a result screen, three upgrades, and two emergency cases.

### What the Player Experiences

`What the Player Experiences` should describe the player-facing arc at a
medium level of detail. It can mention the kinds of moments a good version
should include, but should not become a rubric or implementation checklist.

Good experience writing describes what the player notices and cares about:

- starting from an authored first screen
- learning the premise quickly
- making meaningful decisions in the main loop
- seeing consequences and feedback
- encountering escalation or variation
- reaching a satisfying success or failure state

Avoid exact counts unless the count is central to the task identity. For
example, prefer "a varied set of patients with different needs" over "exactly
four patient types." The rubric can later decide what amount of variety is
enough for full credit.

Avoid implementation-level commands such as "make a Button node at x/y" or
"create a panel named QueuePanel." The instruction should ask for a playable
game with state, feedback, and outcomes. The rubric should judge whether the
submission achieved that.

### Other Required Sections

After the early vision sections, the task can include standard sections for:

- assets
- project layout
- launch command
- demos
- scenarios
- trace file format

Demos must require deterministic input traces under
`/workspace/game/demo_outputs/`. Normal play should start from the title
screen unless a demo intentionally uses a named scenario.

Do not ask the game to satisfy audio requirements. The evaluator judges
sampled frames, so audio cannot be reliably assessed.

## 3. `tests/rubric.json`

The rubric turns the abstract instruction into concrete judgment criteria. It
should judge whether the completed game is a publishable vertical slice. It
should be strict: static screens, decorative UI, label-only systems, and
disconnected scenarios should not score highly.

Use four broad categories:

- Core Mechanics
- Content Depth
- Functional Visuals
- Presentation & Art

Recommended weights:

- Core Mechanics: 15-20%
- Content Depth: 30-35%
- Functional Visuals: 10-20%
- Presentation & Art: 30-35%

Keep the total item count at 24 or fewer. Harder tasks can use more items,
but do not split the rubric into many tiny categories.

Use prefixes consistently:

- `M*` for Core Mechanics
- `D*` for Content Depth
- `V*` for Functional Visuals
- `A*` for Presentation & Art

### Core Mechanics

Core Mechanics asks whether the irreducible gameplay loop works.

It should evaluate:

- player actions
- state changes
- rules and consequences
- correct versus incorrect choices
- pressure, risk, goal, or failure
- whether the loop can continue beyond one scripted moment

Do not put content quantity here. "There are four patient types" is not Core
Mechanics. That is Content Depth.

Good:

- "The player can diagnose a patient, choose a treatment station, and the
  chosen treatment visibly changes the patient's condition."

Bad:

- "There are four patient types."

### Content Depth

Content Depth asks whether the core loop has enough varied material.

It should evaluate:

- varied characters, enemies, patients, cards, tools, levels, maps, events, or
  upgrades
- whether variants behave differently, not just look different
- progression, escalation, late-game state, or multiple scenarios
- success/failure/result states

Content Depth should not give full credit for labels, colors, or names alone.

Good:

- "At least four patient conditions require distinct diagnosis clues and
  different treatment choices."

Bad:

- "The screen lists four patient names."

### Functional Visuals

Functional Visuals asks whether the player can understand and operate the
game during play. It is about readability and feedback, not art polish.

It should evaluate:

- selected target/unit/card/tool clarity
- readable stats, timers, health, resources, objectives, and warnings
- visible feedback after input
- whether success, failure, or state changes are clear in sampled frames
- no overlapping or unstable UI at 1280x720

Do not put content quantity here. "Four stations exist" is Content Depth.
"Station occupancy and selected station are readable" is Functional Visuals.

Do not put art style here. "Beautiful icons" is Presentation & Art. "Icons
communicate gameplay state clearly" is Functional Visuals.

Good:

- "Patient urgency, diagnosis clues, selected treatment station, station
  occupancy, and treatment result are readable without overlap."

Bad:

- "The clinic has cute art."

### Presentation & Art

Presentation & Art asks whether the game feels authored and publishable, not
like a debug prototype. The bar is **Steam / itch.io release quality** — a
screenshot should look like a real game someone would pay for, not a jam
prototype or a homework assignment.

It should evaluate:

- coherent visual style across title, gameplay, HUD, and results
- consistent assets, colors, typography, spacing, animation, and effects
- authored scene composition for the task theme
- polished menus, transitions, result screens, and UI hierarchy
- avoidance of default controls, raw rectangles, placeholder labels, and
  mismatched assets

Full credit means the game could ship on Steam as a polished vertical slice.
Score 0.5 at most if the game uses programmatic shapes (ColorRect, Polygon2D,
StyleBoxFlat, solid-color fills) as primary visual elements instead of real
illustrated or pixel-art assets. Score 0 if the screen is dominated by default
Godot widgets, untextured rectangles, or placeholder text.

### Scoring Calibration

The benchmark targets **Steam-level publishable games**. A score of 0.6+ should
mean the game is genuinely playable, visually polished, and content-complete
enough to release. Rubric descriptions must enforce this bar:

- **Score 1**: The feature is fully implemented with publishable quality. A
  player would not notice anything missing or placeholder.
- **Score 0.5**: The feature exists and functions, but uses placeholder art,
  minimal content, or lacks polish. It works but would not ship.
- **Score 0**: The feature is absent, broken, or purely decorative with no
  gameplay effect.

Every rubric item should include a cap condition. Common caps:

- "Score 0.5 at most if this uses programmatic shapes or solid-color fills
  instead of real sprite/texture assets."
- "Score 0.5 at most if this is only labels, text, or decorative elements
  with no gameplay consequence."
- "Score 0.5 at most if only one variant exists or variants differ only by
  color/name with identical behavior."
- "Score 0.5 at most if the feature is demonstrated only in a static scenario
  without sustained gameplay."

Content Depth items should not give full credit for quantity alone — variants
must behave differently, not just look different or have different names.

### Aggregation

Use `mean` when quality should hold across frames or demos:

- readability
- visual feedback
- art consistency
- UI overlap
- animation/presentation quality

Use `max` only when seeing the feature once is enough to prove it exists.
Be careful: too many `max` items make the rubric too easy, because a static
scenario can expose a feature once without proving the gameplay loop.

Strict rubric descriptions should cap weak evidence:

- "Score 0.5 at most if this uses programmatic shapes instead of real assets."
- "Score 0.5 at most if this is only labels or decorative with no gameplay effect."
- "Score 0.5 at most if variants differ only by color/name, not behavior."
- "Score 0.5 at most if demonstrated only in a static scenario, not sustained play."
- "Score 1 requires visible player action causing state change."
- "Score 1 requires real sprite/texture assets, not ColorRect or solid fills."

### Required Rubric Shape

Each rubric should contain:

- `score_formula`
- `max_demos`
- `max_demo_seconds`
- `build_check`
- `categories`
- `requirements`

Use this category structure:

```json
[
  {"name": "Core Mechanics", "items": ["M1", "M2", "M3", "M4"]},
  {"name": "Content Depth", "items": ["D1", "D2", "D3", "D4"]},
  {"name": "Functional Visuals", "items": ["V1", "V2", "V3", "V4"]},
  {"name": "Presentation & Art", "items": ["A1", "A2", "A3"]}
]
```

Item counts can vary by task, but the four category names and prefix meanings
should stay stable.

## Final Checklist

Before accepting a task sample:

- `task.toml` only contains metadata and runtime settings.
- `instruction.md` starts with the shippable micro-game quality bar.
- `instruction.md` defines a concrete Core Vision.
- `instruction.md` describes observable player experiences, not only UI
  components.
- demos require deterministic input traces.
- rubric uses the four category structure.
- Mechanics and Content Depth are not mixed.
- Functional Visuals checks readability and feedback, not art polish.
- Presentation & Art checks authored finish and style consistency.
- no rubric item evaluates audio.
- full credit requires visible player action, state change, consequences, and
  publishable vertical-slice quality.
- weak implementations are capped at 0.5 or below when they are label-only,
  decorative, static, disconnected, or debug-like.
