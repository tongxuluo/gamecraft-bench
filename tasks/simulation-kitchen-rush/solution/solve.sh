#!/usr/bin/env bash
# Oracle reference implementation for simulation-kitchen-rush.
# Minimal Overcooked-style kitchen management game.
set -euo pipefail

GAME_DIR="/workspace/game"
mkdir -p "$GAME_DIR/scripts" "$GAME_DIR/demo_outputs"

cat > "$GAME_DIR/project.godot" << 'PREF'
; Engine configuration file.
[gd_resource type="ProjectSettings" format=3]

config_version=5

[application]
config/name="Kitchen Rush"
run/main_scene="res://Main.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720

[debug]
gdscript/warnings/untyped_declaration=0
gdscript/warnings/treat_warnings_as_errors=false
PREF

cat > "$GAME_DIR/Main.tscn" << 'TSCN'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/Main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
TSCN

cat > "$GAME_DIR/scripts/Main.gd" << 'GDSCRIPT'
extends Node2D

enum GS { TITLE, PLAYING, SHIFT_SUMMARY, UPGRADE }
var state := GS.TITLE

# Stations: chop, stove, fryer, oven, plate
var stations := [
    {"name":"CHOP",  "x":100.0,"y":300.0,"w":120.0,"h":80.0,"busy":false,"timer":0.0,"duration":2.0,"item":""},
    {"name":"STOVE", "x":280.0,"y":300.0,"w":120.0,"h":80.0,"busy":false,"timer":0.0,"duration":3.0,"item":""},
    {"name":"FRYER", "x":460.0,"y":300.0,"w":120.0,"h":80.0,"busy":false,"timer":0.0,"duration":2.5,"item":""},
    {"name":"OVEN",  "x":640.0,"y":300.0,"w":120.0,"h":80.0,"busy":false,"timer":0.0,"duration":4.0,"item":""},
    {"name":"PLATE", "x":820.0,"y":300.0,"w":120.0,"h":80.0,"busy":false,"timer":0.0,"duration":1.0,"item":""}
]

# Recipes: name, steps (station sequence), ingredients
var recipes := [
    {"name":"Burger",    "steps":["CHOP","STOVE","PLATE"],  "time":30.0},
    {"name":"Fries",     "steps":["CHOP","FRYER","PLATE"],  "time":25.0},
    {"name":"Pizza",     "steps":["CHOP","OVEN","PLATE"],   "time":40.0},
    {"name":"Soup",      "steps":["CHOP","STOVE","PLATE"],  "time":35.0},
    {"name":"Salad",     "steps":["CHOP","PLATE"],          "time":20.0},
    {"name":"Steak",     "steps":["STOVE","PLATE"],         "time":30.0},
    {"name":"Nuggets",   "steps":["FRYER","PLATE"],         "time":22.0},
    {"name":"Casserole", "steps":["CHOP","OVEN","PLATE"],   "time":45.0}
]

# Active orders
var orders: Array = []
var order_spawn_timer := 5.0
var shift_time := 120.0
var time_left := 120.0
var coins := 0
var tips := 0
var orders_completed := 0
var orders_failed := 0
var shift := 1
var rng := RandomNumberGenerator.new()

# In-progress cooking
var cooking_queue: Array = []  # {order_idx, step_idx, station}
var selected_order := -1

# Upgrades
var upgrades := ["Faster Stove","Larger Fryer","Auto-Chopper","Extra Oven","Speed Boost"]
var owned_upgrades: Array = []

# UI
var title_panel: ColorRect
var hud_label: Label
var orders_panel: ColorRect
var summary_panel: ColorRect
var summary_label: Label
var upgrade_panel: ColorRect
var feedback_label: Label

var scenario := ""

func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    for i in range(args.size()):
        if args[i] == "--scenario" and i + 1 < args.size():
            scenario = args[i + 1]
    rng.seed = 42
    _build_ui()
    if scenario == "gameplay":
        state = GS.PLAYING
        _spawn_order(); _spawn_order()
    elif scenario == "summary":
        orders_completed = 7; orders_failed = 1; coins = 140; tips = 35
        state = GS.SHIFT_SUMMARY; _show_summary()
    else:
        state = GS.TITLE; title_panel.visible = true

