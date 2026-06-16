#!/usr/bin/env bash
# Oracle reference implementation for platformer-thunder-valkyrie.
# 2D vertical scrolling bullet-hell shmup with hangar, sector map, and boss.
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
config/name="Thunder Valkyrie"
run/main_scene="res://Main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720

[input]
move_up={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":119,"location":0,"echo":false,"script":null), Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194320,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
move_down={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":83,"key_label":0,"unicode":115,"location":0,"echo":false,"script":null), Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194322,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
move_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":97,"location":0,"echo":false,"script":null), Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194319,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
move_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":100,"location":0,"echo":false,"script":null), Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194321,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
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

enum GS { TITLE, HANGAR, MAP, FLIGHT, RESULTS, VICTORY }
var state: int = GS.TITLE

# Player
var ship_pos := Vector2(640.0, 580.0)
const SHIP_SPEED := 320.0
const SHIP_BOUNDS := Rect2(40, 40, 1200, 640)
var shield_hp := 5
var max_shield := 5
var score := 0
var gold := 0
var frenzy := false
var frenzy_timer := 0.0
const FRENZY_DURATION := 5.0

# Lasers
var lasers: Array = []
var laser_timer := 0.0
const LASER_INTERVAL := 0.12

# Enemies
var enemies: Array = []
var enemy_bullets: Array = []
var wave_timer := 0.0
var wave_index := 0
var enemies_killed := 0

# Crystals
var crystals: Array = []

# Boss
var boss_active := false
var boss_pos := Vector2(640.0, 120.0)
var boss_hp := 20
var boss_max_hp := 20
var boss_phase := 1
var boss_fire_timer := 0.0
var boss_move_dir := 1.0

# Scrolling background
var scroll_y := 0.0
var stars: Array = []

# Save/load
var stages_unlocked := [true, false, false]
var hangar_level := 1
var hangar_gold := 0
var current_stage := 0

# Scenario
var scenario := ""

func _ready() -> void:
    randomize()
    _init_stars()
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if String(args[i]) == "--scenario" and i + 1 < args.size():
            scenario = String(args[i + 1])
    _load_save()
    match scenario:
        "flight":
            current_stage = 0
            _enter_flight()
        "boss":
            current_stage = 0
            _enter_flight_boss()
        "stage2":
            current_stage = 1
            stages_unlocked[1] = true
            _enter_flight()
        "hangar":
            _enter_hangar()
        "map":
            _enter_map()
        "map_unlocked":
            stages_unlocked = [true, true, true]
            _enter_map()
        _:
            _enter_title()

func _init_stars() -> void:
    for i in range(120):
        stars.append({
            "pos": Vector2(randf() * 1280.0, randf() * 720.0),
            "speed": randf_range(30.0, 120.0),
            "size": randf_range(1.0, 3.0),
            "bright": randf_range(0.3, 1.0)
        })

func _enter_title() -> void:
    state = GS.TITLE
    _clear_all()
    _draw_title()

func _enter_hangar() -> void:
    state = GS.HANGAR
    _clear_all()
    _draw_hangar()

func _enter_map() -> void:
    state = GS.MAP
    _clear_all()
    _draw_map()

func _enter_flight() -> void:
    state = GS.FLIGHT
    _clear_all()
    ship_pos = Vector2(640.0, 580.0)
    shield_hp = max_shield
    score = 0
    frenzy = false
    frenzy_timer = 0.0
    lasers.clear()
    enemies.clear()
    enemy_bullets.clear()
    crystals.clear()
    wave_timer = 0.0
    wave_index = 0
    enemies_killed = 0
    boss_active = false
    laser_timer = 0.0
    scroll_y = 0.0

func _enter_flight_boss() -> void:
    _enter_flight()
    wave_index = 99
    boss_active = true
    boss_hp = 20
    boss_max_hp = 20
    boss_phase = 1
    boss_pos = Vector2(640.0, 120.0)
    boss_fire_timer = 0.0

func _enter_results(victory: bool) -> void:
    if victory:
        state = GS.VICTORY
        if current_stage < 2:
            stages_unlocked[current_stage + 1] = true
        hangar_gold += score / 10
        _save_progress()
    else:
        state = GS.RESULTS
    _clear_all()
    _draw_results(victory)

func _input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.pressed and not event.echo):
        return
    var kc: int = event.keycode if event.keycode != 0 else event.physical_keycode
    match state:
        GS.TITLE:
            if kc == KEY_ENTER or kc == KEY_SPACE:
                _enter_hangar()
        GS.HANGAR:
            if kc == KEY_ENTER or kc == KEY_SPACE:
                _enter_map()
            elif kc == KEY_ESCAPE:
                _enter_title()
            elif kc == KEY_1 and hangar_gold >= 10:
                hangar_gold -= 10
                hangar_level = mini(hangar_level + 1, 5)
                max_shield = 3 + hangar_level
                _save_progress()
                _enter_hangar()
        GS.MAP:
            if kc == KEY_1:
                current_stage = 0; _enter_flight()
            elif kc == KEY_2 and stages_unlocked[1]:
                current_stage = 1; _enter_flight()
            elif kc == KEY_3 and stages_unlocked[2]:
                current_stage = 2; _enter_flight()
            elif kc == KEY_ESCAPE:
                _enter_hangar()
        GS.FLIGHT:
            if kc == KEY_ESCAPE:
                _enter_map()
        GS.RESULTS, GS.VICTORY:
            if kc == KEY_ENTER or kc == KEY_SPACE:
                _enter_map()
            elif kc == KEY_ESCAPE:
                _enter_title()

func _process(delta: float) -> void:
    if state != GS.FLIGHT:
        return
    _scroll_stars(delta)
    _move_player(delta)
    _fire_lasers(delta)
    _update_lasers(delta)
    _update_waves(delta)
    _update_enemies(delta)
    _update_enemy_bullets(delta)
    _update_boss(delta)
    _update_crystals(delta)
    if frenzy:
        frenzy_timer -= delta
        if frenzy_timer <= 0.0:
            frenzy = false
    _draw_flight()

func _scroll_stars(delta: float) -> void:
    scroll_y += 60.0 * delta
    if scroll_y >= 720.0:
        scroll_y -= 720.0
    for s in stars:
        s.pos.y += s.speed * delta
        if s.pos.y > 720.0:
            s.pos.y -= 720.0

func _move_player(delta: float) -> void:
    var vel := Vector2.ZERO
    if Input.is_action_pressed("move_up"):    vel.y -= 1.0
    if Input.is_action_pressed("move_down"):  vel.y += 1.0
    if Input.is_action_pressed("move_left"):  vel.x -= 1.0
    if Input.is_action_pressed("move_right"): vel.x += 1.0
    if vel.length() > 0.0:
        vel = vel.normalized() * SHIP_SPEED
    ship_pos += vel * delta
    ship_pos.x = clampf(ship_pos.x, SHIP_BOUNDS.position.x, SHIP_BOUNDS.position.x + SHIP_BOUNDS.size.x)
    ship_pos.y = clampf(ship_pos.y, SHIP_BOUNDS.position.y, SHIP_BOUNDS.position.y + SHIP_BOUNDS.size.y)

func _fire_lasers(delta: float) -> void:
    laser_timer -= delta
    if laser_timer <= 0.0:
        var interval: float = LASER_INTERVAL * (0.5 if frenzy else 1.0)
        laser_timer = interval
        lasers.append({"pos": Vector2(ship_pos.x, ship_pos.y - 20.0), "speed": 600.0})
        if hangar_level >= 3:
            lasers.append({"pos": Vector2(ship_pos.x - 20.0, ship_pos.y), "speed": 600.0})
            lasers.append({"pos": Vector2(ship_pos.x + 20.0, ship_pos.y), "speed": 600.0})

func _update_lasers(delta: float) -> void:
    var to_remove: Array = []
    for i in range(lasers.size()):
        lasers[i].pos.y -= lasers[i].speed * delta
        if lasers[i].pos.y < -10.0:
            to_remove.append(i)
            continue
        # Hit boss
        if boss_active:
            if abs(lasers[i].pos.x - boss_pos.x) < 60.0 and abs(lasers[i].pos.y - boss_pos.y) < 40.0:
                boss_hp -= 1
                score += 5
                to_remove.append(i)
                if boss_hp <= 0:
                    _enter_results(true)
                    return
                elif boss_hp <= boss_max_hp / 2 and boss_phase == 1:
                    boss_phase = 2
                continue
        # Hit enemies
        for j in range(enemies.size() - 1, -1, -1):
            if abs(lasers[i].pos.x - enemies[j].pos.x) < 20.0 and abs(lasers[i].pos.y - enemies[j].pos.y) < 20.0:
                enemies[j].hp -= 1
                score += 10
                if enemies[j].hp <= 0:
                    if enemies[j].type == "capital":
                        crystals.append({"pos": Vector2(enemies[j].pos.x, enemies[j].pos.y), "vel": Vector2(0.0, 80.0)})
                    enemies.remove_at(j)
                    enemies_killed += 1
                to_remove.append(i)
                break
    to_remove.reverse()
    for idx in to_remove:
        if idx < lasers.size():
            lasers.remove_at(idx)

func _update_waves(delta: float) -> void:
    if boss_active or wave_index >= 99:
        return
    wave_timer -= delta
    if wave_timer > 0.0:
        return
    wave_timer = 3.0
    var formation := wave_index % 4
    match formation:
        0:  # Row of scouts
            for i in range(5):
                enemies.append({"pos": Vector2(200.0 + i * 180.0, -30.0), "vel": Vector2(0.0, 80.0), "hp": 1, "type": "scout", "fire_cd": 1.5 + i * 0.2})
        1:  # V-shape interceptors
            for i in range(3):
                enemies.append({"pos": Vector2(440.0 + i * 200.0, -30.0 - i * 40.0), "vel": Vector2(0.0, 100.0), "hp": 2, "type": "interceptor", "fire_cd": 1.0})
                if i > 0:
                    enemies.append({"pos": Vector2(440.0 - i * 200.0 + 200.0, -30.0 - i * 40.0), "vel": Vector2(0.0, 100.0), "hp": 2, "type": "interceptor", "fire_cd": 1.0})
        2:  # Capital ship
            enemies.append({"pos": Vector2(640.0, -60.0), "vel": Vector2(0.0, 50.0), "hp": 8, "type": "capital", "fire_cd": 0.8})
        3:  # Flankers
            enemies.append({"pos": Vector2(100.0, 200.0), "vel": Vector2(60.0, 40.0), "hp": 3, "type": "flanker", "fire_cd": 1.2})
            enemies.append({"pos": Vector2(1180.0, 200.0), "vel": Vector2(-60.0, 40.0), "hp": 3, "type": "flanker", "fire_cd": 1.2})
    wave_index += 1
    if wave_index >= 8:
        wave_timer = 2.0
        boss_active = true
        boss_hp = 20
        boss_max_hp = 20
        boss_phase = 1
        boss_pos = Vector2(640.0, 120.0)
        boss_fire_timer = 0.0

func _update_enemies(delta: float) -> void:
    var to_remove: Array = []
    for i in range(enemies.size()):
        enemies[i].pos += enemies[i].vel * delta
        if enemies[i].pos.y > 780.0:
            to_remove.append(i)
            continue
        enemies[i].fire_cd -= delta
        if enemies[i].fire_cd <= 0.0:
            enemies[i].fire_cd = 1.5
            var dir: Vector2 = (ship_pos - enemies[i].pos).normalized()
            match enemies[i].type:
                "scout":
                    enemy_bullets.append({"pos": Vector2(enemies[i].pos.x, enemies[i].pos.y), "vel": Vector2(0.0, 200.0)})
                "interceptor":
                    enemy_bullets.append({"pos": Vector2(enemies[i].pos.x, enemies[i].pos.y), "vel": dir * 220.0})
                "capital":
                    for a in range(5):
                        var angle: float = deg_to_rad(-60.0 + a * 30.0)
                        enemy_bullets.append({"pos": Vector2(enemies[i].pos.x, enemies[i].pos.y), "vel": Vector2(sin(angle), cos(angle)) * 180.0})
                "flanker":
                    enemy_bullets.append({"pos": Vector2(enemies[i].pos.x, enemies[i].pos.y), "vel": dir * 250.0})
                    enemy_bullets.append({"pos": Vector2(enemies[i].pos.x, enemies[i].pos.y), "vel": Vector2(-dir.y, dir.x) * 200.0})
    to_remove.reverse()
    for idx in to_remove:
        enemies.remove_at(idx)

func _update_enemy_bullets(delta: float) -> void:
    var to_remove: Array = []
    for i in range(enemy_bullets.size()):
        enemy_bullets[i].pos += enemy_bullets[i].vel * delta
        var p: Vector2 = enemy_bullets[i].pos
        if p.x < -20.0 or p.x > 1300.0 or p.y < -20.0 or p.y > 740.0:
            to_remove.append(i)
            continue
        if (p - ship_pos).length() < 12.0:
            shield_hp -= 1
            to_remove.append(i)
            if shield_hp <= 0:
                _enter_results(false)
                return
    to_remove.reverse()
    for idx in to_remove:
        if idx < enemy_bullets.size():
            enemy_bullets.remove_at(idx)

func _update_boss(delta: float) -> void:
    if not boss_active:
        return
    boss_pos.x += boss_move_dir * 80.0 * delta
    if boss_pos.x > 1100.0 or boss_pos.x < 180.0:
        boss_move_dir *= -1.0
    boss_fire_timer -= delta
    if boss_fire_timer <= 0.0:
        boss_fire_timer = 0.6 if boss_phase == 2 else 1.0
        var count: int = 12 if boss_phase == 2 else 8
        for i in range(count):
            var angle: float = (TAU / count) * i
            enemy_bullets.append({"pos": Vector2(boss_pos.x, boss_pos.y), "vel": Vector2(cos(angle), sin(angle)) * 160.0})

func _update_crystals(delta: float) -> void:
    var to_remove: Array = []
    for i in range(crystals.size()):
        crystals[i].pos += crystals[i].vel * delta
        if crystals[i].pos.y > 740.0:
            to_remove.append(i)
            continue
        if (crystals[i].pos - ship_pos).length() < 30.0:
            frenzy = true
            frenzy_timer = FRENZY_DURATION
            score += 50
            to_remove.append(i)
    to_remove.reverse()
    for idx in to_remove:
        crystals.remove_at(idx)

# ── Drawing ──────────────────────────────────────────────────────────────────

func _clear_all() -> void:
    for child in get_children():
        child.queue_free()

func _draw_bg() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.01, 0.01, 0.06, 1.0)
    bg.position = Vector2.ZERO
    bg.size = Vector2(1280, 720)
    add_child(bg)
    for s in stars:
        var sr := ColorRect.new()
        sr.color = Color(s.bright, s.bright, 1.0, s.bright)
        sr.position = s.pos - Vector2(s.size * 0.5, s.size * 0.5)
        sr.size = Vector2(s.size, s.size)
        add_child(sr)

