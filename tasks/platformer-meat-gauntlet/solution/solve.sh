#!/usr/bin/env bash
# Oracle reference implementation for platformer-meat-gauntlet.
# Super Meat Boy-style precision platformer with instant respawn and ghost replay.
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
config/name="Meat Gauntlet"
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

enum GS { TITLE, LEVEL_SELECT, PLAYING, DEAD, COMPLETE }
var state := GS.TITLE

# Player
var player_x := 100.0
var player_y := 400.0
var player_vx := 0.0
var player_vy := 0.0
const GRAVITY := 700.0
const JUMP_FORCE := -420.0
const SPEED := 240.0
var on_ground := false
var spawn_x := 100.0
var spawn_y := 400.0

# Ghost replay
var best_recording: Array = []
var current_recording: Array = []
var ghost_x := 0.0
var ghost_y := 0.0
var ghost_frame := 0
var ghost_active := false
var record_timer := 0.0

# Stats
var death_count := 0
var level_timer := 0.0
var best_time := 9999.0
var total_deaths := 0

# Level data
var current_world := 0
var current_level := 0
var platforms: Array = []
var hazards: Array = []
var goal_pos := Vector2(1100.0, 400.0)

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
        _show_complete(3.5)
    else:
        state = GS.TITLE
        title_panel.visible = true

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.1, 0.05, 0.05)
    bg.size = Vector2(1280, 720)
    add_child(bg)

    title_panel = ColorRect.new()
    title_panel.color = Color(0.0, 0.0, 0.0, 0.9)
    title_panel.size = Vector2(1280, 720)
    title_panel.visible = false
    add_child(title_panel)

    var tl := Label.new()
    tl.text = "MEAT GAUNTLET\nPrecision platformer — die and retry instantly!\nGhost of your best run replays alongside you."
    tl.position = Vector2(300, 200)
    tl.add_theme_font_size_override("font_size", 32)
    tl.modulate = Color.WHITE
    title_panel.add_child(tl)

    var sb := Button.new()
    sb.text = "START"
    sb.position = Vector2(540, 420)
    sb.size = Vector2(200, 60)
    sb.pressed.connect(_on_start)
    title_panel.add_child(sb)

    level_select_panel = ColorRect.new()
    level_select_panel.color = Color(0.05, 0.05, 0.1, 0.92)
    level_select_panel.size = Vector2(1280, 720)
    level_select_panel.visible = false
    add_child(level_select_panel)

    var ll := Label.new()
    ll.text = "SELECT LEVEL  (Deaths: 0)"
    ll.position = Vector2(420, 60)
    ll.add_theme_font_size_override("font_size", 32)
    ll.modulate = Color.WHITE
    level_select_panel.add_child(ll)

    for w in range(3):
        for l in range(5):
            var btn := Button.new()
            btn.text = "%d-%d" % [w + 1, l + 1]
            btn.position = Vector2(200 + l * 180, 180 + w * 100)
            btn.size = Vector2(140, 70)
            btn.pressed.connect(_on_level_select.bind(w, l))
            level_select_panel.add_child(btn)

    hud_label = Label.new()
    hud_label.position = Vector2(10, 10)
    hud_label.add_theme_font_size_override("font_size", 22)
    add_child(hud_label)

    complete_panel = ColorRect.new()
    complete_panel.color = Color(0.0, 0.2, 0.0, 0.9)
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

func _on_level_select(world: int, level: int) -> void:
    level_select_panel.visible = false
    current_world = world
    current_level = level
    _load_level(world, level)

func _on_next() -> void:
    complete_panel.visible = false
    current_level += 1
    if current_level >= 5:
        current_world += 1
        current_level = 0
    if current_world >= 3:
        current_world = 0
    _load_level(current_world, current_level)

