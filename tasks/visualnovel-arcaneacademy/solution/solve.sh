#!/bin/bash
# Reference solution for gamecraft-bench/visualnovel-arcaneacademy.
#
# A compact magic-academy stat-raising visual novel. ORIGINAL prose. Structure:
#   - Title -> term -> alternate TRAINING and STORY beats -> one of 3 endings.
#   - Training: spend limited Action Points to raise one of four disciplines
#     (Elemental, Runecraft, Alchemy, Forbidden). Each train costs 1 AP and
#     raises that stat; out of AP ends planning for the beat.
#   - Stats are persistent and gate content: story choices and the finale check
#     thresholds (a high Forbidden stat unlocks a dark option/ending; high
#     Runecraft unlocks the honored path).
#   - Story beats with real choices between training rounds (a rival duel, a
#     mentor's offer / forbidden temptation).
#   - Three endings: ARCHMAGE'S FAVOR, FALLEN TO THE FORBIDDEN, EXPELLED.
#   - Scenarios jump to specific states/endings for deterministic demos.
#
# Oracle for the verifier framework, not a polished game: drawn from primitives,
# so the art items (A1-A4) stay low while mechanic/content items pass.
#
# NOTE (GDScript warnings-as-errors): min()/max()/Dictionary subscripts/JSON
# return Variant; each such value is given an explicit type to avoid the
# "inferred Variant" parse error that fails the whole script.
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="ArcaneAcademy"
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
const DISCIPLINES := ["Elemental", "Runecraft", "Alchemy", "Forbidden"]
const AP_PER_TERM := 3
const TERMS := 3

# Persistent stats (state variables).
var stats := {"Elemental": 0, "Runecraft": 0, "Alchemy": 0, "Forbidden": 0}
var term := 1
var ap := AP_PER_TERM
var scenario := ""
var mode := "title"          # title, train, story, ending
var line_t := 0.0
var msg := ""
var anim := 0.0
var ending_id := "expelled"

# Story beats keyed by term. Each: speaker/text and choices that branch and
# can require a stat threshold.
var beats := {
    1: {
        "bg": "hall", "speaker": "Rival — Cassia",
        "text": "Cassia blocks the corridor, sparks dancing on her knuckles. 'They say the new student is all talk. Duel me, or admit it.' How you answer depends on what you have made of yourself this term.",
        "choice": [
            {"label": "Answer with elemental fire", "req": "Elemental", "need": 2,
             "ok": "Your flame answers hers and holds. Cassia steps back, reassessing. Respect, grudging and real.",
             "fail": "Your spark gutters out. Cassia laughs. The corridor remembers it.", "stat": "Elemental"},
            {"label": "Bind her spell with a rune", "req": "Runecraft", "need": 2,
             "ok": "You trace a sigil and her fire folds into nothing. A mentor watching nods, unseen.",
             "fail": "Your rune smears and breaks. She walks through it like smoke.", "stat": "Runecraft"},
            {"label": "Refuse the duel and walk on", "req": "", "need": 0,
             "ok": "You step around her. Some call it wisdom, some cowardice. The term will decide which.", "stat": ""},
        ],
    },
    2: {
        "bg": "library", "speaker": "Archivist Vohl",
        "text": "In the restricted stacks, Vohl slides a black-spined book toward you. 'The forbidden arts are not evil,' he murmurs. 'Only honest about the price. Will you read?'",
        "choice": [
            {"label": "Open the forbidden book", "req": "", "need": 0,
             "ok": "Ink crawls off the page into your eyes. You understand things you cannot unlearn. (Forbidden rises.)", "stat": "Forbidden", "gain": 2},
            {"label": "Decline and report him", "req": "Runecraft", "need": 1,
             "ok": "You note the sigils on the shelf and bring them to the Dean. Vohl vanishes by morning. You are trusted.", "stat": "Runecraft"},
            {"label": "Decline, quietly", "req": "", "need": 0,
             "ok": "You shake your head and leave. The book watches you go.", "stat": ""},
        ],
    },
}

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
    elif id == "train":
        _new_term(); mode = "train"
    elif id == "story_rival":
        _new_term(); stats["Elemental"] = 3; mode = "story"; term = 1; line_t = 0.0
    elif id == "story_forbidden":
        _new_term(); mode = "story"; term = 2; line_t = 0.0
    elif id == "ending_archmage":
        stats = {"Elemental": 2, "Runecraft": 4, "Alchemy": 1, "Forbidden": 0}; _go_ending()
    elif id == "ending_fallen":
        stats = {"Elemental": 1, "Runecraft": 0, "Alchemy": 1, "Forbidden": 5}; _go_ending()
    else:
        _new_term(); mode = "train"

