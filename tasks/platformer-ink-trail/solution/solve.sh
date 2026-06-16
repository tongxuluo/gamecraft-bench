#!/usr/bin/env bash
# Oracle reference implementation for platformer-ink-trail.
# Ink-trail platformer: draw platforms with wet ink that solidifies.
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
config/name="Ink Trail"
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

enum GS { TITLE, PLAYING, COMPLETE }
var state := GS.TITLE

# Player
var player_x := 100.0
var player_y := 500.0
var player_vx := 0.0
var player_vy := 0.0
const GRAVITY := 600.0
const JUMP_FORCE := -380.0
const SPEED := 180.0
var on_ground := false

# Ink system
var ink_meter := 100.0
const INK_MAX := 100.0
const INK_DRAIN := 15.0
var ink_used := 0.0

# Trail points: {x, y, age, solid}
var trail_points: Array = []
const SOLIDIFY_DELAY := 1.0

# Level data
var walls: Array = []
var ink_wells: Array = []
var exit_pos := Vector2(1150.0, 500.0)
var current_level := 0

# UI
var title_panel: ColorRect
var start_btn: Button
var hud_ink: Label
var hud_level: Label
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
    _load_level(0)

    if scenario == "level_complete":
        state = GS.COMPLETE
        _show_complete(80.0)
    else:
        state = GS.TITLE
        title_panel.visible = true

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.9, 0.95, 1.0)
    bg.size = Vector2(1280, 720)
    add_child(bg)

    title_panel = ColorRect.new()
    title_panel.color = Color(0.1, 0.1, 0.4, 0.9)
    title_panel.size = Vector2(1280, 720)
    title_panel.visible = false
    add_child(title_panel)

    var tl := Label.new()
    tl.text = "INK TRAIL\nDraw platforms with your ink trail!\nWet ink solidifies after 1 second."
    tl.position = Vector2(380, 200)
    tl.add_theme_font_size_override("font_size", 36)
    tl.modulate = Color.WHITE
    title_panel.add_child(tl)

    start_btn = Button.new()
    start_btn.text = "START"
    start_btn.position = Vector2(540, 420)
    start_btn.size = Vector2(200, 60)
    start_btn.pressed.connect(_on_start)
    title_panel.add_child(start_btn)

    hud_ink = Label.new()
    hud_ink.position = Vector2(10, 10)
    hud_ink.add_theme_font_size_override("font_size", 22)
    add_child(hud_ink)

    hud_level = Label.new()
    hud_level.position = Vector2(10, 40)
    hud_level.add_theme_font_size_override("font_size", 22)
    add_child(hud_level)

    complete_panel = ColorRect.new()
    complete_panel.color = Color(0.0, 0.5, 0.2, 0.9)
    complete_panel.size = Vector2(600, 300)
    complete_panel.position = Vector2(340, 210)
    complete_panel.visible = false
    add_child(complete_panel)

    complete_label = Label.new()
    complete_label.position = Vector2(50, 40)
    complete_label.add_theme_font_size_override("font_size", 28)
    complete_label.modulate = Color.WHITE
    complete_panel.add_child(complete_label)

    next_btn = Button.new()
    next_btn.text = "Next Level"
    next_btn.position = Vector2(200, 220)
    next_btn.size = Vector2(200, 50)
    next_btn.pressed.connect(_on_next)
    complete_panel.add_child(next_btn)

func _load_level(idx: int) -> void:
    walls.clear()
    ink_wells.clear()
    trail_points.clear()
    ink_meter = INK_MAX
    ink_used = 0.0
    player_x = 100.0
    player_y = 500.0
    player_vx = 0.0
    player_vy = 0.0

    match idx % 6:
        0:
            walls = [
                {"x": 0.0, "y": 600.0, "w": 300.0, "h": 20.0},
                {"x": 900.0, "y": 600.0, "w": 380.0, "h": 20.0}
            ]
            ink_wells = [{"x": 400.0, "y": 560.0, "active": true}]
            exit_pos = Vector2(1150.0, 560.0)
        1:
            walls = [
                {"x": 0.0, "y": 650.0, "w": 200.0, "h": 20.0},
                {"x": 500.0, "y": 500.0, "w": 200.0, "h": 20.0},
                {"x": 1000.0, "y": 600.0, "w": 280.0, "h": 20.0}
            ]
            ink_wells = [
                {"x": 300.0, "y": 610.0, "active": true},
                {"x": 700.0, "y": 460.0, "active": true}
            ]
            exit_pos = Vector2(1150.0, 560.0)
        _:
            walls = [
                {"x": 0.0, "y": 620.0, "w": 250.0, "h": 20.0},
                {"x": 600.0, "y": 450.0, "w": 200.0, "h": 20.0},
                {"x": 1000.0, "y": 580.0, "w": 280.0, "h": 20.0}
            ]
            ink_wells = [{"x": 350.0, "y": 580.0, "active": true}]
            exit_pos = Vector2(1150.0, 540.0)

func _on_start() -> void:
    title_panel.visible = false
    state = GS.PLAYING

func _on_next() -> void:
    complete_panel.visible = false
    current_level += 1
    _load_level(current_level)
    state = GS.PLAYING

