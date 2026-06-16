#!/bin/bash
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
rm -rf "$GAME"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5
[application]
config/name="Shadow Courier"
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
var player := Vector2(125, 585)
var velocity := Vector2.ZERO
var has_key := false
var has_doc := false
var blackout := false
var alert := 0.0
var message := "Avoid vision cones. SPACE interacts."
var guards := []
var result_success := false
var time_alive := 0.0

const PLAYER_RADIUS := 15.0
const SPEED := 180.0

func _ready() -> void:
    _parse_args()
    if scenario == "":
        _show_title()
    else:
        _start_level(scenario)

func _parse_args() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]

func _clear() -> void:
    for child in get_children():
        remove_child(child)
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

func _button(text: String, pos: Vector2, size: Vector2, cb: Callable) -> void:
    var b := Button.new()
    b.text = text
    b.position = pos
    b.size = size
    b.add_theme_font_size_override("font_size", 22)
    b.pressed.connect(cb)
    add_child(b)

func _poly(points: PackedVector2Array, color: Color) -> void:
    var p := Polygon2D.new()
    p.polygon = points
    p.color = color
    add_child(p)

func _show_title() -> void:
    mode = "title"
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.015, 0.018, 0.028))
    _rect(Vector2(90, 90), Vector2(1100, 500), Color(0.035, 0.055, 0.075))
    for i in range(7):
        _rect(Vector2(155 + i * 145, 370 - (i % 2) * 32), Vector2(72, 180), Color(0.06, 0.08, 0.105))
    _poly(PackedVector2Array([Vector2(230, 585), Vector2(1040, 585), Vector2(970, 635), Vector2(170, 635)]), Color(0.02, 0.02, 0.03, 0.85))
    _label("SHADOW COURIER", Vector2(290, 150), Vector2(720, 70), 56, Color(0.82, 0.9, 1.0))
    _label("Steal the sealed archive file. Kill the lights. Leave unseen.", Vector2(330, 250), Vector2(640, 80), 27, Color(0.76, 0.82, 0.9))
    _button("Begin Mission", Vector2(520, 475), Vector2(240, 62), Callable(self, "_show_briefing"))

func _show_briefing() -> void:
    mode = "briefing"
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.018, 0.02, 0.032))
    _rect(Vector2(245, 120), Vector2(790, 470), Color(0.055, 0.07, 0.09))
    _label("Mission Briefing", Vector2(325, 175), Vector2(560, 52), 42, Color(0.82, 0.9, 1.0))
    _label("The city archive holds a sealed courier ledger. Patrols sweep the west hall, a locked record room blocks the route, and the power box can cut the lights long enough to steal the document.", Vector2(325, 255), Vector2(640, 150), 25, Color(0.82, 0.86, 0.9))
    _label("Goal: key -> blackout -> document -> exit.", Vector2(325, 430), Vector2(620, 44), 28, Color(0.95, 0.78, 0.42))
    _button("Enter Archive", Vector2(520, 510), Vector2(240, 58), Callable(self, "_start_default"))

func _start_default() -> void:
    _start_level("archive")

func _start_level(id := "archive") -> void:
    mode = "game"
    player = Vector2(125, 585)
    has_key = false
    has_doc = false
    blackout = false
    alert = 0.0
    time_alive = 0.0
    message = "Avoid vision cones. SPACE interacts."
    if id == "key_door":
        player = Vector2(300, 570)
    elif id == "blackout":
        player = Vector2(560, 470)
        has_key = true
    elif id == "document":
        player = Vector2(805, 245)
        has_key = true
        blackout = true
    elif id == "near_escape":
        player = Vector2(1020, 125)
        has_key = true
        has_doc = true
        blackout = true
    elif id == "caught":
        player = Vector2(500, 305)
    _make_guards()
    _draw_game()

func _make_guards() -> void:
    guards = [
        {"pos": Vector2(430, 310), "a": Vector2(320, 310), "b": Vector2(605, 310), "speed": 82.0, "dir": Vector2.RIGHT, "kind": "Patrol"},
        {"pos": Vector2(870, 410), "a": Vector2(870, 210), "b": Vector2(870, 540), "speed": 70.0, "dir": Vector2.DOWN, "kind": "Captain"},
        {"pos": Vector2(715, 175), "a": Vector2(715, 175), "b": Vector2(715, 175), "speed": 0.0, "dir": Vector2.RIGHT, "kind": "Sentry", "spin": 0.0}
    ]

