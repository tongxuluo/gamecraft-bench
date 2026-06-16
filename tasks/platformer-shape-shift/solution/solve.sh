#!/usr/bin/env bash
# Oracle reference implementation for platformer-shape-shift.
# Transform between three forms (heavy/bouncy/glide) to solve puzzles.
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
config/name="Shape Shift"
run/main_scene="res://Main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720

[input]
form_heavy={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":49,"key_label":0,"unicode":49,"location":0,"echo":false,"script":null)]
}
form_bouncy={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":50,"key_label":0,"unicode":50,"location":0,"echo":false,"script":null)]
}
form_glide={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":51,"key_label":0,"unicode":51,"location":0,"echo":false,"script":null)]
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

enum GS { TITLE, WORLD_SELECT, PLAYING, COMPLETE }
enum Form { HEAVY, BOUNCY, GLIDE }

var state := GS.TITLE
var current_form := Form.HEAVY

# Player
var player_x := 100.0
var player_y := 400.0
var player_vx := 0.0
var player_vy := 0.0
var on_ground := false
var glide_time := 0.0
const GLIDE_MAX := 2.0

# Form physics
const GRAVITY_HEAVY := 900.0
const GRAVITY_BOUNCY := 500.0
const GRAVITY_GLIDE := 150.0
const JUMP_HEAVY := -300.0
const JUMP_BOUNCY := -500.0
const JUMP_GLIDE := -280.0
const SPEED_HEAVY := 140.0
const SPEED_BOUNCY := 200.0
const SPEED_GLIDE := 220.0
const BOUNCE_FACTOR := 0.7

# Level data
var current_world := 0
var current_level := 0
var world_names := ["Heavy World", "Bouncy World", "Glide World", "Combined"]
var platforms: Array = []
var pressure_plates: Array = []
var fragile_floors: Array = []
var updrafts: Array = []
var wide_gaps: Array = []
var stars: Array = []
var exit_pos := Vector2(1100.0, 400.0)
var stars_collected := 0
var form_switches := 0

# UI
var title_panel: ColorRect
var world_panel: ColorRect
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

    if scenario == "world_select":
        state = GS.WORLD_SELECT
        world_panel.visible = true
    elif scenario == "complete":
        state = GS.COMPLETE
        _show_complete()
    else:
        state = GS.TITLE
        title_panel.visible = true

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.15, 0.1, 0.2)
    bg.size = Vector2(1280, 720)
    add_child(bg)

    title_panel = ColorRect.new()
    title_panel.color = Color(0.0, 0.0, 0.0, 0.9)
    title_panel.size = Vector2(1280, 720)
    title_panel.visible = false
    add_child(title_panel)

    var tl := Label.new()
    tl.text = "SHAPE SHIFT\n1: Heavy (breaks floors, presses plates)\n2: Bouncy (ricochets, reaches heights)\n3: Glide (crosses wide gaps)\n\nChain forms mid-air to solve puzzles!"
    tl.position = Vector2(300, 160)
    tl.add_theme_font_size_override("font_size", 30)
    tl.modulate = Color.WHITE
    title_panel.add_child(tl)

    var sb := Button.new()
    sb.text = "START"
    sb.position = Vector2(540, 460)
    sb.size = Vector2(200, 60)
    sb.pressed.connect(_on_start)
    title_panel.add_child(sb)

    world_panel = ColorRect.new()
    world_panel.color = Color(0.05, 0.05, 0.15, 0.92)
    world_panel.size = Vector2(1280, 720)
    world_panel.visible = false
    add_child(world_panel)

    var wl := Label.new()
    wl.text = "SELECT WORLD"
    wl.position = Vector2(490, 80)
    wl.add_theme_font_size_override("font_size", 36)
    wl.modulate = Color.WHITE
    world_panel.add_child(wl)

    for i in range(4):
        var btn := Button.new()
        btn.text = "World %d: %s" % [i + 1, world_names[i]]
        btn.position = Vector2(440, 200 + i * 80)
        btn.size = Vector2(400, 60)
        btn.pressed.connect(_on_world_select.bind(i))
        world_panel.add_child(btn)

    hud_label = Label.new()
    hud_label.position = Vector2(10, 10)
    hud_label.add_theme_font_size_override("font_size", 22)
    add_child(hud_label)

    complete_panel = ColorRect.new()
    complete_panel.color = Color(0.0, 0.3, 0.1, 0.9)
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
    state = GS.WORLD_SELECT
    world_panel.visible = true

func _on_world_select(idx: int) -> void:
    world_panel.visible = false
    current_world = idx
    current_level = 0
    _load_level(idx, 0)

func _on_next() -> void:
    complete_panel.visible = false
    current_level += 1
    if current_level >= 5:
        current_world = (current_world + 1) % 4
        current_level = 0
    _load_level(current_world, current_level)