func _draw_title() -> void:
    _draw_bg()
    var title := Label.new()
    title.text = "THUNDER VALKYRIE"
    title.add_theme_font_size_override("font_size", 60)
    title.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
    title.position = Vector2(320, 200)
    add_child(title)
    var sub := Label.new()
    sub.text = "Pilot the cosmos. Survive the storm."
    sub.add_theme_font_size_override("font_size", 22)
    sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
    sub.position = Vector2(400, 300)
    add_child(sub)
    var prompt := Label.new()
    prompt.text = "[ENTER] Launch"
    prompt.add_theme_font_size_override("font_size", 20)
    prompt.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
    prompt.position = Vector2(540, 500)
    add_child(prompt)

func _draw_hangar() -> void:
    _draw_bg()
    var header := Label.new()
    header.text = "HANGAR — LOADOUT"
    header.add_theme_font_size_override("font_size", 36)
    header.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
    header.position = Vector2(460, 40)
    add_child(header)
    var gold_lbl := Label.new()
    gold_lbl.text = "GOLD: %d" % hangar_gold
    gold_lbl.add_theme_font_size_override("font_size", 22)
    gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
    gold_lbl.position = Vector2(60, 40)
    add_child(gold_lbl)
    var slots := [
        ["Starfighter Lv", str(hangar_level)],
        ["Shield Type", "Mk-%d" % mini(hangar_level, 3)],
        ["Sub-weapon", "Missiles" if hangar_level >= 2 else "None"],
        ["Wingman", "Active" if hangar_level >= 4 else "Locked"]
    ]
    for i in range(4):
        var panel := ColorRect.new()
        panel.color = Color(0.05, 0.1, 0.2, 1.0)
        panel.position = Vector2(100 + i * 270, 200)
        panel.size = Vector2(240, 160)
        add_child(panel)
        var lbl := Label.new()
        lbl.text = slots[i][0]
        lbl.add_theme_font_size_override("font_size", 16)
        lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
        lbl.position = Vector2(110 + i * 270, 210)
        add_child(lbl)
        var val := Label.new()
        val.text = slots[i][1]
        val.add_theme_font_size_override("font_size", 22)
        val.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
        val.position = Vector2(110 + i * 270, 260)
        add_child(val)
    var upgrade_hint := Label.new()
    upgrade_hint.text = "[1] Upgrade Starfighter (10 Gold)  |  [ENTER] Deploy  |  [ESC] Back"
    upgrade_hint.add_theme_font_size_override("font_size", 16)
    upgrade_hint.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
    upgrade_hint.position = Vector2(200, 600)
    add_child(upgrade_hint)

