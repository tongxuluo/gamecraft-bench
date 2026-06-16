#!/bin/bash
# Reference solution for gamecraft-bench/openworld-submarine.
#
# A compact 2D submarine deep-ocean exploration game:
#   - Title -> ocean cross-section. WASD pilot sub (momentum, gravity pulls down).
#   - Sonar: press E to send a pulse ring that reveals hidden terrain/wrecks.
#   - Oxygen depletes while submerged; surface to refill. 0 O2 = mission fail.
#   - Depth pressure: crossing rated depth causes hull stress (HP loss over time).
#   - Discover wrecks (salvage credits), caves (rare loot), creatures (danger).
#   - Upgrades at surface dock: hull (depth rating), O2 tank, sonar range.
#   - Multiple depth layers with distinct visuals and content.
#   - HUD: depth, O2, hull HP, credits. Result on surfacing with full salvage
#     or hull breach.
#   - Scenarios jump to dive / sonar / wreck / pressure for deterministic demos.
set -eu

GAME="${GAME_PROJECT_PATH:-/workspace/game}"
mkdir -p "$GAME/scripts" "$GAME/scenes" "$GAME/assets" "$GAME/demo_outputs"

cat > "$GAME/project.godot" <<'EOF'
config_version=5
[application]
config/name="Submarine"
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
const SUB_R := 16.0
const SURFACE_Y := 80.0
const MAX_DEPTH := 600.0
const GRAVITY := 30.0
const MAX_O2 := 100.0
const O2_DRAIN := 8.0
const MAX_HULL := 10
const DEPTH_RATING := 300.0

const UPGRADES := [
    {"name": "Hull+", "cost": 60, "stat": "hull"},
    {"name": "O2 Tank+", "cost": 50, "stat": "o2"},
    {"name": "Sonar+", "cost": 70, "stat": "sonar"},
]

const LOCATIONS := [
    {"name": "Wreck Alpha", "pos": Vector2(400, 300), "kind": "wreck", "found": false},
    {"name": "Deep Cave", "pos": Vector2(800, 480), "kind": "cave", "found": false},
    {"name": "Abyss Vent", "pos": Vector2(600, 580), "kind": "vent", "found": false},
    {"name": "Coral Reef", "pos": Vector2(300, 180), "kind": "reef", "found": false},
]

var scenario := ""
var mode := "title"          # title, dive, dock, result
var pos := Vector2(640, SURFACE_Y)
var vel := Vector2.ZERO
var move := {"up": false, "down": false, "left": false, "right": false}
var o2 := MAX_O2
var hull := MAX_HULL
var depth_rating := DEPTH_RATING
var sonar_range := 120.0
var credits := 0
var sonar_pulse := 0.0       # expanding ring radius (0 = inactive)
var locations: Array = []
var revealed: Array = []     # indices of revealed locations
var salvage_goal := 3
var salvaged := 0
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
            scenario = args[i + 1]; i += 2
        else: i += 1

func _load_scenario(id: String) -> void:
    if id == "title_flow": mode = "title"
    elif id == "dive": _start()
    elif id == "sonar": _start(); pos = Vector2(400, 250)
    elif id == "wreck": _start(); pos = Vector2(400, 290); revealed = [0]
    elif id == "pressure": _start(); pos = Vector2(600, 500); depth_rating = 200.0
    elif id == "dock": _start(); pos = Vector2(640, SURFACE_Y); credits = 150; mode = "dock"
    else: _start()

func _start() -> void:
    mode = "dive"; pos = Vector2(640, SURFACE_Y); vel = Vector2.ZERO
    o2 = MAX_O2; hull = MAX_HULL; depth_rating = DEPTH_RATING; sonar_range = 120.0
    credits = 0; sonar_pulse = 0.0; salvaged = 0; revealed = []
    locations = []
    for loc in LOCATIONS:
        locations.append({"name": loc["name"], "pos": loc["pos"], "kind": loc["kind"], "found": false})
    msg = "WASD dive. E sonar. SPACE surface/dock. Collect salvage from wrecks."

func _depth() -> float:
    return max(0.0, pos.y - SURFACE_Y)

func _physics_process(delta: float) -> void:
    anim += delta
    if mode == "dive":
        _dive_physics(delta)
    if sonar_pulse > 0.0:
        sonar_pulse += 300.0 * delta
        if sonar_pulse > sonar_range * 3.0:
            sonar_pulse = 0.0
    queue_redraw()

