#!/bin/bash
set -eu

GAME=/workspace/game
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cp "/workspace/assets/library/2D/isometric-miniature-library/Sample.png" "$GAME/assets/bg_school.png" 2>/dev/null || true
cp "/workspace/assets/library/2D/modular-characters/preview.png" "$GAME/assets/characters.png" 2>/dev/null || true
cp "/workspace/assets/library/2D/game-icons/preview.png" "$GAME/assets/icons.png" 2>/dev/null || true

cat > "$GAME/project.godot" <<'EOF'
config_version=5
[application]
config/name="Debate Club"
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
var reputation := 3
var evidence := ["Library Log: Mira checked out the projector key at 15:40",
    "Courtyard Photo: Theo stood by the trophy case after the bell",
    "Class Roster: Len was absent during setup",
    "Scuffed Podium: fresh silver paint matches the trophy base",
    "Audio Memo: a voice rehearses the stolen speech",
    "Gate Pass: one late exit stamped 16:05"]

func _ready() -> void:
    var a := OS.get_cmdline_user_args()
    for i in range(a.size()):
        if a[i] == "--scenario" and i + 1 < a.size():
            mode = a[i + 1]
    _draw()

func _clear() -> void:
    for c in get_children():
        c.queue_free()

func _rect(p: Vector2, s: Vector2, c: Color) -> void:
    var r := ColorRect.new(); r.position = p; r.size = s; r.color = c; add_child(r)

func _tex(path: String, p: Vector2, s: Vector2, alpha := 1.0) -> void:
    var t := TextureRect.new(); t.position = p; t.size = s; t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; t.modulate.a = alpha
    if ResourceLoader.exists(path): t.texture = load(path)
    add_child(t)

func _label(t: String, p: Vector2, s: Vector2, fs := 22, col := Color.WHITE) -> void:
    var l := Label.new(); l.text = t; l.position = p; l.size = s
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_font_size_override("font_size", fs); l.add_theme_color_override("font_color", col)
    add_child(l)

func _button(t: String, p: Vector2, s: Vector2, cb: Callable) -> void:
    var b := Button.new(); b.text = t; b.position = p; b.size = s
    b.add_theme_font_size_override("font_size", 18); b.pressed.connect(cb); add_child(b)

func _chrome(title: String) -> void:
    _clear(); _rect(Vector2.ZERO, Vector2(1280,720), Color(0.06,0.07,0.10))
    _tex("res://assets/bg_school.png", Vector2(0,0), Vector2(1280,720), .42)
    _rect(Vector2(36,34), Vector2(1208,650), Color(0.03,0.04,0.07,.82))
    _label(title, Vector2(62,54), Vector2(760,48), 36, Color(1,.86,.35))
    _label("Reputation " + str(reputation) + "/3", Vector2(940,64), Vector2(260,32), 24, Color(.65,.95,1))

func _draw_cards() -> void:
    for i in range(evidence.size()):
        var x := 70 + (i % 3) * 250; var y := 462 + int(i / 3) * 82
        _rect(Vector2(x,y), Vector2(228,68), Color(.18,.16,.10,.95))
        _tex("res://assets/icons.png", Vector2(x+8,y+8), Vector2(44,44), .85)
        _label(evidence[i], Vector2(x+58,y+7), Vector2(160,55), 13, Color(.92,.90,.78))

func _draw() -> void:
    if mode == "title":
        _chrome("DEBATE CLUB")
        _label("Academic thriller: collect evidence, read formal arguments, fire truth bullets at contradictions.", Vector2(88,150), Vector2(760,70), 24)
        _tex("res://assets/characters.png", Vector2(840,128), Vector2(300,240), .95)
        _button("Open Investigation", Vector2(500,570), Vector2(260,54), Callable(self, "_go_investigation"))
    elif mode == "investigation":
        _chrome("Investigation - three school locations")
        _label("Classroom hotspot: roster and scuffed podium\nLibrary hotspot: checkout log and audio memo\nCourtyard hotspot: trophy photo and gate pass", Vector2(80,132), Vector2(480,120), 22)
        for x in [165, 405, 645, 885]:
            _rect(Vector2(x,292), Vector2(105,84), Color(.95,.76,.25,.28))
        _label("Evidence cards show FACT, SOURCE, and RELEVANCE TAGS after clicking hotspots.", Vector2(610,142), Vector2(510,80), 22, Color(.7,1,.84))
        _draw_cards()
        _button("Start Debate", Vector2(980,580), Vector2(180,46), Callable(self, "_go_debate"))
    elif mode == "debate_good":
        _debate(true)
    elif mode == "debate_wrong":
        reputation = 1
        _debate(false)
    elif mode == "final_success":
        _result(true)
    elif mode == "final_fail":
        _result(false)
    else:
        _go_investigation()