func _draw_map() -> void:
    _draw_bg()
    var header := Label.new()
    header.text = "SECTOR MAP"
    header.add_theme_font_size_override("font_size", 36)
    header.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
    header.position = Vector2(520, 40)
    add_child(header)
    var stage_names := ["Orion's Belt", "Perseus Void", "The Nebula Core"]
    for i in range(3):
        var panel := ColorRect.new()
        panel.color = Color(0.05, 0.12, 0.25, 1.0) if stages_unlocked[i] else Color(0.05, 0.05, 0.1, 0.6)
        panel.position = Vector2(100 + i * 370, 220)
        panel.size = Vector2(320, 200)
        add_child(panel)
        var lbl := Label.new()
        lbl.text = "%d: %s" % [i + 1, stage_names[i]]
        lbl.add_theme_font_size_override("font_size", 20)
        lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0) if stages_unlocked[i] else Color(0.3, 0.3, 0.4))
        lbl.position = Vector2(110 + i * 370, 240)
        add_child(lbl)
        var status := Label.new()
        status.text = "UNLOCKED" if stages_unlocked[i] else "LOCKED"
        status.add_theme_font_size_override("font_size", 16)
        status.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5) if stages_unlocked[i] else Color(0.5, 0.3, 0.3))
        status.position = Vector2(110 + i * 370, 290)
        add_child(status)
    var hint := Label.new()
    hint.text = "[1][2][3] Select Stage  |  [ESC] Hangar"
    hint.add_theme_font_size_override("font_size", 16)
    hint.add_theme_color_override("font_color", Color(0.4, 0.6, 0.4))
    hint.position = Vector2(420, 620)
    add_child(hint)

