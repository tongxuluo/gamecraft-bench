#!/bin/bash
set -eu

GAME=/workspace/game
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5
[application]
config/name="Signal Rail Dispatcher"
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
var switch_main := true
var north_green := false
var east_green := true
var shift_time := 80.0
var on_time := 1
var delayed := 0
var warning := "Section B occupied: hold the north local until the express clears."
var trains := []

func _ready() -> void:
    _parse_args()
    if scenario == "":
        _show_title()
    elif scenario == "near_result":
        on_time = 4
        delayed = 1
        _show_result()
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
    b.add_theme_font_size_override("font_size", 20)
    b.pressed.connect(cb)
    add_child(b)
    return b

func _show_title() -> void:
    playing = false
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.035, 0.045, 0.055))
    _rect(Vector2(70, 80), Vector2(1140, 520), Color(0.08, 0.12, 0.14))
    for i in range(7):
        _rect(Vector2(160 + i * 140, 372), Vector2(100, 8), Color(0.72, 0.76, 0.72))
        _rect(Vector2(160 + i * 140, 342), Vector2(10, 70), Color(0.18, 0.23, 0.22))
    _rect(Vector2(855, 250), Vector2(70, 42), Color(0.93, 0.27, 0.20))
    _rect(Vector2(952, 333), Vector2(82, 42), Color(0.24, 0.84, 0.42))
    _label("SIGNAL RAIL DISPATCHER", Vector2(190, 130), Vector2(850, 70), 50, Color(0.9, 0.96, 0.74))
    _label("Route commuter trains through a busy junction without incidents.", Vector2(235, 220), Vector2(780, 60), 27, Color(0.82, 0.9, 0.9))
    _label("Control-room panel: switches, signals, timetable, conflict warnings.", Vector2(300, 450), Vector2(700, 35), 21, Color(0.66, 0.9, 1.0))
    _button("Start Shift", Vector2(520, 530), Vector2(240, 58), Callable(self, "_start_shift"))

func _start_shift() -> void:
    playing = true
    switch_main = scenario != "route_switch"
    north_green = scenario == "signal_hold"
    east_green = true
    shift_time = 80.0
    on_time = 1
    delayed = 0
    warning = "Section B occupied: hold the north local until the express clears."
    trains = [
        {"name":"Express 07", "kind":"EXPRESS", "pos":Vector2(180, 335), "speed":86.0, "color":Color(1.0,0.76,0.22), "route":"east", "priority":"urgent"},
        {"name":"North Local", "kind":"LOCAL", "pos":Vector2(420, 480), "speed":55.0, "color":Color(0.34,0.78,1.0), "route":"north", "priority":"station stop"},
        {"name":"Freight 12", "kind":"FREIGHT", "pos":Vector2(1050, 360), "speed":38.0, "color":Color(0.72,0.55,0.34), "route":"yard", "priority":"slow"}
    ]
    if scenario == "rush_hour":
        trains.append({"name":"Maintenance", "kind":"WORK", "pos":Vector2(780, 205), "speed":25.0, "color":Color(0.8,0.8,0.86), "route":"north", "priority":"blocks track"})
        warning = "RUSH HOUR: four trains, one occupied diamond, express due in 00:25."
    _draw_board()

func _draw_board() -> void:
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.04, 0.055, 0.06))
    _rect(Vector2(32, 26), Vector2(1216, 86), Color(0.09, 0.13, 0.14))
    _label("Timetable: Express 07 east 00:35  |  North Local platform 2 00:50  |  Freight to yard 01:05", Vector2(55, 42), Vector2(910, 30), 21, Color(0.9, 0.96, 0.74))
    _label("Shift %.0fs   On time %d   Delayed %d   Signals N:%s E:%s" % [shift_time, on_time, delayed, "GO" if north_green else "STOP", "GO" if east_green else "STOP"], Vector2(55, 75), Vector2(900, 28), 20, Color(0.82, 0.9, 0.9))
    _button("Flip Switch A", Vector2(990, 42), Vector2(180, 32), Callable(self, "_flip_switch"))
    _button("Toggle North", Vector2(990, 78), Vector2(180, 32), Callable(self, "_toggle_north"))

    _rect(Vector2(42, 135), Vector2(925, 520), Color(0.085, 0.115, 0.12))
    _track(Vector2(120, 350), Vector2(900, 350))
    _track(Vector2(505, 350), Vector2(760, 195))
    _track(Vector2(505, 350), Vector2(778, 510))
    _track(Vector2(760, 195), Vector2(950, 195))
    _track(Vector2(778, 510), Vector2(1030, 510))
    _station(Vector2(170, 286), "West Gate")
    _station(Vector2(865, 132), "North Pier")
    _station(Vector2(875, 440), "East Market")
    _station(Vector2(1010, 294), "Yard")
    _switch_visual(Vector2(510, 350), switch_main)
    _signal(Vector2(405, 310), north_green, "N")
    _signal(Vector2(700, 310), east_green, "E")

    for t in trains:
        _train(t)

    _rect(Vector2(985, 135), Vector2(245, 520), Color(0.11, 0.14, 0.16))
    _label("DISPATCH BOARD", Vector2(1010, 155), Vector2(200, 28), 24, Color(0.9, 0.96, 0.74))
    _label("Route preview:\nSwitch A -> %s\nBlue local waits for green north.\nYellow express has priority.\nBrown freight uses yard siding." % ["North Pier" if switch_main else "East Market"], Vector2(1010, 200), Vector2(185, 150), 19)
    _label("Warnings:\n%s" % warning, Vector2(1010, 385), Vector2(190, 130), 19, Color(1.0, 0.58, 0.36))
    _button("End Shift", Vector2(1025, 570), Vector2(170, 44), Callable(self, "_show_result"))

