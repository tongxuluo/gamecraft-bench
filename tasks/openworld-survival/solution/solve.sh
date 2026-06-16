#!/bin/bash
# Reference solution for gamecraft-bench/openworld-survival.
#
# Drops a minimal but coherent open-world survival game into
# /workspace/game/. Covers all mechanic requirements with simple shapes
# and colours; art-style requirements (A1-A3) are intentionally low.
#
# Scenarios:
#   default         — title → explore → gather → craft → place
#   gather_wood     — skip title, player near trees
#   gather_stone    — skip title, player near rocks
#   gather_food     — skip title, player near berry bushes
#   craft_campfire  — skip title, inventory has materials, open crafting
#   place_shelter   — skip title, place a shelter
#   night_survival  — skip title, night time, player near campfire
#   full_day        — skip title, rapid day-night cycle
set -eu

GAME=${GAME:-/workspace/game}
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

# --------------------------------------------------------------------------
# project.godot + Main scene
# --------------------------------------------------------------------------

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="Wildern"
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
# Main.gd — single-file survival game
# --------------------------------------------------------------------------

cat > "$GAME/scripts/Main.gd" <<'GDEOF'
extends Node2D

enum Mode { TITLE, WORLD, CRAFTING, BUILDING }

const C_GRASS  = Color(0.40, 0.65, 0.30)
const C_FOREST = Color(0.15, 0.40, 0.15)
const C_ROCK   = Color(0.55, 0.50, 0.45)
const C_PLAYER = Color(0.30, 0.50, 0.90)
const C_TREE   = Color(0.45, 0.30, 0.15)
const C_STONE  = Color(0.55, 0.55, 0.60)
const C_BERRY  = Color(0.80, 0.20, 0.30)
const C_CF     = Color(0.95, 0.55, 0.15)
const C_SHEL   = Color(0.60, 0.40, 0.25)
const MAP_W    = 2400
const MAP_H    = 1600

var mode        := Mode.TITLE
var player_pos  := Vector2(640, 360)
var player_spd  := 180.0
var inv         := {"wood": 0, "stone": 0, "food": 0}
var hunger      := 100.0
var thirst      := 100.0
var health      := 100.0
var day_time    := 6.0
var day_spd     := 1.5
var placed      := []
var resources   := []
var gather_cd   := 0.0
var msg_t       := 0.0
var near_b      := false

var cam         : Camera2D
var title_ui    : Control
var hud         : Control
var hb          : ProgressBar
var tb          : ProgressBar
var hl          : Label
var tl          : Label
var dl          : Label
var il          : Label
var msg_l       : Label
var craft_p     : Panel
var day_mod     : CanvasModulate
var world_root  : Node2D
var res_root    : Node2D
var build_root  : Node2D
var player_rect : ColorRect

func _ready():
    cam = Camera2D.new()
    cam.position = player_pos
    cam.zoom = Vector2(1, 1)
    add_child(cam)

    day_mod = CanvasModulate.new()
    day_mod.color = Color.WHITE
    add_child(day_mod)

    world_root = Node2D.new()
    add_child(world_root)
    res_root = Node2D.new()
    add_child(res_root)
    build_root = Node2D.new()
    add_child(build_root)

    _gen_terrain()
    _gen_resources()
    _make_player()
    _make_title_ui()
    _make_hud()
    _make_craft_panel()
    _apply_scenario()

func _make_player():
    player_rect = ColorRect.new()
    player_rect.color = C_PLAYER
    player_rect.size = Vector2(24, 24)
    player_rect.position = player_pos - player_rect.size / 2
    player_rect.z_index = 10
    add_child(player_rect)

func _gen_terrain():
    var tile_s = 64
    for x in range(0, MAP_W, tile_s):
        for y in range(0, MAP_H, tile_s):
            var r = randf()
            var c = C_GRASS
            if r > 0.55 and r < 0.80: c = C_FOREST
            elif r >= 0.80: c = C_ROCK
            var cr = ColorRect.new()
            cr.color = c
            cr.size = Vector2(tile_s, tile_s)
            cr.position = Vector2(x, y)
            world_root.add_child(cr)

