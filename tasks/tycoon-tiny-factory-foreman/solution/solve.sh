#!/bin/bash
set -eu

GAME=/workspace/game
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5
[application]
config/name="Tiny Factory Foreman"
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
var playing := false
var timer := 70.0
var coins := 0
var fulfilled := 0
var missed := 0
var sorter_to_gears := true
var machine_speed := 1.0
var message := "Order: 3 gears and 2 circuits before the shift timer ends."
var items := []
var spawn_t := 0.0

func _ready() -> void:
    _parse_args()
    if scenario == "":
        _show_title()
    elif scenario == "upgrade_shop":
        _show_upgrade()
    elif scenario == "near_result":
        fulfilled = 5
        coins = 32
        missed = 1
        _show_result()
    else:
        _start_floor()

func _parse_args() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]

func _clear() -> void:
    for child in get_children():
        child.queue_free()

func _rect(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
    var r := ColorRect.new()
    r.position = pos
    r.size = size
    r.color = color
    add_child(r)
    return r

func _label(text: String, pos: Vector2, size: Vector2, fs := 22, color := Color.WHITE) -> Label:
    var l := Label.new()
    l.text = text
    l.position = pos
    l.size = size
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_font_size_override("font_size", fs)
    l.add_theme_color_override("font_color", color)
    l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
    l.add_theme_constant_override("shadow_offset_x", 2)
    l.add_theme_constant_override("shadow_offset_y", 2)
    add_child(l)
    return l

func _button(text: String, pos: Vector2, size: Vector2, cb: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.position = pos
    b.size = size
    b.add_theme_font_size_override("font_size", 19)
    b.pressed.connect(cb)
    add_child(b)
    return b

func _show_title() -> void:
    playing = false
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.07, 0.075, 0.07))
    _rect(Vector2(80, 78), Vector2(1120, 520), Color(0.12, 0.13, 0.12))
    for i in range(7):
        _rect(Vector2(230 + i * 100, 390), Vector2(86, 28), Color(0.30, 0.34, 0.34))
        _rect(Vector2(258 + i * 100, 424), Vector2(30, 42), Color(0.58, 0.61, 0.58))
    _rect(Vector2(480, 280), Vector2(105, 92), Color(0.22, 0.42, 0.55))
    _rect(Vector2(685, 278), Vector2(115, 94), Color(0.55, 0.33, 0.18))
    _label("TINY FACTORY FOREMAN", Vector2(245, 132), Vector2(800, 68), 50, Color(1.0, 0.84, 0.38))
    _label("Build a compact line, route materials, and fulfill the order board.", Vector2(250, 220), Vector2(790, 60), 27, Color(0.88, 0.92, 0.86))
    _label("Animated belts - sorters - assemblers - shift report", Vector2(350, 505), Vector2(610, 35), 22, Color(0.62, 0.9, 1.0))
    _button("Start Order", Vector2(520, 555), Vector2(240, 58), Callable(self, "_start_floor"))

func _start_floor() -> void:
    playing = true
    timer = 70.0
    coins = 0
    fulfilled = 0
    missed = 0
    spawn_t = 0.0
    sorter_to_gears = scenario != "sorter_split"
    machine_speed = 1.0
    message = "Iron feeds gear press; copper feeds circuit bench. Click sorter to reroute."
    items = [
        {"kind":"ore", "pos":Vector2(185, 305), "stage":0, "color":Color(0.75,0.50,0.32)},
        {"kind":"copper", "pos":Vector2(185, 425), "stage":0, "color":Color(1.0,0.55,0.25)}
    ]
    _draw_floor()

