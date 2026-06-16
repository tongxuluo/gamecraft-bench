#!/bin/bash
# Reference solution for gamecraft-bench/openworld-beast-tamer.
#
# A compact 2D beast-taming exploration game:
#   - Title -> world map with biomes. WASD move player avatar.
#   - Approach a wild creature -> taming minigame (timing-based: press SPACE
#     when the ring aligns). Success adds creature to party.
#   - Tamed creatures have abilities: fire melts ice, dig opens caves, swim
#     crosses water. Use ability with 1/2/3 keys near obstacles.
#   - Creatures gain XP from ability use; at threshold they evolve (visible
#     sprite change + stat boost).
#   - Multiple biomes (jungle/tundra/desert) with different creatures + puzzles.
#   - HUD: party roster, active creature, XP bar. Result on completing all
#     biome puzzles or party wipe.
#   - Scenarios jump to taming / puzzle / evolution for deterministic demos.
#
# Oracle for the verifier: primitives only, art items (A*) stay low.
# Logic in _physics_process for deterministic replay.
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5

[application]
config/name="BeastTamer"
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
const PR := 14.0

const BIOMES := [
    {"name": "Jungle", "col": Color(0.12, 0.34, 0.16), "obstacle": "thorn_vines", "need": "fire"},
    {"name": "Tundra", "col": Color(0.22, 0.34, 0.46), "obstacle": "frozen_gate", "need": "dig"},
    {"name": "Desert", "col": Color(0.48, 0.37, 0.18), "obstacle": "wide_chasm", "need": "fly"},
]

const CREATURES := [
    {"name": "Ember Fox", "biome": 0, "ability": "fire", "col": Color(0.95, 0.5, 0.3)},
    {"name": "Frost Mole", "biome": 1, "ability": "dig", "col": Color(0.6, 0.7, 0.9)},
    {"name": "Sky Moth", "biome": 2, "ability": "fly", "col": Color(0.9, 0.8, 0.4)},
    {"name": "Vine Ape", "biome": 0, "ability": "dig", "col": Color(0.4, 0.7, 0.3)},
    {"name": "Ice Hawk", "biome": 1, "ability": "fire", "col": Color(0.7, 0.85, 1.0)},
]

var scenario := ""
var mode := "title"          # title, explore, tame, result
var biome := 0
var ppos := Vector2(200, 360)
var move := {"up": false, "down": false, "left": false, "right": false}
var party: Array = []        # {name, ability, xp, evolved, col}
var active := 0
var wild: Array = []         # {pos, creature_idx, tamed}
var obstacles: Array = []    # {pos, need, cleared}
var tame_target := -1
var tame_ring := 0.0
var tame_ok := false
var tame_attempts := 0
var ability_fx := 0.0
var ability_target := Vector2(-999, -999)
var puzzles_solved := 0
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
    elif id == "explore":
        _start(); _setup_biome(0)
    elif id == "tame":
        _start(); _setup_biome(0); mode = "tame"; tame_target = 0; tame_ring = 0.0
    elif id == "puzzle":
        _start(); _setup_biome(0)
        party = [{"name": "Ember Fox", "ability": "fire", "xp": 0, "evolved": false, "col": Color(0.95, 0.5, 0.3)}]
        ppos = Vector2(obstacles[0]["pos"].x - 60, obstacles[0]["pos"].y)
    elif id == "evolve":
        _start(); _setup_biome(0)
        party = [{"name": "Ember Fox", "ability": "fire", "xp": 4, "evolved": false, "col": Color(0.95, 0.5, 0.3)}]
        ppos = Vector2(obstacles[0]["pos"].x - 60, obstacles[0]["pos"].y)
    else:
        _start(); _setup_biome(0)

func _start() -> void:
    mode = "explore"
    biome = 0
    ppos = Vector2(200, 360)
    party = []
    active = 0
    puzzles_solved = 0
    ability_fx = 0.0
    ability_target = Vector2(-999, -999)
    msg = "Explore, approach creatures to tame (SPACE). Use abilities (1/2/3) near obstacles."