func _process(delta: float) -> void:
    if mode != "game":
        return
    time_alive += delta
    _update_player(delta)
    _update_guards(delta)
    _update_detection(delta)
    if mode != "game":
        return
    _check_auto_objectives()
    if mode != "game":
        return
    _draw_game()

func _update_player(delta: float) -> void:
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
        var next := player + velocity.normalized() * SPEED * delta
        if not _blocked(next):
            player = next

func _update_guards(delta: float) -> void:
    for g in guards:
        if g.has("spin"):
            g["spin"] += delta
            g["dir"] = Vector2.RIGHT.rotated(g["spin"] * 1.7)
        elif g["speed"] > 0.0:
            var target: Vector2 = g["b"]
            if g["pos"].distance_to(g["b"]) < 8.0:
                var old_a: Vector2 = g["a"]
                g["a"] = g["b"]
                g["b"] = old_a
                target = g["b"]
            var d: Vector2 = (target - g["pos"]).normalized()
            g["pos"] += d * g["speed"] * delta
            g["dir"] = d

func _update_detection(delta: float) -> void:
    var seen := false
    for g in guards:
        if _player_in_cone(g):
            seen = true
    if seen:
        alert += delta * (0.35 if blackout else 0.75)
        message = "Guard suspicion rising. Break line of sight."
    else:
        alert = max(0.0, alert - delta * 0.55)
    if alert >= 1.0:
        _show_result(false)

func _player_in_cone(g: Dictionary) -> bool:
    var range := 145.0 if blackout else (250.0 if g["kind"] == "Captain" else 210.0)
    var to_player: Vector2 = player - g["pos"]
    if to_player.length() > range:
        return false
    if abs(g["dir"].angle_to(to_player.normalized())) > 0.48:
        return false
    if _in_cover(player):
        return false
    return true

func _unhandled_input(event: InputEvent) -> void:
    if mode == "game" and event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
        _interact()

func _interact() -> void:
    if player.distance_to(Vector2(335, 585)) < 70.0 and not has_key:
        has_key = true
        message = "Keycard lifted. The record-room door can open."
    elif player.distance_to(Vector2(595, 470)) < 80.0:
        blackout = not blackout
        message = "Power box switched. Vision cones shrink in the blackout." if blackout else "Lights restored."
    elif player.distance_to(Vector2(850, 240)) < 85.0 and has_key:
        has_doc = true
        message = "Sealed document stolen. Reach the north exit."
    elif player.distance_to(Vector2(1135, 95)) < 90.0:
        if has_doc:
            _show_result(true)
        else:
            message = "The exit handler needs the stolen document."
    else:
        message = "Nothing useful within reach."

func _check_auto_objectives() -> void:
    if player.distance_to(Vector2(335, 585)) < 34.0 and not has_key:
        has_key = true
        message = "Keycard lifted. The record-room door can open."
    if player.distance_to(Vector2(850, 240)) < 38.0 and has_key and blackout:
        has_doc = true
        message = "Sealed document stolen. Reach the north exit."
    if player.distance_to(Vector2(1135, 95)) < 46.0 and has_doc:
        _show_result(true)

func _blocked(pos: Vector2) -> bool:
    if pos.x < 70 or pos.x > 1170 or pos.y < 70 or pos.y > 635:
        return true
    var blocks := [
        Rect2(Vector2(205, 115), Vector2(70, 395)),
        Rect2(Vector2(205, 510), Vector2(415, 52)),
        Rect2(Vector2(650, 500), Vector2(330, 55)),
        Rect2(Vector2(995, 165), Vector2(55, 390)),
        Rect2(Vector2(435, 120), Vector2(62, 145)),
        Rect2(Vector2(700, 305), Vector2(70, 155))
    ]
    for b in blocks:
        if b.grow(PLAYER_RADIUS).has_point(pos):
            return true
    if not has_key and Rect2(Vector2(620, 225), Vector2(38, 125)).grow(PLAYER_RADIUS).has_point(pos):
        return true
    return false

func _in_cover(pos: Vector2) -> bool:
    var covers := [
        Rect2(Vector2(360, 420), Vector2(95, 48)),
        Rect2(Vector2(790, 360), Vector2(90, 48)),
        Rect2(Vector2(535, 150), Vector2(70, 48))
    ]
    for c in covers:
        if c.grow(18).has_point(pos):
            return true
    return false

