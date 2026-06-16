#!/bin/bash
# Reference solution for gamecraft-bench/visualnovel-grimfable.
#
# A compact dark-fairytale branching visual novel. ORIGINAL prose (no copied
# text) that subverts familiar storybook openings. Structure:
#   - Title -> story -> branching dialogue with choices -> one of 3 endings.
#   - A dialogue/narration system the player advances (SPACE / click / ENTER),
#     with a framed dialogue box and a named speaker.
#   - Examinable scene hotspots that reveal clues and record discoveries.
#   - Choices at key beats; selecting one branches the next content.
#   - Persistent state variables: `trust` and `truth` (collected truths),
#     carried across scenes; a LATER beat depends on an EARLIER choice or
#     examined clue (the cottage finale checks what the player discovered).
#   - Two recognizable tales/characters (a woodland "Grandmother" tale and a
#     "Sweet House" tale) with distinct dilemmas.
#   - Three distinct endings: ESCAPE, GRIM RECKONING, HIDDEN TRUTH.
#   - Scenarios jump to specific beats / endings for deterministic demos.
#
# It is the oracle for the verifier framework, not a polished game: backgrounds
# and characters are drawn from primitives, so the art items (A1-A4) stay low
# while mechanic/content items pass.
#
# NOTE (GDScript, warnings-as-errors): min()/Dictionary subscripts/JSON return
# Variant; every such value is given an explicit type to avoid the
# "inferred Variant" parse error that fails the whole script.
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="GrimFable"
run/main_scene="res://scenes/Main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
EOF

cat > "$GAME/scenes/Main.tscn" <<'EOF'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/Main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
EOF

cat > "$GAME/scripts/Main.gd" <<'GDSCRIPT'
extends Node2D

const VIEW := Vector2(1280, 720)

# Each story node: speaker, text, background tint, optional choices.
# A node is either a "line" (advance to `next`) or a "choice" (options).
# Choices carry effects on state and a target node id.
var nodes := {
    "start": {
        "bg": "wood", "speaker": "Narrator",
        "text": "You know this tale. A red hood, a path through the trees, a grandmother waiting at the end. You have walked it a hundred bedtimes. Tonight the wood is darker, and the path forks where it never forked before.",
        "next": "wood1",
    },
    "wood1": {
        "bg": "wood", "speaker": "The Wolf",
        "text": "A grey shape keeps pace beside you, polite as a gentleman. 'Going to grandmother's?' it asks. 'Mind the shortcut. The flowers are sweeter, but the old road is safer. Which will it be?'",
        "choice": [
            {"label": "Take the flower shortcut (trust the wolf)", "trust": 1, "to": "wood_short"},
            {"label": "Keep to the old safe road", "trust": -1, "to": "wood_safe"},
            {"label": "Ask why a wolf would help you", "truth": "wolf_motive", "to": "wood_ask"},
        ],
    },
    "wood_short": {
        "bg": "wood", "speaker": "Narrator",
        "text": "You gather flowers while the grey shape lopes ahead. By the time you reach the cottage the door already hangs open, and something inside is wearing your grandmother's shawl.",
        "next": "cottage1",
    },
    "wood_safe": {
        "bg": "wood", "speaker": "Narrator",
        "text": "You keep to the rutted road. You arrive first. The cottage is quiet, the kettle cold, and your grandmother's bed is already turned down as if she expected a different guest.",
        "next": "cottage1",
    },
    "wood_ask": {
        "bg": "wood", "speaker": "The Wolf",
        "text": "The wolf's smile falters. 'Because the woodsman is not the hero you were told,' it says. 'Ask your grandmother who taught him to skin what he kills.' It melts into the trees, and a truth settles cold in your chest.",
        "next": "cottage1",
    },
    "cottage1": {
        "bg": "cottage", "speaker": "Grandmother",
        "text": "The figure in the bed beckons. 'Come closer, child.' The voice is almost right. Look closely before you answer — examine the room (click the marked spots), then choose.",
        "hotspots": [
            {"rect": Rect2(470, 300, 90, 70), "truth": "wet_knife",
             "reveal": "A woodsman's hunting knife lies on the table, the blade still wet. This was used moments ago — and not on bread."},
            {"rect": Rect2(600, 300, 80, 70), "truth": "grandma_specs",
             "reveal": "Your grandmother's spectacles, neatly folded. She never took them off while she was awake. Someone laid them here."},
            {"rect": Rect2(96, 424, 92, 92), "truth": "wrong_eyes",
             "reveal": "Under the shawl, the eyes are too yellow, the smile too wide. Whatever wears your grandmother's face is not your grandmother."},
        ],
        "choice": [
            {"label": "Embrace 'grandmother'", "to": "end_branch"},
            {"label": "Pick up the knife", "trust": -1, "to": "end_branch"},
            {"label": "Name the truth the wolf told you", "to": "end_branch"},
        ],
    },
    # end_branch is resolved in code (depends on earlier `truth`/`trust`).
    "sweethouse": {
        "bg": "candy", "speaker": "Narrator",
        "text": "Another bedtime, another tale: a house of sugar in a starving wood, and two children with breadcrumbs in their pockets. You have read how this ends. The oven. The old woman. But the children look very well fed, and the old woman looks afraid.",
        "next": "end_truth",
    },
}