func _gen_resources():
    # Trees
    for i in range(25):
        var p = Vector2(randi() % (MAP_W - 100) + 50, randi() % (MAP_H - 100) + 50)
        resources.append({"type": "tree", "pos": p, "avail": true})
        var cr = ColorRect.new()
        cr.color = C_TREE
        cr.size = Vector2(32, 40)
        cr.position = p - cr.size / 2
        cr.name = "res_tree_%d" % i
        res_root.add_child(cr)
    # Stones
    for i in range(15):
        var p = Vector2(randi() % (MAP_W - 100) + 50, randi() % (MAP_H - 100) + 50)
        resources.append({"type": "stone", "pos": p, "avail": true})
        var cr = ColorRect.new()
        cr.color = C_STONE
        cr.size = Vector2(28, 28)
        cr.position = p - cr.size / 2
        cr.name = "res_stone_%d" % i
        res_root.add_child(cr)
    # Berries
    for i in range(20):
        var p = Vector2(randi() % (MAP_W - 100) + 50, randi() % (MAP_H - 100) + 50)
        resources.append({"type": "berry", "pos": p, "avail": true})
        var cr = ColorRect.new()
        cr.color = C_BERRY
        cr.size = Vector2(20, 20)
        cr.position = p - cr.size / 2
        cr.name = "res_berry_%d" % i
        res_root.add_child(cr)

GDEOF


cat >> "$GAME/scripts/Main.gd" <<'GDEOF'

func _make_title_ui():
    title_ui = Control.new()
    title_ui.size = Vector2(1280, 720)
    title_ui.z_index = 100
    add_child(title_ui)

    var bg = ColorRect.new()
    bg.color = Color(0.12, 0.22, 0.15)
    bg.size = Vector2(1280, 720)
    title_ui.add_child(bg)

    var title = Label.new()
    title.text = "WILDERN"
    title.position = Vector2(440, 200)
    title.add_theme_font_size_override("font_size", 72)
    title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
    title_ui.add_child(title)

    var btn = Button.new()
    btn.text = "Start Survival"
    btn.position = Vector2(540, 380)
    btn.size = Vector2(200, 50)
    btn.add_theme_font_size_override("font_size", 24)
    btn.pressed.connect(_on_start)
    title_ui.add_child(btn)

    var sub = Label.new()
    sub.text = "Gather. Craft. Survive."
    sub.position = Vector2(480, 300)
    sub.add_theme_font_size_override("font_size", 20)
    sub.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
    title_ui.add_child(sub)

func _on_start():
    mode = Mode.WORLD
    title_ui.visible = false
    hud.visible = true

