#!/usr/bin/env bash
# Oracle reference implementation for platformer-magnet-dash.
# Magnetic attract/repel traversal platformer with boss fights.
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
config/name="Magnet Dash"
run/main_scene="res://Main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720

[input]
attract={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":90,"key_label":0,"unicode":122,"location":0,"echo":false,"script":null)]
}
repel={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":88,"key_label":0,"unicode":120,"location":0,"echo":false,"script":null)]
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

enum GS { TITLE, ZONE_SELECT, PLAYING, BOSS, LEVEL_COMPLETE, VICTORY }
var state := GS.TITLE

# Player
var player_x := 200.0
var player_y := 400.0
var player_vx := 0.0
var player_vy := 0.0
const GRAVITY := 500.0
const JUMP_FORCE := -350.0
const SPEED := 180.0
var on_ground := false

# Magnetic mechanics
var attract_active := false
var repel_active := false
var nearest_metal_x := 0.0
var nearest_metal_y := 0.0
var nearest_metal_dist := 9999.0
const ATTRACT_FORCE := 600.0
const REPEL_FORCE := 800.0
const MAGNET_RANGE := 300.0

# Level data
var current_zone := 0
var current_level := 0
var zone_names := ["Steel Factory", "Electric Grid", "Gravity Core"]
var metal_surfaces: Array = []
var platforms: Array = []
var hazards: Array = []
var collectibles: Array = []
var exit_pos := Vector2(1100.0, 400.0)
var level_complete := false

# Boss
var boss_hp := 0
var boss_max_hp := 8
var boss_x := 0.0
var boss_y := 0.0
var boss_vx := 60.0
var boss_projectiles: Array = []
var boss_timer := 0.0

# Stats
var style_rating := 0
var collectibles_got := 0

# UI
var title_panel: ColorRect
var zone_panel: ColorRect
var hud_label: Label
var boss_bar_bg: ColorRect
var boss_bar_fill: ColorRect
var complete_panel: ColorRect
var complete_label: Label
var victory_panel: ColorRect

var scenario := ""

func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]

    _build_ui()

    if scenario == "boss":
        current_zone = 0
        _start_boss()
    elif scenario == "zone_select":
        state = GS.ZONE_SELECT
        zone_panel.visible = true
    elif scenario == "victory":
        state = GS.VICTORY
        victory_panel.visible = true
    else:
        state = GS.TITLE
        title_panel.visible = true

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.08, 0.08, 0.12)
    bg.size = Vector2(1280, 720)
    add_child(bg)

    title_panel = ColorRect.new()
    title_panel.color = Color(0.0, 0.0, 0.0, 0.9)
    title_panel.size = Vector2(1280, 720)
    title_panel.visible = false
    add_child(title_panel)

    var tl := Label.new()
    tl.text = "MAGNET DASH\nZ: Attract  X: Repel  Arrows: Move  Space: Jump\n\nMetal surfaces glow — use them to swing and launch!"
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

    zone_panel = ColorRect.new()
    zone_panel.color = Color(0.05, 0.05, 0.15, 0.92)
    zone_panel.size = Vector2(1280, 720)
    zone_panel.visible = false
    add_child(zone_panel)

    var zl := Label.new()
    zl.text = "SELECT ZONE"
    zl.position = Vector2(500, 80)
    zl.add_theme_font_size_override("font_size", 36)
    zl.modulate = Color.WHITE
    zone_panel.add_child(zl)

    for i in range(3):
        var btn := Button.new()
        btn.text = "Zone %d: %s" % [i + 1, zone_names[i]]
        btn.position = Vector2(440, 200 + i * 80)
        btn.size = Vector2(400, 60)
        btn.pressed.connect(_on_zone_select.bind(i))
        zone_panel.add_child(btn)

    hud_label = Label.new()
    hud_label.position = Vector2(10, 10)
    hud_label.add_theme_font_size_override("font_size", 20)
    add_child(hud_label)

    boss_bar_bg = ColorRect.new()
    boss_bar_bg.color = Color(0.2, 0.0, 0.0)
    boss_bar_bg.size = Vector2(400, 24)
    boss_bar_bg.position = Vector2(440, 10)
    boss_bar_bg.visible = false
    add_child(boss_bar_bg)

    boss_bar_fill = ColorRect.new()
    boss_bar_fill.color = Color(0.9, 0.1, 0.1)
    boss_bar_fill.size = Vector2(400, 24)
    boss_bar_bg.add_child(boss_bar_fill)

    complete_panel = ColorRect.new()
    complete_panel.color = Color(0.0, 0.1, 0.3, 0.9)
    complete_panel.size = Vector2(600, 300)
    complete_panel.position = Vector2(340, 210)
    complete_panel.visible = false
    add_child(complete_panel)

    complete_label = Label.new()
    complete_label.position = Vector2(50, 40)
    complete_label.add_theme_font_size_override("font_size", 26)
    complete_label.modulate = Color.WHITE
    complete_panel.add_child(complete_label)

    var next_btn := Button.new()
    next_btn.text = "Next Level"
    next_btn.position = Vector2(200, 220)
    next_btn.size = Vector2(200, 50)
    next_btn.pressed.connect(_on_next_level)
    complete_panel.add_child(next_btn)

    victory_panel = ColorRect.new()
    victory_panel.color = Color(0.0, 0.2, 0.1, 0.9)
    victory_panel.size = Vector2(700, 350)
    victory_panel.position = Vector2(290, 185)
    victory_panel.visible = false
    add_child(victory_panel)

    var vl := Label.new()
    vl.text = "VICTORY!\nAll zones cleared!\nStyle Rating: S"
    vl.position = Vector2(200, 80)
    vl.add_theme_font_size_override("font_size", 36)
    vl.modulate = Color.WHITE
    victory_panel.add_child(vl)

