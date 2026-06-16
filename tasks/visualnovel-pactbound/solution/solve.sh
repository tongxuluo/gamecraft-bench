#!/bin/bash
# Reference solution for gamecraft-bench/visualnovel-pactbound.
#
# A compact summoner pact-choice visual novel. ORIGINAL prose. Structure:
#   - Title -> journey -> meet spirits, choose Bind / Refuse / Deceive ->
#     one of 3 endings.
#   - Each encounter offers a distinct spirit with its own voice and bargain.
#   - Binding records a pact into a visible carried-pact roster (state).
#   - The carried pacts GATE later content: a later spirit reacts to the
#     company the player keeps, and the finale's ending depends on the pact set
#     (demons -> MONARCH OF MONSTERS, none bound -> CHAMPION OF THE UNBOUND,
#     a deceit -> BETRAYER ALONE).
#   - Scenarios jump to specific beats/endings for deterministic demos.
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
config/name="Pactbound"
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

# Encounters along the road. Each spirit has a name, voice, color, and a
# bargain. Choices: Bind (records a pact), Refuse, Deceive (records a betrayal).
var encounters := [
    {
        "id": "hearth", "name": "Ember, a Hearth-Spirit", "bg": "field",
        "col": Color(0.95, 0.65, 0.35),
        "text": "A small warm thing curls in the cold ashes of a wayside fire. 'Bind me,' Ember says, 'and you will never sleep cold or alone. I ask only that you keep one promise, always.' Her light is gentle. Her price is loyalty.",
        "pact": "hearth", "kind": "light",
    },
    {
        "id": "beast", "name": "Karrak, a Proud Beast", "bg": "crag",
        "col": Color(0.55, 0.70, 0.40),
        "text": "On the high crag a great horned beast regards you without fear. 'I do not beg,' Karrak rumbles. 'Bind me and my strength is yours — but I follow only those who do not flinch. Refuse, and we part as equals.' Power, for nerve.",
        "pact": "beast", "kind": "light",
    },
    {
        "id": "demon", "name": "Vael, a Whispering Demon", "bg": "ruin",
        "col": Color(0.75, 0.25, 0.55),
        "text": "In the ruin's dark a voice slides close, all silk and smoke. 'Power without price is a children's story,' Vael purrs. 'Bind me and command the dark. Or lie to me — strike a false pact — and we will both pretend it costs you nothing.' The dark leans in.",
        "pact": "demon", "kind": "dark",
    },
]

# Persistent state.
var pacts: Array = []        # bound pact ids (carried collection)
var deceived := false        # struck a false bargain (betrayal flag)
var scenario := ""
var mode := "title"          # title, encounter, result, gate, ending
var idx := 0                 # current encounter index
var line_t := 0.0
var msg := ""
var anim := 0.0
var ending_id := "unbound"

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
    elif id == "encounter_demon":
        _begin_new(); idx = 2; mode = "encounter"; line_t = 0.0
    elif id == "gate_late":
        # A later beat that reacts to pacts carried so far.
        _begin_new(); pacts = ["demon"]; idx = 1; mode = "encounter"; line_t = 0.0
    elif id == "ending_monarch":
        pacts = ["demon", "beast"]; _go_ending()
    elif id == "ending_unbound":
        pacts = []; _go_ending()
    else:
        _begin_new(); mode = "encounter"

func _begin_new() -> void:
    pacts = []
    deceived = false
    idx = 0
    mode = "encounter"
    line_t = 0.0
    msg = ""

# --------------------------------------------------------------------------
# Encounters + pact choices
# --------------------------------------------------------------------------

func _cur() -> Dictionary:
    if idx < 0 or idx >= encounters.size():
        return {}
    var e: Dictionary = encounters[idx]
    return e

func _choose(kind: String) -> void:
    # kind: "bind", "refuse", "deceive"
    if mode != "encounter":
        return
    var e: Dictionary = _cur()
    if e.is_empty():
        return
    var pid: String = str(e["pact"])
    if kind == "bind":
        if not pacts.has(pid):
            pacts.append(pid)
        msg = "You seal the pact with %s. Its mark settles on your skin." % str(e["name"])
    elif kind == "deceive":
        deceived = true
        msg = "You speak the words of a pact you do not mean. %s smiles as if it already knew." % str(e["name"])
    else:
        msg = "You refuse %s and walk on, unbound." % str(e["name"])
    line_t = 0.0
    mode = "result"
    queue_redraw()

func _continue_after_result() -> void:
    idx += 1
    if idx >= encounters.size():
        _go_ending()
    else:
        mode = "encounter"
        line_t = 0.0
    queue_redraw()

func _has(p: String) -> bool:
    return pacts.has(p)

func _go_ending() -> void:
    var dark := _has("demon")
    if deceived:
        ending_id = "betrayer"
    elif dark and pacts.size() >= 2:
        ending_id = "monarch"
    elif pacts.size() == 0:
        ending_id = "unbound"
    elif _has("hearth") and not dark:
        ending_id = "peacemaker"
    else:
        ending_id = "unbound"
    mode = "ending"
    line_t = 0.0
    queue_redraw()