func _make_hud():
    hud = Control.new()
    hud.size = Vector2(1280, 720)
    hud.visible = false
    hud.z_index = 50
    add_child(hud)

    # Hunger bar
    var hbp = Panel.new()
    hbp.position = Vector2(20, 20)
    hbp.size = Vector2(200, 30)
    hud.add_child(hbp)
    hb = ProgressBar.new()
    hb.position = Vector2(25, 22)
    hb.size = Vector2(190, 26)
    hb.max_value = 100
    hb.value = 100
    hb.add_theme_color_override("fill", Color(0.9, 0.5, 0.15))
    hud.add_child(hb)
    hl = Label.new()
    hl.text = "Hunger"
    hl.position = Vector2(25, 4)
    hl.add_theme_font_size_override("font_size", 12)
    hud.add_child(hl)

    # Thirst bar
    var tbp = Panel.new()
    tbp.position = Vector2(20, 60)
    tbp.size = Vector2(200, 30)
    hud.add_child(tbp)
    tb = ProgressBar.new()
    tb.position = Vector2(25, 62)
    tb.size = Vector2(190, 26)
    tb.max_value = 100
    tb.value = 100
    tb.add_theme_color_override("fill", Color(0.2, 0.5, 0.9))
    hud.add_child(tb)
    tl = Label.new()
    tl.text = "Thirst"
    tl.position = Vector2(25, 44)
    tl.add_theme_font_size_override("font_size", 12)
    hud.add_child(tl)

    # Day label
    dl = Label.new()
    dl.position = Vector2(1100, 20)
    dl.add_theme_font_size_override("font_size", 18)
    dl.add_theme_color_override("font_color", Color.WHITE)
    hud.add_child(dl)

    # Inventory label
    il = Label.new()
    il.position = Vector2(1100, 50)
    il.add_theme_font_size_override("font_size", 14)
    il.add_theme_color_override("font_color", Color.WHITE)
    hud.add_child(il)

    # Message label
    msg_l = Label.new()
    msg_l.position = Vector2(440, 600)
    msg_l.size = Vector2(400, 30)
    msg_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    msg_l.add_theme_font_size_override("font_size", 16)
    msg_l.add_theme_color_override("font_color", Color.YELLOW)
    hud.add_child(msg_l)

    # Craft button
    var cb = Button.new()
    cb.text = "Craft (C)"
    cb.position = Vector2(20, 110)
    cb.size = Vector2(100, 32)
    cb.pressed.connect(_toggle_craft)
    hud.add_child(cb)

    # Build button
    var bb = Button.new()
    bb.text = "Build (B)"
    bb.position = Vector2(130, 110)
    bb.size = Vector2(100, 32)
    bb.pressed.connect(_toggle_build)
    hud.add_child(bb)

func _make_craft_panel():
    craft_p = Panel.new()
    craft_p.position = Vector2(340, 140)
    craft_p.size = Vector2(600, 440)
    craft_p.visible = false
    craft_p.z_index = 60
    add_child(craft_p)

    var bg = ColorRect.new()
    bg.color = Color(0.15, 0.15, 0.15, 0.95)
    bg.size = craft_p.size
    craft_p.add_child(bg)

    var title = Label.new()
    title.text = "CRAFTING"
    title.position = Vector2(240, 15)
    title.add_theme_font_size_override("font_size", 28)
    title.add_theme_color_override("font_color", Color.WHITE)
    craft_p.add_child(title)

    var close = Button.new()
    close.text = "X"
    close.position = Vector2(560, 10)
    close.size = Vector2(30, 30)
    close.pressed.connect(_close_craft)
    craft_p.add_child(close)

    # Recipe 1: Campfire
    _add_recipe(0, "Campfire", "3 Wood", {"wood": 3}, "campfire")
    # Recipe 2: Shelter
    _add_recipe(1, "Shelter", "5 Wood + 2 Stone", {"wood": 5, "stone": 2}, "shelter")
    # Recipe 3: Axe (tool)
    _add_recipe(2, "Axe", "2 Wood + 1 Stone", {"wood": 2, "stone": 1}, "axe")

func _add_recipe(idx: int, name: String, cost_str: String, cost: Dictionary, item: String):
    var y = 80 + idx * 90
    var rbg = ColorRect.new()
    rbg.color = Color(0.25, 0.25, 0.25)
    rbg.position = Vector2(30, y)
    rbg.size = Vector2(540, 80)
    craft_p.add_child(rbg)

    var nl = Label.new()
    nl.text = name
    nl.position = Vector2(45, y + 8)
    nl.add_theme_font_size_override("font_size", 20)
    nl.add_theme_color_override("font_color", Color.WHITE)
    craft_p.add_child(nl)

    var cl = Label.new()
    cl.text = cost_str
    cl.position = Vector2(45, y + 38)
    cl.add_theme_font_size_override("font_size", 14)
    cl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
    craft_p.add_child(cl)

    var btn = Button.new()
    btn.text = "Craft"
    btn.position = Vector2(450, y + 20)
    btn.size = Vector2(100, 40)
    btn.pressed.connect(func(): _do_craft(cost, item))
    craft_p.add_child(btn)

