#!/usr/bin/env bash
# Oracle reference implementation for simulation-air-control.
# Minimal ATC radar game: draw paths, land planes, avoid collisions.
set -euo pipefail

GAME_DIR="/workspace/game"
mkdir -p "$GAME_DIR/scripts" "$GAME_DIR/demo_outputs"

cat > "$GAME_DIR/project.godot" << 'PREF'
; Engine configuration file.
[gd_resource type="ProjectSettings" format=3]

config_version=5

[application]
config/name="Air Control"
run/main_scene="res://Main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
PREF

cat > "$GAME_DIR/Main.tscn" << 'TSCN'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/Main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
TSCN

cat > "$GAME_DIR/scripts/Main.gd" << 'GDSCRIPT'
extends Node2D

enum GS { TITLE, PLAYING, LEVEL_SUMMARY, UPGRADE }
var state := GS.TITLE

# Aircraft
var aircraft: Array = []
var next_spawn_timer := 3.0
var spawn_interval := 4.0
var rng := RandomNumberGenerator.new()

# Runways
var runways := [
    {"x": 200.0, "y": 600.0, "w": 120.0, "h": 20.0, "type": "A", "label": "RWY-A"},
    {"x": 900.0, "y": 600.0, "w": 120.0, "h": 20.0, "type": "B", "label": "RWY-B"},
    {"x": 550.0, "y": 650.0, "w": 120.0, "h": 20.0, "type": "C", "label": "RWY-C"}
]

# Path drawing
var selected_aircraft := -1
var drawn_path: Array = []
var drawing := false

# Score / stats
var score := 0
var planes_landed := 0
var near_misses := 0
var level := 1
var level_timer := 60.0
var time_left := 60.0

# Weather
var weather := "clear"
var weather_timer := 15.0

# Upgrades
var upgrades_available := ["Extra Runway", "Weather Radar", "Auto-Land Assist", "Speed Boost"]
var upgrades_owned: Array = []

# Aircraft types
var ac_types := [
    {"name": "PROP", "speed": 60.0, "color": Color(0.3, 0.8, 0.3), "size": 10.0},
    {"name": "JET",  "speed": 100.0, "color": Color(0.3, 0.5, 1.0), "size": 14.0},
    {"name": "CARGO","speed": 70.0, "color": Color(0.8, 0.6, 0.2), "size": 16.0},
    {"name": "HELI", "speed": 50.0, "color": Color(0.8, 0.3, 0.8), "size": 9.0}
]

# UI
var title_panel: ColorRect
var hud_label: Label
var weather_label: Label
var summary_panel: ColorRect
var summary_label: Label
var upgrade_panel: ColorRect

var scenario := ""

