#!/bin/bash
# Reference solution for gamecraft-bench/rhythm-beat-dungeon.
#
# Drops a minimal but coherent rhythm-based dungeon crawler into /workspace/game/:
#   - Title screen with pulsing game name and PLAY button.
#   - 8x6 grid dungeon with player (@), enemies (E), and loot (*).
#   - Beat indicator bar at bottom that pulses as a visual metronome.
#   - Arrow keys move the player; on-beat moves deal bonus damage, off-beat
#     causes a stumble (brief stun).
#   - Enemies patrol simple patterns and damage player on contact.
#   - Score/combo/HP HUD at the top.
#   - Supports --scenario via OS.get_cmdline_user_args().
#
# Three demo traces exercise different requirement subsets.
set -eu

GAME=/workspace/game
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/demo_outputs"

# --------------------------------------------------------------------------
# project.godot
# --------------------------------------------------------------------------

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="RhythmBeatDungeon"
run/main_scene="res://scenes/Main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
EOF

# --------------------------------------------------------------------------
# Main.tscn
# --------------------------------------------------------------------------

cat > "$GAME/scenes/Main.tscn" <<'EOF'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/Main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
EOF

# --------------------------------------------------------------------------
# Main.gd
# --------------------------------------------------------------------------

cat > "$GAME/scripts/Main.gd" <<'GDEOF'
extends Node2D

const COLS := 8
const ROWS := 6
const CELL := 80
const ORIGIN := Vector2(160, 80)
const BPM := 120.0
const BEAT_SEC := 60.0 / BPM
const BEAT_WINDOW := 0.18
const VP := Vector2(1280, 720)

const C_BG := Color(0.08, 0.08, 0.12)
const C_GRID := Color(0.15, 0.16, 0.22)
const C_LINE := Color(0.25, 0.28, 0.35)
const C_PLAYER := Color(0.2, 0.75, 0.95)
const C_ENEMY := Color(0.9, 0.25, 0.25)
const C_LOOT := Color(1.0, 0.85, 0.1)
const C_BEAT_ON := Color(0.1, 0.9, 0.4)
const C_BEAT_OFF := Color(0.25, 0.25, 0.3)
const C_TITLE := Color(0.85, 0.3, 0.95)

enum State { TITLE, PLAY, GAMEOVER }

var state: int = State.TITLE
var _scenario: String = ""

var player_pos := Vector2i(1, 3)
var player_hp := 5
var score := 0
var combo := 0
var best_combo := 0

var enemies: Array = []
var loot_cells: Array = []

var beat_time := 0.0
var elapsed := 0.0
var beat_count := 0
var stumble_timer := 0.0

var title_label: Label
var play_btn: Button
var grid_root: Node2D
var unit_root: Node2D
var beat_bar: ColorRect
var beat_flash: ColorRect
var hud_label: Label
var banner_label: Label
func _ready() -> void:
    _parse_args()
    if state == State.TITLE:
        _build_title()

func _parse_args() -> void:
    var args := OS.get_cmdline_user_args()
    var i := 0
    while i < args.size():
        if args[i] == "--scenario" and i + 1 < args.size():
            _scenario = args[i + 1]
            i += 2
            continue
        i += 1
    if _scenario == "mid_game":
        _start_game()
    elif _scenario == "low_hp":
        _start_game()
        player_hp = 1
        combo = 4

func _build_title() -> void:
    var bg := ColorRect.new()
    bg.color = C_BG
    bg.position = Vector2.ZERO
    bg.size = VP
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)

    title_label = Label.new()
    title_label.text = "RHYTHM BEAT DUNGEON"
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.position = Vector2(340, 250)
    title_label.add_theme_font_size_override("font_size", 48)
    title_label.add_theme_color_override("font_color", C_TITLE)
    add_child(title_label)

    play_btn = Button.new()
    play_btn.text = "PLAY"
    play_btn.position = Vector2(560, 400)
    play_btn.size = Vector2(160, 60)
    play_btn.pressed.connect(_on_play)
    add_child(play_btn)

func _on_play() -> void:
    _clear_children()
    _start_game()

func _clear_children() -> void:
    for c in get_children():
        c.queue_free()
func _start_game() -> void:
    state = State.PLAY
    elapsed = 0.0
    beat_time = 0.0
    beat_count = 0
    _build_play_scene()
    _spawn_level()

