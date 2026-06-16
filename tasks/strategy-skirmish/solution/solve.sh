#!/bin/bash
# Reference solution for gamecraft-bench/strategy-skirmish.
#
# Drops a minimal but coherent turn-based skirmish into /workspace/game/:
#   - 8x6 grid, 2 player units (blue) on the left, 2 enemy units (red) on the
#     right, all 3 HP.
#   - Click a player unit to select it; move-range cells highlight up to 2
#     tiles away.
#   - Escape (or click empty) clears selection.
#   - Click an in-range cell to walk there cell-by-cell.
#   - Adjacent enemy click = melee attack (-1 HP). 0 HP units are removed.
#   - End Turn button switches to enemy turn; enemies step toward the nearest
#     player and attack if adjacent.
#   - Last side standing triggers "Victory" / "Defeat" centered on screen.
#
# Three demo traces under demo_outputs/ exercise different requirement subsets,
# including a `--scenario near_victory` for the V1 endgame check.
#
# This solution is intentionally small enough to read end-to-end. It is the
# oracle for the verifier framework, not a polished game.
set -eu

GAME=/workspace/game
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

# --------------------------------------------------------------------------
# project.godot + Main scene
# --------------------------------------------------------------------------

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="StrategySkirmish"
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

cat > "$GAME/scenes/Main.tscn" <<'EOF'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/Main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
EOF

# --------------------------------------------------------------------------
# Main.gd — the whole game lives in one file. Long-ish, but every piece maps
# to a numbered requirement in instruction.md.
# --------------------------------------------------------------------------

cat > "$GAME/scripts/Main.gd" <<'GDSCRIPT_EOF'
extends Node2D

const COLS := 8
const ROWS := 6
const CELL := 80
const ORIGIN := Vector2(160, 120)
const MOVE_RANGE := 2
const VIEWPORT := Vector2(1280, 720)

const COLOR_GRID := Color(0.18, 0.20, 0.24)
const COLOR_GRID_LINE := Color(0.30, 0.34, 0.40)
const COLOR_PLAYER := Color(0.30, 0.55, 0.95)
const COLOR_ENEMY  := Color(0.90, 0.30, 0.30)
const COLOR_SELECT := Color(1.00, 0.95, 0.20, 0.85)
const COLOR_RANGE  := Color(0.45, 0.85, 0.55, 0.45)

var grid_root: Node2D
var unit_root: Node2D
var hud_root: CanvasLayer

var turn_label: Label
var end_turn_btn: Button
var banner_label: Label

var units: Array = []
var selected_id: int = -1
var range_overlay: Array = []
var current_side: String = "player"
var game_over: bool = false
var animating: bool = false
var _scenario: String = ""
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.seed = 1
    _parse_args()
    _build_grid()
    _build_hud()
    _spawn_default()
    _refresh_hud()

func _parse_args() -> void:
    var args := OS.get_cmdline_user_args()
    var i := 0
    while i < args.size():
        if args[i] == "--scenario" and i + 1 < args.size():
            _scenario = args[i + 1]
            i += 2
            continue
        i += 1

GDSCRIPT_EOF

cat >> "$GAME/scripts/Main.gd" <<'GDSCRIPT_EOF'
func _build_grid() -> void:
    grid_root = Node2D.new()
    grid_root.name = "Grid"
    add_child(grid_root)

    var bg := ColorRect.new()
    bg.color = COLOR_GRID
    bg.position = ORIGIN
    bg.size = Vector2(COLS * CELL, ROWS * CELL)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    grid_root.add_child(bg)
    for c in range(COLS + 1):
        var v := ColorRect.new()
        v.color = COLOR_GRID_LINE
        v.position = ORIGIN + Vector2(c * CELL - 1, 0)
        v.size = Vector2(2, ROWS * CELL)
        v.mouse_filter = Control.MOUSE_FILTER_IGNORE
        grid_root.add_child(v)
    for r in range(ROWS + 1):
        var h := ColorRect.new()
        h.color = COLOR_GRID_LINE
        h.position = ORIGIN + Vector2(0, r * CELL - 1)
        h.size = Vector2(COLS * CELL, 2)
        h.mouse_filter = Control.MOUSE_FILTER_IGNORE
        grid_root.add_child(h)

    unit_root = Node2D.new()
    unit_root.name = "Units"
    add_child(unit_root)

