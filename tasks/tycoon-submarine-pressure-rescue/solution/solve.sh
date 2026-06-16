#!/bin/bash
set -eu

GAME=/workspace/game
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5
[application]
config/name="Submarine Pressure Rescue"
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

var mode := "title"
var hull := 68
var oxygen := 74
var power := 5

func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            mode = args[i + 1]
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

func _label(t: String, p: Vector2, s: Vector2, fs := 20, c := Color.WHITE) -> void:
    var l := Label.new()
    l.text = t
    l.position = p
    l.size = s
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_font_size_override("font_size", fs)
    l.add_theme_color_override("font_color", c)
    add_child(l)

func _button(t: String, p: Vector2, s: Vector2, cb: Callable) -> void:
    var b := Button.new()
    b.text = t
    b.position = p
    b.size = s
    b.add_theme_font_size_override("font_size", 18)
    b.pressed.connect(cb)
    add_child(b)

func _room(i: int, name: String, water: float, crew: String, warn := false) -> void:
    var p := Vector2(100 + i * 160, 240)
    _rect(p, Vector2(145, 170), Color(0.10, 0.14, 0.17))
    _rect(p, Vector2(145, 170 * water), Color(0.04, 0.25, 0.46))
    if warn:
        _rect(p + Vector2(108, 12), Vector2(18, 18), Color(1.0, 0.12, 0.06))
    _label(name, p + Vector2(12, 16), Vector2(118, 26), 18, Color(0.75, 0.95, 1.0))
    _label(crew, p + Vector2(12, 118), Vector2(118, 42), 16)

func _sub(title: String) -> void:
    _clear()
    _rect(Vector2.ZERO, Vector2(1280,720), Color(0.02,0.06,0.09))
    _rect(Vector2(45,35), Vector2(1190,78), Color(0.06,0.13,0.18))
    _label(title, Vector2(70,52), Vector2(560,42), 34, Color(0.55,0.88,1.0))
    _label("Hull %d%%  Oxygen %d%%  Power %d/8  Beacon 1.8km" % [hull, oxygen, power], Vector2(690,60), Vector2(500,28), 20)
    _rect(Vector2(70,205), Vector2(900,245), Color(0.16,0.20,0.23))
    for i in range(6):
        var names := ["Bridge","Sonar","Pump","Med","Engine","Airlock"]
        _room(i, names[i], 0.08 + 0.08 * (i % 3), "Crew " + str(i + 1), mode == "leak_drill" and i == 2)
    _rect(Vector2(995,135), Vector2(220,500), Color(0.05,0.11,0.15))
    _label("COMMANDS", Vector2(1028,158), Vector2(160,28), 24, Color(0.55,0.88,1.0))
    _button("Patch Leak", Vector2(1028,210), Vector2(150,38), Callable(self,"_patch"))
    _button("Route Power", Vector2(1028,260), Vector2(150,38), Callable(self,"_power"))
    _button("Close Door", Vector2(1028,310), Vector2(150,38), Callable(self,"_door"))
    _button("Ping Sonar", Vector2(1028,360), Vector2(150,38), Callable(self,"_sonar"))
    _rect(Vector2(110,485), Vector2(780,120), Color(0.04,0.09,0.12))