func _build_play_scene() -> void:
    var bg := ColorRect.new()
    bg.color = C_BG
    bg.position = Vector2.ZERO
    bg.size = VP
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)

    grid_root = Node2D.new()
    grid_root.name = "Grid"
    add_child(grid_root)

    var grid_bg := ColorRect.new()
    grid_bg.color = C_GRID
    grid_bg.position = ORIGIN
    grid_bg.size = Vector2(COLS * CELL, ROWS * CELL)
    grid_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    grid_root.add_child(grid_bg)

    for c in range(COLS + 1):
        var line := ColorRect.new()
        line.color = C_LINE
        line.position = ORIGIN + Vector2(c * CELL - 1, 0)
        line.size = Vector2(2, ROWS * CELL)
        line.mouse_filter = Control.MOUSE_FILTER_IGNORE
        grid_root.add_child(line)
    for r in range(ROWS + 1):
        var line := ColorRect.new()
        line.color = C_LINE
        line.position = ORIGIN + Vector2(0, r * CELL - 1)
        line.size = Vector2(COLS * CELL, 2)
        line.mouse_filter = Control.MOUSE_FILTER_IGNORE
        grid_root.add_child(line)

    unit_root = Node2D.new()
    unit_root.name = "Units"
    add_child(unit_root)

    beat_bar = ColorRect.new()
    beat_bar.color = C_BEAT_OFF
    beat_bar.position = Vector2(160, 580)
    beat_bar.size = Vector2(640, 24)
    beat_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(beat_bar)
    beat_flash = ColorRect.new()
    beat_flash.color = C_BEAT_ON
    beat_flash.position = Vector2(160, 580)
    beat_flash.size = Vector2(0, 24)
    beat_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(beat_flash)

    hud_label = Label.new()
    hud_label.text = ""
    hud_label.position = Vector2(160, 20)
    hud_label.add_theme_font_size_override("font_size", 22)
    hud_label.add_theme_color_override("font_color", Color.WHITE)
    add_child(hud_label)

    banner_label = Label.new()
    banner_label.text = ""
    banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    banner_label.position = Vector2(400, 340)
    banner_label.add_theme_font_size_override("font_size", 40)
    banner_label.add_theme_color_override("font_color", Color.WHITE)
    banner_label.visible = false
    add_child(banner_label)

func _spawn_level() -> void:
    enemies.clear()
    loot_cells.clear()
    if _scenario == "low_hp":
        enemies.append({"pos": Vector2i(5, 3), "dir": 1, "hp": 2})
    else:
        enemies.append({"pos": Vector2i(4, 1), "dir": 1, "hp": 2})
        enemies.append({"pos": Vector2i(6, 4), "dir": -1, "hp": 2})
    loot_cells.append(Vector2i(3, 2))
    loot_cells.append(Vector2i(6, 5))
    _draw_units()
func _process(delta: float) -> void:
    if state != State.PLAY:
        if state == State.TITLE and title_label != null:
            var pulse := 0.7 + 0.3 * sin(elapsed * 3.0)
            title_label.modulate.a = pulse
            elapsed += delta
        return
    elapsed += delta
    beat_time += delta
    if stumble_timer > 0.0:
        stumble_timer -= delta

    var beat_phase := fmod(beat_time, BEAT_SEC) / BEAT_SEC
    var flash_w := 640.0 * (1.0 - beat_phase)
    beat_flash.size = Vector2(flash_w, 24)

    if beat_time >= BEAT_SEC:
        beat_time -= BEAT_SEC
        beat_count += 1
        _enemy_step()
        _check_enemy_contact()

    _draw_units()
    _refresh_hud()

func _is_on_beat() -> bool:
    var phase := fmod(beat_time, BEAT_SEC)
    return phase < BEAT_WINDOW or (BEAT_SEC - phase) < BEAT_WINDOW

func _unhandled_input(event: InputEvent) -> void:
    if state != State.PLAY:
        return
    if not event is InputEventKey:
        return
    if not event.pressed or event.echo:
        return
    var dir := Vector2i.ZERO
    if event.keycode == KEY_UP:
        dir = Vector2i(0, -1)
    elif event.keycode == KEY_DOWN:
        dir = Vector2i(0, 1)
    elif event.keycode == KEY_LEFT:
        dir = Vector2i(-1, 0)
    elif event.keycode == KEY_RIGHT:
        dir = Vector2i(1, 0)
    if dir == Vector2i.ZERO:
        return
    if stumble_timer > 0.0:
        return
    _move_player(dir)