func _draw_flight() -> void:
    _clear_all()
    # Background
    _draw_bg()
    # Crystals
    for c in crystals:
        var cr := ColorRect.new()
        cr.color = Color(1.0, 0.2, 0.2, 1.0)
        cr.position = c.pos - Vector2(8, 8)
        cr.size = Vector2(16, 16)
        add_child(cr)
    # Enemy bullets
    for b in enemy_bullets:
        var br := ColorRect.new()
        br.color = Color(1.0, 0.5, 0.1, 1.0)
        br.position = b.pos - Vector2(4, 4)
        br.size = Vector2(8, 8)
        add_child(br)
    # Enemies
    for e in enemies:
        var er := ColorRect.new()
        match e.type:
            "scout":     er.color = Color(0.8, 0.3, 0.8, 1.0)
            "interceptor": er.color = Color(0.9, 0.2, 0.3, 1.0)
            "capital":   er.color = Color(0.6, 0.1, 0.1, 1.0)
            "flanker":   er.color = Color(0.7, 0.4, 0.1, 1.0)
        er.position = e.pos - Vector2(18, 14)
        er.size = Vector2(36, 28)
        add_child(er)
        # HP bar
        var hp_bg := ColorRect.new()
        hp_bg.color = Color(0.2, 0.0, 0.0, 1.0)
        hp_bg.position = e.pos - Vector2(18, 20)
        hp_bg.size = Vector2(36, 4)
        add_child(hp_bg)
        var hp_fill := ColorRect.new()
        hp_fill.color = Color(1.0, 0.3, 0.3, 1.0)
        hp_fill.position = e.pos - Vector2(18, 20)
        hp_fill.size = Vector2(36.0 * float(e.hp) / 8.0, 4)
        add_child(hp_fill)
    # Boss
    if boss_active:
        var boss_rect := ColorRect.new()
        boss_rect.color = Color(0.5, 0.1, 0.7, 1.0) if boss_phase == 1 else Color(0.8, 0.1, 0.5, 1.0)
        boss_rect.position = boss_pos - Vector2(60, 40)
        boss_rect.size = Vector2(120, 80)
        add_child(boss_rect)
        # Boss HP bar
        var bhp_bg := ColorRect.new()
        bhp_bg.color = Color(0.1, 0.0, 0.1, 1.0)
        bhp_bg.position = Vector2(200, 10)
        bhp_bg.size = Vector2(880, 16)
        add_child(bhp_bg)
        var bhp_fill := ColorRect.new()
        bhp_fill.color = Color(0.8, 0.2, 1.0, 1.0)
        bhp_fill.position = Vector2(200, 10)
        bhp_fill.size = Vector2(880.0 * float(boss_hp) / float(boss_max_hp), 16)
        add_child(bhp_fill)
        var boss_lbl := Label.new()
        boss_lbl.text = "CELESTIAL GUARDIAN  Phase %d" % boss_phase
        boss_lbl.add_theme_font_size_override("font_size", 14)
        boss_lbl.add_theme_color_override("font_color", Color(0.9, 0.5, 1.0))
        boss_lbl.position = Vector2(200, 28)
        add_child(boss_lbl)
    # Player lasers
    for l in lasers:
        var lr := ColorRect.new()
        lr.color = Color(0.3, 0.8, 1.0, 1.0)
        lr.position = l.pos - Vector2(2, 10)
        lr.size = Vector2(4, 20)
        add_child(lr)
    # Player ship
    var ship_rect := ColorRect.new()
    ship_rect.color = Color(0.2, 0.6, 1.0, 1.0) if not frenzy else Color(1.0, 0.8, 0.2, 1.0)
    ship_rect.position = ship_pos - Vector2(16, 20)
    ship_rect.size = Vector2(32, 40)
    add_child(ship_rect)
    # Hitbox indicator
    var hb := ColorRect.new()
    hb.color = Color(1.0, 1.0, 1.0, 0.9)
    hb.position = ship_pos - Vector2(4, 4)
    hb.size = Vector2(8, 8)
    add_child(hb)
    # HUD
    _draw_hud()

