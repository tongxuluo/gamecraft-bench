#!/bin/bash
set -eu

GAME=/workspace/game
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5
[application]
config/name="Orbital Salvage"
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
var ship := Vector2(250, 380)
var vel := Vector2.ZERO
var salvage := Vector2(525, 360)
var heavy := Vector2(690, 500)
var capsule := Vector2(835, 250)
var attached := false
var towing := "Light Panel"
var fuel := 100.0
var credits := 0
var delivered := 0
var warning := "Contract: tow a light panel to Recovery Station Alpha."
var mission_t := 85.0

func _ready() -> void:
    _parse_args()
    if scenario == "":
        _show_title()
    elif scenario == "near_result":
        credits = 180
        delivered = 3
        _show_result()
    else:
        _start_contract()

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
    l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
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
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.015, 0.025, 0.055))
    _rect(Vector2(70, 78), Vector2(1140, 520), Color(0.035, 0.065, 0.11))
    for i in range(18):
        _rect(Vector2(110 + (i * 67) % 1060, 120 + (i * 101) % 420), Vector2(4, 4), Color(0.8, 0.9, 1.0))
    _rect(Vector2(455, 320), Vector2(90, 42), Color(0.55, 0.82, 1.0))
    _rect(Vector2(710, 285), Vector2(135, 88), Color(0.22, 0.30, 0.42))
    _rect(Vector2(560, 350), Vector2(170, 6), Color(0.32, 0.95, 1.0))
    _label("ORBITAL SALVAGE", Vector2(300, 138), Vector2(700, 70), 54, Color(0.62, 0.92, 1.0))
    _label("Pilot a tug, manage inertia, and tow valuable wreckage through hazards.", Vector2(238, 225), Vector2(810, 58), 26)
    _label("Contract board: Light Panel $60 / Heavy Core $140 / Volatile Capsule $220", Vector2(240, 470), Vector2(790, 35), 21, Color(1.0, 0.86, 0.45))
    _button("Start Contract", Vector2(520, 540), Vector2(240, 58), Callable(self, "_start_contract"))

func _start_contract() -> void:
    playing = true
    ship = Vector2(250, 380)
    vel = Vector2.ZERO
    salvage = Vector2(525, 360)
    heavy = Vector2(690, 500)
    capsule = Vector2(835, 250)
    attached = false
    towing = "Heavy Core" if scenario == "heavy_core" else "Light Panel"
    if scenario == "hazard_route":
        ship = Vector2(585, 380)
        warning = "GRAVITY WELL ACTIVE: reroute around the red hazard ring."
    else:
        warning = "Contract: tow a light panel to Recovery Station Alpha."
    fuel = 100.0
    credits = 0
    delivered = 0
    mission_t = 85.0
    _draw_space()

func _draw_space() -> void:
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.015, 0.025, 0.055))
    _rect(Vector2(32, 26), Vector2(1216, 86), Color(0.025, 0.055, 0.09))
    _label("Contract: %s   Fuel %.0f%%   Velocity %.0f   Credits $%d   Mission %.0fs" % [towing, fuel, vel.length(), credits, mission_t], Vector2(55, 44), Vector2(900, 32), 22, Color(0.62, 0.92, 1.0))
    _label(warning, Vector2(55, 76), Vector2(880, 28), 19, Color(1.0, 0.86, 0.45))
    _button("Toggle Tractor", Vector2(965, 44), Vector2(160, 34), Callable(self, "_toggle_tractor"))
    _button("Report", Vector2(1140, 44), Vector2(90, 34), Callable(self, "_show_result"))

    _rect(Vector2(46, 132), Vector2(905, 520), Color(0.02, 0.035, 0.065))
    for i in range(22):
        _rect(Vector2(80 + (i * 83) % 825, 158 + (i * 61) % 455), Vector2(3, 3), Color(0.65, 0.78, 0.9))
    _station(Vector2(790, 345))
    _hazard(Vector2(610, 330), "Gravity\nWell")
    _hazard(Vector2(340, 535), "Mine\nField")
    _salvage(salvage, "Panel\nmass 1", Color(0.58, 0.80, 0.95))
    _salvage(heavy, "Heavy\nmass 3", Color(0.78, 0.55, 0.35))
    _salvage(capsule, "Volatile\nrisk", Color(0.95, 0.38, 0.55))
    if attached:
        var beam_start := ship + Vector2(24, 0)
        var target := salvage if towing == "Light Panel" else heavy
        _beam(beam_start, target)
    _ship()

    _rect(Vector2(975, 132), Vector2(250, 520), Color(0.025, 0.055, 0.09))
    _label("MISSION CONSOLE", Vector2(1000, 156), Vector2(200, 30), 24, Color(0.62, 0.92, 1.0))
    _label("Salvage catalog:\n- Light Panel: $60 mass 1\n- Heavy Core: $140 mass 3\n- Volatile Capsule: $220 risk\n\nDelivery zone:\nRecovery Station Alpha\n\nPressure:\nFuel, gravity, mines, contract timer.", Vector2(1000, 205), Vector2(195, 275), 18)
    _label("Tractor: %s\nDelivered: %d" % ["ACTIVE" if attached else "OFF", delivered], Vector2(1000, 520), Vector2(180, 70), 20, Color(1.0, 0.86, 0.45))

func _ship() -> void:
    _rect(ship - Vector2(26, 16), Vector2(52, 32), Color(0.62, 0.92, 1.0))
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        _rect(ship + Vector2(-40, -8), Vector2(16, 16), Color(1.0, 0.55, 0.22))
    _label("TUG", ship - Vector2(17, 8), Vector2(38, 17), 13, Color(0.02, 0.04, 0.07))