func _toggle_craft():
    if mode == Mode.CRAFTING:
        mode = Mode.WORLD
        craft_p.visible = false
    else:
        mode = Mode.CRAFTING
        craft_p.visible = true

func _close_craft():
    mode = Mode.WORLD
    craft_p.visible = false

func _toggle_build():
    if mode == Mode.BUILDING:
        mode = Mode.WORLD
        _show_msg("Build mode off")
    else:
        mode = Mode.BUILDING
        _show_msg("Build mode: click to place (Campfire)")

GDEOF


cat >> "$GAME/scripts/Main.gd" <<'GDEOF'

func _process(delta):
    match mode:
        Mode.TITLE:
            pass
        Mode.WORLD:
            _update_day_night(delta)
            _update_survival(delta)
            _handle_movement(delta)
            _update_building_benefits()
            _check_gather()
            _update_hud()
            _update_cam()
        Mode.CRAFTING:
            _update_hud()
        Mode.BUILDING:
            _update_day_night(delta)
            _update_survival(delta)
            _update_building_benefits()
            _update_hud()
            _update_cam()

func _update_cam():
    cam.position = player_pos

func _update_day_night(delta):
    day_time += delta * day_spd * 0.3
    if day_time >= 24.0:
        day_time -= 24.0
        # New day
    var t = day_time
    var c = Color.WHITE
    if t < 5.0:
        c = Color(0.15, 0.15, 0.35)  # pre-dawn
    elif t < 7.0:
        c = Color(0.9, 0.65, 0.4)    # dawn
    elif t < 17.0:
        c = Color.WHITE               # day
    elif t < 19.0:
        c = Color(0.9, 0.55, 0.3)    # dusk
    elif t < 21.0:
        c = Color(0.4, 0.25, 0.4)    # twilight
    else:
        c = Color(0.12, 0.12, 0.30)  # night
    day_mod.color = day_mod.color.lerp(c, delta * 2.0)

func _update_survival(delta):
    var h_rate = 1.2
    var t_rate = 1.8
    if day_time >= 20.0 or day_time < 5.0:
        h_rate *= 1.5
        t_rate *= 1.5
    hunger = max(0, hunger - h_rate * delta)
    thirst = max(0, thirst - t_rate * delta)
    if hunger <= 0 or thirst <= 0:
        health = max(0, health - 2.0 * delta)
    if health <= 0:
        health = 100.0
        hunger = 50.0
        thirst = 50.0
        _show_msg("You collapsed from exhaustion...")

func _update_building_benefits():
    near_b = false
    for b in placed:
        var d = player_pos.distance_to(b["pos"])
        if d < 80:
            near_b = true
            if b["type"] == "campfire":
                health = min(100, health + 3.0 * get_process_delta_time())
            elif b["type"] == "shelter":
                health = min(100, health + 5.0 * get_process_delta_time())
                hunger = min(100, hunger + 1.0 * get_process_delta_time())
                thirst = min(100, thirst + 1.0 * get_process_delta_time())

func _handle_movement(delta):
    var inp = Vector2.ZERO
    if Input.is_action_pressed("ui_right"): inp.x += 1
    if Input.is_action_pressed("ui_left"):  inp.x -= 1
    if Input.is_action_pressed("ui_down"):  inp.y += 1
    if Input.is_action_pressed("ui_up"):    inp.y -= 1
    if inp.length() > 0:
        inp = inp.normalized()
        player_pos += inp * player_spd * delta
        player_pos.x = clamp(player_pos.x, 20, MAP_W - 20)
        player_pos.y = clamp(player_pos.y, 20, MAP_H - 20)
    player_rect.position = player_pos - player_rect.size / 2

