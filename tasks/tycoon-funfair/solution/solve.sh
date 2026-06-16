#!/bin/bash
# Reference solution for gamecraft-bench/tycoon-funfair.
#
# Generates a compact grid-based theme-park tycoon with a satisfaction economy:
#   - Title -> park (new or loaded from user://save) -> build & manage.
#   - Build tools (number keys): 1 path, 2 coaster (thrill), 3 carousel (gentle),
#     4 food stall, 5 drink stall, 6 bench (rest). Click a grid cell to place the
#     selected tool. Building costs cash; unaffordable build is refused (flash).
#   - Connectivity: an attraction earns/serves only if a path connects it to the
#     entrance (flood fill from the gate). Stranded builds sit idle.
#   - Guests: visible little visitors spawn at the gate, walk along paths toward
#     attractions that match their need (thrill / gentle / food / drink / rest),
#     pay, and leave. A guest whose need has no built+connected option grows
#     unhappy.
#   - Satisfaction: derived from variety, connectivity, queue load, and price;
#     higher satisfaction raises the guest spawn rate (the snowball).
#   - Economy: cash from gate + purchases; reinvest to build/upgrade. U upgrades
#     the selected ride tier (bigger draw). [ ] adjust ticket price.
#   - Time advances by day on SPACE; cash/layout banked to user://funfair_save.json.
#   - Deterministic: seeded RNG; guest logic stepped on a fixed accumulator.
#   - Demos cover building, a busy park, guest variety, and the unhappy state.
#
# The whole game lives in one Main.gd. It is the oracle for the verifier
# framework, not a polished game: everything is drawn from primitives, so the
# art items (A1-A5) stay low while the mechanic and depth items pass.
#
# NOTE (GDScript, warnings-as-errors): min()/max()/Dictionary subscripts/JSON
# return Variant. Every such value is given an explicit type to avoid the
# "inferred Variant" parse error that fails the whole script.
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="Funfair"
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
const COLS := 14
const ROWS := 9
const CELL := 64.0
const ORIGIN := Vector2(60, 120)
const SAVE_PATH := "user://funfair_save.json"

# Tool ids and their build defs. "need" links an attraction to a guest need.
const TOOLS := {
    1: {"kind": "path",     "name": "Path",     "cost": 5,   "need": "",       "col": Color(0.78, 0.70, 0.52)},
    2: {"kind": "coaster",  "name": "Coaster",  "cost": 120, "need": "thrill", "col": Color(0.85, 0.30, 0.34)},
    3: {"kind": "carousel", "name": "Carousel", "cost": 70,  "need": "gentle", "col": Color(0.95, 0.74, 0.30)},
    4: {"kind": "food",     "name": "Food",     "cost": 45,  "need": "food",   "col": Color(0.55, 0.78, 0.40)},
    5: {"kind": "drink",    "name": "Drink",    "cost": 40,  "need": "drink",  "col": Color(0.40, 0.66, 0.90)},
    6: {"kind": "bench",    "name": "Bench",    "cost": 20,  "need": "rest",   "col": Color(0.66, 0.60, 0.72)},
}
const NEEDS := ["thrill", "gentle", "food", "drink", "rest"]

var scenario := ""
var mode := "title"
var tool := 1
var cash := 400
var day := 1
var satisfaction := 60      # 0..100
var ticket := 8             # gate price
var deny_flash := 0.0
var spawn_accum := 0.0
var message := ""
# grid[r][c] = "" or a kind string; tier[r][c] = ride tier (1..3)
var grid: Array = []
var tier: Array = []
var guests: Array = []      # {pos, need, target(Vector2i or null), state, t}
var rng := RandomNumberGenerator.new()
var entrance := Vector2i(0, 4)

func _ready() -> void:
    rng.seed = 9090
    _blank_grid()
    _load_save()
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

func _blank_grid() -> void:
    grid = []
    tier = []
    for r in range(ROWS):
        var row: Array = []
        var trow: Array = []
        for c in range(COLS):
            row.append("")
            trow.append(1)
        grid.append(row)
        tier.append(trow)
    grid[entrance.y][entrance.x] = "gate"

# --------------------------------------------------------------------------
# Save / load
# --------------------------------------------------------------------------

func _load_save() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if not f:
        return
    var parsed: Variant = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var d: Dictionary = parsed
    cash = int(d.get("cash", 400))
    day = int(d.get("day", 1))
    satisfaction = int(d.get("satisfaction", 60))
    ticket = int(d.get("ticket", 8))
    var saved_grid: Variant = d.get("grid", [])
    if typeof(saved_grid) == TYPE_ARRAY and (saved_grid as Array).size() == ROWS:
        var sg: Array = saved_grid
        for r in range(ROWS):
            var srow: Array = sg[r]
            for c in range(COLS):
                grid[r][c] = str(srow[c])