func _on_start() -> void:
    title_panel.visible = false
    state = GS.ZONE_SELECT
    zone_panel.visible = true

func _on_zone_select(idx: int) -> void:
    zone_panel.visible = false
    current_zone = idx
    current_level = 0
    _load_level(idx, 0)

func _on_next_level() -> void:
    complete_panel.visible = false
    current_level += 1
    if current_level >= 5:
        _start_boss()
    else:
        _load_level(current_zone, current_level)

func _load_level(zone: int, level: int) -> void:
    state = GS.PLAYING
    player_x = 100.0
    player_y = 400.0
    player_vx = 0.0
    player_vy = 0.0
    level_complete = false
    collectibles_got = 0
    style_rating = 0
    boss_bar_bg.visible = false

    # Metal surfaces (magnetic anchors)
    metal_surfaces = [
        {"x": 300.0, "y": 350.0, "w": 60.0, "h": 60.0},
        {"x": 600.0, "y": 250.0, "w": 60.0, "h": 60.0},
        {"x": 850.0, "y": 400.0, "w": 60.0, "h": 60.0},
        {"x": 500.0, "y": 500.0, "w": 60.0, "h": 60.0}
    ]

    # Regular platforms
    platforms = [
        {"x": 0.0, "y": 620.0, "w": 200.0, "h": 20.0},
        {"x": 1080.0, "y": 620.0, "w": 200.0, "h": 20.0},
        {"x": 400.0, "y": 550.0, "w": 150.0, "h": 20.0}
    ]

    # Hazards (electric fields, etc.)
    hazards = [
        {"x": 700.0, "y": 580.0, "w": 80.0, "h": 40.0, "type": zone}
    ]

    # Collectibles
    collectibles = [
        {"x": 600.0, "y": 200.0, "collected": false},
        {"x": 850.0, "y": 350.0, "collected": false}
    ]

    exit_pos = Vector2(1100.0, 580.0)

func _start_boss() -> void:
    state = GS.BOSS
    player_x = 200.0
    player_y = 500.0
    player_vx = 0.0
    player_vy = 0.0
    boss_hp = boss_max_hp
    boss_x = 900.0
    boss_y = 500.0
    boss_vx = 60.0
    boss_timer = 0.0
    boss_projectiles = []
    metal_surfaces = [
        {"x": 400.0, "y": 300.0, "w": 60.0, "h": 60.0},
        {"x": 700.0, "y": 200.0, "w": 60.0, "h": 60.0}
    ]
    platforms = [{"x": 0.0, "y": 620.0, "w": 1280.0, "h": 20.0}]
    hazards = []
    collectibles = []
    boss_bar_bg.visible = true
    boss_bar_fill.size.x = 400.0

func _process(delta: float) -> void:
    if state == GS.PLAYING or state == GS.BOSS:
        _update(delta)
    _update_hud()
    queue_redraw()