func _draw_floor() -> void:
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.08, 0.09, 0.085))
    _rect(Vector2(28, 26), Vector2(1224, 86), Color(0.13, 0.145, 0.13))
    _label("Order: 3 Gears + 2 Circuits   Timer %.0fs   Fulfilled %d   Coins $%d" % [timer, fulfilled, coins], Vector2(55, 44), Vector2(820, 32), 23, Color(1.0, 0.84, 0.38))
    _label("Line status: %s" % message, Vector2(55, 76), Vector2(850, 26), 19, Color(0.88, 0.92, 0.86))
    _button("Toggle Sorter", Vector2(930, 42), Vector2(155, 32), Callable(self, "_toggle_sorter"))
    _button("Upgrade", Vector2(1100, 42), Vector2(115, 32), Callable(self, "_show_upgrade"))
    _button("Report", Vector2(1100, 78), Vector2(115, 32), Callable(self, "_show_result"))

    _rect(Vector2(48, 132), Vector2(900, 520), Color(0.12, 0.13, 0.12))
    for x in range(110, 865, 84):
        _belt(Vector2(x, 310), true)
        _belt(Vector2(x, 430), true)
    _machine(Vector2(465, 246), "GEAR\nPRESS", Color(0.22, 0.42, 0.55))
    _machine(Vector2(470, 486), "CIRCUIT\nBENCH", Color(0.30, 0.48, 0.28))
    _sorter(Vector2(360, 354))
    _source(Vector2(110, 260), "IRON")
    _source(Vector2(110, 382), "COPPER")
    _bin(Vector2(790, 260), "Gear Bin", Color(0.62, 0.70, 0.74))
    _bin(Vector2(790, 500), "Circuit Bin", Color(0.42, 0.83, 0.48))
    for it in items:
        _item(it)

    _rect(Vector2(970, 132), Vector2(250, 520), Color(0.15, 0.16, 0.145))
    _label("ORDER BOARD", Vector2(1000, 155), Vector2(190, 30), 24, Color(1.0, 0.84, 0.38))
    _label("Materials:\n- Iron ore -> Gear\n- Copper -> Circuit\n- Packed crates -> Coin\n\nPressure:\nTimer drains, jams flash red, fulfilled orders pay coins.", Vector2(1000, 205), Vector2(190, 245), 19)
    _label("Sorter route:\n%s" % ["Ore to gear press\nCopper to circuit bench" if sorter_to_gears else "Copper priority lane\nOre held at buffer"], Vector2(1000, 480), Vector2(195, 80), 19, Color(0.62, 0.9, 1.0))

func _belt(pos: Vector2, right: bool) -> void:
    _rect(pos, Vector2(70, 30), Color(0.28, 0.31, 0.31))
    _label(">>" if right else "<<", pos + Vector2(18, 4), Vector2(40, 20), 16, Color(0.78, 0.82, 0.78))

func _machine(pos: Vector2, name: String, color: Color) -> void:
    _rect(pos, Vector2(120, 100), color)
    _rect(pos + Vector2(12, 68), Vector2(96, 12), Color(1.0, 0.84, 0.38))
    _label(name, pos + Vector2(16, 20), Vector2(92, 45), 18)

func _sorter(pos: Vector2) -> void:
    _rect(pos, Vector2(80, 80), Color(0.62, 0.48, 0.20))
    _label("SORT\n%s" % ["GEAR" if sorter_to_gears else "CIRCUIT"], pos + Vector2(13, 15), Vector2(60, 45), 16, Color(0.05, 0.04, 0.02))

func _source(pos: Vector2, name: String) -> void:
    _rect(pos, Vector2(90, 70), Color(0.26, 0.23, 0.20))
    _label(name, pos + Vector2(14, 20), Vector2(70, 24), 17, Color(1.0, 0.84, 0.38))

func _bin(pos: Vector2, name: String, color: Color) -> void:
    _rect(pos, Vector2(125, 80), color)
    _label(name, pos + Vector2(12, 20), Vector2(100, 36), 17, Color(0.03, 0.04, 0.04))

func _item(it: Dictionary) -> void:
    _rect(it["pos"] - Vector2(13, 13), Vector2(26, 26), it["color"])
    _label(it["kind"].substr(0, 1).to_upper(), it["pos"] - Vector2(7, 10), Vector2(20, 20), 14, Color.BLACK)

func _toggle_sorter() -> void:
    sorter_to_gears = not sorter_to_gears
    message = "Sorter diverter moved: item paths now split by recipe priority."
    _draw_floor()

