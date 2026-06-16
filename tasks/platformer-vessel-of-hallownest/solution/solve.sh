#!/usr/bin/env bash
# Oracle reference implementation for platformer-vessel-of-hallownest.
# Minimal Hollow Knight-style metroidvania covering M1-M5, D1-D5, V1-V4, A1-A5.
set -euo pipefail

GAME_DIR="/workspace/game"
mkdir -p "$GAME_DIR/scripts" "$GAME_DIR/demo_outputs"

cat > "$GAME_DIR/project.godot" << 'PREF'
; Engine configuration file.
[gd_resource type="ProjectSettings" format=3]

config_version=5

[application]
config/name="Vessel of Hallownest"
run/main_scene="res://Main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720

[input]
slash={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":90,"key_label":0,"unicode":122,"location":0,"echo":false,"script":null)]
}
focus={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":88,"key_label":0,"unicode":120,"location":0,"echo":false,"script":null)]
}
dash={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":67,"key_label":0,"unicode":99,"location":0,"echo":false,"script":null)]
}
PREF

cat > "$GAME_DIR/Main.tscn" << 'TSCN'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/Main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
TSCN


cat > "$GAME_DIR/scripts/Main.gd" << 'GDSCRIPT'
extends Node2D

enum GS { TITLE, MAP, PLAYING, DEAD, BOSS, VICTORY }
var state := GS.TITLE

# Player physics
const GRAVITY := 700.0
const JUMP_FORCE := -420.0
const SPEED := 220.0
const DASH_SPEED := 600.0
const DASH_DUR := 0.15
const WALL_SLIDE := 80.0
var player_x := 200.0
var player_y := 400.0
var player_vx := 0.0
var player_vy := 0.0
var on_ground := false
var on_wall := false
var wall_dir := 0
var dashing := false
var dash_timer := 0.0
var dash_charge := true
var facing := 1

# Combat / survival
var masks := 5
var max_masks := 5
var soul := 0
var max_soul := 100
var geo := 0
var iframes := 0.0
var slash_active := false
var slash_timer := 0.0
var focusing := false
var focus_timer := 0.0
const FOCUS_TIME := 1.0

# Stage data
var current_stage := 0
var stages_unlocked := 1
var stage_names := ["Forgotten Crossroads", "Greenpath", "Fungal Wastes"]
var checkpoint_x := 200.0
var checkpoint_y := 400.0
var platforms: Array = []
var enemies: Array = []
var thorns: Array = []
var collectibles: Array = []
var stage_exit := Vector2(1100.0, 400.0)
var stage_cleared := false

# Boss
var boss_hp := 0
var boss_max_hp := 12
var boss_x := 0.0
var boss_y := 0.0
var boss_vx := 80.0
var boss_attack_timer := 0.0
var boss_phase := 0
var boss_projectiles: Array = []
var in_boss_room := false