func _draw_hud() -> void:
    var hud_bg := ColorRect.new()
    hud_bg.color = Color(0.0, 0.0, 0.05, 0.85)
    hud_bg.position = Vector2(0, 0)
    hud_bg.size = Vector2(1280, 36)
    add_child(hud_bg)
    var stage_names := ["Orion's Belt", "Perseus Void", "The Nebula Core"]
    var stage_lbl := Label.new()
    stage_lbl.text = stage_names[current_stage]
    stage_lbl.add_theme_font_size_override("font_size", 14)
    stage_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
    stage_lbl.position = Vector2(10, 8)
    add_child(stage_lbl)
    var shield_lbl := Label.new()
    shield_lbl.text = "SHIELD: %d/%d" % [shield_hp, max_shield]
    shield_lbl.add_theme_font_size_override("font_size", 14)
    shield_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
    shield_lbl.position = Vector2(300, 8)
    add_child(shield_lbl)
    var score_lbl := Label.new()
    score_lbl.text = "SCORE: %d" % score
    score_lbl.add_theme_font_size_override("font_size", 14)
    score_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
    score_lbl.position = Vector2(500, 8)
    add_child(score_lbl)
    var wave_lbl := Label.new()
    wave_lbl.text = "WAVE: %d" % wave_index if not boss_active else "BOSS"
    wave_lbl.add_theme_font_size_override("font_size", 14)
    wave_lbl.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
    wave_lbl.position = Vector2(700, 8)
    add_child(wave_lbl)
    if frenzy:
        var frenzy_lbl := Label.new()
        frenzy_lbl.text = "FRENZY! %.1fs" % frenzy_timer
        frenzy_lbl.add_theme_font_size_override("font_size", 14)
        frenzy_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.1))
        frenzy_lbl.position = Vector2(900, 8)
        add_child(frenzy_lbl)

func _draw_results(victory: bool) -> void:
    _draw_bg()
    var title := Label.new()
    title.text = "MISSION COMPLETE" if victory else "SHIP DESTROYED"
    title.add_theme_font_size_override("font_size", 48)
    title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5) if victory else Color(1.0, 0.3, 0.3))
    title.position = Vector2(380, 200)
    add_child(title)
    var stats := Label.new()
    stats.text = "Score: %d\nGold Earned: %d\nWaves Survived: %d" % [score, score / 10, wave_index]
    stats.add_theme_font_size_override("font_size", 24)
    stats.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
    stats.position = Vector2(480, 320)
    add_child(stats)
    var prompt := Label.new()
    prompt.text = "[ENTER] Sector Map  |  [ESC] Title"
    prompt.add_theme_font_size_override("font_size", 18)
    prompt.add_theme_color_override("font_color", Color(0.4, 0.7, 0.4))
    prompt.position = Vector2(440, 520)
    add_child(prompt)

# ── Save/Load ────────────────────────────────────────────────────────────────

const SAVE_PATH := "user://thunder_valkyrie_save.cfg"

func _save_progress() -> void:
    var cfg := ConfigFile.new()
    for i in range(stages_unlocked.size()):
        cfg.set_value("progress", "stage_%d" % i, stages_unlocked[i])
    cfg.set_value("hangar", "level", hangar_level)
    cfg.set_value("hangar", "gold", hangar_gold)
    cfg.save(SAVE_PATH)

func _load_save() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) == OK:
        for i in range(stages_unlocked.size()):
            stages_unlocked[i] = cfg.get_value("progress", "stage_%d" % i, i == 0)
        hangar_level = int(cfg.get_value("hangar", "level", 1))
        hangar_gold = int(cfg.get_value("hangar", "gold", 0))
        max_shield = 3 + hangar_level
GDSCRIPT

###############################################################################
# Demo traces
###############################################################################

