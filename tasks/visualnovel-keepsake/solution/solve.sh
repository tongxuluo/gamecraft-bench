#!/bin/bash
# Reference solution for gamecraft-bench/visualnovel-keepsake.
#
# A compact memory-reconstruction visual novel. ORIGINAL prose about an
# invented person. Structure:
#   - Title -> the room -> examine keepsakes in any order -> interpretation
#     choice -> one of 3 closing understandings.
#   - Free-order examination: the player picks objects from a room/box; each
#     reveals a memory fragment recorded into a visible collected-fragments list.
#   - Fragments connect: a later fragment recontextualizes an earlier one, and
#     which fragments were found GATES the available interpretations and ending.
#   - Several distinct keepsakes (photo, letter, ring, diary) sketching one
#     life across episodes; an interpretation choice (judge / forgive / keep).
#   - Endings depend on found fragments + the interpretation chosen.
#   - Scenarios jump to specific states/endings for deterministic demos.
#
# Oracle for the verifier framework, not a polished game: drawn from primitives,
# so the art items (A1-A4) stay low while mechanic/content items pass.
#
# NOTE (GDScript warnings-as-errors): min()/Dictionary subscripts/JSON return
# Variant; each such value is given an explicit type to avoid the
# "inferred Variant" parse error that fails the whole script.
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="Keepsake"
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

# Keepsakes the player can examine, in any order. Each reveals a memory and
# records a fragment id. Some text recontextualizes earlier fragments.
var items := [
    {
        "id": "photo", "name": "A Faded Photograph", "col": Color(0.80, 0.72, 0.55),
        "frag": "photo",
        "text": "Two young women on a pier, squinting into a lost summer. One is Edith, unmistakable even young. The other you do not know — her arm around Edith's waist, both of them laughing at something just out of frame. On the back, in pencil: 'Before everything. — M.'"},
    {
        "id": "letter", "name": "A Folded Letter", "col": Color(0.86, 0.84, 0.78),
        "frag": "letter",
        "text": "The letter was never sent; the envelope is blank. 'I am sorry I chose the safe road and let you walk the other alone. I told myself it was for the family. I think I was only afraid. If you ever read this, M., know that I counted the cost every day after.' It is dated forty years ago."},
    {
        "id": "ring", "name": "A Worn Ring", "col": Color(0.85, 0.78, 0.40),
        "frag": "ring",
        "text": "A plain band, too small for the man Edith married. Inside the curve, an engraving worn nearly smooth: two initials, E and M, and a date that matches the summer on the pier. She wore it on a chain, the neighbors said, under her collar, for sixty years."},
    {
        "id": "diary", "name": "A Diary, One Page Torn", "col": Color(0.70, 0.60, 0.62),
        "frag": "diary",
        "text": "Most entries are weather and groceries. But near the end, a steadier hand: 'M. passed in the spring. I read it in the paper, three towns over. I did not go. I have no right to grief I chose. I keep the ring. It is the truest thing I own.' The facing page has been torn out."},
]

# Persistent state.
var found: Array = []        # fragment ids gathered (collected fragments)
var examined: Array = []     # item ids already examined
var scenario := ""
var mode := "title"          # title, room, item, interp, ending
var cur_item := -1
var line_t := 0.0
var anim := 0.0
var ending_id := "grief"

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
    elif id == "room":
        _begin_new(); mode = "room"
    elif id == "examine":
        _begin_new(); mode = "item"; cur_item = 1; _record(1); line_t = 0.0
    elif id == "interp_full":
        _begin_new(); found = ["photo", "letter", "ring", "diary"]; examined = ["photo", "letter", "ring", "diary"]; mode = "interp"
    elif id == "ending_forgive":
        found = ["photo", "letter", "ring", "diary"]; ending_id = "forgive"; mode = "ending"
    elif id == "ending_grief":
        found = ["photo"]; ending_id = "grief"; mode = "ending"
    else:
        _begin_new(); mode = "room"

func _begin_new() -> void:
    found = []
    examined = []
    cur_item = -1
    mode = "room"
    line_t = 0.0

# --------------------------------------------------------------------------
# Examination + fragment recording
# --------------------------------------------------------------------------

func _record(i: int) -> void:
    if i < 0 or i >= items.size():
        return
    var it: Dictionary = items[i]
    var fid: String = str(it["frag"])
    if not examined.has(str(it["id"])):
        examined.append(str(it["id"]))
    if not found.has(fid):
        found.append(fid)