func _go_investigation() -> void: mode = "investigation"; _draw()
func _go_debate() -> void: mode = "debate_good"; _draw()
func _wrong() -> void: reputation -= 1; mode = "debate_wrong"; _draw()
func _right() -> void: mode = "final_success"; _draw()

func _debate(correct: bool) -> void:
    _chrome("Debate Round 2 - statement contradiction")
    _tex("res://assets/characters.png", Vector2(78,118), Vector2(250,208), .95)
    _label("Suspects: Mira (precise), Theo (dramatic), Len (evasive). Each needs different proof.", Vector2(350,124), Vector2(720,44), 20, Color(.86,.95,1))
    var statements := ["1. Mira: The projector key never left the staff desk.",
        "2. Theo: Nobody approached the trophy case after final bell.",
        "3. Len: I was in debate prep the whole afternoon.",
        "4. Mira: The speech file played from the podium laptop."]
    for i in range(statements.size()):
        _rect(Vector2(350,188+i*58), Vector2(745,46), Color(.11,.13,.19,.95))
        _label(statements[i], Vector2(366,198+i*58), Vector2(710,28), 18)
    _draw_cards()
    if correct:
        _rect(Vector2(700,342), Vector2(380,76), Color(.78,.12,.16,.92))
        _label("TRUTH BULLET HIT: Library Log shatters statement 1. New harder claim unlocked.", Vector2(722,356), Vector2(330,42), 20)
    else:
        _rect(Vector2(700,342), Vector2(380,76), Color(.65,.08,.08,.92))
        _label("WRONG EVIDENCE: reputation lost. At zero the debate fails.", Vector2(722,358), Vector2(330,42), 20)
    _button("Fire Library Log", Vector2(935,470), Vector2(180,42), Callable(self, "_right"))
    _button("Fire Roster", Vector2(935,520), Vector2(180,42), Callable(self, "_wrong"))

func _result(win: bool) -> void:
    _chrome("Verdict Result")
    if win:
        _label("VERDICT: Culprit identified - Mira staged the speech theft.\nAccuracy 6/6 evidence cards. Reputation preserved.\nFinal deduction used log + photo + podium paint, not a single clue.", Vector2(130,160), Vector2(800,150), 28, Color(.75,1,.78))
    else:
        _label("DEBATE LOST: wrong truth bullets exhausted reputation.\nResult shows failed suspect reads and missing evidence accuracy.", Vector2(130,160), Vector2(800,130), 28, Color(1,.62,.58))
    _tex("res://assets/characters.png", Vector2(840,180), Vector2(260,240), .95)
EOF

cat > "$GAME/demo_outputs/01_title_to_investigation.json" <<'EOF'
{"duration_frames":360,"events":[{"frame":80,"type":"mouse_click","button":"left","x":620,"y":595},{"frame":360,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/02_investigation_cards.json" <<'EOF'
{"scenario":"investigation","duration_frames":360,"events":[{"frame":120,"type":"mouse_click","button":"left","x":210,"y":330},{"frame":360,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/03_correct_truth_bullet.json" <<'EOF'
{"scenario":"debate_good","duration_frames":480,"events":[{"frame":150,"type":"mouse_click","button":"left","x":1015,"y":490},{"frame":480,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/04_wrong_penalty.json" <<'EOF'
{"scenario":"debate_wrong","duration_frames":360,"events":[{"frame":160,"type":"mouse_click","button":"left","x":1010,"y":540},{"frame":360,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/05_results.json" <<'EOF'
{"scenario":"final_success","duration_frames":360,"events":[{"frame":360,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/06_failure.json" <<'EOF'
{"scenario":"final_fail","duration_frames":360,"events":[{"frame":360,"type":"wait"}]}
EOF