func _show_complete(ink_left: float) -> void:
    complete_panel.visible = true
    var efficiency := ink_left / INK_MAX
    var stars := 1
    if efficiency > 0.5:
        stars = 2
    if efficiency > 0.75:
        stars = 3
    complete_label.text = "Level Complete!\nInk Used: %d%%\nRating: %d Stars\nTime: Good" % [
        int((1.0 - efficiency) * 100.0), stars
    ]

func _process(delta: float) -> void:
    if state == GS.PLAYING:
        _update(delta)
    _update_hud()
    queue_redraw()

func _update(delta: float) -> void:
    player_vy += GRAVITY * delta
    player_y += player_vy * delta

    player_vx = 0.0
    if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
        player_vx = -SPEED
    if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
        player_vx = SPEED
    player_x += player_vx * delta

    if (abs(player_vx) > 0.0 or abs(player_vy) > 5.0) and ink_meter > 0.0:
        ink_meter -= INK_DRAIN * delta
        ink_used += INK_DRAIN * delta
        trail_points.append({"x": player_x, "y": player_y + 16.0, "age": 0.0, "solid": false})

    for tp in trail_points:
        tp["age"] += delta
        if tp["age"] >= SOLIDIFY_DELAY and not tp["solid"]:
            tp["solid"] = true

    for well in ink_wells:
        if well["active"] and Vector2(player_x, player_y).distance_to(Vector2(float(well["x"]), float(well["y"]))) < 40.0:
            ink_meter = min(ink_meter + 40.0, INK_MAX)
            well["active"] = false

    on_ground = false
    for w in walls:
        var pr := Rect2(player_x - 12.0, player_y - 16.0, 24.0, 32.0)
        var wr := Rect2(float(w["x"]), float(w["y"]), float(w["w"]), float(w["h"]))
        if pr.intersects(wr) and player_vy > 0.0 and player_y < w["y"] + 5.0:
            player_y = w["y"] - 16.0
            player_vy = 0.0
            on_ground = true

    for tp in trail_points:
        if tp["solid"] and abs(player_x - tp["x"]) < 20.0 and abs(player_y + 16.0 - tp["y"]) < 8.0 and player_vy > 0.0:
            player_y = tp["y"] - 16.0
            player_vy = 0.0
            on_ground = true

    if Input.is_key_pressed(KEY_SPACE) and on_ground:
        player_vy = JUMP_FORCE

    player_x = clamp(player_x, 20.0, 1260.0)
    if player_y > 750.0:
        player_y = 100.0
        player_vy = 0.0

    if Vector2(player_x, player_y).distance_to(exit_pos) < 40.0:
        state = GS.COMPLETE
        _show_complete(ink_meter)

func _update_hud() -> void:
    hud_ink.text = "Ink: %d%%" % int(ink_meter)
    hud_level.text = "Level: %d / 18  (World %d)" % [current_level + 1, current_level / 3 + 1]

func _draw() -> void:
    for w in walls:
        draw_rect(Rect2(float(w["x"]), float(w["y"]), float(w["w"]), float(w["h"])), Color(0.3, 0.2, 0.1))

    for well in ink_wells:
        var col: Color = Color(0.1, 0.5, 1.0) if well["active"] else Color(0.5, 0.5, 0.5)
        draw_circle(Vector2(float(well["x"]), float(well["y"])), 20.0, col)
        draw_string(ThemeDB.fallback_font, Vector2(well["x"] - 15.0, well["y"] + 5.0),
            "INK", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

    for tp in trail_points:
        var col: Color = Color(0.1, 0.3, 0.9, 0.6) if not tp["solid"] else Color(0.05, 0.15, 0.6)
        draw_circle(Vector2(float(tp["x"]), float(tp["y"])), 6.0, col)

    draw_rect(Rect2(exit_pos.x - 20.0, exit_pos.y - 30.0, 40.0, 40.0), Color(1.0, 0.8, 0.0))
    draw_string(ThemeDB.fallback_font, Vector2(exit_pos.x - 15.0, exit_pos.y - 5.0),
        "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)

    if state == GS.PLAYING:
        draw_rect(Rect2(player_x - 12.0, player_y - 16.0, 24.0, 32.0), Color(0.2, 0.7, 0.3))
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

cat > "$GAME_DIR/demo_outputs/02_gameplay.json" << 'DEMO'
{
  "duration_frames": 540,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 640, "y": 450},
    {"frame": 60,  "type": "key_down",    "keycode": "RIGHT"},
    {"frame": 120, "type": "key_press",   "keycode": "SPACE"},
    {"frame": 180, "type": "key_up",      "keycode": "RIGHT"},
    {"frame": 200, "type": "key_down",    "keycode": "RIGHT"},
    {"frame": 260, "type": "key_press",   "keycode": "SPACE"},
    {"frame": 320, "type": "key_up",      "keycode": "RIGHT"},
    {"frame": 360, "type": "key_down",    "keycode": "RIGHT"},
    {"frame": 420, "type": "key_up",      "keycode": "RIGHT"},
    {"frame": 480, "type": "key_press",   "keycode": "SPACE"}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/03_complete.json" << 'DEMO'
{
  "scenario": "level_complete",
  "duration_frames": 300,
  "events": [
    {"frame": 60,  "type": "wait"},
    {"frame": 200, "type": "mouse_click", "button": "left", "x": 540, "y": 430}
  ]
}
DEMO

echo "Oracle written to $GAME_DIR"