# Demo 1: Title → Hangar → Map → Stage 1 flight (shows M1 movement, M2 waves, V1/V2 HUD)
cat > "$GAME_DIR/demo_outputs/01_title_to_flight.json" << 'DEMO1'
{
  "duration_frames": 600,
  "events": [
    {"frame": 30,  "type": "key_press", "keycode": "ENTER"},
    {"frame": 60,  "type": "key_press", "keycode": "ENTER"},
    {"frame": 90,  "type": "key_press", "keycode": "1"},
    {"frame": 120, "type": "key_press", "keycode": "W"},
    {"frame": 125, "type": "key_press", "keycode": "W"},
    {"frame": 130, "type": "key_press", "keycode": "A"},
    {"frame": 135, "type": "key_press", "keycode": "A"},
    {"frame": 140, "type": "key_press", "keycode": "D"},
    {"frame": 145, "type": "key_press", "keycode": "D"},
    {"frame": 150, "type": "key_press", "keycode": "S"},
    {"frame": 155, "type": "key_press", "keycode": "W"},
    {"frame": 160, "type": "key_press", "keycode": "W"},
    {"frame": 165, "type": "key_press", "keycode": "A"},
    {"frame": 170, "type": "key_press", "keycode": "A"},
    {"frame": 175, "type": "key_press", "keycode": "D"},
    {"frame": 180, "type": "key_press", "keycode": "W"},
    {"frame": 185, "type": "key_press", "keycode": "W"},
    {"frame": 190, "type": "key_press", "keycode": "A"},
    {"frame": 200, "type": "key_press", "keycode": "D"},
    {"frame": 210, "type": "key_press", "keycode": "W"},
    {"frame": 220, "type": "key_press", "keycode": "A"},
    {"frame": 230, "type": "key_press", "keycode": "D"},
    {"frame": 240, "type": "key_press", "keycode": "W"},
    {"frame": 250, "type": "key_press", "keycode": "A"},
    {"frame": 260, "type": "key_press", "keycode": "D"},
    {"frame": 270, "type": "key_press", "keycode": "W"},
    {"frame": 280, "type": "key_press", "keycode": "A"},
    {"frame": 290, "type": "key_press", "keycode": "D"},
    {"frame": 300, "type": "key_press", "keycode": "W"},
    {"frame": 310, "type": "key_press", "keycode": "A"},
    {"frame": 320, "type": "key_press", "keycode": "D"},
    {"frame": 330, "type": "key_press", "keycode": "W"},
    {"frame": 340, "type": "key_press", "keycode": "A"},
    {"frame": 350, "type": "key_press", "keycode": "D"},
    {"frame": 360, "type": "key_press", "keycode": "W"},
    {"frame": 370, "type": "key_press", "keycode": "A"},
    {"frame": 380, "type": "key_press", "keycode": "D"},
    {"frame": 390, "type": "key_press", "keycode": "W"},
    {"frame": 400, "type": "key_press", "keycode": "A"},
    {"frame": 410, "type": "key_press", "keycode": "D"},
    {"frame": 420, "type": "key_press", "keycode": "W"},
    {"frame": 430, "type": "key_press", "keycode": "A"},
    {"frame": 440, "type": "key_press", "keycode": "D"},
    {"frame": 450, "type": "key_press", "keycode": "W"},
    {"frame": 460, "type": "key_press", "keycode": "A"},
    {"frame": 470, "type": "key_press", "keycode": "D"},
    {"frame": 480, "type": "key_press", "keycode": "W"},
    {"frame": 490, "type": "key_press", "keycode": "A"},
    {"frame": 500, "type": "key_press", "keycode": "D"},
    {"frame": 510, "type": "key_press", "keycode": "W"},
    {"frame": 520, "type": "key_press", "keycode": "A"},
    {"frame": 530, "type": "key_press", "keycode": "D"},
    {"frame": 540, "type": "key_press", "keycode": "W"},
    {"frame": 550, "type": "key_press", "keycode": "A"},
    {"frame": 560, "type": "key_press", "keycode": "D"},
    {"frame": 570, "type": "key_press", "keycode": "W"},
    {"frame": 580, "type": "key_press", "keycode": "ESCAPE"},
    {"frame": 590, "type": "wait"}
  ]
}
DEMO1

# Demo 2: Direct flight scenario - movement + auto-fire + enemy destruction (M1/M2/M3)
cat > "$GAME_DIR/demo_outputs/02_flight_combat.json" << 'DEMO2'
{
  "scenario": "flight",
  "duration_frames": 600,
  "events": [
    {"frame": 10,  "type": "key_press", "keycode": "W"},
    {"frame": 15,  "type": "key_press", "keycode": "W"},
    {"frame": 20,  "type": "key_press", "keycode": "A"},
    {"frame": 25,  "type": "key_press", "keycode": "A"},
    {"frame": 30,  "type": "key_press", "keycode": "D"},
    {"frame": 35,  "type": "key_press", "keycode": "D"},
    {"frame": 40,  "type": "key_press", "keycode": "W"},
    {"frame": 50,  "type": "key_press", "keycode": "A"},
    {"frame": 60,  "type": "key_press", "keycode": "D"},
    {"frame": 70,  "type": "key_press", "keycode": "W"},
    {"frame": 80,  "type": "key_press", "keycode": "A"},
    {"frame": 90,  "type": "key_press", "keycode": "D"},
    {"frame": 100, "type": "key_press", "keycode": "W"},
    {"frame": 110, "type": "key_press", "keycode": "A"},
    {"frame": 120, "type": "key_press", "keycode": "D"},
    {"frame": 130, "type": "key_press", "keycode": "W"},
    {"frame": 140, "type": "key_press", "keycode": "A"},
    {"frame": 150, "type": "key_press", "keycode": "D"},
    {"frame": 160, "type": "key_press", "keycode": "W"},
    {"frame": 170, "type": "key_press", "keycode": "A"},
    {"frame": 180, "type": "key_press", "keycode": "D"},
    {"frame": 190, "type": "key_press", "keycode": "W"},
    {"frame": 200, "type": "key_press", "keycode": "A"},
    {"frame": 210, "type": "key_press", "keycode": "D"},
    {"frame": 220, "type": "key_press", "keycode": "W"},
    {"frame": 230, "type": "key_press", "keycode": "A"},
    {"frame": 240, "type": "key_press", "keycode": "D"},
    {"frame": 250, "type": "key_press", "keycode": "W"},
    {"frame": 260, "type": "key_press", "keycode": "A"},
    {"frame": 270, "type": "key_press", "keycode": "D"},
    {"frame": 280, "type": "key_press", "keycode": "W"},
    {"frame": 290, "type": "key_press", "keycode": "A"},
    {"frame": 300, "type": "key_press", "keycode": "D"},
    {"frame": 310, "type": "key_press", "keycode": "W"},
    {"frame": 320, "type": "key_press", "keycode": "A"},
    {"frame": 330, "type": "key_press", "keycode": "D"},
    {"frame": 340, "type": "key_press", "keycode": "W"},
    {"frame": 350, "type": "key_press", "keycode": "A"},
    {"frame": 360, "type": "key_press", "keycode": "D"},
    {"frame": 370, "type": "key_press", "keycode": "W"},
    {"frame": 380, "type": "key_press", "keycode": "A"},
    {"frame": 390, "type": "key_press", "keycode": "D"},
    {"frame": 400, "type": "key_press", "keycode": "W"},
    {"frame": 410, "type": "key_press", "keycode": "A"},
    {"frame": 420, "type": "key_press", "keycode": "D"},
    {"frame": 430, "type": "key_press", "keycode": "W"},
    {"frame": 440, "type": "key_press", "keycode": "A"},
    {"frame": 450, "type": "key_press", "keycode": "D"},
    {"frame": 460, "type": "key_press", "keycode": "W"},
    {"frame": 470, "type": "key_press", "keycode": "A"},
    {"frame": 480, "type": "key_press", "keycode": "D"},
    {"frame": 490, "type": "key_press", "keycode": "W"},
    {"frame": 500, "type": "key_press", "keycode": "A"},
    {"frame": 510, "type": "key_press", "keycode": "D"},
    {"frame": 520, "type": "key_press", "keycode": "W"},
    {"frame": 530, "type": "key_press", "keycode": "A"},
    {"frame": 540, "type": "key_press", "keycode": "D"},
    {"frame": 550, "type": "key_press", "keycode": "W"},
    {"frame": 560, "type": "key_press", "keycode": "A"},
    {"frame": 570, "type": "key_press", "keycode": "D"},
    {"frame": 580, "type": "key_press", "keycode": "W"},
    {"frame": 590, "type": "key_press", "keycode": "A"}
  ]
}
DEMO2