func _check_gather():
    gather_cd = max(0, gather_cd - get_process_delta_time())
    if gather_cd > 0: return
    if not Input.is_action_just_pressed("ui_accept"): return
    for i in range(resources.size()):
        var r = resources[i]
        if not r["avail"]: continue
        if player_pos.distance_to(r["pos"]) < 50:
            gather_cd = 0.8
            r["avail"] = false
            _flash_res(i)
            match r["type"]:
                "tree":
                    inv["wood"] += 2
                    _show_msg("+2 Wood")
                "stone":
                    inv["stone"] += 1
                    _show_msg("+1 Stone")
                "berry":
                    inv["food"] += 1
                    hunger = min(100, hunger + 10)
                    thirst = min(100, thirst + 5)
                    _show_msg("+1 Food (ate berries)")
            break

func _flash_res(idx: int):
    var node = res_root.get_child(idx)
    if node:
        node.modulate = Color(0.3, 0.3, 0.3)
        var t = create_tween()
        t.tween_property(node, "modulate", Color(0.3, 0.3, 0.3), 0.1)

func _do_craft(cost: Dictionary, item: String):
    for k in cost:
        if inv.get(k, 0) < cost[k]:
            _show_msg("Not enough materials!")
            return
    for k in cost:
        inv[k] -= cost[k]
    if item == "campfire" or item == "shelter":
        # Add to build queue
        inv["build_" + item] = inv.get("build_" + item, 0) + 1
        _show_msg("Crafted " + item + "! Press B to place.")
    else:
        _show_msg("Crafted " + item + "!")

func _input(event):
    if mode == Mode.TITLE: return
    if event is InputEventKey:
        if event.pressed and event.keycode == KEY_C:
            _toggle_craft()
        elif event.pressed and event.keycode == KEY_B:
            _toggle_build()
    if mode == Mode.BUILDING and event is InputEventMouseButton:
        if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            _try_place_building()

func _try_place_building():
    var mpos = get_global_mouse_position()
    if inv.get("build_campfire", 0) > 0:
        inv["build_campfire"] -= 1
        _place_building("campfire", mpos)
    elif inv.get("build_shelter", 0) > 0:
        inv["build_shelter"] -= 1
        _place_building("shelter", mpos)
    else:
        _show_msg("No buildings to place!")
        mode = Mode.WORLD

func _place_building(btype: String, pos: Vector2):
    placed.append({"type": btype, "pos": pos})
    var cr = ColorRect.new()
    cr.z_index = 5
    if btype == "campfire":
        cr.color = C_CF
        cr.size = Vector2(36, 36)
    else:
        cr.color = C_SHEL
        cr.size = Vector2(48, 48)
    cr.position = pos - cr.size / 2
    build_root.add_child(cr)
    _show_msg("Placed " + btype + "!")
    mode = Mode.WORLD

func _update_hud():
    hb.value = hunger
    tb.value = thirst
    dl.text = "Day %d  %02d:00" % [int(day_time / 24) + 1, int(day_time)]
    il.text = "W:%d  S:%d  F:%d" % [inv["wood"], inv["stone"], inv["food"]]
    if msg_t > 0:
        msg_t -= get_process_delta_time()
        if msg_t <= 0:
            msg_l.text = ""

func _show_msg(txt: String):
    msg_l.text = txt
    msg_t = 2.5

GDEOF


cat >> "$GAME/scripts/Main.gd" <<'GDEOF'

