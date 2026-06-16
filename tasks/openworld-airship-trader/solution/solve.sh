#!/bin/bash
# Reference solution for gamecraft-bench/openworld-airship-trader.
#
# A compact 2D airship trading game:
#   - Title -> sky map with floating islands. Pilot airship with WASD (momentum).
#   - Dock at islands (SPACE near one) to open trade: buy/sell goods at
#     island-specific prices. Buy low, sell high across islands.
#   - Sky pirates chase the player along routes; contact = combat (auto-resolve
#     with HP loss or flee). Defeating pirates drops loot.
#   - Earn credits -> upgrade ship (speed, cargo, armor) at a shipyard island.
#   - HUD: credits, cargo, HP, current goods. Result screen on death or
#     reaching a profit goal.
#   - Scenarios jump to trade / combat / upgrade for deterministic demos.
#
# Oracle for the verifier: primitives only, art items (A*) stay low.
# Logic in _physics_process for deterministic replay.
#
# NOTE (GDScript warnings-as-errors): explicit types on Dictionary-subscript
# derived values to avoid inferred-Variant parse errors.
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="AirshipTrader"
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
const SHIP_R := 16.0
const DOCK_DIST := 60.0
const PIRATE_SPD := 80.0
const MAX_HP := 10
const MAX_FUEL := 100.0
const PROFIT_GOAL := 500

const ISLANDS := [
    {"name": "Port Nimbus", "pos": Vector2(200, 360), "col": Color(0.4, 0.7, 0.9),
     "buy": {"Spice": 10, "Ore": 30}, "sell": {"Silk": 40, "Gem": 80}},
    {"name": "Ember Rock", "pos": Vector2(640, 180), "col": Color(0.9, 0.5, 0.3),
     "buy": {"Ore": 8, "Gem": 50}, "sell": {"Spice": 25, "Ore": 18}},
    {"name": "Verdant Isle", "pos": Vector2(1060, 500), "col": Color(0.3, 0.8, 0.4),
     "buy": {"Silk": 12, "Spice": 18}, "sell": {"Ore": 35, "Gem": 90}},
    {"name": "Skyforge", "pos": Vector2(400, 580), "col": Color(0.7, 0.6, 0.9),
     "buy": {}, "sell": {}, "shipyard": true},
]

const UPGRADES := [
    {"name": "Engine+", "cost": 80, "stat": "speed", "val": 40},
    {"name": "Cargo+", "cost": 100, "stat": "cargo", "val": 2},
    {"name": "Armor+", "cost": 120, "stat": "armor", "val": 3},
]

var scenario := ""
var mode := "title"          # title, fly, trade, shipyard, result
var pos := Vector2(200, 360)
var vel := Vector2.ZERO
var move := {"up": false, "down": false, "left": false, "right": false}
var credits := 50
var hp := MAX_HP
var fuel := MAX_FUEL
var cargo: Array = []        # goods carried: [{name, qty}]
var max_cargo := 4
var speed := 140.0
var armor := 0
var docked_idx := -1
var pirates: Array = []      # {pos, alive}
var shots: Array = []        # {pos, vel}
var won := false
var anim := 0.0
var msg := ""

func _ready() -> void:
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

func _load_scenario(id: String) -> void:
    if id == "title_flow":
        mode = "title"
    elif id == "fly":
        _start(); mode = "fly"
    elif id == "trade":
        _start(); mode = "trade"; docked_idx = 0
    elif id == "combat":
        _start(); mode = "fly"
        pirates = [
            {"pos": Vector2(560, 300), "alive": true},
            {"pos": Vector2(820, 470), "alive": true}
        ]
    elif id == "shipyard":
        _start(); credits = 200; mode = "shipyard"; docked_idx = 3
    elif id == "near_goal":
        _start(); credits = PROFIT_GOAL - 20; mode = "fly"
    else:
        _start(); mode = "fly"

func _start() -> void:
    mode = "fly"
    pos = Vector2(200, 360)
    vel = Vector2.ZERO
    credits = 50
    hp = MAX_HP
    fuel = MAX_FUEL
    cargo = []
    max_cargo = 4
    speed = 140.0
    armor = 0
    docked_idx = -1
    pirates = [{"pos": Vector2(800, 300), "alive": true}]
    shots = []
    won = false
    msg = "Fly to islands, trade goods, avoid pirates. WASD move, SPACE dock, F fires cannon."

