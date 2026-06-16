#!/bin/bash
set -eu

GAME=/workspace/game
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5
[application]
config/name="Cozy Harbor Delivery"
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
var boat := Vector2(250, 420)
var velocity := Vector2.ZERO
var cargo := "None"
var coins := 0
var rating := 3
var shift_time := 75.0
var delivered := 0
var urgent_time := 18.0
var playing := false
var message := "Pick up tea crates and deliver to matching docks."

func _ready() -> void:
    _parse_args()
    if scenario == "":
        _show_title()
    elif scenario == "upgrade_shop":
        _show_upgrade()
    elif scenario == "near_result":
        delivered = 4
        coins = 18
        _show_result(true)
    else:
        _start_shift()

func _parse_args() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]

func _clear() -> void:
    for child in get_children():
        child.queue_free()

func _rect(pos: Vector2, size: Vector2, color: Color) -> void:
    var r := ColorRect.new()
    r.position = pos
    r.size = size
    r.color = color
    add_child(r)

func _label(text: String, pos: Vector2, size: Vector2, fs := 23, color := Color.WHITE) -> Label:
    var l := Label.new()
    l.text = text
    l.position = pos
    l.size = size
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_font_size_override("font_size", fs)
    l.add_theme_color_override("font_color", color)
    add_child(l)
    return l

func _button(text: String, pos: Vector2, size: Vector2, cb: Callable) -> void:
    var b := Button.new()
    b.text = text
    b.position = pos
    b.size = size
    b.add_theme_font_size_override("font_size", 22)
    b.pressed.connect(cb)
    add_child(b)

func _show_title() -> void:
    playing = false
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.05, 0.12, 0.16))
    _rect(Vector2(110, 95), Vector2(1060, 500), Color(0.12, 0.32, 0.42))
    _rect(Vector2(170, 370), Vector2(940, 120), Color(0.78, 0.58, 0.34))
    _label("COZY HARBOR DELIVERY", Vector2(245, 145), Vector2(820, 70), 50, Color(1.0, 0.88, 0.45))
    _label("Pilot a courier boat, pick up parcels, and keep dock customers happy.", Vector2(265, 250), Vector2(760, 70), 27)
    _rect(Vector2(560, 390), Vector2(120, 54), Color(1.0, 0.88, 0.45))
    _label("BOAT", Vector2(590, 402), Vector2(80, 28), 20, Color.BLACK)
    _button("Start Shift", Vector2(520, 525), Vector2(240, 62), Callable(self, "_start_shift"))

func _start_shift() -> void:
    playing = true
    boat = Vector2(250, 420)
    cargo = "None"
    coins = 0
    delivered = 0
    shift_time = 75.0
    urgent_time = 18.0
    message = "WASD steer. Pickup at yellow crates, deliver to colored docks."
    _draw_harbor()

func _draw_harbor() -> void:
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.08, 0.33, 0.48))
    _rect(Vector2(70, 80), Vector2(150, 500), Color(0.78, 0.58, 0.34))
    _rect(Vector2(980, 120), Vector2(210, 430), Color(0.78, 0.58, 0.34))
    _rect(Vector2(480, 285), Vector2(220, 110), Color(0.17, 0.47, 0.25))
    _rect(Vector2(320, 160), Vector2(85, 70), Color(1.0, 0.82, 0.25))
    _label("TEA", Vector2(342, 182), Vector2(55, 25), 16, Color.BLACK)
    _rect(Vector2(735, 500), Vector2(85, 70), Color(1.0, 0.55, 0.25))
    _label("FISH", Vector2(752, 522), Vector2(65, 25), 16, Color.BLACK)
    _dock(Vector2(1010, 165), "Tea House", Color(0.95, 0.35, 0.35))
    _dock(Vector2(1010, 320), "Fish Stall", Color(0.35, 0.95, 0.8))
    _dock(Vector2(1010, 475), "Lighthouse", Color(0.9, 0.75, 1.0))
    _rect(boat - Vector2(30, 18), Vector2(60, 36), Color(1.0, 0.9, 0.4))
    _label("Boat", boat - Vector2(22, 10), Vector2(60, 24), 16, Color.BLACK)
    _label("Cargo: %s   Orders: Tea->Tea House, Fish->Fish Stall, Urgent mail %.0fs   Coins $%d   Shift %.0fs" % [cargo, urgent_time, coins, shift_time], Vector2(40, 25), Vector2(1080, 36), 22)
    _label(message, Vector2(40, 615), Vector2(900, 38), 24, Color(1.0, 0.88, 0.45))
    _button("Upgrade Screen", Vector2(1010, 610), Vector2(190, 50), Callable(self, "_show_upgrade"))

func _dock(pos: Vector2, name: String, color: Color) -> void:
    _rect(pos, Vector2(135, 70), color)
    _label(name, pos + Vector2(10, 16), Vector2(115, 38), 18, Color.BLACK)