func _build_ui() -> void:
    var bg := ColorRect.new(); bg.color = Color(0.15,0.1,0.05); bg.size = Vector2(1280,720); add_child(bg)
    title_panel = ColorRect.new(); title_panel.color = Color(0,0,0,0.92); title_panel.size = Vector2(1280,720); title_panel.visible = false; add_child(title_panel)
    var tl := Label.new(); tl.text = "KITCHEN RUSH\nRestaurant Simulation\n\nClick orders to select, then click stations to cook.\nComplete orders before timers run out!"; tl.position = Vector2(340,180); tl.add_theme_font_size_override("font_size",34); tl.modulate = Color(1.0,0.8,0.3); title_panel.add_child(tl)
    var sb := Button.new(); sb.text = "START SHIFT"; sb.position = Vector2(490,420); sb.size = Vector2(300,65); sb.add_theme_font_size_override("font_size",28); sb.pressed.connect(_on_start); title_panel.add_child(sb)
    hud_label = Label.new(); hud_label.position = Vector2(10,10); hud_label.add_theme_font_size_override("font_size",20); hud_label.modulate = Color(1.0,0.9,0.5); add_child(hud_label)
    feedback_label = Label.new(); feedback_label.position = Vector2(10,680); feedback_label.add_theme_font_size_override("font_size",20); feedback_label.modulate = Color(0.3,1.0,0.3); feedback_label.visible = false; add_child(feedback_label)
    summary_panel = ColorRect.new(); summary_panel.color = Color(0.05,0.04,0.02,0.95); summary_panel.size = Vector2(600,380); summary_panel.position = Vector2(340,170); summary_panel.visible = false; add_child(summary_panel)
    summary_label = Label.new(); summary_label.position = Vector2(50,30); summary_label.add_theme_font_size_override("font_size",26); summary_label.modulate = Color(1.0,0.9,0.5); summary_panel.add_child(summary_label)
    var nb := Button.new(); nb.text = "Next Shift"; nb.position = Vector2(200,300); nb.size = Vector2(200,55); nb.pressed.connect(_on_next_shift); summary_panel.add_child(nb)
    upgrade_panel = ColorRect.new(); upgrade_panel.color = Color(0.05,0.04,0.02,0.95); upgrade_panel.size = Vector2(700,400); upgrade_panel.position = Vector2(290,160); upgrade_panel.visible = false; add_child(upgrade_panel)
    var ul := Label.new(); ul.text = "UPGRADES — Choose one:"; ul.position = Vector2(150,20); ul.add_theme_font_size_override("font_size",28); ul.modulate = Color(1.0,0.9,0.5); upgrade_panel.add_child(ul)
    for i in range(upgrades.size()):
        var btn := Button.new(); btn.text = upgrades[i]; btn.position = Vector2(100,80+i*60); btn.size = Vector2(500,50); btn.add_theme_font_size_override("font_size",22); btn.pressed.connect(_on_upgrade.bind(i)); upgrade_panel.add_child(btn)

func _on_start() -> void:
    title_panel.visible = false; state = GS.PLAYING; _spawn_order(); _spawn_order()

func _on_next_shift() -> void:
    summary_panel.visible = false; state = GS.UPGRADE; upgrade_panel.visible = true

func _on_upgrade(idx: int) -> void:
    upgrade_panel.visible = false; owned_upgrades.append(upgrades[idx])
    shift += 1; time_left = 120.0; orders_completed = 0; orders_failed = 0; coins = 0; tips = 0
    order_spawn_timer = max(3.0, 5.0 - shift * 0.3)
    state = GS.PLAYING; _spawn_order()

func _spawn_order() -> void:
    if orders.size() >= 5 + shift: return
    var r: Dictionary = recipes[rng.randi_range(0, recipes.size()-1)]
    var t: float = float(r["time"]) - shift * 2.0
    orders.append({"recipe": r["name"], "steps": r["steps"].duplicate(), "step": 0, "timer": max(15.0, t), "max_timer": max(15.0, t), "done": false, "failed": false})

