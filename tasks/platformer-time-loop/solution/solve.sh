#!/usr/bin/env bash
# Oracle reference implementation for platformer-time-loop.
# 30-second time loop puzzle: ghosts from past loops physically interact.
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
config/name="Time Loop"
run/main_scene="res://Main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720

[input]
reset_ghosts={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":82,"key_label":0,"unicode":114,"location":0,"echo":false,"script":null)]
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

const LOOP_DURATION := 30.0
const GRAVITY := 600.0
const JUMP_FORCE := -380.0
const SPEED := 200.0

# Player
var player_x := 100.0
var player_y := 500.0
var player_vx := 0.0
var player_vy := 0.0
var on_ground := false

# Time loop
var loop_timer := 0.0
var loop_count := 0
var current_recording: Array = []
var record_timer := 0.0
var ghosts: Array = []  # each: {frames, frame_idx, x, y}
const MAX_GHOSTS := 4

# Level data
var current_chapter := 0
var current_level := 0
var chapter_names := ["Tutorial", "Timing", "Multi-Ghost", "Master"]
var platforms: Array = []
var switches: Array = []   # {x, y, w, h, pressed, door_id}
var doors: Array = []      # {x, y, w, h, id, open}
var exit_crystal := Vector2(1100.0, 500.0)
var exit_accessible := false
var loops_used := 0
var exit_time := 0.0

# UI
var title_panel: ColorRect
var chapter_panel: ColorRect
var hud_label: Label
var timeline_bar: ColorRect
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
    elif scenario == "multi_ghost":
        current_chapter = 2
        current_level = 0
        _load_level(2, 0)
        _add_demo_ghosts()
    elif scenario == "complete":
        state = GS.COMPLETE
        _show_complete(2, 8.5)
    else:
        state = GS.TITLE
        title_panel.visible = true

func _add_demo_ghosts() -> void:
    # Pre-populate ghosts for demo
    for g in range(2):
        var frames: Array = []
        for f in range(int(LOOP_DURATION * 30)):
            frames.append({"x": 300.0 + g * 100.0, "y": 500.0})
        ghosts.append({"frames": frames, "frame_idx": 0, "x": 300.0 + g * 100.0, "y": 500.0})
    # Make switch pressed by ghost
    if not switches.is_empty():
        switches[0]["pressed"] = true
        _update_doors()

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.06, 0.06, 0.14)
    bg.size = Vector2(1280, 720)
    add_child(bg)

    title_panel = ColorRect.new()
    title_panel.color = Color(0.0, 0.0, 0.0, 0.9)
    title_panel.size = Vector2(1280, 720)
    title_panel.visible = false
    add_child(title_panel)

    var tl := Label.new()
    tl.text = "TIME LOOP\nEach 30-second loop records your actions.\nGhosts from past loops press switches and hold doors!\nR: Reset all ghosts"
    tl.position = Vector2(280, 180)
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

    for i in range(4):
        var btn := Button.new()
        btn.text = "Chapter %d: %s" % [i + 1, chapter_names[i]]
        btn.position = Vector2(440, 200 + i * 80)
        btn.size = Vector2(400, 60)
        btn.pressed.connect(_on_chapter_select.bind(i))
        chapter_panel.add_child(btn)

    hud_label = Label.new()
    hud_label.position = Vector2(10, 10)
    hud_label.add_theme_font_size_override("font_size", 20)
    add_child(hud_label)

    # Timeline bar
    var tl_bg := ColorRect.new()
    tl_bg.color = Color(0.1, 0.1, 0.2)
    tl_bg.size = Vector2(800, 20)
    tl_bg.position = Vector2(240, 695)
    add_child(tl_bg)

    timeline_bar = ColorRect.new()
    timeline_bar.color = Color(0.3, 0.8, 1.0)
    timeline_bar.size = Vector2(0, 20)
    timeline_bar.position = Vector2(0, 0)
    tl_bg.add_child(timeline_bar)

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
    state = GS.CHAPTER_SELECT
    chapter_panel.visible = true