# UI
var title_panel: ColorRect
var map_panel: ColorRect
var hud_masks: Label
var hud_soul: Label
var hud_geo: Label
var boss_bar_bg: ColorRect
var boss_bar_fill: ColorRect
var dead_panel: ColorRect
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
        _load_stage(0)
        _enter_boss()
    elif scenario == "map":
        state = GS.MAP
        map_panel.visible = true
    elif scenario == "combat":
        current_stage = 0
        _load_stage(0)
        state = GS.PLAYING
    else:
        state = GS.TITLE
        title_panel.visible = true

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.05, 0.04, 0.1)
    bg.size = Vector2(1280, 720)
    add_child(bg)

    # Title
    title_panel = ColorRect.new()
    title_panel.color = Color(0.0, 0.0, 0.0, 0.92)
    title_panel.size = Vector2(1280, 720)
    title_panel.visible = false
    add_child(title_panel)

    var tl := Label.new()
    tl.text = "VESSEL OF HALLOWNEST"
    tl.position = Vector2(280, 180)
    tl.add_theme_font_size_override("font_size", 56)
    tl.modulate = Color(0.6, 0.7, 1.0)
    title_panel.add_child(tl)

    var sub := Label.new()
    sub.text = "A ruined kingdom awaits..."
    sub.position = Vector2(460, 270)
    sub.add_theme_font_size_override("font_size", 26)
    sub.modulate = Color(0.4, 0.4, 0.6)
    title_panel.add_child(sub)

    var start_btn := Button.new()
    start_btn.text = "BEGIN JOURNEY"
    start_btn.position = Vector2(490, 380)
    start_btn.size = Vector2(300, 65)
    start_btn.add_theme_font_size_override("font_size", 28)
    start_btn.pressed.connect(_on_start)
    title_panel.add_child(start_btn)

    var load_btn := Button.new()
    load_btn.text = "CONTINUE"
    load_btn.position = Vector2(490, 460)
    load_btn.size = Vector2(300, 55)
    load_btn.add_theme_font_size_override("font_size", 24)
    load_btn.pressed.connect(_on_start)
    title_panel.add_child(load_btn)

    # Map
    map_panel = ColorRect.new()
    map_panel.color = Color(0.02, 0.02, 0.06, 0.95)
    map_panel.size = Vector2(1280, 720)
    map_panel.visible = false
    add_child(map_panel)

    var map_title := Label.new()
    map_title.text = "KINGDOM MAP"
    map_title.position = Vector2(500, 60)
    map_title.add_theme_font_size_override("font_size", 40)
    map_title.modulate = Color(0.6, 0.7, 1.0)
    map_panel.add_child(map_title)

    for i in range(3):
        var unlocked := i < stages_unlocked
        var btn := Button.new()
        btn.text = "%s%s" % [stage_names[i], "" if unlocked else " [LOCKED]"]
        btn.position = Vector2(440, 180 + i * 100)
        btn.size = Vector2(400, 70)
        btn.add_theme_font_size_override("font_size", 26)
        btn.disabled = not unlocked
        btn.pressed.connect(_on_stage_select.bind(i))
        map_panel.add_child(btn)

    var geo_lbl := Label.new()
    geo_lbl.text = "Geo: 0  |  Masks: 5/5"
    geo_lbl.position = Vector2(440, 520)
    geo_lbl.add_theme_font_size_override("font_size", 24)
    geo_lbl.modulate = Color(0.8, 0.7, 0.3)
    map_panel.add_child(geo_lbl)

    # HUD
    hud_masks = Label.new()
    hud_masks.position = Vector2(10, 10)
    hud_masks.add_theme_font_size_override("font_size", 22)
    add_child(hud_masks)

    hud_soul = Label.new()
    hud_soul.position = Vector2(10, 40)
    hud_soul.add_theme_font_size_override("font_size", 22)
    add_child(hud_soul)

    hud_geo = Label.new()
    hud_geo.position = Vector2(10, 70)
    hud_geo.add_theme_font_size_override("font_size", 22)
    add_child(hud_geo)

    boss_bar_bg = ColorRect.new()
    boss_bar_bg.color = Color(0.2, 0.0, 0.0)
    boss_bar_bg.size = Vector2(500, 26)
    boss_bar_bg.position = Vector2(390, 10)
    boss_bar_bg.visible = false
    add_child(boss_bar_bg)

    boss_bar_fill = ColorRect.new()
    boss_bar_fill.color = Color(0.8, 0.1, 0.1)
    boss_bar_fill.size = Vector2(500, 26)
    boss_bar_bg.add_child(boss_bar_fill)

    # Dead
    dead_panel = ColorRect.new()
    dead_panel.color = Color(0.0, 0.0, 0.0, 0.9)
    dead_panel.size = Vector2(600, 300)
    dead_panel.position = Vector2(340, 210)
    dead_panel.visible = false
    add_child(dead_panel)

    var dl := Label.new()
    dl.text = "YOU HAVE FALLEN\nGeo lost..."
    dl.position = Vector2(120, 60)
    dl.add_theme_font_size_override("font_size", 36)
    dl.modulate = Color(0.6, 0.6, 1.0)
    dead_panel.add_child(dl)

    var rb := Button.new()
    rb.text = "Return to Checkpoint"
    rb.position = Vector2(160, 200)
    rb.size = Vector2(280, 55)
    rb.pressed.connect(_on_respawn)
    dead_panel.add_child(rb)

    # Victory
    victory_panel = ColorRect.new()
    victory_panel.color = Color(0.0, 0.1, 0.05, 0.92)
    victory_panel.size = Vector2(700, 350)
    victory_panel.position = Vector2(290, 185)
    victory_panel.visible = false
    add_child(victory_panel)

    var vl := Label.new()
    vl.text = "STAGE CLEARED\nThe kingdom stirs..."
    vl.position = Vector2(150, 60)
    vl.add_theme_font_size_override("font_size", 36)
    vl.modulate = Color(0.5, 0.8, 1.0)
    victory_panel.add_child(vl)

    var map_btn := Button.new()
    map_btn.text = "Return to Kingdom Map"
    map_btn.position = Vector2(200, 240)
    map_btn.size = Vector2(300, 60)
    map_btn.pressed.connect(_on_map)
    victory_panel.add_child(map_btn)

