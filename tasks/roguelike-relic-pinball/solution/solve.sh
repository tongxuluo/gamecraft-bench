#!/bin/bash
set -eu

GAME=/workspace/game
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5
[application]
config/name="Relic Pinball"
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
var ball := Vector2(840, 560)
var ball2 := Vector2(820, 540)
var vel := Vector2.ZERO
var vel2 := Vector2.ZERO
var launched := false
var multiball := false
var left_flip := 0.0
var right_flip := 0.0
var score := 0
var balls := 3
var chamber := 1
var objective := 6
var hits := 0
var combo := 1
var spinner := 0
var gate_open := false
var portal_ready := true
var magnet_relic := false
var fire_relic := false
var echo_relic := false
var boss_shield := true
var message := "SPACE launches. Arrow keys work the flippers."
var targets := []
var sparks := []
var relics := []

func _ready() -> void:
    _parse_args()
    if scenario == "":
        _show_title()
    elif scenario == "relic_choice":
        _show_relic_choice()
    elif scenario == "near_victory":
        score = 1850
        chamber = 3
        relics = ["Magnet Moon", "Fireglass", "Echo Bell"]
        _show_result(true)
    elif scenario == "near_defeat":
        balls = 0
        _show_result(false)
    else:
        _start_table()

func _parse_args() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]

func _clear() -> void:
    for child in get_children():
        child.queue_free()

func _rect(pos: Vector2, size: Vector2, color: Color, rot := 0.0) -> ColorRect:
    var r := ColorRect.new()
    r.position = pos
    r.size = size
    r.color = color
    r.rotation = rot
    r.pivot_offset = size * 0.5
    add_child(r)
    return r

func _label(text: String, pos: Vector2, size: Vector2, fs := 20, color := Color.WHITE) -> Label:
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
    b.add_theme_font_size_override("font_size", 18)
    b.pressed.connect(cb)
    add_child(b)
    return b

func _show_title() -> void:
    mode = "title"
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.06, 0.04, 0.08))
    _rect(Vector2(145, 78), Vector2(990, 540), Color(0.13, 0.08, 0.10))
    _rect(Vector2(315, 135), Vector2(650, 395), Color(0.24, 0.15, 0.12))
    _rect(Vector2(345, 165), Vector2(590, 335), Color(0.05, 0.04, 0.06))
    _rect(Vector2(425, 365), Vector2(170, 18), Color(0.84, 0.60, 0.25), -0.28)
    _rect(Vector2(690, 365), Vector2(170, 18), Color(0.84, 0.60, 0.25), 0.28)
    _rect(Vector2(560, 245), Vector2(48, 48), Color(0.78, 0.92, 1.0))
    _rect(Vector2(690, 215), Vector2(72, 72), Color(0.36, 0.10, 0.46))
    _rect(Vector2(708, 232), Vector2(36, 36), Color(0.95, 0.78, 0.25))
    _label("RELIC PINBALL", Vector2(330, 105), Vector2(620, 70), 54, Color(1.0, 0.78, 0.36))
    _label("An arcane table of brass rails, target banks, flippers, chambers, and mutating relic balls.", Vector2(310, 520), Vector2(660, 52), 23)
    _button("Start Run", Vector2(520, 585), Vector2(240, 54), Callable(self, "_start_table"))

func _setup_targets() -> void:
    targets = []
    var y := 145
    var colors := [Color(0.62, 0.22, 0.25), Color(0.78, 0.42, 0.18), Color(0.38, 0.25, 0.62)]
    for row in range(3):
        for col in range(4):
            targets.append({"pos": Vector2(410 + col * 95, y + row * 58), "size": Vector2(66, 34), "hp": 1 + row, "kind": "brick", "color": colors[row]})
    targets.append({"pos": Vector2(345, 365), "size": Vector2(58, 58), "hp": 2, "kind": "bumper", "color": Color(0.95, 0.72, 0.22)})
    targets.append({"pos": Vector2(820, 360), "size": Vector2(58, 58), "hp": 2, "kind": "bumper", "color": Color(0.35, 0.85, 0.95)})
    targets.append({"pos": Vector2(585, 330), "size": Vector2(70, 26), "hp": 3, "kind": "spinner", "color": Color(0.72, 0.60, 0.95)})
    if chamber >= 2 or scenario == "mechanism_showcase" or scenario == "boss_table":
        targets.append({"pos": Vector2(710, 430), "size": Vector2(90, 22), "hp": 2, "kind": "gate", "color": Color(0.35, 0.95, 0.45)})
        targets.append({"pos": Vector2(450, 455), "size": Vector2(48, 48), "hp": 1, "kind": "portal", "color": Color(0.9, 0.28, 0.92)})
    if chamber >= 3 or scenario == "boss_table":
        targets.append({"pos": Vector2(560, 105), "size": Vector2(160, 52), "hp": 5, "kind": "boss", "color": Color(0.72, 0.08, 0.18)})