func _open_item(i: int) -> void:
    if mode != "room":
        return
    cur_item = i
    _record(i)
    mode = "item"
    line_t = 0.0
    queue_redraw()

func _close_item() -> void:
    cur_item = -1
    # When every keepsake has been examined, the interpretation opens.
    if examined.size() >= items.size():
        mode = "interp"
    else:
        mode = "room"
    queue_redraw()

# --------------------------------------------------------------------------
# Interpretation choice -> ending (gated by fragments found)
# --------------------------------------------------------------------------

func _interpret(idx: int) -> void:
    if mode != "interp":
        return
    # The "forgive" reading is only true to the story if the player found the
    # letter and the ring (the evidence of lifelong regret). Choosing to forgive
    # without them lands as hollow grief instead.
    var knows := found.has("letter") and found.has("ring")
    if idx == 0:  # forgive / understand
        ending_id = "forgive" if knows else "grief"
    elif idx == 1:  # judge
        ending_id = "judge"
    else:  # keep the secret / say nothing
        ending_id = "kept"
    mode = "ending"
    line_t = 0.0
    queue_redraw()

func _ending_data() -> Dictionary:
    match ending_id:
        "forgive":
            return {"title": "A LIFE REDEEMED", "bg": "warm",
                "text": "You set the ring in the box and close the lid gently. Edith chose the safe road and paid for it in silence for sixty years — but she paid, and she kept faith the only way left to her. You understand her now, and understanding is its own forgiveness. You will not throw the ring away."}
        "judge":
            return {"title": "THE COWARD'S HOARD", "bg": "cold",
                "text": "You see it plainly: she chose comfort over love and dressed her regret up as devotion to soothe herself. The ring is not faith, it is a forty-year apology she never had the courage to send. You sort the rest into boxes and do not keep it."}
        "kept":
            return {"title": "A SECRET KEPT IN KINDNESS", "bg": "warm",
                "text": "Whatever Edith was, she is past being asked. You fold the letter back into its blank envelope and tell no one what you read. Some truths are not yours to publish. The ring goes back on its chain, and the chain goes into the earth with her."}
        _:
            return {"title": "A QUIET GRIEF", "bg": "dim",
                "text": "You did not learn enough to be sure of her, and you will not pretend you did. There was love here, and a long ache, and a torn-out page you will never read. You grieve the shape of a person you only half-met, and let the rest stay buried."}

# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _bg_color(tag: String) -> Color:
    match tag:
        "warm": return Color(0.16, 0.13, 0.10)
        "cold": return Color(0.10, 0.11, 0.14)
        "dim": return Color(0.10, 0.10, 0.11)
    return Color(0.13, 0.11, 0.10)

func _draw() -> void:
    match mode:
        "title": _draw_title()
        "room": _draw_room()
        "item": _draw_item()
        "interp": _draw_interp()
        "ending": _draw_ending()

func _panel(rect: Rect2, color := Color(0.07, 0.06, 0.05, 0.94)) -> void:
    draw_rect(rect, color)
    draw_rect(rect, Color(0.46, 0.40, 0.32, 0.95), false, 2.0)

func _text(s: String, p: Vector2, size: int, color: Color) -> void:
    draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _wrap(s: String, rect: Rect2, size: int, color: Color) -> void:
    draw_multiline_string(ThemeDB.fallback_font, rect.position, s, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, size, -1, color)

func _button(rect: Rect2, label: String) -> void:
    draw_rect(rect, Color(0.13, 0.11, 0.09))
    draw_rect(rect, Color(0.55, 0.48, 0.38), false, 2.0)
    _text(label, rect.position + Vector2(16, rect.size.y * 0.64), 18, Color(0.90, 0.86, 0.78))

func _room_bg() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), _bg_color("warm"))
    # a window with soft light + dust motes
    draw_rect(Rect2(940, 60, 260, 300), Color(0.22, 0.20, 0.16))
    draw_rect(Rect2(948, 68, 244, 284), Color(0.30, 0.28, 0.22))
    for i in range(16):
        var x := 300.0 + fmod(float(i) * 130.0 + anim * 12.0, 800.0)
        var y := 120.0 + float((i * 53) % 300)
        draw_circle(Vector2(x, y), 2.0, Color(0.8, 0.75, 0.6, 0.16))
    draw_rect(Rect2(60, 470, 1160, 130), Color(0.10, 0.08, 0.06))