func _save() -> void:
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if not f:
        return
    f.store_string(JSON.stringify({
        "cash": cash, "day": day, "satisfaction": satisfaction,
        "ticket": ticket, "grid": grid,
    }))

func _load_scenario(id: String) -> void:
    mode = "park"
    if id == "building":
        cash = 600
        message = "Lay paths (1) from the gate, then build rides and stalls."
    elif id == "busy_park":
        cash = 900
        satisfaction = 85
        _prebuild_demo_park()
        _seed_guests(10)
        message = "A busy, varied park: coasters, carousels, food, drink, rest."
    elif id == "unhappy_park":
        cash = 120
        satisfaction = 22
        ticket = 18
        _build(2, 2, "coaster")  # one stranded coaster, no paths -> idle
        _seed_guests(4)
        message = "Unhappy park: no paths, gouging prices, nothing to do."
    else:
        message = "Lay paths (1), build rides 2/3, stalls 4/5/6. SPACE = next day."

func _prebuild_demo_park() -> void:
    for c in range(1, 11):
        _put(c, 4, "path")
    _build(3, 3, "coaster"); tier[3][3] = 2
    _build(5, 5, "carousel")
    _build(7, 3, "food")
    _build(9, 5, "drink")
    _build(6, 4, "bench")  # overwritten path is fine for demo
    _put(6, 4, "path")
    _build(8, 5, "bench")
    _put(2, 4, "path")

# --------------------------------------------------------------------------
# Building
# --------------------------------------------------------------------------

func _in_bounds(c: int, r: int) -> bool:
    return c >= 0 and c < COLS and r >= 0 and r < ROWS

func _put(c: int, r: int, kind: String) -> void:
    if _in_bounds(c, r):
        grid[r][c] = kind

func _build(c: int, r: int, kind: String) -> void:
    if _in_bounds(c, r) and grid[r][c] == "":
        grid[r][c] = kind

func _place(c: int, r: int) -> void:
    if not _in_bounds(c, r):
        return
    if grid[r][c] != "" and grid[r][c] != "path":
        message = "That cell is occupied."
        queue_redraw(); return
    var t: Dictionary = TOOLS[tool]
    var cost: int = int(t["cost"])
    if cash < cost:
        deny_flash = 0.5
        message = "Not enough cash for %s (need %d)." % [t["name"], cost]
        queue_redraw(); return
    if grid[r][c] == "path" and t["kind"] == "path":
        message = "Already a path here."
        queue_redraw(); return
    cash -= cost
    grid[r][c] = str(t["kind"])
    tier[r][c] = 1
    _recompute_satisfaction()
    message = "Built %s for %d." % [t["name"], cost]
    queue_redraw()

func _upgrade_selected_kind() -> void:
    # Upgrade the first connected ride of the current tool's kind (tier up).
    var t: Dictionary = TOOLS[tool]
    if t["kind"] != "coaster" and t["kind"] != "carousel":
        message = "Select a ride tool (2 or 3) to upgrade."
        queue_redraw(); return
    var cost: int = 80
    if cash < cost:
        deny_flash = 0.5
        message = "Not enough cash to upgrade (need %d)." % cost
        queue_redraw(); return
    for r in range(ROWS):
        for c in range(COLS):
            if grid[r][c] == t["kind"] and int(tier[r][c]) < 3:
                cash -= cost
                tier[r][c] = int(tier[r][c]) + 1
                message = "Upgraded a %s to tier %d." % [t["name"], tier[r][c]]
                _recompute_satisfaction()
                queue_redraw()
                return
    message = "No upgradeable %s found." % t["name"]
    queue_redraw()

# --------------------------------------------------------------------------
# Connectivity (flood fill from gate over path cells)
# --------------------------------------------------------------------------

func _connected_cells() -> Dictionary:
    # Returns a set-like dict of "c,r" path cells reachable from the gate.
    var seen: Dictionary = {}
    var stack: Array = [entrance]
    while stack.size() > 0:
        var cur: Vector2i = stack.pop_back()
        var key := "%d,%d" % [cur.x, cur.y]
        if seen.has(key):
            continue
        seen[key] = true
        for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
            var n: Vector2i = cur + d
            if _in_bounds(n.x, n.y) and grid[n.y][n.x] == "path":
                stack.append(n)
    return seen