func _on_start() -> void:
    title_panel.visible = false
    state = GS.MAP
    map_panel.visible = true

func _on_map() -> void:
    victory_panel.visible = false
    dead_panel.visible = false
    state = GS.MAP
    map_panel.visible = true

func _on_stage_select(idx: int) -> void:
    map_panel.visible = false
    current_stage = idx
    _load_stage(idx)
    state = GS.PLAYING

func _on_respawn() -> void:
    dead_panel.visible = false
    masks = max_masks
    soul = 0
    geo = max(0, geo - 10)
    player_x = checkpoint_x
    player_y = checkpoint_y
    player_vx = 0.0
    player_vy = 0.0
    state = GS.PLAYING

func _load_stage(idx: int) -> void:
    stage_cleared = false
    in_boss_room = false
    boss_bar_bg.visible = false
    checkpoint_x = 200.0
    checkpoint_y = 400.0
    player_x = checkpoint_x
    player_y = checkpoint_y
    player_vx = 0.0
    player_vy = 0.0
    masks = max_masks
    soul = 0
    iframes = 0.0
    slash_active = false
    focusing = false
    boss_projectiles.clear()

    platforms = [
        {"x": 0.0, "y": 580.0, "w": 400.0, "h": 20.0},
        {"x": 500.0, "y": 480.0, "w": 200.0, "h": 20.0},
        {"x": 800.0, "y": 380.0, "w": 200.0, "h": 20.0},
        {"x": 1050.0, "y": 580.0, "w": 230.0, "h": 20.0},
        {"x": 0.0, "y": 700.0, "w": 1280.0, "h": 20.0}
    ]

    # 3 enemy types per stage
    enemies = [
        {"x": 350.0, "y": 540.0, "vx": 60.0, "hp": 2, "max_hp": 2, "type": 0, "alive": true, "iframes": 0.0},
        {"x": 600.0, "y": 440.0, "vx": -50.0, "hp": 3, "max_hp": 3, "type": 1, "alive": true, "iframes": 0.0},
        {"x": 900.0, "y": 340.0, "vx": 70.0, "hp": 1, "max_hp": 1, "type": 2, "alive": true, "iframes": 0.0}
    ]

    thorns = [
        {"x": 420.0, "y": 560.0, "w": 60.0, "h": 20.0},
        {"x": 750.0, "y": 460.0, "w": 40.0, "h": 20.0}
    ]

    collectibles = [
        {"x": 550.0, "y": 440.0, "type": "geo", "value": 5, "collected": false},
        {"x": 850.0, "y": 340.0, "type": "geo", "value": 8, "collected": false}
    ]

    stage_exit = Vector2(1150.0, 540.0)

func _enter_boss() -> void:
    state = GS.BOSS
    in_boss_room = true
    boss_hp = boss_max_hp
    boss_x = 900.0
    boss_y = 500.0
    boss_vx = 80.0
    boss_attack_timer = 0.0
    boss_phase = 0
    boss_projectiles.clear()
    platforms = [
        {"x": 0.0, "y": 580.0, "w": 1280.0, "h": 20.0},
        {"x": 200.0, "y": 420.0, "w": 150.0, "h": 20.0},
        {"x": 900.0, "y": 420.0, "w": 150.0, "h": 20.0}
    ]
    enemies = []
    thorns = []
    collectibles = []
    boss_bar_bg.visible = true
    boss_bar_fill.size.x = 500.0

func _process(delta: float) -> void:
    if state == GS.PLAYING or state == GS.BOSS:
        _update(delta)
    _update_hud()
    queue_redraw()

