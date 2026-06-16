#!/usr/bin/env bash
# Oracle reference implementation for platformer-iron-vanguard.
# Top-down grid-based tactical tank shooter with base defense.
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
config/name="Iron Vanguard"
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
fire={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":32,"location":0,"echo":false,"script":null)]
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

enum GS { TITLE, MAP, BATTLE, VICTORY, DEFEAT }
var state: int = GS.TITLE

# Grid config
const CELL := 48
const COLS := 26
const ROWS := 15
const GRID_OFFSET := Vector2(16, 0)

# Player
var player_grid := Vector2i(13, 13)
var player_dir := Vector2i(0, -1)
var player_armor := 3
var player_lives := 3
var player_shell: Dictionary = {}
var player_move_cd := 0.0
const MOVE_DELAY := 0.15
const MUD_PENALTY := 2.5

# Enemies
var enemies: Array = []
var enemy_shells: Array = []
var wave_queue: Array = []
var enemies_spawned := 0
var enemies_killed := 0
var total_enemies := 20
var spawn_timer := 0.0
const SPAWN_INTERVAL := 1.5
var shots_fired := 0
var shots_hit := 0

# Map data: 0=empty, 1=brick, 2=steel, 3=mud, 9=core
var grid: Array = []
var current_zone := 0
var zones_unlocked := [true, false, false]

# Power-ups
var powerups: Array = []

# Visual nodes
var grid_container: Node2D
var hud_layer: CanvasLayer
var ui_layer: CanvasLayer

# Zone maps (predefined layouts)
var zone_maps := []

func _ready() -> void:
    _init_zone_maps()
    var args := OS.get_cmdline_user_args()
    var scenario := ""
    for i in range(args.size()):
        if String(args[i]) == "--scenario" and i + 1 < args.size():
            scenario = String(args[i + 1])

    match scenario:
        "battle":
            current_zone = 0
            _enter_battle()
        "near_victory":
            current_zone = 0
            _enter_battle_scenario_near_victory()
        "core_destroy":
            current_zone = 0
            _enter_battle_scenario_core_destroy()
        "zone2":
            current_zone = 1
            zones_unlocked[1] = true
            _enter_battle()
        "map_unlocked":
            zones_unlocked = [true, true, true]
            _enter_map()
        _:
            _enter_title()

func _init_zone_maps() -> void:
    # Zone 0: The Outpost - simple layout
    var z0: Array = []
    for r in range(ROWS):
        var row: Array = []
        for c in range(COLS):
            row.append(0)
        z0.append(row)
    # Brick barricades
    for c in range(8, 18):
        z0[5][c] = 1
        z0[9][c] = 1
    # Steel walls
    z0[7][4] = 2; z0[7][5] = 2; z0[7][20] = 2; z0[7][21] = 2
    # Mud patches
    for c in range(11, 15):
        z0[11][c] = 3
    # Core position
    z0[13][13] = 9
    zone_maps.append(z0)

    # Zone 1: The Fuel Depot - more complex
    var z1: Array = []
    for r in range(ROWS):
        var row: Array = []
        for c in range(COLS):
            row.append(0)
        z1.append(row)
    for c in range(3, 23):
        z1[4][c] = 1
    for c in range(6, 20):
        z1[8][c] = 1
    z1[6][6] = 2; z1[6][7] = 2; z1[6][18] = 2; z1[6][19] = 2
    z1[10][10] = 2; z1[10][11] = 2; z1[10][14] = 2; z1[10][15] = 2
    for c in range(9, 17):
        z1[12][c] = 3
    z1[13][13] = 9
    zone_maps.append(z1)

    # Zone 2: The Central Core - hardest
    var z2: Array = []
    for r in range(ROWS):
        var row: Array = []
        for c in range(COLS):
            row.append(0)
        z2.append(row)
    for c in range(5, 21):
        z2[3][c] = 1
        z2[6][c] = 1
        z2[10][c] = 1
    z2[5][3] = 2; z2[5][4] = 2; z2[5][21] = 2; z2[5][22] = 2
    z2[8][8] = 2; z2[8][9] = 2; z2[8][16] = 2; z2[8][17] = 2
    for c in range(10, 16):
        z2[12][c] = 3
    z2[13][13] = 9
    zone_maps.append(z2)

# ── State transitions ────────────────────────────────────────────────────────

func _enter_title() -> void:
    state = GS.TITLE
    _clear_all()
    _draw_title()

func _enter_map() -> void:
    state = GS.MAP
    _clear_all()
    _draw_map()

func _enter_battle() -> void:
    state = GS.BATTLE
    _clear_all()
    _init_battle()
    _draw_battlefield()

func _enter_battle_scenario_near_victory() -> void:
    state = GS.BATTLE
    _clear_all()
    _init_battle()
    enemies_killed = 19
    total_enemies = 20
    wave_queue.clear()
    # Spawn one weak enemy directly above player in same column
    enemies.append({"grid": Vector2i(12, 5), "dir": Vector2i(0, 1), "hp": 1, "type": "scout", "move_cd": 2.0, "fire_cd": 5.0, "node": null})
    _draw_battlefield()

func _enter_battle_scenario_core_destroy() -> void:
    state = GS.BATTLE
    _clear_all()
    _init_battle()
    wave_queue.clear()
    # Spawn enemy aimed directly at core
    enemies.append({"grid": Vector2i(13, 11), "dir": Vector2i(0, 1), "hp": 1, "type": "scout", "move_cd": 0.0, "fire_cd": 0.0, "node": null})
    player_grid = Vector2i(3, 13)
    _draw_battlefield()

func _enter_victory() -> void:
    state = GS.VICTORY
    if current_zone < 2:
        zones_unlocked[current_zone + 1] = true
    _save_progress()
    _clear_all()
    _draw_victory()

func _enter_defeat() -> void:
    state = GS.DEFEAT
    _clear_all()
    _draw_defeat()

# ── Battle init ──────────────────────────────────────────────────────────────

func _init_battle() -> void:
    grid = []
    var src: Array = zone_maps[current_zone]
    for r in range(ROWS):
        var row: Array = []
        for c in range(COLS):
            row.append(src[r][c])
        grid.append(row)
    player_grid = Vector2i(12, 13)
    player_dir = Vector2i(0, -1)
    player_armor = 3
    player_shell = {}
    enemies.clear()
    enemy_shells.clear()
    powerups.clear()
    enemies_spawned = 0
    enemies_killed = 0
    shots_fired = 0
    shots_hit = 0
    spawn_timer = 0.0
    _build_wave_queue()

func _build_wave_queue() -> void:
    wave_queue.clear()
    for i in range(total_enemies):
        var etype := "scout"
        if i % 7 == 6:
            etype = "carrier"
        elif i % 4 == 3:
            etype = "heavy"
        var spawn_col: int = (hash(i * 37) % 20) + 3
        wave_queue.append({"type": etype, "col": spawn_col})

# ── Input handling ───────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.pressed and not event.echo):
        return
    var kc: int = event.keycode if event.keycode != 0 else event.physical_keycode

    match state:
        GS.TITLE:
            if kc == KEY_ENTER or kc == KEY_SPACE:
                _enter_map()
        GS.MAP:
            if kc == KEY_1:
                current_zone = 0; _enter_battle()
            elif kc == KEY_2 and zones_unlocked[1]:
                current_zone = 1; _enter_battle()
            elif kc == KEY_3 and zones_unlocked[2]:
                current_zone = 2; _enter_battle()
            elif kc == KEY_ESCAPE:
                _enter_title()
        GS.BATTLE:
            if kc == KEY_SPACE:
                _fire_shell()
            elif kc == KEY_ESCAPE:
                _enter_map()
        GS.VICTORY, GS.DEFEAT:
            if kc == KEY_ENTER or kc == KEY_SPACE:
                _enter_map()
            elif kc == KEY_ESCAPE:
                _enter_title()

# ── Process ──────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
    if state != GS.BATTLE:
        return

    player_move_cd -= delta
    if player_move_cd <= 0.0:
        var moved := false
        if Input.is_action_pressed("move_up"):
            player_dir = Vector2i(0, -1); moved = _try_move(player_grid + player_dir)
        elif Input.is_action_pressed("move_down"):
            player_dir = Vector2i(0, 1); moved = _try_move(player_grid + player_dir)
        elif Input.is_action_pressed("move_left"):
            player_dir = Vector2i(-1, 0); moved = _try_move(player_grid + player_dir)
        elif Input.is_action_pressed("move_right"):
            player_dir = Vector2i(1, 0); moved = _try_move(player_grid + player_dir)
        if moved:
            var cell_type: int = grid[player_grid.y][player_grid.x]
            player_move_cd = MOVE_DELAY * (MUD_PENALTY if cell_type == 3 else 1.0)
            _check_powerup_pickup()

    _update_player_shell(delta)
    _update_spawner(delta)
    _update_enemies(delta)
    _update_enemy_shells(delta)

    if enemies_killed >= total_enemies and enemies.size() == 0 and wave_queue.size() == 0:
        _enter_victory()

    _draw_battlefield()

# ── Movement helpers ─────────────────────────────────────────────────────────

func _try_move(target: Vector2i) -> bool:
    if target.x < 0 or target.x >= COLS or target.y < 0 or target.y >= ROWS:
        return false
    var cell: int = grid[target.y][target.x]
    if cell == 2 or cell == 9:
        return false
    if cell == 1:
        return false
    for e in enemies:
        if e.grid == target:
            return false
    player_grid = target
    return true

func _is_walkable_enemy(pos: Vector2i) -> bool:
    if pos.x < 0 or pos.x >= COLS or pos.y < 0 or pos.y >= ROWS:
        return false
    var cell: int = grid[pos.y][pos.x]
    return cell == 0 or cell == 3

# ── Firing ───────────────────────────────────────────────────────────────────

func _fire_shell() -> void:
    if player_shell.size() > 0:
        return
    shots_fired += 1
    player_shell = {"pos": Vector2(player_grid) + Vector2(player_dir) * 0.5, "dir": Vector2(player_dir), "speed": 8.0}

func _update_player_shell(delta: float) -> void:
    if player_shell.size() == 0:
        return
    player_shell.pos += player_shell.dir * player_shell.speed * delta
    var gx: int = int(round(player_shell.pos.x))
    var gy: int = int(round(player_shell.pos.y))
    if gx < 0 or gx >= COLS or gy < 0 or gy >= ROWS:
        player_shell = {}
        return
    var cell: int = grid[gy][gx]
    if cell == 2:
        player_shell = {}
        return
    if cell == 1:
        grid[gy][gx] = 0
        player_shell = {}
        return
    for i in range(enemies.size() - 1, -1, -1):
        if enemies[i].grid == Vector2i(gx, gy):
            enemies[i].hp -= 1
            shots_hit += 1
            if enemies[i].hp <= 0:
                _on_enemy_killed(enemies[i])
                enemies.remove_at(i)
                enemies_killed += 1
            player_shell = {}
            return

func _on_enemy_killed(enemy: Dictionary) -> void:
    if enemy.type == "carrier":
        var ptype: String = ["repair", "shield", "emp"][randi() % 3]
        powerups.append({"grid": enemy.grid, "type": ptype})

# ── Enemy spawning ───────────────────────────────────────────────────────────

func _update_spawner(delta: float) -> void:
    if wave_queue.size() == 0:
        return
    spawn_timer += delta
    if spawn_timer >= SPAWN_INTERVAL:
        spawn_timer = 0.0
        var info: Dictionary = wave_queue.pop_front()
        var hp := 1
        if info.type == "heavy":
            hp = 3
        elif info.type == "carrier":
            hp = 2
        var spawn_pos := Vector2i(info.col, 0)
        if not _is_walkable_enemy(spawn_pos):
            spawn_pos = Vector2i(13, 0)
        enemies.append({"grid": spawn_pos, "dir": Vector2i(0, 1), "hp": hp, "type": info.type, "move_cd": 0.0, "fire_cd": 0.0, "node": null})
        enemies_spawned += 1

# ── Enemy AI ─────────────────────────────────────────────────────────────────

func _update_enemies(delta: float) -> void:
    var core_pos := Vector2i(13, 13)
    for e in enemies:
        e.move_cd -= delta
        e.fire_cd -= delta
        # Movement
        if e.move_cd <= 0.0:
            var speed_delay := 0.4
            if e.type == "scout":
                speed_delay = 0.25
            elif e.type == "heavy":
                speed_delay = 0.6
            e.move_cd = speed_delay
            var target: Vector2i = core_pos
            if player_grid.y < e.grid.y + 3 and absf(player_grid.x - e.grid.x) < 4:
                target = player_grid
            var best_dir := Vector2i(0, 1)
            var best_dist := 9999.0
            for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
                var np: Vector2i = e.grid + d
                if _is_walkable_enemy(np) and np != player_grid:
                    var occupied := false
                    for other in enemies:
                        if other != e and other.grid == np:
                            occupied = true
                            break
                    if not occupied:
                        var dist: float = Vector2(np).distance_to(Vector2(target))
                        if dist < best_dist:
                            best_dist = dist
                            best_dir = d
            var next_pos: Vector2i = e.grid + best_dir
            if _is_walkable_enemy(next_pos) and next_pos != player_grid:
                var occupied := false
                for other in enemies:
                    if other != e and other.grid == next_pos:
                        occupied = true
                        break
                if not occupied:
                    e.grid = next_pos
                    e.dir = best_dir
        # Firing
        if e.fire_cd <= 0.0:
            e.fire_cd = 2.0 if e.type == "heavy" else 3.0
            enemy_shells.append({"pos": Vector2(e.grid) + Vector2(e.dir) * 0.5, "dir": Vector2(e.dir), "speed": 8.0})

func _update_enemy_shells(delta: float) -> void:
    var to_remove: Array = []
    for i in range(enemy_shells.size()):
        var s: Dictionary = enemy_shells[i]
        s.pos += s.dir * s.speed * delta
        var gx: int = int(round(s.pos.x))
        var gy: int = int(round(s.pos.y))
        if gx < 0 or gx >= COLS or gy < 0 or gy >= ROWS:
            to_remove.append(i)
            continue
        var cell: int = grid[gy][gx]
        if cell == 2:
            to_remove.append(i)
            continue
        if cell == 1:
            grid[gy][gx] = 0
            to_remove.append(i)
            continue
        if cell == 9:
            _enter_defeat()
            return
        if Vector2i(gx, gy) == player_grid:
            player_armor -= 1
            to_remove.append(i)
            if player_armor <= 0:
                player_lives -= 1
                if player_lives <= 0:
                    _enter_defeat()
                    return
                player_armor = 3
                player_grid = Vector2i(12, 13)
    to_remove.reverse()
    for idx in to_remove:
        enemy_shells.remove_at(idx)

# ── Power-ups ────────────────────────────────────────────────────────────────

func _check_powerup_pickup() -> void:
    for i in range(powerups.size() - 1, -1, -1):
        if powerups[i].grid == player_grid:
            var ptype: String = powerups[i].type
            match ptype:
                "repair":
                    player_armor = mini(player_armor + 2, 5)
                "shield":
                    # Place steel around core temporarily (just set bricks)
                    for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
                        var bp: Vector2i = Vector2i(13, 13) + d
                        if grid[bp.y][bp.x] == 0:
                            grid[bp.y][bp.x] = 1
                "emp":
                    for e in enemies:
                        e.move_cd = 3.0
                        e.fire_cd = 3.0
            powerups.remove_at(i)

# ── Save/Load ────────────────────────────────────────────────────────────────

const SAVE_PATH := "user://iron_vanguard_save.cfg"

func _save_progress() -> void:
    var cfg := ConfigFile.new()
    for i in range(zones_unlocked.size()):
        cfg.set_value("progress", "zone_%d" % i, zones_unlocked[i])
    cfg.save(SAVE_PATH)

func _load_progress() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) == OK:
        for i in range(zones_unlocked.size()):
            zones_unlocked[i] = cfg.get_value("progress", "zone_%d" % i, i == 0)