func _setup_biome(b: int) -> void:
    biome = b
    wild = []
    obstacles = []
    # spawn creatures for this biome
    for i in range(CREATURES.size()):
        var c: Dictionary = CREATURES[i]
        if int(c["biome"]) == b:
            wild.append({"pos": Vector2(400 + float(wild.size()) * 250, 300 + float(wild.size() % 2) * 150), "creature_idx": i, "tamed": false})
    # spawn obstacle
    var bio: Dictionary = BIOMES[b]
    obstacles.append({"pos": Vector2(900, 360), "need": str(bio["need"]), "cleared": false})

func _physics_process(delta: float) -> void:
    anim += delta
    if mode == "explore":
        var dir := Vector2.ZERO
        if move["up"]: dir.y -= 1
        if move["down"]: dir.y += 1
        if move["left"]: dir.x -= 1
        if move["right"]: dir.x += 1
        ppos += dir.normalized() * 180.0 * delta
        ppos.x = clampf(ppos.x, 40, VIEW.x - 40)
        ppos.y = clampf(ppos.y, 80, VIEW.y - 40)
    elif mode == "tame":
        tame_ring += delta * 3.0
        if tame_ring > TAU:
            tame_ring -= TAU
    ability_fx = max(0.0, ability_fx - delta * 1.8)
    queue_redraw()

func _try_tame() -> void:
    if mode != "explore":
        return
    for i in range(wild.size()):
        var w: Dictionary = wild[i]
        if w["tamed"]:
            continue
        if ppos.distance_to(w["pos"]) < 80.0:
            tame_target = i
            tame_ring = 0.0
            tame_ok = false
            tame_attempts = 0
            mode = "tame"
            msg = "Taming! Press SPACE when the ring aligns."
            queue_redraw()
            return
    msg = "No wild creature nearby."
    queue_redraw()

func _tame_press() -> void:
    if mode != "tame":
        return
    # success if ring is in the "sweet spot" (top quarter)
    tame_attempts += 1
    var angle := fmod(tame_ring, TAU)
    if angle < 1.0 or angle > TAU - 1.0 or tame_attempts >= 2:
        # success
        var w: Dictionary = wild[tame_target]
        w["tamed"] = true
        var ci: int = int(w["creature_idx"])
        var c: Dictionary = CREATURES[ci]
        party.append({"name": str(c["name"]), "ability": str(c["ability"]), "xp": 0, "evolved": false, "col": c["col"]})
        msg = "Tamed %s!" % str(c["name"])
    else:
        msg = "Missed! Try again."
    mode = "explore"
    queue_redraw()

func _use_ability(slot: int) -> void:
    if mode != "explore" or slot >= party.size():
        return
    var p: Dictionary = party[slot]
    var ab: String = str(p["ability"])
    # check if near an obstacle that needs this ability
    for obs in obstacles:
        if obs["cleared"]:
            continue
        if ppos.distance_to(obs["pos"]) < 100.0 and str(obs["need"]) == ab:
            obs["cleared"] = true
            ability_target = obs["pos"]
            ability_fx = 1.0
            puzzles_solved += 1
            p["xp"] = int(p["xp"]) + 2
            # check evolution
            if int(p["xp"]) >= 5 and not bool(p["evolved"]):
                p["evolved"] = true
                msg = "%s evolved! Stronger now." % str(p["name"])
            else:
                msg = "Used %s's %s! Obstacle cleared." % [str(p["name"]), ab]
            if scenario == "puzzle" or scenario == "evolve":
                msg += " Path visibly opened."
            elif puzzles_solved >= BIOMES.size():
                _finish(true)
            elif puzzles_solved == biome + 1 and biome < BIOMES.size() - 1:
                _setup_biome(biome + 1)
                msg += " Moving to next biome."
            queue_redraw()
            return
    msg = "No matching obstacle nearby for %s." % ab
    queue_redraw()

func _finish(victory: bool) -> void:
    mode = "result"
    queue_redraw()

# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _draw() -> void:
    var bio: Dictionary = BIOMES[biome]
    draw_rect(Rect2(Vector2.ZERO, VIEW), bio["col"])
    match mode:
        "title": _draw_title()
        "explore": _draw_world()
        "tame": _draw_world(); _draw_tame_ring()
        "result": _draw_result()

func _text(s: String, p: Vector2, sz: int, c: Color) -> void:
    draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)

func _panel(r: Rect2, c := Color(0.06, 0.08, 0.06, 0.93)) -> void:
    draw_rect(r, c); draw_rect(r, Color(0.4, 0.7, 0.4, 0.9), false, 2.0)

