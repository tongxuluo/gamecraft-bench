#!/usr/bin/env bash
# Oracle reference implementation for platformer-knight-quest.
# Castlevania-style action platformer with hub, stages, bosses, and shop.
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
config/name="Knight Quest"
run/main_scene="res://Main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720

[input]
attack={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":90,"key_label":0,"unicode":122,"location":0,"echo":false,"script":null)]
}
subweapon={
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

enum GS { TITLE, HUB, STAGE, BOSS, GAMEOVER, VICTORY }
var state := GS.TITLE

# Player
var player_x := 200.0
var player_y := 500.0
var player_vy := 0.0
const GRAVITY := 600.0
const JUMP_FORCE := -380.0
const SPEED := 200.0
var on_ground := false
var player_health := 5
var gems := 0

# Combat
var combo_hit := 0
var sub_ammo := 10
var current_sub := 0
var sub_names := ["Axe", "Boomerang", "Holy Water"]
var attack_timer := 0.0
var attack_active := false
var projectiles: Array = []

# Stage data
var current_stage := 0
var stage_names := ["Crypt", "Volcano", "Ice Cave", "Swamp"]
var platforms: Array = []
var enemies: Array = []

# Boss
var boss_hp := 0
var boss_max_hp := 10
var boss_x := 0.0
var boss_y := 0.0
var boss_phase := 0

# UI
var title_panel: ColorRect
var hub_panel: ColorRect
var hud_health: Label
var hud_gems: Label
var hud_sub: Label
var boss_bar_bg: ColorRect
var boss_bar_fill: ColorRect
var gameover_panel: ColorRect
var victory_panel: ColorRect

var scenario := ""

func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]

    _build_ui()

    if scenario == "boss":
        current_stage = 0
        _start_boss()
    elif scenario == "hub":
        state = GS.HUB
        hub_panel.visible = true
    elif scenario == "victory":
        state = GS.VICTORY
        victory_panel.visible = true
    else:
        state = GS.TITLE
        title_panel.visible = true

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.1, 0.05, 0.15)
    bg.size = Vector2(1280, 720)
    add_child(bg)

    # Title
    title_panel = ColorRect.new()
    title_panel.color = Color(0.0, 0.0, 0.0, 0.9)
    title_panel.size = Vector2(1280, 720)
    title_panel.visible = false
    add_child(title_panel)

    var tl := Label.new()
    tl.text = "KNIGHT QUEST\nA retro action-platformer\n\nZ: Attack  X: Sub-Weapon  Arrows: Move  Space: Jump"
    tl.position = Vector2(320, 200)
    tl.add_theme_font_size_override("font_size", 34)
    tl.modulate = Color.WHITE
    title_panel.add_child(tl)

    var sb := Button.new()
    sb.text = "START"
    sb.position = Vector2(540, 420)
    sb.size = Vector2(200, 60)
    sb.pressed.connect(_on_start)
    title_panel.add_child(sb)

    # Hub
    hub_panel = ColorRect.new()
    hub_panel.color = Color(0.1, 0.1, 0.2, 0.9)
    hub_panel.size = Vector2(1280, 720)
    hub_panel.visible = false
    add_child(hub_panel)

    var hl := Label.new()
    hl.text = "VILLAGE HUB\nChoose your next stage"
    hl.position = Vector2(450, 80)
    hl.add_theme_font_size_override("font_size", 32)
    hl.modulate = Color.WHITE
    hub_panel.add_child(hl)

    for i in range(4):
        var btn := Button.new()
        btn.text = "Stage %d: %s" % [i + 1, stage_names[i]]
        btn.position = Vector2(440, 200 + i * 70)
        btn.size = Vector2(400, 55)
        btn.pressed.connect(_on_stage_select.bind(i))
        hub_panel.add_child(btn)

    var shop_btn := Button.new()
    shop_btn.text = "SHOP"
    shop_btn.position = Vector2(440, 500)
    shop_btn.size = Vector2(400, 55)
    hub_panel.add_child(shop_btn)

    # HUD
    hud_health = Label.new()
    hud_health.position = Vector2(10, 10)
    hud_health.add_theme_font_size_override("font_size", 22)
    add_child(hud_health)

    hud_gems = Label.new()
    hud_gems.position = Vector2(10, 40)
    hud_gems.add_theme_font_size_override("font_size", 22)
    add_child(hud_gems)

    hud_sub = Label.new()
    hud_sub.position = Vector2(10, 70)
    hud_sub.add_theme_font_size_override("font_size", 22)
    add_child(hud_sub)

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

    # Game Over
    gameover_panel = ColorRect.new()
    gameover_panel.color = Color(0.0, 0.0, 0.0, 0.9)
    gameover_panel.size = Vector2(600, 300)
    gameover_panel.position = Vector2(340, 210)
    gameover_panel.visible = false
    add_child(gameover_panel)

    var gol := Label.new()
    gol.text = "GAME OVER\nStages Cleared: 0\nGems: 0\nDeaths: 1"
    gol.position = Vector2(150, 60)
    gol.add_theme_font_size_override("font_size", 28)
    gol.modulate = Color.WHITE
    gameover_panel.add_child(gol)

    var rb := Button.new()
    rb.text = "Return to Hub"
    rb.position = Vector2(200, 220)
    rb.size = Vector2(200, 50)
    rb.pressed.connect(_on_hub)
    gameover_panel.add_child(rb)

    # Victory
    victory_panel = ColorRect.new()
    victory_panel.color = Color(0.0, 0.3, 0.0, 0.9)
    victory_panel.size = Vector2(700, 350)
    victory_panel.position = Vector2(290, 185)
    victory_panel.visible = false
    add_child(victory_panel)

    var vl := Label.new()
    vl.text = "VICTORY!\nAll stages cleared!\nGems: 0  Deaths: 0  Time: --"
    vl.position = Vector2(150, 60)
    vl.add_theme_font_size_override("font_size", 30)
    vl.modulate = Color.WHITE
    victory_panel.add_child(vl)