func _spawn_default() -> void:
    units.clear()
    if _scenario == "near_victory":
        _add_unit("player", Vector2i(2, 2), 3)
        _add_unit("enemy",  Vector2i(3, 2), 1)
    elif _scenario == "near_defeat":
        _add_unit("player", Vector2i(3, 2), 1)
        _add_unit("enemy",  Vector2i(4, 2), 3)
        _add_unit("enemy",  Vector2i(2, 2), 3)
    else:
        _add_unit("player", Vector2i(1, 2), 3)
        _add_unit("player", Vector2i(1, 3), 3)
        _add_unit("enemy",  Vector2i(6, 2), 3)
        _add_unit("enemy",  Vector2i(6, 3), 3)
    current_side = "player"
    for u in units:
        unit_root.add_child(u.sprite)
        unit_root.add_child(u.hp_label)
    _refresh_units()

func _add_unit(side: String, cell: Vector2i, hp: int) -> void:
    var sprite := ColorRect.new()
    sprite.size = Vector2(CELL - 16, CELL - 16)
    sprite.color = COLOR_PLAYER if side == "player" else COLOR_ENEMY
    sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var label := Label.new()
    label.add_theme_font_size_override("font_size", 18)
    label.modulate = Color(1, 1, 1)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    units.append({
        "id": units.size(),
        "side": side,
        "cell": cell,
        "hp": hp,
        "max_hp": hp,
        "acted": false,
        "sprite": sprite,
        "hp_label": label,
    })

func _refresh_units() -> void:
    for u in units:
        var p: Vector2 = _cell_to_pixel(u.cell) + Vector2(8, 8)
        u.sprite.position = p
        u.sprite.modulate = Color(1, 1, 1, 0.5) if (u.acted and u.side == "player") else Color(1, 1, 1)
        u.hp_label.position = p + Vector2(4, -2)
        u.hp_label.text = "HP %d" % u.hp

GDSCRIPT_EOF

cat >> "$GAME/scripts/Main.gd" <<'GDSCRIPT_EOF'
func _build_hud() -> void:
    hud_root = CanvasLayer.new()
    add_child(hud_root)

    turn_label = Label.new()
    turn_label.add_theme_font_size_override("font_size", 32)
    turn_label.position = Vector2(20, 16)
    turn_label.text = "Player Turn"
    hud_root.add_child(turn_label)

    end_turn_btn = Button.new()
    end_turn_btn.text = "End Turn"
    end_turn_btn.position = Vector2(VIEWPORT.x - 200, 20)
    end_turn_btn.size = Vector2(160, 56)
    end_turn_btn.add_theme_font_size_override("font_size", 24)
    end_turn_btn.pressed.connect(_on_end_turn)
    hud_root.add_child(end_turn_btn)

    banner_label = Label.new()
    banner_label.add_theme_font_size_override("font_size", 96)
    banner_label.position = Vector2(VIEWPORT.x / 2 - 220, VIEWPORT.y / 2 - 60)
    banner_label.size = Vector2(440, 120)
    banner_label.modulate = Color(1, 1, 1)
    banner_label.visible = false
    hud_root.add_child(banner_label)

func _refresh_hud() -> void:
    turn_label.text = ("Player Turn" if current_side == "player" else "Enemy Turn")

func _unhandled_input(event: InputEvent) -> void:
    if game_over or animating:
        return
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        _clear_selection()
        return
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            _on_left_click(event.position)

func _on_left_click(screen_pos: Vector2) -> void:
    if current_side != "player":
        return
    if end_turn_btn.get_global_rect().has_point(screen_pos):
        return
    var cell: Vector2i = _pixel_to_cell(screen_pos)
    if cell == Vector2i(-1, -1):
        _clear_selection()
        return
    var unit_here = _unit_at(cell)
    if unit_here != null and unit_here.side == "player" and not unit_here.acted:
        _select(unit_here.id)
        return
    if selected_id == -1:
        return
    var sel = _unit_by_id(selected_id)
    if sel == null:
        return
    if unit_here != null and unit_here.side == "enemy":
        if _cell_distance(sel.cell, unit_here.cell) == 1:
            _attack(sel, unit_here)
        return
    if _is_in_range(sel, cell):
        _move_unit(sel, cell)