func _cargo_count() -> int:
    var c := 0
    for g in cargo:
        c += int(g["qty"])
    return c

func _physics_process(delta: float) -> void:
    anim += delta
    if mode != "fly":
        return
    var dir := Vector2.ZERO
    if move["up"]: dir.y -= 1
    if move["down"]: dir.y += 1
    if move["left"]: dir.x -= 1
    if move["right"]: dir.x += 1
    var thrust := dir.normalized()
    if fuel <= 0.0:
        thrust = Vector2.ZERO
        msg = "Out of fuel. Drift to a port or collect a fuel crate."
    vel = vel.lerp(thrust * speed, 3.0 * delta)
    pos += vel * delta
    pos.x = clampf(pos.x, 40, VIEW.x - 40)
    pos.y = clampf(pos.y, 40, VIEW.y - 40)
    if thrust.length() > 0:
        fuel = max(0.0, fuel - 7.0 * delta)

    var keep_shots: Array = []
    for s in shots:
        s["pos"] += s["vel"] * delta
        var hit := false
        for p in pirates:
            if p["alive"] and s["pos"].distance_to(p["pos"]) < 22.0:
                p["alive"] = false
                credits += 45
                msg = "Cannon hit! Pirate defeated, +45 credits."
                hit = true
                break
        if not hit and Rect2(0, 0, VIEW.x, VIEW.y).has_point(s["pos"]):
            keep_shots.append(s)
    shots = keep_shots

    # pirates chase
    for p in pirates:
        if not p["alive"]:
            continue
        var d: Vector2 = pos - p["pos"]
        p["pos"] += d.normalized() * PIRATE_SPD * delta
        if d.length() < SHIP_R + 20.0:
            _pirate_combat(p)

    if credits >= PROFIT_GOAL:
        _finish(true)
    queue_redraw()

func _pirate_combat(p: Dictionary) -> void:
    var dmg: int = max(1, 3 - armor)
    hp -= dmg
    p["alive"] = false
    credits += 30
    msg = "Pirate defeated! -%d HP, +30 credits." % dmg
    if hp <= 0:
        _finish(false)

func _fire_cannon() -> void:
    if mode != "fly":
        return
    var target := Vector2.ZERO
    var best := 99999.0
    for p in pirates:
        if p["alive"]:
            var dist := pos.distance_to(p["pos"])
            if dist < best:
                best = dist
                target = p["pos"]
    if best >= 99999.0:
        msg = "No pirate in sight."
        queue_redraw()
        return
    var dir := (target - pos).normalized()
    shots.append({"pos": pos + dir * 22.0, "vel": dir * 520.0})
    msg = "Cannon fired at pirate patrol."
    queue_redraw()

func _try_dock() -> void:
    if mode != "fly":
        return
    for i in range(ISLANDS.size()):
        var isl: Dictionary = ISLANDS[i]
        if pos.distance_to(isl["pos"]) < DOCK_DIST:
            docked_idx = i
            fuel = MAX_FUEL
            if isl.has("shipyard"):
                mode = "shipyard"
            else:
                mode = "trade"
            msg = "Docked at %s. Fuel refilled." % str(isl["name"])
            queue_redraw()
            return
    msg = "No island nearby to dock."
    queue_redraw()

func _buy(good: String, price: int) -> void:
    if credits < price or _cargo_count() >= max_cargo:
        msg = "Can't buy (no credits or cargo full)."
        queue_redraw(); return
    credits -= price
    # add to cargo
    var found := false
    for g in cargo:
        if str(g["name"]) == good:
            g["qty"] = int(g["qty"]) + 1
            found = true; break
    if not found:
        cargo.append({"name": good, "qty": 1})
    msg = "Bought %s for %d." % [good, price]
    queue_redraw()

func _sell(good: String, price: int) -> void:
    for g in cargo:
        if str(g["name"]) == good and int(g["qty"]) > 0:
            g["qty"] = int(g["qty"]) - 1
            credits += price
            msg = "Sold %s for %d." % [good, price]
            queue_redraw(); return
    msg = "You don't have %s to sell." % good
    queue_redraw()