func _load_level(world: int, level: int) -> void:
    state = GS.PLAYING
    player_x = 100.0
    player_y = 400.0
    player_vx = 0.0
    player_vy = 0.0
    current_form = Form.HEAVY
    stars_collected = 0
    form_switches = 0
    glide_time = 0.0

    platforms = [
        {"x": 0.0, "y": 600.0, "w": 200.0, "h": 20.0},
        {"x": 500.0, "y": 500.0, "w": 200.0, "h": 20.0},
        {"x": 1000.0, "y": 580.0, "w": 280.0, "h": 20.0}
    ]

    # Pressure plates (heavy form only)
    pressure_plates = [{"x": 300.0, "y": 590.0, "w": 60.0, "h": 10.0, "pressed": false}]

    # Fragile floors (break under heavy)
    fragile_floors = [{"x": 600.0, "y": 450.0, "w": 120.0, "h": 15.0, "broken": false}]

    # Updrafts (bouncy form gains height)
    updrafts = [{"x": 400.0, "y": 300.0, "w": 60.0, "h": 200.0}]

    # Wide gaps (glide form only)
    wide_gaps = []

    # Stars
    stars = [
        {"x": 300.0, "y": 550.0, "collected": false},
        {"x": 700.0, "y": 460.0, "collected": false}
    ]

    exit_pos = Vector2(1100.0, 540.0)

func _show_complete() -> void:
    complete_panel.visible = true
    complete_label.text = "Level Complete!\nStars: %d/2\nForm Switches: %d\nTime: Good" % [stars_collected, form_switches]

func _process(delta: float) -> void:
    if state == GS.PLAYING:
        _update(delta)
    _update_hud()
    queue_redraw()

func _update(delta: float) -> void:
    # Form switching
    if Input.is_action_just_pressed("form_heavy") and current_form != Form.HEAVY:
        current_form = Form.HEAVY
        form_switches += 1
    if Input.is_action_just_pressed("form_bouncy") and current_form != Form.BOUNCY:
        current_form = Form.BOUNCY
        form_switches += 1
    if Input.is_action_just_pressed("form_glide") and current_form != Form.GLIDE:
        current_form = Form.GLIDE
        form_switches += 1
        glide_time = 0.0

    # Physics per form
    var gravity := GRAVITY_HEAVY
    var jump := JUMP_HEAVY
    var speed: float = SPEED_HEAVY
    match current_form:
        Form.BOUNCY:
            gravity = GRAVITY_BOUNCY
            jump = JUMP_BOUNCY
            speed = SPEED_BOUNCY
        Form.GLIDE:
            gravity = GRAVITY_GLIDE
            jump = JUMP_GLIDE
            speed = SPEED_GLIDE
            glide_time += delta

    player_vy += gravity * delta
    player_y += player_vy * delta

    var mv := 0.0
    if Input.is_key_pressed(KEY_LEFT):
        mv = -speed
    if Input.is_key_pressed(KEY_RIGHT):
        mv = speed
    player_vx = mv
    player_x += player_vx * delta
    player_x = clamp(player_x, 20.0, 1260.0)

    on_ground = false
    for p in platforms:
        if (player_x >= p["x"] and player_x <= p["x"] + p["w"]
                and player_y + 16.0 >= p["y"] and player_y + 16.0 <= p["y"] + p["h"] + 8.0
                and player_vy > 0.0):
            player_y = p["y"] - 16.0
            if current_form == Form.BOUNCY:
                player_vy = -abs(player_vy) * BOUNCE_FACTOR
            else:
                player_vy = 0.0
            on_ground = true

    # Pressure plates (heavy only)
    for pp in pressure_plates:
        pp["pressed"] = (current_form == Form.HEAVY
            and player_x >= pp["x"] and player_x <= pp["x"] + pp["w"]
            and abs(player_y + 16.0 - pp["y"]) < 10.0)

    # Fragile floors (heavy breaks them)
    for ff in fragile_floors:
        if not ff["broken"]:
            if (player_x >= ff["x"] and player_x <= ff["x"] + ff["w"]
                    and player_y + 16.0 >= ff["y"] and player_y + 16.0 <= ff["y"] + ff["h"] + 8.0
                    and player_vy > 0.0):
                if current_form == Form.HEAVY:
                    ff["broken"] = true
                else:
                    player_y = ff["y"] - 16.0
                    player_vy = 0.0
                    on_ground = true

    # Updrafts boost bouncy
    for ud in updrafts:
        if (current_form == Form.BOUNCY
                and player_x >= ud["x"] and player_x <= ud["x"] + ud["w"]
                and player_y >= ud["y"] and player_y <= ud["y"] + ud["h"]):
            player_vy -= 400.0 * delta

    if Input.is_key_pressed(KEY_SPACE) and on_ground:
        player_vy = jump

    # Stars
    for star in stars:
        if not star["collected"] and Vector2(player_x, player_y).distance_to(Vector2(float(star["x"]), float(star["y"]))) < 30.0:
            star["collected"] = true
            stars_collected += 1

    if player_y > 750.0:
        player_y = 100.0
        player_vy = 0.0

    if Vector2(player_x, player_y).distance_to(exit_pos) < 40.0:
        _show_complete()
        state = GS.COMPLETE