func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]

    rng.seed = 42
    _build_ui()

    if scenario == "gameplay":
        state = GS.PLAYING
        _spawn_aircraft()
        _spawn_aircraft()
    elif scenario == "summary":
        planes_landed = 8
        near_misses = 1
        score = 240
        state = GS.LEVEL_SUMMARY
        _show_summary()
    else:
        state = GS.TITLE
        title_panel.visible = true

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.05, 0.1, 0.05)
    bg.size = Vector2(1280, 720)
    add_child(bg)

    # Radar grid lines
    for i in range(8):
        var grid_line := ColorRect.new()
        grid_line.color = Color(0.0, 0.3, 0.0, 0.3)
        grid_line.position = Vector2(i * 160, 0)
        grid_line.size = Vector2(1, 720)
        add_child(grid_line)
    for i in range(5):
        var grid_line := ColorRect.new()
        grid_line.color = Color(0.0, 0.3, 0.0, 0.3)
        grid_line.position = Vector2(0, i * 144)
        grid_line.size = Vector2(1280, 1)
        add_child(grid_line)

    # Title
    title_panel = ColorRect.new()
    title_panel.color = Color(0.0, 0.0, 0.0, 0.92)
    title_panel.size = Vector2(1280, 720)
    title_panel.visible = false
    add_child(title_panel)

    var tl := Label.new()
    tl.text = "AIR CONTROL\nRadar-based ATC Simulation\n\nClick aircraft to select, then click to draw flight path.\nLand planes on matching runways!"
    tl.position = Vector2(340, 180)
    tl.add_theme_font_size_override("font_size", 34)
    tl.modulate = Color(0.3, 1.0, 0.3)
    title_panel.add_child(tl)

    var sb := Button.new()
    sb.text = "BEGIN SHIFT"
    sb.position = Vector2(490, 440)
    sb.size = Vector2(300, 65)
    sb.add_theme_font_size_override("font_size", 28)
    sb.pressed.connect(_on_start)
    title_panel.add_child(sb)

    # HUD
    hud_label = Label.new()
    hud_label.position = Vector2(10, 10)
    hud_label.add_theme_font_size_override("font_size", 20)
    hud_label.modulate = Color(0.3, 1.0, 0.3)
    add_child(hud_label)

    weather_label = Label.new()
    weather_label.position = Vector2(1050, 10)
    weather_label.add_theme_font_size_override("font_size", 20)
    weather_label.modulate = Color(0.8, 0.8, 0.3)
    add_child(weather_label)

    # Summary
    summary_panel = ColorRect.new()
    summary_panel.color = Color(0.0, 0.05, 0.0, 0.92)
    summary_panel.size = Vector2(600, 380)
    summary_panel.position = Vector2(340, 170)
    summary_panel.visible = false
    add_child(summary_panel)

    summary_label = Label.new()
    summary_label.position = Vector2(50, 30)
    summary_label.add_theme_font_size_override("font_size", 26)
    summary_label.modulate = Color(0.3, 1.0, 0.3)
    summary_panel.add_child(summary_label)

    var next_btn := Button.new()
    next_btn.text = "Next Level"
    next_btn.position = Vector2(200, 300)
    next_btn.size = Vector2(200, 50)
    next_btn.pressed.connect(_on_next_level)
    summary_panel.add_child(next_btn)

    # Upgrade panel
    upgrade_panel = ColorRect.new()
    upgrade_panel.color = Color(0.0, 0.05, 0.0, 0.92)
    upgrade_panel.size = Vector2(700, 420)
    upgrade_panel.position = Vector2(290, 150)
    upgrade_panel.visible = false
    add_child(upgrade_panel)

    var ul := Label.new()
    ul.text = "UPGRADES — Choose one:"
    ul.position = Vector2(150, 20)
    ul.add_theme_font_size_override("font_size", 30)
    ul.modulate = Color(0.3, 1.0, 0.3)
    upgrade_panel.add_child(ul)

    for i in range(4):
        var btn := Button.new()
        btn.text = upgrades_available[i]
        btn.position = Vector2(100, 90 + i * 70)
        btn.size = Vector2(500, 55)
        btn.add_theme_font_size_override("font_size", 22)
        btn.pressed.connect(_on_upgrade.bind(i))
        upgrade_panel.add_child(btn)

func _on_start() -> void:
    title_panel.visible = false
    state = GS.PLAYING
    _spawn_aircraft()
    _spawn_aircraft()

func _on_next_level() -> void:
    summary_panel.visible = false
    state = GS.UPGRADE
    upgrade_panel.visible = true

func _on_upgrade(idx: int) -> void:
    upgrade_panel.visible = false
    upgrades_owned.append(upgrades_available[idx])
    level += 1
    time_left = 60.0
    spawn_interval = max(2.0, spawn_interval - 0.3)
    state = GS.PLAYING
    _spawn_aircraft()

func _spawn_aircraft() -> void:
    var edges := [
        Vector2(rng.randf_range(100, 1180), 30.0),
        Vector2(rng.randf_range(100, 1180), 680.0),
        Vector2(30.0, rng.randf_range(80, 620)),
        Vector2(1250.0, rng.randf_range(80, 620))
    ]
    var pos: Vector2 = edges[rng.randi_range(0, 3)]
    var t_idx := rng.randi_range(0, 3)
    var rwy_idx := rng.randi_range(0, 2)
    var callsign := "AC%d%d" % [rng.randi_range(1, 9), rng.randi_range(10, 99)]
    aircraft.append({
        "x": pos.x, "y": pos.y,
        "vx": 0.0, "vy": 0.0,
        "type": t_idx,
        "callsign": callsign,
        "dest_rwy": rwy_idx,
        "path": [],
        "path_idx": 0,
        "landed": false,
        "warning": false
    })

func _process(delta: float) -> void:
    if state == GS.PLAYING:
        _update(delta)
    _update_hud()
    queue_redraw()