func _process(delta: float) -> void:
    if not playing:
        return
    timer -= delta
    spawn_t -= delta
    if timer <= 0:
        _show_result()
        return
    if spawn_t <= 0:
        spawn_t = 2.4
        items.append({"kind":"ore", "pos":Vector2(185, 305), "stage":0, "color":Color(0.75,0.50,0.32)})
        items.append({"kind":"copper", "pos":Vector2(185, 425), "stage":0, "color":Color(1.0,0.55,0.25)})
    for it in items:
        var p: Vector2 = it["pos"]
        p.x += 76.0 * machine_speed * delta
        if it["kind"] == "ore" and p.x > 520 and p.y < 360:
            it["kind"] = "gear"
            it["color"] = Color(0.62, 0.70, 0.74)
            message = "Gear press transformed ore into a gear."
        if it["kind"] == "copper" and p.x > 520 and p.y > 360:
            it["kind"] = "circuit"
            it["color"] = Color(0.42, 0.83, 0.48)
            message = "Circuit bench transformed copper into a circuit."
        if p.x > 825:
            fulfilled += 1
            coins += 4
            p.x = 185
        it["pos"] = p
    _draw_floor()

func _show_upgrade() -> void:
    playing = false
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.07, 0.075, 0.07))
    _label("Factory Planning", Vector2(105, 70), Vector2(600, 55), 42, Color(1.0, 0.84, 0.38))
    _label("Choose one improvement for the next production shift.", Vector2(108, 128), Vector2(700, 32), 23)
    _upgrade(Vector2(145, 230), "Faster Belts", "Belt speed +25%.")
    _upgrade(Vector2(500, 230), "Twin Press", "Processes two gears.")
    _upgrade(Vector2(855, 230), "Smart Sorter", "Auto routes mixed items.")
    _button("Return to Floor", Vector2(520, 590), Vector2(240, 56), Callable(self, "_start_floor"))

func _upgrade(pos: Vector2, title: String, desc: String) -> void:
    _rect(pos, Vector2(285, 230), Color(0.15, 0.16, 0.145))
    _label(title, pos + Vector2(22, 26), Vector2(230, 34), 27, Color(1.0, 0.84, 0.38))
    _label(desc, pos + Vector2(22, 85), Vector2(230, 55), 21)
    _button("Choose", pos + Vector2(70, 165), Vector2(140, 42), Callable(self, "_start_floor"))

func _show_result() -> void:
    playing = false
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.07, 0.075, 0.07))
    _rect(Vector2(300, 165), Vector2(680, 360), Color(0.15, 0.16, 0.145))
    _label("SHIFT REPORT", Vector2(465, 215), Vector2(380, 56), 43, Color(1.0, 0.84, 0.38))
    _label("Fulfilled orders: %d\nMissed orders: %d\nCoins earned: $%d\nBottleneck: sorter lane" % [fulfilled, missed, coins], Vector2(455, 305), Vector2(400, 130), 27)
    _button("Retry", Vector2(430, 460), Vector2(170, 52), Callable(self, "_start_floor"))
    _button("Title", Vector2(680, 460), Vector2(170, 52), Callable(self, "_show_title"))
EOF

cat > "$GAME/demo_outputs/01_first_line.json" <<'EOF'
{"duration_frames":360,"events":[{"frame":25,"type":"mouse_click","button":"left","x":640,"y":585},{"frame":120,"type":"mouse_click","button":"left","x":1000,"y":58},{"frame":340,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/02_sorter_split.json" <<'EOF'
{"scenario":"sorter_split","duration_frames":330,"events":[{"frame":80,"type":"mouse_click","button":"left","x":1000,"y":58},{"frame":180,"type":"mouse_click","button":"left","x":1000,"y":58},{"frame":310,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/03_upgrade_shop.json" <<'EOF'
{"scenario":"upgrade_shop","duration_frames":240,"events":[{"frame":70,"type":"mouse_click","button":"left","x":570,"y":418},{"frame":220,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/04_result.json" <<'EOF'
{"scenario":"near_result","duration_frames":180,"events":[{"frame":160,"type":"wait"}]}
EOF

echo "Wrote Tiny Factory Foreman to $GAME"