func _new_term() -> void:
    stats = {"Elemental": 0, "Runecraft": 0, "Alchemy": 0, "Forbidden": 0}
    term = 1
    ap = AP_PER_TERM
    msg = "Spend your time. Train a discipline (1-4). Each costs 1 hour."

func _begin_new() -> void:
    _new_term()
    mode = "train"

# --------------------------------------------------------------------------
# Training (stat raising)
# --------------------------------------------------------------------------

func _train(idx: int) -> void:
    if mode != "train":
        return
    if ap <= 0:
        msg = "No hours left this term. The lesson moves on."
        queue_redraw()
        return
    if idx < 0 or idx >= DISCIPLINES.size():
        return
    var d: String = DISCIPLINES[idx]
    stats[d] = int(stats[d]) + 1
    ap -= 1
    msg = "You study %s. (%s now %d)  Hours left: %d" % [d, d, stats[d], ap]
    if ap <= 0:
        msg = "The term's hours are spent. Press SPACE for what comes next."
    queue_redraw()

func _finish_training() -> void:
    # Move from planning into this term's story beat.
    if beats.has(term):
        mode = "story"
        line_t = 0.0
    else:
        _resolve_term()
    queue_redraw()

func _resolve_term() -> void:
    if term >= TERMS:
        _decide_ending()
    else:
        term += 1
        ap = AP_PER_TERM
        mode = "train"
        msg = "A new term. Train again (1-4)."
    queue_redraw()

# --------------------------------------------------------------------------
# Story beats + choices (gated by stats)
# --------------------------------------------------------------------------

func _cur_beat() -> Dictionary:
    var b: Dictionary = beats.get(term, {})
    return b

func _pick(idx: int) -> void:
    if mode != "story":
        return
    var b: Dictionary = _cur_beat()
    if not b.has("choice"):
        return
    var opts: Array = b["choice"]
    if idx < 0 or idx >= opts.size():
        return
    var o: Dictionary = opts[idx]
    var req: String = str(o.get("req", ""))
    var passed := true
    if req != "":
        passed = int(stats.get(req, 0)) >= int(o.get("need", 0))
    # Apply stat gain (e.g. reading the forbidden book).
    if o.has("gain") and str(o.get("stat", "")) != "":
        var s: String = str(o["stat"])
        stats[s] = int(stats[s]) + int(o["gain"])
    msg = str(o["ok"]) if passed else str(o.get("fail", o["ok"]))
    line_t = 0.0
    mode = "result"
    queue_redraw()

func _continue_after_result() -> void:
    _resolve_term()

func _decide_ending() -> void:
    _go_ending()

func _go_ending() -> void:
    var forb: int = int(stats["Forbidden"])
    var rune: int = int(stats["Runecraft"])
    if forb >= 4:
        ending_id = "fallen"
    elif rune >= 3 or int(stats["Elemental"]) >= 3:
        ending_id = "archmage"
    else:
        ending_id = "expelled"
    mode = "ending"
    line_t = 0.0
    queue_redraw()

func _ending_data() -> Dictionary:
    match ending_id:
        "archmage":
            return {"title": "THE ARCHMAGE'S FAVOR", "bg": "hall",
                "text": "You walk the graduation hall with your head high. Discipline and craft earned you the Archmage's own sigil-ring. The forbidden door stayed shut, and the school will remember your name kindly."}
        "fallen":
            return {"title": "FALLEN TO THE FORBIDDEN", "bg": "library",
                "text": "Power, yes — and a price you paid in pieces of yourself. They strike your name from the rolls and seal the stacks behind you. The dark you learned does not let go of what it teaches."}
        _:
            return {"title": "EXPELLED IN DISGRACE", "bg": "hall",
                "text": "You drifted, mastered nothing, and the term ran out before you became anyone at all. The Dean's letter is short. Some students the academy simply forgets."}

# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _bg_color(tag: String) -> Color:
    match tag:
        "hall": return Color(0.12, 0.12, 0.20)
        "library": return Color(0.14, 0.11, 0.08)
        "classroom": return Color(0.10, 0.16, 0.16)
    return Color(0.10, 0.10, 0.16)

func _draw() -> void:
    match mode:
        "title": _draw_title()
        "train": _draw_train()
        "story": _draw_story()
        "result": _draw_result()
        "ending": _draw_ending()

func _panel(rect: Rect2, color := Color(0.06, 0.06, 0.10, 0.93)) -> void:
    draw_rect(rect, color)
    draw_rect(rect, Color(0.45, 0.42, 0.70, 0.95), false, 2.0)