func _draw_fragments() -> void:
    _panel(Rect2(978, 380, 288, 200))
    _text("WHAT YOU KNOW", Vector2(996, 408), 18, Color(0.82, 0.76, 0.6))
    if found.size() == 0:
        _text("(nothing yet)", Vector2(996, 438), 16, Color(0.7, 0.66, 0.6))
    for i in range(found.size()):
        _text("• " + str(found[i]).capitalize(), Vector2(996, 438 + i * 26), 16, Color(0.86, 0.82, 0.74))
    _text("Examined %d/%d" % [examined.size(), items.size()], Vector2(996, 560), 15, Color(0.7, 0.7, 0.62))

func _draw_title() -> void:
    _room_bg()
    _panel(Rect2(300, 150, 680, 360))
    _text("KEEPSAKE", Vector2(470, 250), 58, Color(0.78, 0.70, 0.55))
    _text("She is gone. Her things remain. Piece together who she was.", Vector2(360, 312), 19, Color(0.84, 0.80, 0.72))
    _button(Rect2(500, 410, 280, 64), "OPEN THE BOX")

func _draw_room() -> void:
    _room_bg()
    _draw_fragments()
    _panel(Rect2(40, 120, 880, 320))
    _text("EDITH'S KEEPSAKES", Vector2(70, 168), 30, Color(0.82, 0.76, 0.6))
    _text("Take up whatever you like, in any order.", Vector2(70, 204), 18, Color(0.8, 0.78, 0.7))
    for i in range(items.size()):
        var it: Dictionary = items[i]
        var seen := examined.has(str(it["id"]))
        var r := Rect2(70 + (i % 2) * 420, 234 + (i / 2) * 90, 400, 74)
        draw_rect(r, Color(0.13, 0.11, 0.09))
        draw_rect(r, Color(0.55, 0.48, 0.38) if not seen else Color(0.35, 0.50, 0.35), false, 2.0)
        draw_rect(Rect2(r.position + Vector2(12, 16), Vector2(40, 40)), it.get("col", Color(0.7, 0.6, 0.5)))
        _text("%d. %s" % [i + 1, str(it["name"])], r.position + Vector2(64, 34), 18, Color(0.9, 0.86, 0.78))
        if seen:
            _text("(examined)", r.position + Vector2(64, 58), 14, Color(0.6, 0.8, 0.6))
    _panel(Rect2(40, 470, 1160, 130))
    _text("Examine every keepsake to reach an understanding.", Vector2(70, 520), 18, Color(0.82, 0.78, 0.7))

func _draw_item() -> void:
    if cur_item < 0 or cur_item >= items.size():
        mode = "room"; return
    var it: Dictionary = items[cur_item]
    _room_bg()
    _draw_fragments()
    # the object, large
    var c: Color = it.get("col", Color(0.7, 0.6, 0.5))
    draw_rect(Rect2(120, 150, 220, 220), Color(c.r * 0.5, c.g * 0.5, c.b * 0.5))
    draw_rect(Rect2(140, 170, 180, 180), c)
    _panel(Rect2(40, 540, 1200, 150))
    _panel(Rect2(60, 512, 360, 40), Color(0.20, 0.16, 0.12, 0.95))
    _text(str(it["name"]), Vector2(76, 540), 20, Color(0.88, 0.82, 0.7))
    var full: String = str(it["text"])
    var shown := full
    if line_t < 1.0:
        shown = full.substr(0, int(float(full.length()) * line_t))
    _wrap(shown, Rect2(380, 200, 600, 320), 20, Color(0.90, 0.86, 0.78))
    if line_t >= 1.0:
        _button(Rect2(540, 636, 200, 44), "Set it down")

func _draw_interp() -> void:
    _room_bg()
    _draw_fragments()
    _panel(Rect2(40, 120, 880, 360))
    _text("HOW WILL YOU REMEMBER HER?", Vector2(70, 168), 28, Color(0.82, 0.76, 0.6))
    _wrap("You have turned over everything she left. A summer, a letter never sent, a ring worn sixty years, a torn-out page. Now you must decide what to make of it.",
          Rect2(70, 196, 820, 90), 19, Color(0.86, 0.82, 0.74))
    _button(Rect2(70, 300, 820, 50), "1. Forgive her — she paid for her choice in silence")
    _button(Rect2(70, 364, 820, 50), "2. Judge her — she dressed cowardice up as devotion")
    _button(Rect2(70, 428, 820, 50), "3. Keep her secret — tell no one what you read")

