#!/usr/bin/env bash
# Oracle reference implementation for platformer-momentum-lab.
# Momentum-based platformer: build speed, wall-jump, collect gold, beat timer.
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
config/name="Momentum Lab"
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

enum GS { TITLE, LEVEL_SELECT, PLAYING, COMPLETE }
var state := GS.TITLE

# Player with momentum physics
var player_x := 100.0
var player_y := 400.0
var player_vx := 0.0
var player_vy := 0.0
const GRAVITY := 600.0
const JUMP_FORCE := -400.0
const ACCEL := 600.0
const MAX_SPEED := 400.0
const FRICTION := 0.85
const WALL_JUMP_VX := 300.0
var on_ground := false
var on_wall := false
var wall_dir := 0

# Level data
var current_lab := 0
var current_level := 0
var lab_names := ["Basic Lab", "Ice Lab", "Conveyor Lab", "Gravity Lab"]
var platforms: Array = []
var env_elements: Array = []
var gold_coins: Array = []
var key_pos := Vector2(-999.0, -999.0)
var key_collected := false
var exit_pos := Vector2(1100.0, 400.0)
var exit_open := false
var spawn_x := 80.0
var spawn_y := 400.0

# Timer and stats
var level_timer := 0.0
var time_limit := 30.0
var gold_count := 0
var total_gold := 0
var best_time := 9999.0

# UI
var title_panel: ColorRect
var level_select_panel: ColorRect
var hud_label: Label
var complete_panel: ColorRect
var complete_label: Label
var next_btn: Button

var scenario := ""

func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]

    _build_ui()

    if scenario == "level_select":
        state = GS.LEVEL_SELECT
        level_select_panel.visible = true
    elif scenario == "complete":
        state = GS.COMPLETE
        _show_complete(12.5)
    else:
        state = GS.TITLE
        title_panel.visible = true

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.08, 0.1, 0.12)
    bg.size = Vector2(1280, 720)
    add_child(bg)

    title_panel = ColorRect.new()
    title_panel.color = Color(0.0, 0.0, 0.0, 0.9)
    title_panel.size = Vector2(1280, 720)
    title_panel.visible = false
    add_child(title_panel)

    var tl := Label.new()
    tl.text = "MOMENTUM LAB\nBuild speed to reach gold and the exit!\nWall-jump preserves momentum.\nCollect the key to open the exit door."
    tl.position = Vector2(300, 180)
    tl.add_theme_font_size_override("font_size", 30)
    tl.modulate = Color.WHITE
    title_panel.add_child(tl)

    var sb := Button.new()
    sb.text = "START"
    sb.position = Vector2(540, 440)
    sb.size = Vector2(200, 60)
    sb.pressed.connect(_on_start)
    title_panel.add_child(sb)

    level_select_panel = ColorRect.new()
    level_select_panel.color = Color(0.05, 0.05, 0.1, 0.92)
    level_select_panel.size = Vector2(1280, 720)
    level_select_panel.visible = false
    add_child(level_select_panel)

    var ll := Label.new()
    ll.text = "SELECT LEVEL"
    ll.position = Vector2(490, 60)
    ll.add_theme_font_size_override("font_size", 36)
    ll.modulate = Color.WHITE
    level_select_panel.add_child(ll)

    for lab in range(4):
        for lv in range(5):
            var btn := Button.new()
            btn.text = "%d-%d" % [lab + 1, lv + 1]
            btn.position = Vector2(180 + lv * 180, 160 + lab * 100)
            btn.size = Vector2(140, 70)
            btn.pressed.connect(_on_level_select.bind(lab, lv))
            level_select_panel.add_child(btn)

    hud_label = Label.new()
    hud_label.position = Vector2(10, 10)
    hud_label.add_theme_font_size_override("font_size", 22)
    add_child(hud_label)

    complete_panel = ColorRect.new()
    complete_panel.color = Color(0.0, 0.2, 0.1, 0.9)
    complete_panel.size = Vector2(600, 300)
    complete_panel.position = Vector2(340, 210)
    complete_panel.visible = false
    add_child(complete_panel)

    complete_label = Label.new()
    complete_label.position = Vector2(50, 40)
    complete_label.add_theme_font_size_override("font_size", 26)
    complete_label.modulate = Color.WHITE
    complete_panel.add_child(complete_label)

    next_btn = Button.new()
    next_btn.text = "Next Level"
    next_btn.position = Vector2(200, 220)
    next_btn.size = Vector2(200, 50)
    next_btn.pressed.connect(_on_next)
    complete_panel.add_child(next_btn)

func _on_start() -> void:
    title_panel.visible = false
    state = GS.LEVEL_SELECT
    level_select_panel.visible = true

func _on_level_select(lab: int, lv: int) -> void:
    level_select_panel.visible = false
    current_lab = lab
    current_level = lv
    _load_level(lab, lv)