func _salvage(pos: Vector2, text: String, color: Color) -> void:
    _rect(pos - Vector2(28, 22), Vector2(56, 44), color)
    _label(text, pos - Vector2(26, 14), Vector2(54, 30), 13, Color(0.02, 0.03, 0.04))

func _station(pos: Vector2) -> void:
    _rect(pos, Vector2(125, 92), Color(0.30, 0.38, 0.52))
    _label("RECOVERY\nSTATION", pos + Vector2(15, 25), Vector2(96, 42), 16, Color(0.85, 0.95, 1.0))

func _hazard(pos: Vector2, text: String) -> void:
    _rect(pos - Vector2(50, 50), Vector2(100, 100), Color(0.35, 0.06, 0.10, 0.75))
    _rect(pos - Vector2(30, 30), Vector2(60, 60), Color(0.75, 0.12, 0.18, 0.65))
    _label(text, pos - Vector2(35, 18), Vector2(75, 40), 14, Color(1.0, 0.88, 0.7))

func _beam(a: Vector2, b: Vector2) -> void:
    var mid := (a + b) * 0.5
    var len := a.distance_to(b)
    var r := _rect(mid - Vector2(len * 0.5, 3), Vector2(len, 6), Color(0.32, 0.95, 1.0, 0.75))
    r.rotation = (b - a).angle()
    r.pivot_offset = Vector2(len * 0.5, 3)

func _toggle_tractor() -> void:
    attached = not attached
    warning = "Tractor beam locked; tow mass changes handling." if attached else "Tractor beam released."
    _draw_space()

func _process(delta: float) -> void:
    if not playing:
        return
    mission_t -= delta
    if mission_t <= 0 or fuel <= 0:
        _show_result()
        return
    var thrust := Vector2.ZERO
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        thrust.y -= 1
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        thrust.y += 1
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        thrust.x -= 1
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        thrust.x += 1
    if Input.is_key_pressed(KEY_SPACE):
        attached = true
    if thrust.length() > 0:
        thrust = thrust.normalized()
        vel += thrust * 135.0 * delta
        fuel -= 8.0 * delta
    var mass_drag := 0.97 if attached and towing == "Heavy Core" else 0.992
    vel *= mass_drag
    ship += vel * delta
    ship = ship.clamp(Vector2(75, 155), Vector2(915, 620))
    if ship.distance_to(Vector2(610, 330)) < 105:
        vel += (ship - Vector2(610, 330)).normalized() * 45.0 * delta
        warning = "Gravity warning: tug being pulled off route."
    if attached:
        var target := salvage if towing == "Light Panel" else heavy
        target += (ship - target) * delta * (0.9 if towing == "Light Panel" else 0.42)
        if towing == "Light Panel":
            salvage = target
        else:
            heavy = target
        if target.distance_to(Vector2(850, 390)) < 95:
            credits += 60 if towing == "Light Panel" else 140
            delivered += 1
            attached = false
            warning = "Delivered salvage to Recovery Station Alpha."
    _draw_space()

func _show_result() -> void:
    playing = false
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.015, 0.025, 0.055))
    _rect(Vector2(300, 165), Vector2(680, 360), Color(0.025, 0.055, 0.09))
    _label("MISSION REPORT", Vector2(445, 215), Vector2(430, 56), 43, Color(0.62, 0.92, 1.0))
    _label("Delivered salvage: %d\nCredits earned: $%d\nFuel remaining: %.0f%%\nDamage: minor hull scoring" % [delivered, credits, fuel], Vector2(450, 305), Vector2(430, 130), 27)
    _button("Retry", Vector2(430, 460), Vector2(170, 52), Callable(self, "_start_contract"))
    _button("Title", Vector2(680, 460), Vector2(170, 52), Callable(self, "_show_title"))
EOF

cat > "$GAME/demo_outputs/01_tow_panel.json" <<'EOF'
{"duration_frames":360,"events":[{"frame":25,"type":"mouse_click","button":"left","x":640,"y":570},{"frame":80,"type":"mouse_click","button":"left","x":1045,"y":62},{"frame":95,"type":"key_down","keycode":"D"},{"frame":160,"type":"key_up","keycode":"D"},{"frame":170,"type":"key_down","keycode":"W"},{"frame":225,"type":"key_up","keycode":"W"},{"frame":340,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/02_heavy_core.json" <<'EOF'
{"scenario":"heavy_core","duration_frames":330,"events":[{"frame":55,"type":"mouse_click","button":"left","x":1045,"y":62},{"frame":80,"type":"key_down","keycode":"D"},{"frame":180,"type":"key_up","keycode":"D"},{"frame":190,"type":"key_down","keycode":"S"},{"frame":230,"type":"key_up","keycode":"S"},{"frame":310,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/03_hazard_route.json" <<'EOF'
{"scenario":"hazard_route","duration_frames":330,"events":[{"frame":45,"type":"key_down","keycode":"W"},{"frame":110,"type":"key_up","keycode":"W"},{"frame":115,"type":"key_down","keycode":"D"},{"frame":185,"type":"key_up","keycode":"D"},{"frame":310,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/04_result.json" <<'EOF'
{"scenario":"near_result","duration_frames":180,"events":[{"frame":160,"type":"wait"}]}
EOF

echo "Wrote Orbital Salvage to $GAME"