const ENDINGS := {
    "escape": {"title": "AN ESCAPE", "bg": "wood",
        "text": "You trusted nothing and no one, and you walked out of the tale alive — but the wood keeps the people you left inside it. Some stories you survive only by refusing to finish them."},
    "reckoning": {"title": "A GRIM RECKONING", "bg": "cottage",
        "text": "Steel for steel. The thing in the shawl falls, and so does the woodsman when he comes for his knife. You are the last one standing in a story that was never meant to have a winner."},
    "truth": {"title": "THE HIDDEN TRUTH", "bg": "candy",
        "text": "The wolf did not lie. The woodsman fed this wood for years, and the sugar house was a trap built by the saved, not the lost. You close the book knowing the villain's name was on the cover all along."},
}

var scenario := ""
var mode := "title"          # title, story, ending
var cur := "start"
var line_t := 0.0            # text reveal timer
var trust := 0               # state variable
var truths: Array = []       # collected truth flags (state variable)
var ending_id := "escape"
var msg := ""
var anim := 0.0
var reveal_text := ""        # clue overlay shown after examining a hotspot
var examined: Array = []     # hotspot truths already examined (no double-count)

func _ready() -> void:
    _parse_args()
    if scenario != "":
        _load_scenario(scenario)
    queue_redraw()

func _parse_args() -> void:
    var args := OS.get_cmdline_user_args()
    var i := 0
    while i < args.size():
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]
            i += 2
        else:
            i += 1

func _load_scenario(id: String) -> void:
    if id == "title_flow":
        mode = "title"
    elif id == "woods":
        mode = "story"; cur = "wood1"; line_t = 0.0
    elif id == "cottage":
        mode = "story"; cur = "cottage1"; truths = ["wolf_motive"]; trust = 1; line_t = 0.0
    elif id == "sweethouse":
        mode = "story"; cur = "sweethouse"; line_t = 0.0
    elif id == "ending_truth":
        truths = ["wolf_motive"]; _go_ending("truth")
    elif id == "ending_reckoning":
        trust = -2; _go_ending("reckoning")
    else:
        mode = "story"; cur = "start"; line_t = 0.0

func _begin_new() -> void:
    mode = "story"; cur = "start"; trust = 0; truths = []; line_t = 0.0
    msg = ""
    reveal_text = ""
    examined = []

# --------------------------------------------------------------------------
# Progression
# --------------------------------------------------------------------------

func _cur_node() -> Dictionary:
    var n: Dictionary = nodes.get(cur, {})
    return n

func _is_choice() -> bool:
    return _cur_node().has("choice")

func _advance() -> void:
    # Advance a plain line; reveal text fully first, then move on.
    var n: Dictionary = _cur_node()
    if _is_choice():
        return
    if line_t < 1.0:
        line_t = 1.0
        queue_redraw()
        return
    var nxt: String = str(n.get("next", ""))
    if nxt == "end_truth":
        # Sweet House tale resolves into the hidden-truth ending.
        ending_id = "truth"
        _go_ending("truth")
        return
    if nxt == "":
        _go_ending("escape")
        return
    cur = nxt
    line_t = 0.0
    queue_redraw()

