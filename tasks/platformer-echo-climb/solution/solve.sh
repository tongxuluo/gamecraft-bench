#!/usr/bin/env bash
# Oracle reference implementation for platformer-echo-climb.
# Ghost-replay tower climber: past runs become solid platforms.
set -euo pipefail

GAME_DIR="/workspace/game"
mkdir -p "$GAME_DIR/scripts" "$GAME_DIR/demo_outputs"

###############################################################################
# project.godot
###############################################################################
cat > "$GAME_DIR/project.godot" << 'PREF'
; Engine configuration file.
[gd_resource type="ProjectSettings" format=3]

config_version=5

[application]
config/name="Echo Climb"
run/main_scene="res://Main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
PREF

###############################################################################
# Main.tscn
###############################################################################
cat > "$GAME_DIR/Main.tscn" << 'TSCN'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/Main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
TSCN

###############################################################################
# scripts/Main.gd
###############################################################################
cat > "$GAME_DIR/scripts/Main.gd" << 'GDSCRIPT'
extends Node2D

enum GS { TITLE, CLIMBING, ATTEMPT_END, STATS }
var state := GS.TITLE

const GRAVITY := 600.0
const JUMP_FORCE := -380.0
const SPEED := 200.0

var player_x := 640.0
var player_y := 650.0
var player_vy := 0.0
var on_ground := false

var current_height := 0.0
var best_height := 0.0
var attempt_count := 0
var total_ghosts := 0
var solidified_count := 0
var camera_y := 0.0

const TOWER_HEIGHT := 3000.0

var fixed_platforms: Array = []
var ghost_platforms: Array = []
var solidified_platforms: Array = []
var ghosts: Array = []
var current_recording: Array = []
var record_timer := 0.0

# UI
var title_panel: ColorRect
var hud_height: Label
var hud_best: Label
var hud_ghosts: Label
var end_panel: ColorRect
var end_label: Label
var solidify_btn: Button
var retry_btn: Button
var stats_panel: ColorRect

var scenario := ""

func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]

    _build_ui()
    _generate_tower()

    if scenario == "with_ghosts":
        attempt_count = 3
        total_ghosts = 3
        best_height = 800.0
        _add_demo_ghosts()
        state = GS.CLIMBING
    elif scenario == "stats":
        state = GS.STATS
        stats_panel.visible = true
    else:
        state = GS.TITLE
        title_panel.visible = true

func _generate_tower() -> void:
    fixed_platforms.clear()
    fixed_platforms.append({"x": 400.0, "y": 680.0, "w": 480.0, "h": 20.0})
    var rng := RandomNumberGenerator.new()
    rng.seed = 42
    var y := 580.0
    while y > -TOWER_HEIGHT:
        var x := float(rng.randi_range(100, 900))
        fixed_platforms.append({"x": x, "y": y, "w": float(rng.randi_range(80, 180)), "h": 16.0})
        y -= float(rng.randi_range(120, 220))