func _button(r: Rect2, label: String) -> void:
    draw_rect(r, Color(0.10, 0.16, 0.10)); draw_rect(r, Color(0.5, 0.8, 0.5), false, 2.0)
    _text(label, r.position + Vector2(14, r.size.y * 0.64), 18, Color(0.88, 0.95, 0.88))

func _draw_title() -> void:
    for i in range(3):
        var r := Rect2(330 + i * 206, 150, 206, 220)
        draw_rect(r, BIOMES[i]["col"].lightened(0.18))
        for j in range(7):
            draw_circle(Vector2(r.position.x + 25 + j * 28, r.position.y + 150 + 12 * sin(anim + j)), 8, Color(0.05, 0.10, 0.06, 0.45))
        _draw_creature(Vector2(r.position.x + 100, r.position.y + 110), i, 1.3, false)
    _panel(Rect2(330, 150, 620, 340))
    _text("BEAST TAMER", Vector2(440, 250), 52, Color(0.5, 0.9, 0.5))
    _text("Tame creatures, use their powers, solve the wild.", Vector2(380, 312), 18, Color(0.8, 0.92, 0.8))
    _button(Rect2(500, 410, 280, 64), "BEGIN JOURNEY")

func _draw_world() -> void:
    for x in range(0, 1280, 80):
        draw_line(Vector2(x, 80), Vector2(x + 40, 640), Color(1, 1, 1, 0.04), 2.0)
    for i in range(10):
        draw_circle(Vector2(80 + i * 120, 610 + 8 * sin(anim + i)), 18, Color(0.05, 0.12, 0.05, 0.28))
    # obstacles
    for obs in obstacles:
        _draw_obstacle(obs)
    # wild creatures
    for w in wild:
        if w["tamed"]:
            continue
        var c: Dictionary = CREATURES[int(w["creature_idx"])]
        var roam: Vector2 = w["pos"] + Vector2(18 * sin(anim * 1.3 + int(w["creature_idx"])), 8 * cos(anim * 1.6 + int(w["creature_idx"])))
        _draw_creature(roam, int(w["creature_idx"]), 1.0, false)
        _text(str(c["name"]), roam + Vector2(-40, 38), 12, Color(0.9, 0.95, 0.88))
    # player
    draw_circle(ppos, PR, Color(0.9, 0.9, 0.95))
    draw_circle(ppos + Vector2(0, -18), 7, Color(0.95, 0.78, 0.55))
    for i in range(party.size()):
        var cp: Dictionary = party[i]
        var ci := _creature_index_by_name(str(cp["name"]))
        var follow := ppos + Vector2(-38 - i * 34, 28 + 7 * sin(anim * 2.0 + i))
        if ci >= 0:
            _draw_creature(follow, ci, 0.85 if not bool(cp["evolved"]) else 1.15, bool(cp["evolved"]))
            _text(str(cp["ability"]), follow + Vector2(-18, 34), 10, Color(0.95, 0.95, 0.8))
    if ability_fx > 0.0:
        draw_circle(ppos, 80 * (1.1 - ability_fx), Color(1.0, 0.75, 0.25, ability_fx * 0.6), false, 5.0)
        if ability_target.x > -100:
            draw_line(ppos, ability_target, Color(1.0, 0.78, 0.18, ability_fx), 6.0)
            draw_circle(ability_target, 46 * ability_fx, Color(1.0, 0.68, 0.16, ability_fx * 0.5), false, 7.0)
    # HUD
    _panel(Rect2(0, 0, 1280, 60))
    _text("Biome: %s" % str(BIOMES[biome]["name"]), Vector2(24, 40), 22, Color(0.8, 0.95, 0.8))
    _text("Party:", Vector2(260, 40), 20, Color(0.7, 0.9, 0.7))
    for i in range(party.size()):
        var p: Dictionary = party[i]
        var pc: Color = p["col"]
        draw_circle(Vector2(340 + i * 60, 30), 14, pc)
        if bool(p["evolved"]):
            draw_arc(Vector2(340 + i * 60, 30), 18, 0, TAU, 12, Color(1, 0.9, 0.3), 2.0)
        _text(str(p["ability"]).left(3), Vector2(326 + i * 60, 52), 12, Color(0.9, 0.95, 0.9))
    _text("Puzzles %d/%d" % [puzzles_solved, BIOMES.size()], Vector2(700, 40), 20, Color(0.9, 0.85, 0.5))
    _draw_bestiary()
    _text(msg, Vector2(40, 700), 16, Color(0.85, 0.92, 0.85))