func _update(delta: float) -> void:
    time_left -= delta
    if time_left <= 0.0:
        _show_summary()
        return

    # Weather cycle
    weather_timer -= delta
    if weather_timer <= 0.0:
        weather_timer = rng.randf_range(10.0, 20.0)
        var weathers := ["clear", "fog", "storm", "crosswind"]
        weather = weathers[rng.randi_range(0, 3)]

    # Spawn
    next_spawn_timer -= delta
    if next_spawn_timer <= 0.0:
        next_spawn_timer = spawn_interval + rng.randf_range(-0.5, 0.5)
        if aircraft.size() < 6 + level:
            _spawn_aircraft()

    # Move aircraft along paths
    for ac in aircraft:
        if ac["landed"]:
            continue
        var path: Array = ac["path"]
        var pidx: int = ac["path_idx"]
        if pidx < path.size():
            var target: Vector2 = path[pidx]
            var pos := Vector2(float(ac["x"]), float(ac["y"]))
            var dir := (target - pos)
            var dist := dir.length()
            var t_data: Dictionary = ac_types[int(ac["type"])]
            var spd: float = float(t_data["speed"])
            if weather == "storm":
                spd *= 0.7
            if dist < spd * delta:
                ac["x"] = target.x
                ac["y"] = target.y
                ac["path_idx"] = pidx + 1
            else:
                var d := dir.normalized()
                ac["x"] = float(ac["x"]) + d.x * spd * delta
                ac["y"] = float(ac["y"]) + d.y * spd * delta
        else:
            # Drift forward
            if float(ac["x"]) < 640.0:
                ac["x"] = float(ac["x"]) + 30.0 * delta
            else:
                ac["x"] = float(ac["x"]) - 30.0 * delta

    # Check landing
    for ac in aircraft:
        if ac["landed"]:
            continue
        var rwy: Dictionary = runways[int(ac["dest_rwy"])]
        var rwy_center := Vector2(float(rwy["x"]) + float(rwy["w"]) / 2.0, float(rwy["y"]))
        if Vector2(float(ac["x"]), float(ac["y"])).distance_to(rwy_center) < 40.0:
            ac["landed"] = true
            planes_landed += 1
            score += 30

    # Proximity warnings
    for i in range(aircraft.size()):
        aircraft[i]["warning"] = false
    for i in range(aircraft.size()):
        for j in range(i + 1, aircraft.size()):
            var a: Dictionary = aircraft[i]
            var b: Dictionary = aircraft[j]
            if bool(a["landed"]) or bool(b["landed"]):
                continue
            var dist := Vector2(float(a["x"]), float(a["y"])).distance_to(Vector2(float(b["x"]), float(b["y"])))
            if dist < 80.0:
                aircraft[i]["warning"] = true
                aircraft[j]["warning"] = true
                if dist < 30.0:
                    near_misses += 1
                    score = max(0, score - 20)

    aircraft = aircraft.filter(func(ac): return not bool(ac["landed"]) or float(ac["x"]) > -100.0)

func _show_summary() -> void:
    state = GS.LEVEL_SUMMARY
    summary_panel.visible = true
    var efficiency := int(float(planes_landed) / max(1, planes_landed + near_misses) * 100.0)
    summary_label.text = "LEVEL %d COMPLETE\n\nPlanes Landed: %d\nNear-Misses: %d\nEfficiency: %d%%\nScore: %d\n\nWeather Events: %s" % [
        level, planes_landed, near_misses, efficiency, score, weather.to_upper()
    ]

func _update_hud() -> void:
    if state != GS.PLAYING:
        return
    hud_label.text = "Score: %d  |  Landed: %d  |  Time: %.0fs  |  Level: %d  |  Aircraft: %d" % [
        score, planes_landed, time_left, level, aircraft.size()
    ]
    weather_label.text = "WX: %s" % weather.to_upper()