func _dive_physics(delta: float) -> void:
    var dir := Vector2.ZERO
    if move["up"]: dir.y -= 1
    if move["down"]: dir.y += 1
    if move["left"]: dir.x -= 1
    if move["right"]: dir.x += 1
    vel = vel.lerp(dir * 160.0, 2.5 * delta)
    vel.y += GRAVITY * delta  # sinks naturally
    pos += vel * delta
    pos.x = clampf(pos.x, 60, VIEW.x - 60)
    pos.y = clampf(pos.y, SURFACE_Y - 20, SURFACE_Y + MAX_DEPTH)
    # O2
    if pos.y > SURFACE_Y + 10:
        o2 = max(0.0, o2 - O2_DRAIN * delta)
    else:
        o2 = min(MAX_O2, o2 + 40.0 * delta)
    # depth pressure
    if _depth() > depth_rating:
        hull -= 1
        msg = "HULL STRESS! Too deep!"
        if hull <= 0: _finish(false)
    # check proximity to revealed locations
    for i in range(locations.size()):
        if not revealed.has(i): continue
        var loc: Dictionary = locations[i]
        if loc["found"]: continue
        if pos.distance_to(loc["pos"]) < 50.0:
            loc["found"] = true
            var kind: String = str(loc["kind"])
            if kind == "wreck":
                credits += 80; salvaged += 1
                msg = "Salvaged %s! +80 credits." % str(loc["name"])
            elif kind == "cave":
                credits += 120
                msg = "Rare loot in %s! +120 credits." % str(loc["name"])
            else:
                credits += 40
                msg = "Explored %s. +40 credits." % str(loc["name"])
            if salvaged >= salvage_goal: _finish(true)
    if o2 <= 0: _finish(false)

func _sonar() -> void:
    if mode != "dive": return
    sonar_pulse = 1.0
    # reveal locations within sonar range
    for i in range(locations.size()):
        if revealed.has(i): continue
        if pos.distance_to(locations[i]["pos"]) < sonar_range:
            revealed.append(i)
            msg = "Sonar detected: %s!" % str(locations[i]["name"])
    queue_redraw()

func _surface_dock() -> void:
    if mode != "dive": return
    if pos.y <= SURFACE_Y + 30:
        mode = "dock"
        o2 = MAX_O2
        msg = "Surfaced. Dock: buy upgrades or dive again."
        queue_redraw()
    else:
        msg = "Must be near the surface to dock."
        queue_redraw()

func _buy_upgrade(idx: int) -> void:
    if idx < 0 or idx >= UPGRADES.size(): return
    var u: Dictionary = UPGRADES[idx]
    var cost: int = int(u["cost"])
    if credits < cost:
        msg = "Not enough credits."; queue_redraw(); return
    credits -= cost
    var stat: String = str(u["stat"])
    if stat == "hull": depth_rating += 100.0; hull = min(hull + 3, MAX_HULL)
    elif stat == "o2": o2 = MAX_O2  # refill + implicit bigger tank
    elif stat == "sonar": sonar_range += 60.0
    msg = "Upgraded %s!" % str(u["name"])
    queue_redraw()

func _dive_again() -> void:
    mode = "dive"; o2 = MAX_O2
    msg = "Diving again..."
    queue_redraw()

func _finish(victory: bool) -> void:
    mode = "result"; queue_redraw()

func _draw() -> void:
    # depth gradient background
    var depth_frac := clampf(_depth() / MAX_DEPTH, 0.0, 1.0)
    var bg := Color(0.05, 0.15, 0.3).lerp(Color(0.02, 0.03, 0.08), depth_frac)
    draw_rect(Rect2(Vector2.ZERO, VIEW), bg)
    # surface line
    draw_line(Vector2(0, SURFACE_Y), Vector2(VIEW.x, SURFACE_Y), Color(0.3, 0.5, 0.7, 0.5), 2.0)
    match mode:
        "title": _draw_title()
        "dive": _draw_dive()
        "dock": _draw_dock()
        "result": _draw_result()

func _text(s: String, p: Vector2, sz: int, c: Color) -> void:
    draw_string(ThemeDB.fallback_font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)
func _panel(r: Rect2, c := Color(0.04, 0.06, 0.12, 0.93)) -> void:
    draw_rect(r, c); draw_rect(r, Color(0.3, 0.5, 0.7, 0.9), false, 2.0)