func _on_chapter_select(idx: int) -> void:
    chapter_panel.visible = false
    current_chapter = idx
    current_level = 0
    _load_level(idx, 0)

func _on_next() -> void:
    complete_panel.visible = false
    current_level += 1
    if current_level >= 4:
        current_chapter = (current_chapter + 1) % 4
        current_level = 0
    _load_level(current_chapter, current_level)

func _load_level(chapter: int, level: int) -> void:
    state = GS.PLAYING
    loop_timer = 0.0
    loop_count = 0
    loops_used = 0
    ghosts.clear()
    current_recording.clear()
    record_timer = 0.0
    exit_accessible = false

    player_x = 100.0
    player_y = 500.0
    player_vx = 0.0
    player_vy = 0.0

    platforms = [
        {"x": 0.0, "y": 580.0, "w": 300.0, "h": 20.0},
        {"x": 500.0, "y": 500.0, "w": 200.0, "h": 20.0},
        {"x": 900.0, "y": 580.0, "w": 380.0, "h": 20.0}
    ]

    switches = [
        {"x": 200.0, "y": 560.0, "w": 40.0, "h": 20.0, "pressed": false, "door_id": 0}
    ]

    doors = [
        {"x": 780.0, "y": 480.0, "w": 30.0, "h": 120.0, "id": 0, "open": false}
    ]

    exit_crystal = Vector2(1100.0, 540.0)

func _show_complete(loops: int, time: float) -> void:
    complete_panel.visible = true
    var rating := "C"
    if loops <= 3: rating = "B"
    if loops <= 2: rating = "A"
    if loops <= 1: rating = "S"
    complete_label.text = "Level Complete!\nLoops Used: %d\nExit Time: %.1fs\nRating: %s" % [loops, time, rating]

func _process(delta: float) -> void:
    if state == GS.PLAYING:
        _update(delta)
    _update_hud()
    queue_redraw()

func _update(delta: float) -> void:
    loop_timer += delta

    # Loop rewind
    if loop_timer >= LOOP_DURATION:
        loop_timer = 0.0
        loop_count += 1
        loops_used += 1
        if ghosts.size() < MAX_GHOSTS:
            ghosts.append({"frames": current_recording.duplicate(), "frame_idx": 0, "x": 100.0, "y": 500.0})
        current_recording.clear()
        player_x = 100.0
        player_y = 500.0
        player_vx = 0.0
        player_vy = 0.0

    # Reset ghosts
    if Input.is_action_just_pressed("reset_ghosts"):
        ghosts.clear()
        loop_timer = 0.0
        current_recording.clear()
        player_x = 100.0
        player_y = 500.0
        player_vx = 0.0
        player_vy = 0.0
        for sw in switches:
            sw["pressed"] = false
        _update_doors()

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

    if player_y > 750.0:
        player_y = 100.0
        player_vy = 0.0

    # Advance ghosts and check switch interaction
    for ghost in ghosts:
        if ghost["frame_idx"] < ghost["frames"].size():
            var gf: Dictionary = ghost["frames"][ghost["frame_idx"]]
            ghost["x"] = gf["x"]
            ghost["y"] = gf["y"]
            ghost["frame_idx"] += 1

    # Switches pressed by player or ghosts
    for sw in switches:
        var was_pressed: bool = bool(sw["pressed"])
        sw["pressed"] = false
        # Player
        if (player_x >= sw["x"] and player_x <= sw["x"] + sw["w"]
                and abs(player_y + 14.0 - sw["y"]) < 10.0):
            sw["pressed"] = true
        # Ghosts
        for ghost in ghosts:
            if (ghost["x"] >= sw["x"] and ghost["x"] <= sw["x"] + sw["w"]
                    and abs(ghost["y"] + 14.0 - sw["y"]) < 10.0):
                sw["pressed"] = true
        if sw["pressed"] != was_pressed:
            _update_doors()

    # Record
    record_timer += delta
    if record_timer >= 1.0 / 30.0:
        record_timer = 0.0
        current_recording.append({"x": player_x, "y": player_y})

    # Check exit
    exit_accessible = _all_switches_pressed()
    if exit_accessible and Vector2(player_x, player_y).distance_to(exit_crystal) < 35.0:
        exit_time = loop_timer
        _show_complete(loops_used, exit_time)
        state = GS.COMPLETE

