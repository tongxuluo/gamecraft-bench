#!/bin/bash
set -eu

GAME=/workspace/game
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5
[application]
config/name="Creature Clinic Triage"
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
var selected := "Ember Kit"
var reputation := 72

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

func _label(t: String, p: Vector2, s: Vector2, fs := 21, c := Color.WHITE) -> void:
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

func _patient(p, name, sym, hp, col):
    _rect(p, Vector2(245,82), Color(0.14,0.18,0.17)); _rect(p+Vector2(12,12), Vector2(52,52), col)
    _label(name, p+Vector2(76,8), Vector2(150,24), 20, Color(1,0.86,0.44)); _label(sym, p+Vector2(76,34), Vector2(150,36), 15)
    _rect(p+Vector2(12,68), Vector2(210,6), Color(0.35,0.07,0.05)); _rect(p+Vector2(12,68), Vector2(210*hp,6), Color(0.3,0.9,0.55))

func _station(p, name, busy, col):
    _rect(p, Vector2(150,92), col); _label(name+"\n"+busy, p+Vector2(12,14), Vector2(125,56), 18, Color(0.02,0.03,0.03))

func _floor(title):
    _clear(); _rect(Vector2.ZERO, Vector2(1280,720), Color(0.07,0.11,0.10)); _rect(Vector2(40,35), Vector2(1200,76), Color(0.13,0.24,0.21))
    _label(title, Vector2(65,52), Vector2(520,42), 34, Color(0.7,1,0.82)); _label("Shift 2  Reputation %d  Supplies 8  Waiting 4" % reputation, Vector2(700,58), Vector2(450,30), 21)
    _rect(Vector2(55,135), Vector2(310,500), Color(0.10,0.14,0.13)); _label("TRIAGE QUEUE", Vector2(82,155), Vector2(210,28), 24, Color(1,0.86,0.44))
    _patient(Vector2(82,200), "Ember Kit", "singed wings | urgent", 0.46, Color(1,0.33,0.16))
    _patient(Vector2(82,295), "Moss Snail", "cracked shell", 0.72, Color(0.44,0.86,0.38))
    _patient(Vector2(82,390), "Glimmer Bat", "fever glow", 0.58, Color(0.58,0.54,1))
    _patient(Vector2(82,485), "Thorn Pup", "barbed paw", 0.83, Color(0.85,0.65,0.38))
    _rect(Vector2(410,135), Vector2(500,500), Color(0.12,0.16,0.15)); _label("Selected: "+selected, Vector2(440,158), Vector2(330,28), 25, Color(1,0.86,0.44))
    _label("Symptoms: soot, wing tremor, panic chirp\nScanner hint: heat stress + torn membrane\nRecommended: cool wash, wing splint, recovery cot", Vector2(440,202), Vector2(390,104), 20)
    _station(Vector2(440,335), "Scanner", "ready", Color(0.35,0.72,0.82)); _station(Vector2(615,335), "Herb Mixer", "cooldown", Color(0.45,0.68,0.32)); _station(Vector2(790,335), "Wash Basin", "ready", Color(0.35,0.58,0.92))
    _station(Vector2(440,460), "Splint Table", "ready", Color(0.82,0.64,0.36)); _station(Vector2(615,460), "Recovery Cot", "occupied", Color(0.72,0.48,0.72)); _station(Vector2(790,460), "Isolation", "empty", Color(0.78,0.38,0.36))
    _rect(Vector2(945,135), Vector2(270,500), Color(0.15,0.19,0.17)); _label("CARE LOG", Vector2(985,158), Vector2(180,28), 24, Color(1,0.86,0.44))

