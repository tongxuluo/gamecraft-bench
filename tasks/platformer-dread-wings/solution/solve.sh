#!/usr/bin/env bash
# Oracle reference implementation for platformer-dread-wings.
# Minimal Flappy Bird clone covering M1-M4, D1-D4, V1-V4, A1-A4.
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
config/name="Dread Wings"
run/main_scene="res://Main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720

[input]
flap={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":32,"location":0,"echo":false,"script":null), Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":1,"position":Vector2(0,0),"global_position":Vector2(0,0),"factor":1.0,"button_index":1,"canceled":false,"pressed":true,"double_click":false,"script":null)]
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

enum GS { TITLE, READY, PLAYING, DEAD }
var state := GS.TITLE

# Bird
const GRAVITY := 700.0
const FLAP := -400.0
const BIRD_X := 280.0
var bird_y := 360.0
var bird_vy := 0.0
const BIRD_R := 20.0
const FLOOR_Y := 690.0
const CEIL_Y := 30.0

# Pipes
const PIPE_SPEED := 200.0
const PIPE_GAP := 220.0
const PIPE_W := 80.0
const PIPE_INTERVAL := 300.0
var pipes: Array = []
var pipe_timer := 0.0
var scroll_speed := 200.0

# Score
var score := 0
var high_score := 0

# Difficulty tiers
var tier := 0  # 0=normal, 1=fast, 2=faster

# UI
var title_panel: ColorRect
var title_score_label: Label
var start_btn: Button
var ready_label: Label
var hud_score: Label
var hud_hi: Label
var result_panel: ColorRect
var result_score_label: Label
var result_hi_label: Label
var result_new_best: Label
var retry_btn: Button
var streak_label: Label

var scenario := ""

func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]

    _load_hi()
    _build_ui()

    if scenario == "gameplay":
        _enter_ready()
    else:
        _enter_title()

func _build_ui() -> void:
    # Background
    var bg := ColorRect.new()
    bg.color = Color(0.08, 0.04, 0.12)
    bg.size = Vector2(1280, 720)
    add_child(bg)

    # Floor
    var floor_rect := ColorRect.new()
    floor_rect.color = Color(0.15, 0.08, 0.05)
    floor_rect.position = Vector2(0, FLOOR_Y)
    floor_rect.size = Vector2(1280, 30)
    add_child(floor_rect)

    var floor_line := ColorRect.new()
    floor_line.color = Color(0.0, 0.8, 0.4)
    floor_line.position = Vector2(0, FLOOR_Y)
    floor_line.size = Vector2(1280, 3)
    add_child(floor_line)

    # Ceiling
    var ceil_rect := ColorRect.new()
    ceil_rect.color = Color(0.15, 0.08, 0.05)
    ceil_rect.position = Vector2(0, 0)
    ceil_rect.size = Vector2(1280, CEIL_Y)
    add_child(ceil_rect)

    var ceil_line := ColorRect.new()
    ceil_line.color = Color(0.0, 0.8, 0.4)
    ceil_line.position = Vector2(0, CEIL_Y)
    ceil_line.size = Vector2(1280, 3)
    add_child(ceil_line)

    # HUD
    hud_score = Label.new()
    hud_score.position = Vector2(600, 40)
    hud_score.add_theme_font_size_override("font_size", 48)
    hud_score.modulate = Color.WHITE
    add_child(hud_score)

    hud_hi = Label.new()
    hud_hi.position = Vector2(10, 10)
    hud_hi.add_theme_font_size_override("font_size", 24)
    hud_hi.modulate = Color(0.0, 0.9, 0.4)
    add_child(hud_hi)

    streak_label = Label.new()
    streak_label.position = Vector2(10, 40)
    streak_label.add_theme_font_size_override("font_size", 20)
    streak_label.modulate = Color(0.8, 0.6, 0.2)
    add_child(streak_label)

    # Title
    title_panel = ColorRect.new()
    title_panel.color = Color(0.0, 0.0, 0.0, 0.88)
    title_panel.size = Vector2(1280, 720)
    title_panel.visible = false
    add_child(title_panel)

    var tl := Label.new()
    tl.text = "DREAD WINGS"
    tl.position = Vector2(380, 160)
    tl.add_theme_font_size_override("font_size", 72)
    tl.modulate = Color(0.0, 1.0, 0.5)
    title_panel.add_child(tl)

    var sub := Label.new()
    sub.text = "// CYBERPUNK FLIGHT PROTOCOL //"
    sub.position = Vector2(380, 260)
    sub.add_theme_font_size_override("font_size", 22)
    sub.modulate = Color(0.5, 0.5, 0.5)
    title_panel.add_child(sub)

    title_score_label = Label.new()
    title_score_label.position = Vector2(480, 320)
    title_score_label.add_theme_font_size_override("font_size", 32)
    title_score_label.modulate = Color(0.0, 0.9, 0.4)
    title_panel.add_child(title_score_label)

    start_btn = Button.new()
    start_btn.text = "[ LAUNCH ]"
    start_btn.position = Vector2(490, 420)
    start_btn.size = Vector2(300, 70)
    start_btn.add_theme_font_size_override("font_size", 30)
    start_btn.pressed.connect(_on_start)
    title_panel.add_child(start_btn)

    # Ready
    ready_label = Label.new()
    ready_label.text = ">>> PRESS SPACE TO FLAP <<<"
    ready_label.position = Vector2(340, 460)
    ready_label.add_theme_font_size_override("font_size", 28)
    ready_label.modulate = Color(0.0, 1.0, 0.5)
    ready_label.visible = false
    add_child(ready_label)

    # Result
    result_panel = ColorRect.new()
    result_panel.color = Color(0.03, 0.03, 0.08, 0.95)
    result_panel.size = Vector2(600, 400)
    result_panel.position = Vector2(340, 160)
    result_panel.visible = false
    add_child(result_panel)

    var go_lbl := Label.new()
    go_lbl.text = "// SYSTEM FAILURE //"
    go_lbl.position = Vector2(100, 30)
    go_lbl.add_theme_font_size_override("font_size", 36)
    go_lbl.modulate = Color(0.9, 0.1, 0.1)
    result_panel.add_child(go_lbl)

    result_score_label = Label.new()
    result_score_label.position = Vector2(80, 110)
    result_score_label.add_theme_font_size_override("font_size", 32)
    result_score_label.modulate = Color.WHITE
    result_panel.add_child(result_score_label)

    result_hi_label = Label.new()
    result_hi_label.position = Vector2(80, 160)
    result_hi_label.add_theme_font_size_override("font_size", 26)
    result_hi_label.modulate = Color(0.0, 0.9, 0.4)
    result_panel.add_child(result_hi_label)

    result_new_best = Label.new()
    result_new_best.text = "★ NEW BEST ★"
    result_new_best.position = Vector2(160, 210)
    result_new_best.add_theme_font_size_override("font_size", 30)
    result_new_best.modulate = Color(1.0, 0.85, 0.0)
    result_new_best.visible = false
    result_panel.add_child(result_new_best)

    retry_btn = Button.new()
    retry_btn.text = "[ RE-FLY ]"
    retry_btn.position = Vector2(180, 300)
    retry_btn.size = Vector2(240, 60)
    retry_btn.add_theme_font_size_override("font_size", 26)
    retry_btn.pressed.connect(_on_retry)
    result_panel.add_child(retry_btn)