func _start_table() -> void:
    mode = "table"
    chamber = 2 if scenario in ["mechanism_showcase", "magnet_relic", "multiball"] else chamber
    chamber = 3 if scenario == "boss_table" else chamber
    ball = Vector2(840, 565)
    ball2 = Vector2(805, 540)
    vel = Vector2.ZERO
    vel2 = Vector2.ZERO
    launched = false
    multiball = scenario == "multiball"
    magnet_relic = scenario in ["magnet_relic", "multiball", "boss_table"]
    fire_relic = scenario in ["multiball", "boss_table"]
    if magnet_relic and relics.is_empty():
        relics = ["Magnet Moon", "Fireglass", "Echo Bell"] if fire_relic else ["Magnet Moon"]
    balls = max(balls, 2)
    message = "Launch the ball, clear target banks, and charge the relic meter."
    _setup_targets()
    if scenario in ["target_bank", "mechanism_showcase", "magnet_relic", "multiball", "boss_table"]:
        launched = true
        vel = Vector2(-150, -255)
        if multiball:
            vel2 = Vector2(185, -220)
    _draw_table()

func _draw_table() -> void:
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.055, 0.035, 0.06))
    _rect(Vector2(40, 28), Vector2(1198, 78), Color(0.13, 0.08, 0.10))
    _label("Score %06d   Balls %d   Chamber %d/3   Objective %d/%d   Combo x%d" % [score, balls, chamber, hits, objective, combo], Vector2(65, 48), Vector2(770, 28), 23, Color(1.0, 0.78, 0.36))
    _label(message, Vector2(65, 78), Vector2(760, 24), 17, Color(0.92, 0.86, 0.70))
    _button("Relics", Vector2(1075, 48), Vector2(78, 32), Callable(self, "_show_relic_choice"))
    _button("Result", Vector2(1160, 48), Vector2(72, 32), Callable(self, "_show_result_win"))

    _rect(Vector2(250, 108), Vector2(690, 552), Color(0.19, 0.11, 0.10))
    _rect(Vector2(275, 130), Vector2(640, 505), Color(0.06, 0.05, 0.07))
    _rect(Vector2(265, 115), Vector2(18, 535), Color(0.74, 0.48, 0.20))
    _rect(Vector2(900, 115), Vector2(18, 535), Color(0.74, 0.48, 0.20))
    _rect(Vector2(285, 120), Vector2(615, 16), Color(0.86, 0.64, 0.26))
    _rect(Vector2(530, 610), Vector2(95, 24), Color(0.36, 0.08, 0.08))
    _label("DRAIN", Vector2(548, 611), Vector2(70, 22), 16, Color(1.0, 0.64, 0.46))

    _draw_lane(Vector2(320, 145), Vector2(360, 515), "opal lane")
    _draw_lane(Vector2(865, 145), Vector2(820, 515), "cinder lane")
    for t in targets:
        _draw_target(t)
    if gate_open:
        _rect(Vector2(710, 430), Vector2(90, 12), Color(0.24, 0.95, 0.38))
        _label("GATE OPEN", Vector2(705, 408), Vector2(110, 20), 14, Color(0.62, 1.0, 0.64))
    if boss_shield and (chamber >= 3 or scenario == "boss_table"):
        _rect(Vector2(540, 94), Vector2(200, 13), Color(0.9, 0.22, 0.22, 0.85))
        _label("CURSED SHIELD: hit spinner to unlock boss plate", Vector2(435, 72), Vector2(430, 22), 16, Color(1.0, 0.68, 0.62))

    left_flip = lerp(left_flip, 1.0 if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) else 0.0, 0.55)
    right_flip = lerp(right_flip, 1.0 if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) else 0.0, 0.55)
    _rect(Vector2(420, 575), Vector2(165, 18), Color(0.95, 0.62, 0.20), -0.28 - left_flip * 0.32)
    _rect(Vector2(685, 575), Vector2(165, 18), Color(0.95, 0.62, 0.20), 0.28 + right_flip * 0.32)

    _draw_ball(ball, Color(0.82, 0.96, 1.0))
    if multiball:
        _draw_ball(ball2, Color(1.0, 0.55, 0.35))
    for s in sparks:
        _rect(s["pos"], Vector2(16, 16), s["color"])

    _rect(Vector2(970, 130), Vector2(245, 505), Color(0.12, 0.07, 0.09))
    _label("ACTIVE RELICS", Vector2(995, 155), Vector2(180, 28), 24, Color(1.0, 0.78, 0.36))
    var ry := 200
    for r in relics:
        _rect(Vector2(995, ry), Vector2(175, 56), Color(0.28, 0.12, 0.23))
        _label(r, Vector2(1010, ry + 8), Vector2(145, 20), 18, Color(1.0, 0.85, 0.45))
        ry += 68
    _label("Mechanisms\nSpinner charge: %d/3\nGate: %s\nPortal: %s\nBoss shield: %s" % [spinner, "open" if gate_open else "locked", "ready" if portal_ready else "cooling", "on" if boss_shield else "broken"], Vector2(995, 420), Vector2(190, 135), 18)

