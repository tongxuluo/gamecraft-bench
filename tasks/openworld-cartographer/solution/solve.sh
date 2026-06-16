#!/bin/bash
# Reference solution for gamecraft-bench/openworld-cartographer.
#
# A compact 2D cartography exploration game:
#   - Title -> wilderness with fog of war. WASD move; fog clears as player walks.
#   - Discovered terrain types (forest/mountain/river/ruin) are recorded on a
#     minimap with distinct markers. Landmarks give bonus credits when sold.
#   - Resources constrain exploration: food (depletes over time, 0=starve),
#     ink (spent to annotate landmarks), rope (spent to cross cliffs).
#   - Return to town to sell the map (credits = explored area + annotations).
#   - Buy equipment upgrades (boots=speed, compass=reveal radius, pack=capacity).
#   - HUD: food/ink/rope counts, minimap, credits. Result on starvation or
#     selling a complete map.
#   - Scenarios jump to explore / town / danger for deterministic demos.
#
# Oracle for the verifier: primitives only, art items (A*) stay low.
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="Cartographer"
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

cat > "$GAME/scripts/Main.gd" <<'GDSCRIPT'
extends Node2D

const VIEW := Vector2(1280, 720)
const GRID := 16
const CELL := 40.0
const REVEAL_R := 3
const TOWN := Vector2i(0, 7)

const TERRAIN_COLS := {
    "fog": Color(0.12, 0.12, 0.14),
    "grass": Color(0.2, 0.4, 0.2),
    "forest": Color(0.1, 0.3, 0.1),
    "mountain": Color(0.4, 0.35, 0.3),
    "river": Color(0.2, 0.3, 0.5),
    "ruin": Color(0.5, 0.4, 0.3),
    "town": Color(0.5, 0.5, 0.6),
}

const UPGRADES := [
    {"name": "Boots (speed+)", "cost": 40, "stat": "speed"},
    {"name": "Compass (reveal+)", "cost": 60, "stat": "reveal"},
    {"name": "Pack (capacity+)", "cost": 50, "stat": "capacity"},
]

var scenario := ""
var mode := "title"          # title, explore, town, result
var grid_data: Array = []    # 2D: terrain string per cell
var revealed: Array = []     # 2D: bool
var annotated: Array = []    # 2D: bool (landmark annotated)
var px := 0
var py := 7
var food := 10
var ink := 5
var rope := 3
var max_food := 10
var credits := 0
var speed_bonus := 0
var reveal_bonus := 0
var move_accum := 0.0
var move_dir := {"up": false, "down": false, "left": false, "right": false}
var anim := 0.0
var msg := ""
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.seed = 7777
    _parse_args()
    if scenario != "":
        _load_scenario(scenario)
    queue_redraw()

func _parse_args() -> void:
    var args := OS.get_cmdline_user_args()
    var i := 0
    while i < args.size():
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]
            i += 2
        else:
            i += 1

func _gen_world() -> void:
    grid_data = []
    revealed = []
    annotated = []
    var kinds := ["grass", "forest", "mountain", "river", "ruin"]
    for y in range(GRID):
        var row: Array = []
        var rrow: Array = []
        var arow: Array = []
        for x in range(GRID):
            if x == TOWN.x and y == TOWN.y:
                row.append("town")
            else:
                row.append(kinds[rng.randi() % kinds.size()])
            rrow.append(false)
            arow.append(false)
        grid_data.append(row)
        revealed.append(rrow)
        annotated.append(arow)
    _reveal_around(TOWN.x, TOWN.y)

func _reveal_around(cx: int, cy: int) -> void:
    var r: int = REVEAL_R + reveal_bonus
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            var nx := cx + dx
            var ny := cy + dy
            if nx >= 0 and nx < GRID and ny >= 0 and ny < GRID:
                revealed[ny][nx] = true