func _input(event: InputEvent) -> void:
    if state != GS.PLAYING:
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var mp: Vector2 = event.position
        # Check if clicking on aircraft
        var clicked_ac := -1
        for i in range(aircraft.size()):
            var ac: Dictionary = aircraft[i]
            if bool(ac["landed"]):
                continue
            if Vector2(float(ac["x"]), float(ac["y"])).distance_to(mp) < 20.0:
                clicked_ac = i
                break
        if clicked_ac >= 0:
            selected_aircraft = clicked_ac
            drawn_path = [mp]
            drawing = true
        elif drawing and selected_aircraft >= 0:
            drawn_path.append(mp)
            aircraft[selected_aircraft]["path"] = drawn_path.duplicate()
            aircraft[selected_aircraft]["path_idx"] = 0
    elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if drawing and selected_aircraft >= 0:
            aircraft[selected_aircraft]["path"] = drawn_path.duplicate()
            aircraft[selected_aircraft]["path_idx"] = 0
        drawing = false
        selected_aircraft = -1
    elif event is InputEventMouseMotion and drawing and selected_aircraft >= 0:
        drawn_path.append(event.position)

func _draw() -> void:
    if state == GS.TITLE:
        return

    # Runways
    for rwy in runways:
        draw_rect(Rect2(float(rwy["x"]), float(rwy["y"]), float(rwy["w"]), float(rwy["h"])), Color(0.5, 0.5, 0.5))
        draw_string(ThemeDB.fallback_font, Vector2(float(rwy["x"]) + 5.0, float(rwy["y"]) - 8.0),
            str(rwy["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.3, 1.0, 0.3))

    # Aircraft paths
    for i in range(aircraft.size()):
        var ac: Dictionary = aircraft[i]
        if bool(ac["landed"]):
            continue
        var path: Array = ac["path"]
        var pidx: int = ac["path_idx"]
        if path.size() > pidx + 1:
            for j in range(pidx, path.size() - 1):
                draw_line(path[j], path[j + 1], Color(0.0, 0.8, 0.0, 0.5), 2.0)

    # Aircraft
    for i in range(aircraft.size()):
        var ac: Dictionary = aircraft[i]
        if bool(ac["landed"]):
            continue
        var pos := Vector2(float(ac["x"]), float(ac["y"]))
        var t_data: Dictionary = ac_types[int(ac["type"])]
        var col: Color = t_data["color"]
        if bool(ac["warning"]):
            col = Color(1.0, 0.2, 0.2)
        var sz: float = float(t_data["size"])
        draw_circle(pos, sz, col)
        draw_string(ThemeDB.fallback_font, pos + Vector2(sz + 2.0, -4.0),
            str(ac["callsign"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 1.0, 0.3))
        # Destination indicator
        var rwy: Dictionary = runways[int(ac["dest_rwy"])]
        draw_string(ThemeDB.fallback_font, pos + Vector2(sz + 2.0, 10.0),
            "→" + str(rwy["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.3))
        if bool(ac["warning"]):
            draw_circle(pos, sz + 8.0, Color(1.0, 0.0, 0.0, 0.4))

    # Selected aircraft path preview
    if drawing and drawn_path.size() > 1:
        for i in range(drawn_path.size() - 1):
            draw_line(drawn_path[i], drawn_path[i + 1], Color(0.0, 1.0, 0.0, 0.8), 2.0)
GDSCRIPT

cat > "$GAME_DIR/demo_outputs/01_title.json" << 'DEMO'
{
  "duration_frames": 300,
  "events": [
    {"frame": 60, "type": "mouse_click", "button": "left", "x": 640, "y": 473}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/02_gameplay.json" << 'DEMO'
{
  "scenario": "gameplay",
  "duration_frames": 540,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 200, "y": 200},
    {"frame": 60,  "type": "mouse_click", "button": "left", "x": 260, "y": 580},
    {"frame": 90,  "type": "mouse_click", "button": "left", "x": 600, "y": 150},
    {"frame": 120, "type": "mouse_click", "button": "left", "x": 960, "y": 580},
    {"frame": 150, "type": "wait"},
    {"frame": 240, "type": "mouse_click", "button": "left", "x": 400, "y": 300},
    {"frame": 270, "type": "mouse_click", "button": "left", "x": 610, "y": 630},
    {"frame": 300, "type": "wait"},
    {"frame": 390, "type": "mouse_click", "button": "left", "x": 700, "y": 200},
    {"frame": 420, "type": "mouse_click", "button": "left", "x": 960, "y": 580},
    {"frame": 480, "type": "wait"}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/03_summary.json" << 'DEMO'
{
  "scenario": "summary",
  "duration_frames": 300,
  "events": [
    {"frame": 60,  "type": "wait"},
    {"frame": 180, "type": "mouse_click", "button": "left", "x": 540, "y": 470}
  ]
}
DEMO

echo "Oracle written to $GAME_DIR"