func _all_switches_pressed() -> bool:
    for sw in switches:
        if not sw["pressed"]:
            return false
    return true

func _update_doors() -> void:
    var all_pressed := _all_switches_pressed()
    for door in doors:
        door["open"] = all_pressed

func _update_hud() -> void:
    var time_left := LOOP_DURATION - loop_timer
    hud_label.text = "Loop: %d  Time left: %.1fs  Ghosts: %d/%d  R: Reset" % [
        loop_count + 1, time_left, ghosts.size(), MAX_GHOSTS
    ]
    timeline_bar.size.x = 800.0 * (loop_timer / LOOP_DURATION)

func _draw() -> void:
    if state == GS.TITLE or state == GS.CHAPTER_SELECT:
        return

    for p in platforms:
        draw_rect(Rect2(float(p["x"]), float(p["y"]), float(p["w"]), float(p["h"])), Color(0.35, 0.35, 0.5))

    for sw in switches:
        var col: Color = Color(1.0, 0.6, 0.0) if sw["pressed"] else Color(0.5, 0.3, 0.0)
        draw_rect(Rect2(float(sw["x"]), float(sw["y"]), float(sw["w"]), float(sw["h"])), col)
        draw_string(ThemeDB.fallback_font, Vector2(sw["x"] + 2.0, sw["y"] - 5.0),
            "SW", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

    for door in doors:
        if not door["open"]:
            draw_rect(Rect2(float(door["x"]), float(door["y"]), float(door["w"]), float(door["h"])), Color(0.6, 0.2, 0.2))
            draw_string(ThemeDB.fallback_font, Vector2(door["x"] + 2.0, door["y"] + 60.0),
                "DOOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

    var crystal_col: Color = Color(0.0, 1.0, 0.6) if exit_accessible else Color(0.3, 0.3, 0.3)
    draw_circle(exit_crystal, 18.0, crystal_col)
    draw_string(ThemeDB.fallback_font, Vector2(exit_crystal.x - 15.0, exit_crystal.y + 5.0),
        "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)

    # Ghosts (semi-transparent, each a different hue)
    var ghost_colors := [
        Color(0.5, 0.7, 1.0, 0.45),
        Color(0.7, 0.5, 1.0, 0.45),
        Color(0.5, 1.0, 0.7, 0.45),
        Color(1.0, 0.7, 0.5, 0.45)
    ]
    for i in range(ghosts.size()):
        var ghost: Dictionary = ghosts[i]
        draw_rect(Rect2(ghost["x"] - 10.0, ghost["y"] - 14.0, 20.0, 28.0), ghost_colors[i % 4])

    if state == GS.PLAYING:
        draw_rect(Rect2(player_x - 10.0, player_y - 14.0, 20.0, 28.0), Color(0.9, 0.9, 0.2))
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
    {"frame": 60, "type": "mouse_click", "button": "left", "x": 640, "y": 200}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/03_multi_ghost.json" << 'DEMO'
{
  "scenario": "multi_ghost",
  "duration_frames": 480,
  "events": [
    {"frame": 30,  "type": "key_down",  "keycode": "RIGHT"},
    {"frame": 90,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 150, "type": "key_up",    "keycode": "RIGHT"},
    {"frame": 180, "type": "key_down",  "keycode": "RIGHT"},
    {"frame": 240, "type": "key_press", "keycode": "SPACE"},
    {"frame": 300, "type": "key_up",    "keycode": "RIGHT"},
    {"frame": 330, "type": "key_down",  "keycode": "RIGHT"},
    {"frame": 390, "type": "key_press", "keycode": "SPACE"},
    {"frame": 420, "type": "key_up",    "keycode": "RIGHT"}
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