func _update(delta: float) -> void:
    iframes = max(0.0, iframes - delta)

    # Gravity
    if not dashing:
        player_vy += GRAVITY * delta
    player_y += player_vy * delta

    # Horizontal
    var mv := 0.0
    if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
        mv = -SPEED
        facing = -1
    if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
        mv = SPEED
        facing = 1

    if dashing:
        dash_timer -= delta
        player_x += facing * DASH_SPEED * delta
        if dash_timer <= 0.0:
            dashing = false
            player_vx = facing * SPEED * 0.3
    else:
        player_vx = mv
        player_x += player_vx * delta

    player_x = clamp(player_x, 20.0, 1260.0)

    # Platform collision
    on_ground = false
    on_wall = false
    for p in platforms:
        var px: float = float(p["x"])
        var py: float = float(p["y"])
        var pw: float = float(p["w"])
        var ph: float = float(p["h"])
        if player_x >= px and player_x <= px + pw and player_y + 16.0 >= py and player_y + 16.0 <= py + ph + 8.0 and player_vy > 0.0:
            player_y = py - 16.0
            player_vy = 0.0
            on_ground = true
            dash_charge = true

    # Wall cling
    if not on_ground and not dashing:
        for p in platforms:
            var px: float = float(p["x"])
            var py: float = float(p["y"])
            var ph: float = float(p["h"])
            if player_y >= py and player_y <= py + ph:
                if abs(player_x - px) < 14.0:
                    on_wall = true
                    wall_dir = 1
                    dash_charge = true
                elif abs(player_x - (px + float(p["w"]))) < 14.0:
                    on_wall = true
                    wall_dir = -1
                    dash_charge = true
        if on_wall and player_vy > WALL_SLIDE:
            player_vy = WALL_SLIDE

    # Jump
    if Input.is_key_pressed(KEY_SPACE):
        if on_ground:
            player_vy = JUMP_FORCE
        elif on_wall:
            player_vy = JUMP_FORCE
            player_vx = wall_dir * SPEED
            dash_charge = true

    # Dash
    if Input.is_action_just_pressed("dash") and dash_charge and not dashing:
        dashing = true
        dash_timer = DASH_DUR
        dash_charge = false
        player_vy = 0.0

    # Slash
    if Input.is_action_just_pressed("slash"):
        slash_active = true
        slash_timer = 0.25

    if slash_active:
        slash_timer -= delta
        if slash_timer <= 0.0:
            slash_active = false

    # Focus / heal
    if Input.is_action_pressed("focus") and soul >= 33 and on_ground and not slash_active:
        focusing = true
        focus_timer += delta
        if focus_timer >= FOCUS_TIME:
            focus_timer = 0.0
            soul -= 33
            masks = min(masks + 1, max_masks)
    else:
        focusing = false
        focus_timer = 0.0

    # Thorn damage
    for t in thorns:
        if iframes <= 0.0 and player_x >= float(t["x"]) and player_x <= float(t["x"]) + float(t["w"]) and player_y >= float(t["y"]) - 10.0 and player_y <= float(t["y"]) + float(t["h"]):
            masks -= 1
            iframes = 1.5
            player_vy = -200.0

    # Collectibles
    for col in collectibles:
        if not col["collected"] and Vector2(player_x, player_y).distance_to(Vector2(float(col["x"]), float(col["y"]))) < 30.0:
            col["collected"] = true
            if col["type"] == "geo":
                geo += int(col["value"])

    # Enemy update and combat
    for e in enemies:
        if not e["alive"]:
            continue
        e["x"] = float(e["x"]) + float(e["vx"]) * delta
        if float(e["x"]) < 50.0 or float(e["x"]) > 1230.0:
            e["vx"] = -float(e["vx"])
        e["iframes"] = max(0.0, float(e["iframes"]) - delta)

        # Slash hits enemy
        if slash_active and abs(player_x - float(e["x"])) < 70.0 and abs(player_y - float(e["y"])) < 50.0 and float(e["iframes"]) <= 0.0:
            e["hp"] = int(e["hp"]) - 1
            e["iframes"] = 0.5
            soul = min(soul + 11, max_soul)
            if int(e["hp"]) <= 0:
                e["alive"] = false
                geo += 3

        # Enemy damages player
        if iframes <= 0.0 and abs(player_x - float(e["x"])) < 30.0 and abs(player_y - float(e["y"])) < 30.0:
            masks -= 1
            iframes = 1.5
            player_vy = -200.0

    enemies = enemies.filter(func(e): return bool(e["alive"]))

    # Checkpoint (first platform area)
    if on_ground and player_x < 400.0:
        checkpoint_x = player_x
        checkpoint_y = player_y

    # Fall death
    if player_y > 750.0:
        _trigger_death()
        return

    # Mask death
    if masks <= 0:
        _trigger_death()
        return

    # Stage exit
    if state == GS.PLAYING and Vector2(player_x, player_y).distance_to(stage_exit) < 40.0:
        if enemies.is_empty():
            _stage_clear()
        else:
            _enter_boss()
        return

    # Boss
    if state == GS.BOSS:
        _update_boss(delta)