GDSCRIPT_EOF

cat >> "$GAME/scripts/Main.gd" <<'GDSCRIPT_EOF'
func _select(uid: int) -> void:
    selected_id = uid
    _draw_range()

func _clear_selection() -> void:
    selected_id = -1
    for r in range_overlay:
        r.queue_free()
    range_overlay.clear()

func _draw_range() -> void:
    for r in range_overlay:
        r.queue_free()
    range_overlay.clear()
    var u = _unit_by_id(selected_id)
    if u == null:
        return
    var sel_ring := ColorRect.new()
    sel_ring.color = COLOR_SELECT
    sel_ring.position = _cell_to_pixel(u.cell)
    sel_ring.size = Vector2(CELL, CELL)
    sel_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
    grid_root.add_child(sel_ring)
    range_overlay.append(sel_ring)
    for dy in range(-MOVE_RANGE, MOVE_RANGE + 1):
        for dx in range(-MOVE_RANGE, MOVE_RANGE + 1):
            if abs(dx) + abs(dy) == 0 or abs(dx) + abs(dy) > MOVE_RANGE:
                continue
            var c := Vector2i(u.cell.x + dx, u.cell.y + dy)
            if not _in_bounds(c):
                continue
            if _unit_at(c) != null:
                continue
            var rr := ColorRect.new()
            rr.color = COLOR_RANGE
            rr.position = _cell_to_pixel(c)
            rr.size = Vector2(CELL, CELL)
            rr.mouse_filter = Control.MOUSE_FILTER_IGNORE
            grid_root.add_child(rr)
            range_overlay.append(rr)

func _is_in_range(u: Dictionary, cell: Vector2i) -> bool:
    if not _in_bounds(cell):
        return false
    if _unit_at(cell) != null:
        return false
    return _cell_distance(u.cell, cell) <= MOVE_RANGE

func _move_unit(u: Dictionary, dest: Vector2i) -> void:
    animating = true
    var path: Array = _path(u.cell, dest)
    var step_time := 0.12
    for raw_step in path:
        var step: Vector2i = raw_step
        var start_pix: Vector2 = _cell_to_pixel(u.cell) + Vector2(8, 8)
        var end_pix: Vector2 = _cell_to_pixel(step) + Vector2(8, 8)
        var elapsed := 0.0
        while elapsed < step_time:
            await get_tree().process_frame
            elapsed += get_process_delta_time()
            var k := clampf(elapsed / step_time, 0.0, 1.0)
            u.sprite.position = start_pix.lerp(end_pix, k)
        u.cell = step
        u.sprite.position = end_pix
    u.acted = true
    animating = false
    _clear_selection()
    _refresh_units()

func _path(a: Vector2i, b: Vector2i) -> Array:
    var p: Array = []
    var cur := a
    while cur.x != b.x:
        cur.x += 1 if b.x > cur.x else -1
        p.append(cur)
    while cur.y != b.y:
        cur.y += 1 if b.y > cur.y else -1
        p.append(cur)
    return p

GDSCRIPT_EOF

cat >> "$GAME/scripts/Main.gd" <<'GDSCRIPT_EOF'
func _attack(attacker: Dictionary, target: Dictionary) -> void:
    target.hp -= 1
    attacker.acted = true
    if target.hp <= 0:
        units.erase(target)
        target.sprite.queue_free()
        target.hp_label.queue_free()
    _clear_selection()
    _refresh_units()
    _check_end()

func _on_end_turn() -> void:
    if game_over or animating:
        return
    if current_side != "player":
        return
    _clear_selection()
    current_side = "enemy"
    _refresh_hud()
    _enemy_turn()

func _enemy_turn() -> void:
    animating = true
    for u in units.duplicate():
        if u.side != "enemy" or u.hp <= 0:
            continue
        var nearest = _nearest(u, "player")
        if nearest == null:
            continue
        if _cell_distance(u.cell, nearest.cell) == 1:
            _attack(u, nearest)
            if game_over:
                animating = false
                return
            continue
        var step: Vector2i = u.cell
        if nearest.cell.x != u.cell.x:
            step.x += 1 if nearest.cell.x > u.cell.x else -1
        elif nearest.cell.y != u.cell.y:
            step.y += 1 if nearest.cell.y > u.cell.y else -1
        if _unit_at(step) == null and _in_bounds(step):
            u.cell = step
        await get_tree().create_timer(0.15).timeout
    for u in units:
        if u.side == "player":
            u.acted = false
    current_side = "player"
    _refresh_hud()
    _refresh_units()
    animating = false
    _check_end()