func _draw() -> void:
    if mode == "title":
        _clear()
        _rect(Vector2.ZERO, Vector2(1280,720), Color(0.02,0.05,0.08))
        _rect(Vector2(180,130), Vector2(920,250), Color(0.08,0.16,0.20))
        _rect(Vector2(300,250), Vector2(680,70), Color(0.16,0.22,0.25))
        for x in [380, 500, 620, 740, 860]:
            _rect(Vector2(x, 268), Vector2(42, 32), Color(0.55, 0.88, 1.0))
        _label("SUBMARINE PRESSURE RESCUE", Vector2(255,155), Vector2(780,70), 46, Color(0.55,0.88,1.0))
        _label("Patch compartments, route power, and reach the rescue beacon.", Vector2(350,410), Vector2(580,50), 24)
        _button("Dive", Vector2(545,500), Vector2(190,54), Callable(self,"_brief"))
    elif mode == "briefing":
        _sub("Mission Briefing")
        _label("Rescue beacon detected beyond a trench. Pump room has seepage; engine needs power. Keep oxygen above 30%.", Vector2(130,505), Vector2(700,70), 22)
    elif mode == "leak_drill":
        _sub("Damage Control")
        _label("Pump room leak is rising. Assign crew to patch or close doors before pressure spreads.", Vector2(130,505), Vector2(700,70), 22)
    elif mode == "patched":
        hull = 76
        _sub("Leak Patched")
        _label("Crew patched the pump room. Water level drops, hull stabilizes, but power is still scarce.", Vector2(130,505), Vector2(700,70), 22)
    elif mode == "power_failure":
        power = 2
        oxygen = 55
        _sub("Power Failure")
        _label("Only two power cells remain. Sonar and pump cannot run together; choose rescue route or flooding control.", Vector2(130,505), Vector2(700,70), 22)
    elif mode == "sonar_rescue":
        _sub("Sonar Rescue")
        _label("SONAR SWEEP: beacon at 030 degrees, wreckage hazard port side, safe trench opens in 40 seconds.", Vector2(130,505), Vector2(700,70), 22)
        _rect(Vector2(700,505), Vector2(110,70), Color(0.0,0.35,0.50))
        _rect(Vector2(750,525), Vector2(16,16), Color(0.8,1.0,1.0))
    elif mode == "near_success":
        _clear(); _rect(Vector2.ZERO, Vector2(1280,720), Color(0.03,0.09,0.11)); _rect(Vector2(260,145), Vector2(760,410), Color(0.07,0.18,0.20)); _label("RESCUE COMPLETE", Vector2(410,205), Vector2(500,60), 44, Color(0.55,0.88,1.0)); _label("Beacon reached. Hull 61% | Crew 6/6 | Survivors evacuated 12.", Vector2(390,305), Vector2(520,80), 24); _button("Retry", Vector2(515,455), Vector2(120,42), Callable(self,"_brief")); _button("Title", Vector2(650,455), Vector2(120,42), Callable(self,"_title"))
    elif mode == "near_collapse":
        _clear(); _rect(Vector2.ZERO, Vector2(1280,720), Color(0.12,0.03,0.04)); _rect(Vector2(260,145), Vector2(760,410), Color(0.24,0.06,0.06)); _label("HULL COLLAPSE", Vector2(430,205), Vector2(450,60), 44, Color(1.0,0.45,0.42)); _label("Flooding overtook engine and airlock before evacuation could finish.", Vector2(390,305), Vector2(520,80), 24); _button("Retry", Vector2(580,455), Vector2(120,42), Callable(self,"_brief"))

func _title() -> void:
    mode = "title"
    _draw()

func _brief() -> void:
    mode = "briefing"
    _draw()

func _patch() -> void:
    mode = "patched"
    _draw()

func _power() -> void:
    mode = "power_failure"
    _draw()

func _door() -> void:
    mode = "leak_drill"
    _draw()

func _sonar() -> void:
    mode = "sonar_rescue"
    _draw()
EOF
cat > "$GAME/demo_outputs/00_title.json" <<'EOF'
{"duration_frames":210,"events":[{"frame":30,"type":"mouse_click","button":"left","x":640,"y":528},{"frame":170,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/01_leak_patch.json" <<'EOF'
{"scenario":"leak_drill","duration_frames":270,"events":[{"frame":40,"type":"mouse_click","button":"left","x":1100,"y":230},{"frame":205,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/02_power.json" <<'EOF'
{"scenario":"power_failure","duration_frames":210,"events":[{"frame":170,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/03_sonar.json" <<'EOF'
{"scenario":"sonar_rescue","duration_frames":210,"events":[{"frame":170,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/04_results.json" <<'EOF'
{"scenario":"near_success","duration_frames":180,"events":[{"frame":140,"type":"wait"}]}
EOF
