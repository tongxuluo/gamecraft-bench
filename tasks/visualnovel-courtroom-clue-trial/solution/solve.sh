#!/bin/bash
set -eu

GAME=/workspace/game
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5
[application]
config/name="Courtroom Clue Trial"
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
[node name="Main" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
EOF

cat > "$GAME/scripts/Main.gd" <<'EOF'
extends Control

var scenario := ""
var mode := "title"
var credibility := 3
var statement := 1
var evidence := "Broken Watch"

func _ready() -> void:
    for i in range(OS.get_cmdline_user_args().size()):
        var args := OS.get_cmdline_user_args()
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]
    mode = scenario if scenario != "" else "title"
    _draw()

func _clear() -> void:
    for c in get_children():
        c.queue_free()

func _rect(p: Vector2, s: Vector2, c: Color) -> void:
    var r := ColorRect.new()
    r.position = p
    r.size = s
    r.color = c
    add_child(r)

func _label(t: String, p: Vector2, s: Vector2, fs := 22, c := Color.WHITE) -> void:
    var l := Label.new()
    l.text = t
    l.position = p
    l.size = s
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_font_size_override("font_size", fs)
    l.add_theme_color_override("font_color", c)
    l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
    l.add_theme_constant_override("shadow_offset_x", 2)
    l.add_theme_constant_override("shadow_offset_y", 2)
    add_child(l)

func _button(t: String, p: Vector2, s: Vector2, cb: Callable) -> void:
    var b := Button.new()
    b.text = t
    b.position = p
    b.size = s
    b.add_theme_font_size_override("font_size", 18)
    b.pressed.connect(cb)
    add_child(b)

func _draw_frame(title: String) -> void:
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.10, 0.07, 0.055))
    _rect(Vector2(60, 64), Vector2(1160, 590), Color(0.20, 0.12, 0.08))
    _rect(Vector2(90, 92), Vector2(1100, 84), Color(0.36, 0.22, 0.12))
    _label(title, Vector2(110, 112), Vector2(760, 44), 34, Color(1.0, 0.82, 0.38))
    _label("Credibility: " + "◆".repeat(credibility) + "◇".repeat(3 - credibility), Vector2(900, 118), Vector2(250, 32), 22, Color(0.85, 0.96, 1.0))
    _rect(Vector2(120, 205), Vector2(230, 285), Color(0.52, 0.42, 0.30))
    _label("WITNESS\nMara Quill", Vector2(150, 245), Vector2(170, 90), 24)
    _rect(Vector2(930, 205), Vector2(210, 285), Color(0.38, 0.27, 0.18))
    _label("JUDGE\nBench", Vector2(965, 245), Vector2(150, 70), 24)
    _rect(Vector2(388, 210), Vector2(500, 250), Color(0.13, 0.16, 0.18))
    _rect(Vector2(120, 515), Vector2(1020, 105), Color(0.08, 0.10, 0.12))

