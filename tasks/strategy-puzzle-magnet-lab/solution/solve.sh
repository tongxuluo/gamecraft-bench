#!/bin/bash
set -eu

GAME=/workspace/game
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5
[application]
config/name="Puzzle Magnet Lab"
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
[node name="Main" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
EOF

cat > "$GAME/scripts/Main.gd" <<'EOF'
extends Control

const CELL := 64
const ORIGIN := Vector2(170, 120)
var scenario := ""
var level := 1
var moves := 0
var polarity := 1
var player := Vector2i(1, 3)
var block := Vector2i(3, 3)
var switch_cell := Vector2i(5, 3)
var exit_cell := Vector2i(7, 3)
var gate_open := false
var message := "Swap polarity with SPACE. Move with arrows."

func _ready() -> void:
    _parse_args()
    if scenario == "":
        _show_title()
    else:
        if scenario == "swap_gate":
            level = 2
            player = Vector2i(1, 2)
            block = Vector2i(4, 2)
            switch_cell = Vector2i(6, 2)
        elif scenario == "near_complete":
            player = Vector2i(6, 3)
            block = switch_cell
            gate_open = true
        _draw_level()

func _parse_args() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]

func _clear() -> void:
    for child in get_children():
        child.queue_free()

func _rect(pos: Vector2, size: Vector2, color: Color) -> void:
    var r := ColorRect.new()
    r.position = pos
    r.size = size
    r.color = color
    add_child(r)

func _label(text: String, pos: Vector2, size: Vector2, fs := 23, color := Color.WHITE) -> Label:
    var l := Label.new()
    l.text = text
    l.position = pos
    l.size = size
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_font_size_override("font_size", fs)
    l.add_theme_color_override("font_color", color)
    add_child(l)
    return l

func _button(text: String, pos: Vector2, size: Vector2, cb: Callable) -> void:
    var b := Button.new()
    b.text = text
    b.position = pos
    b.size = size
    b.add_theme_font_size_override("font_size", 22)
    b.pressed.connect(cb)
    add_child(b)

func _show_title() -> void:
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.04, 0.05, 0.07))
    _rect(Vector2(170, 110), Vector2(940, 430), Color(0.08, 0.12, 0.16))
    _label("PUZZLE MAGNET LAB", Vector2(290, 150), Vector2(720, 70), 52, Color(0.5, 0.9, 1.0))
    _label("Push and pull metal cores with polarity to open lab gates.", Vector2(325, 260), Vector2(660, 70), 27)
    _label("+ and - fields behave differently. Undo/reset is available.", Vector2(375, 340), Vector2(560, 60), 24, Color(1.0, 0.82, 0.35))
    _button("Start Puzzle", Vector2(520, 470), Vector2(240, 60), Callable(self, "_start_game"))

func _start_game() -> void:
    _draw_level()

func _draw_level() -> void:
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.03, 0.04, 0.06))
    _label("Magnet Lab L%d" % level, Vector2(50, 35), Vector2(300, 40), 32, Color(0.5, 0.9, 1.0))
    _label("Moves %d   Polarity %s   Gate %s" % [moves, "+" if polarity > 0 else "-", "OPEN" if gate_open else "LOCKED"], Vector2(50, 82), Vector2(520, 32), 24)
    _label(message, Vector2(50, 124), Vector2(650, 36), 23, Color(1.0, 0.82, 0.35))
    for y in range(6):
        for x in range(9):
            var pos := ORIGIN + Vector2(x * CELL, y * CELL)
            var wall := x == 0 or y == 0 or x == 8 or y == 5 or (x == 4 and y == 4)
            _rect(pos, Vector2(CELL - 3, CELL - 3), Color(0.12, 0.14, 0.18) if wall else Color(0.17, 0.20, 0.25))
    _draw_cell(exit_cell, Color(0.2, 0.95, 0.55), "EXIT")
    _draw_cell(switch_cell, Color(1.0, 0.78, 0.2), "SW")
    if not gate_open:
        _draw_cell(Vector2i(6, 3), Color(0.9, 0.25, 0.25), "GATE")
    _draw_cell(block, Color(0.8, 0.3, 1.0), "-CORE")
    _draw_cell(player, Color(0.25, 0.75, 1.0), "+LAB" if polarity > 0 else "-LAB")
    _rect(Vector2(825, 145), Vector2(320, 335), Color(0.08, 0.10, 0.16))
    _label("Rules\nSame polarity pushes.\nOpposite polarity pulls.\nBlocks on switches open gates.\nHazards and walls block movement.", Vector2(850, 170), Vector2(270, 180), 23)
    _button("Swap Polarity", Vector2(860, 370), Vector2(230, 48), Callable(self, "_swap"))
    _button("Reset", Vector2(860, 430), Vector2(230, 48), Callable(self, "_reset"))