func _update_hud() -> void:
    var form_names := ["HEAVY", "BOUNCY", "GLIDE"]
    hud_label.text = "Form: %s  [1/2/3]  Stars: %d  World: %d" % [
        form_names[current_form], stars_collected, current_world + 1
    ]

func _draw() -> void:
    if state == GS.TITLE or state == GS.WORLD_SELECT:
        return

    for p in platforms:
        draw_rect(Rect2(float(p["x"]), float(p["y"]), float(p["w"]), float(p["h"])), Color(0.4, 0.35, 0.5))

    for pp in pressure_plates:
        var col: Color = Color(1.0, 0.5, 0.0) if pp["pressed"] else Color(0.6, 0.3, 0.0)
        draw_rect(Rect2(float(pp["x"]), float(pp["y"]), float(pp["w"]), float(pp["h"])), col)
        draw_string(ThemeDB.fallback_font, Vector2(pp["x"] + 2.0, pp["y"] - 5.0),
            "PLATE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

    for ff in fragile_floors:
        if not ff["broken"]:
            draw_rect(Rect2(float(ff["x"]), float(ff["y"]), float(ff["w"]), float(ff["h"])), Color(0.8, 0.6, 0.3))
            draw_string(ThemeDB.fallback_font, Vector2(ff["x"] + 2.0, ff["y"] - 5.0),
                "FRAGILE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

    for ud in updrafts:
        draw_rect(Rect2(float(ud["x"]), float(ud["y"]), float(ud["w"]), float(ud["h"])), Color(0.3, 0.8, 0.5, 0.3))
        draw_string(ThemeDB.fallback_font, Vector2(ud["x"] + 5.0, ud["y"] + 100.0),
            "UPDRAFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

    for star in stars:
        if not star["collected"]:
            draw_circle(Vector2(float(star["x"]), float(star["y"])), 10.0, Color(1.0, 0.9, 0.0))

    draw_rect(Rect2(exit_pos.x - 20.0, exit_pos.y - 30.0, 40.0, 50.0), Color(0.0, 1.0, 0.5))
    draw_string(ThemeDB.fallback_font, Vector2(exit_pos.x - 15.0, exit_pos.y - 5.0),
        "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)

    # Player shape per form
    var form_colors: Array = [Color(0.6, 0.3, 0.9), Color(0.9, 0.5, 0.1), Color(0.2, 0.7, 1.0)]
    var col: Color = form_colors[current_form]
    match current_form:
        Form.HEAVY:
            draw_rect(Rect2(player_x - 16.0, player_y - 16.0, 32.0, 32.0), col)
        Form.BOUNCY:
            draw_circle(Vector2(player_x, player_y), 16.0, col)
        Form.GLIDE:
            draw_rect(Rect2(player_x - 22.0, player_y - 8.0, 44.0, 16.0), col)
GDSCRIPT

###############################################################################
# Demo traces
###############################################################################

cat > "$GAME_DIR/demo_outputs/01_title.json" << 'DEMO'
{
  "duration_frames": 300,
  "events": [
    {"frame": 60, "type": "mouse_click", "button": "left", "x": 640, "y": 480}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/02_world_select.json" << 'DEMO'
{
  "scenario": "world_select",
  "duration_frames": 300,
  "events": [
    {"frame": 60, "type": "mouse_click", "button": "left", "x": 640, "y": 200}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/03_form_switch.json" << 'DEMO'
{
  "scenario": "world_select",
  "duration_frames": 480,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 640, "y": 200},
    {"frame": 60,  "type": "key_down",    "keycode": "RIGHT"},
    {"frame": 90,  "type": "key_press",   "keycode": "SPACE"},
    {"frame": 120, "type": "key_press",   "keycode": "2"},
    {"frame": 150, "type": "key_press",   "keycode": "SPACE"},
    {"frame": 180, "type": "key_press",   "keycode": "3"},
    {"frame": 210, "type": "key_up",      "keycode": "RIGHT"},
    {"frame": 240, "type": "key_press",   "keycode": "1"},
    {"frame": 270, "type": "key_press",   "keycode": "SPACE"},
    {"frame": 300, "type": "key_down",    "keycode": "RIGHT"},
    {"frame": 360, "type": "key_press",   "keycode": "2"},
    {"frame": 390, "type": "key_press",   "keycode": "SPACE"},
    {"frame": 420, "type": "key_up",      "keycode": "RIGHT"}
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