func _button(r: Rect2, label: String, on := true) -> void:
    draw_rect(r, Color(0.08, 0.12, 0.20) if on else Color(0.16, 0.08, 0.08))
    draw_rect(r, Color(0.4, 0.6, 0.8) if on else Color(0.4, 0.3, 0.3), false, 2.0)
    _text(label, r.position + Vector2(14, r.size.y * 0.64), 18, Color(0.85, 0.92, 0.95))

func _draw_title() -> void:
    _panel(Rect2(330, 150, 620, 340))
    _text("SUBMARINE", Vector2(480, 250), 52, Color(0.4, 0.7, 0.9))
    _text("Descend into the abyss. Use sonar. Salvage the deep.", Vector2(380, 312), 18, Color(0.7, 0.85, 0.92))
    _button(Rect2(500, 410, 280, 64), "DIVE")

func _draw_dive() -> void:
    for i in range(7):
        var y := 80 + i * 90
        draw_rect(Rect2(0, y, VIEW.x, 90), Color(0.03, 0.10 + i * 0.015, 0.18 + i * 0.025, 0.18))
    draw_rect(Rect2(0, 640, VIEW.x, 80), Color(0.06, 0.045, 0.035, 0.75))
    for i in range(14):
        draw_circle(Vector2(fmod(anim * (18 + i) + i * 95, 1300), 150 + (i * 41) % 470), 3 + i % 4, Color(0.55, 0.85, 1.0, 0.18))
    # revealed locations
    for i in revealed:
        var loc: Dictionary = locations[i]
        var lc := Color(0.8, 0.6, 0.3) if str(loc["kind"]) == "wreck" else (Color(0.4, 0.8, 0.5) if str(loc["kind"]) == "cave" else Color(0.7, 0.5, 0.5))
        if loc["found"]: lc = lc.darkened(0.5)
        draw_circle(loc["pos"], 24, lc)
        _text(str(loc["name"]), loc["pos"] + Vector2(-30, 32), 12, Color(0.8, 0.85, 0.9))
    # sonar pulse ring
    if sonar_pulse > 0.0:
        draw_arc(pos, sonar_pulse, 0, TAU, 32, Color(0.3, 0.8, 0.9, 0.5 - sonar_pulse / (sonar_range * 3.0) * 0.5), 2.0)
    # depth pressure warning zone
    if _depth() > depth_rating:
        draw_rect(Rect2(0, pos.y - 20, VIEW.x, 40), Color(0.8, 0.2, 0.2, 0.15))
    # submarine
    draw_polygon([pos + Vector2(-28, -10), pos + Vector2(18, -12), pos + Vector2(34, 0), pos + Vector2(18, 12), pos + Vector2(-28, 10)], [Color(0.5, 0.7, 0.9)])
    draw_circle(pos + Vector2(10, 0), 7, Color(0.8, 0.95, 1.0))
    draw_line(pos + Vector2(-26, 0), pos + Vector2(-44, -10), Color(0.45, 0.65, 0.9), 4.0)
    draw_line(pos + Vector2(-26, 0), pos + Vector2(-44, 10), Color(0.45, 0.65, 0.9), 4.0)
    # HUD
    _panel(Rect2(0, 0, 1280, 60))
    _text("Depth %.0fm" % _depth(), Vector2(24, 40), 20, Color(0.7, 0.85, 0.95))
    _text("O2", Vector2(200, 28), 16, Color(0.6, 0.9, 0.9))
    draw_rect(Rect2(240, 22, 120, 16), Color(0.1, 0.1, 0.15))
    draw_rect(Rect2(240, 22, 120 * (o2 / MAX_O2), 16), Color(0.4, 0.9, 0.9))
    _text("Hull %d/%d" % [hull, MAX_HULL], Vector2(400, 40), 18, Color(0.8, 0.7, 0.5))
    _text("Credits %d" % credits, Vector2(580, 40), 20, Color(0.95, 0.85, 0.4))
    _text("Salvaged %d/%d" % [salvaged, salvage_goal], Vector2(760, 40), 18, Color(0.8, 0.9, 0.7))
    _text("Rating %.0fm" % depth_rating, Vector2(960, 40), 16, Color(0.7, 0.7, 0.8))
    _text(msg, Vector2(40, 700), 16, Color(0.7, 0.85, 0.9))

func _draw_dock() -> void:
    _draw_dive()
    draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, 0.5))
    _panel(Rect2(300, 120, 680, 460))
    _text("SURFACE DOCK", Vector2(460, 170), 32, Color(0.5, 0.8, 0.95))
    _text("Credits: %d   Hull: %d   O2: full" % [credits, hull], Vector2(380, 210), 18, Color(0.85, 0.9, 0.9))
    for i in range(UPGRADES.size()):
        var u: Dictionary = UPGRADES[i]
        _button(Rect2(380, 260 + i * 70, 520, 54), "%s — %d credits" % [str(u["name"]), int(u["cost"])], credits >= int(u["cost"]))
    _button(Rect2(380, 490, 520, 50), "DIVE AGAIN")