func _add_demo_ghosts() -> void:
    for g in range(3):
        var ghost_frames: Array = []
        for f in range(180):
            ghost_frames.append({"x": 640.0 + g * 30.0 - f * 0.5, "y": 650.0 - f * 2.5})
        ghosts.append({"frames": ghost_frames, "frame": 0, "x": 640.0, "y": 650.0})
        ghost_platforms.append({"x": 500.0 + g * 80.0, "y": 500.0 - g * 60.0, "w": 60.0, "h": 12.0})

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.05, 0.05, 0.12)
    bg.size = Vector2(1280, 720)
    add_child(bg)

    title_panel = ColorRect.new()
    title_panel.color = Color(0.0, 0.0, 0.0, 0.9)
    title_panel.size = Vector2(1280, 720)
    title_panel.visible = false
    add_child(title_panel)

    var tl := Label.new()
    tl.text = "ECHO CLIMB\nClimb the tower using ghost replays!\nGhosts from past runs become solid platforms."
    tl.position = Vector2(320, 200)
    tl.add_theme_font_size_override("font_size", 34)
    tl.modulate = Color.WHITE
    title_panel.add_child(tl)

    var sb := Button.new()
    sb.text = "START CLIMBING"
    sb.position = Vector2(490, 420)
    sb.size = Vector2(300, 60)
    sb.pressed.connect(_on_start)
    title_panel.add_child(sb)

    var stats_btn := Button.new()
    stats_btn.text = "STATS"
    stats_btn.position = Vector2(490, 500)
    stats_btn.size = Vector2(300, 50)
    stats_btn.pressed.connect(func(): state = GS.STATS; stats_panel.visible = true)
    title_panel.add_child(stats_btn)

    hud_height = Label.new()
    hud_height.position = Vector2(10, 10)
    hud_height.add_theme_font_size_override("font_size", 22)
    add_child(hud_height)

    hud_best = Label.new()
    hud_best.position = Vector2(10, 40)
    hud_best.add_theme_font_size_override("font_size", 22)
    add_child(hud_best)

    hud_ghosts = Label.new()
    hud_ghosts.position = Vector2(10, 70)
    hud_ghosts.add_theme_font_size_override("font_size", 22)
    add_child(hud_ghosts)

    end_panel = ColorRect.new()
    end_panel.color = Color(0.0, 0.0, 0.0, 0.88)
    end_panel.size = Vector2(600, 320)
    end_panel.position = Vector2(340, 200)
    end_panel.visible = false
    add_child(end_panel)

    end_label = Label.new()
    end_label.position = Vector2(50, 30)
    end_label.add_theme_font_size_override("font_size", 26)
    end_label.modulate = Color.WHITE
    end_panel.add_child(end_label)

    solidify_btn = Button.new()
    solidify_btn.text = "Solidify a Ghost (make permanent platform)"
    solidify_btn.position = Vector2(60, 180)
    solidify_btn.size = Vector2(480, 50)
    solidify_btn.pressed.connect(_on_solidify)
    end_panel.add_child(solidify_btn)

    retry_btn = Button.new()
    retry_btn.text = "Try Again"
    retry_btn.position = Vector2(200, 250)
    retry_btn.size = Vector2(200, 50)
    retry_btn.pressed.connect(_on_retry)
    end_panel.add_child(retry_btn)

    stats_panel = ColorRect.new()
    stats_panel.color = Color(0.05, 0.05, 0.2, 0.92)
    stats_panel.size = Vector2(700, 400)
    stats_panel.position = Vector2(290, 160)
    stats_panel.visible = false
    add_child(stats_panel)

    var sl := Label.new()
    sl.text = "STATS\nTotal Attempts: 0\nTotal Ghosts: 0\nSolidified: 0\nBest Height: 0m\nTime Played: --"
    sl.position = Vector2(100, 60)
    sl.add_theme_font_size_override("font_size", 26)
    sl.modulate = Color.WHITE
    stats_panel.add_child(sl)

    var back_btn := Button.new()
    back_btn.text = "Back"
    back_btn.position = Vector2(280, 320)
    back_btn.size = Vector2(140, 50)
    back_btn.pressed.connect(func(): stats_panel.visible = false; state = GS.TITLE; title_panel.visible = true)
    stats_panel.add_child(back_btn)

func _on_start() -> void:
    title_panel.visible = false
    _begin_attempt()

func _begin_attempt() -> void:
    player_x = 640.0
    player_y = 650.0
    player_vy = 0.0
    current_height = 0.0
    camera_y = 0.0
    current_recording.clear()
    record_timer = 0.0
    state = GS.CLIMBING

func _on_solidify() -> void:
    if not ghost_platforms.is_empty():
        var gp: Dictionary = ghost_platforms[0]
        solidified_platforms.append(gp)
        ghost_platforms.remove_at(0)
        solidified_count += 1
    end_panel.visible = false
    _begin_attempt()

func _on_retry() -> void:
    end_panel.visible = false
    _begin_attempt()

func _process(delta: float) -> void:
    if state == GS.CLIMBING:
        _update(delta)
    _update_hud()
    queue_redraw()

func _update(delta: float) -> void:
    player_vy += GRAVITY * delta
    player_y += player_vy * delta

    var mv := 0.0
    if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
        mv = -SPEED
    if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
        mv = SPEED
    player_x += mv * delta
    player_x = clamp(player_x, 20.0, 1260.0)

    on_ground = false
    var all_plats := fixed_platforms + ghost_platforms + solidified_platforms
    for p in all_plats:
        var py_world: float = float(p["y"]) + camera_y
        if (player_x >= float(p["x"]) and player_x <= float(p["x"]) + float(p["w"])
                and player_y + 16.0 >= py_world and player_y + 16.0 <= py_world + float(p["h"]) + 8.0
                and player_vy > 0.0):
            player_y = py_world - 16.0
            player_vy = 0.0
            on_ground = true

    if Input.is_key_pressed(KEY_SPACE) and on_ground:
        player_vy = JUMP_FORCE

    if player_y < 300.0:
        var scroll := 300.0 - player_y
        camera_y -= scroll
        player_y = 300.0
        current_height += scroll
        best_height = max(best_height, current_height)

    record_timer += delta
    if record_timer >= 1.0 / 30.0:
        record_timer = 0.0
        current_recording.append({"x": player_x, "y": player_y})

    for ghost in ghosts:
        if ghost["frame"] < ghost["frames"].size():
            var gf: Dictionary = ghost["frames"][ghost["frame"]]
            ghost["x"] = gf["x"]
            ghost["y"] = gf["y"] + camera_y
            ghost["frame"] += 1

    if player_y > 750.0:
        _end_attempt()