func _draw_game() -> void:
    _clear()
    var floor_color := Color(0.08, 0.095, 0.11) if not blackout else Color(0.025, 0.032, 0.048)
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.012, 0.014, 0.022))
    _rect(Vector2(60, 60), Vector2(1140, 590), floor_color)
    _draw_rooms()
    _draw_objectives()
    for g in guards:
        _draw_guard(g)
    _draw_player()
    _draw_hud()

func _draw_rooms() -> void:
    var wall := Color(0.18, 0.2, 0.23)
    var cover := Color(0.17, 0.13, 0.09)
    _rect(Vector2(205, 115), Vector2(70, 395), wall)
    _rect(Vector2(205, 510), Vector2(415, 52), wall)
    _rect(Vector2(650, 500), Vector2(330, 55), wall)
    _rect(Vector2(995, 165), Vector2(55, 390), wall)
    _rect(Vector2(435, 120), Vector2(62, 145), wall)
    _rect(Vector2(700, 305), Vector2(70, 155), wall)
    _rect(Vector2(620, 225), Vector2(38, 125), Color(0.45, 0.13, 0.12) if not has_key else Color(0.12, 0.36, 0.22))
    _label("LOCK", Vector2(612, 270), Vector2(58, 24), 13, Color(1, 0.8, 0.6))
    _rect(Vector2(360, 420), Vector2(95, 48), cover)
    _rect(Vector2(790, 360), Vector2(90, 48), cover)
    _rect(Vector2(535, 150), Vector2(70, 48), cover)
    _label("cover", Vector2(378, 432), Vector2(70, 22), 14, Color(0.9, 0.78, 0.56))
    _label("cover", Vector2(808, 372), Vector2(70, 22), 14, Color(0.9, 0.78, 0.56))
    _rect(Vector2(1110, 65), Vector2(80, 62), Color(0.09, 0.3, 0.22))
    _label("EXIT", Vector2(1125, 82), Vector2(50, 26), 18, Color(0.65, 1.0, 0.78))

func _draw_objectives() -> void:
    if not has_key:
        _rect(Vector2(315, 566), Vector2(42, 32), Color(0.95, 0.77, 0.2))
        _label("KEY", Vector2(318, 572), Vector2(40, 20), 14, Color(0.05, 0.04, 0.02))
    _rect(Vector2(565, 448), Vector2(62, 46), Color(0.15, 0.22, 0.27))
    _label("PWR", Vector2(575, 460), Vector2(42, 22), 15, Color(0.75, 0.95, 1.0))
    if not has_doc:
        _rect(Vector2(815, 210), Vector2(76, 54), Color(0.42, 0.33, 0.2))
        _label("FILE", Vector2(832, 225), Vector2(46, 22), 17, Color(1.0, 0.9, 0.6))

func _draw_guard(g: Dictionary) -> void:
    var range := 145.0 if blackout else (250.0 if g["kind"] == "Captain" else 210.0)
    var angle := 0.48
    var a: Vector2 = g["dir"].rotated(-angle) * range
    var b: Vector2 = g["dir"].rotated(angle) * range
    var cone_color := Color(1.0, 0.23, 0.16, 0.36) if _player_in_cone(g) else Color(0.95, 0.82, 0.25, 0.23)
    _poly(PackedVector2Array([g["pos"], g["pos"] + a, g["pos"] + b]), cone_color)
    _rect(g["pos"] - Vector2(18, 18), Vector2(36, 36), Color(0.48, 0.62, 0.76))
    _rect(g["pos"] + g["dir"] * 18 - Vector2(6, 6), Vector2(12, 12), Color(0.95, 0.88, 0.55))
    _label(g["kind"], g["pos"] + Vector2(-28, 24), Vector2(80, 20), 13, Color(0.82, 0.9, 1.0))

func _draw_player() -> void:
    _rect(player - Vector2(15, 15), Vector2(30, 30), Color(0.12, 0.72, 0.9))
    _rect(player - Vector2(7, 20), Vector2(14, 8), Color(0.02, 0.04, 0.05))
    if _in_cover(player):
        _label("HIDDEN", player + Vector2(-30, -46), Vector2(75, 20), 15, Color(0.65, 1.0, 0.78))