# ── Drawing ──────────────────────────────────────────────────────────────────

func _clear_all() -> void:
    for child in get_children():
        child.queue_free()

func _draw_title() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.05, 0.05, 0.08, 1.0)
    bg.position = Vector2.ZERO
    bg.size = Vector2(1280, 720)
    add_child(bg)

    var title := Label.new()
    title.text = "IRON VANGUARD"
    title.add_theme_font_size_override("font_size", 64)
    title.add_theme_color_override("font_color", Color(0.9, 0.4, 0.1))
    title.position = Vector2(380, 200)
    add_child(title)

    var sub := Label.new()
    sub.text = "Defend the Core. Survive the Onslaught."
    sub.add_theme_font_size_override("font_size", 22)
    sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
    sub.position = Vector2(400, 300)
    add_child(sub)

    var prompt := Label.new()
    prompt.text = "[ENTER / SPACE] to Deploy"
    prompt.add_theme_font_size_override("font_size", 18)
    prompt.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
    prompt.position = Vector2(480, 500)
    add_child(prompt)

func _draw_map() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.06, 0.06, 0.1, 1.0)
    bg.position = Vector2.ZERO
    bg.size = Vector2(1280, 720)
    add_child(bg)

    var header := Label.new()
    header.text = "TACTICAL MAP"
    header.add_theme_font_size_override("font_size", 40)
    header.add_theme_color_override("font_color", Color(0.9, 0.5, 0.1))
    header.position = Vector2(480, 40)
    add_child(header)

    var zone_names := ["1: The Outpost", "2: The Fuel Depot", "3: The Central Core"]
    var zone_enemies := [20, 20, 20]
    for i in range(3):
        var panel := ColorRect.new()
        panel.size = Vector2(300, 140)
        panel.position = Vector2(100 + i * 380, 250)
        panel.color = Color(0.15, 0.2, 0.15, 1.0) if zones_unlocked[i] else Color(0.1, 0.1, 0.1, 0.6)
        add_child(panel)

        var lbl := Label.new()
        lbl.text = zone_names[i]
        lbl.add_theme_font_size_override("font_size", 20)
        lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 0.3) if zones_unlocked[i] else Color(0.4, 0.4, 0.4))
        lbl.position = Vector2(110 + i * 380, 260)
        add_child(lbl)

        var info := Label.new()
        info.text = "Enemies: %d\nStatus: %s" % [zone_enemies[i], "UNLOCKED" if zones_unlocked[i] else "LOCKED"]
        info.add_theme_font_size_override("font_size", 16)
        info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
        info.position = Vector2(110 + i * 380, 310)
        add_child(info)

    var hint := Label.new()
    hint.text = "Press [1] [2] [3] to select zone  |  [ESC] back"
    hint.add_theme_font_size_override("font_size", 16)
    hint.add_theme_color_override("font_color", Color(0.4, 0.7, 0.4))
    hint.position = Vector2(380, 600)
    add_child(hint)

