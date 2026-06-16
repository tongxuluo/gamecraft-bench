#!/usr/bin/env bash
# Oracle reference implementation for platformer-wall-dancer.
# Celeste-style wall-cling + directional dash precision platformer.
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
config/name="Wall Dancer"
run/main_scene="res://Main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720

[input]
dash={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":90,"key_label":0,"unicode":122,"location":0,"echo":false,"script":null)]
}
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

enum GS { TITLE, CHAPTER_SELECT, PLAYING, COMPLETE }
var state := GS.TITLE

const GRAVITY := 700.0
const JUMP_FORCE := -420.0
const SPEED := 220.0
const WALL_SLIDE_SPEED := 60.0
const DASH_SPEED := 500.0
const DASH_DURATION := 0.15

# Player
var player_x := 100.0
var player_y := 400.0
var player_vx := 0.0
var player_vy := 0.0
var on_ground := false
var on_wall_left := false
var on_wall_right := false
var wall_clinging := false

# Dash
var dash_charge := true
var dashing := false
var dash_timer := 0.0
var dash_vx := 0.0
var dash_vy := 0.0

# Stats
var death_count := 0
var chapter_deaths := 0
var chapter_timer := 0.0
var best_time := 9999.0
var spawn_x := 100.0
var spawn_y := 400.0

# Level data
var current_chapter := 0
var current_room := 0
var chapter_names := ["Crystal Caves", "Wind Tunnels", "Crumble Cliffs"]
var platforms: Array = []
var hazards: Array = []
var room_exit := Vector2(1100.0, 400.0)
var total_rooms := 5

# UI
var title_panel: ColorRect
var chapter_panel: ColorRect
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

    if scenario == "chapter_select":
        state = GS.CHAPTER_SELECT
        chapter_panel.visible = true
    elif scenario == "complete":
        state = GS.COMPLETE
        _show_complete(18.5)
    else:
        state = GS.TITLE
        title_panel.visible = true

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.07, 0.07, 0.12)
    bg.size = Vector2(1280, 720)
    add_child(bg)

    title_panel = ColorRect.new()
    title_panel.color = Color(0.0, 0.0, 0.0, 0.9)
    title_panel.size = Vector2(1280, 720)
    title_panel.visible = false
    add_child(title_panel)

    var tl := Label.new()
    tl.text = "WALL DANCER\nCling to walls, dash in any direction!\nZ: Dash  Space: Jump  Arrows: Move\n\nDash recharges on landing or wall-grab."
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

    chapter_panel = ColorRect.new()
    chapter_panel.color = Color(0.05, 0.05, 0.12, 0.92)
    chapter_panel.size = Vector2(1280, 720)
    chapter_panel.visible = false
    add_child(chapter_panel)

    var cl := Label.new()
    cl.text = "SELECT CHAPTER"
    cl.position = Vector2(460, 80)
    cl.add_theme_font_size_override("font_size", 36)
    cl.modulate = Color.WHITE
    chapter_panel.add_child(cl)

    for i in range(3):
        var btn := Button.new()
        btn.text = "Chapter %d: %s" % [i + 1, chapter_names[i]]
        btn.position = Vector2(440, 220 + i * 90)
        btn.size = Vector2(400, 65)
        btn.pressed.connect(_on_chapter_select.bind(i))
        chapter_panel.add_child(btn)

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
    next_btn.text = "Next Chapter"
    next_btn.position = Vector2(200, 220)
    next_btn.size = Vector2(200, 50)
    next_btn.pressed.connect(_on_next)
    complete_panel.add_child(next_btn)

func _on_start() -> void:
    title_panel.visible = false
    state = GS.CHAPTER_SELECT
    chapter_panel.visible = true

func _on_chapter_select(idx: int) -> void:
    chapter_panel.visible = false
    current_chapter = idx
    current_room = 0
    chapter_deaths = 0
    chapter_timer = 0.0
    _load_room(idx, 0)

func _on_next() -> void:
    complete_panel.visible = false
    current_chapter = (current_chapter + 1) % 3
    current_room = 0
    chapter_deaths = 0
    chapter_timer = 0.0
    _load_room(current_chapter, 0)