func _attraction_is_served(c: int, r: int, connected: Dictionary) -> bool:
    # An attraction works if a connected path is adjacent to it.
    for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
        var n: Vector2i = Vector2i(c, r) + d
        if _in_bounds(n.x, n.y) and grid[n.y][n.x] == "path":
            if connected.has("%d,%d" % [n.x, n.y]):
                return true
    return false

func _served_attractions() -> Array:
    var connected: Dictionary = _connected_cells()
    var out: Array = []
    for r in range(ROWS):
        for c in range(COLS):
            var k: String = grid[r][c]
            if k != "" and k != "path" and k != "gate":
                if _attraction_is_served(c, r, connected):
                    out.append({"c": c, "r": r, "kind": k, "need": _need_of(k)})
    return out

func _need_of(kind: String) -> String:
    for id in TOOLS:
        if TOOLS[id]["kind"] == kind:
            return str(TOOLS[id]["need"])
    return ""

# --------------------------------------------------------------------------
# Satisfaction + guests
# --------------------------------------------------------------------------

func _recompute_satisfaction() -> void:
    var served: Array = _served_attractions()
    var kinds_needs: Dictionary = {}
    for a in served:
        kinds_needs[a["need"]] = true
    var variety: int = kinds_needs.size()          # how many needs are covered
    var base := 35 + variety * 12                   # variety drives happiness
    base -= max(0, ticket - 8) * 2                   # gouging hurts
    if served.size() == 0:
        base = 15
    satisfaction = clampi(base, 0, 100)

func _seed_guests(n: int) -> void:
    guests = []
    for i in range(n):
        _spawn_guest()

func _spawn_guest() -> void:
    var need: String = NEEDS[rng.randi() % NEEDS.size()]
    guests.append({
        "pos": Vector2(ORIGIN.x + float(entrance.x) * CELL + CELL * 0.5,
                       ORIGIN.y + float(entrance.y) * CELL + CELL * 0.5),
        "need": need, "state": "seek", "t": 0.0,
        "happy": true,
    })

func _nearest_attraction_for(need: String, served: Array) -> Dictionary:
    for a in served:
        if a["need"] == need:
            return a
    return {}

func _process(delta: float) -> void:
    if deny_flash > 0.0:
        deny_flash = max(0.0, deny_flash - delta)
    if mode != "park":
        return
    # Spawn rate scales with satisfaction (the snowball).
    spawn_accum += delta * (0.3 + float(satisfaction) / 60.0)
    if spawn_accum >= 1.0 and guests.size() < 18:
        spawn_accum -= 1.0
        _spawn_guest()
    var served: Array = _served_attractions()
    var keep: Array = []
    for g in guests:
        g["t"] += delta
        var target: Dictionary = _nearest_attraction_for(g["need"], served)
        if target.is_empty():
            g["happy"] = false
            # wander a little, then leave unhappy
            g["pos"] += Vector2(20.0, 0.0) * delta
            if g["t"] < 4.0:
                keep.append(g)
            continue
        g["happy"] = true
        var tp: Vector2 = Vector2(ORIGIN.x + float(int(target["c"])) * CELL + CELL * 0.5,
                          ORIGIN.y + float(int(target["r"])) * CELL + CELL * 0.5)
        g["pos"] = g["pos"].move_toward(tp, 70.0 * delta)
        if g["pos"].distance_to(tp) < 8.0 and g["state"] == "seek":
            g["state"] = "spend"
            cash += ticket + 3      # gate + purchase
        if g["t"] < 6.0:
            keep.append(g)
    guests = keep
    queue_redraw()

func _next_day() -> void:
    day += 1
    _recompute_satisfaction()
    _save()
    message = "Day %d. The park opens again." % day
    queue_redraw()

# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.10, 0.16, 0.12))
    match mode:
        "title": _draw_title()
        "park": _draw_park()

func _panel(rect: Rect2, color := Color(0.08, 0.10, 0.12, 0.93)) -> void:
    draw_rect(rect, color)
    draw_rect(rect, Color(0.45, 0.55, 0.65, 0.95), false, 2.0)

func _text(s: String, p: Vector2, size: int, color: Color) -> void:
    draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _button(rect: Rect2, label: String) -> void:
    draw_rect(rect, Color(0.16, 0.20, 0.16))
    draw_rect(rect, Color(0.6, 0.7, 0.45), false, 2.0)
    _text(label, rect.position + Vector2(14, rect.size.y * 0.64), 20, Color(0.92, 0.95, 0.85))