func _draw_battlefield() -> void:
    _clear_all()
    # Background
    var bg := ColorRect.new()
    bg.color = Color(0.04, 0.04, 0.06, 1.0)
    bg.position = Vector2.ZERO
    bg.size = Vector2(1280, 720)
    add_child(bg)

    # Grid cells
    for r in range(ROWS):
        for c in range(COLS):
            var cell: int = grid[r][c]
            if cell == 0:
                continue
            var rect := ColorRect.new()
            rect.position = GRID_OFFSET + Vector2(c * CELL, r * CELL)
            rect.size = Vector2(CELL - 1, CELL - 1)
            match cell:
                1: rect.color = Color(0.5, 0.25, 0.1, 1.0)  # brick
                2: rect.color = Color(0.4, 0.4, 0.45, 1.0)   # steel
                3: rect.color = Color(0.2, 0.15, 0.05, 0.5)   # mud
                9: rect.color = Color(0.1, 0.8, 0.9, 1.0)     # core
            add_child(rect)

    # Power-ups
    for p in powerups:
        var pr := ColorRect.new()
        pr.position = GRID_OFFSET + Vector2(p.grid.x * CELL + 12, p.grid.y * CELL + 12)
        pr.size = Vector2(24, 24)
        match p.type:
            "repair": pr.color = Color(0.2, 0.9, 0.2, 1.0)
            "shield": pr.color = Color(0.2, 0.5, 0.9, 1.0)
            "emp": pr.color = Color(0.9, 0.9, 0.2, 1.0)
        add_child(pr)

    # Player tank
    var player_rect := ColorRect.new()
    player_rect.position = GRID_OFFSET + Vector2(player_grid.x * CELL + 4, player_grid.y * CELL + 4)
    player_rect.size = Vector2(CELL - 8, CELL - 8)
    player_rect.color = Color(0.2, 0.7, 0.2, 1.0)
    add_child(player_rect)

    # Player turret direction indicator
    var turret := ColorRect.new()
    var tp: Vector2 = GRID_OFFSET + Vector2(player_grid.x * CELL + CELL / 2 - 4, player_grid.y * CELL + CELL / 2 - 4)
    tp += Vector2(player_dir.x * 14, player_dir.y * 14)
    turret.position = tp
    turret.size = Vector2(8, 8)
    turret.color = Color(0.5, 1.0, 0.5, 1.0)
    add_child(turret)

    # Enemies
    for e in enemies:
        var er := ColorRect.new()
        er.position = GRID_OFFSET + Vector2(e.grid.x * CELL + 4, e.grid.y * CELL + 4)
        er.size = Vector2(CELL - 8, CELL - 8)
        match e.type:
            "scout": er.color = Color(0.8, 0.2, 0.2, 1.0)
            "heavy": er.color = Color(0.6, 0.1, 0.1, 1.0)
            "carrier": er.color = Color(0.8, 0.6, 0.1, 1.0)
        add_child(er)

    # Player shell
    if player_shell.size() > 0:
        var sr := ColorRect.new()
        sr.position = GRID_OFFSET + Vector2(player_shell.pos.x * CELL + CELL / 2 - 4, player_shell.pos.y * CELL + CELL / 2 - 4)
        sr.size = Vector2(8, 8)
        sr.color = Color(1.0, 1.0, 0.3, 1.0)
        add_child(sr)

    # Enemy shells
    for s in enemy_shells:
        var esr := ColorRect.new()
        esr.position = GRID_OFFSET + Vector2(s.pos.x * CELL + CELL / 2 - 3, s.pos.y * CELL + CELL / 2 - 3)
        esr.size = Vector2(6, 6)
        esr.color = Color(1.0, 0.3, 0.3, 1.0)
        add_child(esr)

    # HUD
    _draw_hud()