func _process(delta: float) -> void:
    if state == GS.PLAYING:
        _update(delta)
    _update_hud()
    queue_redraw()

func _update(delta: float) -> void:
    time_left -= delta
    if time_left <= 0.0: _show_summary(); return
    order_spawn_timer -= delta
    if order_spawn_timer <= 0.0:
        order_spawn_timer = rng.randf_range(3.0, 6.0)
        _spawn_order()
    # Tick order timers
    for o in orders:
        if bool(o["done"]) or bool(o["failed"]): continue
        o["timer"] = float(o["timer"]) - delta
        if float(o["timer"]) <= 0.0:
            o["failed"] = true; orders_failed += 1
    # Tick stations
    for st in stations:
        if bool(st["busy"]):
            st["timer"] = float(st["timer"]) - delta
            if float(st["timer"]) <= 0.0:
                st["busy"] = false; st["timer"] = 0.0
                _station_done(str(st["name"]))
    orders = orders.filter(func(o): return not bool(o["failed"]) or float(o["timer"]) > -5.0)

func _station_done(station_name: String) -> void:
    for o in orders:
        if bool(o["done"]) or bool(o["failed"]): continue
        var steps: Array = o["steps"]
        var step: int = int(o["step"])
        if step < steps.size() and steps[step] == station_name:
            o["step"] = step + 1
            if int(o["step"]) >= steps.size():
                o["done"] = true; orders_completed += 1
                var speed_bonus: int = int(float(o["timer"]) / float(o["max_timer"]) * 10.0)
                coins += 20; tips += speed_bonus
                _show_feedback("Order done! +%d coins +%d tip" % [20, speed_bonus])
            break

func _show_feedback(msg: String) -> void:
    feedback_label.text = msg; feedback_label.visible = true
    get_tree().create_timer(2.0).timeout.connect(func(): feedback_label.visible = false)

func _show_summary() -> void:
    state = GS.SHIFT_SUMMARY; summary_panel.visible = true
    var stars := 1
    if orders_completed >= 8: stars = 2
    if orders_completed >= 12: stars = 3
    summary_label.text = "SHIFT %d COMPLETE\n\nOrders Completed: %d\nOrders Failed: %d\nCoins Earned: %d\nTips: %d\nRating: %d Stars" % [shift, orders_completed, orders_failed, coins, tips, stars]

func _update_hud() -> void:
    if state != GS.PLAYING: return
    hud_label.text = "Shift %d  |  Time: %.0fs  |  Orders: %d done / %d failed  |  Coins: %d  Tips: %d" % [shift, time_left, orders_completed, orders_failed, coins, tips]

func _input(event: InputEvent) -> void:
    if state != GS.PLAYING: return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var mp: Vector2 = event.position
        # Click on order to select
        for i in range(orders.size()):
            var o: Dictionary = orders[i]
            if bool(o["done"]) or bool(o["failed"]): continue
            var oy: float = 500.0 + i * 50.0
            if mp.x >= 20.0 and mp.x <= 500.0 and mp.y >= oy and mp.y <= oy + 44.0:
                selected_order = i; return
        # Click on station to cook
        if selected_order >= 0 and selected_order < orders.size():
            var o: Dictionary = orders[selected_order]
            if bool(o["done"]) or bool(o["failed"]): return
            for st in stations:
                if mp.x >= float(st["x"]) and mp.x <= float(st["x"]) + float(st["w"]) and mp.y >= float(st["y"]) and mp.y <= float(st["y"]) + float(st["h"]):
                    if not bool(st["busy"]):
                        var steps: Array = o["steps"]
                        var step: int = int(o["step"])
                        if step < steps.size() and steps[step] == str(st["name"]):
                            st["busy"] = true; st["timer"] = float(st["duration"]); st["item"] = str(o["recipe"])
                            _show_feedback("Cooking %s at %s..." % [str(o["recipe"]), str(st["name"])])
                    break