func _move_player(dir: Vector2i) -> void:
    var on_beat := _is_on_beat()
    var new_pos := player_pos + dir
    if new_pos.x < 0 or new_pos.x >= COLS or new_pos.y < 0 or new_pos.y >= ROWS:
        return
    if not on_beat:
        stumble_timer = 0.3
        combo = 0
        return
    player_pos = new_pos
    combo += 1
    if combo > best_combo:
        best_combo = combo
    var hit_enemy := -1
    for idx in range(enemies.size()):
        var e: Dictionary = enemies[idx]
        if Vector2i(e["pos"]) == player_pos:
            hit_enemy = idx
    if hit_enemy >= 0:
        var bonus := 1 + int(combo / 4)
        var ehp: int = enemies[hit_enemy]["hp"]
        ehp -= bonus
        enemies[hit_enemy]["hp"] = ehp
        if ehp <= 0:
            enemies.remove_at(hit_enemy)
            score += 100
        else:
            score += 25
        player_pos -= dir
    var loot_idx := loot_cells.find(player_pos)
    if loot_idx >= 0:
        loot_cells.remove_at(loot_idx)
        score += 50
    if enemies.size() == 0 and loot_cells.size() == 0:
        _end_game(true)

func _enemy_step() -> void:
    for idx in range(enemies.size()):
        var e: Dictionary = enemies[idx]
        var epos := Vector2i(e["pos"])
        var edir: int = e["dir"]
        var next := epos + Vector2i(edir, 0)
        if next.x < 0 or next.x >= COLS:
            edir = -edir
            next = epos + Vector2i(edir, 0)
        enemies[idx]["pos"] = next
        enemies[idx]["dir"] = edir

func _check_enemy_contact() -> void:
    for e in enemies:
        if Vector2i(e["pos"]) == player_pos:
            player_hp -= 1
            combo = 0
            if player_hp <= 0:
                _end_game(false)
                return

func _end_game(won: bool) -> void:
    state = State.GAMEOVER
    banner_label.visible = true
    if won:
        banner_label.text = "VICTORY! Score: " + str(score)
    else:
        banner_label.text = "GAME OVER  Score: " + str(score)

func _refresh_hud() -> void:
    if hud_label == null:
        return
    hud_label.text = "HP: " + str(player_hp) + "  Score: " + str(score) + "  Combo: " + str(combo)
func _draw_units() -> void:
    if unit_root == null:
        return
    for c in unit_root.get_children():
        c.queue_free()
    var pr := ColorRect.new()
    pr.color = C_PLAYER
    pr.position = ORIGIN + Vector2(player_pos.x * CELL + 10, player_pos.y * CELL + 10)
    pr.size = Vector2(CELL - 20, CELL - 20)
    pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
    unit_root.add_child(pr)
    for e in enemies:
        var er := ColorRect.new()
        er.color = C_ENEMY
        var epos := Vector2i(e["pos"])
        er.position = ORIGIN + Vector2(epos.x * CELL + 12, epos.y * CELL + 12)
        er.size = Vector2(CELL - 24, CELL - 24)
        er.mouse_filter = Control.MOUSE_FILTER_IGNORE
        unit_root.add_child(er)
    for lp in loot_cells:
        var lr := ColorRect.new()
        lr.color = C_LOOT
        lr.position = ORIGIN + Vector2(lp.x * CELL + 25, lp.y * CELL + 25)
        lr.size = Vector2(CELL - 50, CELL - 50)
        lr.mouse_filter = Control.MOUSE_FILTER_IGNORE
        unit_root.add_child(lr)
GDEOF

# --------------------------------------------------------------------------
# Demo traces
# --------------------------------------------------------------------------

cat > "$GAME/demo_outputs/title_to_play.json" <<'EOF'
{"duration_frames": 360, "events": [{"frame": 60, "type": "wait"}, {"frame": 120, "type": "mouse_click", "button": "left", "x": 640, "y": 430}]}
EOF

cat > "$GAME/demo_outputs/on_beat_moves.json" <<'EOF'
{"duration_frames": 600, "events": [{"frame": 60, "type": "wait"}, {"frame": 120, "type": "mouse_click", "button": "left", "x": 640, "y": 430}, {"frame": 180, "type": "key_press", "keycode": "RIGHT"}, {"frame": 210, "type": "key_press", "keycode": "RIGHT"}, {"frame": 240, "type": "key_press", "keycode": "UP"}, {"frame": 270, "type": "key_press", "keycode": "RIGHT"}, {"frame": 300, "type": "key_press", "keycode": "DOWN"}, {"frame": 360, "type": "key_press", "keycode": "RIGHT"}]}
EOF

cat > "$GAME/demo_outputs/scenario_low_hp.json" <<'EOF'
{"duration_frames": 480, "events": [{"frame": 30, "type": "wait"}, {"frame": 60, "type": "key_press", "keycode": "RIGHT"}, {"frame": 90, "type": "key_press", "keycode": "RIGHT"}, {"frame": 120, "type": "key_press", "keycode": "RIGHT"}, {"frame": 150, "type": "key_press", "keycode": "RIGHT"}]}
EOF

echo "rhythm-beat-dungeon oracle written to $GAME"