func _enter_title() -> void:
    state = GS.TITLE
    title_score_label.text = "High Score: %d" % high_score
    title_panel.visible = true
    ready_label.visible = false
    result_panel.visible = false
    _clear_pipes()
    bird_y = 360.0
    bird_vy = 0.0

func _enter_ready() -> void:
    state = GS.READY
    title_panel.visible = false
    result_panel.visible = false
    ready_label.visible = true
    score = 0
    tier = 0
    scroll_speed = PIPE_SPEED
    pipe_timer = 0.0
    _clear_pipes()
    bird_y = 360.0
    bird_vy = 0.0
    _update_hud()

func _on_start() -> void:
    _enter_ready()

func _on_retry() -> void:
    _enter_ready()

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.physical_keycode == KEY_SPACE:
            _handle_flap()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _handle_flap()

func _handle_flap() -> void:
    match state:
        GS.TITLE:
            _enter_ready()
        GS.READY:
            state = GS.PLAYING
            ready_label.visible = false
            bird_vy = FLAP
        GS.PLAYING:
            bird_vy = FLAP
        GS.DEAD:
            _enter_ready()

func _process(delta: float) -> void:
    match state:
        GS.PLAYING:
            _update_playing(delta)
        GS.READY:
            var t := Time.get_ticks_msec() / 1000.0
            bird_y = 360.0 + sin(t * 2.5) * 18.0
            ready_label.modulate.a = 0.6 + 0.4 * sin(t * 4.0)
    queue_redraw()