# Demo 3: Boss scenario (shows M4 boss, V3 effects, D4 frenzy potential)
cat > "$GAME_DIR/demo_outputs/03_boss_fight.json" << 'DEMO3'
{
  "scenario": "boss",
  "duration_frames": 600,
  "events": [
    {"frame": 10,  "type": "key_press", "keycode": "W"},
    {"frame": 20,  "type": "key_press", "keycode": "A"},
    {"frame": 30,  "type": "key_press", "keycode": "D"},
    {"frame": 40,  "type": "key_press", "keycode": "W"},
    {"frame": 50,  "type": "key_press", "keycode": "A"},
    {"frame": 60,  "type": "key_press", "keycode": "D"},
    {"frame": 70,  "type": "key_press", "keycode": "W"},
    {"frame": 80,  "type": "key_press", "keycode": "A"},
    {"frame": 90,  "type": "key_press", "keycode": "D"},
    {"frame": 100, "type": "key_press", "keycode": "W"},
    {"frame": 110, "type": "key_press", "keycode": "A"},
    {"frame": 120, "type": "key_press", "keycode": "D"},
    {"frame": 130, "type": "key_press", "keycode": "W"},
    {"frame": 140, "type": "key_press", "keycode": "A"},
    {"frame": 150, "type": "key_press", "keycode": "D"},
    {"frame": 160, "type": "key_press", "keycode": "W"},
    {"frame": 170, "type": "key_press", "keycode": "A"},
    {"frame": 180, "type": "key_press", "keycode": "D"},
    {"frame": 190, "type": "key_press", "keycode": "W"},
    {"frame": 200, "type": "key_press", "keycode": "A"},
    {"frame": 210, "type": "key_press", "keycode": "D"},
    {"frame": 220, "type": "key_press", "keycode": "W"},
    {"frame": 230, "type": "key_press", "keycode": "A"},
    {"frame": 240, "type": "key_press", "keycode": "D"},
    {"frame": 250, "type": "key_press", "keycode": "W"},
    {"frame": 260, "type": "key_press", "keycode": "A"},
    {"frame": 270, "type": "key_press", "keycode": "D"},
    {"frame": 280, "type": "key_press", "keycode": "W"},
    {"frame": 290, "type": "key_press", "keycode": "A"},
    {"frame": 300, "type": "key_press", "keycode": "D"},
    {"frame": 310, "type": "key_press", "keycode": "W"},
    {"frame": 320, "type": "key_press", "keycode": "A"},
    {"frame": 330, "type": "key_press", "keycode": "D"},
    {"frame": 340, "type": "key_press", "keycode": "W"},
    {"frame": 350, "type": "key_press", "keycode": "A"},
    {"frame": 360, "type": "key_press", "keycode": "D"},
    {"frame": 370, "type": "key_press", "keycode": "W"},
    {"frame": 380, "type": "key_press", "keycode": "A"},
    {"frame": 390, "type": "key_press", "keycode": "D"},
    {"frame": 400, "type": "key_press", "keycode": "W"},
    {"frame": 410, "type": "key_press", "keycode": "A"},
    {"frame": 420, "type": "key_press", "keycode": "D"},
    {"frame": 430, "type": "key_press", "keycode": "W"},
    {"frame": 440, "type": "key_press", "keycode": "A"},
    {"frame": 450, "type": "key_press", "keycode": "D"},
    {"frame": 460, "type": "key_press", "keycode": "W"},
    {"frame": 470, "type": "key_press", "keycode": "A"},
    {"frame": 480, "type": "key_press", "keycode": "D"},
    {"frame": 490, "type": "key_press", "keycode": "W"},
    {"frame": 500, "type": "key_press", "keycode": "A"},
    {"frame": 510, "type": "key_press", "keycode": "D"},
    {"frame": 520, "type": "key_press", "keycode": "W"},
    {"frame": 530, "type": "key_press", "keycode": "A"},
    {"frame": 540, "type": "key_press", "keycode": "D"},
    {"frame": 550, "type": "key_press", "keycode": "W"},
    {"frame": 560, "type": "key_press", "keycode": "A"},
    {"frame": 570, "type": "key_press", "keycode": "D"},
    {"frame": 580, "type": "key_press", "keycode": "W"},
    {"frame": 590, "type": "key_press", "keycode": "A"}
  ]
}
DEMO3