func _load_room(chapter: int, room: int) -> void:
    state = GS.PLAYING
    spawn_x = 80.0
    spawn_y = 500.0
    player_x = spawn_x
    player_y = spawn_y
    player_vx = 0.0
    player_vy = 0.0
    dash_charge = true
    dashing = false

    # Room layouts vary by chapter and room index
    var base_y := 580.0
    platforms = [
        {"x": 0.0, "y": base_y, "w": 180.0, "h": 20.0},
        {"x": 300.0, "y": base_y - 120.0 - room * 20.0, "w": 140.0, "h": 20.0},
        {"x": 600.0, "y": base_y - 80.0 - room * 30.0, "w": 140.0, "h": 20.0},
        {"x": 950.0, "y": base_y, "w": 330.0, "h": 20.0}
    ]

    # Hazards vary by chapter
    hazards = []
    match chapter:
        0:
            hazards = [
                {"x": 220.0, "y": base_y - 30.0, "w": 60.0, "h": 30.0, "type": "spike"}
            ]
        1:
            hazards = [
                {"x": 480.0, "y": base_y - 30.0, "w": 100.0, "h": 30.0, "type": "wind", "vx": 150.0},
                {"x": 220.0, "y": base_y - 30.0, "w": 60.0, "h": 30.0, "type": "spike"}
            ]
        2:
            hazards = [
                {"x": 220.0, "y": base_y - 30.0, "w": 60.0, "h": 30.0, "type": "spike"},
                {"x": 480.0, "y": base_y - 30.0, "w": 60.0, "h": 30.0, "type": "spike"},
                {"x": 750.0, "y": base_y - 30.0, "w": 60.0, "h": 30.0, "type": "spike"}
            ]

    room_exit = Vector2(1100.0, base_y - 20.0)

func _show_complete(time: float) -> void:
    complete_panel.visible = true
    best_time = min(best_time, time)
    var grade := "C"
    if chapter_deaths < 10: grade = "B"
    if chapter_deaths < 5: grade = "A"
    if chapter_deaths == 0: grade = "S"
    complete_label.text = "Chapter Complete!\nTime: %.1fs  Deaths: %d\nGrade: %s\nBest: %.1fs" % [
        time, chapter_deaths, grade, best_time
    ]

func _process(delta: float) -> void:
    if state == GS.PLAYING:
        _update(delta)
    _update_hud()
    queue_redraw()

func _update(delta: float) -> void:
    chapter_timer += delta

    if dashing:
        dash_timer -= delta
        player_x += dash_vx * delta
        player_y += dash_vy * delta
        if dash_timer <= 0.0:
            dashing = false
            player_vx = dash_vx * 0.3
            player_vy = dash_vy * 0.3
    else:
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
    on_wall_left = false
    on_wall_right = false
    for p in platforms:
        if (player_x >= p["x"] and player_x <= p["x"] + p["w"]
                and player_y + 14.0 >= p["y"] and player_y + 14.0 <= p["y"] + p["h"] + 8.0
                and player_vy > 0.0):
            player_y = p["y"] - 14.0
            player_vy = 0.0
            on_ground = true
            dash_charge = true

    # Wall detection
    if not on_ground and not dashing:
        for p in platforms:
            if (player_y >= p["y"] and player_y <= p["y"] + p["h"]
                    and abs(player_x - p["x"]) < 12.0):
                on_wall_left = true
                dash_charge = true
            if (player_y >= p["y"] and player_y <= p["y"] + p["h"]
                    and abs(player_x - (p["x"] + p["w"])) < 12.0):
                on_wall_right = true
                dash_charge = true

    wall_clinging = (on_wall_left or on_wall_right) and not on_ground
    if wall_clinging and player_vy > WALL_SLIDE_SPEED:
        player_vy = WALL_SLIDE_SPEED

    # Jump
    if Input.is_key_pressed(KEY_SPACE):
        if on_ground:
            player_vy = JUMP_FORCE
        elif on_wall_left:
            player_vy = JUMP_FORCE
            player_vx = SPEED
            dash_charge = true
        elif on_wall_right:
            player_vy = JUMP_FORCE
            player_vx = -SPEED
            dash_charge = true

    # Dash
    if Input.is_action_just_pressed("dash") and dash_charge:
        dash_charge = false
        dashing = true
        dash_timer = DASH_DURATION
        var dir_x := 0.0
        var dir_y := 0.0
        if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
            dir_x = -1.0
        elif Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
            dir_x = 1.0
        if Input.is_key_pressed(KEY_UP):
            dir_y = -1.0
        elif Input.is_key_pressed(KEY_DOWN):
            dir_y = 1.0
        if dir_x == 0.0 and dir_y == 0.0:
            dir_x = 1.0
        var length: float = sqrt(dir_x * dir_x + dir_y * dir_y)
        dash_vx = dir_x / length * DASH_SPEED
        dash_vy = dir_y / length * DASH_SPEED

    # Hazard collision
    for h in hazards:
        if h["type"] == "wind":
            if (player_x >= h["x"] and player_x <= h["x"] + h["w"]
                    and player_y >= h["y"] and player_y <= h["y"] + h["h"]):
                player_vx += h["vx"] * delta
        else:
            if (player_x >= h["x"] - 5.0 and player_x <= h["x"] + h["w"] + 5.0
                    and player_y >= h["y"] - 5.0 and player_y <= h["y"] + h["h"] + 5.0):
                _die()
                return

    if player_y > 750.0:
        _die()
        return

    if Vector2(player_x, player_y).distance_to(room_exit) < 35.0:
        current_room += 1
        if current_room >= total_rooms:
            _show_complete(chapter_timer)
            state = GS.COMPLETE
        else:
            _load_room(current_chapter, current_room)