func _update(delta: float) -> void:
    player_vy += GRAVITY * delta
    player_y += player_vy * delta

    var mv := 0.0
    if Input.is_key_pressed(KEY_LEFT):
        mv = -SPEED
    if Input.is_key_pressed(KEY_RIGHT):
        mv = SPEED
    player_vx = mv
    player_x += player_vx * delta
    player_x = clamp(player_x, 20.0, 1260.0)

    on_ground = false
    for p in platforms:
        if (player_x >= p["x"] and player_x <= p["x"] + p["w"]
                and player_y + 16.0 >= p["y"] and player_y + 16.0 <= p["y"] + p["h"] + 8.0
                and player_vy > 0.0):
            player_y = p["y"] - 16.0
            player_vy = 0.0
            on_ground = true

    if Input.is_key_pressed(KEY_SPACE) and on_ground:
        player_vy = JUMP_FORCE

    # Find nearest metal surface
    nearest_metal_dist = 9999.0
    for ms in metal_surfaces:
        var cx: float = float(ms["x"]) + float(ms["w"]) / 2.0
        var cy: float = float(ms["y"]) + float(ms["h"]) / 2.0
        var d: float = Vector2(player_x, player_y).distance_to(Vector2(cx, cy))
        if d < nearest_metal_dist:
            nearest_metal_dist = d
            nearest_metal_x = cx
            nearest_metal_y = cy

    # Attract
    attract_active = Input.is_action_pressed("attract") and nearest_metal_dist < MAGNET_RANGE
    if attract_active:
        var dir := Vector2(nearest_metal_x - player_x, nearest_metal_y - player_y).normalized()
        player_vx += dir.x * ATTRACT_FORCE * delta
        player_vy += dir.y * ATTRACT_FORCE * delta
        style_rating += 1

    # Repel
    repel_active = Input.is_action_just_pressed("repel") and nearest_metal_dist < MAGNET_RANGE
    if repel_active:
        var dir := Vector2(player_x - nearest_metal_x, player_y - nearest_metal_y).normalized()
        player_vx += dir.x * REPEL_FORCE
        player_vy += dir.y * REPEL_FORCE
        style_rating += 2

    # Collectibles
    for col in collectibles:
        if not col["collected"] and Vector2(player_x, player_y).distance_to(Vector2(float(col["x"]), float(col["y"]))) < 30.0:
            col["collected"] = true
            collectibles_got += 1

    # Hazard damage (just push back for oracle)
    for h in hazards:
        if (player_x >= h["x"] and player_x <= h["x"] + h["w"]
                and player_y >= h["y"] and player_y <= h["y"] + h["h"]):
            player_x -= 50.0

    # Exit
    if state == GS.PLAYING and Vector2(player_x, player_y).distance_to(exit_pos) < 40.0:
        _show_level_complete()

    if state == GS.BOSS:
        _update_boss(delta)

func _show_level_complete() -> void:
    state = GS.LEVEL_COMPLETE
    complete_panel.visible = true
    var grade := "C"
    if style_rating > 50: grade = "B"
    if style_rating > 100: grade = "A"
    if style_rating > 200: grade = "S"
    complete_label.text = "Level Complete!\nCollectibles: %d/2\nStyle Rating: %s\nTime: Good" % [collectibles_got, grade]

func _update_boss(delta: float) -> void:
    boss_x += boss_vx * delta
    if boss_x < 200.0 or boss_x > 1000.0:
        boss_vx *= -1.0

    boss_timer += delta
    if boss_timer >= 2.0:
        boss_timer = 0.0
        boss_projectiles.append({"x": boss_x, "y": boss_y, "vx": -200.0, "vy": 0.0})

    for proj in boss_projectiles:
        proj["x"] += proj["vx"] * delta
    boss_projectiles = boss_projectiles.filter(func(p): return p["x"] > 0.0)

    # Repel deflects projectiles
    if repel_active:
        for proj in boss_projectiles:
            if Vector2(player_x, player_y).distance_to(Vector2(float(proj["x"]), float(proj["y"]))) < 80.0:
                proj["vx"] *= -1.0

    # Attract pulls boss armor (damage)
    if attract_active and Vector2(player_x, player_y).distance_to(Vector2(boss_x, boss_y)) < MAGNET_RANGE:
        boss_hp -= int(delta * 3.0)
        boss_hp = max(boss_hp, 0)
        boss_bar_fill.size.x = 400.0 * boss_hp / float(boss_max_hp)
        if boss_hp <= 0:
            state = GS.VICTORY
            victory_panel.visible = true

func _update_hud() -> void:
    if state == GS.PLAYING or state == GS.BOSS:
        var attract_str := "ATTRACT" if attract_active else "attract"
        var repel_str := "REPEL" if repel_active else "repel"
        hud_label.text = "Z:%s  X:%s  Metal dist: %dm  Style: %d" % [
            attract_str, repel_str, int(nearest_metal_dist), style_rating
        ]