func _update_playing(delta: float) -> void:
    bird_vy += GRAVITY * delta
    bird_y += bird_vy * delta

    # Difficulty tiers
    if score >= 20 and tier < 2:
        tier = 2
        scroll_speed = PIPE_SPEED * 1.4
    elif score >= 10 and tier < 1:
        tier = 1
        scroll_speed = PIPE_SPEED * 1.2

    # Spawn pipes
    pipe_timer += scroll_speed * delta
    if pipe_timer >= PIPE_INTERVAL:
        pipe_timer -= PIPE_INTERVAL
        _spawn_pipe()

    # Move pipes
    for p in pipes:
        p["x"] -= scroll_speed * delta

    # Score
    for p in pipes:
        if not p["scored"] and p["x"] + PIPE_W / 2.0 < BIRD_X:
            p["scored"] = true
            score += 1
            _update_hud()

    # Collision
    if bird_y - BIRD_R <= CEIL_Y or bird_y + BIRD_R >= FLOOR_Y:
        _die()
        return

    for p in pipes:
        var px: float = p["x"]
        var gap_y: float = p["gap_y"]
        if BIRD_X + BIRD_R > px and BIRD_X - BIRD_R < px + PIPE_W:
            if bird_y - BIRD_R < gap_y - PIPE_GAP / 2.0 or bird_y + BIRD_R > gap_y + PIPE_GAP / 2.0:
                _die()
                return

    pipes = pipes.filter(func(p): return p["x"] + PIPE_W > -50.0)

func _spawn_pipe() -> void:
    var gap_y := randf_range(200.0, 520.0)
    pipes.append({"x": 1350.0, "gap_y": gap_y, "scored": false, "style": tier})

func _clear_pipes() -> void:
    pipes.clear()

func _die() -> void:
    state = GS.DEAD
    var new_best := score > high_score
    if new_best:
        high_score = score
        _save_hi()
    result_score_label.text = "Score: %d" % score
    result_hi_label.text = "Best: %d" % high_score
    result_new_best.visible = new_best
    result_panel.visible = true

func _update_hud() -> void:
    hud_score.text = "%d" % score
    hud_hi.text = "HI: %d" % high_score
    var tier_names := ["NORMAL", "FAST", "DANGER"]
    streak_label.text = "Speed: %s  |  Pipes: %d" % [tier_names[tier], pipes.size()]

const SAVE_PATH := "user://dread_wings.cfg"

func _load_hi() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) == OK:
        high_score = int(cfg.get_value("score", "hi", 0))

func _save_hi() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("score", "hi", high_score)
    cfg.save(SAVE_PATH)

func _draw() -> void:
    # Bird
    var tilt := clampf(bird_vy / 700.0, -0.5, 1.2)
    draw_set_transform(Vector2(BIRD_X, bird_y), tilt * 1.2)
    draw_circle(Vector2.ZERO, BIRD_R, Color(0.7, 0.65, 0.2))
    draw_circle(Vector2(8.0, -6.0), 5.0, Color.WHITE)
    draw_circle(Vector2(10.0, -6.0), 2.5, Color(0.05, 0.05, 0.05))
    draw_rect(Rect2(12.0, -3.0, 14.0, 6.0), Color(0.9, 0.35, 0.05))
    draw_set_transform(Vector2.ZERO)

    # Pipes
    var pipe_styles := [
        Color(0.08, 0.25, 0.08),
        Color(0.1, 0.1, 0.3),
        Color(0.3, 0.05, 0.05)
    ]
    var cap_styles := [
        Color(0.0, 0.9, 0.4),
        Color(0.2, 0.4, 1.0),
        Color(1.0, 0.2, 0.1)
    ]
    for p in pipes:
        var px: float = p["x"]
        var gap_y: float = p["gap_y"]
        var s: int = p["style"]
        var pcol: Color = pipe_styles[s]
        var ccol: Color = cap_styles[s]
        # Top pipe
        draw_rect(Rect2(px, 0.0, PIPE_W, gap_y - PIPE_GAP / 2.0), pcol)
        draw_rect(Rect2(px - 6.0, gap_y - PIPE_GAP / 2.0 - 14.0, PIPE_W + 12.0, 14.0), ccol)
        # Bottom pipe
        draw_rect(Rect2(px, gap_y + PIPE_GAP / 2.0, PIPE_W, FLOOR_Y - gap_y - PIPE_GAP / 2.0), pcol)
        draw_rect(Rect2(px - 6.0, gap_y + PIPE_GAP / 2.0, PIPE_W + 12.0, 14.0), ccol)
GDSCRIPT

###############################################################################
# Demo traces
###############################################################################