func _pick(idx: int) -> void:
    var n: Dictionary = _cur_node()
    if not n.has("choice"):
        return
    var opts: Array = n["choice"]
    if idx < 0 or idx >= opts.size():
        return
    var opt: Dictionary = opts[idx]
    if opt.has("trust"):
        trust += int(opt["trust"])
    if opt.has("truth"):
        truths.append(str(opt["truth"]))
    var to: String = str(opt.get("to", ""))
    if to == "end_branch":
        _resolve_finale(idx)
        return
    cur = to
    line_t = 0.0
    queue_redraw()

func _examine(h: Dictionary) -> void:
    # Examining a hotspot reveals a clue and records it into the player's
    # gathered truths (state). A later beat (the finale) checks these.
    reveal_text = str(h["reveal"])
    var flag: String = str(h["truth"])
    if not examined.has(flag):
        examined.append(flag)
        truths.append(flag)
    queue_redraw()

func _resolve_finale(choice_idx: int) -> void:
    # LATER beat depends on EARLIER discoveries: naming the truth only lands
    # if the player actually uncovered it — either by learning the wolf's
    # motive in the woods, or by examining the room's clues here. A player who
    # rushed past without looking cannot reach the hidden-truth ending.
    var knows_truth := truths.has("wolf_motive") or truths.has("wrong_eyes") or truths.has("wet_knife")
    if choice_idx == 2 and knows_truth:
        _go_ending("truth")
    elif choice_idx == 2 and not knows_truth:
        # tried to name a truth they never found — it rings hollow.
        _go_ending("escape")
    elif choice_idx == 1 or trust < 0:
        _go_ending("reckoning")
    else:
        _go_ending("escape")

func _go_ending(id: String) -> void:
    ending_id = id
    mode = "ending"
    line_t = 0.0
    anim = 0.0
    queue_redraw()

# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _bg_color(tag: String) -> Color:
    match tag:
        "wood": return Color(0.10, 0.14, 0.12)
        "cottage": return Color(0.16, 0.12, 0.10)
        "candy": return Color(0.18, 0.10, 0.16)
    return Color(0.08, 0.08, 0.10)

func _draw() -> void:
    match mode:
        "title": _draw_title()
        "story": _draw_story()
        "ending": _draw_ending()

func _panel(rect: Rect2, color := Color(0.05, 0.05, 0.07, 0.92)) -> void:
    draw_rect(rect, color)
    draw_rect(rect, Color(0.55, 0.45, 0.30, 0.95), false, 2.0)

func _text(s: String, p: Vector2, size: int, color: Color) -> void:
    draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _wrap(s: String, rect: Rect2, size: int, color: Color) -> void:
    draw_multiline_string(ThemeDB.fallback_font, rect.position, s, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, size, -1, color)

func _button(rect: Rect2, label: String, hot := false) -> void:
    draw_rect(rect, Color(0.14, 0.12, 0.10) if not hot else Color(0.24, 0.18, 0.12))
    draw_rect(rect, Color(0.70, 0.56, 0.34), false, 2.0)
    _text(label, rect.position + Vector2(16, rect.size.y * 0.64), 18, Color(0.92, 0.86, 0.72))

func _scene_bg(tag: String) -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), _bg_color(tag))
    # crude illustrated backdrop: trees / cottage / candy silhouettes
    if tag == "wood":
        for i in range(9):
            var x := 60.0 + float(i) * 140.0
            draw_rect(Rect2(x, 180, 34, 360), Color(0.06, 0.10, 0.07))
            draw_circle(Vector2(x + 17, 180), 60, Color(0.09, 0.16, 0.10))
    elif tag == "cottage":
        draw_rect(Rect2(440, 250, 400, 280), Color(0.22, 0.16, 0.12))
        draw_polygon(PackedVector2Array([Vector2(420,250),Vector2(860,250),Vector2(640,140)]), PackedColorArray([Color(0.30,0.12,0.10),Color(0.30,0.12,0.10),Color(0.30,0.12,0.10)]))
        draw_rect(Rect2(600, 380, 80, 150), Color(0.10, 0.07, 0.05))
    elif tag == "candy":
        draw_rect(Rect2(470, 270, 360, 250), Color(0.40, 0.22, 0.30))
        for i in range(5):
            draw_circle(Vector2(520.0 + i * 70.0, 300.0), 18, Color(0.85, 0.55, 0.70))
    # a vignette
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, 0.12))