func _draw_hud() -> void:
    var hud_bg := ColorRect.new()
    hud_bg.position = Vector2(0, 0)
    hud_bg.size = Vector2(1280, 32)
    hud_bg.color = Color(0.02, 0.02, 0.04, 0.9)
    add_child(hud_bg)

    var zone_names := ["The Outpost", "The Fuel Depot", "The Central Core"]
    var zone_lbl := Label.new()
    zone_lbl.text = "ZONE: %s" % zone_names[current_zone]
    zone_lbl.add_theme_font_size_override("font_size", 14)
    zone_lbl.add_theme_color_override("font_color", Color(0.9, 0.6, 0.1))
    zone_lbl.position = Vector2(10, 6)
    add_child(zone_lbl)

    var armor_lbl := Label.new()
    armor_lbl.text = "ARMOR: %d" % player_armor
    armor_lbl.add_theme_font_size_override("font_size", 14)
    armor_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
    armor_lbl.position = Vector2(300, 6)
    add_child(armor_lbl)

    var lives_lbl := Label.new()
    lives_lbl.text = "LIVES: %d" % player_lives
    lives_lbl.add_theme_font_size_override("font_size", 14)
    lives_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
    lives_lbl.position = Vector2(450, 6)
    add_child(lives_lbl)

    var remaining := total_enemies - enemies_killed
    var enemy_lbl := Label.new()
    enemy_lbl.text = "ENEMIES: %d/%d" % [remaining, total_enemies]
    enemy_lbl.add_theme_font_size_override("font_size", 14)
    enemy_lbl.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
    enemy_lbl.position = Vector2(600, 6)
    add_child(enemy_lbl)

    var core_lbl := Label.new()
    core_lbl.text = "CORE: ACTIVE"
    core_lbl.add_theme_font_size_override("font_size", 14)
    core_lbl.add_theme_color_override("font_color", Color(0.1, 0.8, 0.9))
    core_lbl.position = Vector2(800, 6)
    add_child(core_lbl)