func _load_scenario(id: String) -> void:
    if id == "title_flow":
        mode = "title"
    elif id == "explore":
        _start()
    elif id == "town":
        _start(); mode = "town"
    elif id == "danger":
        _start(); food = 2; px = 8; py = 8; _reveal_around(px, py)
    elif id == "sell":
        _start(); px = TOWN.x; py = TOWN.y; credits = 0
        # reveal a bunch for selling
        for y in range(6):
            for x in range(6):
                revealed[y][x] = true
        mode = "town"
    else:
        _start()

func _start() -> void:
    mode = "explore"
    _gen_world()
    px = TOWN.x
    py = TOWN.y
    food = 10
    ink = 5
    rope = 3
    max_food = 10
    credits = 0
    speed_bonus = 0
    reveal_bonus = 0
    msg = "Explore the wilderness. WASD move. E annotate. SPACE return to town when at town."

func _explored_count() -> int:
    var c := 0
    for y in range(GRID):
        for x in range(GRID):
            if revealed[y][x]:
                c += 1
    return c

func _annotated_count() -> int:
    var c := 0
    for y in range(GRID):
        for x in range(GRID):
            if annotated[y][x]:
                c += 1
    return c

func _physics_process(delta: float) -> void:
    anim += delta
    if mode != "explore":
        return
    var dir := Vector2i.ZERO
    if move_dir["up"]: dir.y = -1
    elif move_dir["down"]: dir.y = 1
    elif move_dir["left"]: dir.x = -1
    elif move_dir["right"]: dir.x = 1
    if dir != Vector2i.ZERO:
        move_accum += delta * (2.5 + float(speed_bonus))
        if move_accum >= 1.0:
            move_accum = 0.0
            _step(dir)
    queue_redraw()

func _step(dir: Vector2i) -> void:
    var nx := px + dir.x
    var ny := py + dir.y
    if nx < 0 or nx >= GRID or ny < 0 or ny >= GRID:
        return
    var terrain: String = str(grid_data[ny][nx])
    if terrain == "mountain" and rope <= 0:
        msg = "Need rope to cross mountains!"
        return
    if terrain == "mountain":
        rope -= 1
    px = nx
    py = ny
    _reveal_around(px, py)
    food -= 1
    if food <= 0:
        _finish(false)

func _annotate() -> void:
    if mode != "explore":
        return
    if ink <= 0:
        msg = "No ink left to annotate."
        queue_redraw(); return
    var terrain: String = str(grid_data[py][px])
    if terrain in ["ruin", "river", "mountain"] and not annotated[py][px]:
        annotated[py][px] = true
        ink -= 1
        msg = "Annotated %s landmark!" % terrain
    else:
        msg = "Nothing special to annotate here."
    queue_redraw()

func _enter_town() -> void:
    if px == TOWN.x and py == TOWN.y:
        mode = "town"
        msg = "Welcome back. Sell your map or buy supplies."
        queue_redraw()

func _sell_map() -> void:
    var value: int = _explored_count() * 2 + _annotated_count() * 5
    credits += value
    msg = "Sold map for %d credits! (explored %d, annotated %d)" % [value, _explored_count(), _annotated_count()]
    if _explored_count() >= GRID * GRID - 10:
        _finish(true)
    queue_redraw()

func _buy_upgrade(idx: int) -> void:
    if idx < 0 or idx >= UPGRADES.size():
        return
    var u: Dictionary = UPGRADES[idx]
    var cost: int = int(u["cost"])
    if credits < cost:
        msg = "Not enough credits."
        queue_redraw(); return
    credits -= cost
    var stat: String = str(u["stat"])
    if stat == "speed": speed_bonus += 1
    elif stat == "reveal": reveal_bonus += 1
    elif stat == "capacity": max_food += 5; food = max_food
    msg = "Bought %s!" % str(u["name"])
    queue_redraw()

func _restock() -> void:
    food = max_food
    ink = 5
    rope = 3
    msg = "Restocked supplies."
    queue_redraw()