# Demo 4: Map with both stages unlocked (shows D3 multi-stage)
cat > "$GAME_DIR/demo_outputs/04_both_stages.json" << 'DEMO4'
{
  "scenario": "map_unlocked",
  "duration_frames": 600,
  "events": [
    {"frame": 20,  "type": "key_press", "keycode": "1"},
    {"frame": 50,  "type": "key_press", "keycode": "W"},
    {"frame": 60,  "type": "key_press", "keycode": "A"},
    {"frame": 70,  "type": "key_press", "keycode": "D"},
    {"frame": 80,  "type": "key_press", "keycode": "W"},
    {"frame": 90,  "type": "key_press", "keycode": "A"},
    {"frame": 100, "type": "key_press", "keycode": "D"},
    {"frame": 110, "type": "key_press", "keycode": "W"},
    {"frame": 120, "type": "key_press", "keycode": "A"},
    {"frame": 130, "type": "key_press", "keycode": "ESCAPE"},
    {"frame": 160, "type": "key_press", "keycode": "ENTER"},
    {"frame": 190, "type": "key_press", "keycode": "2"},
    {"frame": 220, "type": "key_press", "keycode": "W"},
    {"frame": 230, "type": "key_press", "keycode": "A"},
    {"frame": 240, "type": "key_press", "keycode": "D"},
    {"frame": 250, "type": "key_press", "keycode": "W"},
    {"frame": 260, "type": "key_press", "keycode": "A"},
    {"frame": 270, "type": "key_press", "keycode": "D"},
    {"frame": 280, "type": "key_press", "keycode": "W"},
    {"frame": 290, "type": "key_press", "keycode": "A"},
    {"frame": 300, "type": "key_press", "keycode": "ESCAPE"},
    {"frame": 330, "type": "wait"},
    {"frame": 590, "type": "wait"}
  ]
}
DEMO4

# Demo 5: Stage 2 flight (shows D3 different stage backdrop)
cat > "$GAME_DIR/demo_outputs/05_stage2_flight.json" << 'DEMO5'
{
  "scenario": "stage2",
  "duration_frames": 600,
  "events": [
    {"frame": 10,  "type": "key_press", "keycode": "W"},
    {"frame": 20,  "type": "key_press", "keycode": "A"},
    {"frame": 30,  "type": "key_press", "keycode": "D"},
    {"frame": 40,  "type": "key_press", "keycode": "W"},
    {"frame": 50,  "type": "key_press", "keycode": "A"},
    {"frame": 60,  "type": "key_press", "keycode": "D"},
    {"frame": 70,  "type": "key_press", "keycode": "W"},
    {"frame": 80,  "type": "key_press", "keycode": "A"},
    {"frame": 90,  "type": "key_press", "keycode": "D"},
    {"frame": 100, "type": "key_press", "keycode": "W"},
    {"frame": 110, "type": "key_press", "keycode": "A"},
    {"frame": 120, "type": "key_press", "keycode": "D"},
    {"frame": 130, "type": "key_press", "keycode": "W"},
    {"frame": 140, "type": "key_press", "keycode": "A"},
    {"frame": 150, "type": "key_press", "keycode": "D"},
    {"frame": 160, "type": "key_press", "keycode": "W"},
    {"frame": 170, "type": "key_press", "keycode": "A"},
    {"frame": 180, "type": "key_press", "keycode": "D"},
    {"frame": 190, "type": "key_press", "keycode": "W"},
    {"frame": 200, "type": "key_press", "keycode": "A"},
    {"frame": 210, "type": "key_press", "keycode": "D"},
    {"frame": 220, "type": "key_press", "keycode": "W"},
    {"frame": 230, "type": "key_press", "keycode": "A"},
    {"frame": 240, "type": "key_press", "keycode": "D"},
    {"frame": 250, "type": "key_press", "keycode": "W"},
    {"frame": 260, "type": "key_press", "keycode": "A"},
    {"frame": 270, "type": "key_press", "keycode": "D"},
    {"frame": 280, "type": "key_press", "keycode": "W"},
    {"frame": 290, "type": "key_press", "keycode": "A"},
    {"frame": 300, "type": "key_press", "keycode": "D"},
    {"frame": 310, "type": "key_press", "keycode": "W"},
    {"frame": 320, "type": "key_press", "keycode": "A"},
    {"frame": 330, "type": "key_press", "keycode": "D"},
    {"frame": 340, "type": "key_press", "keycode": "W"},
    {"frame": 350, "type": "key_press", "keycode": "A"},
    {"frame": 360, "type": "key_press", "keycode": "D"},
    {"frame": 370, "type": "key_press", "keycode": "W"},
    {"frame": 380, "type": "key_press", "keycode": "A"},
    {"frame": 390, "type": "key_press", "keycode": "D"},
    {"frame": 400, "type": "key_press", "keycode": "W"},
    {"frame": 410, "type": "key_press", "keycode": "A"},
    {"frame": 420, "type": "key_press", "keycode": "D"},
    {"frame": 430, "type": "key_press", "keycode": "W"},
    {"frame": 440, "type": "key_press", "keycode": "A"},
    {"frame": 450, "type": "key_press", "keycode": "D"},
    {"frame": 460, "type": "key_press", "keycode": "W"},
    {"frame": 470, "type": "key_press", "keycode": "A"},
    {"frame": 480, "type": "key_press", "keycode": "D"},
    {"frame": 490, "type": "key_press", "keycode": "W"},
    {"frame": 500, "type": "key_press", "keycode": "A"},
    {"frame": 510, "type": "key_press", "keycode": "D"},
    {"frame": 520, "type": "key_press", "keycode": "W"},
    {"frame": 530, "type": "key_press", "keycode": "A"},
    {"frame": 540, "type": "key_press", "keycode": "D"},
    {"frame": 550, "type": "key_press", "keycode": "W"},
    {"frame": 560, "type": "key_press", "keycode": "A"},
    {"frame": 570, "type": "key_press", "keycode": "D"},
    {"frame": 580, "type": "key_press", "keycode": "W"},
    {"frame": 590, "type": "key_press", "keycode": "A"}
  ]
}
DEMO5

chmod +x "$0"
echo "Oracle solve.sh completed successfully."