func _draw_lane(a: Vector2, b: Vector2, text: String) -> void:
    var mid := (a + b) * 0.5
    var len := a.distance_to(b)
    _rect(mid - Vector2(len * 0.5, 4), Vector2(len, 8), Color(0.26, 0.18, 0.12), (b - a).angle())
    _label(text, mid + Vector2(-45, -22), Vector2(100, 20), 13, Color(0.84, 0.68, 0.42))

func _draw_target(t: Dictionary) -> void:
    var c: Color = t["color"]
    var hp: int = t["hp"]
    if hp <= 0:
        c = Color(0.12, 0.10, 0.10)
    _rect(t["pos"], t["size"], c)
    _label("%s %d" % [String(t["kind"]).to_upper(), max(hp, 0)], t["pos"] + Vector2(3, 6), t["size"], 13, Color.WHITE)

func _draw_ball(pos: Vector2, color: Color) -> void:
    _rect(pos - Vector2(13, 13), Vector2(26, 26), Color(1.0, 1.0, 1.0, 0.25))
    _rect(pos - Vector2(10, 10), Vector2(20, 20), color)
    if magnet_relic:
        _rect(pos - Vector2(22, 22), Vector2(44, 44), Color(0.25, 0.85, 1.0, 0.18))
    if fire_relic:
        _rect(pos + Vector2(-18, 8), Vector2(20, 8), Color(1.0, 0.35, 0.10, 0.65))

func _process(delta: float) -> void:
    if mode != "table":
        return
    if Input.is_key_pressed(KEY_SPACE) and not launched:
        launched = true
        vel = Vector2(-195, -305)
        if multiball:
            vel2 = Vector2(175, -285)
        message = "Ball launched. Hit flippers to keep it alive."
    if launched:
        _step_ball(delta, false)
        if multiball:
            _step_ball(delta, true)
    for s in sparks:
        s["life"] -= delta
    sparks = sparks.filter(func(s): return s["life"] > 0)
    if hits >= objective:
        _show_relic_choice()
        return
    _draw_table()