func _leave_town() -> void:
    mode = "explore"
    msg = "Back to the wild."
    queue_redraw()

func _finish(victory: bool) -> void:
    mode = "result"
    queue_redraw()

# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.08, 0.08, 0.10))
    match mode:
        "title": _draw_title()
        "explore": _draw_map()
        "town": _draw_town()
        "result": _draw_result()

func _text(s: String, p: Vector2, sz: int, c: Color) -> void:
    draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)

func _panel(r: Rect2, c := Color(0.06, 0.07, 0.05, 0.93)) -> void:
    draw_rect(r, c); draw_rect(r, Color(0.5, 0.6, 0.4, 0.9), false, 2.0)

func _button(r: Rect2, label: String, on := true) -> void:
    draw_rect(r, Color(0.12, 0.14, 0.10) if on else Color(0.18, 0.10, 0.10))
    draw_rect(r, Color(0.5, 0.7, 0.4) if on else Color(0.5, 0.3, 0.3), false, 2.0)
    _text(label, r.position + Vector2(14, r.size.y * 0.64), 18, Color(0.88, 0.95, 0.85))

func _draw_title() -> void:
    _panel(Rect2(330, 150, 620, 340))
    _text("CARTOGRAPHER", Vector2(420, 250), 50, Color(0.6, 0.8, 0.5))
    _text("Map the unknown. Manage supplies. Sell your discoveries.", Vector2(370, 312), 18, Color(0.8, 0.9, 0.8))
    _button(Rect2(500, 410, 280, 64), "VENTURE FORTH")

func _draw_map() -> void:
    var ox := 20.0
    var oy := 70.0
    draw_rect(Rect2(ox - 8, oy - 8, GRID * CELL + 8, GRID * CELL + 8), Color(0.64, 0.55, 0.38, 0.28))
    for y in range(GRID):
        for x in range(GRID):
            var r := Rect2(ox + float(x) * CELL, oy + float(y) * CELL, CELL - 2, CELL - 2)
            if revealed[y][x]:
                var terrain: String = str(grid_data[y][x])
                draw_rect(r, TERRAIN_COLS.get(terrain, Color(0.2, 0.2, 0.2)))
                _draw_terrain_icon(terrain, r)
                if annotated[y][x]:
                    draw_rect(r, Color(1, 0.9, 0.3, 0.3))
                    draw_circle(r.get_center(), 10, Color(1.0, 0.86, 0.24, 0.65), false, 3.0)
            else:
                draw_rect(r, TERRAIN_COLS["fog"])
                draw_rect(r.grow(-9), Color(0.02, 0.02, 0.03, 0.16))
    # player
    var pp := Vector2(ox + float(px) * CELL + CELL * 0.5, oy + float(py) * CELL + CELL * 0.5)
    draw_polygon([pp + Vector2(0, -16), pp + Vector2(12, 12), pp + Vector2(0, 6), pp + Vector2(-12, 12)], [Color(0.95, 0.9, 0.72)])
    draw_circle(pp, 7, Color(0.35, 0.22, 0.16))
    # HUD
    _panel(Rect2(0, 0, 1280, 60))
    _text("Food %d" % food, Vector2(24, 40), 20, Color(0.9, 0.7, 0.4))
    _text("Ink %d" % ink, Vector2(160, 40), 20, Color(0.5, 0.7, 0.9))
    _text("Rope %d" % rope, Vector2(280, 40), 20, Color(0.7, 0.6, 0.4))
    _text("Credits %d" % credits, Vector2(420, 40), 20, Color(0.95, 0.85, 0.4))
    _text("Explored %d/%d" % [_explored_count(), GRID * GRID], Vector2(620, 40), 18, Color(0.8, 0.9, 0.7))
    # minimap legend
    _text("E=annotate  SPACE=town(at town tile)", Vector2(900, 40), 14, Color(0.7, 0.8, 0.7))
    _draw_compass(Vector2(1130, 128))
    _text(msg, Vector2(40, 700), 16, Color(0.8, 0.9, 0.8))