func _upgrade(idx: int) -> void:
    if idx < 0 or idx >= UPGRADES.size():
        return
    var u: Dictionary = UPGRADES[idx]
    var cost: int = int(u["cost"])
    if credits < cost:
        msg = "Not enough credits for %s." % str(u["name"])
        queue_redraw(); return
    credits -= cost
    var stat: String = str(u["stat"])
    if stat == "speed": speed += float(u["val"])
    elif stat == "cargo": max_cargo += int(u["val"])
    elif stat == "armor": armor += int(u["val"])
    msg = "Upgraded %s!" % str(u["name"])
    queue_redraw()

func _undock() -> void:
    docked_idx = -1
    mode = "fly"
    msg = "Back in the sky."
    queue_redraw()

func _finish(victory: bool) -> void:
    won = victory
    mode = "result"
    queue_redraw()

# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.08, 0.12, 0.22))
    match mode:
        "title": _draw_title()
        "fly": _draw_sky()
        "trade": _draw_trade()
        "shipyard": _draw_shipyard()
        "result": _draw_result()

func _text(s: String, p: Vector2, sz: int, c: Color) -> void:
    draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)

func _panel(r: Rect2, c := Color(0.06, 0.08, 0.14, 0.93)) -> void:
    draw_rect(r, c); draw_rect(r, Color(0.4, 0.6, 0.8, 0.9), false, 2.0)

func _button(r: Rect2, label: String, on := true) -> void:
    draw_rect(r, Color(0.10, 0.14, 0.22) if on else Color(0.18, 0.10, 0.10))
    draw_rect(r, Color(0.5, 0.7, 0.9) if on else Color(0.5, 0.3, 0.3), false, 2.0)
    _text(label, r.position + Vector2(14, r.size.y * 0.64), 18, Color(0.88, 0.92, 0.96))

func _draw_sky() -> void:
    # parallax clouds
    for i in range(12):
        var cx := fmod(float(i) * 130.0 + anim * 8.0, 1400.0) - 60.0
        draw_circle(Vector2(cx, 100 + float(i % 4) * 160), 40, Color(0.2, 0.25, 0.35, 0.4))
    # islands
    for i in range(ISLANDS.size() - 1):
        draw_line(ISLANDS[i]["pos"], ISLANDS[i + 1]["pos"], Color(0.55, 0.7, 0.95, 0.18), 3.0)
    for isl in ISLANDS:
        var ic: Color = isl["col"]
        draw_circle(isl["pos"], 44, ic)
        draw_circle(isl["pos"], 44, Color(ic.r * 0.6, ic.g * 0.6, ic.b * 0.6), false, 3.0)
        _text(str(isl["name"]), isl["pos"] + Vector2(-40, 56), 14, Color(0.85, 0.9, 0.95))
    # pirates
    for p in pirates:
        if p["alive"]:
            draw_polygon([p["pos"] + Vector2(-22, 10), p["pos"] + Vector2(20, 0), p["pos"] + Vector2(-22, -10)], [Color(0.9, 0.25, 0.25)])
            draw_line(p["pos"] + Vector2(-10, -16), p["pos"] + Vector2(-10, -42), Color(0.95, 0.95, 0.95), 2.0)
            draw_polygon([p["pos"] + Vector2(-8, -40), p["pos"] + Vector2(18, -30), p["pos"] + Vector2(-8, -20)], [Color(0.12, 0.12, 0.16)])
            _text("PIRATE", p["pos"] + Vector2(-30, 32), 12, Color(1, 0.55, 0.55))
    for s in shots:
        draw_circle(s["pos"], 5, Color(1.0, 0.85, 0.25))
    # player ship
    draw_polygon([pos + Vector2(24, 0), pos + Vector2(-18, -14), pos + Vector2(-10, 0), pos + Vector2(-18, 14)], [Color(0.5, 0.8, 1.0)])
    draw_circle(pos + Vector2(-8, 0), 12, Color(0.35, 0.55, 0.95, 0.85))
    if vel.length() > 5.0:
        draw_line(pos - vel.normalized() * 16.0, pos - vel.normalized() * 34.0, Color(1, 0.8, 0.35, 0.65), 4.0)
    _draw_hud()