func _draw() -> void:
    if state == GS.TITLE: return
    # Stations
    var scols := [Color(0.4,0.6,0.3),Color(0.8,0.3,0.1),Color(0.6,0.5,0.1),Color(0.5,0.3,0.6),Color(0.3,0.5,0.7)]
    for i in range(stations.size()):
        var st: Dictionary = stations[i]
        var col: Color = scols[i]
        if bool(st["busy"]): col = Color(1.0,0.8,0.0)
        draw_rect(Rect2(float(st["x"]),float(st["y"]),float(st["w"]),float(st["h"])), col)
        draw_string(ThemeDB.fallback_font, Vector2(float(st["x"])+5.0,float(st["y"])+20.0), str(st["name"]), HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.BLACK)
        if bool(st["busy"]):
            var prog: float = 1.0 - float(st["timer"]) / float(st["duration"])
            draw_rect(Rect2(float(st["x"]),float(st["y"])+float(st["h"])-8.0,float(st["w"])*prog,8.0), Color(0.3,1.0,0.3))
            draw_string(ThemeDB.fallback_font, Vector2(float(st["x"])+5.0,float(st["y"])+50.0), str(st["item"]), HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)
    # Orders
    for i in range(orders.size()):
        var o: Dictionary = orders[i]
        if bool(o["failed"]): continue
        var oy: float = 500.0 + i * 50.0
        var ocol := Color(0.2,0.15,0.1) if i != selected_order else Color(0.35,0.25,0.1)
        draw_rect(Rect2(20.0,oy,480.0,44.0), ocol)
        var steps: Array = o["steps"]
        var step: int = int(o["step"])
        var step_str := " → ".join(steps)
        draw_string(ThemeDB.fallback_font, Vector2(28.0,oy+16.0), "%s  [%s]  step %d/%d" % [str(o["recipe"]),step_str,step,steps.size()], HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(1.0,0.9,0.5))
        var ratio: float = float(o["timer"]) / float(o["max_timer"])
        var tcol := Color(0.3,1.0,0.3) if ratio > 0.5 else (Color(1.0,0.8,0.0) if ratio > 0.25 else Color(1.0,0.2,0.2))
        draw_rect(Rect2(510.0,oy+8.0,200.0*ratio,28.0), tcol)
        draw_string(ThemeDB.fallback_font, Vector2(720.0,oy+16.0), "%.0fs" % float(o["timer"]), HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
GDSCRIPT

cat > "$GAME_DIR/demo_outputs/01_title.json" << 'DEMO'
{"duration_frames":300,"events":[{"frame":60,"type":"mouse_click","button":"left","x":640,"y":453}]}
DEMO

cat > "$GAME_DIR/demo_outputs/02_gameplay.json" << 'DEMO'
{"scenario":"gameplay","duration_frames":540,"events":[{"frame":30,"type":"mouse_click","button":"left","x":200,"y":500},{"frame":60,"type":"mouse_click","button":"left","x":160,"y":340},{"frame":120,"type":"mouse_click","button":"left","x":200,"y":500},{"frame":150,"type":"mouse_click","button":"left","x":340,"y":340},{"frame":210,"type":"mouse_click","button":"left","x":200,"y":500},{"frame":240,"type":"mouse_click","button":"left","x":880,"y":340},{"frame":300,"type":"mouse_click","button":"left","x":200,"y":550},{"frame":330,"type":"mouse_click","button":"left","x":160,"y":340},{"frame":390,"type":"mouse_click","button":"left","x":200,"y":550},{"frame":420,"type":"mouse_click","button":"left","x":880,"y":340},{"frame":480,"type":"wait"}]}
DEMO

cat > "$GAME_DIR/demo_outputs/03_summary.json" << 'DEMO'
{"scenario":"summary","duration_frames":300,"events":[{"frame":60,"type":"wait"},{"frame":200,"type":"mouse_click","button":"left","x":540,"y":470}]}
DEMO

echo "Oracle written to $GAME_DIR"
