#!/usr/bin/env bash
# Oracle reference implementation for platformer-dig-descent.
# Vertical descent shooter with combo scoring and shop upgrades.
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
config/name="Dig Descent"
run/main_scene="res://Main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720

[input]
fire={
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

enum GS { TITLE, PLAYING, SHOP, GAMEOVER }
var state := GS.TITLE

# Player
var player_x := 640.0
var player_y := 200.0
var player_vy := 0.0
const GRAVITY := 500.0
const RECOIL := -180.0
var health := 3
var max_health := 3

# Scoring
var gems := 0
var depth := 0.0
var combo := 0
var max_combo := 0
var enemies_killed := 0

# Procedural generation
var rng := RandomNumberGenerator.new()
var platforms: Array = []
var enemies: Array = []
var blocks: Array = []
var projectiles: Array = []
var depth_tier := 0
var scroll_speed := 120.0
var shop_depth := 300.0

# Shop upgrades
var weapon_spread := 1
var fire_rate := 0.3
var fire_timer := 0.0
var has_shield := false

# UI nodes
var title_panel: ColorRect
var hud_health: Label
var hud_gems: Label
var hud_combo: Label
var hud_depth: Label
var gameover_panel: ColorRect
var go_depth_label: Label
var go_gems_label: Label
var go_combo_label: Label
var shop_panel: ColorRect

var scenario := ""

func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]

    rng.seed = 12345
    _build_ui()
    _spawn_initial_world()

    if scenario == "shop":
        gems = 50
        depth = 250.0
        state = GS.SHOP
        shop_panel.visible = true
    elif scenario == "gameover":
        depth = 500.0
        gems = 30
        max_combo = 5
        enemies_killed = 8
        state = GS.GAMEOVER
        _show_gameover()
    else:
        state = GS.TITLE
        title_panel.visible = true

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.05, 0.05, 0.15)
    bg.size = Vector2(1280, 720)
    add_child(bg)

    # Title
    title_panel = ColorRect.new()
    title_panel.color = Color(0.0, 0.0, 0.0, 0.85)
    title_panel.size = Vector2(1280, 720)
    title_panel.visible = false
    add_child(title_panel)

    var tl := Label.new()
    tl.text = "DIG DESCENT\nHigh Score: 0\n\nZ: Shoot Down  Arrow: Move\nShoot to slow fall and chain combos!"
    tl.position = Vector2(400, 180)
    tl.add_theme_font_size_override("font_size", 34)
    tl.modulate = Color.WHITE
    title_panel.add_child(tl)

    var sb := Button.new()
    sb.text = "START"
    sb.position = Vector2(540, 420)
    sb.size = Vector2(200, 60)
    sb.pressed.connect(_on_start)
    title_panel.add_child(sb)

    # HUD
    hud_health = Label.new()
    hud_health.position = Vector2(10, 10)
    hud_health.add_theme_font_size_override("font_size", 22)
    add_child(hud_health)

    hud_gems = Label.new()
    hud_gems.position = Vector2(10, 40)
    hud_gems.add_theme_font_size_override("font_size", 22)
    add_child(hud_gems)

    hud_combo = Label.new()
    hud_combo.position = Vector2(10, 70)
    hud_combo.add_theme_font_size_override("font_size", 22)
    add_child(hud_combo)

    hud_depth = Label.new()
    hud_depth.position = Vector2(10, 100)
    hud_depth.add_theme_font_size_override("font_size", 22)
    add_child(hud_depth)

    # Game Over
    gameover_panel = ColorRect.new()
    gameover_panel.color = Color(0.0, 0.0, 0.0, 0.9)
    gameover_panel.size = Vector2(600, 400)
    gameover_panel.position = Vector2(340, 160)
    gameover_panel.visible = false
    add_child(gameover_panel)

    var go_title := Label.new()
    go_title.text = "GAME OVER"
    go_title.position = Vector2(180, 20)
    go_title.add_theme_font_size_override("font_size", 40)
    go_title.modulate = Color.WHITE
    gameover_panel.add_child(go_title)

    go_depth_label = Label.new()
    go_depth_label.position = Vector2(50, 100)
    go_depth_label.add_theme_font_size_override("font_size", 24)
    go_depth_label.modulate = Color.WHITE
    gameover_panel.add_child(go_depth_label)

    go_gems_label = Label.new()
    go_gems_label.position = Vector2(50, 140)
    go_gems_label.add_theme_font_size_override("font_size", 24)
    go_gems_label.modulate = Color.WHITE
    gameover_panel.add_child(go_gems_label)

    go_combo_label = Label.new()
    go_combo_label.position = Vector2(50, 180)
    go_combo_label.add_theme_font_size_override("font_size", 24)
    go_combo_label.modulate = Color.WHITE
    gameover_panel.add_child(go_combo_label)

    var retry_btn := Button.new()
    retry_btn.text = "RETRY"
    retry_btn.position = Vector2(200, 300)
    retry_btn.size = Vector2(200, 60)
    retry_btn.pressed.connect(_on_retry)
    gameover_panel.add_child(retry_btn)

    # Shop
    shop_panel = ColorRect.new()
    shop_panel.color = Color(0.1, 0.1, 0.3, 0.95)
    shop_panel.size = Vector2(700, 420)
    shop_panel.position = Vector2(290, 150)
    shop_panel.visible = false
    add_child(shop_panel)

    var shop_title := Label.new()
    shop_title.text = "SHOP - Spend your gems!"
    shop_title.position = Vector2(150, 20)
    shop_title.add_theme_font_size_override("font_size", 30)
    shop_title.modulate = Color.WHITE
    shop_panel.add_child(shop_title)

    var shop_items := [
        ["Weapon Spread", 10],
        ["Fire Rate Up", 10],
        ["Health Refill", 15],
        ["Shield", 20]
    ]
    for i in range(shop_items.size()):
        var btn := Button.new()
        btn.text = "%s (%dg)" % [shop_items[i][0], shop_items[i][1]]
        btn.position = Vector2(100, 100 + i * 60)
        btn.size = Vector2(500, 50)
        btn.pressed.connect(_on_shop_buy.bind(i))
        shop_panel.add_child(btn)

    var cont_btn := Button.new()
    cont_btn.text = "Continue Descent"
    cont_btn.position = Vector2(200, 360)
    cont_btn.size = Vector2(300, 45)
    cont_btn.pressed.connect(_on_shop_continue)
    shop_panel.add_child(cont_btn)