func _draw():
    if mode=="title":
        _clear(); _rect(Vector2.ZERO, Vector2(1280,720), Color(0.07,0.12,0.10)); _rect(Vector2(190,100), Vector2(900,420), Color(0.13,0.25,0.21))
        for x in [320, 470, 620, 770, 920]:
            _rect(Vector2(x, 330), Vector2(80, 70), Color(0.35 + float(x % 2) * 0.2, 0.65, 0.48))
        _label("CREATURE CLINIC TRIAGE", Vector2(285,155), Vector2(720,70), 48, Color(0.72,1,0.82))
        _label("Diagnose strange patients, route stations, and survive the shift.", Vector2(330,245), Vector2(620,48), 24)
        _button("Start Shift", Vector2(535,460), Vector2(210,54), Callable(self,"_admit"))
    elif mode=="admission":
        _floor("Admission And Diagnosis"); _label("Urgent case selected. Choose scanner or treatment station.", Vector2(980,205), Vector2(190,80), 18); _button("Scan Patient", Vector2(988,320), Vector2(170,40), Callable(self,"_diagnosis"))
    elif mode=="diagnosis":
        _floor("Diagnosis"); _label("Scanner confirms heat stress. Wrong herb mix worsens fever; wash basin stabilizes first.", Vector2(980,205), Vector2(190,95), 18); _button("Send To Wash", Vector2(988,320), Vector2(170,40), Callable(self,"_treat")); _button("Wrong Herb", Vector2(988,372), Vector2(170,40), Callable(self,"_wrong"))
    elif mode=="treat":
        reputation=84; _floor("Treatment Success"); _label("Wash basin cooled the wings. Splint table queued next; recovery cot frees in 12s.", Vector2(980,205), Vector2(190,90), 18); _button("Shift Result", Vector2(988,520), Vector2(170,40), Callable(self,"_success"))
    elif mode=="wrong":
        reputation=55; _floor("Wrong Treatment"); _label("Herb mix irritated the burn. Health dropped and the next patient deteriorated.", Vector2(980,205), Vector2(190,90), 18)
    elif mode=="emergency":
        _floor("Outbreak Emergency"); _label("Two fever-glow patients arrive. Isolation has one bed; scanner and recovery cot are occupied.", Vector2(980,205), Vector2(190,110), 18)
    elif mode=="success":
        _clear(); _rect(Vector2.ZERO, Vector2(1280,720), Color(0.06,0.12,0.09)); _rect(Vector2(260,145), Vector2(760,410), Color(0.13,0.25,0.18)); _label("SHIFT COMPLETE", Vector2(430,205), Vector2(440,60), 44, Color(0.72,1,0.82)); _label("Treated 8 | Waiting 1 | Failed 0 | Reputation 84\nUpgrade unlocked: second recovery cot.", Vector2(390,300), Vector2(500,95), 25); _button("Retry", Vector2(515,455), Vector2(120,42), Callable(self,"_admit")); _button("Title", Vector2(650,455), Vector2(120,42), Callable(self,"_title"))
    elif mode=="fail":
        _clear(); _rect(Vector2.ZERO, Vector2(1280,720), Color(0.12,0.05,0.05)); _rect(Vector2(260,145), Vector2(760,410), Color(0.26,0.10,0.08)); _label("SHIFT FAILED", Vector2(445,205), Vector2(390,60), 44, Color(1,0.62,0.50)); _label("Three patients deteriorated while stations jammed. Reputation fell below safe practice.", Vector2(390,310), Vector2(500,75), 24); _button("Retry", Vector2(580,455), Vector2(120,42), Callable(self,"_admit"))
func _title() -> void:
    mode = "title"
    reputation = 72
    _draw()

func _admit() -> void:
    mode = "admission"
    _draw()

func _diagnosis() -> void:
    mode = "diagnosis"
    _draw()

func _treat() -> void:
    mode = "treat"
    _draw()

func _wrong() -> void:
    mode = "wrong"
    _draw()

func _success() -> void:
    mode = "success"
    _draw()
EOF
cat > "$GAME/demo_outputs/00_title.json" <<'EOF'
{"duration_frames":210,"events":[{"frame":30,"type":"mouse_click","button":"left","x":640,"y":488},{"frame":170,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/01_diagnose_treat.json" <<'EOF'
{"scenario":"admission","duration_frames":330,"events":[{"frame":30,"type":"mouse_click","button":"left","x":1065,"y":340},{"frame":120,"type":"mouse_click","button":"left","x":1065,"y":340},{"frame":245,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/02_wrong.json" <<'EOF'
{"scenario":"diagnosis","duration_frames":220,"events":[{"frame":40,"type":"mouse_click","button":"left","x":1065,"y":392},{"frame":170,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/03_emergency.json" <<'EOF'
{"scenario":"emergency","duration_frames":210,"events":[{"frame":170,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/04_results.json" <<'EOF'
{"scenario":"success","duration_frames":180,"events":[{"frame":140,"type":"wait"}]}
EOF