func _process(delta: float) -> void:
    if not playing:
        return
    shift_time -= delta
    urgent_time -= delta
    if shift_time <= 0:
        _show_result(delivered >= 2)
        return
    velocity = Vector2.ZERO
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        velocity.x -= 1
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        velocity.x += 1
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        velocity.y -= 1
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        velocity.y += 1
    if velocity.length() > 0:
        velocity = velocity.normalized() * 170 * delta
        var next := boat + velocity
        if not Rect2(Vector2(480, 285), Vector2(220, 110)).has_point(next):
            boat = next.clamp(Vector2(120, 95), Vector2(950, 585))
        _check_points()
        _draw_harbor()

func _check_points() -> void:
    if boat.distance_to(Vector2(360, 195)) < 70 and cargo == "None":
        cargo = "Tea"
        message = "Picked up Tea cargo. Route marker points to Tea House."
    elif boat.distance_to(Vector2(778, 535)) < 70 and cargo == "None":
        cargo = "Fish"
        message = "Picked up Fish cargo. Capacity forces a route choice."
    elif boat.distance_to(Vector2(1078, 200)) < 95 and cargo == "Tea":
        _deliver("Tea")
    elif boat.distance_to(Vector2(1078, 355)) < 95 and cargo == "Fish":
        _deliver("Fish")

func _deliver(kind: String) -> void:
    cargo = "None"
    delivered += 1
    coins += 5
    rating += 1
    message = "Delivered %s. Tip sparkle and reputation increased." % kind
    if delivered >= 2:
        _show_upgrade()

func _show_upgrade() -> void:
    playing = false
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.05, 0.12, 0.16))
    _label("Harbor Planning Board", Vector2(95, 65), Vector2(700, 60), 42, Color(1.0, 0.88, 0.45))
    _label("Spend earnings on one upgrade before the next shift.", Vector2(100, 125), Vector2(700, 40), 24)
    _upgrade(Vector2(140, 235), "Swift Sail", "Boat speed +20%.")
    _upgrade(Vector2(500, 235), "Bigger Hold", "Carry 2 parcels.")
    _upgrade(Vector2(860, 235), "Route Bell", "Shows urgent route hints.")
    _button("Start Next Shift", Vector2(520, 585), Vector2(240, 58), Callable(self, "_start_shift"))

func _upgrade(pos: Vector2, title: String, desc: String) -> void:
    _rect(pos, Vector2(285, 235), Color(0.12, 0.28, 0.36))
    _label(title, pos + Vector2(22, 26), Vector2(240, 36), 28, Color(1.0, 0.88, 0.45))
    _label(desc, pos + Vector2(22, 82), Vector2(230, 70), 22)
    _button("Choose", pos + Vector2(72, 165), Vector2(140, 44), Callable(self, "_start_shift"))

func _show_result(success: bool) -> void:
    playing = false
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.05, 0.12, 0.16))
    _rect(Vector2(300, 170), Vector2(680, 340), Color(0.12, 0.28, 0.36))
    _label("SHIFT COMPLETE" if success else "LOW RATING", Vector2(420, 220), Vector2(500, 60), 44, Color(1.0, 0.88, 0.45))
    _label("Deliveries: %d\nEarnings: $%d\nRating: %d stars" % [delivered, coins, rating], Vector2(475, 315), Vector2(340, 120), 29)
    _button("Retry", Vector2(420, 455), Vector2(170, 52), Callable(self, "_start_shift"))
    _button("Title", Vector2(690, 455), Vector2(170, 52), Callable(self, "_show_title"))
EOF

cat > "$GAME/demo_outputs/01_title_pickup.json" <<'EOF'
{"duration_frames":360,"events":[{"frame":25,"type":"mouse_click","button":"left","x":640,"y":555},{"frame":55,"type":"key_down","keycode":"D"},{"frame":100,"type":"key_up","keycode":"D"},{"frame":105,"type":"key_down","keycode":"W"},{"frame":145,"type":"key_up","keycode":"W"},{"frame":340,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/02_urgent_order.json" <<'EOF'
{"scenario":"urgent_order","duration_frames":360,"events":[{"frame":30,"type":"key_down","keycode":"D"},{"frame":120,"type":"key_up","keycode":"D"},{"frame":130,"type":"key_down","keycode":"W"},{"frame":180,"type":"key_up","keycode":"W"},{"frame":340,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/03_upgrade_shop.json" <<'EOF'
{"scenario":"upgrade_shop","duration_frames":240,"events":[{"frame":60,"type":"mouse_click","button":"left","x":570,"y":424},{"frame":220,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/04_result.json" <<'EOF'
{"scenario":"near_result","duration_frames":180,"events":[{"frame":160,"type":"wait"}]}
EOF

echo "Wrote Cozy Harbor Delivery to $GAME"