func _spawn_initial_world() -> void:
    for i in range(8):
        var px := rng.randi_range(50, 1150)
        var py := 400 + i * 200
        platforms.append({"x": float(px), "y": float(py), "w": 150.0, "h": 20.0})

    for i in range(3):
        var ex := rng.randi_range(100, 1100)
        var ey := rng.randi_range(300, 600)
        enemies.append({"x": float(ex), "y": float(ey), "vx": rng.randf_range(-80.0, 80.0), "type": i % 3})

    for i in range(10):
        var bx := rng.randi_range(100, 1100)
        var by := rng.randi_range(200, 700)
        var btype := rng.randi_range(0, 3)
        blocks.append({"x": float(bx), "y": float(by), "type": btype, "alive": true})

func _on_start() -> void:
    title_panel.visible = false
    state = GS.PLAYING
    _reset_game()

func _on_retry() -> void:
    gameover_panel.visible = false
    state = GS.PLAYING
    _reset_game()

func _on_shop_buy(idx: int) -> void:
    var costs := [10, 10, 15, 20]
    if gems >= costs[idx]:
        gems -= costs[idx]
        match idx:
            0: weapon_spread = min(weapon_spread + 1, 3)
            1: fire_rate = max(fire_rate - 0.05, 0.1)
            2: health = min(health + 1, max_health)
            3: has_shield = true

func _on_shop_continue() -> void:
    shop_panel.visible = false
    state = GS.PLAYING
    shop_depth += 300.0

func _reset_game() -> void:
    player_x = 640.0
    player_y = 200.0
    player_vy = 0.0
    health = 3
    gems = 0
    depth = 0.0
    combo = 0
    max_combo = 0
    enemies_killed = 0
    scroll_speed = 120.0
    depth_tier = 0
    shop_depth = 300.0
    platforms.clear()
    enemies.clear()
    blocks.clear()
    projectiles.clear()
    rng.seed = 12345
    _spawn_initial_world()

func _process(delta: float) -> void:
    if state == GS.PLAYING:
        _update_game(delta)
        _update_hud()
    queue_redraw()