func _draw_title() -> void:
    _scene_bg("wood")
    _panel(Rect2(300, 150, 680, 360))
    _text("GRIM FABLE", Vector2(430, 250), 64, Color(0.85, 0.30, 0.30))
    _text("Every story you know was told to keep you from the truth.", Vector2(350, 312), 20, Color(0.82, 0.78, 0.70))
    _button(Rect2(500, 410, 280, 64), "OPEN THE BOOK")

func _draw_char(speaker: String) -> void:
    # simple character token left of the dialogue box
    var col := Color(0.6, 0.6, 0.65)
    if speaker == "The Wolf": col = Color(0.5, 0.52, 0.58)
    elif speaker == "Grandmother": col = Color(0.7, 0.5, 0.55)
    draw_circle(Vector2(130, 470), 46, col)
    draw_circle(Vector2(130, 452), 20, Color(0.9, 0.85, 0.8))

func _draw_story() -> void:
    var n: Dictionary = _cur_node()
    _scene_bg(str(n.get("bg", "wood")))
    _draw_char(str(n.get("speaker", "")))
    # dialogue box
    _panel(Rect2(40, 540, 1200, 150))
    # name plate
    _panel(Rect2(60, 512, 260, 40), Color(0.30, 0.10, 0.10, 0.95))
    _text(str(n.get("speaker", "")), Vector2(76, 540), 20, Color(0.95, 0.82, 0.55))
    # progressive text reveal
    var full: String = str(n.get("text", ""))
    var shown := full
    if line_t < 1.0:
        var cnt := int(float(full.length()) * line_t)
        shown = full.substr(0, cnt)
    _wrap(shown, Rect2(72, 556, 1140, 120), 20, Color(0.92, 0.90, 0.84))
    # examinable hotspots — marked spots the player can click to uncover clues
    if n.has("hotspots") and line_t >= 1.0:
        var hs: Array = n["hotspots"]
        for h in hs:
            var hr: Rect2 = h["rect"]
            var seen := examined.has(str(h["truth"]))
            var ring := Color(0.55, 0.85, 0.55, 0.85) if not seen else Color(0.45, 0.45, 0.40, 0.6)
            draw_rect(hr, Color(ring.r, ring.g, ring.b, 0.10))
            draw_rect(hr, ring, false, 2.0)
            draw_circle(hr.position + Vector2(hr.size.x - 12, 12), 7, ring)
            _text("?" if not seen else "✓", hr.position + Vector2(hr.size.x - 16, 17), 14, Color(0.05, 0.08, 0.05))
        _text("Examine the marked spots, then choose below.", Vector2(72, 230), 17, Color(0.7, 0.85, 0.65))
    # choices
    if _is_choice() and line_t >= 1.0:
        var opts: Array = n["choice"]
        for i in range(opts.size()):
            var o: Dictionary = opts[i]
            _button(Rect2(120, 256 + i * 64, 1040, 52), "%d. %s" % [i + 1, str(o["label"])])
    elif not _is_choice():
        _text("> click / SPACE to continue", Vector2(1000, 700), 15, Color(0.7, 0.7, 0.6))
    # tiny state readout (design exposes the stakes)
    _panel(Rect2(1040, 16, 224, 56))
    _text("Trust %d   Clues %d" % [trust, truths.size()], Vector2(1056, 50), 18, Color(0.8, 0.86, 0.7))
    # clue reveal overlay (shown after examining a hotspot)
    if reveal_text != "":
        draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, 0.5))
        _panel(Rect2(280, 250, 720, 200), Color(0.06, 0.07, 0.05, 0.96))
        _text("A CLUE", Vector2(320, 300), 26, Color(0.6, 0.9, 0.55))
        _wrap(reveal_text, Rect2(320, 326, 640, 110), 20, Color(0.92, 0.92, 0.84))
        _button(Rect2(560, 408, 160, 40), "Note it")