func _text(s: String, p: Vector2, size: int, color: Color) -> void:
    draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _wrap(s: String, rect: Rect2, size: int, color: Color) -> void:
    draw_multiline_string(ThemeDB.fallback_font, rect.position, s, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, size, -1, color)

func _button(rect: Rect2, label: String) -> void:
    draw_rect(rect, Color(0.14, 0.13, 0.20))
    draw_rect(rect, Color(0.55, 0.50, 0.80), false, 2.0)
    _text(label, rect.position + Vector2(16, rect.size.y * 0.64), 18, Color(0.90, 0.88, 0.96))

func _scene_bg(tag: String) -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), _bg_color(tag))
    # crude arched-window backdrop
    for i in range(5):
        var x := 120.0 + float(i) * 220.0
        draw_rect(Rect2(x, 90, 120, 280), Color(0.16, 0.16, 0.26))
        draw_circle(Vector2(x + 60, 90), 60, Color(0.16, 0.16, 0.26))
        draw_rect(Rect2(x + 56, 110, 8, 240), Color(0.08, 0.08, 0.14))
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, 0.12))

func _draw_statbar() -> void:
    _panel(Rect2(960, 14, 306, 168))
    _text("YOUR STUDIES", Vector2(978, 42), 18, Color(0.80, 0.78, 0.95))
    for i in range(DISCIPLINES.size()):
        var d: String = DISCIPLINES[i]
        var y := 58 + i * 28
        _text("%d %s" % [i + 1, d], Vector2(978, y + 18), 16, Color(0.85, 0.84, 0.92))
        var v: int = int(stats[d])
        for k in range(5):
            var on := k < v
            var col := Color(0.6, 0.55, 0.9) if on else Color(0.2, 0.2, 0.28)
            if d == "Forbidden" and on: col = Color(0.8, 0.3, 0.5)
            draw_rect(Rect2(1140 + k * 22, y + 6, 18, 14), col)
    _text("Hours left: %d   Term %d/%d" % [ap, term, TERMS], Vector2(978, 172), 15, Color(0.9, 0.86, 0.6))

func _draw_title() -> void:
    _scene_bg("hall")
    _panel(Rect2(300, 150, 680, 360))
    _text("ARCANE ACADEMY", Vector2(360, 250), 56, Color(0.70, 0.62, 0.95))
    _text("One term. Too little time. Become someone before it ends.", Vector2(355, 312), 20, Color(0.82, 0.80, 0.92))
    _button(Rect2(500, 410, 280, 64), "ENROL")

func _draw_train() -> void:
    _scene_bg("classroom")
    _draw_statbar()
    _panel(Rect2(40, 200, 880, 300))
    _text("PLAN YOUR TERM", Vector2(70, 250), 30, Color(0.82, 0.80, 0.96))
    _text("Spend each hour on a discipline. Choose what kind of mage to become.", Vector2(70, 290), 18, Color(0.8, 0.82, 0.9))
    for i in range(DISCIPLINES.size()):
        _button(Rect2(70 + (i % 2) * 420, 320 + (i / 2) * 70, 400, 54), "%d. Study %s" % [i + 1, DISCIPLINES[i]])
    _panel(Rect2(40, 520, 1200, 150))
    _wrap(msg, Rect2(64, 552, 1150, 110), 20, Color(0.9, 0.9, 0.84))
    _text("> SPACE when your hours are spent", Vector2(980, 700), 15, Color(0.7, 0.7, 0.8))

func _draw_story() -> void:
    var b: Dictionary = _cur_beat()
    _scene_bg(str(b.get("bg", "hall")))
    _draw_statbar()
    _panel(Rect2(40, 520, 1200, 170))
    _panel(Rect2(60, 492, 300, 40), Color(0.20, 0.14, 0.34, 0.95))
    _text(str(b.get("speaker", "")), Vector2(76, 520), 20, Color(0.88, 0.82, 0.98))
    var full: String = str(b.get("text", ""))
    var shown := full
    if line_t < 1.0:
        shown = full.substr(0, int(float(full.length()) * line_t))
    _wrap(shown, Rect2(72, 536, 1140, 140), 20, Color(0.92, 0.90, 0.96))
    if line_t >= 1.0 and b.has("choice"):
        var opts: Array = b["choice"]
        for i in range(opts.size()):
            var o: Dictionary = opts[i]
            var req: String = str(o.get("req", ""))
            var label: String = "%d. %s" % [i + 1, str(o["label"])]
            if req != "":
                label += "   [needs %s %d]" % [req, int(o.get("need", 0))]
            _button(Rect2(120, 250 + i * 64, 1040, 52), label)