func _on_next() -> void:
    complete_panel.visible = false
    current_level += 1
    if current_level >= 5:
        current_lab = (current_lab + 1) % 4
        current_level = 0
    _load_level(current_lab, current_level)

func _load_level(lab: int, lv: int) -> void:
    state = GS.PLAYING
    level_timer = 0.0
    gold_count = 0
    key_collected = false
    exit_open = false

    var base_y := 580.0
    spawn_x = 80.0
    spawn_y = base_y - 20.0
    player_x = spawn_x
    player_y = spawn_y
    player_vx = 0.0
    player_vy = 0.0

    platforms = [
        {"x": 0.0, "y": base_y, "w": 200.0, "h": 20.0},
        {"x": 350.0, "y": base_y - 100.0, "w": 180.0, "h": 20.0},
        {"x": 650.0, "y": base_y - 60.0, "w": 180.0, "h": 20.0},
        {"x": 950.0, "y": base_y, "w": 330.0, "h": 20.0}
    ]

    # Environmental elements vary by lab
    env_elements = []
    match lab:
        1:
            env_elements = [{"x": 350.0, "y": base_y - 100.0, "w": 180.0, "h": 20.0, "type": "ice"}]
        2:
            env_elements = [{"x": 650.0, "y": base_y - 60.0, "w": 180.0, "h": 20.0, "type": "conveyor", "dir": 1.0}]
        3:
            env_elements = [{"x": 500.0, "y": base_y - 200.0, "w": 200.0, "h": 20.0, "type": "gravity_flip"}]

    gold_coins = [
        {"x": 400.0, "y": base_y - 130.0, "collected": false},
        {"x": 700.0, "y": base_y - 90.0, "collected": false},
        {"x": 1000.0, "y": base_y - 30.0, "collected": false}
    ]
    total_gold = gold_coins.size()

    key_pos = Vector2(550.0, base_y - 90.0)
    exit_pos = Vector2(1100.0, base_y - 20.0)
    time_limit = 30.0 - lv * 2.0

func _show_complete(time: float) -> void:
    complete_panel.visible = true
    best_time = min(best_time, time)
    var time_left := time_limit - time
    var stars := 1
    if time_left > 10.0: stars = 2
    if time_left > 20.0: stars = 3
    complete_label.text = "Level Complete!\nTime: %.1fs  Gold: %d/%d\nRating: %d Stars\nBest: %.1fs" % [
        time, gold_count, total_gold, stars, best_time
    ]

func _process(delta: float) -> void:
    if state == GS.PLAYING:
        _update(delta)
    _update_hud()
    queue_redraw()

func _update(delta: float) -> void:
    level_timer += delta

    # Timer expired = restart
    if level_timer >= time_limit:
        player_x = spawn_x
        player_y = spawn_y
        player_vx = 0.0
        player_vy = 0.0
        level_timer = 0.0
        key_collected = false
        exit_open = false
        for g in gold_coins:
            g["collected"] = false
        gold_count = 0
        return

    player_vy += GRAVITY * delta
    player_y += player_vy * delta

    # Momentum-based horizontal movement
    var input_dir := 0.0
    if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
        input_dir = -1.0
    if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
        input_dir = 1.0

    if input_dir != 0.0:
        player_vx += input_dir * ACCEL * delta
        player_vx = clamp(player_vx, -MAX_SPEED, MAX_SPEED)
    else:
        player_vx *= pow(FRICTION, delta * 60.0)

    player_x += player_vx * delta
    player_x = clamp(player_x, 20.0, 1260.0)

    on_ground = false
    on_wall = false
    for p in platforms:
        if (player_x >= float(p["x"]) and player_x <= float(p["x"]) + float(p["w"])
                and player_y + 14.0 >= float(p["y"]) and player_y + 14.0 <= float(p["y"]) + float(p["h"]) + 8.0
                and player_vy > 0.0):
            player_y = float(p["y"]) - 14.0
            player_vy = 0.0
            on_ground = true

    # Wall detection
    if not on_ground:
        if player_x <= 22.0:
            on_wall = true
            wall_dir = 1
        elif player_x >= 1258.0:
            on_wall = true
            wall_dir = -1

    # Wall jump preserves momentum
    if Input.is_key_pressed(KEY_SPACE):
        if on_ground:
            player_vy = JUMP_FORCE
        elif on_wall:
            player_vy = JUMP_FORCE
            player_vx = wall_dir * WALL_JUMP_VX

    # Environmental effects
    for el in env_elements:
        if (player_x >= float(el["x"]) and player_x <= float(el["x"]) + float(el["w"])
                and player_y + 14.0 >= float(el["y"]) and player_y + 14.0 <= float(el["y"]) + float(el["h"]) + 8.0):
            match el.get("type", ""):
                "ice":
                    pass  # low friction already handled
                "conveyor":
                    player_vx += float(el["dir"]) * 200.0 * delta
                "gravity_flip":
                    player_vy -= GRAVITY * 2.0 * delta

    # Gold collection
    for g in gold_coins:
        if not g["collected"] and Vector2(player_x, player_y).distance_to(Vector2(float(g["x"]), float(g["y"]))) < 25.0:
            g["collected"] = true
            gold_count += 1

    # Key collection
    if not key_collected and Vector2(player_x, player_y).distance_to(key_pos) < 25.0:
        key_collected = true
        exit_open = true

    if player_y > 750.0:
        player_x = spawn_x
        player_y = spawn_y
        player_vx = 0.0
        player_vy = 0.0
        level_timer = 0.0

    if exit_open and Vector2(player_x, player_y).distance_to(exit_pos) < 35.0:
        _show_complete(level_timer)
        state = GS.COMPLETE