func _update_game(delta: float) -> void:
    player_vy += GRAVITY * delta
    player_y += player_vy * delta

    if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
        player_x -= 200.0 * delta
    if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
        player_x += 200.0 * delta
    player_x = clamp(player_x, 16.0, 1264.0)

    fire_timer -= delta
    if Input.is_action_just_pressed("fire") and fire_timer <= 0.0:
        fire_timer = fire_rate
        _shoot()

    var scroll := scroll_speed * delta
    depth += scroll
    for p in platforms:
        p["y"] -= scroll
    for e in enemies:
        e["y"] -= scroll
    for b in blocks:
        b["y"] -= scroll
    for proj in projectiles:
        proj["y"] += 400.0 * delta

    for e in enemies:
        e["x"] += e["vx"] * delta
        if e["x"] < 50.0 or e["x"] > 1230.0:
            e["vx"] *= -1.0

    # Platform landing resets combo
    for p in platforms:
        if (player_y + 16.0 >= p["y"] and player_y + 16.0 <= p["y"] + p["h"] + 5.0
                and player_x >= p["x"] - p["w"] / 2.0 and player_x <= p["x"] + p["w"] / 2.0
                and player_vy > 0.0):
            player_y = p["y"] - 16.0
            player_vy = 0.0
            combo = 0

    # Projectile hits
    var projs_to_remove: Array = []
    for proj in projectiles:
        for e in enemies:
            if abs(proj["x"] - e["x"]) < 20.0 and abs(proj["y"] - e["y"]) < 20.0:
                projs_to_remove.append(proj)
                enemies.erase(e)
                combo += 1
                max_combo = max(max_combo, combo)
                gems += combo
                enemies_killed += 1
                break
        for b in blocks:
            if b["alive"] and abs(proj["x"] - b["x"]) < 20.0 and abs(proj["y"] - b["y"]) < 20.0:
                if b["type"] == 0:
                    b["alive"] = false
                    projs_to_remove.append(proj)
                    combo += 1
                    max_combo = max(max_combo, combo)
                elif b["type"] == 3:
                    b["alive"] = false
                    projs_to_remove.append(proj)
                    gems += 3
                break
    for p in projs_to_remove:
        if p in projectiles:
            projectiles.erase(p)

    platforms = platforms.filter(func(p): return p["y"] > -50.0)
    enemies = enemies.filter(func(e): return e["y"] > -50.0)
    blocks = blocks.filter(func(b): return b["y"] > -50.0)
    projectiles = projectiles.filter(func(p): return p["y"] < 800.0)

    while platforms.size() < 8:
        var px := rng.randi_range(50, 1150)
        platforms.append({"x": float(px), "y": 800.0, "w": 150.0, "h": 20.0})
    while enemies.size() < 3:
        var ex := rng.randi_range(100, 1100)
        enemies.append({"x": float(ex), "y": 800.0, "vx": rng.randf_range(-80.0, 80.0), "type": rng.randi_range(0, 2)})
    while blocks.size() < 8:
        var bx := rng.randi_range(100, 1100)
        blocks.append({"x": float(bx), "y": 800.0, "type": rng.randi_range(0, 3), "alive": true})

    depth_tier = int(depth / 500.0)
    scroll_speed = 120.0 + depth_tier * 30.0

    for e in enemies:
        if abs(player_x - e["x"]) < 24.0 and abs(player_y - e["y"]) < 24.0:
            if not has_shield:
                health -= 1
            else:
                has_shield = false
            enemies.erase(e)
            break

    for b in blocks:
        if b["alive"] and b["type"] == 2:
            if abs(player_x - b["x"]) < 24.0 and abs(player_y - b["y"]) < 24.0:
                health -= 1
                b["alive"] = false
                break

    if player_y < 30.0:
        health -= 1
        player_y = 100.0

    if depth >= shop_depth:
        state = GS.SHOP
        shop_panel.visible = true

    if health <= 0:
        state = GS.GAMEOVER
        _show_gameover()

func _shoot() -> void:
    for i in range(weapon_spread):
        var angle := (i - (weapon_spread - 1) / 2.0) * 0.3
        projectiles.append({
            "x": player_x + sin(angle) * 10.0,
            "y": player_y + 16.0,
            "vx": sin(angle) * 100.0
        })
    player_vy += RECOIL