func _draw_result() -> void:
    var b: Dictionary = _cur_beat()
    _scene_bg(str(b.get("bg", "hall")))
    _draw_statbar()
    _panel(Rect2(220, 240, 840, 240))
    _wrap(msg, Rect2(260, 290, 760, 140), 22, Color(0.92, 0.90, 0.96))
    _button(Rect2(560, 430, 160, 40), "Continue")

func _draw_ending() -> void:
    var e: Dictionary = _ending_data()
    _scene_bg(str(e["bg"]))
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, 0.5))
    _panel(Rect2(220, 170, 840, 360))
    _text(str(e["title"]), Vector2(270, 250), 46, Color(0.80, 0.65, 0.98))
    _wrap(str(e["text"]), Rect2(270, 300, 740, 170), 22, Color(0.90, 0.88, 0.96))
    _button(Rect2(420, 470, 200, 54), "NEW TERM")
    _button(Rect2(660, 470, 200, 54), "TITLE")

# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if mode == "train":
            if event.keycode == KEY_1: _train(0)
            elif event.keycode == KEY_2: _train(1)
            elif event.keycode == KEY_3: _train(2)
            elif event.keycode == KEY_4: _train(3)
            elif event.keycode == KEY_SPACE: _finish_training()
        elif mode == "story":
            if event.keycode == KEY_1: _pick(0)
            elif event.keycode == KEY_2: _pick(1)
            elif event.keycode == KEY_3: _pick(2)
            elif event.keycode == KEY_SPACE and line_t < 1.0: line_t = 1.0; queue_redraw()
        elif mode == "result":
            if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER: _continue_after_result()
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _click(event.position)

func _click(p: Vector2) -> void:
    if mode == "title":
        if Rect2(500, 410, 280, 64).has_point(p):
            _begin_new(); queue_redraw()
    elif mode == "train":
        for i in range(DISCIPLINES.size()):
            if Rect2(70 + (i % 2) * 420, 320 + (i / 2) * 70, 400, 54).has_point(p):
                _train(i); return
    elif mode == "story":
        var b: Dictionary = _cur_beat()
        if line_t >= 1.0 and b.has("choice"):
            var opts: Array = b["choice"]
            for i in range(opts.size()):
                if Rect2(120, 250 + i * 64, 1040, 52).has_point(p):
                    _pick(i); return
        else:
            line_t = 1.0; queue_redraw()
    elif mode == "result":
        if Rect2(560, 430, 160, 40).has_point(p):
            _continue_after_result()
    elif mode == "ending":
        if Rect2(420, 470, 200, 54).has_point(p):
            _begin_new(); queue_redraw()
        elif Rect2(660, 470, 200, 54).has_point(p):
            mode = "title"; queue_redraw()

func _process(delta: float) -> void:
    anim += delta
    if mode == "story" and line_t < 1.0:
        line_t = min(1.0, line_t + delta * 1.6)
        queue_redraw()
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_train.json" <<'EOF'
{
  "duration_frames": 400,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 640, "y": 442},
    {"frame": 90,  "type": "key_press", "keycode": "2"},
    {"frame": 150, "type": "key_press", "keycode": "2"},
    {"frame": 210, "type": "key_press", "keycode": "1"},
    {"frame": 280, "type": "key_press", "keycode": "SPACE"},
    {"frame": 380, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_rival_pass.json" <<'EOF'
{
  "scenario": "story_rival",
  "duration_frames": 380,
  "events": [
    {"frame": 50,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 130, "type": "key_press", "keycode": "1"},
    {"frame": 220, "type": "key_press", "keycode": "SPACE"},
    {"frame": 340, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_forbidden_beat.json" <<'EOF'
{
  "scenario": "story_forbidden",
  "duration_frames": 380,
  "events": [
    {"frame": 50,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 140, "type": "key_press", "keycode": "1"},
    {"frame": 240, "type": "key_press", "keycode": "SPACE"},
    {"frame": 340, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_ending_archmage.json" <<'EOF'
{
  "scenario": "ending_archmage",
  "duration_frames": 300,
  "events": [
    {"frame": 60,  "type": "wait"},
    {"frame": 220, "type": "mouse_click", "button": "left", "x": 520, "y": 497},
    {"frame": 290, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/05_ending_fallen.json" <<'EOF'
{
  "scenario": "ending_fallen",
  "duration_frames": 300,
  "events": [
    {"frame": 60,  "type": "wait"},
    {"frame": 240, "type": "wait"}
  ]
}
EOF

echo "arcaneacademy oracle generated at $GAME"