func _draw_victory() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.02, 0.08, 0.02, 1.0)
    bg.position = Vector2.ZERO
    bg.size = Vector2(1280, 720)
    add_child(bg)

    var title := Label.new()
    title.text = "ZONE CLEARED"
    title.add_theme_font_size_override("font_size", 48)
    title.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
    title.position = Vector2(440, 180)
    add_child(title)

    var accuracy := 0.0
    if shots_fired > 0:
        accuracy = float(shots_hit) / float(shots_fired) * 100.0
    var stats := Label.new()
    stats.text = "Shots Fired: %d\nShots Hit: %d\nAccuracy: %.1f%%\nLives Remaining: %d" % [shots_fired, shots_hit, accuracy, player_lives]
    stats.add_theme_font_size_override("font_size", 22)
    stats.add_theme_color_override("font_color", Color(0.7, 0.8, 0.6))
    stats.position = Vector2(460, 300)
    add_child(stats)

    var prompt := Label.new()
    prompt.text = "[ENTER] Return to Tactical Map"
    prompt.add_theme_font_size_override("font_size", 18)
    prompt.add_theme_color_override("font_color", Color(0.4, 0.7, 0.4))
    prompt.position = Vector2(460, 520)
    add_child(prompt)

func _draw_defeat() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.08, 0.02, 0.02, 1.0)
    bg.position = Vector2.ZERO
    bg.size = Vector2(1280, 720)
    add_child(bg)

    var title := Label.new()
    title.text = "MISSION FAILED"
    title.add_theme_font_size_override("font_size", 48)
    title.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
    title.position = Vector2(430, 250)
    add_child(title)

    var sub := Label.new()
    sub.text = "The Command Core has been compromised."
    sub.add_theme_font_size_override("font_size", 20)
    sub.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
    sub.position = Vector2(410, 350)
    add_child(sub)

    var prompt := Label.new()
    prompt.text = "[ENTER] Return to Tactical Map  |  [ESC] Title"
    prompt.add_theme_font_size_override("font_size", 18)
    prompt.add_theme_color_override("font_color", Color(0.7, 0.4, 0.4))
    prompt.position = Vector2(380, 500)
    add_child(prompt)