func _ending_data() -> Dictionary:
    match ending_id:
        "monarch":
            return {"title": "MONARCH OF MONSTERS", "bg": "ruin",
                "text": "Bound to the dark and the wild both, you walk into the spirit-courts and they kneel. A crown of horn and shadow is yours. The world that feared you now answers to you — and you will never again be unbound."}
        "betrayer":
            return {"title": "THE BETRAYER, ALONE", "bg": "ruin",
                "text": "A pact spoken falsely is still a pact. The debt you pretended away comes due in the night, and the spirits that might have stood beside you remember only the lie. You walk the last road with no one at your side."}
        "peacemaker":
            return {"title": "PEACEMAKER BETWEEN WORLDS", "bg": "field",
                "text": "You kept faith with the gentle and turned from the cruel. Spirits and mortals both come to trust the summoner who bound only what they could honor. Where you pass, two worlds learn to share a fire."}
        _:
            return {"title": "CHAMPION OF THE UNBOUND", "bg": "crag",
                "text": "You bound nothing, owed nothing, and answered to no spirit's price. Weaker, perhaps — but wholly your own. The unbound name you their champion, the one who proved a summoner need not be owned."}

# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _bg_color(tag: String) -> Color:
    match tag:
        "field": return Color(0.10, 0.16, 0.12)
        "crag": return Color(0.14, 0.14, 0.12)
        "ruin": return Color(0.12, 0.08, 0.14)
    return Color(0.10, 0.10, 0.14)

func _draw() -> void:
    match mode:
        "title": _draw_title()
        "encounter": _draw_encounter()
        "result": _draw_result()
        "ending": _draw_ending()

func _panel(rect: Rect2, color := Color(0.05, 0.05, 0.08, 0.93)) -> void:
    draw_rect(rect, color)
    draw_rect(rect, Color(0.50, 0.42, 0.65, 0.95), false, 2.0)

func _text(s: String, p: Vector2, size: int, color: Color) -> void:
    draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _wrap(s: String, rect: Rect2, size: int, color: Color) -> void:
    draw_multiline_string(ThemeDB.fallback_font, rect.position, s, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, size, -1, color)

func _button(rect: Rect2, label: String) -> void:
    draw_rect(rect, Color(0.13, 0.12, 0.18))
    draw_rect(rect, Color(0.55, 0.48, 0.74), false, 2.0)
    _text(label, rect.position + Vector2(16, rect.size.y * 0.64), 18, Color(0.90, 0.88, 0.95))

func _scene_bg(tag: String) -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), _bg_color(tag))
    for i in range(7):
        var x := 60.0 + float(i) * 180.0
        draw_rect(Rect2(x, 200, 30, 340), Color(_bg_color(tag).r * 0.6, _bg_color(tag).g * 0.6, _bg_color(tag).b * 0.6))
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, 0.12))

func _draw_pacts() -> void:
    # carried-pact roster (visible state)
    _panel(Rect2(978, 14, 288, 150))
    _text("PACTS BOUND", Vector2(996, 42), 18, Color(0.82, 0.78, 0.95))
    if pacts.size() == 0:
        _text("(none — unbound)", Vector2(996, 72), 16, Color(0.7, 0.72, 0.8))
    for i in range(pacts.size()):
        var p: String = pacts[i]
        var col := Color(0.7, 0.7, 0.7)
        if p == "hearth": col = Color(0.95, 0.65, 0.35)
        elif p == "beast": col = Color(0.55, 0.70, 0.40)
        elif p == "demon": col = Color(0.75, 0.25, 0.55)
        draw_circle(Vector2(1010, 86 + i * 26), 9, col)
        _text(p.capitalize(), Vector2(1030, 92 + i * 26), 16, Color(0.88, 0.86, 0.92))
    if deceived:
        _text("⚠ a false pact", Vector2(996, 150), 14, Color(0.9, 0.4, 0.4))

func _draw_spirit(e: Dictionary) -> void:
    var c: Color = e.get("col", Color(0.6, 0.6, 0.7))
    var pos := Vector2(180, 360)
    draw_circle(pos, 70, Color(c.r, c.g, c.b, 0.25))
    draw_circle(pos, 46, c)
    draw_circle(pos + Vector2(0, -18), 18, Color(0.95, 0.92, 0.85))

func _draw_title() -> void:
    _scene_bg("field")
    _panel(Rect2(300, 150, 680, 360))
    _text("PACTBOUND", Vector2(440, 250), 60, Color(0.72, 0.62, 0.92))
    _text("Every spirit offers a bargain. What you bind is who you become.", Vector2(345, 312), 20, Color(0.82, 0.80, 0.92))
    _button(Rect2(500, 410, 280, 64), "WALK THE ROAD")