func _die() -> void:
    death_count += 1
    chapter_deaths += 1
    player_x = spawn_x
    player_y = spawn_y
    player_vx = 0.0
    player_vy = 0.0
    dash_charge = true
    dashing = false

func _update_hud() -> void:
    var dash_str := "READY" if dash_charge else "used"
    hud_label.text = "Room: %d/%d  Deaths: %d  Time: %.1fs  Dash: %s" % [
        current_room + 1, total_rooms, chapter_deaths, chapter_timer, dash_str
    ]

func _draw() -> void:
    if state == GS.TITLE or state == GS.CHAPTER_SELECT:
        return

    for p in platforms:
        draw_rect(Rect2(float(p["x"]), float(p["y"]), float(p["w"]), float(p["h"])), Color(0.35, 0.35, 0.5))

    for h in hazards:
        var hcol: Color = Color(0.9, 0.1, 0.1)
        if h["type"] == "wind":
            hcol = Color(0.3, 0.7, 1.0, 0.5)
        draw_rect(Rect2(float(h["x"]), float(h["y"]), float(h["w"]), float(h["h"])), hcol)
        draw_string(ThemeDB.fallback_font, Vector2(h["x"] + 2.0, h["y"] - 4.0),
            h["type"].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

    draw_rect(Rect2(room_exit.x - 15.0, room_exit.y - 25.0, 30.0, 40.0), Color(0.0, 1.0, 0.5))
    draw_string(ThemeDB.fallback_font, Vector2(room_exit.x - 12.0, room_exit.y - 5.0),
        "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)

    if state == GS.PLAYING:
        var pcol: Color = Color(0.8, 0.3, 1.0) if dashing else Color(0.6, 0.8, 1.0)
        if wall_clinging:
            pcol = Color(0.3, 1.0, 0.6)
        draw_rect(Rect2(player_x - 10.0, player_y - 14.0, 20.0, 28.0), pcol)

        # Dash charge indicator
        if dash_charge:
            draw_circle(Vector2(player_x, player_y - 20.0), 5.0, Color(1.0, 0.9, 0.0))
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

cat > "$GAME_DIR/demo_outputs/02_chapter_select.json" << 'DEMO'
{
  "scenario": "chapter_select",
  "duration_frames": 300,
  "events": [
    {"frame": 60, "type": "mouse_click", "button": "left", "x": 640, "y": 220}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/03_gameplay_dash.json" << 'DEMO'
{
  "scenario": "chapter_select",
  "duration_frames": 540,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 640, "y": 220},
    {"frame": 60,  "type": "key_down",    "keycode": "RIGHT"},
    {"frame": 90,  "type": "key_press",   "keycode": "SPACE"},
    {"frame": 120, "type": "key_press",   "keycode": "Z"},
    {"frame": 150, "type": "key_up",      "keycode": "RIGHT"},
    {"frame": 180, "type": "key_press",   "keycode": "SPACE"},
    {"frame": 210, "type": "key_down",    "keycode": "RIGHT"},
    {"frame": 240, "type": "key_press",   "keycode": "Z"},
    {"frame": 270, "type": "key_press",   "keycode": "SPACE"},
    {"frame": 300, "type": "key_up",      "keycode": "RIGHT"},
    {"frame": 330, "type": "key_down",    "keycode": "RIGHT"},
    {"frame": 390, "type": "key_press",   "keycode": "SPACE"},
    {"frame": 420, "type": "key_press",   "keycode": "Z"},
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