func _load_level(world: int, level: int) -> void:
    state = GS.PLAYING
    death_count = 0
    level_timer = 0.0
    current_recording.clear()
    ghost_active = not best_recording.is_empty()
    ghost_frame = 0
    record_timer = 0.0

    # Level layouts vary by world and level index
    var base_y := 580.0
    spawn_x = 80.0
    spawn_y = base_y - 20.0
    player_x = spawn_x
    player_y = spawn_y
    player_vx = 0.0
    player_vy = 0.0

    platforms = [
        {"x": 0.0, "y": base_y, "w": 200.0, "h": 20.0},
        {"x": 350.0, "y": base_y - 80.0 * (level + 1), "w": 150.0, "h": 20.0},
        {"x": 650.0, "y": base_y - 40.0 * (level + 1), "w": 150.0, "h": 20.0},
        {"x": 950.0, "y": base_y, "w": 330.0, "h": 20.0}
    ]

    # Hazards vary by world
    hazards = []
    match world:
        0:
            hazards = [
                {"x": 250.0, "y": base_y - 30.0, "w": 80.0, "h": 30.0, "type": "saw"},
                {"x": 550.0, "y": base_y - 30.0, "w": 80.0, "h": 30.0, "type": "saw"}
            ]
        1:
            hazards = [
                {"x": 300.0, "y": base_y - 20.0, "w": 30.0, "h": 20.0, "type": "spike"},
                {"x": 600.0, "y": base_y - 20.0, "w": 30.0, "h": 20.0, "type": "spike"},
                {"x": 800.0, "y": base_y - 20.0, "w": 30.0, "h": 20.0, "type": "spike"}
            ]
        2:
            hazards = [
                {"x": 280.0, "y": base_y - 40.0, "w": 60.0, "h": 40.0, "type": "crumble", "timer": 0.0, "broken": false},
                {"x": 700.0, "y": base_y - 40.0, "w": 60.0, "h": 40.0, "type": "crumble", "timer": 0.0, "broken": false}
            ]

    goal_pos = Vector2(1100.0, base_y - 20.0)

func _show_complete(time: float) -> void:
    complete_panel.visible = true
    best_time = min(best_time, time)
    complete_label.text = "Level Complete!\nTime: %.2fs\nBest: %.2fs\nDeaths: %d" % [time, best_time, death_count]

func _process(delta: float) -> void:
    if state == GS.PLAYING:
        _update(delta)
    elif state == GS.DEAD:
        _respawn()
    _update_hud()
    queue_redraw()

func _update(delta: float) -> void:
    level_timer += delta

    player_vy += GRAVITY * delta
    player_y += player_vy * delta

    var mv := 0.0
    if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
        mv = -SPEED
    if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
        mv = SPEED
    player_vx = mv
    player_x += player_vx * delta
    player_x = clamp(player_x, 20.0, 1260.0)

    on_ground = false
    for p in platforms:
        if (player_x >= p["x"] and player_x <= p["x"] + p["w"]
                and player_y + 14.0 >= p["y"] and player_y + 14.0 <= p["y"] + p["h"] + 8.0
                and player_vy > 0.0):
            player_y = p["y"] - 14.0
            player_vy = 0.0
            on_ground = true

    if Input.is_key_pressed(KEY_SPACE) and on_ground:
        player_vy = JUMP_FORCE

    # Hazard collision = instant death
    for h in hazards:
        if h.get("broken", false):
            continue
        if (player_x >= h["x"] - 5.0 and player_x <= h["x"] + h["w"] + 5.0
                and player_y >= h["y"] - 5.0 and player_y <= h["y"] + h["h"] + 5.0):
            _die()
            return

    if player_y > 750.0:
        _die()
        return

    # Record ghost frame
    record_timer += delta
    if record_timer >= 1.0 / 30.0:
        record_timer = 0.0
        current_recording.append({"x": player_x, "y": player_y})

    # Advance ghost
    if ghost_active and ghost_frame < best_recording.size():
        var gf: Dictionary = best_recording[ghost_frame]
        ghost_x = gf["x"]
        ghost_y = gf["y"]
        ghost_frame += 1

    # Goal
    if Vector2(player_x, player_y).distance_to(goal_pos) < 30.0:
        best_recording = current_recording.duplicate()
        _show_complete(level_timer)
        state = GS.COMPLETE