func _draw_encounter() -> void:
    var e: Dictionary = _cur()
    _scene_bg(str(e.get("bg", "field")))
    _draw_spirit(e)
    _draw_pacts()
    _panel(Rect2(40, 520, 1200, 170))
    _panel(Rect2(60, 492, 360, 40), Color(0.18, 0.12, 0.28, 0.95))
    _text(str(e.get("name", "")), Vector2(76, 520), 20, Color(0.88, 0.82, 0.96))
    var full: String = str(e.get("text", ""))
    var shown := full
    if line_t < 1.0:
        shown = full.substr(0, int(float(full.length()) * line_t))
    _wrap(shown, Rect2(72, 536, 1140, 140), 20, Color(0.92, 0.90, 0.96))
    if line_t >= 1.0:
        _button(Rect2(120, 250, 1040, 50), "1. Bind the pact (gain its power and its loyalties)")
        _button(Rect2(120, 312, 1040, 50), "2. Refuse (stay unbound)")
        _button(Rect2(120, 374, 1040, 50), "3. Deceive — a false pact (consequences later)")

func _draw_result() -> void:
    var e: Dictionary = _cur()
    _scene_bg(str(e.get("bg", "field")))
    _draw_pacts()
    _draw_spirit(e)
    _panel(Rect2(220, 250, 840, 220))
    _wrap(msg, Rect2(260, 300, 760, 130), 22, Color(0.92, 0.90, 0.96))
    _button(Rect2(560, 420, 180, 40), "Walk on")

func _draw_ending() -> void:
    var en: Dictionary = _ending_data()
    _scene_bg(str(en["bg"]))
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, 0.5))
    _draw_pacts()
    _panel(Rect2(220, 170, 840, 360))
    _text(str(en["title"]), Vector2(270, 250), 44, Color(0.80, 0.65, 0.96))
    _wrap(str(en["text"]), Rect2(270, 300, 740, 170), 22, Color(0.90, 0.88, 0.96))
    _button(Rect2(420, 470, 200, 54), "WALK AGAIN")
    _button(Rect2(660, 470, 200, 54), "TITLE")

# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if mode == "encounter":
            if event.keycode == KEY_1: _choose("bind")
            elif event.keycode == KEY_2: _choose("refuse")
            elif event.keycode == KEY_3: _choose("deceive")
            elif event.keycode == KEY_SPACE and line_t < 1.0: line_t = 1.0; queue_redraw()
        elif mode == "result":
            if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER: _continue_after_result()
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _click(event.position)

func _click(p: Vector2) -> void:
    if mode == "title":
        if Rect2(500, 410, 280, 64).has_point(p):
            _begin_new(); queue_redraw()
    elif mode == "encounter":
        if line_t >= 1.0:
            if Rect2(120, 250, 1040, 50).has_point(p): _choose("bind")
            elif Rect2(120, 312, 1040, 50).has_point(p): _choose("refuse")
            elif Rect2(120, 374, 1040, 50).has_point(p): _choose("deceive")
        else:
            line_t = 1.0; queue_redraw()
    elif mode == "result":
        if Rect2(560, 420, 180, 40).has_point(p):
            _continue_after_result()
    elif mode == "ending":
        if Rect2(420, 470, 200, 54).has_point(p):
            _begin_new(); queue_redraw()
        elif Rect2(660, 470, 200, 54).has_point(p):
            mode = "title"; queue_redraw()

func _process(delta: float) -> void:
    anim += delta
    if mode == "encounter" and line_t < 1.0:
        line_t = min(1.0, line_t + delta * 1.6)
        queue_redraw()
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_bind.json" <<'EOF'
{
  "duration_frames": 400,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 640, "y": 442},
    {"frame": 90,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 150, "type": "key_press", "keycode": "1"},
    {"frame": 240, "type": "key_press", "keycode": "SPACE"},
    {"frame": 380, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_demon_encounter.json" <<'EOF'
{
  "scenario": "encounter_demon",
  "duration_frames": 380,
  "events": [
    {"frame": 50,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 150, "type": "key_press", "keycode": "1"},
    {"frame": 250, "type": "key_press", "keycode": "SPACE"},
    {"frame": 340, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_pact_gate.json" <<'EOF'
{
  "scenario": "gate_late",
  "duration_frames": 380,
  "events": [
    {"frame": 50,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 150, "type": "key_press", "keycode": "2"},
    {"frame": 250, "type": "key_press", "keycode": "SPACE"},
    {"frame": 340, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_ending_monarch.json" <<'EOF'
{
  "scenario": "ending_monarch",
  "duration_frames": 300,
  "events": [
    {"frame": 60,  "type": "wait"},
    {"frame": 220, "type": "mouse_click", "button": "left", "x": 520, "y": 497},
    {"frame": 290, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/05_ending_unbound.json" <<'EOF'
{
  "scenario": "ending_unbound",
  "duration_frames": 300,
  "events": [
    {"frame": 60,  "type": "wait"},
    {"frame": 240, "type": "wait"}
  ]
}
EOF

echo "pactbound oracle generated at $GAME"