func _show_gameover() -> void:
    gameover_panel.visible = true
    go_depth_label.text = "Depth Reached: %d m" % int(depth)
    go_gems_label.text = "Gems Collected: %d" % gems
    go_combo_label.text = "Max Combo: x%d  |  Enemies Killed: %d" % [max_combo, enemies_killed]

func _update_hud() -> void:
    hud_health.text = "HP: %d/%d" % [health, max_health]
    hud_gems.text = "Gems: %d" % gems
    hud_combo.text = "Combo: x%d" % combo
    hud_depth.text = "Depth: %d m  |  Tier: %d" % [int(depth), depth_tier + 1]

func _draw() -> void:
    if state == GS.TITLE or state == GS.GAMEOVER or state == GS.SHOP:
        return

    draw_rect(Rect2(player_x - 16.0, player_y - 16.0, 32.0, 32.0), Color(0.2, 0.8, 1.0))

    for p in platforms:
        draw_rect(Rect2(p["x"] - p["w"] / 2.0, p["y"], p["w"], p["h"]), Color(0.4, 0.7, 0.4))

    var enemy_colors := [Color(1.0, 0.3, 0.3), Color(1.0, 0.6, 0.1), Color(0.8, 0.2, 0.8)]
    for e in enemies:
        draw_rect(Rect2(e["x"] - 16.0, e["y"] - 16.0, 32.0, 32.0), enemy_colors[e["type"]])

    var block_colors := [Color(0.6, 0.4, 0.2), Color(0.5, 0.5, 0.5), Color(1.0, 0.2, 0.2), Color(1.0, 0.9, 0.1)]
    for b in blocks:
        if b["alive"]:
            draw_rect(Rect2(b["x"] - 14.0, b["y"] - 14.0, 28.0, 28.0), block_colors[b["type"]])

    for proj in projectiles:
        draw_circle(Vector2(float(proj["x"]), float(proj["y"])), 5.0, Color(1.0, 1.0, 0.3))
GDSCRIPT

###############################################################################
# Demo traces
###############################################################################

cat > "$GAME_DIR/demo_outputs/01_title_flow.json" << 'DEMO'
{
  "duration_frames": 300,
  "events": [
    {"frame": 60, "type": "mouse_click", "button": "left", "x": 640, "y": 450}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/02_gameplay_shoot.json" << 'DEMO'
{
  "duration_frames": 480,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 640, "y": 450},
    {"frame": 60,  "type": "key_press", "keycode": "Z"},
    {"frame": 90,  "type": "key_press", "keycode": "Z"},
    {"frame": 120, "type": "key_press", "keycode": "Z"},
    {"frame": 150, "type": "key_press", "keycode": "Z"},
    {"frame": 180, "type": "key_press", "keycode": "Z"},
    {"frame": 210, "type": "key_press", "keycode": "Z"},
    {"frame": 240, "type": "key_press", "keycode": "Z"},
    {"frame": 270, "type": "key_press", "keycode": "Z"},
    {"frame": 300, "type": "key_press", "keycode": "Z"},
    {"frame": 330, "type": "key_press", "keycode": "Z"},
    {"frame": 360, "type": "key_press", "keycode": "Z"},
    {"frame": 390, "type": "key_press", "keycode": "Z"},
    {"frame": 420, "type": "key_press", "keycode": "Z"},
    {"frame": 450, "type": "key_press", "keycode": "Z"}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/03_shop.json" << 'DEMO'
{
  "scenario": "shop",
  "duration_frames": 300,
  "events": [
    {"frame": 60,  "type": "mouse_click", "button": "left", "x": 640, "y": 200},
    {"frame": 120, "type": "mouse_click", "button": "left", "x": 640, "y": 260},
    {"frame": 180, "type": "mouse_click", "button": "left", "x": 490, "y": 390}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/04_gameover.json" << 'DEMO'
{
  "scenario": "gameover",
  "duration_frames": 300,
  "events": [
    {"frame": 60,  "type": "wait"},
    {"frame": 200, "type": "mouse_click", "button": "left", "x": 540, "y": 460}
  ]
}
DEMO

echo "Oracle written to $GAME_DIR"