func _on_start() -> void:
    title_panel.visible = false
    state = GS.HUB
    hub_panel.visible = true

func _on_hub() -> void:
    gameover_panel.visible = false
    state = GS.HUB
    hub_panel.visible = true

func _on_stage_select(idx: int) -> void:
    hub_panel.visible = false
    current_stage = idx
    _start_stage(idx)

func _start_stage(idx: int) -> void:
    state = GS.STAGE
    player_x = 100.0
    player_y = 500.0
    player_vy = 0.0
    player_health = 5
    platforms = [
        {"x": 0.0, "y": 620.0, "w": 1280.0, "h": 20.0},
        {"x": 200.0, "y": 480.0, "w": 200.0, "h": 20.0},
        {"x": 600.0, "y": 380.0, "w": 200.0, "h": 20.0},
        {"x": 900.0, "y": 480.0, "w": 200.0, "h": 20.0}
    ]
    enemies = []
    for i in range(3 + idx):
        enemies.append({
            "x": 300.0 + i * 200.0,
            "y": 580.0,
            "vx": 60.0 * (1.0 if i % 2 == 0 else -1.0),
            "hp": 2,
            "type": i % 5,
            "alive": true
        })
    boss_bar_bg.visible = false

func _start_boss() -> void:
    state = GS.BOSS
    player_x = 200.0
    player_y = 500.0
    player_vy = 0.0
    boss_hp = boss_max_hp
    boss_x = 900.0
    boss_y = 500.0
    boss_phase = 0
    platforms = [{"x": 0.0, "y": 620.0, "w": 1280.0, "h": 20.0}]
    enemies = []
    boss_bar_bg.visible = true
    boss_bar_fill.size.x = 400.0

func _process(delta: float) -> void:
    if state == GS.STAGE or state == GS.BOSS:
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
    player_x += mv * delta
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

    if Input.is_action_just_pressed("attack"):
        attack_active = true
        attack_timer = 0.3
        combo_hit = (combo_hit + 1) % 3

    if attack_active:
        attack_timer -= delta
        if attack_timer <= 0.0:
            attack_active = false
            _check_attack_hit()

    if Input.is_action_just_pressed("subweapon") and sub_ammo > 0:
        sub_ammo -= 1
        projectiles.append({"x": player_x, "y": player_y, "vx": 300.0, "alive": true})

    for proj in projectiles:
        proj["x"] += proj["vx"] * delta
    projectiles = projectiles.filter(func(p): return p["x"] < 1300.0 and p["alive"])

    for e in enemies:
        if not e["alive"]:
            continue
        e["x"] += e["vx"] * delta
        if e["x"] < 50.0 or e["x"] > 1230.0:
            e["vx"] *= -1.0
        for proj in projectiles:
            if proj["alive"] and abs(proj["x"] - e["x"]) < 30.0 and abs(proj["y"] - e["y"]) < 30.0:
                e["hp"] -= 1
                proj["alive"] = false
                if e["hp"] <= 0:
                    e["alive"] = false
                    gems += 3
        if abs(player_x - e["x"]) < 30.0 and abs(player_y - e["y"]) < 30.0:
            player_health -= 1
            e["x"] += 100.0
    enemies = enemies.filter(func(e): return e["alive"])

    if state == GS.BOSS:
        _update_boss(delta)

    if player_health <= 0:
        state = GS.GAMEOVER
        gameover_panel.visible = true

    if state == GS.STAGE and enemies.is_empty():
        _start_boss()

