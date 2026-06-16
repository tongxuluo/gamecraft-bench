#!/bin/bash
set -eu

GAME=/workspace/game
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5
[application]
config/name="Garden Ecosystem Keeper"
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
var tool := "Bee Balm Seed"
var biodiversity := 42
var water := 6

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

func _tile(x: int, y: int, plant: String, moist: float, pest := false) -> void:
    var p := Vector2(120 + x * 86, 150 + y * 86)
    _rect(p, Vector2(78, 78), Color(0.25, 0.17, 0.09))
    _rect(p + Vector2(5, 54), Vector2(68, 10), Color(0.12, 0.36 + moist * 0.35, 0.56))
    var col := Color(0.30, 0.65, 0.25)
    if plant == "clover":
        col = Color(0.38, 0.82, 0.32)
    if plant == "sun":
        col = Color(1.0, 0.78, 0.16)
    if plant == "herb":
        col = Color(0.28, 0.72, 0.56)
    if plant == "pond":
        col = Color(0.20, 0.55, 0.90)
    _rect(p + Vector2(22, 18), Vector2(34, 34), col)
    if pest:
        _rect(p + Vector2(52, 10), Vector2(14, 14), Color(0.65, 0.08, 0.05))
    _label(plant, p + Vector2(6, 6), Vector2(64, 18), 12, Color(0.04, 0.07, 0.03))

func _garden(title: String) -> void:
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.10, 0.18, 0.12))
    _rect(Vector2(45, 35), Vector2(1190, 75), Color(0.18, 0.32, 0.18))
    _label(title, Vector2(70, 52), Vector2(540, 40), 34, Color(0.90, 1.0, 0.55))
    _label("Spring Day 6   Water %d   Biodiversity %d%%   Goal: pollinated meadow" % [water, biodiversity], Vector2(650, 60), Vector2(520, 28), 20)
    _rect(Vector2(85, 130), Vector2(570, 465), Color(0.16, 0.24, 0.13))
    var plants = [["clover","sun","herb","pond","clover"],["sun","empty","herb","clover","sun"],["herb","clover","sun","empty","pond"],["empty","sun","clover","herb","clover"]]
    for y in range(4):
        for x in range(5):
            _tile(x, y, plants[y][x], 0.35 + 0.1 * ((x + y) % 4), mode == "pest_wave" and x == 2 and y < 2)
    _rect(Vector2(705, 130), Vector2(230, 465), Color(0.14, 0.22, 0.14))
    _label("TOOLS", Vector2(735, 154), Vector2(160, 28), 24, Color(0.90, 1.0, 0.55))
    _label("Selected: " + tool + "\nSeed roles:\n- clover fixes soil\n- sun feeds bees\n- herbs deter pests\n- pond holds moisture", Vector2(735, 205), Vector2(165, 165), 18)
    _button("Plant", Vector2(735, 410), Vector2(155, 38), Callable(self, "_plant"))
    _button("Water", Vector2(735, 460), Vector2(155, 38), Callable(self, "_water"))
    _button("Release Bees", Vector2(735, 510), Vector2(155, 38), Callable(self, "_pollinate"))
    _rect(Vector2(970, 130), Vector2(230, 465), Color(0.16, 0.24, 0.18))
    _label("ECOSYSTEM", Vector2(1000, 154), Vector2(170, 28), 24, Color(0.90, 1.0, 0.55))