func _check_end() -> void:
    var alive_p := 0
    var alive_e := 0
    for u in units:
        if u.side == "player" and u.hp > 0:
            alive_p += 1
        elif u.side == "enemy" and u.hp > 0:
            alive_e += 1
    if alive_e == 0:
        _end_game("Victory")
    elif alive_p == 0:
        _end_game("Defeat")

func _end_game(text: String) -> void:
    game_over = true
    banner_label.text = text
    banner_label.visible = true

GDSCRIPT_EOF

cat >> "$GAME/scripts/Main.gd" <<'GDSCRIPT_EOF'
func _cell_to_pixel(c: Vector2i) -> Vector2:
    return ORIGIN + Vector2(c.x * CELL, c.y * CELL)

func _pixel_to_cell(p: Vector2) -> Vector2i:
    var rel := p - ORIGIN
    var x := int(rel.x / CELL)
    var y := int(rel.y / CELL)
    if x < 0 or x >= COLS or y < 0 or y >= ROWS:
        return Vector2i(-1, -1)
    return Vector2i(x, y)

func _in_bounds(c: Vector2i) -> bool:
    return c.x >= 0 and c.x < COLS and c.y >= 0 and c.y < ROWS

func _cell_distance(a: Vector2i, b: Vector2i) -> int:
    return abs(a.x - b.x) + abs(a.y - b.y)

func _unit_at(c: Vector2i):
    for u in units:
        if u.cell == c and u.hp > 0:
            return u
    return null

func _unit_by_id(uid: int):
    for u in units:
        if u.id == uid:
            return u
    return null

func _nearest(from: Dictionary, side: String):
    var best = null
    var best_d := 999
    for u in units:
        if u.side != side or u.hp <= 0:
            continue
        var d := _cell_distance(from.cell, u.cell)
        if d < best_d:
            best_d = d
            best = u
    return best
GDSCRIPT_EOF

# --------------------------------------------------------------------------
# Demo traces. Coordinates target cell centers given ORIGIN=(160,120) and
# CELL=80: cell (c, r) is at pixel (160 + c*80 + 40, 120 + r*80 + 40).
# So (1,2) -> (240, 280); (2,2) -> (320, 280); (3,2) -> (400, 280); etc.
# End Turn button is centered around (1080, 48).
# --------------------------------------------------------------------------

cat > "$GAME/demo_outputs/opening.json" <<'EOF'
{
  "duration_frames": 540,
  "events": [
    {"frame": 60,  "type": "mouse_click", "button": "left", "x": 240, "y": 280},
    {"frame": 120, "type": "key_press",   "keycode": "ESCAPE"},
    {"frame": 180, "type": "mouse_click", "button": "left", "x": 240, "y": 360},
    {"frame": 240, "type": "mouse_click", "button": "left", "x": 800, "y": 600},
    {"frame": 300, "type": "mouse_click", "button": "left", "x": 320, "y": 360},
    {"frame": 360, "type": "mouse_click", "button": "left", "x": 400, "y": 360},
    {"frame": 420, "type": "mouse_click", "button": "left", "x": 1080, "y": 48},
    {"frame": 540, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/combat_victory.json" <<'EOF'
{
  "scenario": "near_victory",
  "duration_frames": 360,
  "events": [
    {"frame": 60,  "type": "mouse_click", "button": "left", "x": 320, "y": 280},
    {"frame": 150, "type": "mouse_click", "button": "left", "x": 400, "y": 280},
    {"frame": 360, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/defeat.json" <<'EOF'
{
  "scenario": "near_defeat",
  "duration_frames": 480,
  "events": [
    {"frame": 60,  "type": "mouse_click", "button": "left", "x": 1080, "y": 48},
    {"frame": 480, "type": "wait"}
  ]
}
EOF

echo "oracle wrote project to $GAME"
ls -1 "$GAME"