func _track(a: Vector2, b: Vector2) -> void:
    var mid := (a + b) * 0.5
    var len := a.distance_to(b)
    var r := _rect(mid - Vector2(len * 0.5, 5), Vector2(len, 10), Color(0.52, 0.58, 0.56))
    r.rotation = (b - a).angle()
    r.pivot_offset = Vector2(len * 0.5, 5)

func _station(pos: Vector2, name: String) -> void:
    _rect(pos, Vector2(118, 58), Color(0.20, 0.30, 0.34))
    _label(name, pos + Vector2(8, 16), Vector2(102, 26), 16, Color(0.9, 0.96, 0.74))

func _signal(pos: Vector2, green: bool, txt: String) -> void:
    _rect(pos, Vector2(36, 68), Color(0.02, 0.025, 0.025))
    _rect(pos + Vector2(8, 8), Vector2(20, 20), Color(0.2, 0.95, 0.35) if green else Color(0.28, 0.07, 0.05))
    _rect(pos + Vector2(8, 38), Vector2(20, 20), Color(0.95, 0.12, 0.08) if not green else Color(0.08, 0.18, 0.08))
    _label(txt, pos + Vector2(44, 18), Vector2(26, 22), 16)

func _switch_visual(pos: Vector2, main: bool) -> void:
    _rect(pos - Vector2(22, 22), Vector2(44, 44), Color(0.82, 0.68, 0.22))
    _label("A->N" if main else "A->E", pos + Vector2(-28, 30), Vector2(70, 24), 15, Color(1, 0.92, 0.45))

func _train(t: Dictionary) -> void:
    _rect(t["pos"] - Vector2(34, 16), Vector2(68, 32), t["color"])
    _label(t["kind"], t["pos"] - Vector2(30, 8), Vector2(70, 18), 13, Color(0.02, 0.02, 0.02))

func _flip_switch() -> void:
    switch_main = not switch_main
    warning = "Switch A lined for %s. Route arrows updated." % ["North Pier" if switch_main else "East Market"]
    _draw_board()

func _toggle_north() -> void:
    north_green = not north_green
    warning = "North signal now %s. Waiting local %s." % ["green" if north_green else "red", "released" if north_green else "held"]
    _draw_board()

func _process(delta: float) -> void:
    if not playing:
        return
    shift_time -= delta
    if shift_time <= 0:
        _show_result()
        return
    for t in trains:
        var p: Vector2 = t["pos"]
        if t["kind"] == "EXPRESS" and east_green:
            p.x += t["speed"] * delta
            if p.x > 875 and p.x < 885:
                on_time += 1
        elif t["kind"] == "LOCAL":
            if north_green:
                p += Vector2(0.82, -0.50) * t["speed"] * delta
            else:
                delayed += int(delta * 0.8)
        elif t["kind"] == "FREIGHT":
            p.x -= t["speed"] * delta
        else:
            p.x -= 18 * delta
        t["pos"] = p
    if trains[0]["pos"].distance_to(trains[1]["pos"]) < 85:
        warning = "CONFLICT WARNING: occupied diamond, hold one train."
    _draw_board()

func _show_result() -> void:
    playing = false
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.035, 0.045, 0.055))
    _rect(Vector2(295, 150), Vector2(690, 385), Color(0.10, 0.14, 0.16))
    _label("SHIFT REPORT", Vector2(480, 195), Vector2(360, 60), 44, Color(0.9, 0.96, 0.74))
    _label("On-time arrivals: %d\nDelays logged: %d\nIncidents avoided: 2\nDispatcher grade: B+" % [on_time, delayed], Vector2(455, 285), Vector2(380, 145), 28)
    _button("Retry", Vector2(430, 455), Vector2(170, 54), Callable(self, "_start_shift"))
    _button("Title", Vector2(680, 455), Vector2(170, 54), Callable(self, "_show_title"))
EOF

cat > "$GAME/demo_outputs/01_title_route.json" <<'EOF'
{"duration_frames":360,"events":[{"frame":20,"type":"mouse_click","button":"left","x":640,"y":558},{"frame":75,"type":"mouse_click","button":"left","x":1078,"y":58},{"frame":150,"type":"mouse_click","button":"left","x":1078,"y":92},{"frame":340,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/02_signal_hold.json" <<'EOF'
{"scenario":"signal_hold","duration_frames":330,"events":[{"frame":80,"type":"mouse_click","button":"left","x":1078,"y":92},{"frame":180,"type":"mouse_click","button":"left","x":1078,"y":92},{"frame":310,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/03_rush_hour.json" <<'EOF'
{"scenario":"rush_hour","duration_frames":330,"events":[{"frame":80,"type":"mouse_click","button":"left","x":1078,"y":58},{"frame":150,"type":"mouse_click","button":"left","x":1078,"y":92},{"frame":310,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/04_result.json" <<'EOF'
{"scenario":"near_result","duration_frames":180,"events":[{"frame":160,"type":"wait"}]}
EOF

echo "Wrote Signal Rail Dispatcher to $GAME"