GDSCRIPT

###############################################################################
# Demo traces
###############################################################################

# Demo 1: Title → Map → Zone 1 battle (shows M1 movement+firing, M2 waves, V1/V2 HUD)
cat > "$GAME_DIR/demo_outputs/01_battle_flow.json" << 'DEMO1'
{
  "duration_frames": 600,
  "events": [
    {"frame": 30,  "type": "key_press", "keycode": "ENTER"},
    {"frame": 60,  "type": "key_press", "keycode": "1"},
    {"frame": 90,  "type": "key_press", "keycode": "W"},
    {"frame": 95,  "type": "key_press", "keycode": "W"},
    {"frame": 100, "type": "key_press", "keycode": "W"},
    {"frame": 105, "type": "key_press", "keycode": "W"},
    {"frame": 110, "type": "key_press", "keycode": "W"},
    {"frame": 115, "type": "key_press", "keycode": "SPACE"},
    {"frame": 135, "type": "key_press", "keycode": "SPACE"},
    {"frame": 155, "type": "key_press", "keycode": "A"},
    {"frame": 160, "type": "key_press", "keycode": "A"},
    {"frame": 165, "type": "key_press", "keycode": "SPACE"},
    {"frame": 185, "type": "key_press", "keycode": "D"},
    {"frame": 190, "type": "key_press", "keycode": "D"},
    {"frame": 195, "type": "key_press", "keycode": "D"},
    {"frame": 200, "type": "key_press", "keycode": "SPACE"},
    {"frame": 220, "type": "key_press", "keycode": "W"},
    {"frame": 225, "type": "key_press", "keycode": "W"},
    {"frame": 230, "type": "key_press", "keycode": "SPACE"},
    {"frame": 250, "type": "key_press", "keycode": "S"},
    {"frame": 255, "type": "key_press", "keycode": "S"},
    {"frame": 260, "type": "key_press", "keycode": "SPACE"},
    {"frame": 280, "type": "key_press", "keycode": "W"},
    {"frame": 285, "type": "key_press", "keycode": "SPACE"},
    {"frame": 305, "type": "key_press", "keycode": "A"},
    {"frame": 310, "type": "key_press", "keycode": "SPACE"},
    {"frame": 330, "type": "key_press", "keycode": "D"},
    {"frame": 335, "type": "key_press", "keycode": "SPACE"},
    {"frame": 355, "type": "key_press", "keycode": "W"},
    {"frame": 360, "type": "key_press", "keycode": "SPACE"},
    {"frame": 380, "type": "key_press", "keycode": "W"},
    {"frame": 385, "type": "key_press", "keycode": "SPACE"},
    {"frame": 405, "type": "key_press", "keycode": "A"},
    {"frame": 410, "type": "key_press", "keycode": "SPACE"},
    {"frame": 430, "type": "key_press", "keycode": "W"},
    {"frame": 435, "type": "key_press", "keycode": "SPACE"},
    {"frame": 455, "type": "key_press", "keycode": "D"},
    {"frame": 460, "type": "key_press", "keycode": "SPACE"},
    {"frame": 480, "type": "key_press", "keycode": "W"},
    {"frame": 485, "type": "key_press", "keycode": "SPACE"},
    {"frame": 505, "type": "key_press", "keycode": "A"},
    {"frame": 510, "type": "key_press", "keycode": "SPACE"},
    {"frame": 530, "type": "key_press", "keycode": "W"},
    {"frame": 535, "type": "key_press", "keycode": "SPACE"},
    {"frame": 555, "type": "key_press", "keycode": "D"},
    {"frame": 560, "type": "key_press", "keycode": "SPACE"},
    {"frame": 580, "type": "key_press", "keycode": "W"},
    {"frame": 585, "type": "key_press", "keycode": "SPACE"}
  ]
}
DEMO1