func _draw_hud() -> void:
    _rect(Vector2(24, 18), Vector2(760, 58), Color(0.035, 0.045, 0.065, 0.95))
    _label("Key: %s   Document: %s   Lights: %s   Alert: %d%%" % [
        "YES" if has_key else "NO",
        "STOLEN" if has_doc else "MISSING",
        "BLACKOUT" if blackout else "ON",
        int(alert * 100.0)
    ], Vector2(42, 32), Vector2(720, 28), 21, Color(0.86, 0.92, 1.0))
    _rect(Vector2(820, 22), Vector2(385, 50), Color(0.035, 0.045, 0.065, 0.95))
    _label(message, Vector2(838, 34), Vector2(350, 26), 18, Color(0.95, 0.78, 0.42))
    _rect(Vector2(42, 84), Vector2(180, 14), Color(0.18, 0.05, 0.05))
    _rect(Vector2(42, 84), Vector2(180 * clamp(alert, 0.0, 1.0), 14), Color(0.95, 0.2, 0.15))

func _show_result(success: bool) -> void:
    mode = "result"
    result_success = success
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.012, 0.014, 0.022))
    _rect(Vector2(300, 155), Vector2(680, 395), Color(0.045, 0.058, 0.078))
    _label("PACKAGE DELIVERED" if success else "ALARM TRIGGERED", Vector2(405, 215), Vector2(520, 58), 42, Color(0.82, 0.9, 1.0) if success else Color(1.0, 0.45, 0.34))
    _label("Key: %s\nDocument: %s\nLights: %s\nTime inside: %.1fs" % [
        "yes" if has_key else "no",
        "stolen" if has_doc else "missing",
        "blackout" if blackout else "on",
        time_alive
    ], Vector2(455, 305), Vector2(370, 130), 25, Color(0.82, 0.86, 0.9))
    _button("Retry", Vector2(410, 465), Vector2(170, 54), Callable(self, "_start_default"))
    _button("Title", Vector2(700, 465), Vector2(170, 54), Callable(self, "_show_title"))
EOF

cat > "$GAME/demo_outputs/01_title_flow.json" <<'EOF'
{"duration_frames":360,"events":[{"frame":30,"type":"mouse_click","button":"left","x":640,"y":505},{"frame":120,"type":"mouse_click","button":"left","x":640,"y":540},{"frame":170,"type":"key_down","keycode":"D"},{"frame":230,"type":"key_up","keycode":"D"},{"frame":340,"type":"wait"}]}
EOF

cat > "$GAME/demo_outputs/02_patrol_showcase.json" <<'EOF'
{"scenario":"patrol_showcase","duration_frames":420,"events":[{"frame":30,"type":"key_down","keycode":"D"},{"frame":100,"type":"key_up","keycode":"D"},{"frame":140,"type":"key_down","keycode":"W"},{"frame":205,"type":"key_up","keycode":"W"},{"frame":400,"type":"wait"}]}
EOF

cat > "$GAME/demo_outputs/03_key_door.json" <<'EOF'
{"scenario":"key_door","duration_frames":420,"events":[{"frame":20,"type":"key_down","keycode":"D"},{"frame":55,"type":"key_up","keycode":"D"},{"frame":60,"type":"key_press","keycode":"SPACE"},{"frame":95,"type":"key_down","keycode":"D"},{"frame":210,"type":"key_up","keycode":"D"},{"frame":400,"type":"wait"}]}
EOF

cat > "$GAME/demo_outputs/04_blackout_document.json" <<'EOF'
{"scenario":"blackout","duration_frames":520,"events":[{"frame":30,"type":"key_press","keycode":"SPACE"},{"frame":65,"type":"key_down","keycode":"D"},{"frame":150,"type":"key_up","keycode":"D"},{"frame":155,"type":"key_down","keycode":"W"},{"frame":240,"type":"key_up","keycode":"W"},{"frame":245,"type":"key_down","keycode":"D"},{"frame":310,"type":"key_up","keycode":"D"},{"frame":315,"type":"key_press","keycode":"SPACE"},{"frame":500,"type":"wait"}]}
EOF

cat > "$GAME/demo_outputs/05_escape_success.json" <<'EOF'
{"scenario":"near_escape","duration_frames":260,"events":[{"frame":20,"type":"key_down","keycode":"D"},{"frame":55,"type":"key_up","keycode":"D"},{"frame":60,"type":"key_down","keycode":"W"},{"frame":105,"type":"key_up","keycode":"W"},{"frame":130,"type":"key_press","keycode":"SPACE"},{"frame":240,"type":"wait"}]}
EOF

cat > "$GAME/demo_outputs/06_caught_failure.json" <<'EOF'
{"scenario":"caught","duration_frames":300,"events":[{"frame":30,"type":"key_down","keycode":"D"},{"frame":105,"type":"key_up","keycode":"D"},{"frame":280,"type":"wait"}]}
EOF

echo "Wrote Shadow Courier to $GAME"