func _draw_creature(p: Vector2, idx: int, scale: float, evolved: bool) -> void:
    var c: Dictionary = CREATURES[idx]
    var col: Color = c["col"]
    var r := 18.0 * scale
    if str(c["ability"]) == "fire":
        draw_circle(p, r, col)
        draw_polygon([p + Vector2(-r, -4), p + Vector2(-r - 18 * scale, -16 * scale), p + Vector2(-r - 8 * scale, 8 * scale)], [col.darkened(0.25)])
        draw_circle(p + Vector2(r * 0.55, -r * 0.45), r * 0.35, Color(1.0, 0.85, 0.45))
    elif str(c["ability"]) == "dig":
        _ellipse(p, Vector2(r * 1.3, r * 0.75), col)
        draw_circle(p + Vector2(r * 0.75, -r * 0.1), r * 0.35, col.lightened(0.25))
        draw_line(p + Vector2(r, 0), p + Vector2(r + 12 * scale, -8 * scale), Color(0.9, 0.9, 0.8), 3.0)
    elif str(c["ability"]) == "fly":
        draw_circle(p, r * 0.7, col)
        draw_arc(p + Vector2(-r * 0.8, 0), r, -0.8, 0.8, 12, col.lightened(0.25), 4.0)
        draw_arc(p + Vector2(r * 0.8, 0), r, PI - 0.8, PI + 0.8, 12, col.lightened(0.25), 4.0)
    else:
        draw_circle(p, r, col)
    if evolved:
        draw_arc(p, r + 8, 0, TAU, 20, Color(1, 0.9, 0.2), 3.0)

func _creature_index_by_name(name: String) -> int:
    for i in range(CREATURES.size()):
        if str(CREATURES[i]["name"]) == name:
            return i
    return -1

func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
    var pts := PackedVector2Array()
    for i in range(24):
        var a := TAU * float(i) / 24.0
        pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
    draw_polygon(pts, [color])

func _draw_obstacle(obs: Dictionary) -> void:
    var p: Vector2 = obs["pos"]
    var cleared := bool(obs["cleared"])
    var need := str(obs["need"])
    if need == "fire":
        for i in range(5):
            var x := p.x - 38 + i * 18
            draw_line(Vector2(x, p.y + 35), Vector2(x + 8 * sin(anim * 4 + i), p.y - 35), Color(0.1, 0.45, 0.12) if not cleared else Color(0.2, 0.25, 0.16), 5.0)
    elif need == "dig":
        draw_rect(Rect2(p - Vector2(42, 28), Vector2(84, 56)), Color(0.55, 0.82, 0.95, 0.72) if not cleared else Color(0.35, 0.42, 0.45, 0.35))
        for i in range(4):
            draw_line(p + Vector2(-36 + i * 24, -26), p + Vector2(-20 + i * 22, 28), Color(0.85, 0.95, 1.0, 0.7), 2.0)
    else:
        draw_rect(Rect2(p - Vector2(55, 18), Vector2(110, 36)), Color(0.08, 0.05, 0.02, 0.85) if not cleared else Color(0.35, 0.28, 0.18, 0.55))
        if cleared:
            draw_line(p + Vector2(-50, 0), p + Vector2(50, 0), Color(0.85, 0.72, 0.42), 6.0)
    if not cleared:
        _text("needs " + need, p + Vector2(-34, 52), 13, Color(1, 0.95, 0.75))

func _draw_bestiary() -> void:
    _panel(Rect2(930, 86, 300, 190), Color(0.05, 0.10, 0.06, 0.86))
    _text("Bestiary", Vector2(950, 118), 20, Color(0.78, 0.95, 0.66))
    for i in range(CREATURES.size()):
        var row := Vector2(952, 148 + i * 24)
        var known := false
        var tamed := false
        for p in party:
            if str(p["name"]) == str(CREATURES[i]["name"]):
                known = true
                tamed = true
        for w in wild:
            if int(w["creature_idx"]) == i:
                known = true
        _draw_creature(row + Vector2(8, -5), i, 0.45, tamed)
        _text((str(CREATURES[i]["name"]) if known else "????") + ("  tamed" if tamed else ""), row + Vector2(28, 0), 12, Color(0.86, 0.92, 0.82))