func _step_ball(delta: float, second := false) -> void:
    var p := ball2 if second else ball
    var v := vel2 if second else vel
    if magnet_relic:
        for t in targets:
            if t["hp"] > 0 and p.distance_to(t["pos"] + t["size"] * 0.5) < 145:
                v += (t["pos"] + t["size"] * 0.5 - p).normalized() * 42.0 * delta
                break
    v.y += 260.0 * delta
    p += v * delta
    if p.x < 292 or p.x > 895:
        v.x *= -0.92
        p.x = clamp(p.x, 292, 895)
        _spark(p, Color(0.95, 0.72, 0.25))
    if p.y < 142:
        v.y = abs(v.y) * 0.94
        _spark(p, Color(0.95, 0.72, 0.25))
    if p.y > 650:
        balls -= 1
        p = Vector2(840, 565)
        v = Vector2.ZERO
        launched = false
        message = "Ball drained. Launch the next one." if balls > 0 else "All balls lost."
        if balls <= 0:
            _show_result(false)
            return
    var left_pressed := Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)
    var right_pressed := Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)
    if p.y > 555 and p.y < 610 and p.x > 400 and p.x < 600 and left_pressed:
        v = Vector2(185, -345)
        combo += 1
        _spark(p, Color(1.0, 0.48, 0.18))
    if p.y > 555 and p.y < 610 and p.x > 660 and p.x < 860 and right_pressed:
        v = Vector2(-185, -345)
        combo += 1
        _spark(p, Color(1.0, 0.48, 0.18))
    for t in targets:
        if t["hp"] > 0 and Rect2(t["pos"] - Vector2(14, 14), t["size"] + Vector2(28, 28)).has_point(p):
            if t["kind"] == "boss" and boss_shield:
                v.y = abs(v.y)
                message = "Boss shield rejects the ball; charge the spinner."
            else:
                t["hp"] -= 2 if fire_relic else 1
                score += 50 * combo
                hits += 1
                _spark(p, Color(1.0, 0.88, 0.34))
                if t["kind"] == "bumper":
                    v = (p - (t["pos"] + t["size"] * 0.5)).normalized() * 360
                    score += 70
                elif t["kind"] == "spinner":
                    spinner += 1
                    if spinner >= 3:
                        gate_open = true
                        boss_shield = false
                        message = "Spinner charged: gate open and boss shield broken."
                    v.y *= -1.05
                elif t["kind"] == "gate":
                    gate_open = true
                    v.x *= -1
                    message = "Gate lock released; new lane is open."
                elif t["kind"] == "portal" and portal_ready:
                    p = Vector2(805, 175)
                    portal_ready = false
                    message = "Portal warp sends the ball to the upper lane."
                else:
                    v.y *= -1
                if t["hp"] <= 0:
                    score += 120
                    if echo_relic:
                        score += 80
            break
    if second:
        ball2 = p
        vel2 = v
    else:
        ball = p
        vel = v

func _spark(pos: Vector2, color: Color) -> void:
    sparks.append({"pos": pos + Vector2(-8, -8), "color": color, "life": 0.25})

func _show_relic_choice() -> void:
    mode = "relics"
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.055, 0.035, 0.06))
    _rect(Vector2(180, 105), Vector2(920, 510), Color(0.13, 0.08, 0.10))
    _label("CHAMBER RELIC", Vector2(420, 145), Vector2(480, 50), 44, Color(1.0, 0.78, 0.36))
    _label("Choose a relic. The active row persists into later tables.", Vector2(385, 205), Vector2(520, 30), 21)
    _relic_card("Magnet Moon", "Ball bends toward metal targets.", Vector2(260, 285), Callable(self, "_take_magnet"))
    _relic_card("Fireglass", "Ball cracks targets twice per hit.", Vector2(530, 285), Callable(self, "_take_fire"))
    _relic_card("Echo Bell", "Cleared banks echo bonus score.", Vector2(800, 285), Callable(self, "_take_echo"))

func _relic_card(name: String, desc: String, pos: Vector2, cb: Callable) -> void:
    _rect(pos, Vector2(210, 235), Color(0.26, 0.12, 0.22))
    _rect(pos + Vector2(58, 28), Vector2(94, 70), Color(0.95, 0.72, 0.25))
    _label(name, pos + Vector2(22, 120), Vector2(166, 28), 22, Color(1.0, 0.86, 0.45))
    _label(desc, pos + Vector2(22, 156), Vector2(166, 56), 16)
    _button("Choose", pos + Vector2(45, 188), Vector2(120, 34), cb)

func _take_magnet() -> void:
    magnet_relic = true
    _add_relic("Magnet Moon")

func _take_fire() -> void:
    fire_relic = true
    _add_relic("Fireglass")

func _take_echo() -> void:
    echo_relic = true
    _add_relic("Echo Bell")

func _add_relic(name: String) -> void:
    if not relics.has(name):
        relics.append(name)
    chamber += 1
    objective += 3
    hits = 0
    if chamber > 3:
        _show_result(true)
    else:
        _start_table()