func _apply_scenario():
    var sc = OS.get_environment("SCENARIO")
    match sc:
        "default":
            pass
        "gather_wood", "gather_stone", "gather_food":
            mode = Mode.WORLD
            title_ui.visible = false
            hud.visible = true
            # Find nearest resource of target type
            var target = "tree"
            if sc == "gather_stone": target = "stone"
            if sc == "gather_food": target = "berry"
            var best = -1
            var best_d = 99999.0
            for i in range(resources.size()):
                if resources[i]["type"] == target and resources[i]["avail"]:
                    var d = player_pos.distance_to(resources[i]["pos"])
                    if d < best_d:
                        best_d = d
                        best = i
            if best >= 0:
                player_pos = resources[best]["pos"] + Vector2(40, 0)
                player_rect.position = player_pos - player_rect.size / 2
        "craft_campfire":
            mode = Mode.WORLD
            title_ui.visible = false
            hud.visible = true
            inv = {"wood": 5, "stone": 2, "food": 1}
            _toggle_craft()
        "place_shelter":
            mode = Mode.WORLD
            title_ui.visible = false
            hud.visible = true
            inv = {"wood": 0, "stone": 0, "food": 0, "build_shelter": 1}
            _toggle_build()
        "night_survival":
            mode = Mode.WORLD
            title_ui.visible = false
            hud.visible = true
            day_time = 22.0
            hunger = 30.0
            thirst = 25.0
            # Place a campfire near player
            _place_building("campfire", player_pos + Vector2(60, 0))
        "full_day":
            mode = Mode.WORLD
            title_ui.visible = false
            hud.visible = true
            day_spd = 8.0
            inv = {"wood": 3, "stone": 1, "food": 2}
            _place_building("campfire", player_pos + Vector2(80, 30))
GDEOF


# --------------------------------------------------------------------------
# Demo traces
# --------------------------------------------------------------------------

cat > "$GAME/demo_outputs/01_title_screen.json" <<'EOF'
{
  "duration_frames": 300,
  "events": [
    {"frame": 30, "type": "wait"},
    {"frame": 120, "type": "mouse_click", "button": "left", "x": 640, "y": 405},
    {"frame": 300, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_gather_wood.json" <<'EOF'
{
  "scenario": "gather_wood",
  "duration_frames": 360,
  "events": [
    {"frame": 60, "type": "wait"},
    {"frame": 120, "type": "key_press", "keycode": "ENTER"},
    {"frame": 150, "type": "key_up", "keycode": "ENTER"},
    {"frame": 360, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_gather_stone.json" <<'EOF'
{
  "scenario": "gather_stone",
  "duration_frames": 360,
  "events": [
    {"frame": 60, "type": "wait"},
    {"frame": 120, "type": "key_press", "keycode": "ENTER"},
    {"frame": 150, "type": "key_up", "keycode": "ENTER"},
    {"frame": 360, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_gather_food.json" <<'EOF'
{
  "scenario": "gather_food",
  "duration_frames": 360,
  "events": [
    {"frame": 60, "type": "wait"},
    {"frame": 120, "type": "key_press", "keycode": "ENTER"},
    {"frame": 150, "type": "key_up", "keycode": "ENTER"},
    {"frame": 360, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/05_craft_campfire.json" <<'EOF'
{
  "scenario": "craft_campfire",
  "duration_frames": 420,
  "events": [
    {"frame": 60, "type": "wait"},
    {"frame": 150, "type": "mouse_click", "button": "left", "x": 500, "y": 200},
    {"frame": 420, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/06_place_shelter.json" <<'EOF'
{
  "scenario": "place_shelter",
  "duration_frames": 360,
  "events": [
    {"frame": 60, "type": "wait"},
    {"frame": 150, "type": "mouse_click", "button": "left", "x": 700, "y": 400},
    {"frame": 360, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/07_night_survival.json" <<'EOF'
{
  "scenario": "night_survival",
  "duration_frames": 480,
  "events": [
    {"frame": 60, "type": "wait"},
    {"frame": 180, "type": "key_press", "keycode": "LEFT"},
    {"frame": 240, "type": "key_up", "keycode": "LEFT"},
    {"frame": 480, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/08_full_day.json" <<'EOF'
{
  "scenario": "full_day",
  "duration_frames": 600,
  "events": [
    {"frame": 60, "type": "wait"},
    {"frame": 150, "type": "key_press", "keycode": "RIGHT"},
    {"frame": 210, "type": "key_up", "keycode": "RIGHT"},
    {"frame": 300, "type": "key_press", "keycode": "DOWN"},
    {"frame": 360, "type": "key_up", "keycode": "DOWN"},
    {"frame": 600, "type": "wait"}
  ]
}
EOF