func _draw_ending() -> void:
    var e: Dictionary = ENDINGS[ending_id]
    _scene_bg(str(e["bg"]))
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, 0.45))
    _panel(Rect2(220, 180, 840, 360))
    _text(str(e["title"]), Vector2(280, 260), 52, Color(0.90, 0.40, 0.40))
    _wrap(str(e["text"]), Rect2(280, 300, 720, 160), 22, Color(0.90, 0.86, 0.78))
    _button(Rect2(420, 470, 200, 54), "READ AGAIN")
    _button(Rect2(660, 470, 200, 54), "CLOSE BOOK")

# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if mode == "story":
            if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
                _advance()
            elif event.keycode == KEY_1: _pick(0)
            elif event.keycode == KEY_2: _pick(1)
            elif event.keycode == KEY_3: _pick(2)
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _click(event.position)

func _click(p: Vector2) -> void:
    if mode == "title":
        if Rect2(500, 410, 280, 64).has_point(p):
            _begin_new()
            queue_redraw()
    elif mode == "story":
        # 1. dismiss an open clue overlay first.
        if reveal_text != "":
            reveal_text = ""
            queue_redraw()
            return
        var n: Dictionary = _cur_node()
        # 2. examine a hotspot if one was clicked.
        if n.has("hotspots") and line_t >= 1.0:
            var hs: Array = n["hotspots"]
            for h in hs:
                var hr: Rect2 = h["rect"]
                if hr.has_point(p):
                    _examine(h)
                    return
        # 3. choices.
        if _is_choice() and line_t >= 1.0:
            var opts: Array = n["choice"]
            for i in range(opts.size()):
                if Rect2(120, 256 + i * 64, 1040, 52).has_point(p):
                    _pick(i)
                    return
        else:
            _advance()
    elif mode == "ending":
        if Rect2(420, 470, 200, 54).has_point(p):
            _begin_new()
            queue_redraw()
        elif Rect2(660, 470, 200, 54).has_point(p):
            mode = "title"
            queue_redraw()

func _process(delta: float) -> void:
    anim += delta
    if mode == "story" and line_t < 1.0:
        line_t = min(1.0, line_t + delta * 1.6)  # progressive text reveal
        queue_redraw()
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_open.json" <<'EOF'
{
  "duration_frames": 380,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 640, "y": 442},
    {"frame": 120, "type": "key_press", "keycode": "SPACE"},
    {"frame": 200, "type": "key_press", "keycode": "SPACE"},
    {"frame": 300, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_woods_choice.json" <<'EOF'
{
  "scenario": "woods",
  "duration_frames": 420,
  "events": [
    {"frame": 60,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 140, "type": "key_press", "keycode": "3"},
    {"frame": 240, "type": "key_press", "keycode": "SPACE"},
    {"frame": 380, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_cottage_branch.json" <<'EOF'
{
  "scenario": "cottage",
  "duration_frames": 500,
  "events": [
    {"frame": 50,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 110, "type": "mouse_click", "button": "left", "x": 515, "y": 335},
    {"frame": 180, "type": "mouse_click", "button": "left", "x": 640, "y": 446},
    {"frame": 240, "type": "mouse_click", "button": "left", "x": 142, "y": 470},
    {"frame": 300, "type": "mouse_click", "button": "left", "x": 640, "y": 446},
    {"frame": 360, "type": "key_press", "keycode": "3"},
    {"frame": 460, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_ending_truth.json" <<'EOF'
{
  "scenario": "ending_truth",
  "duration_frames": 320,
  "events": [
    {"frame": 60,  "type": "wait"},
    {"frame": 200, "type": "mouse_click", "button": "left", "x": 520, "y": 497},
    {"frame": 300, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/05_ending_reckoning.json" <<'EOF'
{
  "scenario": "ending_reckoning",
  "duration_frames": 300,
  "events": [
    {"frame": 60,  "type": "wait"},
    {"frame": 240, "type": "wait"}
  ]
}
EOF

echo "grimfable oracle generated at $GAME"