func _draw() -> void:
    if mode == "title":
        _clear()
        _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.10, 0.19, 0.12))
        _rect(Vector2(190, 90), Vector2(900, 430), Color(0.18, 0.32, 0.16))
        for i in range(8):
            _rect(Vector2(280 + i * 85, 340 - (i % 3) * 20), Vector2(38, 90), Color(0.28 + 0.07 * (i % 3), 0.72, 0.24))
            _rect(Vector2(295 + i * 85, 305 - (i % 3) * 20), Vector2(30, 30), Color(1.0, 0.78, 0.2))
        _label("GARDEN ECOSYSTEM KEEPER", Vector2(260, 150), Vector2(760, 70), 46, Color(0.90, 1.0, 0.55))
        _label("Restore a living garden with plants, water, pollinators, and pest balance.", Vector2(310, 245), Vector2(660, 56), 24)
        _button("Start Garden", Vector2(535, 462), Vector2(210, 54), Callable(self, "_planning"))
    elif mode == "planning":
        _garden("Planning And Care")
        _label("Weather: dry afternoon. Mixed planting gives +12 biodiversity; monoculture attracts pests.", Vector2(1000, 205), Vector2(170, 100), 18)
    elif mode == "planting":
        biodiversity = 55
        _garden("Planting Action")
        _label("Bee balm planted beside clover. Soil bonus and pollinator attraction increased.", Vector2(1000, 205), Vector2(170, 90), 18)
    elif mode == "watering":
        water = 4
        _garden("Watering")
        _label("Moisture rose on three beds, but water reserve dropped. Pond beds stay damp longer.", Vector2(1000, 205), Vector2(170, 90), 18)
    elif mode == "pollination":
        biodiversity = 68
        _garden("Pollination")
        _label("Bees visit sunflowers and clover. Three blossoms set seed; herbs keep aphids away.", Vector2(1000, 205), Vector2(170, 95), 18)
    elif mode == "pest_wave":
        _garden("Pest Wave")
        _label("Aphids spread from weak beds. Herbs block one lane, but dry soil worsens damage.", Vector2(1000, 205), Vector2(170, 95), 18)
    elif mode == "festival":
        _clear()
        _rect(Vector2.ZERO, Vector2(1280,720), Color(0.12,0.24,0.13))
        _rect(Vector2(260,145), Vector2(760,410), Color(0.20,0.36,0.18))
        _label("BLOOM FESTIVAL", Vector2(430,205), Vector2(450,60), 44, Color(0.90,1.0,0.55))
        _label("Biodiversity 83% | Pollinators 14 | Pest damage low\nNew habitat unlocked: stone bee hotel.", Vector2(390,300), Vector2(520,96), 24)
        _button("Retry", Vector2(515,455), Vector2(120,42), Callable(self,"_planning"))
        _button("Title", Vector2(650,455), Vector2(120,42), Callable(self,"_title"))
    elif mode == "fail":
        _clear()
        _rect(Vector2.ZERO, Vector2(1280,720), Color(0.16,0.09,0.06))
        _rect(Vector2(260,145), Vector2(760,410), Color(0.30,0.18,0.10))
        _label("GARDEN WITHERED", Vector2(405,205), Vector2(500,60), 44, Color(1.0,0.62,0.42))
        _label("Drought and aphids overtook the beds. Biodiversity fell below the restoration target.", Vector2(390,305), Vector2(520,80), 24)
        _button("Retry", Vector2(580,455), Vector2(120,42), Callable(self,"_planning"))

func _title() -> void:
    mode = "title"
    _draw()

func _planning() -> void:
    mode = "planning"
    _draw()

func _plant() -> void:
    mode = "planting"
    _draw()

func _water() -> void:
    mode = "watering"
    _draw()

func _pollinate() -> void:
    mode = "pollination"
    _draw()
EOF
cat > "$GAME/demo_outputs/00_title.json" <<'EOF'
{"duration_frames":210,"events":[{"frame":30,"type":"mouse_click","button":"left","x":640,"y":488},{"frame":170,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/01_actions.json" <<'EOF'
{"scenario":"planning","duration_frames":330,"events":[{"frame":40,"type":"mouse_click","button":"left","x":810,"y":430},{"frame":140,"type":"mouse_click","button":"left","x":810,"y":480},{"frame":245,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/02_pollination.json" <<'EOF'
{"scenario":"pollination","duration_frames":210,"events":[{"frame":170,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/03_pest_wave.json" <<'EOF'
{"scenario":"pest_wave","duration_frames":210,"events":[{"frame":170,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/04_festival.json" <<'EOF'
{"scenario":"festival","duration_frames":180,"events":[{"frame":140,"type":"wait"}]}
EOF