func _update_boss(delta: float) -> void:
    boss_phase = 1 if boss_hp < boss_max_hp / 2 else 0
    var spd := 80.0 + boss_phase * 50.0
    boss_x += boss_vx * delta
    if boss_x < 150.0 or boss_x > 1100.0:
        boss_vx = -boss_vx

    boss_attack_timer += delta
    var attack_interval := 1.5 - boss_phase * 0.4
    if boss_attack_timer >= attack_interval:
        boss_attack_timer = 0.0
        # Pattern varies by phase
        match boss_phase:
            0:
                boss_projectiles.append({"x": boss_x, "y": boss_y, "vx": -200.0, "vy": 0.0})
            1:
                boss_projectiles.append({"x": boss_x, "y": boss_y, "vx": -180.0, "vy": -100.0})
                boss_projectiles.append({"x": boss_x, "y": boss_y, "vx": -180.0, "vy": 100.0})

    for proj in boss_projectiles:
        proj["x"] = float(proj["x"]) + float(proj["vx"]) * delta
        proj["y"] = float(proj["y"]) + float(proj["vy"]) * delta
    boss_projectiles = boss_projectiles.filter(func(p): return float(p["x"]) > 0.0 and float(p["x"]) < 1280.0)

    # Slash hits boss
    if slash_active and abs(player_x - boss_x) < 80.0 and abs(player_y - boss_y) < 60.0:
        boss_hp -= 1
        soul = min(soul + 11, max_soul)
        boss_bar_fill.size.x = 500.0 * boss_hp / float(boss_max_hp)
        if boss_hp <= 0:
            _stage_clear()
            return

    # Boss projectile hits player
    for proj in boss_projectiles:
        if iframes <= 0.0 and abs(player_x - float(proj["x"])) < 20.0 and abs(player_y - float(proj["y"])) < 20.0:
            masks -= 1
            iframes = 1.5
            player_vy = -200.0

    # Boss body hits player
    if iframes <= 0.0 and abs(player_x - boss_x) < 40.0 and abs(player_y - boss_y) < 40.0:
        masks -= 1
        iframes = 1.5
        player_vy = -200.0

func _trigger_death() -> void:
    state = GS.DEAD
    geo = max(0, geo - 10)
    dead_panel.visible = true

func _stage_clear() -> void:
    stage_cleared = true
    if current_stage + 1 > stages_unlocked:
        stages_unlocked = current_stage + 1
    state = GS.VICTORY
    boss_bar_bg.visible = false
    victory_panel.visible = true

func _update_hud() -> void:
    hud_masks.text = "Masks: %d/%d  %s" % [masks, max_masks, "(FOCUSING)" if focusing else ""]
    hud_soul.text = "Soul: %d/%d" % [soul, max_soul]
    hud_geo.text = "Geo: %d" % geo