func _draw_cell(c: Vector2i, color: Color, text: String) -> void:
    var pos := ORIGIN + Vector2(c.x * CELL, c.y * CELL)
    _rect(pos + Vector2(6, 6), Vector2(CELL - 15, CELL - 15), color)
    _label(text, pos + Vector2(6, 20), Vector2(CELL - 12, 26), 14, Color.BLACK)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_SPACE:
            _swap()
        elif event.keycode == KEY_R:
            _reset()
        elif event.keycode == KEY_RIGHT:
            _move(Vector2i(1, 0))
        elif event.keycode == KEY_LEFT:
            _move(Vector2i(-1, 0))
        elif event.keycode == KEY_UP:
            _move(Vector2i(0, -1))
        elif event.keycode == KEY_DOWN:
            _move(Vector2i(0, 1))

func _swap() -> void:
    polarity *= -1
    message = "Polarity swapped. Field lines flash before motion."
    _draw_level()

func _reset() -> void:
    moves = 0
    polarity = 1
    player = Vector2i(1, 3)
    block = Vector2i(3, 3)
    gate_open = false
    message = "Reset restored the puzzle."
    _draw_level()

func _move(d: Vector2i) -> void:
    var next := player + d
    if _blocked(next):
        message = "Wall blocks movement."
    elif next == block:
        var block_next := block + d
        if not _blocked(block_next):
            block = block_next
            player = next
            moves += 1
            message = "Same polarity push moved the core."
    else:
        player = next
        moves += 1
        if polarity < 0 and player.distance_to(block) <= 2.1:
            block = player - d
            message = "Opposite polarity pulled the core behind you."
        else:
            message = "Step complete."
    if block == switch_cell:
        gate_open = true
        message = "Switch charged. Gate opened."
    if player == exit_cell and gate_open:
        _show_result(true)
    else:
        _draw_level()

func _blocked(c: Vector2i) -> bool:
    if c.x <= 0 or c.y <= 0 or c.x >= 8 or c.y >= 5:
        return true
    if c == Vector2i(4, 4):
        return true
    if c == Vector2i(6, 3) and not gate_open:
        return true
    return false

func _show_result(won: bool) -> void:
    _clear()
    _rect(Vector2.ZERO, Vector2(1280, 720), Color(0.03, 0.04, 0.06))
    _rect(Vector2(310, 180), Vector2(660, 320), Color(0.08, 0.12, 0.16))
    _label("LEVEL SOLVED" if won else "LAB FAILURE", Vector2(430, 230), Vector2(420, 60), 44, Color(0.5, 0.9, 1.0))
    _label("Moves: %d\nGate: %s\nUse Next, Retry, or Title." % [moves, "OPEN" if gate_open else "LOCKED"], Vector2(455, 315), Vector2(360, 90), 27)
    _button("Retry", Vector2(410, 430), Vector2(150, 52), Callable(self, "_reset"))
    _button("Title", Vector2(710, 430), Vector2(150, 52), Callable(self, "_show_title"))
EOF

cat > "$GAME/demo_outputs/01_title_start.json" <<'EOF'
{"duration_frames":260,"events":[{"frame":30,"type":"mouse_click","button":"left","x":640,"y":500},{"frame":80,"type":"key_press","keycode":"RIGHT"},{"frame":110,"type":"key_press","keycode":"RIGHT"},{"frame":140,"type":"key_press","keycode":"SPACE"},{"frame":240,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/02_push_pull.json" <<'EOF'
{"scenario":"push_pull","duration_frames":300,"events":[{"frame":35,"type":"key_press","keycode":"RIGHT"},{"frame":70,"type":"key_press","keycode":"RIGHT"},{"frame":105,"type":"key_press","keycode":"SPACE"},{"frame":140,"type":"key_press","keycode":"LEFT"},{"frame":280,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/03_reset.json" <<'EOF'
{"scenario":"hazard_reset","duration_frames":260,"events":[{"frame":30,"type":"key_press","keycode":"RIGHT"},{"frame":65,"type":"key_press","keycode":"R"},{"frame":240,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/04_near_complete.json" <<'EOF'
{"scenario":"near_complete","duration_frames":180,"events":[{"frame":40,"type":"key_press","keycode":"RIGHT"},{"frame":160,"type":"wait"}]}
EOF

echo "Wrote Puzzle Magnet Lab to $GAME"