func _update_hud() -> void:
    var speed: float = abs(player_vx)
    hud_label.text = "Time: %.1f/%.0fs  Gold: %d/%d  Speed: %d  Key: %s" % [
        level_timer, time_limit, gold_count, total_gold, int(speed),
        "YES" if key_collected else "NO"
    ]

func _draw() -> void:
    if state == GS.TITLE or state == GS.LEVEL_SELECT:
        return

    for p in platforms:
        draw_rect(Rect2(float(p["x"]), float(p["y"]), float(p["w"]), float(p["h"])), Color(0.4, 0.4, 0.5))

    for el in env_elements:
        var ecol: Color = Color(0.6, 0.8, 1.0)
        match el.get("type", ""):
            "conveyor": ecol = Color(0.8, 0.6, 0.2)
            "gravity_flip": ecol = Color(0.6, 0.2, 0.8)
        draw_rect(Rect2(float(el["x"]), float(el["y"]), float(el["w"]), float(el["h"])), ecol)
        draw_string(ThemeDB.fallback_font, Vector2(float(el["x"]) + 5.0, float(el["y"]) - 5.0),
            el.get("type", "").to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

    for g in gold_coins:
        if not g["collected"]:
            draw_circle(Vector2(float(g["x"]), float(g["y"])), 10.0, Color(1.0, 0.85, 0.0))

    if not key_collected:
        draw_rect(Rect2(key_pos.x - 10.0, key_pos.y - 10.0, 20.0, 20.0), Color(0.9, 0.7, 0.1))
        draw_string(ThemeDB.fallback_font, Vector2(key_pos.x - 8.0, key_pos.y + 5.0),
            "KEY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)

    var exit_col: Color = Color(0.0, 0.9, 0.4) if exit_open else Color(0.3, 0.3, 0.3)
    draw_rect(Rect2(exit_pos.x - 20.0, exit_pos.y - 30.0, 40.0, 50.0), exit_col)
    draw_string(ThemeDB.fallback_font, Vector2(exit_pos.x - 15.0, exit_pos.y - 5.0),
        "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)

    if state == GS.PLAYING:
        var speed_ratio: float = min(abs(player_vx) / MAX_SPEED, 1.0)
        var pcol: Color = Color(0.3 + speed_ratio * 0.6, 0.8 - speed_ratio * 0.4, 0.2)
        draw_rect(Rect2(player_x - 12.0, player_y - 14.0, 24.0, 28.0), pcol)
GDSCRIPT

###############################################################################
# Demo traces
###############################################################################

cat > "$GAME_DIR/demo_outputs/01_title.json" << 'DEMO'
{
  "duration_frames": 300,
  "events": [
    {"frame": 60, "type": "mouse_click", "button": "left", "x": 640, "y": 460}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/02_level_select.json" << 'DEMO'
{
  "scenario": "level_select",
  "duration_frames": 300,
  "events": [
    {"frame": 60, "type": "mouse_click", "button": "left", "x": 180, "y": 160}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/03_gameplay.json" << 'DEMO'
{
  "scenario": "level_select",
  "duration_frames": 540,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 180, "y": 160},
    {"frame": 60,  "type": "key_down",    "keycode": "RIGHT"},
    {"frame": 120, "type": "key_press",   "keycode": "SPACE"},
    {"frame": 180, "type": "key_up",      "keycode": "RIGHT"},
    {"frame": 200, "type": "key_down",    "keycode": "RIGHT"},
    {"frame": 260, "type": "key_press",   "keycode": "SPACE"},
    {"frame": 320, "type": "key_up",      "keycode": "RIGHT"},
    {"frame": 350, "type": "key_down",    "keycode": "RIGHT"},
    {"frame": 420, "type": "key_press",   "keycode": "SPACE"},
    {"frame": 480, "type": "key_up",      "keycode": "RIGHT"},
    {"frame": 510, "type": "key_press",   "keycode": "SPACE"}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/04_complete.json" << 'DEMO'
{
  "scenario": "complete",
  "duration_frames": 240,
  "events": [
    {"frame": 60,  "type": "wait"},
    {"frame": 180, "type": "mouse_click", "button": "left", "x": 540, "y": 430}
  ]
}
DEMO

echo "Oracle written to $GAME_DIR"