func _check_attack_hit() -> void:
    for e in enemies:
        if not e["alive"]:
            continue
        if abs(player_x - e["x"]) < 60.0 and abs(player_y - e["y"]) < 40.0:
            var dmg := 2 if combo_hit == 2 else 1
            e["hp"] -= dmg
            if e["hp"] <= 0:
                e["alive"] = false
                gems += 2

    if state == GS.BOSS and abs(player_x - boss_x) < 80.0 and abs(player_y - boss_y) < 60.0:
        boss_hp -= 1
        boss_bar_fill.size.x = 400.0 * boss_hp / float(boss_max_hp)
        if boss_hp <= 0:
            state = GS.VICTORY
            victory_panel.visible = true

func _update_boss(delta: float) -> void:
    boss_phase = 1 if boss_hp < 5 else 0
    var spd: float = 80.0 + boss_phase * 40.0
    if boss_x > player_x:
        boss_x -= spd * delta
    else:
        boss_x += spd * delta
    if abs(player_x - boss_x) < 40.0 and abs(player_y - boss_y) < 40.0:
        player_health -= 1
        boss_x += 150.0

func _update_hud() -> void:
    hud_health.text = "HP: %d  |  Combo: %d" % [player_health, combo_hit + 1]
    hud_gems.text = "Gems: %d" % gems
    hud_sub.text = "Sub: %s  Ammo: %d" % [sub_names[current_sub], sub_ammo]

func _draw() -> void:
    if state == GS.TITLE or state == GS.HUB or state == GS.GAMEOVER or state == GS.VICTORY:
        return

    for p in platforms:
        draw_rect(Rect2(float(p["x"]), float(p["y"]), float(p["w"]), float(p["h"])), Color(0.4, 0.3, 0.2))

    draw_rect(Rect2(player_x - 14.0, player_y - 20.0, 28.0, 36.0), Color(0.7, 0.7, 0.9))

    if attack_active:
        draw_rect(Rect2(player_x + 10.0, player_y - 10.0, 40.0, 8.0), Color(1.0, 0.9, 0.3))

    var ecols := [
        Color(0.8, 0.2, 0.2), Color(0.8, 0.5, 0.1), Color(0.5, 0.1, 0.8),
        Color(0.2, 0.6, 0.2), Color(0.9, 0.1, 0.5)
    ]
    for e in enemies:
        if e["alive"]:
            draw_rect(Rect2(e["x"] - 16.0, e["y"] - 16.0, 32.0, 32.0), ecols[e["type"]])

    for proj in projectiles:
        if proj["alive"]:
            draw_circle(Vector2(float(proj["x"]), float(proj["y"])), 6.0, Color(1.0, 0.8, 0.2))

    if state == GS.BOSS:
        draw_rect(Rect2(boss_x - 30.0, boss_y - 40.0, 60.0, 60.0), Color(0.6, 0.0, 0.0))
        draw_string(ThemeDB.fallback_font, Vector2(boss_x - 20.0, boss_y - 45.0),
            "BOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
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

cat > "$GAME_DIR/demo_outputs/02_hub.json" << 'DEMO'
{
  "scenario": "hub",
  "duration_frames": 300,
  "events": [
    {"frame": 60, "type": "mouse_click", "button": "left", "x": 640, "y": 200}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/03_boss.json" << 'DEMO'
{
  "scenario": "boss",
  "duration_frames": 480,
  "events": [
    {"frame": 30,  "type": "key_down",  "keycode": "RIGHT"},
    {"frame": 60,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 90,  "type": "key_up",    "keycode": "RIGHT"},
    {"frame": 120, "type": "key_press", "keycode": "Z"},
    {"frame": 150, "type": "key_press", "keycode": "Z"},
    {"frame": 180, "type": "key_press", "keycode": "Z"},
    {"frame": 210, "type": "key_press", "keycode": "X"},
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

cat > "$GAME_DIR/demo_outputs/04_victory.json" << 'DEMO'
{
  "scenario": "victory",
  "duration_frames": 240,
  "events": [
    {"frame": 60, "type": "wait"}
  ]
}
DEMO

echo "Oracle written to $GAME_DIR"