func _show_result_win() -> void:
    _show_result(true)

func _show_result(win: bool) -> void:
    mode = "result"
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.055, 0.035, 0.06))
    _rect(Vector2(300, 150), Vector2(680, 390), Color(0.13, 0.08, 0.10))
    _label("VICTORY: FINAL LOCK OPEN" if win else "DEFEAT: TABLE DRAINED", Vector2(375, 205), Vector2(540, 54), 38, Color(1.0, 0.78, 0.36))
    _label("Score: %d\nChamber reached: %d\nRelics: %s\nTarget hits: %d\nBoss rule: spinner breaks the cursed shield before final scoring." % [score, chamber, ", ".join(relics) if relics.size() > 0 else "none", hits], Vector2(420, 300), Vector2(455, 120), 23)
    _button("Retry", Vector2(430, 465), Vector2(170, 50), Callable(self, "_restart"))
    _button("Title", Vector2(680, 465), Vector2(170, 50), Callable(self, "_show_title"))

func _restart() -> void:
    score = 0
    balls = 3
    chamber = 1
    objective = 6
    hits = 0
    relics = []
    _start_table()
EOF

cat > "$GAME/demo_outputs/01_title_to_table.json" <<'EOF'
{"duration_frames":420,"events":[{"frame":25,"type":"mouse_click","button":"left","x":640,"y":612},{"frame":65,"type":"key_press","keycode":"SPACE"},{"frame":125,"type":"key_down","keycode":"LEFT"},{"frame":160,"type":"key_up","keycode":"LEFT"},{"frame":205,"type":"key_down","keycode":"RIGHT"},{"frame":240,"type":"key_up","keycode":"RIGHT"},{"frame":400,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/02_target_bank.json" <<'EOF'
{"scenario":"target_bank","duration_frames":360,"events":[{"frame":60,"type":"key_down","keycode":"LEFT"},{"frame":95,"type":"key_up","keycode":"LEFT"},{"frame":155,"type":"key_down","keycode":"RIGHT"},{"frame":190,"type":"key_up","keycode":"RIGHT"},{"frame":330,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/03_mechanism_showcase.json" <<'EOF'
{"scenario":"mechanism_showcase","duration_frames":360,"events":[{"frame":70,"type":"key_down","keycode":"RIGHT"},{"frame":115,"type":"key_up","keycode":"RIGHT"},{"frame":175,"type":"key_down","keycode":"LEFT"},{"frame":220,"type":"key_up","keycode":"LEFT"},{"frame":335,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/04_relic_choice.json" <<'EOF'
{"scenario":"relic_choice","duration_frames":260,"events":[{"frame":85,"type":"mouse_click","button":"left","x":592,"y":492},{"frame":235,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/05_magnet_relic.json" <<'EOF'
{"scenario":"magnet_relic","duration_frames":360,"events":[{"frame":60,"type":"key_down","keycode":"LEFT"},{"frame":100,"type":"key_up","keycode":"LEFT"},{"frame":165,"type":"key_down","keycode":"RIGHT"},{"frame":205,"type":"key_up","keycode":"RIGHT"},{"frame":330,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/06_multiball.json" <<'EOF'
{"scenario":"multiball","duration_frames":360,"events":[{"frame":45,"type":"key_down","keycode":"LEFT"},{"frame":82,"type":"key_up","keycode":"LEFT"},{"frame":130,"type":"key_down","keycode":"RIGHT"},{"frame":180,"type":"key_up","keycode":"RIGHT"},{"frame":335,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/07_boss_table.json" <<'EOF'
{"scenario":"boss_table","duration_frames":360,"events":[{"frame":70,"type":"key_down","keycode":"LEFT"},{"frame":112,"type":"key_up","keycode":"LEFT"},{"frame":170,"type":"key_down","keycode":"RIGHT"},{"frame":215,"type":"key_up","keycode":"RIGHT"},{"frame":335,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/08_near_victory.json" <<'EOF'
{"scenario":"near_victory","duration_frames":180,"events":[{"frame":150,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/09_near_defeat.json" <<'EOF'
{"scenario":"near_defeat","duration_frames":180,"events":[{"frame":150,"type":"wait"}]}
EOF