# Demo 2: Near victory - kill last enemy, show victory screen (M3 collision, M4 victory)
cat > "$GAME_DIR/demo_outputs/02_near_victory.json" << 'DEMO2'
{
  "scenario": "near_victory",
  "duration_frames": 400,
  "events": [
    {"frame": 5,   "type": "key_press", "keycode": "W"},
    {"frame": 10,  "type": "key_press", "keycode": "W"},
    {"frame": 15,  "type": "key_press", "keycode": "W"},
    {"frame": 20,  "type": "key_press", "keycode": "W"},
    {"frame": 25,  "type": "key_press", "keycode": "W"},
    {"frame": 30,  "type": "key_press", "keycode": "W"},
    {"frame": 35,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 60,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 90,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 120, "type": "wait"},
    {"frame": 200, "type": "wait"},
    {"frame": 300, "type": "key_press", "keycode": "ENTER"},
    {"frame": 390, "type": "wait"}
  ]
}
DEMO2

# Demo 3: Core destroy - enemy kills core, defeat screen (M4 defeat)
cat > "$GAME_DIR/demo_outputs/03_core_destroy.json" << 'DEMO3'
{
  "scenario": "core_destroy",
  "duration_frames": 400,
  "events": [
    {"frame": 10,  "type": "wait"},
    {"frame": 100, "type": "wait"},
    {"frame": 200, "type": "wait"},
    {"frame": 300, "type": "wait"},
    {"frame": 380, "type": "key_press", "keycode": "ENTER"}
  ]
}
DEMO3

# Demo 4: Both zones - map_unlocked → zone1 → ESC → zone2 → ESC → zone3 (D3 multi-zone)
cat > "$GAME_DIR/demo_outputs/04_both_zones.json" << 'DEMO4'
{
  "scenario": "map_unlocked",
  "duration_frames": 600,
  "events": [
    {"frame": 20,  "type": "key_press", "keycode": "1"},
    {"frame": 50,  "type": "key_press", "keycode": "W"},
    {"frame": 55,  "type": "key_press", "keycode": "W"},
    {"frame": 60,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 80,  "type": "key_press", "keycode": "W"},
    {"frame": 85,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 105, "type": "key_press", "keycode": "A"},
    {"frame": 110, "type": "key_press", "keycode": "SPACE"},
    {"frame": 130, "type": "key_press", "keycode": "ESCAPE"},
    {"frame": 160, "type": "key_press", "keycode": "2"},
    {"frame": 190, "type": "key_press", "keycode": "W"},
    {"frame": 195, "type": "key_press", "keycode": "W"},
    {"frame": 200, "type": "key_press", "keycode": "SPACE"},
    {"frame": 220, "type": "key_press", "keycode": "D"},
    {"frame": 225, "type": "key_press", "keycode": "SPACE"},
    {"frame": 245, "type": "key_press", "keycode": "W"},
    {"frame": 250, "type": "key_press", "keycode": "SPACE"},
    {"frame": 270, "type": "key_press", "keycode": "ESCAPE"},
    {"frame": 300, "type": "key_press", "keycode": "3"},
    {"frame": 330, "type": "key_press", "keycode": "W"},
    {"frame": 335, "type": "key_press", "keycode": "W"},
    {"frame": 340, "type": "key_press", "keycode": "SPACE"},
    {"frame": 360, "type": "key_press", "keycode": "A"},
    {"frame": 365, "type": "key_press", "keycode": "SPACE"},
    {"frame": 385, "type": "key_press", "keycode": "D"},
    {"frame": 390, "type": "key_press", "keycode": "SPACE"},
    {"frame": 410, "type": "key_press", "keycode": "W"},
    {"frame": 415, "type": "key_press", "keycode": "SPACE"},
    {"frame": 435, "type": "key_press", "keycode": "ESCAPE"},
    {"frame": 460, "type": "wait"},
    {"frame": 590, "type": "wait"}
  ]
}
DEMO4