func _draw_terrain_icon(terrain: String, r: Rect2) -> void:
    var c := r.get_center()
    if terrain == "forest":
        draw_polygon([c + Vector2(-10, 9), c + Vector2(0, -12), c + Vector2(10, 9)], [Color(0.04, 0.22, 0.08, 0.75)])
    elif terrain == "mountain":
        draw_polygon([c + Vector2(-14, 12), c + Vector2(0, -14), c + Vector2(14, 12)], [Color(0.30, 0.28, 0.25, 0.72)])
        draw_polygon([c + Vector2(-5, -5), c + Vector2(0, -14), c + Vector2(5, -5)], [Color(0.8, 0.78, 0.68, 0.6)])
    elif terrain == "water":
        draw_arc(c + Vector2(-7, 0), 9, 0, PI, 10, Color(0.75, 0.9, 1.0, 0.65), 2.0)
        draw_arc(c + Vector2(8, 2), 9, 0, PI, 10, Color(0.75, 0.9, 1.0, 0.65), 2.0)
    elif terrain == "ruin":
        draw_rect(Rect2(c + Vector2(-12, -10), Vector2(24, 20)), Color(0.28, 0.25, 0.22, 0.7), false, 2.0)
    elif terrain == "town":
        draw_rect(Rect2(c + Vector2(-12, -8), Vector2(24, 18)), Color(0.6, 0.44, 0.25, 0.8))
        draw_polygon([c + Vector2(-15, -8), c + Vector2(0, -20), c + Vector2(15, -8)], [Color(0.45, 0.18, 0.12, 0.8)])

func _draw_compass(c: Vector2) -> void:
    _panel(Rect2(c - Vector2(54, 54), Vector2(108, 108)), Color(0.05, 0.06, 0.04, 0.75))
    draw_circle(c, 32, Color(0.8, 0.7, 0.45, 0.16), false, 2.0)
    draw_line(c, c + Vector2(0, -34), Color(0.9, 0.82, 0.45), 3.0)
    draw_line(c, c + Vector2(0, 30), Color(0.55, 0.50, 0.35), 2.0)
    _text("N", c + Vector2(-6, -38), 13, Color(0.95, 0.86, 0.45))

func _draw_town() -> void:
    _draw_map()
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, 0.5))
    _panel(Rect2(300, 100, 680, 500))
    _text("TOWN", Vector2(560, 150), 34, Color(0.6, 0.8, 0.5))
    _text("Credits: %d   Explored: %d" % [credits, _explored_count()], Vector2(380, 190), 18, Color(0.9, 0.9, 0.8))
    _button(Rect2(380, 230, 520, 50), "Sell Map (earn %d)" % (_explored_count() * 2 + _annotated_count() * 5))
    _button(Rect2(380, 300, 520, 50), "Restock Supplies (free)")
    for i in range(UPGRADES.size()):
        var u: Dictionary = UPGRADES[i]
        _button(Rect2(380, 370 + i * 60, 520, 50), "%s — %d credits" % [str(u["name"]), int(u["cost"])], credits >= int(u["cost"]))
    _button(Rect2(380, 550, 520, 44), "LEAVE TOWN")

func _draw_result() -> void:
    _panel(Rect2(300, 180, 680, 320))
    if food <= 0:
        _text("STARVED", Vector2(480, 260), 44, Color(0.95, 0.4, 0.4))
        _text("You ran out of food in the wilderness.", Vector2(400, 320), 20, Color(0.85, 0.8, 0.8))
    else:
        _text("MAP COMPLETE!", Vector2(400, 260), 44, Color(0.5, 0.95, 0.5))
        _text("You charted the entire wilderness. Credits: %d" % credits, Vector2(380, 320), 20, Color(0.85, 0.92, 0.85))
    _button(Rect2(500, 420, 280, 54), "TITLE")

# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey:
        var p: bool = event.pressed
        match event.keycode:
            KEY_W, KEY_UP: move_dir["up"] = p
            KEY_S, KEY_DOWN: move_dir["down"] = p
            KEY_A, KEY_LEFT: move_dir["left"] = p
            KEY_D, KEY_RIGHT: move_dir["right"] = p
            KEY_E:
                if p and not event.echo: _annotate()
            KEY_SPACE:
                if p and not event.echo: _enter_town()
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _click(event.position)

func _click(pos: Vector2) -> void:
    if mode == "title":
        if Rect2(500, 410, 280, 64).has_point(pos):
            _start(); queue_redraw()
    elif mode == "town":
        if Rect2(380, 230, 520, 50).has_point(pos): _sell_map()
        elif Rect2(380, 300, 520, 50).has_point(pos): _restock()
        elif Rect2(380, 550, 520, 44).has_point(pos): _leave_town()
        else:
            for i in range(UPGRADES.size()):
                if Rect2(380, 370 + i * 60, 520, 50).has_point(pos):
                    _buy_upgrade(i); return
    elif mode == "result":
        if Rect2(500, 420, 280, 54).has_point(pos):
            mode = "title"; queue_redraw()
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_explore.json" <<'EOF'
{
  "duration_frames": 460,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 640, "y": 442},
    {"frame": 80,  "type": "key_down", "keycode": "D"},
    {"frame": 200, "type": "key_up", "keycode": "D"},
    {"frame": 240, "type": "key_down", "keycode": "S"},
    {"frame": 340, "type": "key_up", "keycode": "S"},
    {"frame": 380, "type": "key_press", "keycode": "E"},
    {"frame": 440, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_annotate.json" <<'EOF'
{
  "scenario": "explore",
  "duration_frames": 400,
  "events": [
    {"frame": 30,  "type": "key_down", "keycode": "D"},
    {"frame": 130, "type": "key_up", "keycode": "D"},
    {"frame": 160, "type": "key_press", "keycode": "E"},
    {"frame": 220, "type": "key_down", "keycode": "S"},
    {"frame": 300, "type": "key_up", "keycode": "S"},
    {"frame": 340, "type": "key_press", "keycode": "E"},
    {"frame": 380, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_town_sell.json" <<'EOF'
{
  "scenario": "sell",
  "duration_frames": 380,
  "events": [
    {"frame": 40,  "type": "mouse_click", "button": "left", "x": 640, "y": 255},
    {"frame": 120, "type": "mouse_click", "button": "left", "x": 640, "y": 325},
    {"frame": 200, "type": "key_press", "keycode": "1"},
    {"frame": 300, "type": "mouse_click", "button": "left", "x": 640, "y": 572},
    {"frame": 360, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_danger.json" <<'EOF'
{
  "scenario": "danger",
  "duration_frames": 400,
  "events": [
    {"frame": 30,  "type": "key_down", "keycode": "D"},
    {"frame": 200, "type": "key_up", "keycode": "D"},
    {"frame": 240, "type": "key_down", "keycode": "S"},
    {"frame": 380, "type": "key_up", "keycode": "S"}
  ]
}
EOF

cat > "$GAME/demo_outputs/05_upgrade.json" <<'EOF'
{
  "scenario": "town",
  "duration_frames": 360,
  "events": [
    {"frame": 40,  "type": "mouse_click", "button": "left", "x": 640, "y": 255},
    {"frame": 100, "type": "mouse_click", "button": "left", "x": 640, "y": 395},
    {"frame": 180, "type": "mouse_click", "button": "left", "x": 640, "y": 455},
    {"frame": 260, "type": "mouse_click", "button": "left", "x": 640, "y": 572},
    {"frame": 340, "type": "wait"}
  ]
}
EOF

echo "cartographer oracle generated at $GAME"