func _draw_hud() -> void:
    _panel(Rect2(0, 0, 1280, 54))
    _text("Credits %d" % credits, Vector2(24, 36), 22, Color(0.95, 0.85, 0.4))
    _text("HP %d/%d" % [hp, MAX_HP], Vector2(220, 36), 20, Color(0.8, 0.9, 0.8))
    _text("Cargo %d/%d" % [_cargo_count(), max_cargo], Vector2(400, 36), 20, Color(0.7, 0.85, 0.95))
    _text("Fuel %d%%" % int(fuel), Vector2(540, 36), 20, Color(0.8, 0.9, 0.55))
    var goods_str := ""
    for g in cargo:
        if int(g["qty"]) > 0:
            goods_str += "%s×%d " % [str(g["name"]), int(g["qty"])]
    _text(goods_str if goods_str != "" else "(empty)", Vector2(680, 36), 16, Color(0.8, 0.85, 0.9))
    _text("Goal: %d credits" % PROFIT_GOAL, Vector2(1050, 36), 16, Color(0.9, 0.8, 0.5))
    _text(msg, Vector2(40, 700), 16, Color(0.8, 0.85, 0.9))

func _draw_title() -> void:
    _panel(Rect2(330, 150, 620, 340))
    _text("AIRSHIP TRADER", Vector2(410, 250), 50, Color(0.5, 0.8, 0.95))
    _text("Buy low, sell high, dodge pirates, upgrade your ship.", Vector2(370, 312), 18, Color(0.8, 0.88, 0.95))
    _button(Rect2(500, 410, 280, 64), "SET SAIL")

func _draw_trade() -> void:
    _draw_sky()
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, 0.5))
    var isl: Dictionary = ISLANDS[docked_idx]
    _panel(Rect2(240, 100, 800, 500))
    _text("TRADE — %s" % str(isl["name"]), Vector2(280, 150), 30, Color(0.5, 0.8, 0.95))
    _text("Credits: %d   Cargo: %d/%d" % [credits, _cargo_count(), max_cargo], Vector2(280, 190), 18, Color(0.9, 0.9, 0.8))
    var y := 230
    _text("BUY:", Vector2(280, y), 20, Color(0.7, 0.95, 0.7)); y += 30
    var buy_dict: Dictionary = isl.get("buy", {})
    var bi := 0
    for good in buy_dict.keys():
        var price: int = int(buy_dict[good])
        _button(Rect2(300, y, 360, 40), "%s — %d credits" % [str(good), price], credits >= price)
        y += 50; bi += 1
    _text("SELL:", Vector2(280, y + 10), 20, Color(0.95, 0.7, 0.7)); y += 40
    var sell_dict: Dictionary = isl.get("sell", {})
    for good in sell_dict.keys():
        var price: int = int(sell_dict[good])
        _button(Rect2(300, y, 360, 40), "%s — %d credits" % [str(good), price])
        y += 50
    _button(Rect2(700, 540, 200, 44), "UNDOCK")

func _draw_shipyard() -> void:
    _draw_sky()
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, 0.5))
    _panel(Rect2(300, 120, 680, 460))
    _text("SKYFORGE SHIPYARD", Vector2(380, 170), 30, Color(0.7, 0.6, 0.95))
    _text("Credits: %d" % credits, Vector2(380, 210), 20, Color(0.95, 0.85, 0.4))
    for i in range(UPGRADES.size()):
        var u: Dictionary = UPGRADES[i]
        _button(Rect2(380, 260 + i * 80, 520, 60), "%s — %d credits (%s +%s)" % [str(u["name"]), int(u["cost"]), str(u["stat"]), str(u["val"])], credits >= int(u["cost"]))
    _button(Rect2(700, 520, 200, 44), "UNDOCK")

func _draw_result() -> void:
    _panel(Rect2(300, 180, 680, 320))
    if won:
        _text("TRADE EMPIRE!", Vector2(420, 260), 44, Color(0.5, 0.95, 0.7))
        _text("You reached %d credits. The sky is yours." % credits, Vector2(400, 320), 20, Color(0.85, 0.9, 0.9))
    else:
        _text("SHIP LOST", Vector2(470, 260), 44, Color(0.95, 0.4, 0.4))
        _text("Your airship was destroyed. Credits: %d" % credits, Vector2(400, 320), 20, Color(0.85, 0.8, 0.8))
    _button(Rect2(420, 420, 180, 54), "RETRY")
    _button(Rect2(660, 420, 180, 54), "TITLE")

# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey:
        var p: bool = event.pressed
        match event.keycode:
            KEY_W, KEY_UP: move["up"] = p
            KEY_S, KEY_DOWN: move["down"] = p
            KEY_A, KEY_LEFT: move["left"] = p
            KEY_D, KEY_RIGHT: move["right"] = p
            KEY_SPACE:
                if p and not event.echo:
                    if mode == "fly": _try_dock()
            KEY_F:
                if p and not event.echo:
                    _fire_cannon()
            KEY_1:
                if p: _handle_num(0)
            KEY_2:
                if p: _handle_num(1)
            KEY_3:
                if p: _handle_num(2)
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _click(event.position)

func _handle_num(idx: int) -> void:
    if mode == "shipyard":
        _upgrade(idx)
    elif mode == "trade":
        var isl: Dictionary = ISLANDS[docked_idx]
        var buy_dict: Dictionary = isl.get("buy", {})
        var keys: Array = buy_dict.keys()
        if idx < keys.size():
            _buy(str(keys[idx]), int(buy_dict[keys[idx]]))

func _click(p: Vector2) -> void:
    if mode == "title":
        if Rect2(500, 410, 280, 64).has_point(p):
            _start(); queue_redraw()
    elif mode == "trade":
        if Rect2(700, 540, 200, 44).has_point(p):
            _undock()
        # sell buttons
        var isl: Dictionary = ISLANDS[docked_idx]
        var sell_dict: Dictionary = isl.get("sell", {})
        var si := 0
        var buy_count: int = isl.get("buy", {}).size()
        var base_y := 230 + 30 + buy_count * 50 + 50
        for good in sell_dict.keys():
            if Rect2(300, base_y + si * 50, 360, 40).has_point(p):
                _sell(str(good), int(sell_dict[good])); return
            si += 1
    elif mode == "shipyard":
        for i in range(UPGRADES.size()):
            if Rect2(380, 260 + i * 80, 520, 60).has_point(p):
                _upgrade(i); return
        if Rect2(700, 520, 200, 44).has_point(p):
            _undock()
    elif mode == "result":
        if Rect2(420, 420, 180, 54).has_point(p):
            _start(); queue_redraw()
        elif Rect2(660, 420, 180, 54).has_point(p):
            mode = "title"; queue_redraw()
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_fly.json" <<'EOF'
{
  "duration_frames": 460,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 640, "y": 442},
    {"frame": 80,  "type": "key_down", "keycode": "D"},
    {"frame": 160, "type": "key_up", "keycode": "D"},
    {"frame": 200, "type": "key_down", "keycode": "W"},
    {"frame": 280, "type": "key_up", "keycode": "W"},
    {"frame": 440, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_trade.json" <<'EOF'
{
  "scenario": "trade",
  "duration_frames": 400,
  "events": [
    {"frame": 40,  "type": "key_press", "keycode": "1"},
    {"frame": 100, "type": "key_press", "keycode": "2"},
    {"frame": 180, "type": "mouse_click", "button": "left", "x": 800, "y": 558},
    {"frame": 380, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_combat.json" <<'EOF'
{
  "scenario": "combat",
  "duration_frames": 400,
  "events": [
    {"frame": 40,  "type": "key_down", "keycode": "D"},
    {"frame": 120, "type": "key_up", "keycode": "D"},
    {"frame": 150, "type": "key_press", "keycode": "F"},
    {"frame": 220, "type": "key_down", "keycode": "W"},
    {"frame": 300, "type": "key_press", "keycode": "F"},
    {"frame": 330, "type": "key_up", "keycode": "W"},
    {"frame": 380, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_shipyard.json" <<'EOF'
{
  "scenario": "shipyard",
  "duration_frames": 380,
  "events": [
    {"frame": 40,  "type": "key_press", "keycode": "1"},
    {"frame": 120, "type": "key_press", "keycode": "2"},
    {"frame": 200, "type": "mouse_click", "button": "left", "x": 800, "y": 538},
    {"frame": 360, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/05_goal.json" <<'EOF'
{
  "scenario": "near_goal",
  "duration_frames": 360,
  "events": [
    {"frame": 30,  "type": "key_press", "keycode": "SPACE"},
    {"frame": 100, "type": "key_press", "keycode": "1"},
    {"frame": 180, "type": "key_press", "keycode": "1"},
    {"frame": 340, "type": "wait"}
  ]
}
EOF

echo "airship-trader oracle generated at $GAME"