# Demo 5: Battle terrain - clear firing + terrain interaction (D1 terrain, D2 enemies, M1/M3)
cat > "$GAME_DIR/demo_outputs/05_battle_terrain.json" << 'DEMO5'
{
  "scenario": "battle",
  "duration_frames": 600,
  "events": [
    {"frame": 10,  "type": "key_press", "keycode": "W"},
    {"frame": 15,  "type": "key_press", "keycode": "W"},
    {"frame": 20,  "type": "key_press", "keycode": "W"},
    {"frame": 25,  "type": "key_press", "keycode": "W"},
    {"frame": 30,  "type": "key_press", "keycode": "W"},
    {"frame": 35,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 55,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 75,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 95,  "type": "key_press", "keycode": "A"},
    {"frame": 100, "type": "key_press", "keycode": "A"},
    {"frame": 105, "type": "key_press", "keycode": "SPACE"},
    {"frame": 125, "type": "key_press", "keycode": "D"},
    {"frame": 130, "type": "key_press", "keycode": "D"},
    {"frame": 135, "type": "key_press", "keycode": "D"},
    {"frame": 140, "type": "key_press", "keycode": "D"},
    {"frame": 145, "type": "key_press", "keycode": "SPACE"},
    {"frame": 165, "type": "key_press", "keycode": "W"},
    {"frame": 170, "type": "key_press", "keycode": "W"},
    {"frame": 175, "type": "key_press", "keycode": "SPACE"},
    {"frame": 195, "type": "key_press", "keycode": "S"},
    {"frame": 200, "type": "key_press", "keycode": "S"},
    {"frame": 205, "type": "key_press", "keycode": "SPACE"},
    {"frame": 225, "type": "key_press", "keycode": "W"},
    {"frame": 230, "type": "key_press", "keycode": "SPACE"},
    {"frame": 250, "type": "key_press", "keycode": "A"},
    {"frame": 255, "type": "key_press", "keycode": "SPACE"},
    {"frame": 275, "type": "key_press", "keycode": "W"},
    {"frame": 280, "type": "key_press", "keycode": "SPACE"},
    {"frame": 300, "type": "key_press", "keycode": "D"},
    {"frame": 305, "type": "key_press", "keycode": "SPACE"},
    {"frame": 325, "type": "key_press", "keycode": "W"},
    {"frame": 330, "type": "key_press", "keycode": "SPACE"},
    {"frame": 350, "type": "key_press", "keycode": "A"},
    {"frame": 355, "type": "key_press", "keycode": "SPACE"},
    {"frame": 375, "type": "key_press", "keycode": "W"},
    {"frame": 380, "type": "key_press", "keycode": "SPACE"},
    {"frame": 400, "type": "key_press", "keycode": "D"},
    {"frame": 405, "type": "key_press", "keycode": "SPACE"},
    {"frame": 425, "type": "key_press", "keycode": "W"},
    {"frame": 430, "type": "key_press", "keycode": "SPACE"},
    {"frame": 450, "type": "key_press", "keycode": "A"},
    {"frame": 455, "type": "key_press", "keycode": "SPACE"},
    {"frame": 475, "type": "key_press", "keycode": "W"},
    {"frame": 480, "type": "key_press", "keycode": "SPACE"},
    {"frame": 500, "type": "key_press", "keycode": "D"},
    {"frame": 505, "type": "key_press", "keycode": "SPACE"},
    {"frame": 525, "type": "key_press", "keycode": "W"},
    {"frame": 530, "type": "key_press", "keycode": "SPACE"},
    {"frame": 550, "type": "key_press", "keycode": "A"},
    {"frame": 555, "type": "key_press", "keycode": "SPACE"},
    {"frame": 575, "type": "key_press", "keycode": "W"},
    {"frame": 580, "type": "key_press", "keycode": "SPACE"}
  ]
}
DEMO5

chmod +x "$0"
echo "Oracle solve.sh completed successfully."