func _draw_ending() -> void:
    var e: Dictionary = _ending_data()
    draw_rect(Rect2(Vector2.ZERO, VIEW), _bg_color(str(e["bg"])))
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, 0.35))
    _draw_fragments()
    _panel(Rect2(180, 170, 800, 360))
    _text(str(e["title"]), Vector2(230, 250), 40, Color(0.82, 0.72, 0.56))
    _wrap(str(e["text"]), Rect2(230, 300, 700, 190), 21, Color(0.90, 0.86, 0.78))
    _button(Rect2(360, 480, 200, 50), "BEGIN AGAIN")
    _button(Rect2(600, 480, 200, 50), "TITLE")

# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if mode == "room":
            if event.keycode == KEY_1: _open_item(0)
            elif event.keycode == KEY_2: _open_item(1)
            elif event.keycode == KEY_3: _open_item(2)
            elif event.keycode == KEY_4: _open_item(3)
        elif mode == "item":
            if event.keycode == KEY_SPACE and line_t < 1.0: line_t = 1.0; queue_redraw()
            elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER: _close_item()
        elif mode == "interp":
            if event.keycode == KEY_1: _interpret(0)
            elif event.keycode == KEY_2: _interpret(1)
            elif event.keycode == KEY_3: _interpret(2)
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _click(event.position)

func _click(p: Vector2) -> void:
    if mode == "title":
        if Rect2(500, 410, 280, 64).has_point(p):
            _begin_new(); queue_redraw()
    elif mode == "room":
        for i in range(items.size()):
            var r := Rect2(70 + (i % 2) * 420, 234 + (i / 2) * 90, 400, 74)
            if r.has_point(p):
                _open_item(i); return
    elif mode == "item":
        if line_t < 1.0:
            line_t = 1.0; queue_redraw()
        elif Rect2(540, 636, 200, 44).has_point(p):
            _close_item()
    elif mode == "interp":
        if Rect2(70, 300, 820, 50).has_point(p): _interpret(0)
        elif Rect2(70, 364, 820, 50).has_point(p): _interpret(1)
        elif Rect2(70, 428, 820, 50).has_point(p): _interpret(2)
    elif mode == "ending":
        if Rect2(360, 480, 200, 50).has_point(p):
            _begin_new(); queue_redraw()
        elif Rect2(600, 480, 200, 50).has_point(p):
            mode = "title"; queue_redraw()

func _process(delta: float) -> void:
    anim += delta
    if mode == "room":
        queue_redraw()  # drifting dust
    if mode == "item" and line_t < 1.0:
        line_t = min(1.0, line_t + delta * 1.4)
        queue_redraw()
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_examine.json" <<'EOF'
{
  "duration_frames": 420,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 640, "y": 442},
    {"frame": 90,  "type": "key_press", "keycode": "1"},
    {"frame": 170, "type": "key_press", "keycode": "SPACE"},
    {"frame": 230, "type": "key_press", "keycode": "SPACE"},
    {"frame": 400, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_examine_letter.json" <<'EOF'
{
  "scenario": "examine",
  "duration_frames": 380,
  "events": [
    {"frame": 50,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 150, "type": "key_press", "keycode": "SPACE"},
    {"frame": 220, "type": "key_press", "keycode": "3"},
    {"frame": 320, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_interp_forgive.json" <<'EOF'
{
  "scenario": "interp_full",
  "duration_frames": 360,
  "events": [
    {"frame": 60,  "type": "key_press", "keycode": "1"},
    {"frame": 180, "type": "mouse_click", "button": "left", "x": 460, "y": 505},
    {"frame": 320, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_ending_forgive.json" <<'EOF'
{
  "scenario": "ending_forgive",
  "duration_frames": 300,
  "events": [
    {"frame": 60,  "type": "wait"},
    {"frame": 280, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/05_ending_grief.json" <<'EOF'
{
  "scenario": "ending_grief",
  "duration_frames": 300,
  "events": [
    {"frame": 60,  "type": "wait"},
    {"frame": 280, "type": "wait"}
  ]
}
EOF

echo "keepsake oracle generated at $GAME"