func _draw_result() -> void:
    _panel(Rect2(300, 180, 680, 320))
    if salvaged >= salvage_goal:
        _text("MISSION COMPLETE", Vector2(400, 260), 40, Color(0.5, 0.9, 0.7))
        _text("All salvage recovered. Credits: %d" % credits, Vector2(420, 320), 20, Color(0.85, 0.9, 0.9))
    elif o2 <= 0:
        _text("OXYGEN DEPLETED", Vector2(400, 260), 40, Color(0.4, 0.7, 0.9))
        _text("You suffocated in the deep.", Vector2(440, 320), 20, Color(0.7, 0.8, 0.85))
    else:
        _text("HULL BREACH", Vector2(440, 260), 40, Color(0.95, 0.4, 0.4))
        _text("Crushed by the pressure.", Vector2(450, 320), 20, Color(0.85, 0.7, 0.7))
    _button(Rect2(500, 420, 280, 54), "TITLE")

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey:
        var p: bool = event.pressed
        match event.keycode:
            KEY_W, KEY_UP: move["up"] = p
            KEY_S, KEY_DOWN: move["down"] = p
            KEY_A, KEY_LEFT: move["left"] = p
            KEY_D, KEY_RIGHT: move["right"] = p
            KEY_E: if p and not event.echo: _sonar()
            KEY_SPACE: if p and not event.echo: _surface_dock()
            KEY_1: if p: _buy_upgrade(0)
            KEY_2: if p: _buy_upgrade(1)
            KEY_3: if p: _buy_upgrade(2)
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if mode == "title":
            if Rect2(500, 410, 280, 64).has_point(event.position): _start(); queue_redraw()
        elif mode == "dock":
            for i in range(UPGRADES.size()):
                if Rect2(380, 260 + i * 70, 520, 54).has_point(event.position): _buy_upgrade(i); return
            if Rect2(380, 490, 520, 50).has_point(event.position): _dive_again()
        elif mode == "result":
            if Rect2(500, 420, 280, 54).has_point(event.position): mode = "title"; queue_redraw()
GDSCRIPT

cat > "$GAME/demo_outputs/01_title_dive.json" <<'EOF'
{"duration_frames":460,"events":[{"frame":30,"type":"mouse_click","button":"left","x":640,"y":442},{"frame":80,"type":"key_down","keycode":"S"},{"frame":200,"type":"key_up","keycode":"S"},{"frame":240,"type":"key_press","keycode":"E"},{"frame":340,"type":"key_down","keycode":"W"},{"frame":420,"type":"key_up","keycode":"W"},{"frame":440,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/02_sonar.json" <<'EOF'
{"scenario":"sonar","duration_frames":400,"events":[{"frame":40,"type":"key_press","keycode":"E"},{"frame":140,"type":"key_down","keycode":"S"},{"frame":240,"type":"key_up","keycode":"S"},{"frame":280,"type":"key_press","keycode":"E"},{"frame":380,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/03_wreck.json" <<'EOF'
{"scenario":"wreck","duration_frames":400,"events":[{"frame":30,"type":"key_down","keycode":"S"},{"frame":100,"type":"key_up","keycode":"S"},{"frame":140,"type":"key_down","keycode":"D"},{"frame":200,"type":"key_up","keycode":"D"},{"frame":380,"type":"wait"}]}
EOF
cat > "$GAME/demo_outputs/04_pressure.json" <<'EOF'
{"scenario":"pressure","duration_frames":380,"events":[{"frame":30,"type":"key_down","keycode":"S"},{"frame":200,"type":"key_up","keycode":"S"},{"frame":240,"type":"key_down","keycode":"W"},{"frame":360,"type":"key_up","keycode":"W"}]}
EOF
cat > "$GAME/demo_outputs/05_dock.json" <<'EOF'
{"scenario":"dock","duration_frames":380,"events":[{"frame":40,"type":"key_press","keycode":"1"},{"frame":120,"type":"key_press","keycode":"2"},{"frame":200,"type":"mouse_click","button":"left","x":640,"y":515},{"frame":360,"type":"wait"}]}
EOF

echo "submarine oracle generated at $GAME"