func _draw() -> void:
    if state == GS.TITLE or state == GS.ZONE_SELECT or state == GS.VICTORY:
        return

    # Platforms
    for p in platforms:
        draw_rect(Rect2(float(p["x"]), float(p["y"]), float(p["w"]), float(p["h"])), Color(0.4, 0.4, 0.5))

    # Metal surfaces (glow when in range)
    for ms in metal_surfaces:
        var in_range := Vector2(player_x, player_y).distance_to(
            Vector2(ms["x"] + ms["w"] / 2.0, ms["y"] + ms["h"] / 2.0)) < MAGNET_RANGE
        var col: Color = Color(0.8, 0.8, 0.2) if in_range else Color(0.5, 0.5, 0.3)
        draw_rect(Rect2(float(ms["x"]), float(ms["y"]), float(ms["w"]), float(ms["h"])), col)
        draw_string(ThemeDB.fallback_font, Vector2(ms["x"] + 5.0, ms["y"] + 35.0),
            "METAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)

    # Hazards
    var hazard_colors := [Color(1.0, 0.8, 0.0), Color(0.0, 0.8, 1.0), Color(0.8, 0.0, 1.0)]
    for h in hazards:
        draw_rect(Rect2(float(h["x"]), float(h["y"]), float(h["w"]), float(h["h"])), hazard_colors[h["type"]])

    # Collectibles
    for col in collectibles:
        if not col["collected"]:
            draw_circle(Vector2(float(col["x"]), float(col["y"])), 10.0, Color(1.0, 0.9, 0.0))

    # Exit
    draw_rect(Rect2(exit_pos.x - 20.0, exit_pos.y - 30.0, 40.0, 50.0), Color(0.0, 1.0, 0.5))
    draw_string(ThemeDB.fallback_font, Vector2(exit_pos.x - 15.0, exit_pos.y - 5.0),
        "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)

    # Attract line
    if attract_active:
        draw_line(Vector2(player_x, player_y), Vector2(nearest_metal_x, nearest_metal_y),
            Color(0.2, 0.8, 1.0, 0.7), 3.0)

    # Player
    draw_rect(Rect2(player_x - 14.0, player_y - 18.0, 28.0, 34.0), Color(0.3, 0.7, 1.0))

    # Boss
    if state == GS.BOSS:
        draw_rect(Rect2(boss_x - 30.0, boss_y - 40.0, 60.0, 60.0), Color(0.5, 0.0, 0.5))
        draw_string(ThemeDB.fallback_font, Vector2(boss_x - 20.0, boss_y - 45.0),
            "BOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
        for proj in boss_projectiles:
            draw_circle(Vector2(float(proj["x"]), float(proj["y"])), 8.0, Color(1.0, 0.3, 0.0))
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

cat > "$GAME_DIR/demo_outputs/02_zone_select.json" << 'DEMO'
{
  "scenario": "zone_select",
  "duration_frames": 300,
  "events": [
    {"frame": 60, "type": "mouse_click", "button": "left", "x": 640, "y": 200}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/03_gameplay_attract.json" << 'DEMO'
{
  "scenario": "zone_select",
  "duration_frames": 480,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 640, "y": 200},
    {"frame": 60,  "type": "key_down",    "keycode": "RIGHT"},
    {"frame": 90,  "type": "key_press",   "keycode": "SPACE"},
    {"frame": 120, "type": "key_down",    "keycode": "Z"},
    {"frame": 180, "type": "key_up",      "keycode": "Z"},
    {"frame": 200, "type": "key_press",   "keycode": "X"},
    {"frame": 240, "type": "key_up",      "keycode": "RIGHT"},
    {"frame": 270, "type": "key_down",    "keycode": "Z"},
    {"frame": 330, "type": "key_up",      "keycode": "Z"},
    {"frame": 360, "type": "key_press",   "keycode": "X"},
    {"frame": 420, "type": "key_press",   "keycode": "SPACE"}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/04_boss.json" << 'DEMO'
{
  "scenario": "boss",
  "duration_frames": 480,
  "events": [
    {"frame": 30,  "type": "key_down",  "keycode": "RIGHT"},
    {"frame": 60,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 90,  "type": "key_up",    "keycode": "RIGHT"},
    {"frame": 120, "type": "key_down",  "keycode": "Z"},
    {"frame": 200, "type": "key_up",    "keycode": "Z"},
    {"frame": 220, "type": "key_press", "keycode": "X"},
    {"frame": 260, "type": "key_down",  "keycode": "Z"},
    {"frame": 340, "type": "key_up",    "keycode": "Z"},
    {"frame": 360, "type": "key_press", "keycode": "X"},
    {"frame": 400, "type": "key_down",  "keycode": "Z"},
    {"frame": 460, "type": "key_up",    "keycode": "Z"}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/05_victory.json" << 'DEMO'
{
  "scenario": "victory",
  "duration_frames": 240,
  "events": [
    {"frame": 60, "type": "wait"}
  ]
}
DEMO

echo "Oracle written to $GAME_DIR"