cat > "$GAME_DIR/demo_outputs/opening.json" << 'DEMO'
{
  "duration_frames": 600,
  "events": [
    {"frame": 10,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 50,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 70,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 90,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 110, "type": "key_press", "keycode": "SPACE"},
    {"frame": 130, "type": "key_press", "keycode": "SPACE"},
    {"frame": 150, "type": "key_press", "keycode": "SPACE"},
    {"frame": 170, "type": "key_press", "keycode": "SPACE"},
    {"frame": 190, "type": "key_press", "keycode": "SPACE"},
    {"frame": 210, "type": "key_press", "keycode": "SPACE"},
    {"frame": 230, "type": "key_press", "keycode": "SPACE"},
    {"frame": 250, "type": "key_press", "keycode": "SPACE"},
    {"frame": 270, "type": "key_press", "keycode": "SPACE"},
    {"frame": 290, "type": "key_press", "keycode": "SPACE"},
    {"frame": 310, "type": "key_press", "keycode": "SPACE"},
    {"frame": 330, "type": "key_press", "keycode": "SPACE"},
    {"frame": 350, "type": "key_press", "keycode": "SPACE"},
    {"frame": 370, "type": "key_press", "keycode": "SPACE"},
    {"frame": 390, "type": "key_press", "keycode": "SPACE"},
    {"frame": 410, "type": "key_press", "keycode": "SPACE"},
    {"frame": 430, "type": "key_press", "keycode": "SPACE"},
    {"frame": 450, "type": "key_press", "keycode": "SPACE"},
    {"frame": 470, "type": "key_press", "keycode": "SPACE"},
    {"frame": 490, "type": "key_press", "keycode": "SPACE"},
    {"frame": 510, "type": "key_press", "keycode": "SPACE"},
    {"frame": 530, "type": "key_press", "keycode": "SPACE"},
    {"frame": 550, "type": "key_press", "keycode": "SPACE"},
    {"frame": 570, "type": "key_press", "keycode": "SPACE"},
    {"frame": 590, "type": "key_press", "keycode": "SPACE"}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/gameplay.json" << 'DEMO'
{
  "scenario": "gameplay",
  "duration_frames": 600,
  "events": [
    {"frame": 0,   "type": "key_press", "keycode": "SPACE"},
    {"frame": 20,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 40,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 60,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 80,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 100, "type": "key_press", "keycode": "SPACE"},
    {"frame": 120, "type": "key_press", "keycode": "SPACE"},
    {"frame": 140, "type": "key_press", "keycode": "SPACE"},
    {"frame": 160, "type": "key_press", "keycode": "SPACE"},
    {"frame": 180, "type": "key_press", "keycode": "SPACE"},
    {"frame": 200, "type": "key_press", "keycode": "SPACE"},
    {"frame": 220, "type": "key_press", "keycode": "SPACE"},
    {"frame": 240, "type": "key_press", "keycode": "SPACE"},
    {"frame": 260, "type": "key_press", "keycode": "SPACE"},
    {"frame": 280, "type": "key_press", "keycode": "SPACE"},
    {"frame": 300, "type": "key_press", "keycode": "SPACE"},
    {"frame": 320, "type": "key_press", "keycode": "SPACE"},
    {"frame": 340, "type": "key_press", "keycode": "SPACE"},
    {"frame": 360, "type": "key_press", "keycode": "SPACE"},
    {"frame": 380, "type": "key_press", "keycode": "SPACE"},
    {"frame": 400, "type": "key_press", "keycode": "SPACE"},
    {"frame": 420, "type": "key_press", "keycode": "SPACE"},
    {"frame": 440, "type": "key_press", "keycode": "SPACE"},
    {"frame": 460, "type": "key_press", "keycode": "SPACE"},
    {"frame": 480, "type": "key_press", "keycode": "SPACE"},
    {"frame": 500, "type": "key_press", "keycode": "SPACE"},
    {"frame": 520, "type": "key_press", "keycode": "SPACE"},
    {"frame": 540, "type": "key_press", "keycode": "SPACE"},
    {"frame": 560, "type": "key_press", "keycode": "SPACE"},
    {"frame": 580, "type": "key_press", "keycode": "SPACE"}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/defeat.json" << 'DEMO'
{
  "scenario": "gameplay",
  "duration_frames": 600,
  "events": [
    {"frame": 0,   "type": "key_press", "keycode": "SPACE"},
    {"frame": 20,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 40,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 60,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 80,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 100, "type": "key_press", "keycode": "SPACE"},
    {"frame": 120, "type": "key_press", "keycode": "SPACE"},
    {"frame": 140, "type": "key_press", "keycode": "SPACE"},
    {"frame": 250, "type": "wait"},
    {"frame": 380, "type": "key_press", "keycode": "SPACE"},
    {"frame": 400, "type": "key_press", "keycode": "SPACE"},
    {"frame": 420, "type": "key_press", "keycode": "SPACE"},
    {"frame": 440, "type": "key_press", "keycode": "SPACE"},
    {"frame": 460, "type": "key_press", "keycode": "SPACE"},
    {"frame": 480, "type": "key_press", "keycode": "SPACE"},
    {"frame": 500, "type": "key_press", "keycode": "SPACE"},
    {"frame": 520, "type": "key_press", "keycode": "SPACE"},
    {"frame": 540, "type": "key_press", "keycode": "SPACE"},
    {"frame": 560, "type": "key_press", "keycode": "SPACE"},
    {"frame": 580, "type": "key_press", "keycode": "SPACE"}
  ]
}
DEMO

echo "Oracle written to $GAME_DIR"