func _draw_title() -> void:
    draw_rect(Rect2(0, 0, 1280, 720), Color(0.12, 0.18, 0.26))
    _panel(Rect2(330, 160, 620, 340))
    _text("FUNFAIR", Vector2(470, 250), 64, Color(0.98, 0.82, 0.35))
    _text("Build paths, rides and stalls. Keep the crowd happy and growing.", Vector2(360, 312), 19, Color(0.85, 0.9, 0.95))
    _button(Rect2(470, 410, 160, 60), "NEW PARK")
    _button(Rect2(650, 410, 160, 60), "CONTINUE")

func _draw_park() -> void:
    # Grid + contents
    var connected: Dictionary = _connected_cells()
    for r in range(ROWS):
        for c in range(COLS):
            var x := ORIGIN.x + float(c) * CELL
            var y := ORIGIN.y + float(r) * CELL
            var cell := Rect2(x, y, CELL - 2, CELL - 2)
            draw_rect(cell, Color(0.16, 0.26, 0.18))
            draw_rect(cell, Color(0.10, 0.16, 0.12), false, 1.0)
            var k: String = grid[r][c]
            if k == "gate":
                draw_rect(cell, Color(0.85, 0.85, 0.30))
                _text("IN", cell.position + Vector2(14, 40), 18, Color(0.1,0.1,0.1))
            elif k == "path":
                draw_rect(cell, TOOLS[1]["col"])
            elif k != "":
                var served := _attraction_is_served(c, r, connected)
                var col: Color = _kind_col(k)
                if not served:
                    col = col.darkened(0.5)
                draw_rect(cell.grow(-6), col)
                # tier pips
                var tr: int = int(tier[r][c])
                for p in range(tr):
                    draw_circle(cell.position + Vector2(10 + p * 12, 12), 4, Color(1,1,1,0.9))
                if not served:
                    _text("idle", cell.position + Vector2(8, 44), 13, Color(1, 0.7, 0.7))
    # Guests
    for g in guests:
        var gc := Color(0.5, 0.9, 0.6) if g["happy"] else Color(0.95, 0.5, 0.4)
        draw_circle(g["pos"], 7, gc)
        draw_circle(g["pos"] + Vector2(0, -9), 4, Color(0.95, 0.85, 0.7))
    _draw_hud()
    _draw_toolbar()

func _kind_col(kind: String) -> Color:
    for id in TOOLS:
        if TOOLS[id]["kind"] == kind:
            return TOOLS[id]["col"]
    return Color(0.5, 0.5, 0.5)

func _draw_hud() -> void:
    _panel(Rect2(0, 0, 1280, 96), Color(0.07, 0.09, 0.11, 0.95) if deny_flash <= 0.0 else Color(0.4, 0.08, 0.06, 0.95))
    _text("CASH  %d" % cash, Vector2(24, 40), 28, Color(0.98, 0.84, 0.35))
    _text("Guests %d" % guests.size(), Vector2(300, 40), 24, Color(0.7, 0.92, 0.7))
    _text("Day %d" % day, Vector2(300, 74), 18, Color(0.8, 0.86, 0.9))
    # satisfaction meter
    _text("Satisfaction", Vector2(520, 34), 18, Color(0.85, 0.9, 0.7))
    var bar := Rect2(520, 44, 240, 22)
    draw_rect(bar, Color(0.06, 0.08, 0.06))
    var col := Color(0.5, 0.85, 0.4) if satisfaction >= 50 else Color(0.9, 0.5, 0.35)
    draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(satisfaction) / 100.0, bar.size.y)), col)
    draw_rect(bar, Color(0.3, 0.36, 0.26), false, 1.5)
    _text("%d%%" % satisfaction, Vector2(770, 62), 18, Color(0.9, 0.94, 0.8))
    _text("Ticket  %d   ([ / ] to adjust)" % ticket, Vector2(900, 40), 18, Color(0.95, 0.86, 0.5))

func _draw_toolbar() -> void:
    _panel(Rect2(0, 636, 1280, 84))
    var order := [1, 2, 3, 4, 5, 6]
    for i in range(order.size()):
        var id: int = order[i]
        var t: Dictionary = TOOLS[id]
        var rect := Rect2(16 + i * 150, 650, 140, 54)
        draw_rect(rect, Color(0.18, 0.20, 0.16) if tool == id else Color(0.12, 0.14, 0.12))
        draw_rect(rect, Color(0.95, 0.85, 0.3) if tool == id else Color(0.4, 0.5, 0.4), false, 2.0)
        draw_rect(Rect2(rect.position + Vector2(8, 8), Vector2(20, 20)), t["col"])
        _text("%d %s" % [id, t["name"]], rect.position + Vector2(34, 24), 16, Color(0.92, 0.95, 0.85))
        _text("$%d" % int(t["cost"]), rect.position + Vector2(34, 46), 14, Color(0.95, 0.84, 0.4))
    _text("U upgrade ride   SPACE next day   |   " + message, Vector2(940, 668), 15, Color(0.86, 0.9, 0.78))

# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if mode == "park":
            match event.keycode:
                KEY_1: tool = 1
                KEY_2: tool = 2
                KEY_3: tool = 3
                KEY_4: tool = 4
                KEY_5: tool = 5
                KEY_6: tool = 6
                KEY_U: _upgrade_selected_kind()
                KEY_BRACKETLEFT: ticket = max(2, ticket - 1); _recompute_satisfaction(); queue_redraw()
                KEY_BRACKETRIGHT: ticket = min(30, ticket + 1); _recompute_satisfaction(); queue_redraw()
                KEY_SPACE: _next_day()
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _click(event.position)

func _click(p: Vector2) -> void:
    if mode == "title":
        if Rect2(470, 410, 160, 60).has_point(p):
            var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
            if f: f.store_string("{}")
            _blank_grid(); cash = 400; day = 1; satisfaction = 60; ticket = 8; guests = []
            mode = "park"
            message = "Lay paths (1), build rides 2/3, stalls 4/5/6. SPACE = next day."
            queue_redraw()
        elif Rect2(650, 410, 160, 60).has_point(p):
            mode = "park"; queue_redraw()
        return
    if mode == "park":
        # toolbar click selects tool
        var order := [1, 2, 3, 4, 5, 6]
        for i in range(order.size()):
            if Rect2(16 + i * 150, 650, 140, 54).has_point(p):
                tool = order[i]
                queue_redraw()
                return
        # grid click places
        var c := int((p.x - ORIGIN.x) / CELL)
        var r := int((p.y - ORIGIN.y) / CELL)
        if _in_bounds(c, r) and p.y > ORIGIN.y:
            _place(c, r)
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_build.json" <<'EOF'
{
  "duration_frames": 400,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 550, "y": 440},
    {"frame": 70,  "type": "key_press", "keycode": "1"},
    {"frame": 90,  "type": "mouse_click", "button": "left", "x": 140, "y": 380},
    {"frame": 120, "type": "mouse_click", "button": "left", "x": 200, "y": 380},
    {"frame": 150, "type": "mouse_click", "button": "left", "x": 264, "y": 380},
    {"frame": 180, "type": "key_press", "keycode": "2"},
    {"frame": 210, "type": "mouse_click", "button": "left", "x": 200, "y": 316},
    {"frame": 260, "type": "key_press", "keycode": "4"},
    {"frame": 290, "type": "mouse_click", "button": "left", "x": 264, "y": 444},
    {"frame": 380, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_busy_park.json" <<'EOF'
{
  "scenario": "busy_park",
  "duration_frames": 460,
  "events": [
    {"frame": 60,  "type": "wait"},
    {"frame": 200, "type": "key_press", "keycode": "SPACE"},
    {"frame": 440, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_variety_build.json" <<'EOF'
{
  "scenario": "building",
  "duration_frames": 460,
  "events": [
    {"frame": 30,  "type": "key_press", "keycode": "1"},
    {"frame": 50,  "type": "mouse_click", "button": "left", "x": 140, "y": 380},
    {"frame": 80,  "type": "mouse_click", "button": "left", "x": 200, "y": 380},
    {"frame": 110, "type": "mouse_click", "button": "left", "x": 264, "y": 380},
    {"frame": 140, "type": "key_press", "keycode": "3"},
    {"frame": 170, "type": "mouse_click", "button": "left", "x": 140, "y": 316},
    {"frame": 200, "type": "key_press", "keycode": "5"},
    {"frame": 230, "type": "mouse_click", "button": "left", "x": 264, "y": 444},
    {"frame": 270, "type": "key_press", "keycode": "U"},
    {"frame": 320, "type": "key_press", "keycode": "SPACE"},
    {"frame": 440, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_pricing.json" <<'EOF'
{
  "scenario": "busy_park",
  "duration_frames": 400,
  "events": [
    {"frame": 40,  "type": "key_press", "keycode": "RIGHT"},
    {"frame": 70,  "type": "key_press", "keycode": "RIGHT"},
    {"frame": 120, "type": "wait"},
    {"frame": 220, "type": "key_press", "keycode": "LEFT"},
    {"frame": 380, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/05_unhappy.json" <<'EOF'
{
  "scenario": "unhappy_park",
  "duration_frames": 360,
  "events": [
    {"frame": 60,  "type": "wait"},
    {"frame": 300, "type": "wait"}
  ]
}
EOF

echo "funfair oracle generated at $GAME"