func _die() -> void:
    death_count += 1
    total_deaths += 1
    current_recording.clear()
    ghost_active = not best_recording.is_empty()
    ghost_frame = 0
    record_timer = 0.0
    level_timer = 0.0
    player_x = spawn_x
    player_y = spawn_y
    player_vx = 0.0
    player_vy = 0.0

func _respawn() -> void:
    state = GS.PLAYING

func _update_hud() -> void:
    hud_label.text = "Time: %.1fs  Deaths: %d  Total: %d  Level: %d-%d" % [
        level_timer, death_count, total_deaths, current_world + 1, current_level + 1
    ]

func _draw() -> void:
    if state == GS.TITLE or state == GS.LEVEL_SELECT:
        return

    for p in platforms:
        draw_rect(Rect2(float(p["x"]), float(p["y"]), float(p["w"]), float(p["h"])), Color(0.5, 0.4, 0.3))

    for h in hazards:
        if h.get("broken", false):
            continue
        var hcol: Color = Color(0.9, 0.1, 0.1)
        if h["type"] == "spike":
            hcol = Color(0.7, 0.7, 0.8)
        elif h["type"] == "crumble":
            hcol = Color(0.6, 0.4, 0.2)
        draw_rect(Rect2(float(h["x"]), float(h["y"]), float(h["w"]), float(h["h"])), hcol)
        draw_string(ThemeDB.fallback_font, Vector2(h["x"] + 2.0, h["y"] - 4.0),
            h["type"].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

    draw_rect(Rect2(goal_pos.x - 15.0, goal_pos.y - 25.0, 30.0, 35.0), Color(1.0, 0.8, 0.0))
    draw_string(ThemeDB.fallback_font, Vector2(goal_pos.x - 12.0, goal_pos.y - 5.0),
        "GOAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)

    # Ghost
    if ghost_active and ghost_frame > 0:
        draw_rect(Rect2(ghost_x - 10.0, ghost_y - 14.0, 20.0, 28.0), Color(1.0, 0.5, 0.5, 0.4))

    # Player
    if state == GS.PLAYING:
        draw_rect(Rect2(player_x - 10.0, player_y - 14.0, 20.0, 28.0), Color(0.9, 0.2, 0.2))
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

cat > "$GAME_DIR/demo_outputs/02_level_select.json" << 'DEMO'
{
  "scenario": "level_select",
  "duration_frames": 300,
  "events": [
    {"frame": 60, "type": "mouse_click", "button": "left", "x": 200, "y": 180}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/03_gameplay.json" << 'DEMO'
{
  "scenario": "level_select",
  "duration_frames": 540,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 200, "y": 180},
    {"frame": 60,  "type": "key_down",    "keycode": "RIGHT"},
    {"frame": 90,  "type": "key_press",   "keycode": "SPACE"},
    {"frame": 120, "type": "key_up",      "keycode": "RIGHT"},
    {"frame": 150, "type": "key_down",    "keycode": "RIGHT"},
    {"frame": 180, "type": "key_press",   "keycode": "SPACE"},
    {"frame": 210, "type": "key_up",      "keycode": "RIGHT"},
    {"frame": 240, "type": "key_down",    "keycode": "RIGHT"},
    {"frame": 270, "type": "key_press",   "keycode": "SPACE"},
    {"frame": 300, "type": "key_up",      "keycode": "RIGHT"},
    {"frame": 330, "type": "key_down",    "keycode": "RIGHT"},
    {"frame": 390, "type": "key_press",   "keycode": "SPACE"},
    {"frame": 450, "type": "key_up",      "keycode": "RIGHT"},
    {"frame": 480, "type": "key_press",   "keycode": "SPACE"}
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