func _draw() -> void:
    if mode == "title":
        _clear()
        _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.09, 0.06, 0.04))
        _rect(Vector2(180, 95), Vector2(920, 455), Color(0.24, 0.14, 0.08))
        _rect(Vector2(260, 370), Vector2(760, 45), Color(0.46, 0.30, 0.16))
        for x in [330, 480, 630, 780, 930]:
            _rect(Vector2(x, 255), Vector2(70, 115), Color(0.78, 0.68, 0.50))
        _label("COURTROOM CLUE TRIAL", Vector2(275, 150), Vector2(760, 70), 50, Color(1.0, 0.78, 0.32))
        _label("Case 04: the clock tower alibi", Vector2(390, 230), Vector2(520, 40), 27, Color(0.9, 0.95, 1.0))
        _button("Open Case File", Vector2(515, 480), Vector2(250, 56), Callable(self, "_brief"))
    elif mode == "brief":
        _draw_frame("Case Brief")
        _label("Charge: sabotage of the gala clock.\nSuspect: courier Ivo Vale.\nEvidence tray: broken watch, inked receipt, garden map, brass key.", Vector2(420, 245), Vector2(420, 155), 23)
        _button("Begin Testimony", Vector2(510, 540), Vector2(220, 44), Callable(self, "_testimony"))
    elif mode == "testimony":
        _draw_frame("Witness Testimony")
        _label("Statement %d/4\n\"I never left the balcony after 9:00. I heard the clock strike ten from there.\"", Vector2(420, 245), Vector2(420, 120), 23)
        _label("Evidence selected: " + evidence + "\nBroken Watch: stopped at 9:42, glass wet with fountain water.", Vector2(130, 535), Vector2(520, 68), 19, Color(0.85, 0.96, 1.0))
        _button("Press", Vector2(690, 532), Vector2(120, 40), Callable(self, "_press"))
        _button("Present Watch", Vector2(825, 532), Vector2(150, 40), Callable(self, "_object"))
        _button("Present Map", Vector2(990, 532), Vector2(130, 40), Callable(self, "_wrong"))
    elif mode == "pressed":
        _draw_frame("Pressed Statement")
        _label("The witness adds: \"The fountain path was locked, so nobody could reach the tower.\" The brass key now matters.", Vector2(420, 245), Vector2(420, 120), 23)
        _button("Back to Statement", Vector2(520, 540), Vector2(220, 44), Callable(self, "_testimony"))
    elif mode == "contradiction":
        _draw_frame("Objection")
        _rect(Vector2(410, 232), Vector2(455, 138), Color(0.58, 0.05, 0.04))
        _label("OBJECTION!", Vector2(505, 260), Vector2(270, 50), 42, Color.WHITE)
        _label("The watch stopped at 9:42 near the fountain. The witness could not hear the ten o'clock bell from the balcony.", Vector2(130, 535), Vector2(850, 70), 21)
        _button("Reveal Rebuttal", Vector2(985, 535), Vector2(145, 42), Callable(self, "_rebuttal"))
    elif mode == "wrong":
        credibility = 2
        _draw_frame("Judge Warning")
        _label("The garden map does not contradict this statement. Credibility falls; choose evidence that proves time or location.", Vector2(420, 245), Vector2(420, 120), 23)
        _button("Recover", Vector2(530, 540), Vector2(180, 44), Callable(self, "_testimony"))
    elif mode == "rebuttal":
        _draw_frame("Second Layer")
        _label("New clue: the brass key opens the fountain gate. Presenting it proves the witness used the garden shortcut.", Vector2(420, 245), Vector2(420, 120), 23)
        _button("Present Brass Key", Vector2(500, 540), Vector2(240, 44), Callable(self, "_victory"))
    elif mode == "victory":
        _draw_frame("Verdict")
        _label("NOT GUILTY\nThe alibi collapses. The clock was sabotaged from the fountain path at 9:42.", Vector2(430, 245), Vector2(400, 140), 28, Color(0.62, 1.0, 0.76))
        _button("Retry Case", Vector2(505, 540), Vector2(130, 42), Callable(self, "_brief"))
        _button("Title", Vector2(650, 540), Vector2(130, 42), Callable(self, "_title"))
    elif mode == "fail":
        credibility = 0
        _draw_frame("Mistrial")
        _label("MISTRIAL\nThree unsupported accusations exhausted the court's patience.", Vector2(430, 245), Vector2(400, 140), 28, Color(1.0, 0.55, 0.48))
        _button("Retry", Vector2(505, 540), Vector2(130, 42), Callable(self, "_brief"))
        _button("Title", Vector2(650, 540), Vector2(130, 42), Callable(self, "_title"))

func _title() -> void:
    mode = "title"
    credibility = 3
    _draw()

func _brief() -> void:
    mode = "brief"
    _draw()

func _testimony() -> void:
    mode = "testimony"
    _draw()

func _press() -> void:
    mode = "pressed"
    _draw()

func _object() -> void:
    mode = "contradiction"
    _draw()

func _wrong() -> void:
    mode = "wrong"
    _draw()

func _rebuttal() -> void:
    mode = "rebuttal"
    _draw()

func _victory() -> void:
    mode = "victory"
    _draw()
EOF

cat > "$GAME/demo_outputs/00_title_to_brief.json" <<'EOF'
{"duration_frames":210,"events":[{"frame":30,"type":"mouse_click","button":"left","x":640,"y":508},{"frame":170,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/01_press_testimony.json" <<'EOF'
{"scenario":"testimony","duration_frames":240,"events":[{"frame":35,"type":"mouse_click","button":"left","x":750,"y":552},{"frame":170,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/02_correct_objection.json" <<'EOF'
{"scenario":"testimony","duration_frames":300,"events":[{"frame":35,"type":"mouse_click","button":"left","x":895,"y":552},{"frame":145,"type":"mouse_click","button":"left","x":1055,"y":555},{"frame":260,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/03_wrong_penalty.json" <<'EOF'
{"scenario":"testimony","duration_frames":220,"events":[{"frame":35,"type":"mouse_click","button":"left","x":1045,"y":552},{"frame":180,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/04_fail.json" <<'EOF'
{"scenario":"fail","duration_frames":180,"events":[{"frame":140,"type":"wait"}]}
EOF