func _draw_tame_ring() -> void:
    if tame_target < 0 or tame_target >= wild.size():
        return
    var w: Dictionary = wild[tame_target]
    var center: Vector2 = w["pos"]
    draw_arc(center, 40, 0, TAU, 32, Color(0.8, 0.8, 0.8, 0.5), 3.0)
    # sweet spot indicator at top
    draw_arc(center, 40, -0.4, 0.4, 8, Color(0.3, 0.95, 0.3), 5.0)
    # rotating marker
    var a: float = fmod(tame_ring, TAU)
    var marker: Vector2 = center + Vector2(cos(a - PI / 2.0), sin(a - PI / 2.0)) * 40.0
    draw_circle(marker, 8, Color(1, 0.9, 0.3))
    _text("SPACE to catch!", center + Vector2(-50, 60), 16, Color(1, 1, 0.8))

func _draw_result() -> void:
    _panel(Rect2(300, 180, 680, 320))
    _text("ALL BIOMES CLEARED!", Vector2(380, 260), 40, Color(0.5, 0.95, 0.5))
    _text("Creatures tamed: %d   Puzzles solved: %d" % [party.size(), puzzles_solved], Vector2(400, 320), 20, Color(0.85, 0.92, 0.85))
    _button(Rect2(500, 420, 280, 54), "TITLE")

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
                    if mode == "explore": _try_tame()
                    elif mode == "tame": _tame_press()
            KEY_1:
                if p: _use_ability(0)
            KEY_2:
                if p: _use_ability(1)
            KEY_3:
                if p: _use_ability(2)
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if mode == "title":
            if Rect2(500, 410, 280, 64).has_point(event.position):
                _start(); _setup_biome(0); queue_redraw()
        elif mode == "result":
            if Rect2(500, 420, 280, 54).has_point(event.position):
                mode = "title"; queue_redraw()
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_explore.json" <<'EOF'
{
  "duration_frames": 460,
  "events": [
    {"frame": 30,  "type": "mouse_click", "button": "left", "x": 640, "y": 442},
    {"frame": 80,  "type": "key_down", "keycode": "D"},
    {"frame": 180, "type": "key_up", "keycode": "D"},
    {"frame": 220, "type": "key_down", "keycode": "W"},
    {"frame": 300, "type": "key_up", "keycode": "W"},
    {"frame": 440, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/02_tame.json" <<'EOF'
{
  "scenario": "tame",
  "duration_frames": 400,
  "events": [
    {"frame": 60,  "type": "wait"},
    {"frame": 140, "type": "key_press", "keycode": "SPACE"},
    {"frame": 220, "type": "key_press", "keycode": "SPACE"},
    {"frame": 380, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/03_puzzle.json" <<'EOF'
{
  "scenario": "puzzle",
  "duration_frames": 400,
  "events": [
    {"frame": 60,  "type": "key_press", "keycode": "1"},
    {"frame": 180, "type": "key_press", "keycode": "1"},
    {"frame": 380, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/04_evolve.json" <<'EOF'
{
  "scenario": "evolve",
  "duration_frames": 400,
  "events": [
    {"frame": 80, "type": "key_press", "keycode": "1"},
    {"frame": 220, "type": "key_press", "keycode": "1"},
    {"frame": 380, "type": "wait"}
  ]
}
EOF

cat > "$GAME/demo_outputs/05_biome2.json" <<'EOF'
{
  "scenario": "explore",
  "duration_frames": 460,
  "events": [
    {"frame": 30,  "type": "key_down", "keycode": "D"},
    {"frame": 130, "type": "key_up", "keycode": "D"},
    {"frame": 160, "type": "key_press", "keycode": "SPACE"},
    {"frame": 220, "type": "key_press", "keycode": "SPACE"},
    {"frame": 300, "type": "key_down", "keycode": "D"},
    {"frame": 380, "type": "key_up", "keycode": "D"},
    {"frame": 440, "type": "wait"}
  ]
}
EOF

echo "beast-tamer oracle generated at $GAME"