func _end_attempt() -> void:
    attempt_count += 1
    total_ghosts += 1
    var new_ghost_frames := current_recording.duplicate()
    ghosts.append({"frames": new_ghost_frames, "frame": 0, "x": 640.0, "y": 650.0})
    if not current_recording.is_empty():
        var mid: Dictionary = current_recording[current_recording.size() / 2]
        ghost_platforms.append({"x": mid["x"] - 30.0, "y": mid["y"] - camera_y, "w": 60.0, "h": 12.0})
    state = GS.ATTEMPT_END
    end_panel.visible = true
    end_label.text = "Attempt %d ended!\nHeight: %dm\nBest: %dm\nGhosts active: %d\nSolidified: %d" % [
        attempt_count, int(current_height), int(best_height), ghosts.size(), solidified_count
    ]
    solidify_btn.visible = not ghost_platforms.is_empty()

func _update_hud() -> void:
    hud_height.text = "Height: %dm  Best: %dm" % [int(current_height), int(best_height)]
    hud_best.text = "Attempt: %d" % attempt_count
    hud_ghosts.text = "Ghosts: %d  Solidified: %d" % [ghosts.size(), solidified_count]

func _draw() -> void:
    if state == GS.TITLE or state == GS.STATS:
        return

    for p in fixed_platforms:
        draw_rect(Rect2(p["x"], p["y"] + camera_y, p["w"], p["h"]), Color(0.4, 0.4, 0.6))

    for p in ghost_platforms:
        draw_rect(Rect2(p["x"], p["y"] + camera_y, p["w"], p["h"]), Color(0.3, 0.6, 0.9, 0.5))

    for p in solidified_platforms:
        draw_rect(Rect2(p["x"], p["y"] + camera_y, p["w"], p["h"]), Color(0.7, 0.8, 1.0))

    for ghost in ghosts:
        draw_rect(Rect2(ghost["x"] - 12.0, ghost["y"] - 16.0, 24.0, 32.0), Color(0.5, 0.7, 1.0, 0.4))

    if state == GS.CLIMBING:
        draw_rect(Rect2(player_x - 12.0, player_y - 16.0, 24.0, 32.0), Color(0.9, 0.8, 0.2))

    var best_y := 650.0 - best_height + camera_y
    draw_line(Vector2(0.0, best_y), Vector2(1280.0, best_y), Color(1.0, 0.5, 0.0, 0.5), 2.0)
GDSCRIPT

###############################################################################
# Demo traces
###############################################################################

cat > "$GAME_DIR/demo_outputs/01_title.json" << 'DEMO'
{
  "duration_frames": 300,
  "events": [
    {"frame": 60, "type": "mouse_click", "button": "left", "x": 640, "y": 450}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/02_with_ghosts.json" << 'DEMO'
{
  "scenario": "with_ghosts",
  "duration_frames": 480,
  "events": [
    {"frame": 30,  "type": "key_down",  "keycode": "RIGHT"},
    {"frame": 90,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 150, "type": "key_up",    "keycode": "RIGHT"},
    {"frame": 180, "type": "key_down",  "keycode": "LEFT"},
    {"frame": 240, "type": "key_press", "keycode": "SPACE"},
    {"frame": 300, "type": "key_up",    "keycode": "LEFT"},
    {"frame": 360, "type": "key_press", "keycode": "SPACE"},
    {"frame": 420, "type": "key_press", "keycode": "SPACE"}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/03_stats.json" << 'DEMO'
{
  "scenario": "stats",
  "duration_frames": 240,
  "events": [
    {"frame": 60, "type": "wait"}
  ]
}
DEMO

echo "Oracle written to $GAME_DIR"