func _draw() -> void:
    if state == GS.TITLE or state == GS.MAP:
        return

    # Platforms
    for p in platforms:
        draw_rect(Rect2(float(p["x"]), float(p["y"]), float(p["w"]), float(p["h"])), Color(0.25, 0.2, 0.35))

    # Thorns
    for t in thorns:
        draw_rect(Rect2(float(t["x"]), float(t["y"]), float(t["w"]), float(t["h"])), Color(0.7, 0.1, 0.1))
        draw_string(ThemeDB.fallback_font, Vector2(float(t["x"]) + 2.0, float(t["y"]) - 4.0), "THORN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

    # Collectibles
    for col in collectibles:
        if not col["collected"]:
            draw_circle(Vector2(float(col["x"]), float(col["y"])), 8.0, Color(0.9, 0.8, 0.2))

    # Stage exit
    draw_rect(Rect2(stage_exit.x - 18.0, stage_exit.y - 30.0, 36.0, 50.0), Color(0.3, 0.6, 1.0))
    draw_string(ThemeDB.fallback_font, Vector2(stage_exit.x - 15.0, stage_exit.y - 5.0), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

    # Enemies
    var ecols := [Color(0.8, 0.3, 0.3), Color(0.3, 0.7, 0.3), Color(0.7, 0.3, 0.8)]
    for e in enemies:
        if bool(e["alive"]):
            draw_rect(Rect2(float(e["x"]) - 16.0, float(e["y"]) - 16.0, 32.0, 32.0), ecols[int(e["type"])])
            # HP bar
            var hp_ratio: float = float(e["hp"]) / float(e["max_hp"])
            draw_rect(Rect2(float(e["x"]) - 16.0, float(e["y"]) - 24.0, 32.0, 4.0), Color(0.3, 0.0, 0.0))
            draw_rect(Rect2(float(e["x"]) - 16.0, float(e["y"]) - 24.0, 32.0 * hp_ratio, 4.0), Color(0.9, 0.1, 0.1))

    # Boss
    if state == GS.BOSS:
        draw_rect(Rect2(boss_x - 35.0, boss_y - 45.0, 70.0, 70.0), Color(0.5, 0.0, 0.5))
        draw_string(ThemeDB.fallback_font, Vector2(boss_x - 25.0, boss_y - 50.0), "BOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
        for proj in boss_projectiles:
            draw_circle(Vector2(float(proj["x"]), float(proj["y"])), 8.0, Color(0.9, 0.3, 0.9))

    # Player
    if state == GS.PLAYING or state == GS.BOSS:
        var pcol := Color(0.7, 0.7, 0.9) if iframes <= 0.0 else Color(1.0, 1.0, 1.0, 0.4)
        draw_rect(Rect2(player_x - 14.0, player_y - 20.0, 28.0, 36.0), pcol)
        if slash_active:
            var sx := player_x + facing * 40.0
            draw_rect(Rect2(sx - 20.0, player_y - 10.0, 40.0, 8.0), Color(1.0, 0.9, 0.3))
        if focusing:
            draw_circle(Vector2(player_x, player_y), 20.0, Color(0.5, 0.8, 1.0, 0.3))
GDSCRIPT


cat > "$GAME_DIR/demo_outputs/01_title.json" << 'DEMO'
{
  "duration_frames": 300,
  "events": [
    {"frame": 60, "type": "mouse_click", "button": "left", "x": 640, "y": 413}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/02_map.json" << 'DEMO'
{
  "scenario": "map",
  "duration_frames": 300,
  "events": [
    {"frame": 60, "type": "mouse_click", "button": "left", "x": 640, "y": 180}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/03_combat.json" << 'DEMO'
{
  "scenario": "combat",
  "duration_frames": 540,
  "events": [
    {"frame": 30,  "type": "key_down",  "keycode": "RIGHT"},
    {"frame": 60,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 90,  "type": "key_up",    "keycode": "RIGHT"},
    {"frame": 120, "type": "key_press", "keycode": "Z"},
    {"frame": 150, "type": "key_press", "keycode": "Z"},
    {"frame": 180, "type": "key_down",  "keycode": "RIGHT"},
    {"frame": 210, "type": "key_press", "keycode": "SPACE"},
    {"frame": 240, "type": "key_press", "keycode": "Z"},
    {"frame": 270, "type": "key_press", "keycode": "Z"},
    {"frame": 300, "type": "key_up",    "keycode": "RIGHT"},
    {"frame": 330, "type": "key_press", "keycode": "X"},
    {"frame": 360, "type": "key_down",  "keycode": "RIGHT"},
    {"frame": 390, "type": "key_press", "keycode": "Z"},
    {"frame": 420, "type": "key_press", "keycode": "Z"},
    {"frame": 450, "type": "key_press", "keycode": "Z"},
    {"frame": 480, "type": "key_up",    "keycode": "RIGHT"},
    {"frame": 510, "type": "key_press", "keycode": "Z"}
  ]
}
DEMO

cat > "$GAME_DIR/demo_outputs/04_boss.json" << 'DEMO'
{
  "scenario": "boss",
  "duration_frames": 540,
  "events": [
    {"frame": 30,  "type": "key_down",  "keycode": "RIGHT"},
    {"frame": 60,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 90,  "type": "key_up",    "keycode": "RIGHT"},
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
    {"frame": 450, "type": "key_press", "keycode": "Z"},
    {"frame": 480, "type": "key_press", "keycode": "Z"},
    {"frame": 510, "type": "key_press", "keycode": "Z"}
  ]
}
DEMO

echo "Oracle written to $GAME_DIR"
